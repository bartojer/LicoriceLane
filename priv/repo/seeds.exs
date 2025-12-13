# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     LicoriceLane.Repo.insert!(%LicoriceLane.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

import Ecto.Query

alias LicoriceLane.Repo
alias LicoriceLane.Customers.Customer
alias LicoriceLane.Locations.{Location, ItemsLocation, LocationHistory}
alias LicoriceLane.Items.{Item, SingleItem}
alias LicoriceLane.Rentals.{Rental, RentalSingleItem, RentalBulkItem}

# Clear existing data (optional - comment out if you want to keep existing data)
Repo.delete_all(LocationHistory)
Repo.delete_all(RentalBulkItem)
Repo.delete_all(RentalSingleItem)
Repo.delete_all(Rental)
Repo.delete_all(SingleItem)
Repo.delete_all(ItemsLocation)
Repo.delete_all(Item)
Repo.delete_all(Location)
Repo.delete_all(Customer)

IO.puts("Creating customers...")

# Customers
{:ok, customer1} =
  LicoriceLane.Customers.create_customer(%{
    name: "Sunshine Events Co.",
    phone: "555-0123",
    email: "events@sunshine.com",
    contact_person: "Sarah Johnson",
    billing_address: "123 Main Street, Springfield, IL 62701",
    notes: "Preferred customer - always pays on time"
  })

{:ok, customer2} =
  LicoriceLane.Customers.create_customer(%{
    name: "Happy Party Planners",
    phone: "555-0456",
    email: "info@happyparty.com",
    contact_person: "Mike Chen",
    billing_address: "456 Oak Avenue, Springfield, IL 62702",
    notes: "Requires 24-hour notice for pickups"
  })

{:ok, customer3} =
  LicoriceLane.Customers.create_customer(%{
    name: "Elite Weddings LLC",
    phone: "555-0789",
    email: "coordinator@eliteweddings.com",
    contact_person: "Amanda Rodriguez",
    billing_address: "789 Elm Street, Springfield, IL 62703",
    notes: "High-end wedding specialist"
  })

{:ok, customer4} =
  LicoriceLane.Customers.create_customer(%{
    name: "Corporate Events Direct",
    phone: "555-0321",
    email: "bookings@corpevents.com",
    contact_person: "James Wilson",
    billing_address: "321 Business Park Dr, Springfield, IL 62704",
    notes: "Regular corporate client - monthly events"
  })

{:ok, customer5} =
  LicoriceLane.Customers.create_customer(%{
    name: "Birthday Bash Productions",
    phone: "555-0654",
    email: "party@birthdaybash.com",
    contact_person: "Lisa Martinez",
    billing_address: "654 Party Lane, Springfield, IL 62705",
    notes: "Specializes in children's birthday parties"
  })

{:ok, customer6} =
  LicoriceLane.Customers.create_customer(%{
    name: "Gala Affairs",
    phone: "555-0987",
    email: "info@galaaffairs.com",
    contact_person: "Robert Thompson",
    billing_address: "987 Grand Avenue, Springfield, IL 62706",
    notes: "Large-scale event organizer"
  })

IO.puts("Creating locations...")

# Locations
location1 =
  Repo.insert!(%Location{
    name: "Main Warehouse",
    location_type: :warehouse,
    customer_id: nil
  })

location2 =
  Repo.insert!(%Location{
    name: "North Side Warehouse",
    location_type: :warehouse,
    customer_id: nil
  })

location3 =
  Repo.insert!(%Location{
    name: "Sunshine Events - Downtown Venue",
    location_type: :customer,
    customer_id: customer1.id
  })

location4 =
  Repo.insert!(%Location{
    name: "Happy Party Planners - Office",
    location_type: :customer,
    customer_id: customer2.id
  })

location5 =
  Repo.insert!(%Location{
    name: "Elite Weddings - Storage Facility",
    location_type: :customer,
    customer_id: customer3.id
  })

location6 =
  Repo.insert!(%Location{
    name: "Corporate Events Direct - Conference Center",
    location_type: :customer,
    customer_id: customer4.id
  })

IO.puts("Creating items...")

# Single Items (individual rental items)
item_chair =
  Repo.insert!(%Item{
    name: "Chiavari Chair - Gold",
    description: "Elegant gold chiavari chair, perfect for weddings and formal events",
    category: :tableware,
    item_type: :single,
    rental_price: Decimal.new("8.50"),
    image_path: "images/placeholder.png",
    min_stock: 0
  })

