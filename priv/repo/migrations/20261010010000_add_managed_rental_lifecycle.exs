defmodule LicoriceLane.Repo.Migrations.AddManagedRentalLifecycle do
  use Ecto.Migration

  def change do
    alter table(:rentals) do
      add :inventory_managed, :boolean, null: false, default: false
      add :lifecycle_version, :integer, null: false, default: 0
      add :checked_out_at, :utc_datetime
      add :destination_location_id, references(:locations, on_delete: :nothing)
    end

    create table(:rental_allocations) do
      add :rental_id, references(:rentals, on_delete: :delete_all), null: false
      add :item_id, references(:items, on_delete: :nothing), null: false
      add :source_location_id, references(:locations, on_delete: :nothing), null: false
      add :quantity, :integer, null: false
      add :returned_quantity, :integer, null: false, default: 0
      timestamps(type: :utc_datetime)
    end

    create unique_index(:rental_allocations, [:rental_id, :item_id, :source_location_id])
    create index(:rental_allocations, [:item_id, :source_location_id])

    create constraint(:rental_allocations, :valid_allocation_quantities,
             check: "quantity > 0 AND returned_quantity >= 0 AND returned_quantity <= quantity"
           )

    create constraint(:rentals, :valid_lifecycle_version, check: "lifecycle_version >= 0")
  end
end
