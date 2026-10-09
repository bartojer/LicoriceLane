defmodule LicoriceLane.InventoryTest do
  use LicoriceLane.DataCase

  alias LicoriceLane.Inventory

  import LicoriceLane.ItemsFixtures
  import LicoriceLane.LocationsFixtures

  describe "normalize_category_filter/1" do
    test "returns :all for 'all' string" do
      assert Inventory.normalize_category_filter("all") == :all
    end

    test "returns :all for :all atom" do
      assert Inventory.normalize_category_filter(:all) == :all
    end

    test "expands 'lighting' to candle and electric_light categories" do
      assert Inventory.normalize_category_filter("lighting") == [:candle, :electric_light]
      assert Inventory.normalize_category_filter(:lighting) == [:candle, :electric_light]
    end

    test "converts single category string to list" do
      assert Inventory.normalize_category_filter("tableware") == [:tableware]
    end

    test "converts single category atom to list" do
      assert Inventory.normalize_category_filter(:linen) == [:linen]
    end

    test "preserves list of category atoms" do
      assert Inventory.normalize_category_filter([:candle, :tableware]) == [:candle, :tableware]
    end

    test "converts list of strings to atoms" do
      assert Inventory.normalize_category_filter(["candle", "linen"]) == [:candle, :linen]
    end

    @tag :capture_log
    test "returns empty list for empty list" do
      assert Inventory.normalize_category_filter([]) == []
    end
  end

  describe "list_items/0" do
    test "returns all items with preloaded associations" do
      item1 = single_item_fixture()
      item2 = bulk_item_fixture()

      items = Inventory.list_items()
      item_ids = Enum.map(items, & &1.id) |> Enum.sort()

      assert length(items) == 2
      assert Enum.sort([item1.id, item2.id]) == item_ids

      # Check associations are preloaded
      first_item = hd(items)
      assert Ecto.assoc_loaded?(first_item.items_locations)
    end

    test "returns empty list when no items exist" do
      assert Inventory.list_items() == []
    end
  end

  describe "filter_by_categories/2" do
    setup do
      candle = single_item_fixture(%{category: :candle})
      tableware = single_item_fixture(%{category: :tableware})
      linen = bulk_item_fixture(%{category: :linen})

      %{candle: candle, tableware: tableware, linen: linen}
    end

    test "returns all items when categories is :all", %{candle: c, tableware: t, linen: l} do
      query = Inventory.build_items_query()
      result = Inventory.filter_by_categories(query, :all) |> Repo.all()
      result_ids = Enum.map(result, & &1.id) |> Enum.sort()

      assert length(result) == 3
      assert Enum.sort([c.id, t.id, l.id]) == result_ids
    end

    test "returns all items when categories is empty list", %{candle: c, tableware: t, linen: l} do
      query = Inventory.build_items_query()
      result = Inventory.filter_by_categories(query, []) |> Repo.all()

      assert length(result) == 3
      assert Enum.sort(Enum.map(result, & &1.id)) == Enum.sort([c.id, t.id, l.id])
    end

    test "filters by single category", %{candle: candle} do
      query = Inventory.build_items_query()
      result = Inventory.filter_by_categories(query, [:candle]) |> Repo.all()

      assert length(result) == 1
      assert hd(result).id == candle.id
    end

    test "filters by multiple categories", %{candle: candle, linen: linen} do
      query = Inventory.build_items_query()
      result = Inventory.filter_by_categories(query, [:candle, :linen]) |> Repo.all()
      result_ids = Enum.map(result, & &1.id) |> Enum.sort()

      assert length(result) == 2
      assert Enum.sort([candle.id, linen.id]) == result_ids
    end
  end

  describe "filter_by_search_term/2" do
    setup do
      item1 =
        single_item_fixture(%{
          name: "Gold Chiavari Chair",
          description: "Elegant wedding seating"
        })

      item2 =
        bulk_item_fixture(%{name: "White Tablecloth", description: "Premium linen for events"})

      item3 =
        single_item_fixture(%{
          name: "Crystal Chandelier",
          description: "Sparkling gold accent piece"
        })

      %{chair: item1, tablecloth: item2, chandelier: item3}
    end

    test "returns all items for empty string" do
      query = Inventory.build_items_query()
      result = Inventory.filter_by_search_term(query, "") |> Repo.all()

      assert length(result) == 3
    end

    test "returns all items for whitespace-only string" do
      query = Inventory.build_items_query()
      result = Inventory.filter_by_search_term(query, "   ") |> Repo.all()

      assert length(result) == 3
    end

    test "filters by single term in name", %{chair: chair} do
      query = Inventory.build_items_query()
      result = Inventory.filter_by_search_term(query, "Chair") |> Repo.all()

      assert length(result) == 1
      assert hd(result).id == chair.id
    end

    test "filters by single term in description", %{tablecloth: tablecloth} do
      query = Inventory.build_items_query()
      result = Inventory.filter_by_search_term(query, "linen") |> Repo.all()

      assert length(result) == 1
      assert hd(result).id == tablecloth.id
    end

    test "filters by multiple terms with AND logic", %{chair: chair} do
      query = Inventory.build_items_query()
      result = Inventory.filter_by_search_term(query, "gold elegant") |> Repo.all()

      # Only chair has both "gold" AND "elegant"
      assert length(result) == 1
      assert hd(result).id == chair.id
    end

    test "search is case-insensitive", %{tablecloth: tablecloth} do
      query = Inventory.build_items_query()
      result = Inventory.filter_by_search_term(query, "WHITE") |> Repo.all()

      assert length(result) == 1
      assert hd(result).id == tablecloth.id
    end

    test "returns empty list when no matches" do
      query = Inventory.build_items_query()
      result = Inventory.filter_by_search_term(query, "nonexistent") |> Repo.all()

      assert result == []
    end
  end

  describe "list_items_by_categories/1" do
    test "returns items in specified categories" do
      candle = single_item_fixture(%{category: :candle})
      _tableware = single_item_fixture(%{category: :tableware})

      results = Inventory.list_items_by_categories([:candle])

      assert length(results) == 1
      assert hd(results).id == candle.id
    end

    test "handles 'lighting' expansion" do
      candle = single_item_fixture(%{category: :candle})
      electric = single_item_fixture(%{category: :electric_light})
      _tableware = single_item_fixture(%{category: :tableware})

      results = Inventory.list_items_by_categories("lighting")
      result_ids = Enum.map(results, & &1.id) |> Enum.sort()

      assert length(results) == 2
      assert Enum.sort([candle.id, electric.id]) == result_ids
    end
  end

  describe "list_filtered_items/2" do
    setup do
      candle1 =
        single_item_fixture(%{
          category: :candle,
          name: "Gold Taper Candle",
          description: "Elegant tall candle"
        })

      candle2 =
        single_item_fixture(%{
          category: :candle,
          name: "Silver Pillar Candle",
          description: "Modern design"
        })

      table =
        single_item_fixture(%{
          category: :tableware,
          name: "Gold Charger Plate",
          description: "Elegant dining accent"
        })

      %{candle1: candle1, candle2: candle2, table: table}
    end

    test "filters by category only", %{candle1: c1, candle2: c2} do
      results = Inventory.list_filtered_items([:candle], "")
      result_ids = Enum.map(results, & &1.id) |> Enum.sort()

      assert length(results) == 2
      assert Enum.sort([c1.id, c2.id]) == result_ids
    end

    test "filters by search term only", %{candle1: candle1, table: table} do
      results = Inventory.list_filtered_items("all", "gold")
      result_ids = Enum.map(results, & &1.id) |> Enum.sort()

      assert length(results) == 2
      assert Enum.sort([candle1.id, table.id]) == result_ids
    end

    test "filters by both category and search term", %{candle1: candle1} do
      results = Inventory.list_filtered_items([:candle], "gold")

      assert length(results) == 1
      assert hd(results).id == candle1.id
    end

    test "returns all items with no filters" do
      results = Inventory.list_filtered_items("all", "")

      assert length(results) == 3
    end
  end

  describe "single vs bulk items" do
    test "single items have single_item association" do
      single = single_item_fixture()

      items = Inventory.list_items()
      item = Enum.find(items, &(&1.id == single.id))

      assert item.item_type == :single
      assert Ecto.assoc_loaded?(item.single_item)
      assert item.single_item != nil
    end

    test "bulk items have items_locations association" do
      bulk = bulk_item_fixture()

      items = Inventory.list_items()
      item = Enum.find(items, &(&1.id == bulk.id))

      assert item.item_type == :bulk
      assert Ecto.assoc_loaded?(item.items_locations)
      assert length(item.items_locations) > 0
    end

    test "single items are stored at one location" do
      location = warehouse_fixture()
      single = single_item_fixture(%{location: location})

      items = Inventory.list_items()
      item = Enum.find(items, &(&1.id == single.id))

      assert item.single_item.location_id == location.id
    end

    test "bulk items can be at multiple locations" do
      location1 = warehouse_fixture()
      location2 = warehouse_fixture()
      bulk = bulk_item_fixture(%{location: location1})

      # Add to second location
      alias LicoriceLane.Locations.ItemsLocation
      alias LicoriceLane.Repo

      %ItemsLocation{
        item_id: bulk.id,
        location_id: location2.id,
        quantity: 30
      }
      |> Repo.insert!()

      items = Inventory.list_items()
      item = Enum.find(items, &(&1.id == bulk.id))

      assert length(item.items_locations) == 2
    end
  end
end
