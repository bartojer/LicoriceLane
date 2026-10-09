# Item Creation Guide

## Overview

This guide demonstrates how to use `create_item_with_location/1` to add new items to your inventory.

Reviewed against the working tree on October 7, 2026. See [architecture](docs/ARCHITECTURE.md#inventory-relationships-and-writes) for related schemas and [current status](docs/STATUS.md) for unfinished admin workflows.

## Function Signature

```elixir
LicoriceLane.Inventory.create_item_with_location(attrs)
```

## How It Works

The function validates and normalizes attributes, then uses `Ecto.Multi` for two atomic database operations:
1. **Create Item** - Inserts base item record
2. **Create Location Data** - Creates either:
   - `SingleItem` record (for individual tracking) with `id` explicitly set to match `Item.id`
   - `ItemsLocation` record (for quantity tracking)

After a successful transaction, it invalidates inventory cache entries, broadcasts the PubSub update, and loads the item with its associations. Cache invalidation, broadcasting, and the final preload query are outside the transaction.

## Single Items (item_type: :single)

Individual items that need separate tracking (chairs, specific pieces, etc.)

### Required Fields
- `:name` - Item name
- `:description` - Item description
- `:item_type` - Must be `:single` or `"single"`
- `:location_id` - Initial location (warehouse ID)

### Optional Fields
- `:condition` - Defaults to `"New"` if not provided
- `:status` - Defaults to `:available` if not provided
- `:category` - One of: `:candle`, `:tableware`, `:linen`, `:electric_light`, `:tray`
- `:rental_price` - Decimal price
- `:image_path` - Path to image
- `:color` - Color description

### Important Notes
- `min_stock` is automatically set to `0` (single items don't use stock alerts)
- Each physical unit needs its own item record

### Example: Create a Single Chair

```elixir
alias LicoriceLane.Inventory
alias LicoriceLane.Repo

# Get your warehouse location ID
warehouse = Repo.get_by!(LicoriceLane.Locations.Location, name: "Main Warehouse")

# Create a single item
{:ok, chair} = Inventory.create_item_with_location(%{
  name: "Gold Chiavari Chair #1",
  description: "Elegant gold chiavari chair for events",
  item_type: :single,
  category: :tableware,
  rental_price: Decimal.new("8.50"),
  location_id: warehouse.id,
  condition: "Excellent",
  status: :available,
  color: "Gold"
})

# Result: chair is fully preloaded with single_item and location
IO.inspect(chair.single_item.location.name) # => "Main Warehouse"
IO.inspect(chair.min_stock) # => 0 (automatically set)
```

## Bulk Items (item_type: :bulk)

Items tracked by quantity (napkins, candles, etc.)

### Required Fields
- `:name` - Item name
- `:description` - Item description
- `:item_type` - Must be `:bulk` or `"bulk"`
- `:location_id` - Initial location (warehouse ID)
- `:quantity` - Initial quantity (must be > 0)

### Optional Fields
- `:min_stock` - Minimum stock threshold for alerts (defaults to 10)
- `:category` - One of: `:candle`, `:tableware`, `:linen`, `:electric_light`, `:tray`
- `:rental_price` - Decimal price
- `:image_path` - Path to image
- `:color` - Color description

### Important Notes
- One item record represents ALL units of that type
- Can be stored at multiple locations with different quantities
- `min_stock` is preserved; the creation context supplies `10` when the attribute is absent. The base Item schema default is `0`, so direct Repo inserts do not apply this context default.

### Example: Create Bulk Napkins

```elixir
alias LicoriceLane.Inventory
alias LicoriceLane.Repo

# Get your warehouse location ID
warehouse = Repo.get_by!(LicoriceLane.Locations.Location, name: "Main Warehouse")

# Create bulk item
{:ok, napkins} = Inventory.create_item_with_location(%{
  name: "White Linen Napkins",
  description: "20x20 inch white linen napkins",
  item_type: :bulk,
  category: :linen,
  rental_price: Decimal.new("1.25"),
  location_id: warehouse.id,
  quantity: 500,
  min_stock: 50,
  color: "White"
})

# Result: napkins is fully preloaded with items_locations
IO.inspect(hd(napkins.items_locations).quantity) # => 500
IO.inspect(napkins.min_stock) # => 50
```

## Error Handling

The function returns different error tuples depending on what fails:

### Validation Errors (before transaction)

```elixir
{:error, :validation, "quantity is required for bulk items"}
{:error, :validation, "item_type is required"}
{:error, :validation, "location_id is required"}
{:error, :validation, "quantity must be greater than 0"}
```

### Item Creation Errors

```elixir
{:error, :item, changeset}
# Occurs when Item.changeset validation fails
# Check changeset.errors for details:
# - Missing required fields (:name, :description, :item_type)
# - Invalid enum values for :category or :item_type
```

### Location Data Errors

```elixir
{:error, :location_data, changeset}
# Occurs when SingleItem or ItemsLocation creation fails
# For SingleItem: missing/invalid condition, status, location_id
# For ItemsLocation: missing/invalid quantity, location_id
```

### Constraint Violation Errors

```elixir
{:error, :constraint_violation, "This item already has a quantity record at this location"}
# Occurs when trying to create duplicate items_locations record

{:error, :constraint_violation, "Invalid location_id: location does not exist"}
# Occurs when location_id doesn't exist in database
```

## Full Error Handling Example

```elixir
case Inventory.create_item_with_location(attrs) do
  {:ok, item} ->
    # Success! Item is fully preloaded
    render(conn, "show.html", item: item)

  {:error, :validation, reason} ->
    # Pre-transaction validation failed
    conn
    |> put_flash(:error, "Validation error: #{reason}")
    |> render("new.html", changeset: Item.changeset(%Item{}, attrs))

  {:error, :item, changeset} ->
    # Item creation failed
    conn
    |> put_flash(:error, "Could not create item")
    |> render("new.html", changeset: changeset)

  {:error, :location_data, changeset} ->
    # SingleItem or ItemsLocation failed
    conn
    |> put_flash(:error, "Could not set item location")
    |> render("new.html", changeset: changeset)

  {:error, :constraint_violation, message} ->
    # Database constraint violated
    conn
    |> put_flash(:error, message)
    |> render("new.html", changeset: Item.changeset(%Item{}, attrs))
end
```

## Helper Function: Get Full Item Details

After creation or anytime you need complete item data:

```elixir
# Retrieves item with ALL associations preloaded
item = Inventory.get_item_with_full_preloads(item_id)

# Available preloads:
# - item.single_item (with location)
# - item.items_locations (with locations)
# - item.rental_bulk_items (with rental)
# - item.rental_single_items (with single_item and its item)
```

## Schema Relationships

### Single Items
```
Item (id: 42, item_type: :single, min_stock: 0)
  └── SingleItem (id: 42, location_id: 1, condition: "Excellent", status: :available)
        └── Location (id: 1, name: "Main Warehouse")
```

### Bulk Items
```
Item (id: 43, item_type: :bulk, min_stock: 50)
  ├── ItemsLocation (item_id: 43, location_id: 1, quantity: 300)
  │     └── Location (id: 1, name: "Main Warehouse")
  └── ItemsLocation (item_id: 43, location_id: 2, quantity: 200)
        └── Location (id: 2, name: "Storage Unit")
```

## Important Implementation Details

### SingleItem Primary Key
- `SingleItem.id` is NOT autogenerated
- It's a foreign key that references `Item.id`
- Creates a 1-to-1 relationship where both records share the same ID
- The function handles this automatically by explicitly setting `id: item.id`

### Min Stock Behavior
- **Single items**: Always set to `0` (automatic)
- **Bulk items**: Uses provided value or defaults to `10` in the creation context when the attribute is absent
- Used by `list_low_stock_items/0` to generate alerts

### PubSub Broadcasting
- Every successful creation broadcasts `{:inventory_updated, item_id}`
- Subscribers on topic `"inventory:updates"` receive real-time updates
- Use in LiveView: `Phoenix.PubSub.subscribe(LicoriceLane.PubSub, "inventory:updates")`
- A LiveComponent subscription delivers messages to its parent LiveView process. The parent must explicitly refresh child components; a child `handle_info` callback alone is insufficient.

## Testing in IEx

Use a disposable development database for this example; it writes sample inventory records. Automated tests should use the existing fixtures under `test/support/fixtures` rather than seeds.

```elixir
# Start IEx with your app
iex -S mix

# Create warehouse location if needed
alias LicoriceLane.Repo
alias LicoriceLane.Locations.Location
warehouse = Repo.insert!(%Location{name: "Test Warehouse", location_type: :warehouse})

# Test single item
alias LicoriceLane.Inventory
{:ok, chair} = Inventory.create_item_with_location(%{
  name: "Test Chair",
  description: "A test chair",
  item_type: :single,
  location_id: warehouse.id,
  condition: "New"
})

# Test bulk item
{:ok, napkins} = Inventory.create_item_with_location(%{
  name: "Test Napkins",
  description: "Test napkins",
  item_type: :bulk,
  location_id: warehouse.id,
  quantity: 100
})

# Verify
Repo.preload(chair, :single_item) |> IO.inspect()
Repo.preload(napkins, :items_locations) |> IO.inspect()
```

## Next Steps

After creating items, you can:
- Update items with `update_item/2`
- Delete items with `delete_item/1`
- Query items with `list_filtered_items/2`
- Check low stock with `list_low_stock_items/0`
- Get warehouse quantities with `get_warehouse_quantities/1`

`update_item/2` changes base item fields. Admin edits use `update_item_with_details/2`, which atomically updates base fields and single-item condition/status, then invalidates cache and broadcasts on success. Neither API moves single items or edits bulk location quantities.

Admin deletion asks for confirmation before calling `delete_item/1`. Deletion atomically removes the item and its stock/tracking rows, then invalidates cache and broadcasts. Any booking or movement-history reference prevents deletion and returns `{:error, changeset}` without changing stock. This includes returned and cancelled bookings. Locations and image files are retained; see [architecture](docs/ARCHITECTURE.md#inventory-relationships-and-writes).
