defmodule LicoriceLane.Repo.Migrations.AddLocationTypeToLocations do
  use Ecto.Migration

  def change do
    alter table(:locations) do
      add :location_type, :string, null: false, default: "warehouse"
    end
  end
end
