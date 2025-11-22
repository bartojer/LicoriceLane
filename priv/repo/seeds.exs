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
alias LicoriceLane.{Customer, Location, Item, SingleItem, Rental}
alias LicoriceLane.{ItemsLocation, RentalSingleItem, RentalBulkItem, LocationHistory}

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
customer1 =
  Repo.insert!(%Customer{
    name: "Sunshine Events Co.",
    phone: "555-0123",
    email: "events@sunshine.com",
    contact_person: "Sarah Johnson",
    billing_address: "123 Main Street, Springfield, IL 62701",
    notes: "Preferred customer - always pays on time"
  })

customer2 =
  Repo.insert!(%Customer{
    name: "Happy Party Planners",
    phone: "555-0456",
    email: "info@happyparty.com",
    contact_person: "Mike Chen",
    billing_address: "456 Oak Avenue, Springfield, IL 62702",
    notes: "Requires 24-hour notice for pickups"
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
    name: "Sunshine Events - Downtown Venue",
    location_type: :customer,
    customer_id: customer1.id
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
    image_path: "images/placeholder.png"
  })

item_table =
  Repo.insert!(%Item{
    name: "Round Table - 60 inch",
    description: "Round banquet table, seats 8-10 guests comfortably",
    category: :tableware,
    item_type: :single,
    rental_price: Decimal.new("15.00"),
    image_path: "images/placeholder.png"
  })

item_chandelier =
  Repo.insert!(%Item{
    name: "Crystal Chandelier",
    description: "Stunning crystal chandelier centerpiece for luxury events",
    category: :electric_light,
    item_type: :single,
    rental_price: Decimal.new("125.00"),
    image_path: "images/placeholder.png"
  })

item_arch =
  Repo.insert!(%Item{
    name: "Wedding Arch - White",
    description: "Beautiful white wooden wedding arch with floral decorations",
    category: :tableware,
    item_type: :single,
    rental_price: Decimal.new("85.00"),
    image_path: "images/placeholder.png"
  })

# Bulk Items (quantity-based rental items)
item_napkins =
  Repo.insert!(%Item{
    name: "Linen Napkins - White",
    description: "Premium white linen napkins, sold in sets of 10",
    category: :linen,
    item_type: :bulk,
    rental_price: Decimal.new("1.25"),
    image_path: "images/placeholder.png"
  })

item_plates =
  Repo.insert!(%Item{
    name: "Dinner Plates - White Porcelain",
    description: "Classic white porcelain dinner plates, 10-inch diameter",
    category: :tableware,
    item_type: :bulk,
    rental_price: Decimal.new("2.00"),
    image_path: "images/placeholder.png"
  })

item_glassware =
  Repo.insert!(%Item{
    name: "Wine Glasses - Crystal",
    description: "Elegant crystal wine glasses, 12 oz capacity",
    category: :tableware,
    item_type: :bulk,
    rental_price: Decimal.new("1.75"),
    image_path: "images/placeholder.png"
  })

item_tablecloths =
  Repo.insert!(%Item{
    name: "Tablecloths - Ivory",
    description: "Ivory polyester tablecloths, 90x132 inch for rectangular tables",
    category: :linen,
    item_type: :bulk,
    rental_price: Decimal.new("8.00"),
    image_path: "images/placeholder.png"
  })

IO.puts("Creating single item instances...")

# Single Item instances (physical items)
# Note: SingleItem uses the Item's ID as its primary key, so each single item needs its own Item entry

# Additional chair item for the second physical chair
item_chair2 =
  Repo.insert!(%Item{
    name: "Chiavari Chair - Gold",
    description: "Elegant gold chiavari chair, perfect for weddings and formal events",
    category: :tableware,
    item_type: :single,
    rental_price: Decimal.new("8.50"),
    image_path: "images/placeholder.png"
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
    location_id: location2.id
  })

_single_table1 =
  Repo.insert!(%SingleItem{
    id: item_table.id,
    condition: "Excellent",
    status: :available,
    location_id: location1.id
  })

_single_chandelier1 =
  Repo.insert!(%SingleItem{
    id: item_chandelier.id,
    condition: "Excellent",
    status: :available,
    location_id: location1.id
  })

single_arch1 =
  Repo.insert!(%SingleItem{
    id: item_arch.id,
    condition: "Good",
    status: :rented,
    location_id: location2.id
  })

IO.puts("Creating items_locations (bulk item inventory)...")

# Items Locations (bulk item quantities at locations)
Repo.insert!(%ItemsLocation{
  item_id: item_napkins.id,
  location_id: location1.id,
  quantity: 500
})

Repo.insert!(%ItemsLocation{
  item_id: item_napkins.id,
  location_id: location2.id,
  quantity: 100
})

Repo.insert!(%ItemsLocation{
  item_id: item_plates.id,
  location_id: location1.id,
  quantity: 300
})

Repo.insert!(%ItemsLocation{
  item_id: item_glassware.id,
  location_id: location1.id,
  quantity: 250
})

Repo.insert!(%ItemsLocation{
  item_id: item_tablecloths.id,
  location_id: location1.id,
  quantity: 75
})

Repo.insert!(%ItemsLocation{
  item_id: item_tablecloths.id,
  location_id: location2.id,
  quantity: 15
})

IO.puts("Creating rentals...")

# Rentals
rental1 =
  Repo.insert!(%Rental{
    customer_id: customer1.id,
    rented_at: ~U[2025-11-15 10:00:00Z],
    return_by: ~U[2025-11-22 18:00:00Z],
    status: :active
  })

rental2 =
  Repo.insert!(%Rental{
    customer_id: customer2.id,
    rented_at: ~U[2025-11-10 14:00:00Z],
    return_by: ~U[2025-11-17 12:00:00Z],
    status: :late
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
  rental_id: rental2.id,
  item_id: item_plates.id,
  quantity: 50
})

Repo.insert!(%RentalBulkItem{
  rental_id: rental2.id,
  item_id: item_glassware.id,
  quantity: 50
})

IO.puts("Creating location history...")

# Location History (tracking item movements)
Repo.insert!(%LocationHistory{
  item_id: item_napkins.id,
  from_location_id: location1.id,
  to_location_id: location2.id,
  quantity: 100,
  rental_id: rental1.id,
  ts: ~U[2025-11-15 10:00:00Z]
})

Repo.insert!(%LocationHistory{
  item_id: item_tablecloths.id,
  from_location_id: location1.id,
  to_location_id: location2.id,
  quantity: 15,
  rental_id: rental1.id,
  ts: ~U[2025-11-15 10:15:00Z]
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
