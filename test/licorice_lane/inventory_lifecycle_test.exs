defmodule LicoriceLane.InventoryLifecycleTest do
  use LicoriceLane.DataCase

  alias LicoriceLane.{Cache, Inventory}
  alias LicoriceLane.Items.{Item, SingleItem}
  alias LicoriceLane.Locations.ItemsLocation

  import LicoriceLane.ItemsFixtures
  import LicoriceLane.LocationsFixtures
  import LicoriceLane.RentalsFixtures

  @inventory_cache_keys [:inventory_items, :low_stock_items, :dashboard_stats]

  setup do
    warehouse = warehouse_fixture()
    Phoenix.PubSub.subscribe(LicoriceLane.PubSub, "inventory:updates")

    for key <- @inventory_cache_keys, do: Cache.put(key, :stale)

    on_exit(fn ->
      for key <- @inventory_cache_keys, do: Cachex.del(:admin_cache, key)
    end)

    %{warehouse: warehouse}
  end

  describe "create_item_with_location/1" do
    test "creates a single item with matching IDs, defaults, and preloaded location", %{
      warehouse: warehouse
    } do
      attrs =
        valid_single_item_attributes(%{location_id: warehouse.id, min_stock: 50})

      assert {:ok, item} = Inventory.create_item_with_location(attrs)
      assert item.single_item.id == item.id
      assert item.single_item.location.id == warehouse.id
      assert item.single_item.condition == "New"
      assert item.single_item.status == :available
      assert item.min_stock == 0
      assert item.items_locations == []
      assert Repo.get!(SingleItem, item.id).location_id == warehouse.id
      assert_inventory_updated(item.id)
    end

    test "accepts bulk form strings and supplies the context stock default", %{
      warehouse: warehouse
    } do
      attrs =
        valid_bulk_item_attributes()
        |> Map.delete(:min_stock)
        |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)
        |> Map.put("item_type", "bulk")
        |> Map.put("location_id", Integer.to_string(warehouse.id))
        |> Map.put("quantity", "25")

      assert {:ok, item} = Inventory.create_item_with_location(attrs)
      assert item.item_type == :bulk
      assert item.min_stock == 10
      assert item.single_item == nil
      assert [stock] = item.items_locations
      assert stock.item_id == item.id
      assert stock.location.id == warehouse.id
      assert stock.quantity == 25
      assert_inventory_updated(item.id)
    end

    test "preserves an explicit bulk stock threshold", %{warehouse: warehouse} do
      attrs =
        valid_bulk_item_attributes(%{
          location_id: warehouse.id,
          quantity: 30,
          min_stock: 50
        })

      assert {:ok, item} = Inventory.create_item_with_location(attrs)
      assert item.min_stock == 50
      assert_inventory_updated(item.id)
    end

    test "rejects invalid base item data without writes or update side effects", %{
      warehouse: warehouse
    } do
      attrs = valid_single_item_attributes(%{location_id: warehouse.id, name: nil})

      assert {:error, :item, changeset} = Inventory.create_item_with_location(attrs)
      assert "can't be blank" in errors_on(changeset).name
      assert Repo.aggregate(Item, :count) == 0
      assert Repo.aggregate(SingleItem, :count) == 0
      assert_inventory_unchanged()
    end

    test "rolls back the parent item if the single item changeset fails", %{
      warehouse: warehouse
    } do
      attrs = valid_single_item_attributes(%{location_id: warehouse.id, condition: ""})

      assert {:error, :location_data, changeset} = Inventory.create_item_with_location(attrs)
      assert "can't be blank" in errors_on(changeset).condition
      assert Repo.aggregate(Item, :count) == 0
      assert Repo.aggregate(SingleItem, :count) == 0
      assert_inventory_unchanged()
    end

    test "rejects missing, nonpositive, and fractional bulk quantities before writes", %{
      warehouse: warehouse
    } do
      for quantity <- [nil, 0, -1, "1.5"] do
        attrs = valid_bulk_item_attributes(%{location_id: warehouse.id, quantity: quantity})
        assert {:error, :validation, _reason} = Inventory.create_item_with_location(attrs)
      end

      assert Repo.aggregate(Item, :count) == 0
      assert Repo.aggregate(ItemsLocation, :count) == 0
      assert_inventory_unchanged()
    end

    test "rejects a location that no longer exists without creating an orphan", %{
      warehouse: warehouse
    } do
      Repo.delete!(warehouse)
      attrs = valid_single_item_attributes(%{location_id: warehouse.id})

      assert {:error, :validation, "location_id does not exist"} =
               Inventory.create_item_with_location(attrs)

      assert Repo.aggregate(Item, :count) == 0
      assert_inventory_unchanged()
    end
  end

  describe "update_item/2" do
    test "persists base fields and preserves single item tracking", %{warehouse: warehouse} do
      item = single_item_fixture(%{location: warehouse})

      assert {:ok, updated} =
               Inventory.update_item(item, %{name: "Updated item", min_stock: 40})

      assert updated.min_stock == 0
      assert Repo.get!(Item, item.id).name == "Updated item"
      assert Repo.get!(SingleItem, item.id).location_id == warehouse.id
      assert_inventory_updated(item.id)
    end

    test "invalid updates preserve persisted data and emit no update", %{warehouse: warehouse} do
      item = bulk_item_fixture(%{location: warehouse})

      assert {:error, changeset} = Inventory.update_item(item, %{min_stock: -1})
      assert "must be greater than or equal to 0" in errors_on(changeset).min_stock
      assert Repo.get!(Item, item.id).min_stock == item.min_stock
      assert_inventory_unchanged()
    end
  end

  describe "update_item_with_details/2" do
    test "commits image and single details together with update side effects", %{
      warehouse: warehouse
    } do
      item = single_item_fixture(%{location: warehouse})

      assert {:ok, updated} =
               Inventory.update_item_with_details(item, %{
                 "image_path" => "/uploads/new.png",
                 "condition" => "Excellent",
                 "status" => "damaged"
               })

      assert updated.image_path == "/uploads/new.png"
      assert updated.single_item.condition == "Excellent"
      assert updated.single_item.status == :damaged
      assert_inventory_updated(item.id)
    end

    test "invalid single details roll back the image and leave cache and subscribers unchanged",
         %{warehouse: warehouse} do
      item = single_item_fixture(%{location: warehouse})

      assert {:error, changeset} =
               Inventory.update_item_with_details(item, %{
                 image_path: "/uploads/new.png",
                 condition: ""
               })

      assert changeset.data.__struct__ == Item
      assert "can't be blank" in errors_on(changeset).condition
      assert Repo.get!(Item, item.id).image_path == item.image_path
      assert Repo.get!(SingleItem, item.id).condition == item.single_item.condition
      assert_inventory_unchanged()
    end

    test "base-only edits preserve single tracking details", %{warehouse: warehouse} do
      item = single_item_fixture(%{location: warehouse})
      assert {:ok, updated} = Inventory.update_item_with_details(item, %{name: "Edited"})
      assert updated.single_item.condition == item.single_item.condition
      assert updated.single_item.status == item.single_item.status
      assert updated.single_item.location_id == warehouse.id
      assert_inventory_updated(item.id)
    end
  end

  describe "delete_item/1" do
    test "deletes an unbooked single item and its tracking row", %{warehouse: warehouse} do
      item = single_item_fixture(%{location: warehouse})

      assert {:ok, deleted} = Inventory.delete_item(item)
      assert deleted.id == item.id
      assert Repo.get(Item, item.id) == nil
      assert Repo.get(SingleItem, item.id) == nil
      assert_inventory_updated(item.id)
    end

    test "deletes bulk stock at every location and preserves locations and other items", %{
      warehouse: warehouse
    } do
      item = bulk_item_fixture(%{location: warehouse})
      other_item = bulk_item_fixture(%{location: warehouse})
      customer_location = customer_location_fixture()

      Repo.insert!(%ItemsLocation{
        item_id: item.id,
        location_id: customer_location.id,
        quantity: 5
      })

      assert {:ok, deleted} = Inventory.delete_item(item)
      assert deleted.id == item.id
      assert Repo.get(Item, item.id) == nil
      assert Repo.all(from(il in ItemsLocation, where: il.item_id == ^item.id)) == []
      assert Repo.get!(Item, other_item.id)
      assert [%{quantity: 50}] = Inventory.get_warehouse_quantities(other_item.id)
      assert Repo.get!(LicoriceLane.Locations.Location, warehouse.id)
      assert Repo.get!(LicoriceLane.Locations.Location, customer_location.id)
      assert_inventory_updated(item.id)
    end

    test "rejects single items in bookings regardless of status and preserves tracking", %{
      warehouse: warehouse
    } do
      for status <- [:active, :late, :returned, :cancelled] do
        item = single_item_fixture(%{location: warehouse})
        rental = rental_with_single_items_fixture(%{single_item: item, status: status})
        # Customer fixtures invalidate dashboard data; measure only deletion side effects.
        for key <- @inventory_cache_keys, do: Cache.put(key, :stale)

        assert {:error, changeset} = Inventory.delete_item(item)
        assert "is used in a booking" in errors_on(changeset).id
        assert Repo.get!(Item, item.id)
        assert Repo.get!(SingleItem, item.id)

        assert Repo.get!(LicoriceLane.Rentals.RentalSingleItem, hd(rental.rental_single_items).id)
        assert_inventory_unchanged()
      end
    end

    test "rejects bulk items in bookings and rolls back stock deletion", %{warehouse: warehouse} do
      for status <- [:active, :late, :returned, :cancelled] do
        item = bulk_item_fixture(%{location: warehouse})
        rental = rental_with_bulk_items_fixture(%{bulk_item: item, status: status})
        for key <- @inventory_cache_keys, do: Cache.put(key, :stale)

        assert {:error, changeset} = Inventory.delete_item(item)
        assert "is used in a booking" in errors_on(changeset).id
        assert Repo.get!(Item, item.id)
        assert [%{quantity: 50}] = Inventory.get_warehouse_quantities(item.id)
        assert Repo.get!(LicoriceLane.Rentals.RentalBulkItem, hd(rental.rental_bulk_items).id)
        assert_inventory_unchanged()
      end
    end

    test "preserves location history and rolls back single tracking or bulk stock deletion", %{
      warehouse: warehouse
    } do
      items = [
        single_item_fixture(%{location: warehouse}),
        bulk_item_fixture(%{location: warehouse})
      ]

      for item <- items do
        history =
          Repo.insert!(%LicoriceLane.Locations.LocationHistory{
            item_id: item.id,
            quantity: 1,
            ts: DateTime.utc_now() |> DateTime.truncate(:second),
            to_location_id: warehouse.id
          })

        assert {:error, changeset} = Inventory.delete_item(item)
        assert "has movement history" in errors_on(changeset).id
        assert Repo.get!(Item, item.id)
        assert Repo.get!(LicoriceLane.Locations.LocationHistory, history.id)

        if item.item_type == :single do
          assert Repo.get!(SingleItem, item.id)
        else
          assert [%{quantity: 50}] = Inventory.get_warehouse_quantities(item.id)
        end

        assert_inventory_unchanged()
      end
    end

    test "returns an error for an already deleted item without repeating side effects", %{
      warehouse: warehouse
    } do
      item = bulk_item_fixture(%{location: warehouse})
      assert {:ok, _} = Inventory.delete_item(item)
      assert_inventory_updated(item.id)
      for key <- @inventory_cache_keys, do: Cache.put(key, :stale)

      assert {:error, changeset} = Inventory.delete_item(item)
      assert "has already been deleted" in errors_on(changeset).id
      assert_inventory_unchanged()
    end
  end

  describe "warehouse stock" do
    test "sums warehouses, excludes customer stock, and uses a strict low-stock threshold", %{
      warehouse: warehouse
    } do
      second_warehouse = warehouse_fixture()
      customer_location = customer_location_fixture()
      item = bulk_item_fixture(%{location: warehouse, quantity: 3, min_stock: 10})

      Repo.insert!(%ItemsLocation{
        item_id: item.id,
        location_id: second_warehouse.id,
        quantity: 4
      })

      Repo.insert!(%ItemsLocation{
        item_id: item.id,
        location_id: customer_location.id,
        quantity: 100
      })

      bulk_item_fixture(%{location: warehouse, quantity: 10, min_stock: 10})
      single_item_fixture(%{location: warehouse})

      assert [%{item: low_stock_item, warehouse_quantity: 7}] = Inventory.list_low_stock_items()
      assert low_stock_item.id == item.id

      stock = Inventory.get_warehouse_quantities(item.id)

      assert Enum.sort(Enum.map(stock, & &1.location_id)) ==
               Enum.sort([warehouse.id, second_warehouse.id])

      assert Enum.sum(Enum.map(stock, & &1.quantity)) == 7
    end

    test "reports a bulk item with no location rows as zero warehouse stock" do
      item =
        valid_bulk_item_attributes(%{min_stock: 10}) |> then(&struct(Item, &1)) |> Repo.insert!()

      assert [%{item: low_stock_item, warehouse_quantity: 0}] = Inventory.list_low_stock_items()
      assert low_stock_item.id == item.id
    end
  end

  defp assert_inventory_updated(item_id) do
    assert_receive {:inventory_updated, ^item_id}
    for key <- @inventory_cache_keys, do: assert(Cache.get(key) == nil)
  end

  defp assert_inventory_unchanged do
    refute_receive {:inventory_updated, _item_id}
    for key <- @inventory_cache_keys, do: assert(Cache.get(key) == :stale)
  end
end
