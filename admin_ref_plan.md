# Admin Dashboard Refactor Plan

## Overview
Refactor the admin page to use real database queries instead of mock data, split into organized LiveComponents in separate files, create new context modules for Customers and Rentals, add event_type and min_stock fields, and implement PubSub for real-time inventory updates.

## Database Schema Changes

### New Fields to Add

1. **Rental Schema** (`lib/licorice_lane/rental.ex`)
   - `event_type` - string field (displayed as Ecto.Enum: :wedding, :corporate, :birthday)
   - `event_date` - utc_datetime field (when the actual event occurs)
   - Optional fields

2. **Item Schema** (`lib/licorice_lane/item.ex`)
   - `min_stock` - integer field with default value of 10
   - Used for low stock alerts by comparing warehouse quantities

## Implementation Steps

### 1. Create Database Migration
Create migration to add:
- `event_type` (string, nullable) to `rentals` table
- `event_date` (utc_datetime, nullable) to `rentals` table  
- `min_stock` (integer, default: 10) to `items` table

### 2. Update Schemas

**Rental Schema** (`lib/licorice_lane/rental.ex`)
```elixir
schema "rentals" do
  field :status, Ecto.Enum, values: [:active, :returned, :late, :cancelled], default: :active
  field :event_type, Ecto.Enum, values: [:wedding, :corporate, :birthday]
  field :event_date, :utc_datetime
  field :rented_at, :utc_datetime
  field :return_by, :utc_datetime
  field :returned_at, :utc_datetime
  
  belongs_to :customer, LicoriceLane.Customer
  has_many :rental_single_items, LicoriceLane.RentalSingleItem
  has_many :rental_bulk_items, LicoriceLane.RentalBulkItem
  
  timestamps(type: :utc_datetime)
end

def changeset(rental, attrs) do
  rental
  |> cast(attrs, [:customer_id, :rented_at, :return_by, :returned_at, :status, :event_type, :event_date])
  |> validate_required([:customer_id, :rented_at, :return_by, :status])
end
```

**Item Schema** - Add `min_stock` field and update changeset

### 3. Create Context Modules

#### LicoriceLane.Rentals Context (`lib/licorice_lane/rentals.ex`)
New module with functions:
- `list_rentals/0` - all rentals with preloads
- `list_recent_rentals(limit \\ 10)` - most recent rentals
- `list_rentals_by_status(status)` - filter by status enum
- `list_upcoming_rentals/0` - where `rented_at > now()`
- `list_active_rentals/0` - where status == :active
- `list_overdue_rentals/0` - where `return_by < now()` and status == :active
- All queries should preload: `:customer`, `:rental_single_items`, `:rental_bulk_items`

#### LicoriceLane.Customers Context (`lib/licorice_lane/customers.ex`)
New module with functions:
- `list_customers/0` - all customers
- `get_customer(id)` - single customer with preloads
- `search_customers(search_term)` - search by name, email, phone
- Preload `:locations` for customers

### 4. Extend Inventory Context (`lib/licorice_lane/inventory.ex`)

Add new functions:
- `list_low_stock_items/0` - items where warehouse quantity < min_stock
  - Sum quantities from `items_locations` where location is warehouse type
  - Compare to `min_stock` field
- `get_warehouse_quantities(item_id)` - return map of location_name => quantity
  - Only include warehouse locations
  - Exclude rented items

Add PubSub broadcasts:
- After any item create/update/delete operations
- Topic: `"inventory:updates"`
- Message: `{:inventory_updated, item_id}`

```elixir
Phoenix.PubSub.broadcast(
  LicoriceLane.PubSub,
  "inventory:updates",
  {:inventory_updated, item.id}
)
```

### 5. Create Admin Component Directory Structure

```
lib/licorice_lane_web/live/admin/
├── admin_live.ex (main live view - simplified)
├── dashboard_component.ex
├── inventory_component.ex
├── bookings_component.ex
└── clients_component.ex
```

### 6. Dashboard Component (`dashboard_component.ex`)

**LiveComponent with:**
- Uses assigns for:
  - `total_bookings` count
  - `low_stock_items` count (for stat card)
- Uses streams for:
  - `low_stock_items` (detailed list)
  - `recent_bookings` (recent rentals)
- Subscribe to `"inventory:updates"` PubSub topic in `update/2`
- `handle_info` to refresh low_stock_items on inventory changes

**Stats to Display:**
- ~~Total Inventory Items~~ (REMOVED)
- Total Bookings (count from Rentals.list_rentals)
- ~~Revenue Today~~ (REMOVED)
- Low Stock Items (count from Inventory.list_low_stock_items)

**Sections:**
- Recent Bookings table (from Rentals.list_recent_rentals)
  - Show: booking_id, customer name, event_type, total, status
- Low Stock Items list (from Inventory.list_low_stock_items)
  - Show: item name, category, current_stock, min_stock

### 7. Inventory Component (`inventory_component.ex`)

**LiveComponent with:**
- Stream all items from `Inventory.list_items/0`
- Search and category filtering (similar to inventory_live.ex)
- Display per-warehouse quantities using `Inventory.get_warehouse_quantities/1`
- Table columns: Item Name, Category, Warehouse Quantities, Total Stock, Price, Actions
- Actions: Edit (placeholder), Delete (placeholder)
- Include search bar and category dropdown

### 8. Bookings Component (`bookings_component.ex`)

