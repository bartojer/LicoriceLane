defmodule LicoriceLane.Inventory do
  import Ecto.Query

  alias LicoriceLane.Items.Item
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
      from(il in LicoriceLane.Locations.ItemsLocation,
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
    from(il in LicoriceLane.Locations.ItemsLocation,
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
    from(il in LicoriceLane.Locations.ItemsLocation,
      join: l in assoc(il, :location),
      join: i in assoc(il, :item),
      where: l.location_type == :warehouse,
      preload: [:location, :item],
      order_by: [asc: i.name, asc: l.name]
    )
    |> Repo.all()
  end

  @doc """
  Returns all warehouse locations ordered by name.
  Used for location selection in forms.
  """
  def list_warehouse_locations do
    from(l in LicoriceLane.Locations.Location,
      where: l.location_type == :warehouse,
      order_by: [asc: l.name]
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
  Creates an item with initial location tracking.

  This function handles both single and bulk items:
  - Single items: Creates Item + SingleItem with location_id, sets min_stock to 0
  - Bulk items: Creates Item + ItemsLocation with quantity, explicitly sets min_stock to 10 if not provided

  All operations are wrapped in a transaction for atomicity.
  Attributes are normalized (strings converted to proper types) before validation.

  ## Parameters
    - attrs: Map containing item attributes (accepts atom or string keys)
      - Required for all: :name, :description, :item_type, :location_id
      - Required for single: :condition (defaults to "New" if not provided), :status (defaults to :available)
      - Required for bulk: :quantity (must be > 0, accepts string or integer)
      - Optional: :category, :rental_price, :image_path, :color, :min_stock

  ## Returns
    - {:ok, item} - Item with all associations preloaded on success
    - {:error, :item, changeset} - Item validation failed
    - {:error, :location_data, changeset} - SingleItem or ItemsLocation creation failed
    - {:error, :validation, reason} - Pre-transaction validation failed (item_type, location_id, or quantity issues)
    - {:error, :constraint_violation, details} - Database constraint violated

  ## Examples
      # Create a single item (chair)
      create_item_with_location(%{
        name: "Gold Chiavari Chair",
        description: "Elegant gold chair",
        item_type: :single,
        category: :tableware,
        rental_price: Decimal.new("8.50"),
        location_id: warehouse_id,
        condition: "Excellent",
        status: :available
      })

      # Create a bulk item (napkins)
      create_item_with_location(%{
        name: "White Linen Napkins",
        description: "20x20 white napkins",
        item_type: :bulk,
        category: :linen,
        rental_price: Decimal.new("1.25"),
        location_id: warehouse_id,
        quantity: 500,
        min_stock: 50
      })
  """
  def create_item_with_location(attrs) do
    # Normalize and validate attributes before starting transaction
    with :ok <- validate_item_attrs(attrs),
         {:ok, normalized_attrs} <- normalize_attributes(attrs) do
      result =
        Ecto.Multi.new()
        |> Ecto.Multi.insert(:item, Item.changeset(%Item{}, normalized_attrs))
        |> insert_location_data(normalized_attrs)
        |> Repo.transaction()

      case result do
        {:ok, %{item: item}} ->
          broadcast_inventory_update(item.id)
          # Return item with full preloads
          {:ok, get_item_with_full_preloads(item.id)}

        {:error, :item, changeset, _} ->
          {:error, :item, changeset}

        {:error, :location_data, changeset, _} ->
          {:error, :location_data, changeset}

        {:error, failed_operation, failed_value, _changes_so_far} ->
          # Handle unexpected errors
          {:error, failed_operation, failed_value}
      end
    else
      {:error, reason} -> {:error, :validation, reason}
    end
  rescue
    e in Ecto.ConstraintError ->
      {:error, :constraint_violation, constraint_error_message(e)}
  end

  @doc """
  Retrieves an item with all associations preloaded for complete display.

  NOTE: Uses Repo.get! which raises Ecto.NoResultsError if item not found.
  This is intentional - if called after transaction success and item is missing,
  it indicates a serious system issue (concurrent deletion, DB inconsistency, etc.)
  that should bubble up as an error rather than being silently handled.

  Preloads:
  - single_item (with location)
  - items_locations (with locations)
  - rental_bulk_items
  - rental_single_items (through single_item)
  """
  def get_item_with_full_preloads(item_id) do
    Item
    |> Repo.get!(item_id)
    |> Repo.preload([
      single_item: :location,
      items_locations: :location,
      rental_bulk_items: :rental,
      rental_single_items: [single_item: :item]
    ])
  end

  # Private helper functions

  # Helper function to safely get attribute values from maps with atom or string keys
  defp get_attr(attrs, key) when is_atom(key) do
    attrs[key] || attrs[Atom.to_string(key)]
  end

  defp validate_item_attrs(attrs) do
    item_type = get_attr(attrs, :item_type)
    location_id = get_attr(attrs, :location_id)

    with :ok <- validate_required_fields(item_type, location_id),
         :ok <- validate_location_exists(location_id) do
      case item_type do
        type when type in [:single, "single"] -> validate_single_item_attrs(attrs)
        type when type in [:bulk, "bulk"] -> validate_bulk_item_attrs(attrs)
      end
    end
  end

  defp validate_required_fields(nil, _location_id) do
    {:error, "item_type is required"}
  end

  defp validate_required_fields(_item_type, nil) do
    {:error, "location_id is required"}
  end

  defp validate_required_fields(item_type, _location_id)
       when item_type not in [:single, "single", :bulk, "bulk"] do
    {:error, "item_type must be :single or :bulk"}
  end

  defp validate_required_fields(_item_type, _location_id), do: :ok

  defp validate_location_exists(location_id) do
    case Repo.get(LicoriceLane.Locations.Location, location_id) do
      nil -> {:error, "location_id does not exist"}
      _location -> :ok
    end
  end

  defp validate_single_item_attrs(_attrs) do
    # Condition and status will default in changeset if not provided
    # No additional validation needed beyond what's in the changeset
    :ok
  end

  defp validate_bulk_item_attrs(attrs) do
    quantity = get_attr(attrs, :quantity)
    normalize_quantity(quantity)
  end

  defp normalize_quantity(nil) do
    {:error, "quantity is required for bulk items"}
  end

  defp normalize_quantity(quantity) when is_integer(quantity) and quantity > 0 do
    :ok
  end

  defp normalize_quantity(quantity) when is_integer(quantity) do
    {:error, "quantity must be greater than 0"}
  end

  defp normalize_quantity(quantity) when is_binary(quantity) do
    case Integer.parse(quantity) do
      {qty, ""} when qty > 0 -> :ok
      _ -> {:error, "quantity must be a positive integer"}
    end
  end

  defp normalize_quantity(_) do
    {:error, "quantity must be a positive integer"}
  end

  # Normalizes attribute types and sets defaults based on item type
  defp normalize_attributes(attrs) do
    item_type = normalize_item_type(get_attr(attrs, :item_type))
    
    normalized =
      attrs
      |> Map.new(fn {k, v} -> {to_atom_key(k), v} end)
      |> Map.put(:item_type, item_type)

    case item_type do
      :single -> normalize_single_item_attrs(normalized)
      :bulk -> normalize_bulk_item_attrs_with_defaults(normalized)
    end
  end

  defp to_atom_key(key) when is_atom(key), do: key
  defp to_atom_key(key) when is_binary(key) do
    try do
      String.to_existing_atom(key)
    rescue
      ArgumentError -> String.to_atom(key)
    end
  end

  defp normalize_single_item_attrs(attrs) do
    normalized =
      attrs
      |> Map.put_new(:condition, "New")
      |> Map.put_new(:status, :available)

    {:ok, normalized}
  end

  defp normalize_bulk_item_attrs_with_defaults(attrs) do
    quantity = get_attr(attrs, :quantity)
    
    normalized_qty =
      case quantity do
        q when is_integer(q) -> q
        q when is_binary(q) ->
          {parsed, ""} = Integer.parse(q)
          parsed
      end

    normalized =
      attrs
      |> Map.put(:quantity, normalized_qty)
      |> Map.put_new(:min_stock, 10)

    {:ok, normalized}
  end

  defp insert_location_data(multi, attrs) do
    case attrs.item_type do
      :single -> insert_single_item(multi, attrs)
      :bulk -> insert_items_location(multi, attrs)
    end
  end

  defp normalize_item_type(:single), do: :single
  defp normalize_item_type("single"), do: :single
  defp normalize_item_type(:bulk), do: :bulk
  defp normalize_item_type("bulk"), do: :bulk

  defp insert_single_item(multi, attrs) do
    Ecto.Multi.insert(multi, :location_data, fn %{item: item} ->
      # CRITICAL: SingleItem.id must be explicitly set to match Item.id
      # because SingleItem uses a non-autogenerate primary key
      single_attrs = %{
        id: item.id,
        location_id: attrs.location_id,
        condition: attrs.condition,
        status: attrs.status
      }

      LicoriceLane.Items.SingleItem.changeset(
        %LicoriceLane.Items.SingleItem{},
        single_attrs
      )
    end)
  end

  defp insert_items_location(multi, attrs) do
    Ecto.Multi.insert(multi, :location_data, fn %{item: item} ->
      location_attrs = %{
        item_id: item.id,
        location_id: attrs.location_id,
        quantity: attrs.quantity
      }

      LicoriceLane.Locations.ItemsLocation.changeset(
        %LicoriceLane.Locations.ItemsLocation{},
        location_attrs
      )
    end)
  end

  defp constraint_error_message(%Ecto.ConstraintError{constraint: constraint, type: type}) do
    case {type, constraint} do
      {:unique, "items_locations_item_id_location_id_index"} ->
        "This item already has a quantity record at this location"

      {:foreign_key, "items_locations_location_id_fkey"} ->
        "Invalid location_id: location does not exist"

      {:foreign_key, "single_items_location_id_fkey"} ->
        "Invalid location_id: location does not exist"

      {:foreign_key, _} ->
        "Foreign key constraint violation: referenced record does not exist"

      _ ->
        "Database constraint violation: #{constraint}"
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
