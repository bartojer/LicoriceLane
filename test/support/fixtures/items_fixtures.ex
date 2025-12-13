defmodule LicoriceLane.ItemsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `LicoriceLane.Items` context.
  """

  import LicoriceLane.LocationsFixtures

  alias LicoriceLane.Repo
  alias LicoriceLane.Items.{Item, SingleItem}
  alias LicoriceLane.Locations.ItemsLocation

  def unique_item_name, do: "Item #{System.unique_integer()}"

  def valid_single_item_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: unique_item_name(),
      description: "Test item description",
      category: :tableware,
      item_type: :single,
      rental_price: Decimal.new("10.00"),
      image_path: "images/test.png",
      min_stock: 0,
      color: "Blue"
    })
  end

  def valid_bulk_item_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: unique_item_name(),
      description: "Test bulk item description",
      category: :linen,
      item_type: :bulk,
      rental_price: Decimal.new("2.00"),
      image_path: "images/test.png",
      min_stock: 10,
      color: "White"
    })
  end

  def single_item_fixture(attrs \\ %{}) do
    location = attrs[:location] || warehouse_fixture()

    # Create the base Item
    item =
      attrs
      |> valid_single_item_attributes()
      |> then(&struct(Item, &1))
      |> Repo.insert!()

    # Create SingleItem record
    single_item =
      %SingleItem{
        id: item.id,
        condition: attrs[:condition] || "New",
        status: attrs[:status] || :available,
        location_id: location.id
      }
      |> Repo.insert!()

    # Preload associations
    item |> Repo.preload([:single_item, items_locations: :location])
  end

  def bulk_item_fixture(attrs \\ %{}) do
    location = attrs[:location] || warehouse_fixture()
    quantity = attrs[:quantity] || 50

    # Create the base Item
    item =
      attrs
      |> valid_bulk_item_attributes()
      |> then(&struct(Item, &1))
      |> Repo.insert!()

    # Create ItemsLocation record for bulk item
    %ItemsLocation{
      item_id: item.id,
      location_id: location.id,
      quantity: quantity
    }
    |> Repo.insert!()

    # Preload associations
    item |> Repo.preload([:items_locations])
  end
end
