defmodule LicoriceLane.Repo.Migrations.AddReturnedAtToRentals do
  use Ecto.Migration

  def change do
    alter table(:rentals) do
      add :returned_at, :utc_datetime
    end
  end
end
