defmodule LicoriceLane.Inventory do
  import Ecto.Query

  alias LicoriceLane.Item
  alias LicoriceLane.Repo

  @doc """
  Returns all items with necessary preloads for display.
  Preloads single_item, items_locations with their locations for warehouse quantity calculation.
  """
  def list_items do
    Item
    |> preload([
      :single_item,
      items_locations: :location
    ])
    |> Repo.all()
  end

  @doc """
  Returns items filtered by category.
  Special case: "lighting" returns both :candle and :electric_light categories.
  """
  def list_items_by_category("lighting") do
    Item
    |> where([i], i.category in [:candle, :electric_light])
    |> preload([
      :single_item,
      items_locations: :location
    ])
    |> Repo.all()
  end

  def list_items_by_category(category) when is_atom(category) do
    Item
    |> where([i], i.category == ^category)
    |> preload([
      :single_item,
      items_locations: :location
    ])
    |> Repo.all()
  end

  def list_items_by_category(category) when is_binary(category) do
    category_atom = String.to_existing_atom(category)
    list_items_by_category(category_atom)
  end

  @doc """
  Filters a list of items by search term (searches name and description).
  Case-insensitive search.
  """
  def search_items(items, "") do
    items
  end

  def search_items(items, search_term) when is_binary(search_term) do
    search_term = String.downcase(search_term)

    Enum.filter(items, fn item ->
      String.contains?(String.downcase(item.name), search_term) ||
        String.contains?(String.downcase(item.description || ""), search_term)
    end)
  end

  def list_all_inventory do
    Item
    |> preload([:single_item, :rental, :rental_bulk_items, :rental_single_items])
    |> Repo.all()
  end
end
