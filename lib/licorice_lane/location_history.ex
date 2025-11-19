defmodule LicoriceLane.LocationHistory do
  use Ecto.Schema
  import Ecto.Changeset

  schema "location_history" do
    field :quantity, :integer
    field :ts, :utc_datetime
    field :item_id, :id
    field :from_location_id, :id
    field :to_location_id, :id
    field :rental_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(location_history, attrs) do
    location_history
    |> cast(attrs, [:quantity, :ts])
    |> validate_required([:quantity, :ts])
  end
end
