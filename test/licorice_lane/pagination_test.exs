defmodule LicoriceLane.PaginationTest do
  use LicoriceLane.DataCase

  alias LicoriceLane.{Customers, Inventory, Messages, Rentals}
  alias LicoriceLane.Locations.ItemsLocation

  import LicoriceLane.CustomersFixtures
  import LicoriceLane.ItemsFixtures
  import LicoriceLane.LocationsFixtures
  import LicoriceLane.MessagesFixtures
  import LicoriceLane.RentalsFixtures

  test "inventory pages count items once, preserve preloads, and order equal names by ID" do
    items = for _ <- 1..3, do: bulk_item_fixture(%{name: "Matching candle", category: :candle})
    bulk_item_fixture(%{name: "Matching linen", category: :linen})

    Repo.insert!(%ItemsLocation{
      item_id: hd(items).id,
      location_id: warehouse_fixture().id,
      quantity: 2
    })

    expected = items |> Enum.map(& &1.id) |> Enum.sort()

    {first, 3} = Inventory.list_filtered_items_paginated("lighting", "Matching", page_size: 2)

    {last, 3} =
      Inventory.list_filtered_items_paginated("lighting", "Matching", page: 2, page_size: 2)

    assert Enum.map(first ++ last, & &1.id) == expected

    for item <- first ++ last do
      assert item.single_item == nil
      assert Ecto.assoc_loaded?(item.items_locations)
      assert Enum.all?(item.items_locations, &Ecto.assoc_loaded?(&1.location))
    end

    assert {last, 3} ==
             Inventory.list_filtered_items_paginated("lighting", "Matching",
               page: 99,
               page_size: 2
             )

    assert {[], 0} == Inventory.list_filtered_items_paginated("lighting", "missing", page: 99)
  end

  test "customer search deduplicates exact hash/name matches before paginating" do
    customer_fixture(%{name: "lookup@example.com", email: "lookup@example.com"})
    customer_fixture(%{name: "lookup@example.com"})
    customer_fixture(%{name: "Other", email: "other@example.com"})
    matches = Customers.search_customers("lookup@example.com") |> Enum.sort_by(& &1.id)

    {first, 2} = Customers.list_customers_paginated("lookup@example.com", page_size: 1)
    {last, 2} = Customers.list_customers_paginated("lookup@example.com", page: 99, page_size: 1)
    assert Enum.map(first ++ last, & &1.id) == Enum.map(matches, & &1.id)
    assert {[], 0} == Customers.list_customers_paginated("other@")
    assert {[_], 1} = Customers.list_customers_paginated("other@example.com")
    assert {all, 3} = Customers.list_customers_paginated("", page: 0, page_size: 0)
    assert length(all) == 3
  end

  test "messages combine status and name filters with stable pages for equal timestamps" do
    messages = for _ <- 1..3, do: message_fixture(%{name: "Matching sender"})
    message_fixture(%{name: "Matching sender", status: :read})
    message_fixture(%{name: "Other sender"})
    timestamp = ~U[2026-01-01 12:00:00Z]
    Enum.each(messages, &(&1 |> Ecto.Changeset.change(inserted_at: timestamp) |> Repo.update!()))
    expected = messages |> Enum.map(& &1.id) |> Enum.sort()
    opts = [status: :new, search_term: "Matching", page_size: 2]

    {first, 3} = Messages.list_messages_paginated(opts)
    {last, 3} = Messages.list_messages_paginated(Keyword.put(opts, :page, 99))
    assert Enum.map(first ++ last, & &1.id) == expected
    assert {[], 0} == Messages.list_messages_paginated(status: :archived, page: 99)
  end

  test "rental pages retain status rules, preload associations, and use stable ordering" do
    customer = customer_fixture()
    timestamp = ~U[2026-01-01 12:00:00Z]
    rentals = for _ <- 1..3, do: rental_fixture(%{customer: customer, rented_at: timestamp})
    rental_fixture(%{customer: customer, rented_at: timestamp, status: :returned})
    expected = rentals |> Enum.map(& &1.id) |> Enum.sort()

    {first, 3} = Rentals.list_rentals_paginated("active", page_size: 2)
    {last, 3} = Rentals.list_rentals_paginated("active", page: 99, page_size: 2)
    assert Enum.map(first ++ last, & &1.id) == expected

    for rental <- first ++ last do
      assert rental.customer.id == customer.id
      assert Ecto.assoc_loaded?(rental.rental_bulk_items)
      assert Ecto.assoc_loaded?(rental.rental_single_items)
    end

    assert {[], 0} == Rentals.list_rentals_paginated("cancelled", page: 99)
    assert {[_], 1} = Rentals.list_rentals_paginated("returned")
  end

  test "overdue and upcoming pagination match existing rental queries" do
    customer = customer_fixture()
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    attrs = %{
      customer: customer,
      rented_at: DateTime.add(now, -7, :day),
      return_by: DateTime.add(now, -1, :day)
    }

    active = rental_fixture(attrs)
    late = rental_fixture(Map.put(attrs, :status, :late))
    rental_fixture(Map.merge(attrs, %{status: :returned, returned_at: now}))
    rental_fixture(Map.put(attrs, :status, :cancelled))
    future = rental_fixture(%{customer: customer, rented_at: DateTime.add(now, 2, :day)})

    {overdue, 2} = Rentals.list_rentals_paginated("late")
    assert Enum.sort(Enum.map(overdue, & &1.id)) == Enum.sort([active.id, late.id])
    assert {[upcoming], 1} = Rentals.list_rentals_paginated("upcoming")
    assert upcoming.id == future.id
  end

  test "invalid page inputs fall back safely across contexts" do
    single_item_fixture()
    customer_fixture()
    message_fixture()
    rental_fixture()

    queries = [
      &Inventory.list_filtered_items_paginated("all", "", &1),
      &Customers.list_customers_paginated("", &1),
      &Messages.list_messages_paginated/1,
      &Rentals.list_rentals_paginated("all", &1)
    ]

    for query <- queries do
      expected = query.([])

      for page <- [0, -1, "invalid", "2oops", nil] do
        assert query.(page: page, page_size: 0) == expected
      end
    end
  end
end
