defmodule LicoriceLane.DemoSeeds do
  @moduledoc """
  Disposable sample data built through the application contexts. All stock and
  allocation counters come from real lifecycle operations. Historical examples
  adjust only their timeline after those operations to simulate elapsed time.
  Login accounts and tokens are preserved. Business replacement is transactional.
  """
  import Ecto.Query
  alias LicoriceLane.{Repo, Customers, Inventory, Rentals, Messages, Cache}
  alias LicoriceLane.Customers.Customer
  alias LicoriceLane.Items.{Item, SingleItem}
  alias LicoriceLane.Locations.{Location, ItemsLocation, LocationHistory}
  alias LicoriceLane.Rentals.{Rental, RentalAllocation, RentalSingleItem, RentalBulkItem}
  alias LicoriceLane.Messages.Message

  def run do
    {:ok, sample} =
      Repo.transaction(fn ->
        clear_business_data()
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        customers = create_customers()
        [c1, c2, c3, c4, c5, c6] = customers
        main = location!("Main Warehouse", :warehouse)
        north = location!("North Side Warehouse", :warehouse)

        venues =
          Map.new(customers, fn c ->
            {c.id, location!("#{c.name} - Event Venue", :customer, c.id)}
          end)

        items = create_items(main, north)

        reserved =
          book!(c1, venues[c1.id], now, 7, 10, :wedding, [
            allocation(items.arch2, north, 1),
            allocation(items.napkins, main, 80),
            allocation(items.napkins, north, 20),
            allocation(items.plates, main, 60)
          ])

        active =
          book!(c2, venues[c2.id], now, -1, 3, :birthday, [
            allocation(items.chair2, main, 1),
            allocation(items.arch1, main, 1),
            allocation(items.napkins, main, 100),
            allocation(items.tablecloths, main, 15),
            allocation(items.plates, main, 80)
          ])
          |> checkout!()
          |> checkout_timeline!(now, -1)

        partial =
          book!(c3, venues[c3.id], now, -2, 2, :wedding, [
            allocation(items.chandelier2, north, 1),
            allocation(items.napkins, north, 150),
            allocation(items.tablecloths, north, 20),
            allocation(items.glassware, north, 80)
          ])
          |> checkout!()
          |> checkout_timeline!(now, -2)

        {:ok, partial} =
          Rentals.return_rental(partial, %{
            returns: [
              returned(partial, items.napkins, 50),
              returned(partial, items.tablecloths, 5)
            ]
          })

        overdue =
          book!(c4, venues[c4.id], now, -4, 1, :corporate, [
            allocation(items.table2, main, 1),
            allocation(items.plates, main, 50),
            allocation(items.glassware, main, 50)
          ])
          |> checkout!()

        overdue = historical!(overdue, now, -4, -1)

        returned =
          book!(c5, venues[c5.id], now, -6, 1, :birthday, [
            allocation(items.chair4, main, 1),
            allocation(items.plates, north, 40),
            allocation(items.napkins, main, 60)
          ])
          |> checkout!()

        {:ok, returned} =
          Rentals.return_rental(returned, %{
            returns:
              Enum.map(returned.allocations, &%{allocation_id: &1.id, quantity: &1.quantity})
          })

        returned = historical!(returned, now, -6, -3, -4)

        cancelled =
          book!(c6, venues[c6.id], now, 14, 15, :corporate, [
            allocation(items.chair4, main, 1),
            allocation(items.napkins, north, 80)
          ])

        {:ok, cancelled} = Rentals.cancel_rental(cancelled)
        create_messages()

        %{
          customers: customers,
          items: items,
          warehouses: [main, north],
          rentals: %{
            reserved: reserved,
            active: active,
            partial: partial,
            overdue: overdue,
            returned: returned,
            cancelled: cancelled
          }
        }
      end)

    Cache.clear()
    sample
  end

  defp clear_business_data do
    Enum.each(
      [
        Message,
        LocationHistory,
        RentalSingleItem,
        RentalBulkItem,
        RentalAllocation,
        Rental,
        SingleItem,
        ItemsLocation,
        Item,
        Location,
        Customer
      ],
      &Repo.delete_all/1
    )
  end

  defp create_customers do
    [
      "Sunshine Events Co.",
      "Happy Party Planners",
      "Elite Weddings LLC",
      "Corporate Events Direct",
      "Birthday Bash Productions",
      "Gala Affairs"
    ]
    |> Enum.with_index(1)
    |> Enum.map(fn {name, n} ->
      {:ok, customer} =
        Customers.create_customer(%{
          name: name,
          email: "customer#{n}@example.com",
          phone: "555-010#{n}",
          contact_person: "Sample Coordinator #{n}",
          billing_address: "#{n} Sample Avenue",
          notes: "Fictional development customer"
        })

      customer
    end)
  end

  defp location!(name, type, customer_id \\ nil) do
    %Location{}
    |> Location.changeset(%{name: name, location_type: type, customer_id: customer_id})
    |> Repo.insert!()
  end

  defp create_items(main, north) do
    singles = [
      {:chair1, "Chiavari Chair - Gold #1", :tableware, "8.50", main},
      {:chair2, "Chiavari Chair - Gold #2", :tableware, "8.50", main},
      {:chair3, "Chiavari Chair - Gold #3", :tableware, "8.50", north},
      {:chair4, "Chiavari Chair - Gold #4", :tableware, "8.50", main},
      {:table1, "Round Table - 60 inch #1", :tableware, "15.00", main},
      {:table2, "Round Table - 60 inch #2", :tableware, "15.00", main},
      {:table3, "Round Table - 60 inch #3", :tableware, "15.00", north},
      {:chandelier1, "Crystal Chandelier #1", :electric_light, "125.00", main},
      {:chandelier2, "Crystal Chandelier #2", :electric_light, "125.00", north},
      {:arch1, "Wedding Arch - White #1", :tableware, "85.00", main},
      {:arch2, "Wedding Arch - White #2", :tableware, "85.00", north}
    ]

    items =
      Map.new(singles, fn {key, name, category, price, source} ->
        {key, item!(name, :single, category, price, source, %{condition: "Excellent"})}
      end)

    bulks = [
      {:napkins, "Linen Napkins - White", :linen, "1.25", 900, 300, 50},
      {:plates, "Dinner Plates - White Porcelain", :tableware, "2.00", 600, 200, 100},
      {:glassware, "Wine Glasses - Crystal", :tableware, "1.75", 400, 150, 75},
      {:tablecloths, "Tablecloths - Ivory", :linen, "8.00", 120, 40, 20}
    ]

    items =
      Enum.reduce(bulks, items, fn {key, name, category, price, main_qty, north_qty, min}, acc ->
        item = item!(name, :bulk, category, price, main, %{quantity: main_qty, min_stock: min})

        %ItemsLocation{}
        |> ItemsLocation.changeset(%{
          item_id: item.id,
          location_id: north.id,
          quantity: north_qty
        })
        |> Repo.insert!()

        Map.put(acc, key, item)
      end)

    Map.put(
      items,
      :candles,
      item!("LED Candles - Warm White", :bulk, :candle, "2.75", north, %{
        quantity: 8,
        min_stock: 10
      })
    )
  end

  defp item!(name, type, category, price, source, details) do
    attrs =
      Map.merge(
        %{
          name: name,
          description: "Sample event decor: #{name}",
          item_type: type,
          category: category,
          rental_price: Decimal.new(price),
          location_id: source.id,
          image_path: "images/placeholder.png"
        },
        details
      )

    {:ok, item} = Inventory.create_item_with_location(attrs)
    item
  end

  defp book!(customer, destination, now, pickup_day, due_day, type, allocations) do
    {:ok, rental} =
      Rentals.create_rental(%{
        customer_id: customer.id,
        destination_location_id: destination.id,
        rented_at: day(now, pickup_day),
        return_by: day(now, due_day),
        event_date: day(now, pickup_day + 1),
        event_type: type,
        allocations: allocations
      })

    rental
  end

  defp checkout!(rental) do
    {:ok, rental} = Rentals.checkout_rental(rental)
    rental
  end

  defp allocation(item, source, quantity),
    do: %{item_id: item.id, source_location_id: source.id, quantity: quantity}

  defp returned(rental, item, quantity),
    do: %{
      allocation_id: Enum.find(rental.allocations, &(&1.item_id == item.id)).id,
      quantity: quantity
    }

  defp day(now, days), do: DateTime.add(now, days, :day)

  # Context transitions run at the real clock. Only these historical fixture
  # timelines are shifted; allocation counters, stock and history endpoints stay
  # exactly as produced by checkout/return. Never use this in a runtime workflow.
  defp historical!(rental, now, pickup_day, due_day, returned_day \\ nil) do
    rental = checkout_timeline!(rental, now, pickup_day)
    returned = if returned_day, do: day(now, returned_day)

    rental
    |> Ecto.Changeset.change(%{
      return_by: day(now, due_day),
      returned_at: returned,
      status: if(returned, do: :returned, else: :late)
    })
    |> Repo.update!()

    if returned do
      Repo.update_all(
        from(h in LocationHistory,
          where:
            h.rental_id == ^rental.id and h.from_location_id == ^rental.destination_location_id
        ),
        set: [ts: returned]
      )
    end

    Rentals.get_rental(rental.id)
  end

  defp checkout_timeline!(rental, now, pickup_day) do
    checkout = day(now, pickup_day)
    rental |> Ecto.Changeset.change(checked_out_at: checkout) |> Repo.update!()

    Repo.update_all(
      from(h in LocationHistory,
        where: h.rental_id == ^rental.id and h.to_location_id == ^rental.destination_location_id
      ),
      set: [ts: checkout]
    )

    Rentals.get_rental(rental.id)
  end

  defp create_messages do
    for {status, n} <- Enum.with_index([:new, :read, :archived], 1) do
      {:ok, message} =
        Messages.create_message(%{
          name: "Sample Enquiry #{n}",
          email: "enquiry#{n}@example.com",
          phone: "555-020#{n}",
          message: "Fictional enquiry about event decor availability."
        })

      if status != :new do
        {:ok, _} = Messages.update_message_status(message, %{status: status})
      end
    end
  end
end
