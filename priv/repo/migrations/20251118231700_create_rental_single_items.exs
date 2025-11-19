defmodule LicoriceLane.Repo.Migrations.CreateRentalSingleItems do
  use Ecto.Migration

  def change do
    create table(:rental_single_items) do
      add :rental_id, references(:rentals, on_delete: :nothing), null: false
      add :single_item_id, references(:single_items, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:rental_single_items, [:rental_id])
    create index(:rental_single_items, [:single_item_id])
    create unique_index(:rental_single_items, [:rental_id, :single_item_id])
  end
end
