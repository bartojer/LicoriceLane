defmodule LicoriceLane.Locations.LocationHistory do
  use Ecto.Schema
  import Ecto.Changeset

  schema "location_history" do
    field :quantity, :integer
    field :ts, :utc_datetime

    belongs_to :item, LicoriceLane.Items.Item
    belongs_to :from_location, LicoriceLane.Locations.Location
    belongs_to :to_location, LicoriceLane.Locations.Location
    belongs_to :rental, LicoriceLane.Rentals.Rental

    # field :item_id, :id
    # field :from_location_id, :id
    # field :to_location_id, :id
    # field :rental_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(location_history, attrs) do
    location_history
    |> cast(attrs, [:quantity, :ts, :item_id, :from_location_id, :to_location_id, :rental_id])
    |> validate_required([:quantity, :ts, :item_id])
  end
end
