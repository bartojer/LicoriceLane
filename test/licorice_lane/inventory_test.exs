defmodule LicoriceLane.InventoryTest do
  use LicoriceLane.DataCase, async: true

  alias LicoriceLane.Inventory
  alias LicoriceLane.Locations.ItemsLocation

  import LicoriceLane.ItemsFixtures
  import LicoriceLane.LocationsFixtures

  @tag :capture_log
  test "category normalization preserves every supported input form" do
    for {input, expected} <- [
          {"all", :all},
          {:all, :all},
          {"lighting", [:candle, :electric_light]},
          {:lighting, [:candle, :electric_light]},
          {"tableware", [:tableware]},
          {:linen, [:linen]},
          {[:candle, :tableware], [:candle, :tableware]},
          {["candle", "linen"], [:candle, :linen]},
          {[], []}
        ] do
      assert Inventory.normalize_category_filter(input) == expected, "input: #{inspect(input)}"
    end
  end

  test "listing empty inventory returns no items" do
    assert Inventory.list_items() == []
  end

  test "listing preloads single tracking and all bulk locations with their quantities" do
    first = warehouse_fixture()
    second = warehouse_fixture()
    single = single_item_fixture(%{location: first})
    bulk = bulk_item_fixture(%{location: first})
    Repo.insert!(%ItemsLocation{item_id: bulk.id, location_id: second.id, quantity: 30})

    items = Inventory.list_items()
    assert ids(items) == ids([single, bulk])
    loaded_single = Enum.find(items, &(&1.id == single.id))
    assert loaded_single.item_type == :single
    assert loaded_single.single_item.id == single.id
    assert loaded_single.single_item.location_id == first.id
    assert loaded_single.items_locations == []
    loaded_bulk = Enum.find(items, &(&1.id == bulk.id))
    assert loaded_bulk.item_type == :bulk
    assert loaded_bulk.single_item == nil

    assert Enum.sort(Enum.map(loaded_bulk.items_locations, &{&1.location.id, &1.quantity})) ==
             Enum.sort([{first.id, 50}, {second.id, 30}])
  end

  test "category query and public coordinator retain all, empty, single, multiple and lighting filters" do
    warehouse = warehouse_fixture()
    candle = single_item_fixture(%{location: warehouse, category: :candle})
    tableware = single_item_fixture(%{location: warehouse, category: :tableware})
    linen = bulk_item_fixture(%{location: warehouse, category: :linen})
    electric = single_item_fixture(%{location: warehouse, category: :electric_light})
    all = [candle, tableware, linen, electric]

    for {categories, expected} <- [
          {:all, all},
          {[], all},
          {[:candle], [candle]},
          {[:candle, :linen], [candle, linen]}
        ] do
      results =
        Inventory.build_items_query() |> Inventory.filter_by_categories(categories) |> Repo.all()

      assert ids(results) == ids(expected), "categories: #{inspect(categories)}"
    end

    for {categories, expected} <- [
          {[:candle], [candle]},
          {"lighting", [candle, electric]}
        ] do
      assert ids(Inventory.list_items_by_categories(categories)) == ids(expected)
    end
  end

  test "search query matches names and descriptions case-insensitively and ANDs terms" do
    warehouse = warehouse_fixture()

    chair =
      single_item_fixture(%{
        location: warehouse,
        name: "Gold Chiavari Chair",
        description: "Elegant wedding seating"
      })

    tablecloth =
      bulk_item_fixture(%{
        location: warehouse,
        name: "White Tablecloth",
        description: "Premium linen for events"
      })

    chandelier =
      single_item_fixture(%{
        location: warehouse,
        name: "Crystal Chandelier",
        description: "Sparkling gold accent piece"
      })

    all = [chair, tablecloth, chandelier]

    for {term, expected} <- [
          {"", all},
          {"   ", all},
          {"Chair", [chair]},
          {"linen", [tablecloth]},
          {"gold elegant", [chair]},
          {"  GOLD\t elegant  ", [chair]},
          {"WHITE", [tablecloth]},
          {"nonexistent", []}
        ] do
      results =
        Inventory.build_items_query() |> Inventory.filter_by_search_term(term) |> Repo.all()

      assert ids(results) == ids(expected), "search: #{inspect(term)}"
    end
  end

  test "combined filtering intersects categories with name or description search" do
    warehouse = warehouse_fixture()

    gold =
      single_item_fixture(%{
        location: warehouse,
        category: :candle,
        name: "Gold Taper Candle",
        description: "Elegant tall candle"
      })

    silver =
      single_item_fixture(%{
        location: warehouse,
        category: :candle,
        name: "Silver Pillar Candle",
        description: "Modern design"
      })

    plate =
      single_item_fixture(%{
        location: warehouse,
        category: :tableware,
        name: "Gold Charger Plate",
        description: "Elegant dining accent"
      })

    for {categories, term, expected} <- [
          {[:candle], "", [gold, silver]},
          {"all", "gold", [gold, plate]},
          {[:candle], "gold", [gold]},
          {"all", "", [gold, silver, plate]},
          {[:tableware], "modern", []},
          {[:candle], "elegant", [gold]}
        ] do
      results = Inventory.list_filtered_items(categories, term)
      assert ids(results) == ids(expected), "filters: #{inspect({categories, term})}"
      assert Enum.all?(results, &Ecto.assoc_loaded?(&1.single_item))
      assert Enum.all?(results, &Ecto.assoc_loaded?(&1.items_locations))
    end
  end

  defp ids(items), do: items |> Enum.map(& &1.id) |> Enum.sort()
end