**LiveComponent with:**
- Stream rentals from `Rentals.list_rentals/0`
- Filter tabs based on rental status:
  - "All Bookings"
  - "Upcoming" (future rented_at)
  - "Active" (status: active)
  - "Overdue" (return_by < now, status: active)
  - "Completed" (status: returned)
- Date range filter
- Table columns: Booking ID, Client, Event Type, Event Date, Rental Date, Return Date, Total, Status, Actions
- Status badges with colors
- Actions: View (placeholder), Update Status (placeholder)

### 9. Clients Component (`clients_component.ex`)

**LiveComponent with:**
- Stream customers from `Customers.list_customers/0`
- Search functionality (name, email, phone)
- Table columns: Name, Contact Person, Phone, Email, Total Rentals, Actions
- Actions: View (placeholder), Edit (placeholder)
- Simple list view for now

### 10. Refactor Main Admin Live View (`admin_live.ex`)

**Simplified to:**
- Handle tab switching (`:active_tab` assign)
- Render appropriate LiveComponent based on active tab
- Remove all `render_*` private functions
- Keep header and navigation tabs

```elixir
def render(assigns) do
  ~H"""
  <div class="min-h-screen bg-gray-50">
    <!-- Admin Header (keep as-is) -->
    <!-- Navigation Tabs (keep as-is) -->
    
    <div class="px-4 sm:px-6 lg:px-8 py-8">
      <%= if @active_tab == "dashboard" do %>
        <.live_component module={DashboardComponent} id="dashboard" />
      <% end %>
      
      <%= if @active_tab == "inventory" do %>
        <.live_component module={InventoryComponent} id="inventory" />
      <% end %>
      
      <%= if @active_tab == "bookings" do %>
        <.live_component module={BookingsComponent} id="bookings" />
      <% end %>
      
      <%= if @active_tab == "clients" do %>
        <.live_component module={ClientsComponent} id="clients" />
      <% end %>
    </div>
  </div>
  """
end
```

### 11. Update Inventory Live View (`inventory_live.ex`)

Add PubSub subscription for real-time updates:

```elixir
def mount(_params, _session, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(LicoriceLane.PubSub, "inventory:updates")
  end
  
  # existing mount code...
end

def handle_info({:inventory_updated, _item_id}, socket) do
  items = get_filtered_items(socket.assigns.selected_category, socket.assigns.search_term)
  {:noreply, stream(socket, :items, items, reset: true)}
end
```

### 12. Update Router (if needed)

Verify `lib/licorice_lane_web/router.ex` routes to correct location:
```elixir
live "/admin", Admin.AdminLive
```

## Design Decisions & Notes

### Warehouse Inventory Calculation
- Aggregate quantities from `items_locations` table where location is warehouse type
- Compare total warehouse quantity to `min_stock` for alerts
- Show per-warehouse breakdown in admin inventory tab

### Bookings = Rentals
- "Bookings" and "Rentals" refer to the same database entity
- Future bookings: `rented_at > current_datetime`
- Active rentals: `status == :active` and `rented_at <= current_datetime`

### PubSub Topics
- `"inventory:updates"` - broadcast on any inventory CRUD operation
- Only `InventoryLive` and admin dashboard subscribe initially
- Can expand to item-specific topics later: `"inventory:item:#{id}"`

### Status Badge Styling
Consider creating shared helper in CoreComponents:
```elixir
def status_badge(assigns) do
  ~H"""
  <span class={status_badge_class(@status)}>
    {String.capitalize(to_string(@status))}
  </span>
  """
end

defp status_badge_class(:pending), do: "bg-yellow-100 text-yellow-800 ..."
defp status_badge_class(:active), do: "bg-blue-100 text-blue-800 ..."
# etc.
```

## Further Considerations

1. **Seeds Data** - Update `priv/repo/seeds.exs` to include:
   - `event_type` values for rentals
   - `min_stock` values for items
   - Ensures testing of new features

2. **Bulk Items** - Removed from schema
   - Inventory calculations use `items_locations` table
   - Quantities aggregated across warehouse locations

3. **Future Edit Forms** - Components have placeholder actions
   - Add TODO comments for form implementation
   - Consider modal vs separate page for editing

4. **Error Handling** - Add proper error handling in context functions
   - Return `{:ok, result}` or `{:error, reason}` patterns
   - Handle nil cases in LiveComponents

5. **Performance** - Monitor query performance
   - Consider adding database indexes if needed
   - Use `limit` on recent queries
   - Paginate large lists in future iterations

## Testing Checklist

- [ ] Migration runs successfully
- [ ] Schemas validate with new fields
- [ ] Context functions return correct data
- [ ] Dashboard component displays real stats
- [ ] Inventory component shows per-warehouse quantities
- [ ] Bookings component filters work correctly
- [ ] Clients component displays all customers
- [ ] Tab switching works in admin live view
- [ ] PubSub updates reflect in inventory_live
- [ ] PubSub updates reflect in admin dashboard
- [ ] Low stock alerts trigger correctly
- [ ] Seeds file populates test data properly

## Implementation Order

1. Migration + Schema updates (test immediately)
2. Context modules (Rentals, Customers, extend Inventory)
3. Create component directory and files
4. Implement dashboard component
5. Implement inventory component  
6. Implement bookings component
7. Implement clients component
8. Refactor main admin_live.ex
9. Add PubSub to inventory_live.ex
10. Update seeds.exs with new fields
11. Test all functionality
12. Add TODOs for future form implementations
