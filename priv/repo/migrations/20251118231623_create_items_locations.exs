defmodule LicoriceLane.Repo.Migrations.CreateItemsLocations do
  use Ecto.Migration

  def change do
    create table(:items_locations) do
      add :quantity, :integer, null: false, default: 0
      add :item_id, references(:items, on_delete: :nothing), null: false
      add :location_id, references(:locations, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:items_locations, [:item_id])
    create index(:items_locations, [:location_id])
    create unique_index(:items_locations, [:item_id, :location_id])
  end
end
