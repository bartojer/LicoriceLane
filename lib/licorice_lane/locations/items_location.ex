defmodule LicoriceLane.Locations.ItemsLocation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "items_locations" do
    field :quantity, :integer
    # field :item_id, :id
    # field :location_id, :id

    belongs_to :location, LicoriceLane.Locations.Location
    belongs_to :item, LicoriceLane.Items.Item

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(items_location, attrs) do
    items_location
    |> cast(attrs, [:quantity, :item_id, :location_id])
    |> validate_required([:quantity, :item_id, :location_id])
  end
end
