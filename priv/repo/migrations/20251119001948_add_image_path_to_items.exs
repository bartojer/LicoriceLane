defmodule LicoriceLane.Repo.Migrations.AddImagePathToItems do
  use Ecto.Migration

  def change do
    alter table(:items) do
      add :image_path, :string
    end
  end
end
