defmodule LicoriceLane.Customers.Customer do
  use Ecto.Schema
  import Ecto.Changeset

  schema "customers" do
    field :name, :string
    field :phone, LicoriceLane.Encrypted.Binary
    field :email, LicoriceLane.Encrypted.Binary
    field :contact_person, LicoriceLane.Encrypted.Binary
    field :billing_address, LicoriceLane.Encrypted.Binary
    field :notes, LicoriceLane.Encrypted.Binary
    field :email_hash, Cloak.Ecto.SHA256
    field :phone_hash, Cloak.Ecto.SHA256

    has_many :locations, LicoriceLane.Locations.Location

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(customer, attrs) do
    customer
    |> cast(attrs, [:name, :phone, :email, :contact_person, :billing_address, :notes])
    |> validate_required([:name, :phone, :email, :contact_person, :billing_address, :notes])
    |> put_hashed_fields()
  end

  defp put_hashed_fields(changeset) do
    changeset
    |> maybe_put_hash(:email, :email_hash)
    |> maybe_put_hash(:phone, :phone_hash)
  end

  defp maybe_put_hash(changeset, source_field, hash_field) do
    # For new records, get from changes. For updates, try changes first, then fall back to existing data
    value =
      case fetch_change(changeset, source_field) do
        {:ok, val} when not is_nil(val) and val != "" ->
          val

        _ ->
          # For updates without changes to this field, use existing value
          case changeset.data do
            %{__meta__: %{state: :loaded}} -> Map.get(changeset.data, source_field)
            _ -> nil
          end
      end

    # Set hash field if we have a valid value
    # SHA256 type will automatically hash the plaintext value on dump
    # Use force_change to avoid the type's equal? check which fails with nil
    if value && value != "" do
      force_change(changeset, hash_field, value)
    else
      changeset
    end
  end
end
