defmodule LicoriceLane.Repo.Migrations.CreateSingleItems do
  use Ecto.Migration

  def change do
    create table(:single_items, primary_key: false) do
      add :id,
        references(:items, on_delete: :delete_all),
        primary_key: true

      add :condition, :string
      add :status, :string
      add :location_id, references(:locations, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:single_items, [:location_id])
  end
end
