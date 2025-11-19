defmodule LicoriceLane.Repo.Migrations.CreateRentals do
  use Ecto.Migration

  def change do
    create table(:rentals) do
      add :rented_at, :utc_datetime
      add :return_by, :utc_datetime
      add :status, :string
      add :customer_id, references(:customers, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:rentals, [:customer_id])
  end
end
