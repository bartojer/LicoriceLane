defmodule LicoriceLane.RentalLifecycleTest do
  use LicoriceLane.DataCase
  import LicoriceLane.{ItemsFixtures, LocationsFixtures, CustomersFixtures, RentalsFixtures}
  alias LicoriceLane.{Rentals, Inventory, Repo, Cache}
  alias LicoriceLane.Rentals.{Rental, RentalAllocation}
  alias LicoriceLane.Items.SingleItem
  alias LicoriceLane.Locations.{ItemsLocation, LocationHistory, Location}

  test "availability is advisory and does not create destinations, invalidate or broadcast", c do
    request = attrs(c, [row(c.bulk, c.source, 10)])
    Phoenix.PubSub.subscribe(LicoriceLane.PubSub, "rentals:updates")
    Cache.put(:rentals, :retained)
    assert {:ok, :available} = Rentals.check_rental_availability(request)
    assert Repo.aggregate(Rental, :count) == 0 and Repo.aggregate(Location, :count) == 2
    assert Cache.get(:rentals) == :retained
    refute_receive {:rental_updated, _}

    assert {:error, _} =
             Rentals.check_rental_availability(
               attrs(c, [row(c.bulk, c.source, 1)], time(-3600), time(-1800))
             )

    book!(c, [row(c.bulk, c.source, 10)])
    assert {:error, _} = Rentals.check_rental_availability(request)
  end

  setup tags do
    Cache.clear()
    on_exit(fn -> Cache.clear() end)
    customer = customer_fixture()
    source = warehouse_fixture()
    other = warehouse_fixture()
    bulk = bulk_item_fixture(%{location: source, quantity: 10})
    single = if tags[:single], do: single_item_fixture(%{location: source})
    Repo.insert!(%ItemsLocation{item_id: bulk.id, location_id: other.id, quantity: 4})
    %{customer: customer, source: source, other: other, bulk: bulk, single: single}
  end

  @tag :single
  test "booking reserves multi-source summaries without moving stock or trusting lifecycle fields",
       c do
    Phoenix.PubSub.subscribe(LicoriceLane.PubSub, "rentals:updates")
    Phoenix.PubSub.subscribe(LicoriceLane.PubSub, "inventory:updates")
    Cache.put(:rentals, :stale)
    Cache.put(:inventory_items, :stale)

    attrs =
      attrs(c, [row(c.bulk, c.source, 6), row(c.bulk, c.other, 3), row(c.single, c.source, 1)])
      |> Map.merge(%{status: :returned, returned_at: time(0), inventory_managed: false})

    assert {:ok, r} = Rentals.create_rental(attrs)
    assert r.status == :reserved and r.inventory_managed
    assert r.returned_at == nil and r.checked_out_at == nil
    assert length(r.allocations) == 3
    assert hd(r.rental_bulk_items).quantity == 9
    assert hd(r.rental_single_items).single_item_id == c.single.id
    assert stock(c.bulk, c.source) == 10
    assert stock(c.bulk, c.other) == 4
    assert Repo.get!(SingleItem, c.single.id).status == :available
    assert Repo.aggregate(LocationHistory, :count) == 0
    assert_receive {:rental_updated, id}
    assert id == r.id
    assert Cache.get(:rentals) == nil
    assert Cache.get(:inventory_items) == nil
    bulk_id = c.bulk.id
    single_id = c.single.id
    assert_receive {:inventory_updated, ^bulk_id}
    assert_receive {:inventory_updated, ^single_id}
  end

  test "peak demand permits disjoint overlaps and adjacent boundaries, rejecting overbooking",
       c do
    t = time(3600)
    book!(c, [row(c.bulk, c.source, 6)], t, DateTime.add(t, 3600))
    book!(c, [row(c.bulk, c.source, 6)], DateTime.add(t, 3600), DateTime.add(t, 7200))

    assert {:ok, _} =
             Rentals.create_rental(attrs(c, [row(c.bulk, c.source, 4)], t, DateTime.add(t, 7200)))

    assert {:error, cs} =
             Rentals.create_rental(attrs(c, [row(c.bulk, c.source, 1)], t, DateTime.add(t, 7200)))

    assert errors_on(cs).allocations != []
    assert Repo.aggregate(Rental, :count) == 3
    assert stock(c.bulk, c.source) == 10
  end

  @tag :single
  test "mixed checkout and partial returns conserve stock and retain booked summary quantities",
       c do
    r = book!(c, [row(c.bulk, c.source, 6), row(c.bulk, c.other, 3), row(c.single, c.source, 1)])
    assert {:ok, out} = Rentals.checkout_rental(r)
    assert out.status == :active and out.checked_out_at
    assert stock(c.bulk, c.source) == 4 and stock(c.bulk, c.other) == 1
    assert stock(c.bulk, %{id: out.destination_location_id}) == 9
    assert Repo.get!(SingleItem, c.single.id).location_id == out.destination_location_id
    assert Repo.aggregate(LocationHistory, :count) == 3

    a =
      Enum.find(
        out.allocations,
        &(&1.item_id == c.bulk.id and &1.source_location_id == c.source.id)
      )

    s = Enum.find(out.allocations, &(&1.item_id == c.single.id))

    assert {:ok, partial} =
             Rentals.return_rental(out, %{returns: [return_row(a, 2), return_row(s, 1)]})

    assert partial.status == :active and is_nil(partial.returned_at)
    assert hd(partial.rental_bulk_items).quantity == 9
    assert stock(c.bulk, c.source) == 6
    assert stock(c.bulk, %{id: out.destination_location_id}) == 7
    assert Repo.get!(SingleItem, c.single.id).status == :available
    assert Repo.get!(SingleItem, c.single.id).location_id == c.source.id
    remaining = Enum.filter(partial.allocations, &(&1.quantity > &1.returned_quantity))

    assert {:ok, done} =
             Rentals.return_rental(partial, %{
               returns: Enum.map(remaining, &return_row(&1, &1.quantity - &1.returned_quantity))
             })

    assert done.status == :returned and done.returned_at
    assert stock(c.bulk, c.source) == 10 and stock(c.bulk, c.other) == 4
    assert stock(c.bulk, %{id: out.destination_location_id}) == 0
    assert Repo.aggregate(LocationHistory, :count) == 7
    assert Enum.all?(done.allocations, &(&1.returned_quantity == &1.quantity))

    history =
      Repo.all(
        from h in LocationHistory,
          where: h.rental_id == ^r.id,
          select: {h.item_id, h.quantity, h.from_location_id, h.to_location_id}
      )

    assert Enum.sort(history) ==
             Enum.sort([
               {c.bulk.id, 6, c.source.id, out.destination_location_id},
               {c.bulk.id, 3, c.other.id, out.destination_location_id},
               {c.single.id, 1, c.source.id, out.destination_location_id},
               {c.bulk.id, 2, out.destination_location_id, c.source.id},
               {c.single.id, 1, out.destination_location_id, c.source.id},
               {c.bulk.id, 4, out.destination_location_id, c.source.id},
               {c.bulk.id, 3, out.destination_location_id, c.other.id}
             ])

    assert {:error, _} = Rentals.return_rental(done, %{returns: [return_row(a, 1)]})

    assert {:error, _} =
             Rentals.update_rental_details(done, %{return_by: DateTime.add(done.return_by, 60)})

    assert {:ok, corrected} = Rentals.update_rental_details(done, %{event_type: :birthday})
    assert corrected.returned_at == done.returned_at and corrected.return_by == done.return_by
  end

  test "replays, stale forms, foreign allocations and excessive returns cannot move stock", c do
    r = book!(c, [row(c.bulk, c.source, 5)])
    {:ok, out} = Rentals.checkout_rental(r)
    assert {:error, stale} = Rentals.checkout_rental(r)
    assert errors_on(stale).id != []
    a = hd(out.allocations)
    other = book!(c, [row(c.bulk, c.other, 1)])

    assert {:error, _} =
             Rentals.return_rental(out, %{returns: [return_row(hd(other.allocations), 1)]})

    assert {:error, _} = Rentals.return_rental(out, %{returns: [return_row(a, 6)]})

    assert {:error, _} =
             Rentals.return_rental(out, %{returns: [return_row(a, 1), return_row(a, 1)]})

    assert {:error, _} =
             Rentals.return_rental(out, %{returns: [%{allocation_id: a.id + 1000, quantity: 1}]})

    for quantity <- [0, "", -1, "1oops", %{}] do
      assert {:error, _} = Rentals.return_rental(out, %{returns: [return_row(a, quantity)]})
    end

    assert stock(c.bulk, c.source) == 5
    assert hd(Rentals.get_rental(out.id).allocations).returned_quantity == 0

    {:ok, partial} = Rentals.return_rental(out, %{returns: [return_row(a, 1)]})
    assert {:error, _} = Rentals.return_rental(out, %{returns: [return_row(a, 1)]})
    assert partial.lifecycle_version == 2
    assert stock(c.bulk, c.source) == 6
    assert Repo.aggregate(LocationHistory, :count) == 2
    assert {:error, _} = Rentals.cancel_rental(partial)
  end

  @tag :single
  test "physical preflight failure does not move stock, broadcast or invalidate",
       c do
    r = book!(c, [row(c.bulk, c.source, 5), row(c.single, c.source, 1)])
    # A changed physical single location invalidates the planned source.
    Repo.get!(SingleItem, c.single.id)
    |> Ecto.Changeset.change(location_id: c.other.id)
    |> Repo.update!()

    Phoenix.PubSub.subscribe(LicoriceLane.PubSub, "rentals:updates")
    Phoenix.PubSub.subscribe(LicoriceLane.PubSub, "inventory:updates")
    for key <- [:rentals, :inventory_items, :dashboard_stats], do: Cache.put(key, :retained)
    assert {:error, _} = Rentals.checkout_rental(r)
    assert stock(c.bulk, c.source) == 10
    assert Repo.aggregate(LocationHistory, :count) == 0
    assert Rentals.get_rental(r.id).status == :reserved

    for key <- [:rentals, :inventory_items, :dashboard_stats],
        do: assert(Cache.get(key) == :retained)

    refute_receive {:rental_updated, _}
    refute_received {:inventory_updated, _}
  end

  test "checkout failure after an earlier bulk movement rolls back every stock row", c do
    r = book!(c, [row(c.bulk, c.source, 5), row(c.bulk, c.other, 3)])
    destination_quantity = 2_147_483_647 - 6

    Repo.insert!(%ItemsLocation{
      item_id: c.bulk.id,
      location_id: r.destination_location_id,
      quantity: destination_quantity
    })

    assert {:error, cs} = Rentals.checkout_rental(r)
    assert hd(errors_on(cs).allocations) =~ "storage"
    assert stock(c.bulk, c.source) == 10 and stock(c.bulk, c.other) == 4
    assert stock(c.bulk, %{id: r.destination_location_id}) == destination_quantity
    assert Repo.aggregate(LocationHistory, :count) == 0
    assert Rentals.get_rental(r.id).lifecycle_version == 0
  end

  @tag :single
  test "a return failure after an earlier movement rolls everything back", c do
    r = book!(c, [row(c.bulk, c.source, 5), row(c.single, c.source, 1)])
    {:ok, out} = Rentals.checkout_rental(r)

    Repo.get!(SingleItem, c.single.id)
    |> Ecto.Changeset.change(location_id: c.other.id)
    |> Repo.update!()

    returns = Enum.map(out.allocations, &return_row(&1, &1.quantity))
    assert {:error, _} = Rentals.return_rental(out, %{returns: returns})
    assert stock(c.bulk, c.source) == 5
    assert Repo.all(RentalAllocation) |> Enum.all?(&(&1.returned_quantity == 0))
    assert Repo.aggregate(LocationHistory, :count) == 2
  end

  test "cancellation releases reservations, retains history references and rejects replay", c do
    r = book!(c, [row(c.bulk, c.source, 10)])
    assert {:error, _} = Rentals.create_rental(attrs(c, [row(c.bulk, c.source, 1)]))
    assert {:ok, cancelled} = Rentals.cancel_rental(r)
    assert cancelled.status == :cancelled and length(cancelled.allocations) == 1

    assert {:error, _} =
             Rentals.update_rental_details(cancelled, %{
               rented_at: DateTime.add(cancelled.rented_at, -60)
             })

    assert {:ok, corrected} = Rentals.update_rental_details(cancelled, %{event_type: :corporate})
    assert corrected.status == :cancelled and corrected.rented_at == cancelled.rented_at
    assert {:ok, _} = Rentals.create_rental(attrs(c, [row(c.bulk, c.source, 10)]))
    assert {:error, _} = Rentals.cancel_rental(r)
    assert {:error, _} = Inventory.delete_item(c.bulk)
    assert stock(c.bulk, c.source) == 10
    assert Repo.aggregate(LocationHistory, :count) == 0
  end

  test "allocation changes validate new sources, update summaries, and reject stale scheduling",
       c do
    r = book!(c, [row(c.bulk, c.source, 10)])

    assert {:error, _} =
             Rentals.update_rental_allocations(r, %{allocations: [row(c.bulk, c.other, 5)]})

    assert {:ok, changed} =
             Rentals.update_rental_allocations(r, %{allocations: [row(c.bulk, c.other, 4)]})

    assert hd(changed.allocations).source_location_id == c.other.id
    assert hd(changed.rental_bulk_items).quantity == 4
    assert {:error, _} = Rentals.update_rental_details(r, %{event_type: :birthday})
    assert {:ok, _} = Rentals.create_rental(attrs(c, [row(c.bulk, c.source, 10)]))
    assert stock(c.bulk, c.other) == 4
  end

  test "managed scheduling checks capacity and freezes actual pickup after checkout", c do
    t = time(3600)
    r = book!(c, [row(c.bulk, c.source, 10)], t, DateTime.add(t, 3600))
    next = book!(c, [row(c.bulk, c.source, 10)], DateTime.add(t, 3600), DateTime.add(t, 7200))
    assert {:error, _} = Rentals.update_rental_details(r, %{return_by: DateTime.add(t, 3601)})
    assert Rentals.get_rental(r.id).return_by == r.return_by
    assert {:error, _} = Rentals.checkout_rental(r)
    {:ok, _} = Rentals.cancel_rental(next)
    {:ok, r} = Rentals.update_rental_details(r, %{rented_at: time(-60)})
    {:ok, out} = Rentals.checkout_rental(r)
    assert {:error, _} = Rentals.update_rental_details(out, %{rented_at: time(-120)})
    assert {:error, _} = Rentals.update_rental_details(out, %{return_by: out.rented_at})
  end

  test "checked out units can serve a future window but overdue units remain unavailable", c do
    r = book!(c, [row(c.bulk, c.source, 10)], time(-60), time(3600))
    {:ok, out} = Rentals.checkout_rental(r)

    assert {:ok, future} =
             Rentals.create_rental(attrs(c, [row(c.bulk, c.source, 10)], time(7200), time(10800)))

    assert {:error, _} =
             Rentals.create_rental(attrs(c, [row(c.bulk, c.source, 1)], time(600), time(1200)))

    # Simulate passage past the original due time, without waiting in a test.
    Repo.get!(Rental, out.id) |> Ecto.Changeset.change(return_by: time(-1)) |> Repo.update!()

    assert {:error, _} =
             Rentals.create_rental(attrs(c, [row(c.bulk, c.source, 1)], time(14400), time(18000)))

    assert {:error, _} = Rentals.checkout_rental(future)
    out = Rentals.get_rental(out.id)
    {:ok, partial} = Rentals.return_rental(out, %{returns: [return_row(hd(out.allocations), 3)]})
    {:ok, _} = Rentals.cancel_rental(future)

    assert {:ok, _} =
             Rentals.create_rental(attrs(c, [row(c.bulk, c.source, 3)], time(14400), time(18000)))

    assert {:error, _} =
             Rentals.create_rental(attrs(c, [row(c.bulk, c.source, 1)], time(14400), time(18000)))

    assert partial.status == :active
  end

  test "legacy live allocations require reconciliation and never acquire stock actions", c do
    old = rental_with_bulk_items_fixture(%{bulk_item: c.bulk})
    assert {:error, cs} = Rentals.create_rental(attrs(c, [row(c.bulk, c.other, 1)]))
    assert hd(errors_on(cs).allocations) =~ "reconciliation"
    assert {:error, _} = Rentals.checkout_rental(old)
    assert {:error, _} = Rentals.cancel_rental(old)
    assert {:error, _} = Rentals.return_rental(old, %{returns: []})
    assert Repo.aggregate(RentalAllocation, :count) == 0
    assert {:ok, _} = Rentals.update_rental_details(old, %{event_type: :birthday})
    assert stock(c.bulk, c.source) == 10
  end

  @tag :single
  test "booking constraints reject malformed inputs, wrong ownership, duplicate sources and single quantities",
       c do
    wrong = customer_location_fixture()

    bad = [
      nil,
      "bad",
      [],
      [%{}],
      [row(c.bulk, c.source, 0)],
      [row(c.bulk, c.source, -1)],
      [row(c.bulk, c.source, 2), row(c.bulk, c.source, 2)],
      [row(c.single, c.source, 2)],
      [row(c.bulk, wrong, 1)]
    ]

    for rows <- bad, do: assert({:error, _} = Rentals.create_rental(attrs(c, rows)))
    assert {:error, _} = Rentals.create_rental(%{})
    assert {:error, _} = Rentals.create_rental("bad")

    assert {:error, _} =
             Rentals.create_rental(
               Map.put(attrs(c, [row(c.bulk, c.source, 1)]), :destination_location_id, wrong.id)
             )

    assert {:error, _} =
             Rentals.create_rental(attrs(c, [row(c.bulk, c.source, 1)], time(0), time(0)))

    assert Repo.aggregate(Rental, :count) == 0
    assert Repo.aggregate(Location, :count) == 3
  end

  @tag :single
  test "stale inventory forms cannot undo checkout status or change type, but condition remains editable",
       c do
    old = c.single
    r = book!(c, [row(c.single, c.source, 1)])
    assert {:error, _} = Inventory.update_item_with_details(old, %{status: :damaged})
    {:ok, out} = Rentals.checkout_rental(r)

    assert {:error, _} =
             Inventory.update_item_with_details(old, %{
               status: :available,
               name: "Should roll back"
             })

    assert Repo.get!(SingleItem, old.id).status == :rented
    assert Inventory.get_item!(old.id).name == old.name
    assert {:error, _} = Inventory.update_item(old, %{item_type: :bulk})
    assert {:ok, changed} = Inventory.update_item_with_details(old, %{condition: "Inspected"})
    assert changed.single_item.status == :rented and changed.single_item.condition == "Inspected"
    assert {:error, _} = Inventory.delete_item(old)
    assert Rentals.get_rental(out.id).status == :active
  end

  test "overdue metadata edits remain possible without changing stock or schedule", c do
    r = book!(c, [row(c.bulk, c.source, 1)])
    {:ok, out} = Rentals.checkout_rental(r)
    Repo.get!(Rental, out.id) |> change(return_by: time(-1)) |> Repo.update!()
    out = Rentals.get_rental(out.id)
    assert {:ok, edited} = Rentals.update_rental_details(out, %{event_type: :birthday})
    assert edited.return_by == out.return_by and edited.event_type == :birthday
    assert stock(c.bulk, c.source) == 9
  end

  test "oversized IDs and aggregate quantities return validation errors without orphan rows", c do
    for field <- [:customer_id, :destination_location_id] do
      assert {:error, _} =
               Rentals.create_rental(
                 Map.put(attrs(c, [row(c.bulk, c.source, 1)]), field, "9223372036854775808")
               )
    end

    for source <- [c.source, c.other] do
      Repo.one!(
        from s in ItemsLocation, where: s.item_id == ^c.bulk.id and s.location_id == ^source.id
      )
      |> change(quantity: 1_500_000_000)
      |> Repo.update!()
    end

    assert {:error, cs} =
             Rentals.create_rental(
               attrs(c, [
                 row(c.bulk, c.source, 1_500_000_000),
                 row(c.bulk, c.other, 1_500_000_000)
               ])
             )

    assert hd(errors_on(cs).allocations) =~ "storage"
    assert Repo.aggregate(Rental, :count) == 0
    assert Repo.aggregate(Location, :count) == 2
    r = book!(c, [row(c.bulk, c.source, 10)])

    Repo.insert!(%ItemsLocation{
      item_id: c.bulk.id,
      location_id: r.destination_location_id,
      quantity: 2_147_483_647
    })

    assert {:error, _} = Rentals.checkout_rental(r)
    assert stock(c.bulk, c.source) == 1_500_000_000
    assert Repo.aggregate(LocationHistory, :count) == 0
  end

  @tag :single
  test "single reservations cannot overlap and managed query filters omit future cancellations",
       c do
    t = time(3600)
    r = book!(c, [row(c.single, c.source, 1)], t, DateTime.add(t, 3600))

    assert {:error, _} =
             Rentals.create_rental(
               attrs(c, [row(c.single, c.source, 1)], t, DateTime.add(t, 7200))
             )

    next = book!(c, [row(c.single, c.source, 1)], DateTime.add(t, 3600), DateTime.add(t, 7200))
    assert Enum.map(Rentals.list_upcoming_rentals(), & &1.id) == [r.id, next.id]
    {:ok, _} = Rentals.cancel_rental(r)
    assert Enum.map(Rentals.list_upcoming_rentals(), & &1.id) == [next.id]
    assert Rentals.list_active_rentals() == []
  end

  defp attrs(c, rows, pickup \\ time(-60), due \\ time(3600)),
    do: %{
      customer_id: c.customer.id,
      destination_name: "Test venue",
      rented_at: pickup,
      return_by: due,
      allocations: rows
    }

  defp book!(c, rows, pickup \\ time(-60), due \\ time(3600)) do
    {:ok, r} = Rentals.create_rental(attrs(c, rows, pickup, due))
    r
  end

  defp row(item, source, qty),
    do: %{item_id: item.id, source_location_id: source.id, quantity: qty}

  defp return_row(a, quantity), do: %{allocation_id: a.id, quantity: quantity}

  defp time(seconds),
    do: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(seconds)

  defp stock(item, source),
    do:
      Repo.one(
        from s in ItemsLocation,
          where: s.item_id == ^item.id and s.location_id == ^source.id,
          select: s.quantity
      ) || 0
end
