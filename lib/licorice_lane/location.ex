defmodule LicoriceLane.Location do
  use Ecto.Schema
  import Ecto.Changeset

  schema "locations" do
    field :name, :string

    belongs_to :customer, LicoriceLane.Customer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(location, attrs) do
    location
    |> cast(attrs, [:name, :customer_id])
    |> validate_required([:name])
  end
end