item_table =
  Repo.insert!(%Item{
    name: "Round Table - 60 inch",
    description: "Round banquet table, seats 8-10 guests comfortably",
    category: :tableware,
    item_type: :single,
    rental_price: Decimal.new("15.00"),
    image_path: "images/placeholder.png",
    min_stock: 0
  })

item_chandelier =
  Repo.insert!(%Item{
    name: "Crystal Chandelier",
    description: "Stunning crystal chandelier centerpiece for luxury events",
    category: :electric_light,
    item_type: :single,
    rental_price: Decimal.new("125.00"),
    image_path: "images/placeholder.png",
    min_stock: 0
  })

item_arch =
  Repo.insert!(%Item{
    name: "Wedding Arch - White",
    description: "Beautiful white wooden wedding arch with floral decorations",
    category: :tableware,
    item_type: :single,
    rental_price: Decimal.new("85.00"),
    image_path: "images/placeholder.png",
    min_stock: 0
  })

# Bulk Items (quantity-based rental items)
item_napkins =
  Repo.insert!(%Item{
    name: "Linen Napkins - White",
    description: "Premium white linen napkins, sold in sets of 10",
    category: :linen,
    item_type: :bulk,
    rental_price: Decimal.new("1.25"),
    image_path: "images/placeholder.png",
    min_stock: 50
  })

item_plates =
  Repo.insert!(%Item{
    name: "Dinner Plates - White Porcelain",
    description: "Classic white porcelain dinner plates, 10-inch diameter",
    category: :tableware,
    item_type: :bulk,
    rental_price: Decimal.new("2.00"),
    image_path: "images/placeholder.png",
    min_stock: 100
  })

item_glassware =
  Repo.insert!(%Item{
    name: "Wine Glasses - Crystal",
    description: "Elegant crystal wine glasses, 12 oz capacity",
    category: :tableware,
    item_type: :bulk,
    rental_price: Decimal.new("1.75"),
    image_path: "images/placeholder.png",
    min_stock: 75
  })

item_tablecloths =
  Repo.insert!(%Item{
    name: "Tablecloths - Ivory",
    description: "Ivory polyester tablecloths, 90x132 inch for rectangular tables",
    category: :linen,
    item_type: :bulk,
    rental_price: Decimal.new("8.00"),
    image_path: "images/placeholder.png",
    min_stock: 20
  })

IO.puts("Creating single item instances...")

# Single Item instances (physical items)
# Note: SingleItem uses the Item's ID as its primary key, so each single item needs its own Item entry

# Additional chair items
item_chair2 =
  Repo.insert!(%Item{
    name: "Chiavari Chair - Gold",
    description: "Elegant gold chiavari chair, perfect for weddings and formal events",
    category: :tableware,
    item_type: :single,
    rental_price: Decimal.new("8.50"),
    image_path: "images/placeholder.png",
    min_stock: 0
  })

item_chair3 =
  Repo.insert!(%Item{
    name: "Chiavari Chair - Gold",
    description: "Elegant gold chiavari chair, perfect for weddings and formal events",
    category: :tableware,
    item_type: :single,
    rental_price: Decimal.new("8.50"),
    image_path: "images/placeholder.png",
    min_stock: 0
  })

item_chair4 =
  Repo.insert!(%Item{
    name: "Chiavari Chair - Gold",
    description: "Elegant gold chiavari chair, perfect for weddings and formal events",
    category: :tableware,
    item_type: :single,
    rental_price: Decimal.new("8.50"),
    image_path: "images/placeholder.png",
    min_stock: 0
  })

# Additional table items
item_table2 =
  Repo.insert!(%Item{
    name: "Round Table - 60 inch",
    description: "Round banquet table, seats 8-10 guests comfortably",
    category: :tableware,
    item_type: :single,
    rental_price: Decimal.new("15.00"),
    image_path: "images/placeholder.png",
    min_stock: 0
  })

item_table3 =
  Repo.insert!(%Item{
    name: "Round Table - 60 inch",
    description: "Round banquet table, seats 8-10 guests comfortably",
    category: :tableware,
    item_type: :single,
    rental_price: Decimal.new("15.00"),
    image_path: "images/placeholder.png",
    min_stock: 0
  })

