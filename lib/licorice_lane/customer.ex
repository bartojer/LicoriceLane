defmodule LicoriceLane.Customer do
  use Ecto.Schema
  import Ecto.Changeset

  schema "customers" do
    field :name, :string
    field :phone, :string
    field :email, :string
    field :contact_person, :string
    field :billing_address, :string
    field :notes, :string

    has_many :locations, LicoriceLane.Location

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(customer, attrs) do
    customer
    |> cast(attrs, [:name, :phone, :email, :contact_person, :billing_address, :notes])
    |> validate_required([:name, :phone, :email, :contact_person, :billing_address, :notes])
  end
end
