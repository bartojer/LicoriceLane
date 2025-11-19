defmodule LicoriceLane.Repo.Migrations.CreateRentalBulkItems do
  use Ecto.Migration

  def change do
    create table(:rental_bulk_items) do
      add :quantity, :integer, null: false, default: 1
      add :rental_id, references(:rentals, on_delete: :nothing), null: false
      add :item_id, references(:items, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:rental_bulk_items, [:rental_id])
    create index(:rental_bulk_items, [:item_id])
    create unique_index(:rental_bulk_items, [:rental_id, :item_id])
  end
end
