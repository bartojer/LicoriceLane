defmodule LicoriceLane.Repo.Migrations.AddEventTypeToRentalsAndMinStockToItems do
  use Ecto.Migration

  def change do
    alter table(:rentals) do
      add :event_type, :string
      add :event_date, :utc_datetime
    end

    alter table(:items) do
      add :min_stock, :integer, default: 10, null: false
    end
  end
end
