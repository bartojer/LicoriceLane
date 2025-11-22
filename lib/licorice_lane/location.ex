defmodule LicoriceLane.Location do
  use Ecto.Schema
  import Ecto.Changeset

  schema "locations" do
    field :name, :string
    field :location_type, Ecto.Enum, values: [:customer, :warehouse], default: :warehouse

    belongs_to :customer, LicoriceLane.Customer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(location, attrs) do
    location
    |> cast(attrs, [:name, :location_type, :customer_id])
    |> validate_required([:name, :location_type])
  end
end
