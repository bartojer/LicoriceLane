defmodule LicoriceLane.Rentals.Lifecycle do
  @moduledoc """
  Atomic reservation and stock operations for managed bookings. Legacy rentals
  never acquire inferred allocations. Writers lock rental, sorted items, then
  locations; competing reservations are read while the item locks serialize writes.
  """
  import Ecto.Query
  import Ecto.Changeset
  alias LicoriceLane.{Repo, Rentals, Cache, Inventory}
  alias LicoriceLane.Rentals.{Rental, RentalAllocation, RentalSingleItem, RentalBulkItem}
  alias LicoriceLane.Items.{Item, SingleItem}
  alias LicoriceLane.Locations.{Location, ItemsLocation, LocationHistory}
  alias LicoriceLane.Customers.Customer

  @fields [
    :customer_id,
    :destination_location_id,
    :destination_name,
    :rented_at,
    :return_by,
    :event_type,
    :event_date
  ]

  def change_booking(rental, attrs \\ %{}) do
    rental
    |> cast(attrs, @fields)
    |> validate_required([:customer_id, :rented_at, :return_by])
    |> validate_number(:customer_id,
      greater_than: 0,
      less_than_or_equal_to: 9_223_372_036_854_775_807
    )
    |> validate_number(:destination_location_id,
      greater_than: 0,
      less_than_or_equal_to: 9_223_372_036_854_775_807
    )
    |> foreign_key_constraint(:customer_id)
    |> foreign_key_constraint(:destination_location_id)
    |> validate_window()
  end

  defp validate_window(cs) do
    pickup = get_field(cs, :rented_at)
    due = get_field(cs, :return_by)

    if match?(%DateTime{}, pickup) and match?(%DateTime{}, due) and
         DateTime.compare(pickup, due) != :lt,
       do: add_error(cs, :return_by, "must be after pickup"),
       else: cs
  end

  def create(attrs) when is_map(attrs) do
    transact(fn ->
      cs = change_booking(%Rental{}, attrs)
      valid!(cs)
      future_due!(cs)
      rows = normalize_allocations!(value(attrs, :allocations), cs)
      items = lock_items!(rows, cs)
      destination = destination!(cs)
      validate_rows!(rows, items, cs)
      capacity!(rows, items, apply_changes(cs), nil, cs)

      rental =
        cs
        |> put_change(:inventory_managed, true)
        |> put_change(:status, :reserved)
        |> put_change(:destination_location_id, destination.id)
        |> insert!()

      replace_rows!(rental, rows, items)
      rental
    end)
  end

  def create(_), do: {:error, add_error(change_booking(%Rental{}), :id, "invalid booking")}

  def check_availability(attrs) when is_map(attrs) do
    Repo.transaction(fn ->
      cs = %Rental{status: :reserved} |> Rentals.change_rental_details(attrs) |> validate_window()
      valid!(cs)
      future_due!(cs)
      rows = normalize_allocations!(value(attrs, :allocations), cs)
      items = lock_items!(rows, cs)
      validate_rows!(rows, items, cs)
      capacity!(rows, items, apply_changes(cs), nil, cs)
      :available
    end)
  end

  def check_availability(_),
    do: {:error, add_error(change(%Rental{}), :allocations, "invalid request")}

  def reallocate(rental, attrs) when is_map(attrs) do
    transact(fn ->
      current = lock_rental!(rental)
      require_status!(current, [:reserved])
      cs = change(current)
      rows = normalize_allocations!(value(attrs, :allocations), cs)
      old = allocations(current.id)
      items = lock_items!(rows ++ old, cs)
      validate_rows!(rows, items, cs)
      capacity!(rows, items, current, current.id, cs)
      replace_rows!(current, rows, items)
      bump!(current, %{})
    end)
  end

  def reallocate(rental, _),
    do: {:error, add_error(change(rental), :allocations, "invalid allocations")}

  def update_details(rental, attrs) do
    transact(fn ->
      current = lock_rental!(rental)

      if Map.take(current, [:event_type, :event_date, :rented_at, :return_by]) !=
           Map.take(rental, [:event_type, :event_date, :rented_at, :return_by]),
         do: fail!(change(current), :id, "has changed; close and reopen this booking")

      cs = current |> Rentals.change_rental_details(attrs) |> validate_window()
      valid!(cs)

      if current.status != :reserved and
           (get_field(cs, :rented_at) != current.rented_at or
              (current.status in [:returned, :cancelled] and
                 get_field(cs, :return_by) != current.return_by)),
         do: fail!(cs, :rented_at, "schedule is fixed after checkout or cancellation")

      if current.status in [:reserved, :active, :late] and
           (get_field(cs, :rented_at) != current.rented_at or
              get_field(cs, :return_by) != current.return_by) do
        future_due!(cs)
        rows = allocations(current.id)
        items = lock_items!(rows, cs)
        capacity!(rows, items, apply_changes(cs), current.id, cs)
      end

      cs |> put_change(:lifecycle_version, current.lifecycle_version + 1) |> update!()
    end)
  end

  def checkout(rental) do
    transact(fn ->
      current = lock_rental!(rental)
      require_status!(current, [:reserved])
      cs = change(current)
      now = now()

      if DateTime.compare(now, current.rented_at) == :lt,
        do:
          fail!(
            cs,
            :rented_at,
            "checkout cannot precede scheduled pickup; edit the schedule first"
          )

      future_due!(cs)
      rows = allocations(current.id)
      items = lock_items!(rows, cs)
      lock_destination!(current, cs)
      validate_rows!(rows, items, cs)
      capacity!(rows, items, current, current.id, cs)

      Enum.each(rows, fn row ->
        move!(
          items[row.item_id],
          row.quantity,
          row.source_location_id,
          current.destination_location_id,
          current,
          cs,
          :checkout
        )
      end)

      bump!(current, %{status: :active, checked_out_at: now})
    end)
  end

  def cancel(rental) do
    transact(fn ->
      current = lock_rental!(rental)
      require_status!(current, [:reserved])
      lock_items!(allocations(current.id), change(current))
      bump!(current, %{status: :cancelled})
    end)
  end

  def return_items(rental, attrs) when is_map(attrs) do
    transact(fn ->
      current = lock_rental!(rental)
      require_status!(current, [:active, :late])
      cs = change(current)
      rows = allocations(current.id)
      items = lock_items!(rows, cs)
      lock_destination!(current, cs)
      returns = normalize_returns!(value(attrs, :returns), rows, cs)
      lock_warehouses!(rows, cs)

      Enum.each(returns, fn {row, quantity} ->
        move!(
          items[row.item_id],
          quantity,
          current.destination_location_id,
          row.source_location_id,
          current,
          cs,
          :return
        )

        row |> change(returned_quantity: row.returned_quantity + quantity) |> update!()
      end)

      complete = Enum.all?(allocations(current.id), &(&1.returned_quantity == &1.quantity))
      changes = if complete, do: %{status: :returned, returned_at: now()}, else: %{}
      bump!(current, changes)
    end)
  end

  def return_items(rental, _),
    do: {:error, add_error(change(rental), :returns, "invalid returns")}

  # Called under the item lock by Inventory. Any live commitment protects tracking.
  def item_committed?(id) do
    Repo.exists?(
      from a in RentalAllocation,
        join: r in Rental,
        on: r.id == a.rental_id,
        where: a.item_id == ^id and r.status in [:reserved, :active, :late]
    ) or
      legacy_item?(id)
  end

  defp transact(fun) do
    case Repo.transaction(fun) do
      {:ok, rental} ->
        Cache.invalidate_rentals()
        Cache.invalidate_inventory()

        Phoenix.PubSub.broadcast(
          LicoriceLane.PubSub,
          "rentals:updates",
          {:rental_updated, rental.id}
        )

        rental = Rentals.get_rental(rental.id)
        Enum.each(rental.allocations, &Inventory.broadcast_inventory_update(&1.item_id))
        {:ok, rental}

      error ->
        error
    end
  end

  defp lock_rental!(snapshot) do
    current = Repo.one(from r in Rental, where: r.id == ^snapshot.id, lock: "FOR UPDATE")

    cond do
      is_nil(current) ->
        fail!(change(snapshot), :id, "is no longer available")

      not current.inventory_managed ->
        fail!(change(current), :id, "requires legacy reconciliation before stock actions")

      current.lifecycle_version != snapshot.lifecycle_version ->
        fail!(change(snapshot), :id, "has changed; close and reopen this booking")

      true ->
        current
    end
  end

  defp require_status!(rental, allowed) do
    if rental.status not in allowed,
      do: fail!(change(rental), :status, "does not allow this operation")
  end

  defp lock_items!(rows, cs) do
    ids = rows |> Enum.map(& &1.item_id) |> Enum.uniq() |> Enum.sort()
    items = Repo.all(from i in Item, where: i.id in ^ids, order_by: i.id, lock: "FOR UPDATE")
    if length(items) != length(ids), do: fail!(cs, :allocations, "contains an unavailable item")
    Map.new(items, &{&1.id, &1})
  end

  defp allocations(id),
    do: Repo.all(from a in RentalAllocation, where: a.rental_id == ^id, order_by: a.id)

  defp destination!(cs) do
    customer_id = get_field(cs, :customer_id)

    if not Repo.exists?(from c in Customer, where: c.id == ^customer_id),
      do: fail!(cs, :customer_id, "is no longer available")

    id = get_field(cs, :destination_location_id)
    name = get_field(cs, :destination_name)

    cond do
      id ->
        location = Repo.one(from l in Location, where: l.id == ^id, lock: "FOR SHARE")
        valid_destination!(location, customer_id, cs)

      is_binary(name) and String.trim(name) != "" ->
        %Location{}
        |> Location.changeset(%{
          name: String.trim(name),
          location_type: :customer,
          customer_id: customer_id
        })
        |> insert!()

      true ->
        fail!(cs, :destination_name, "enter a venue name or select a customer location")
    end
  end

  defp lock_destination!(rental, cs) do
    location =
      Repo.one(
        from l in Location, where: l.id == ^rental.destination_location_id, lock: "FOR SHARE"
      )

    valid_destination!(location, rental.customer_id, cs)
  end

  defp valid_destination!(%Location{location_type: :customer, customer_id: id} = l, id, _cs),
    do: l

  defp valid_destination!(_, _, cs),
    do: fail!(cs, :destination_location_id, "must belong to this customer")

  defp lock_warehouses!(rows, cs) do
    ids = rows |> Enum.map(& &1.source_location_id) |> Enum.uniq() |> Enum.sort()

    locations =
      Repo.all(from l in Location, where: l.id in ^ids, order_by: l.id, lock: "FOR SHARE")

    if length(locations) != length(ids) or
         Enum.any?(locations, &(&1.location_type != :warehouse)),
       do: fail!(cs, :allocations, "sources must be existing warehouses")
  end

  defp validate_rows!(rows, items, cs) do
    lock_warehouses!(rows, cs)

    Enum.each(Enum.group_by(rows, & &1.item_id), fn {id, group} ->
      if Enum.sum(Enum.map(group, & &1.quantity)) > 2_147_483_647,
        do: fail!(cs, :allocations, "total item quantity exceeds supported storage")

      if legacy_item?(id),
        do: fail!(cs, :allocations, "#{items[id].name} requires legacy reconciliation")

      if items[id].item_type == :single and (length(group) != 1 or hd(group).quantity != 1),
        do: fail!(cs, :allocations, "single items require exactly one unit from one warehouse")
    end)
  end

  defp legacy_item?(id) do
    Repo.exists?(
      from b in RentalBulkItem,
        join: r in Rental,
        on: r.id == b.rental_id,
        where: b.item_id == ^id and not r.inventory_managed and r.status in [:active, :late]
    ) or
      Repo.exists?(
        from s in RentalSingleItem,
          join: r in Rental,
          on: r.id == s.rental_id,
          where:
            s.single_item_id == ^id and not r.inventory_managed and r.status in [:active, :late]
      )
  end

  # Warehouse stock plus outstanding units promised back to it is stable across
  # checkout/return. Demand uses a sweep of simultaneous interval endpoints.
  defp capacity!(rows, items, candidate, exclude_id, cs) do
    Enum.each(rows, fn row ->
      commitments =
        Repo.all(
          from a in RentalAllocation,
            join: r in Rental,
            on: r.id == a.rental_id,
            where:
              a.item_id == ^row.item_id and a.source_location_id == ^row.source_location_id and
                r.status in [:reserved, :active, :late],
            select: {a, r}
        )

      outstanding =
        commitments
        |> Enum.filter(fn {_, r} -> r.status in [:active, :late] end)
        |> Enum.map(fn {a, _} -> a.quantity - a.returned_quantity end)
        |> Enum.sum()

      capacity = physical_quantity(items[row.item_id], row.source_location_id) + outstanding

      demand =
        commitments
        |> Enum.reject(fn {_, r} -> r.id == exclude_id end)
        |> Enum.map(fn {a, r} -> interval(a, r) end)

      quantity = row.quantity - Map.get(row, :returned_quantity, 0)
      {start_at, end_at, _} = interval(%{quantity: quantity, returned_quantity: 0}, candidate)
      peak = peak_demand([{start_at, end_at, quantity} | demand], start_at, end_at)

      if peak > capacity,
        do:
          fail!(
            cs,
            :allocations,
            "#{items[row.item_id].name} has insufficient stock at the selected warehouse for this window"
          )
    end)
  end

  defp interval(a, r) do
    active = r.status in [:active, :late]
    quantity = if active, do: a.quantity - a.returned_quantity, else: a.quantity

    start_at =
      if active and r.checked_out_at,
        do: min_time(r.rented_at, r.checked_out_at),
        else: r.rented_at

    end_at = if active and DateTime.compare(r.return_by, now()) != :gt, do: nil, else: r.return_by
    {start_at, end_at, quantity}
  end

  defp peak_demand(intervals, start_at, end_at) do
    events =
      Enum.flat_map(intervals, fn {s, e, q} ->
        s = max_time(s, start_at)
        e = if is_nil(e), do: end_at, else: if(is_nil(end_at), do: e, else: min_time(e, end_at))

        if q > 0 and (is_nil(e) or DateTime.compare(s, e) == :lt) do
          [{DateTime.to_unix(s), q}] ++ if(e, do: [{DateTime.to_unix(e), -q}], else: [])
        else
          []
        end
      end)

    events
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.sort()
    |> Enum.reduce({0, 0}, fn {_, deltas}, {used, peak} ->
      used = used + Enum.sum(deltas)
      {used, max(peak, used)}
    end)
    |> elem(1)
  end

  defp physical_quantity(%Item{item_type: :single, id: id}, location) do
    case Repo.get(SingleItem, id) do
      %SingleItem{status: :available, location_id: ^location} -> 1
      _ -> 0
    end
  end

  defp physical_quantity(item, location) do
    Repo.one(
      from s in ItemsLocation,
        where: s.item_id == ^item.id and s.location_id == ^location,
        select: s.quantity
    ) || 0
  end

  defp replace_rows!(rental, rows, items) do
    Repo.delete_all(from a in RentalAllocation, where: a.rental_id == ^rental.id)
    Repo.delete_all(from a in RentalSingleItem, where: a.rental_id == ^rental.id)
    Repo.delete_all(from a in RentalBulkItem, where: a.rental_id == ^rental.id)

    Enum.each(rows, fn row ->
      %RentalAllocation{}
      |> RentalAllocation.changeset(Map.put(row, :rental_id, rental.id))
      |> insert!()
    end)

    Enum.each(Enum.group_by(rows, & &1.item_id), fn {id, group} ->
      if items[id].item_type == :single do
        %RentalSingleItem{}
        |> RentalSingleItem.changeset(%{rental_id: rental.id, single_item_id: id})
        |> insert!()
      else
        %RentalBulkItem{}
        |> RentalBulkItem.changeset(%{
          rental_id: rental.id,
          item_id: id,
          quantity: Enum.sum(Enum.map(group, & &1.quantity))
        })
        |> insert!()
      end
    end)
  end

  defp move!(%Item{item_type: :single, id: id}, 1, from, to, rental, cs, direction) do
    single = Repo.get(SingleItem, id)
    expected = if direction == :checkout, do: :available, else: :rented

    if is_nil(single) or single.location_id != from or single.status != expected,
      do: fail!(cs, :allocations, "single item physical location/status has changed")

    single
    |> change(location_id: to, status: if(direction == :checkout, do: :rented, else: :available))
    |> update!()

    history!(id, 1, from, to, rental.id)
  end

  defp move!(item, quantity, from, to, rental, cs, _) do
    source =
      Repo.one(
        from s in ItemsLocation,
          where: s.item_id == ^item.id and s.location_id == ^from,
          lock: "FOR UPDATE"
      )

    if is_nil(source) or source.quantity < quantity,
      do: fail!(cs, :allocations, "physical stock is insufficient; no items were moved")

    destination =
      Repo.one(
        from s in ItemsLocation,
          where: s.item_id == ^item.id and s.location_id == ^to,
          lock: "FOR UPDATE"
      )

    if destination && destination.quantity + quantity > 2_147_483_647,
      do: fail!(cs, :allocations, "destination quantity exceeds supported storage")

    source |> change(quantity: source.quantity - quantity) |> update!()

    if destination do
      destination |> change(quantity: destination.quantity + quantity) |> update!()
    else
      %ItemsLocation{}
      |> ItemsLocation.changeset(%{item_id: item.id, location_id: to, quantity: quantity})
      |> insert!()
    end

    history!(item.id, quantity, from, to, rental.id)
  end

  defp history!(item, quantity, from, to, rental) do
    %LocationHistory{}
    |> LocationHistory.changeset(%{
      item_id: item,
      quantity: quantity,
      from_location_id: from,
      to_location_id: to,
      rental_id: rental,
      ts: now()
    })
    |> insert!()
  end

  defp normalize_allocations!(input, cs) do
    rows = input_rows(input)
    if rows == [], do: fail!(cs, :allocations, "select at least one item and source warehouse")

    rows =
      Enum.map(rows, fn row ->
        if not is_map(row), do: fail!(cs, :allocations, "invalid allocation")

        %{
          item_id: positive!(value(row, :item_id), cs, :allocations),
          source_location_id: positive!(value(row, :source_location_id), cs, :allocations),
          quantity: positive!(value(row, :quantity), cs, :allocations)
        }
      end)

    if length(Enum.uniq_by(rows, &{&1.item_id, &1.source_location_id})) != length(rows),
      do: fail!(cs, :allocations, "duplicate item/source rows; combine their quantities")

    rows
  end

  defp normalize_returns!(input, rows, cs) do
    entries = input_rows(input)

    result =
      Enum.flat_map(entries, fn entry ->
        if not is_map(entry), do: fail!(cs, :returns, "invalid return")
        raw = value(entry, :quantity)

        if raw in [nil, "", "0", 0] do
          []
        else
          id = positive!(value(entry, :allocation_id), cs, :returns)
          quantity = positive!(raw, cs, :returns)
          row = Enum.find(rows, &(&1.id == id))

          if is_nil(row) or quantity > row.quantity - row.returned_quantity,
            do: fail!(cs, :returns, "quantity exceeds this allocation's outstanding units")

          [{row, quantity}]
        end
      end)

    if result == [] or length(Enum.uniq_by(result, fn {row, _} -> row.id end)) != length(result),
      do: fail!(cs, :returns, "enter positive quantities once per allocation")

    result
  end

  defp input_rows(input) when is_list(input), do: input

  defp input_rows(input) when is_map(input),
    do: input |> Enum.sort_by(&elem(&1, 0)) |> Enum.map(&elem(&1, 1))

  defp input_rows(_), do: []

  defp positive!(number, _cs, _field)
       when is_integer(number) and number > 0 and number <= 9_223_372_036_854_775_807,
       do: number

  defp positive!(raw, cs, field) when is_binary(raw) do
    case Integer.parse(raw) do
      {number, ""} when number > 0 and number <= 9_223_372_036_854_775_807 -> number
      _ -> fail!(cs, field, "use positive whole numbers")
    end
  end

  defp positive!(_, cs, field), do: fail!(cs, field, "use positive whole numbers")
  defp value(map, key), do: Map.get(map, key, Map.get(map, Atom.to_string(key)))
  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
  defp min_time(a, b), do: if(DateTime.compare(a, b) == :lt, do: a, else: b)
  defp max_time(a, b), do: if(DateTime.compare(a, b) == :gt, do: a, else: b)

  defp future_due!(cs) do
    if DateTime.compare(get_field(cs, :return_by), now()) != :gt,
      do: fail!(cs, :return_by, "must be in the future")
  end

  defp bump!(rental, attrs),
    do:
      rental
      |> change(Map.put(attrs, :lifecycle_version, rental.lifecycle_version + 1))
      |> update!()

  defp valid!(%{valid?: true}), do: :ok
  defp valid!(cs), do: Repo.rollback(%{cs | action: :insert})

  defp fail!(cs, field, message),
    do: Repo.rollback(%{add_error(cs, field, message) | action: :update})

  defp insert!(cs), do: persist(Repo.insert(cs))
  defp update!(cs), do: persist(Repo.update(cs))
  defp persist({:ok, row}), do: row
  defp persist({:error, cs}), do: Repo.rollback(cs)
end
