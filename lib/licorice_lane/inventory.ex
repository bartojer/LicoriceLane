defmodule LicoriceLane.Inventory do
  import Ecto.Query

  alias LicoriceLane.Item
  alias LicoriceLane.Repo

  @pubsub LicoriceLane.PubSub
  @topic "inventory:updates"

  @doc """
  Normalizes category filter input into a list of category atoms.

  Special cases:
  - "all" or :all -> :all (no category filtering)
  - "lighting" -> [:candle, :electric_light]
  - [] -> logs warning and returns [] (will return no results)
  - Single string/atom -> converts to list
  """
  def normalize_category_filter("all"), do: :all
  def normalize_category_filter(:all), do: :all
  def normalize_category_filter("lighting"), do: [:candle, :electric_light]
  def normalize_category_filter(:lighting), do: [:candle, :electric_light]

  def normalize_category_filter([]) do
    require Logger
    Logger.warning("No categories selected for filtering. This will return no items.")
    []
  end

  def normalize_category_filter(categories) when is_list(categories) do
    Enum.map(categories, fn
      cat when is_atom(cat) -> cat
      cat when is_binary(cat) -> String.to_existing_atom(cat)
    end)
  end

  def normalize_category_filter(category) when is_binary(category) do
    [String.to_existing_atom(category)]
  end

  def normalize_category_filter(category) when is_atom(category) do
    [category]
  end

  @doc """
  Builds the base query for items with standard preloads.
  """
  def build_items_query do
    from(i in Item,
      preload: [
        :single_item,
        items_locations: :location
      ]
    )
  end

  @doc """
  Returns all items with necessary preloads for display.
  """
  def list_items do
    build_items_query()
    |> Repo.all()
  end

  @doc """
  Adds category filtering to a query.
  Returns query unchanged if categories is :all or [].
  """
  def filter_by_categories(query, :all), do: query
  def filter_by_categories(query, []), do: query

  def filter_by_categories(query, categories) when is_list(categories) do
    from(i in query, where: i.category in ^categories)
  end

  @doc """
  Adds search term filtering to a query.
  Searches in item name and description using AND logic for multiple terms.
  Empty string or whitespace-only returns query unchanged.
  """
  def filter_by_search_term(query, search_term) when is_binary(search_term) do
    trimmed = String.trim(search_term)

    if trimmed == "" do
      query
    else
      terms =
        trimmed
        |> String.split(~r/\s+/, trim: true)
        |> Enum.map(&String.downcase/1)

      Enum.reduce(terms, query, fn term, acc_query ->
        pattern = "%#{term}%"

        from(i in acc_query,
          where:
            ilike(i.name, ^pattern) or
              ilike(i.description, ^pattern)
        )
      end)
    end
  end

  def filter_by_search_term(query, _), do: query

  @doc """
  Returns items filtered by categories.
  Categories are normalized before querying.
  """
  def list_items_by_categories(categories) do
    normalized = normalize_category_filter(categories)

    build_items_query()
    |> filter_by_categories(normalized)
    |> Repo.all()
  end

  @doc """
  Coordinator function: Returns items filtered by categories and search term.
  All filtering happens at the DB level for optimal performance.

  ## Parameters
    - categories: Can be "all", :all, "lighting", a single category, or list of categories
    - search_term: String to search in name and description (uses AND logic for multiple words)

  ## Examples
      list_filtered_items("all", "gold taper")
      list_filtered_items([:candle, :electric_light], "vintage")
      list_filtered_items("lighting", "")
  """
  def list_filtered_items(categories, search_term \\ "") do
    normalized_categories = normalize_category_filter(categories)

    build_items_query()
    |> filter_by_categories(normalized_categories)
    |> filter_by_search_term(search_term)
    |> Repo.all()
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