# Additional chandeliers
item_chandelier2 =
  Repo.insert!(%Item{
    name: "Crystal Chandelier",
    description: "Stunning crystal chandelier centerpiece for luxury events",
    category: :electric_light,
    item_type: :single,
    rental_price: Decimal.new("125.00"),
    image_path: "images/placeholder.png",
    min_stock: 0
  })

# Additional arches
item_arch2 =
  Repo.insert!(%Item{
    name: "Wedding Arch - White",
    description: "Beautiful white wooden wedding arch with floral decorations",
    category: :tableware,
    item_type: :single,
    rental_price: Decimal.new("85.00"),
    image_path: "images/placeholder.png",
    min_stock: 0
  })

_single_chair1 =
  Repo.insert!(%SingleItem{
    id: item_chair.id,
    condition: "Excellent",
    status: :available,
    location_id: location1.id
  })

single_chair2 =
  Repo.insert!(%SingleItem{
    id: item_chair2.id,
    condition: "Good",
    status: :rented,
    location_id: location3.id
  })

_single_chair3 =
  Repo.insert!(%SingleItem{
    id: item_chair3.id,
    condition: "Excellent",
    status: :available,
    location_id: location2.id
  })

_single_chair4 =
  Repo.insert!(%SingleItem{
    id: item_chair4.id,
    condition: "Good",
    status: :available,
    location_id: location1.id
  })

_single_table1 =
  Repo.insert!(%SingleItem{
    id: item_table.id,
    condition: "Excellent",
    status: :available,
    location_id: location1.id
  })

single_table2 =
  Repo.insert!(%SingleItem{
    id: item_table2.id,
    condition: "Good",
    status: :rented,
    location_id: location4.id
  })

_single_table3 =
  Repo.insert!(%SingleItem{
    id: item_table3.id,
    condition: "Excellent",
    status: :available,
    location_id: location2.id
  })

_single_chandelier1 =
  Repo.insert!(%SingleItem{
    id: item_chandelier.id,
    condition: "Excellent",
    status: :available,
    location_id: location1.id
  })

single_chandelier2 =
  Repo.insert!(%SingleItem{
    id: item_chandelier2.id,
    condition: "Good",
    status: :rented,
    location_id: location5.id
  })

single_arch1 =
  Repo.insert!(%SingleItem{
    id: item_arch.id,
    condition: "Good",
    status: :rented,
    location_id: location3.id
  })

_single_arch2 =
  Repo.insert!(%SingleItem{
    id: item_arch2.id,
    condition: "Excellent",
    status: :available,
    location_id: location2.id
  })

IO.puts("Creating items_locations (bulk item inventory)...")

# Items Locations (bulk item quantities at locations)
Repo.insert!(%ItemsLocation{
  item_id: item_napkins.id,
  location_id: location1.id,
  quantity: 800
})

Repo.insert!(%ItemsLocation{
  item_id: item_napkins.id,
  location_id: location2.id,
  quantity: 300
})

Repo.insert!(%ItemsLocation{
  item_id: item_napkins.id,
  location_id: location3.id,
  quantity: 100
})

Repo.insert!(%ItemsLocation{
  item_id: item_plates.id,
  location_id: location1.id,
  quantity: 500
})

Repo.insert!(%ItemsLocation{
  item_id: item_plates.id,
  location_id: location2.id,
  quantity: 200
})

Repo.insert!(%ItemsLocation{
  item_id: item_glassware.id,
  location_id: location1.id,
  quantity: 400
})

Repo.insert!(%ItemsLocation{
  item_id: item_glassware.id,
  location_id: location2.id,
  quantity: 150
})

Repo.insert!(%ItemsLocation{
  item_id: item_tablecloths.id,
  location_id: location1.id,
  quantity: 100
})

Repo.insert!(%ItemsLocation{
  item_id: item_tablecloths.id,
  location_id: location2.id,
  quantity: 40
})

Repo.insert!(%ItemsLocation{
  item_id: item_tablecloths.id,
  location_id: location3.id,
  quantity: 15
})

IO.puts("Creating rentals...")

# Rentals
rental1 =
  Repo.insert!(%Rental{
    customer_id: customer1.id,
    rented_at: ~U[2025-11-15 10:00:00Z],
    return_by: ~U[2025-11-22 18:00:00Z],
    event_date: ~U[2025-11-20 17:00:00Z],
    event_type: :wedding,
    status: :active
  })

