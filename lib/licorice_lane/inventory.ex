defmodule LicoriceLane.Inventory do
  import Ecto.Query

  alias LicoriceLane.Item
  alias LicoriceLane.Repo

  @pubsub LicoriceLane.PubSub
  @topic "inventory:updates"

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

  @doc """
  Returns items where warehouse stock is below the min_stock threshold.
  Warehouse stock is calculated by summing quantities from warehouse-type locations.
  """
  def list_low_stock_items do
    warehouse_subquery =
      from(il in LicoriceLane.ItemsLocation,
        join: l in assoc(il, :location),
        where: l.location_type == :warehouse,
        group_by: il.item_id,
        select: %{item_id: il.item_id, total_qty: sum(il.quantity)}
      )

    from(i in Item,
      left_join: wh in subquery(warehouse_subquery),
      on: i.id == wh.item_id,
      where: coalesce(wh.total_qty, 0) < i.min_stock,
      preload: [items_locations: :location],
      select: %{
        item: i,
        warehouse_quantity: coalesce(wh.total_qty, 0)
      }
    )
    |> Repo.all()
  end

  @doc """
  Returns warehouse quantities for a specific item, grouped by warehouse location.
  """
  def get_warehouse_quantities(item_id) do
    from(il in LicoriceLane.ItemsLocation,
      join: l in assoc(il, :location),
      where: il.item_id == ^item_id and l.location_type == :warehouse,
      preload: [:location],
      order_by: [asc: l.name]
    )
    |> Repo.all()
  end

  @doc """
  Returns warehouse quantities for all items, grouped by item and location.
  """
  def list_all_warehouse_quantities do
    from(il in LicoriceLane.ItemsLocation,
      join: l in assoc(il, :location),
      join: i in assoc(il, :item),
      where: l.location_type == :warehouse,
      preload: [:location, :item],
      order_by: [asc: i.name, asc: l.name]
    )
    |> Repo.all()
  end

  @doc """
  Broadcasts an inventory update event via PubSub.
  """
  def broadcast_inventory_update(item_id) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:inventory_updated, item_id})
  end

  @doc """
  Creates an item and broadcasts the update.
  """
  def create_item(attrs \\ %{}) do
    result =
      %Item{}
      |> Item.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, item} ->
        broadcast_inventory_update(item.id)
        {:ok, item}

      error ->
        error
    end
  end

  @doc """
  Updates an item and broadcasts the update.
  """
  def update_item(%Item{} = item, attrs) do
    result =
      item
      |> Item.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated_item} ->
        broadcast_inventory_update(updated_item.id)
        {:ok, updated_item}

      error ->
        error
    end
  end

  @doc """
  Deletes an item and broadcasts the update.
  """
  def delete_item(%Item{} = item) do
    result = Repo.delete(item)

    case result do
      {:ok, deleted_item} ->
        broadcast_inventory_update(deleted_item.id)
        {:ok, deleted_item}

      error ->
        error
    end
  end
end
