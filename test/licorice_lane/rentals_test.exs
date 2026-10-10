defmodule LicoriceLane.RentalsTest do
  use LicoriceLane.DataCase

  alias LicoriceLane.Rentals

  import LicoriceLane.RentalsFixtures
  import LicoriceLane.CustomersFixtures

  describe "list_rentals_paginated/2 with event date filter" do
    test "includes the whole UTC event day, independently of pickup date" do
      customer = customer_fixture()
      attrs = %{customer: customer, rented_at: ~U[2026-10-08 12:00:00Z]}
      start = rental_fixture(Map.put(attrs, :event_date, ~U[2026-10-09 00:00:00Z]))
      finish = rental_fixture(Map.put(attrs, :event_date, ~U[2026-10-09 23:59:59Z]))
      rental_fixture(Map.put(attrs, :event_date, ~U[2026-10-08 23:59:59Z]))
      rental_fixture(Map.put(attrs, :event_date, ~U[2026-10-10 00:00:00Z]))
      rental_fixture(Map.put(attrs, :event_date, nil))

      rental_fixture(%{
        customer: customer,
        rented_at: ~U[2026-10-09 12:00:00Z],
        event_date: ~U[2026-10-10 12:00:00Z]
      })

      {rentals, count} = Rentals.list_rentals_paginated("all", date_filter: "2026-10-09")
      assert count == 2
      assert Enum.map(rentals, & &1.id) == [start.id, finish.id]
      assert Enum.all?(rentals, &Ecto.assoc_loaded?(&1.customer))
      assert Enum.all?(rentals, &Ecto.assoc_loaded?(&1.rental_single_items))
      assert Enum.all?(rentals, &Ecto.assoc_loaded?(&1.rental_bulk_items))
    end

    test "combines event date with every existing status filter" do
      customer = customer_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      attrs = %{
        customer: customer,
        event_date: ~U[2026-10-09 12:00:00Z],
        rented_at: DateTime.add(now, -7, :day),
        return_by: DateTime.add(now, -1, :day)
      }

      active = rental_fixture(attrs)
      late = rental_fixture(Map.put(attrs, :status, :late))
      returned = rental_fixture(Map.merge(attrs, %{status: :returned, returned_at: now}))
      cancelled = rental_fixture(Map.put(attrs, :status, :cancelled))

      upcoming =
        rental_fixture(
          Map.merge(attrs, %{
            rented_at: DateTime.add(now, 2, :day),
            return_by: DateTime.add(now, 7, :day)
          })
        )

      rental_fixture(Map.put(attrs, :event_date, ~U[2026-10-10 12:00:00Z]))

      for {status, expected} <- [
            {"all", [active, late, returned, cancelled, upcoming]},
            {"active", [active, upcoming]},
            {"late", [active, late]},
            {"returned", [returned]},
            {"cancelled", [cancelled]},
            {"upcoming", [upcoming]}
          ] do
        {rentals, count} = Rentals.list_rentals_paginated(status, date_filter: ~D[2026-10-09])
        assert count == length(expected)
        assert Enum.sort(Enum.map(rentals, & &1.id)) == Enum.sort(Enum.map(expected, & &1.id))
      end
    end

    test "counts only matching events and preserves stable page boundaries" do
      customer = customer_fixture()

      attrs = %{
        customer: customer,
        event_date: ~U[2026-10-09 12:00:00Z],
        rented_at: ~U[2026-10-08 12:00:00Z]
      }

      matching = for _ <- 1..3, do: rental_fixture(attrs)
      rental_fixture(Map.put(attrs, :event_date, ~U[2026-10-10 12:00:00Z]))
      opts = [date_filter: "2026-10-09", page_size: 2]

      {first, first_count} = Rentals.list_rentals_paginated("all", opts)
      {last, last_count} = Rentals.list_rentals_paginated("all", Keyword.put(opts, :page, 99))
      assert first_count == 3
      assert last_count == 3
      assert Enum.map(first ++ last, & &1.id) == Enum.map(matching, & &1.id)
      assert {[], 0} == Rentals.list_rentals_paginated("all", date_filter: "2026-10-11", page: 99)
    end

    test "blank and invalid dates leave the status filter intact" do
      rental_fixture(%{status: :returned, event_date: nil})
      rental_fixture(%{status: :active})
      expected = Rentals.list_rentals_paginated("returned")

      for date <- [nil, "", "invalid", "2026-02-30", "2026-10-09oops", 123, %{}, []] do
        assert Rentals.list_rentals_paginated("returned", date_filter: date) == expected
      end
    end
  end

  describe "list_rentals/0" do
    test "returns all rentals ordered by rented_at descending" do
      old_rental = rental_fixture(%{rented_at: DateTime.add(DateTime.utc_now(), -7, :day)})
      recent_rental = rental_fixture(%{rented_at: DateTime.add(DateTime.utc_now(), -1, :day)})
      newest_rental = rental_fixture(%{rented_at: DateTime.utc_now()})

      rentals = Rentals.list_rentals()
      rental_ids = Enum.map(rentals, & &1.id)

      assert rental_ids == [newest_rental.id, recent_rental.id, old_rental.id]

      assert Enum.all?(rentals, fn rental ->
               Enum.all?(
                 [rental.customer, rental.rental_single_items, rental.rental_bulk_items],
                 &Ecto.assoc_loaded?/1
               )
             end)
    end

    test "returns empty list when no rentals exist" do
      assert Rentals.list_rentals() == []
    end
  end

  describe "list_recent_rentals/1" do
    test "returns limited number of recent rentals" do
      now = DateTime.utc_now()
      rentals = for i <- 1..10, do: rental_fixture(%{rented_at: DateTime.add(now, -i, :hour)})

      assert Enum.map(Rentals.list_recent_rentals(), & &1.id) ==
               Enum.map(Enum.take(rentals, 5), & &1.id)

      for limit <- [0, 3, 8, 20] do
        assert Enum.map(Rentals.list_recent_rentals(limit), & &1.id) ==
                 Enum.map(Enum.take(rentals, limit), & &1.id)
      end
    end
  end

  describe "list_rentals_by_status/1" do
    test "returns only rentals with the specified status" do
      active_rental = rental_fixture(%{status: :active})
      returned_rental = rental_fixture(%{status: :returned})
      _cancelled_rental = rental_fixture(%{status: :cancelled})

      active_results = Rentals.list_rentals_by_status(:active)
      assert length(active_results) == 1
      assert hd(active_results).id == active_rental.id

      returned_results = Rentals.list_rentals_by_status(:returned)
      assert length(returned_results) == 1
      assert hd(returned_results).id == returned_rental.id
    end

    test "returns empty list when no rentals have the status" do
      rental_fixture(%{status: :active})

      assert Rentals.list_rentals_by_status(:late) == []
    end
  end

  describe "list_upcoming_rentals/0" do
    test "returns only rentals with future rented_at dates" do
      # Past rental
      _past_rental = rental_fixture(%{rented_at: DateTime.add(DateTime.utc_now(), -1, :day)})

      # Future rentals
      future1 = rental_fixture(%{rented_at: DateTime.add(DateTime.utc_now(), 1, :day)})
      future2 = rental_fixture(%{rented_at: DateTime.add(DateTime.utc_now(), 3, :day)})

      upcoming = Rentals.list_upcoming_rentals()
      upcoming_ids = Enum.map(upcoming, & &1.id)

      assert length(upcoming) == 2
      # Should be in ascending order (soonest first)
      assert upcoming_ids == [future1.id, future2.id]
    end
  end

  describe "list_active_rentals/0" do
    test "returns only rentals with active status" do
      active1 = rental_fixture(%{status: :active})
      active2 = rental_fixture(%{status: :active})
      _returned = rental_fixture(%{status: :returned})

      active_rentals = Rentals.list_active_rentals()
      active_ids = Enum.map(active_rentals, & &1.id) |> Enum.sort()

      assert length(active_rentals) == 2
      assert Enum.sort([active1.id, active2.id]) == active_ids
    end
  end

  describe "list_overdue_rentals/0" do
    test "returns rentals past their return_by date that are not returned" do
      now = DateTime.utc_now()

      # Overdue and not returned
      overdue =
        rental_fixture(%{
          return_by: DateTime.add(now, -2, :day),
          returned_at: nil,
          status: :active
        })

      late = rental_fixture(%{return_by: DateTime.add(now, -1, :day), status: :late})

      for status <- [:reserved, :cancelled] do
        rental_fixture(%{return_by: DateTime.add(now, -3, :day), status: status})
      end

      # Overdue but returned
      _returned =
        rental_fixture(%{
          return_by: DateTime.add(now, -1, :day),
          returned_at: DateTime.add(now, -1, :hour),
          status: :returned
        })

      # Not overdue
      _future =
        rental_fixture(%{
          return_by: DateTime.add(now, 3, :day),
          returned_at: nil,
          status: :active
        })

      overdue_rentals = Rentals.list_overdue_rentals()

      assert Enum.map(overdue_rentals, & &1.id) == [overdue.id, late.id]
    end
  end

  describe "list_upcoming_this_week/0" do
    test "returns rentals within the next 7 days" do
      now = DateTime.utc_now()

      # Within the week
      this_week = rental_fixture(%{rented_at: DateTime.add(now, 3, :day)})

      # More than a week away
      _next_month = rental_fixture(%{rented_at: DateTime.add(now, 10, :day)})

      # In the past
      _past = rental_fixture(%{rented_at: DateTime.add(now, -1, :day)})

      upcoming = Rentals.list_upcoming_this_week()

      assert length(upcoming) == 1
      assert hd(upcoming).id == this_week.id
    end
  end

  describe "get_rental/1" do
    test "returns nil when rental does not exist" do
      assert Rentals.get_rental(999_999) == nil
    end
  end

  describe "search_rentals/1" do
    test "finds customer names case-insensitively and excludes unrelated rentals" do
      customer = customer_fixture(%{name: "Sunshine Events"})
      rental = rental_fixture(%{customer: customer})
      _other_rental = rental_fixture()

      for query <- ["Sunshine", "sunshine", "sUnShInE"] do
        assert Enum.map(Rentals.search_rentals(query), & &1.id) == [rental.id]
      end

      assert Rentals.search_rentals("nonexistent") == []
    end

    test "finds rentals by rental ID" do
      rental = rental_fixture()
      _other_rental = rental_fixture()

      results = Rentals.search_rentals(to_string(rental.id))

      assert length(results) == 1
      assert hd(results).id == rental.id
    end
  end
end
