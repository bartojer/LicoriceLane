defmodule LicoriceLane.RentalDetailsTest do
  use LicoriceLane.DataCase

  import LicoriceLane.RentalsFixtures
  import LicoriceLane.ItemsFixtures
  import LicoriceLane.CustomersFixtures

  alias LicoriceLane.{Cache, Inventory, Rentals}
  alias LicoriceLane.Items.SingleItem
  alias LicoriceLane.Locations.{ItemsLocation, LocationHistory}
  alias LicoriceLane.Rentals.{Rental, RentalBulkItem, RentalSingleItem}

  setup do
    Cache.clear()
    on_exit(fn -> Cache.clear() end)
    :ok
  end

  defp booking(attrs \\ %{}) do
    rental_fixture(
      Map.merge(
        %{
          rented_at: ~U[2026-11-01 10:00:13Z],
          return_by: ~U[2026-11-03 18:00:27Z],
          event_date: ~U[2026-11-02 12:00:41Z]
        },
        attrs
      )
    )
  end

  test "details preload item names, quantities and current single-item locations" do
    single = single_item_fixture()
    bulk = bulk_item_fixture()
    rental = rental_with_single_items_fixture(%{single_item: single})
    Repo.insert!(%RentalBulkItem{rental_id: rental.id, item_id: bulk.id, quantity: 7})
    details = Rentals.get_rental(rental.id)
    assert details.id == rental.id
    assert details.customer.id == rental.customer_id
    assert length(details.rental_single_items) == 1
    assert length(details.rental_bulk_items) == 1
    assert hd(details.rental_single_items).single_item.item.name == single.name

    assert hd(details.rental_single_items).single_item.location.id ==
             single.single_item.location_id

    assert hd(details.rental_bulk_items).item.name == bulk.name
    assert hd(details.rental_bulk_items).quantity == 7
  end

  test "validates edits without persistence and casts explicit offsets to UTC" do
    rental = booking()
    attrs = %{event_type: "corporate", event_date: "2026-11-02T09:00:41-06:00"}
    changeset = Rentals.change_rental_details(rental, attrs)
    assert changeset.valid?
    assert get_change(changeset, :event_date) == ~U[2026-11-02 15:00:41Z]
    assert Rentals.get_rental(rental.id).event_type == :wedding
    assert {:ok, updated} = Rentals.update_rental_details(rental, attrs)
    assert updated.event_type == :corporate
    assert updated.event_date == ~U[2026-11-02 15:00:41Z]
    assert Ecto.assoc_loaded?(updated.customer)
  end

  test "accepts unzoned datetime-local values as UTC and clears optional event fields" do
    rental = booking()

    assert {:ok, updated} =
             Rentals.update_rental_details(rental, %{
               rented_at: "2026-11-01T11:01:13",
               return_by: "2026-11-03T19:02:27",
               event_date: "",
               event_type: ""
             })

    assert updated.rented_at == ~U[2026-11-01 11:01:13Z]
    assert updated.return_by == ~U[2026-11-03 19:02:27Z]
    assert updated.event_date == nil
    assert updated.event_type == nil
  end

  test "rejects missing pickup/due dates, invalid types and reversed schedules without writes" do
    rental = booking()

    for attrs <- [
          %{rented_at: ""},
          %{return_by: ""},
          %{event_type: "unknown"},
          %{event_date: "invalid"},
          %{rented_at: "invalid"},
          %{return_by: "2026-10-31T12:00:00"}
        ] do
      assert {:error, changeset} = Rentals.update_rental_details(rental, attrs)
      refute changeset.valid?
      assert Rentals.get_rental(rental.id).return_by == rental.return_by
      assert Rentals.get_rental(rental.id).rented_at == rental.rented_at
    end
  end

  test "pickup cannot be moved after a recorded actual return" do
    rental = booking(%{status: :returned, returned_at: ~U[2026-11-03 17:00:00Z]})

    assert {:error, changeset} =
             Rentals.update_rental_details(rental, %{
               rented_at: ~U[2026-11-04 10:00:00Z],
               return_by: ~U[2026-11-05 10:00:00Z]
             })

    assert "cannot be after the actual return" in errors_on(changeset).rented_at
    assert Rentals.get_rental(rental.id).returned_at == rental.returned_at
  end

  test "schedule writes preserve lifecycle, customer, allocations, stock and movement history" do
    single = single_item_fixture(%{status: :rented})
    bulk = bulk_item_fixture(%{quantity: 40})
    rental = rental_with_single_items_fixture(%{single_item: single})
    Repo.insert!(%RentalBulkItem{rental_id: rental.id, item_id: bulk.id, quantity: 7})

    Repo.insert!(%LocationHistory{
      item_id: single.id,
      rental_id: rental.id,
      quantity: 1,
      ts: rental.rented_at
    })

    other = customer_fixture()
    before = stock_snapshot(single.id, bulk.id, rental.id)

    assert {:ok, updated} =
             Rentals.update_rental_details(rental, %{
               event_type: :birthday,
               status: :returned,
               returned_at: DateTime.utc_now(),
               customer_id: other.id,
               rental_single_items: [],
               rental_bulk_items: []
             })

    assert updated.status == rental.status
    assert updated.returned_at == rental.returned_at
    assert updated.customer_id == rental.customer_id
    assert updated.event_type == :birthday
    assert stock_snapshot(single.id, bulk.id, rental.id) == before
    assert Inventory.get_item(single.id).single_item.status == :rented
  end

  test "rejects an outdated schedule snapshot and retains the winner's changes" do
    rental = booking()
    assert {:ok, updated} = Rentals.update_rental_details(rental, %{event_type: :corporate})

    assert {:error, changeset} =
             Rentals.update_rental_details(rental, %{event_date: ~U[2026-11-02 14:00:00Z]})

    assert "has changed; close and reopen this booking" in errors_on(changeset).id
    current = Rentals.get_rental(rental.id)
    assert current.event_type == updated.event_type
    assert current.event_date == rental.event_date
  end

  test "uses current lifecycle values while validating a schedule" do
    rental = booking()
    rental |> change(status: :returned, returned_at: ~U[2026-11-02 17:00:00Z]) |> Repo.update!()

    assert {:error, changeset} =
             Rentals.update_rental_details(rental, %{rented_at: ~U[2026-11-03 10:00:00Z]})

    assert "cannot be after the actual return" in errors_on(changeset).rented_at
    assert Rentals.get_rental(rental.id).status == :returned
    assert {:ok, updated} = Rentals.update_rental_details(rental, %{event_type: :birthday})
    assert updated.status == :returned
    assert updated.returned_at == ~U[2026-11-02 17:00:00Z]
  end

  test "deleted bookings return an error changeset" do
    rental = booking()
    Repo.delete!(rental)
    assert {:error, changeset} = Rentals.update_rental_details(rental, %{event_type: :birthday})
    assert "is no longer available" in errors_on(changeset).id
    assert Rentals.get_rental(rental.id) == nil
  end

  test "only committed writes invalidate rental cache and broadcast rental updates" do
    rental = booking()
    Phoenix.PubSub.subscribe(LicoriceLane.PubSub, "rentals:updates")
    Phoenix.PubSub.subscribe(LicoriceLane.PubSub, "inventory:updates")
    Cache.put(:rentals, :cached)
    Cache.put(:dashboard_stats, :cached)
    Cache.put(:inventory_items, :preserved)
    assert {:error, _} = Rentals.update_rental_details(rental, %{return_by: ""})
    assert Cache.get(:rentals) == :cached
    assert Cache.get(:dashboard_stats) == :cached
    refute_received {:rental_updated, _}
    assert {:ok, _} = Rentals.update_rental_details(rental, %{event_type: :corporate})
    assert Cache.get(:rentals) == nil
    assert Cache.get(:dashboard_stats) == nil
    assert Cache.get(:inventory_items) == :preserved
    assert_received {:rental_updated, id}
    assert id == rental.id
    refute_received {:inventory_updated, _}
  end

  test "stale and deleted writes preserve cache entries and emit no broadcasts" do
    rental = booking()
    assert {:ok, _} = Rentals.update_rental_details(rental, %{event_type: :corporate})
    Phoenix.PubSub.subscribe(LicoriceLane.PubSub, "rentals:updates")
    Cache.put(:rentals, :cached)
    Cache.put(:dashboard_stats, :cached)
    assert {:error, _} = Rentals.update_rental_details(rental, %{event_type: :birthday})
    Repo.delete!(Repo.get!(Rental, rental.id))
    assert {:error, _} = Rentals.update_rental_details(rental, %{event_type: :birthday})
    assert Cache.get(:rentals) == :cached
    assert Cache.get(:dashboard_stats) == :cached
    refute_received {:rental_updated, _}
  end

  defp stock_snapshot(single_id, bulk_id, rental_id) do
    {
      Repo.get!(SingleItem, single_id),
      Repo.all(from row in ItemsLocation, where: row.item_id == ^bulk_id, order_by: row.id),
      Repo.all(from row in LocationHistory, where: row.rental_id == ^rental_id, order_by: row.id),
      Repo.all(
        from row in RentalSingleItem, where: row.rental_id == ^rental_id, order_by: row.id
      ),
      Repo.all(from row in RentalBulkItem, where: row.rental_id == ^rental_id, order_by: row.id)
    }
  end
end
