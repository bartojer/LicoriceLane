defmodule LicoriceLane.Repo.Migrations.EncryptCustomerFields do
  use Ecto.Migration

  def up do
    # First, delete all existing customer data (test data only)
    execute "DELETE FROM customers"

    # Alter existing columns to binary type for encryption
    # Using USING clause to handle type conversion
    execute "ALTER TABLE customers ALTER COLUMN phone TYPE bytea USING phone::bytea"
    execute "ALTER TABLE customers ALTER COLUMN email TYPE bytea USING email::bytea"

    execute "ALTER TABLE customers ALTER COLUMN contact_person TYPE bytea USING contact_person::bytea"

    execute "ALTER TABLE customers ALTER COLUMN billing_address TYPE bytea USING billing_address::bytea"

    execute "ALTER TABLE customers ALTER COLUMN notes TYPE bytea USING notes::bytea"

    # Add hash columns for exact-match searching on email and phone
    alter table(:customers) do
      add :email_hash, :binary
      add :phone_hash, :binary
    end

    # Create indexes on hash columns for performance
    create index(:customers, [:email_hash])
    create index(:customers, [:phone_hash])
  end

  def down do
    # Remove hash columns
    drop index(:customers, [:email_hash])
    drop index(:customers, [:phone_hash])

    alter table(:customers) do
      remove :email_hash
      remove :phone_hash
    end

    # Revert columns back to string/text types
    alter table(:customers) do
      modify :phone, :string
      modify :email, :string
      modify :contact_person, :string
      modify :billing_address, :text
      modify :notes, :text
    end
  end
end
