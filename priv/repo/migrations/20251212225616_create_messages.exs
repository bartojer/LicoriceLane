defmodule LicoriceLane.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :name, :string, null: false
      add :email, :binary, null: false
      add :phone, :binary
      add :message, :binary, null: false
      add :email_hash, :binary
      add :phone_hash, :binary
      add :status, :string, null: false, default: "new"
      add :admin_notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:status])
    create index(:messages, [:email_hash])
    create index(:messages, [:phone_hash])
    create index(:messages, [:inserted_at])
  end
end