rental2 =
  Repo.insert!(%Rental{
    customer_id: customer2.id,
    rented_at: ~U[2025-11-10 14:00:00Z],
    return_by: ~U[2025-11-17 12:00:00Z],
    event_date: ~U[2025-11-16 19:00:00Z],
    event_type: :birthday,
    status: :late
  })

rental3 =
  Repo.insert!(%Rental{
    customer_id: customer3.id,
    rented_at: ~U[2025-11-20 09:00:00Z],
    return_by: ~U[2025-11-27 16:00:00Z],
    event_date: ~U[2025-11-26 15:00:00Z],
    event_type: :wedding,
    status: :active
  })

rental4 =
  Repo.insert!(%Rental{
    customer_id: customer4.id,
    rented_at: ~U[2025-11-05 08:00:00Z],
    return_by: ~U[2025-11-08 17:00:00Z],
    returned_at: ~U[2025-11-08 15:30:00Z],
    event_date: ~U[2025-11-07 09:00:00Z],
    event_type: :corporate,
    status: :returned
  })

rental5 =
  Repo.insert!(%Rental{
    customer_id: customer5.id,
    rented_at: ~U[2025-11-22 11:00:00Z],
    return_by: ~U[2025-11-24 18:00:00Z],
    event_date: ~U[2025-11-23 14:00:00Z],
    event_type: :birthday,
    status: :active
  })

rental6 =
  Repo.insert!(%Rental{
    customer_id: customer6.id,
    rented_at: ~U[2025-11-12 10:00:00Z],
    return_by: ~U[2025-11-18 12:00:00Z],
    returned_at: ~U[2025-11-19 10:00:00Z],
    event_date: ~U[2025-11-17 18:00:00Z],
    event_type: :corporate,
    status: :returned
  })

IO.puts("Creating rental items...")

# Rental Single Items (linking single items to rentals)
Repo.insert!(%RentalSingleItem{
  rental_id: rental1.id,
  single_item_id: single_chair2.id
})

Repo.insert!(%RentalSingleItem{
  rental_id: rental1.id,
  single_item_id: single_arch1.id
})

Repo.insert!(%RentalSingleItem{
  rental_id: rental2.id,
  single_item_id: single_table2.id
})

Repo.insert!(%RentalSingleItem{
  rental_id: rental3.id,
  single_item_id: single_chandelier2.id
})

# Rental Bulk Items (linking bulk items to rentals with quantities)
Repo.insert!(%RentalBulkItem{
  rental_id: rental1.id,
  item_id: item_napkins.id,
  quantity: 100
})

Repo.insert!(%RentalBulkItem{
  rental_id: rental1.id,
  item_id: item_tablecloths.id,
  quantity: 15
})

Repo.insert!(%RentalBulkItem{
  rental_id: rental1.id,
  item_id: item_plates.id,
  quantity: 80
})

Repo.insert!(%RentalBulkItem{
  rental_id: rental2.id,
  item_id: item_plates.id,
  quantity: 50
})

Repo.insert!(%RentalBulkItem{
  rental_id: rental2.id,
  item_id: item_glassware.id,
  quantity: 50
})

Repo.insert!(%RentalBulkItem{
  rental_id: rental3.id,
  item_id: item_napkins.id,
  quantity: 150
})

Repo.insert!(%RentalBulkItem{
  rental_id: rental3.id,
  item_id: item_tablecloths.id,
  quantity: 20
})

Repo.insert!(%RentalBulkItem{
  rental_id: rental3.id,
  item_id: item_glassware.id,
  quantity: 100
})

Repo.insert!(%RentalBulkItem{
  rental_id: rental4.id,
  item_id: item_plates.id,
  quantity: 120
})

Repo.insert!(%RentalBulkItem{
  rental_id: rental4.id,
  item_id: item_napkins.id,
  quantity: 120
})

Repo.insert!(%RentalBulkItem{
  rental_id: rental5.id,
  item_id: item_napkins.id,
  quantity: 60
})

Repo.insert!(%RentalBulkItem{
  rental_id: rental5.id,
  item_id: item_plates.id,
  quantity: 40
})

Repo.insert!(%RentalBulkItem{
  rental_id: rental6.id,
  item_id: item_glassware.id,
  quantity: 80
})

Repo.insert!(%RentalBulkItem{
  rental_id: rental6.id,
  item_id: item_tablecloths.id,
  quantity: 25
})

