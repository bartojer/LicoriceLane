defmodule LicoriceLane.Repo.Migrations.CreateCustomers do
  use Ecto.Migration

  def change do
    create table(:customers) do
      add :name, :string, null: false
      add :phone, :string
      add :email, :string
      add :contact_person, :string
      add :billing_address, :text
      add :notes, :text

      timestamps(type: :utc_datetime)
    end
  end
end
