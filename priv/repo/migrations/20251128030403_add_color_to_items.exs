defmodule LicoriceLane.Repo.Migrations.AddColorToItems do
  use Ecto.Migration

  def change do
    alter table(:items) do
      add :color, :string
    end
  end
end