IO.puts("Creating location history...")

# Location History (tracking item movements)
Repo.insert!(%LocationHistory{
  item_id: item_napkins.id,
  from_location_id: location1.id,
  to_location_id: location3.id,
  quantity: 100,
  rental_id: rental1.id,
  ts: ~U[2025-11-15 10:00:00Z]
})

Repo.insert!(%LocationHistory{
  item_id: item_tablecloths.id,
  from_location_id: location1.id,
  to_location_id: location3.id,
  quantity: 15,
  rental_id: rental1.id,
  ts: ~U[2025-11-15 10:15:00Z]
})

Repo.insert!(%LocationHistory{
  item_id: item_plates.id,
  from_location_id: location1.id,
  to_location_id: location3.id,
  quantity: 80,
  rental_id: rental1.id,
  ts: ~U[2025-11-15 10:20:00Z]
})

Repo.insert!(%LocationHistory{
  item_id: item_plates.id,
  from_location_id: location1.id,
  to_location_id: location4.id,
  quantity: 50,
  rental_id: rental2.id,
  ts: ~U[2025-11-10 14:00:00Z]
})

Repo.insert!(%LocationHistory{
  item_id: item_glassware.id,
  from_location_id: location1.id,
  to_location_id: location4.id,
  quantity: 50,
  rental_id: rental2.id,
  ts: ~U[2025-11-10 14:10:00Z]
})

Repo.insert!(%LocationHistory{
  item_id: item_napkins.id,
  from_location_id: location2.id,
  to_location_id: location5.id,
  quantity: 150,
  rental_id: rental3.id,
  ts: ~U[2025-11-20 09:00:00Z]
})

Repo.insert!(%LocationHistory{
  item_id: item_tablecloths.id,
  from_location_id: location2.id,
  to_location_id: location5.id,
  quantity: 20,
  rental_id: rental3.id,
  ts: ~U[2025-11-20 09:15:00Z]
})

Repo.insert!(%LocationHistory{
  item_id: item_glassware.id,
  from_location_id: location2.id,
  to_location_id: location5.id,
  quantity: 100,
  rental_id: rental3.id,
  ts: ~U[2025-11-20 09:20:00Z]
})

# History for returned rental 4
Repo.insert!(%LocationHistory{
  item_id: item_plates.id,
  from_location_id: location1.id,
  to_location_id: location6.id,
  quantity: 120,
  rental_id: rental4.id,
  ts: ~U[2025-11-05 08:00:00Z]
})

Repo.insert!(%LocationHistory{
  item_id: item_napkins.id,
  from_location_id: location1.id,
  to_location_id: location6.id,
  quantity: 120,
  rental_id: rental4.id,
  ts: ~U[2025-11-05 08:10:00Z]
})

Repo.insert!(%LocationHistory{
  item_id: item_plates.id,
  from_location_id: location6.id,
  to_location_id: location1.id,
  quantity: 120,
  rental_id: rental4.id,
  ts: ~U[2025-11-08 15:30:00Z]
})

Repo.insert!(%LocationHistory{
  item_id: item_napkins.id,
  from_location_id: location6.id,
  to_location_id: location1.id,
  quantity: 120,
  rental_id: rental4.id,
  ts: ~U[2025-11-08 15:35:00Z]
})

IO.puts("Seed data created successfully!")
IO.puts("Summary:")
IO.puts("  - #{Repo.aggregate(Customer, :count)} customers")
IO.puts("  - #{Repo.aggregate(Location, :count)} locations")

IO.puts(
  "  - #{Repo.aggregate(Item, :count)} items (#{Repo.aggregate(from(i in Item, where: i.item_type == :single), :count)} single, #{Repo.aggregate(from(i in Item, where: i.item_type == :bulk), :count)} bulk)"
)

IO.puts("  - #{Repo.aggregate(SingleItem, :count)} single item instances")
IO.puts("  - #{Repo.aggregate(Rental, :count)} rentals")
IO.puts("  - #{Repo.aggregate(RentalSingleItem, :count)} rental single items")
IO.puts("  - #{Repo.aggregate(RentalBulkItem, :count)} rental bulk items")
IO.puts("  - #{Repo.aggregate(ItemsLocation, :count)} items_locations records")
IO.puts("  - #{Repo.aggregate(LocationHistory, :count)} location history records")
