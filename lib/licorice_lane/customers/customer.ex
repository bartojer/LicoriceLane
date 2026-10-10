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
    |> validate_required([:name])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "has invalid format")
    |> validate_format(:phone, ~r/^\d{3}-\d{4}$/, message: "has invalid format")
    |> put_hashed_fields()
  end

  defp put_hashed_fields(changeset) do
    changeset
    |> maybe_put_hash(:email, :email_hash)
    |> maybe_put_hash(:phone, :phone_hash)
  end

  defp maybe_put_hash(changeset, source_field, hash_field) do
    value = get_field(changeset, source_field)

    # SHA256 hashes the current plaintext value on dump. Explicit clearing must also
    # clear the lookup column. Force changes because this type cannot compare with nil.
    if changed?(changeset, source_field) or (value && value != "") do
      force_change(changeset, hash_field, value)
    else
      changeset
    end
  end
end
