defmodule LicoriceLane.Repo.Migrations.CreateItems do
  use Ecto.Migration

  def change do
    create table(:items) do
      add :name, :string, null: false
      add :description, :text
      add :item_type, :string, null: false
      add :rental_price, :decimal

      timestamps(type: :utc_datetime)
    end

    create index(:items, [:item_type])
  end
end
