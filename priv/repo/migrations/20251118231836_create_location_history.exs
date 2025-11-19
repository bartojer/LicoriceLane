defmodule LicoriceLane.Repo.Migrations.CreateLocationHistory do
  use Ecto.Migration

  def change do
    create table(:location_history) do
      add :quantity, :integer, null: false, default: 1
      add :ts, :utc_datetime
      add :item_id, references(:items, on_delete: :nothing), null: false
      add :from_location_id, references(:locations, on_delete: :nothing)
      add :to_location_id, references(:locations, on_delete: :nothing)
      add :rental_id, references(:rentals, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:location_history, [:item_id])
    create index(:location_history, [:from_location_id])
    create index(:location_history, [:to_location_id])
    create index(:location_history, [:rental_id])
    create index(:location_history, [:item_id, :ts])
  end
end
