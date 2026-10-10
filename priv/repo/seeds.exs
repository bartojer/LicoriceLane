# Disposable development data. Replaces business records and keeps login accounts.
# Run after migrations with: mix run priv/repo/seeds.exs
Code.require_file("demo_seeds.exs", __DIR__)

sample = LicoriceLane.DemoSeeds.run()

IO.puts(
  "Sample data created: #{length(sample.customers)} customers, #{map_size(sample.items)} items, #{map_size(sample.rentals)} managed bookings."
)

IO.puts(
  "Bookings include reserved, active, partial return, overdue, returned and cancelled examples."
)
