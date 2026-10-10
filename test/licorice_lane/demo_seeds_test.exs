Code.require_file("../../priv/repo/demo_seeds.exs", __DIR__)

defmodule LicoriceLane.DemoSeedsTest do
  use LicoriceLane.DataCase
  import LicoriceLane.AccountsFixtures
  alias LicoriceLane.{DemoSeeds, Rentals, Cache, Customers}
  alias LicoriceLane.Accounts.User
  alias LicoriceLane.Rentals.Rental
  alias LicoriceLane.Items.SingleItem
  alias LicoriceLane.Locations.{Location, ItemsLocation, LocationHistory}
  alias LicoriceLane.Messages.Message
  alias LicoriceLane.Customers.Customer

  setup do
    on_exit(fn -> Cache.clear() end)
    :ok
  end

  test "repeatable seed replacement preserves accounts and creates coherent managed lifecycle examples" do
    account = admin_user_fixture()
    first = DemoSeeds.run()
    first_ids = Enum.map(first.customers, & &1.id)
    sample = DemoSeeds.run()
    assert Repo.get!(User, account.id).admin
    refute Repo.exists?(from c in Customer, where: c.id in ^first_ids)
    assert Repo.aggregate(Customer, :count) == 6
    assert Repo.aggregate(Location, :count) == 8
    assert Repo.aggregate(SingleItem, :count) == 11
    assert Repo.aggregate(Rental, :count) == 6
    assert Repo.aggregate(Message, :count) == 3
    assert Enum.all?(Repo.all(Rental), & &1.inventory_managed)

    assert Enum.sort(Enum.map(Repo.all(Rental), & &1.status)) == [
             :active,
             :active,
             :cancelled,
             :late,
             :reserved,
             :returned
           ]

    r = sample.rentals
    assert r.reserved.checked_out_at == nil and r.cancelled.checked_out_at == nil
    assert r.partial.status == :active and r.partial.returned_at == nil
    assert Enum.any?(r.partial.allocations, &(&1.returned_quantity > 0))
    assert Enum.any?(r.partial.allocations, &(&1.returned_quantity < &1.quantity))
    assert Enum.all?(r.returned.allocations, &(&1.returned_quantity == &1.quantity))
    assert Enum.map(Rentals.list_overdue_rentals(), & &1.id) == [r.overdue.id]
    assert DateTime.compare(r.overdue.checked_out_at, r.overdue.return_by) == :lt
    assert DateTime.compare(r.returned.checked_out_at, r.returned.returned_at) == :lt
    assert DateTime.compare(r.returned.returned_at, r.returned.return_by) == :lt

    for rental <- Map.values(r) do
      assert rental.destination_location.customer_id == rental.customer_id

      if rental.checked_out_at do
        assert DateTime.compare(rental.checked_out_at, rental.event_date) != :gt
      end

      for a <- rental.allocations do
        assert a.source_location.location_type == :warehouse

        histories =
          Repo.all(
            from h in LocationHistory,
              where: h.rental_id == ^rental.id and h.item_id == ^a.item_id
          )

        for history <- histories do
          if history.to_location_id == rental.destination_location_id do
            assert history.ts == rental.checked_out_at
          else
            assert DateTime.compare(history.ts, rental.checked_out_at) != :lt
          end
        end

        checkout_quantity =
          histories
          |> Enum.filter(
            &(&1.from_location_id == a.source_location_id and
                &1.to_location_id == rental.destination_location_id)
          )
          |> Enum.map(& &1.quantity)
          |> Enum.sum()

        returned_quantity =
          histories
          |> Enum.filter(
            &(&1.from_location_id == rental.destination_location_id and
                &1.to_location_id == a.source_location_id)
          )
          |> Enum.map(& &1.quantity)
          |> Enum.sum()

        assert checkout_quantity == if(rental.checked_out_at, do: a.quantity, else: 0)
        assert returned_quantity == a.returned_quantity
      end
    end

    for {key, total} <- [napkins: 1200, plates: 800, glassware: 550, tablecloths: 160, candles: 8] do
      item = sample.items[key]

      assert Repo.one!(
               from s in ItemsLocation, where: s.item_id == ^item.id, select: sum(s.quantity)
             ) == total

      # Customer stock agrees with outstanding units across that destination's bookings.
      for row <-
            Repo.all(
              from s in ItemsLocation,
                join: l in Location,
                on: l.id == s.location_id,
                where: s.item_id == ^item.id and l.location_type == :customer,
                select: s
            ) do
        outstanding =
          Map.values(r)
          |> Enum.filter(
            &(&1.destination_location_id == row.location_id and &1.status in [:active, :late])
          )
          |> Enum.flat_map(& &1.allocations)
          |> Enum.filter(&(&1.item_id == item.id))
          |> Enum.map(&(&1.quantity - &1.returned_quantity))
          |> Enum.sum()

        assert row.quantity == outstanding
      end
    end

    for single <- Repo.all(SingleItem) do
      out =
        Map.values(r)
        |> Enum.filter(&(&1.status in [:active, :late]))
        |> Enum.find(fn rental ->
          Enum.any?(rental.allocations, &(&1.item_id == single.id and &1.returned_quantity == 0))
        end)

      if out do
        assert single.status == :rented and single.location_id == out.destination_location_id
      else
        assert single.status == :available
        assert Repo.get!(Location, single.location_id).location_type == :warehouse
      end
    end

    customer = hd(sample.customers)
    assert Enum.map(Customers.search_customers("customer1@example.com"), & &1.id) == [customer.id]
    assert customer.email_hash != nil and customer.phone_hash != nil
    # Seeded records can immediately use the workflow, without reconciliation.
    assert {:ok, _} = Rentals.cancel_rental(r.reserved)

    assert {:ok, done} =
             Rentals.return_rental(r.overdue, %{
               returns:
                 Enum.map(
                   r.overdue.allocations,
                   &%{allocation_id: &1.id, quantity: &1.quantity - &1.returned_quantity}
                 )
             })

    assert done.status == :returned
  end
end
