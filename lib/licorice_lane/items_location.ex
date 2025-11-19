defmodule LicoriceLane.ItemsLocation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "items_locations" do
    field :quantity, :integer
    field :item_id, :id
    field :location_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(items_location, attrs) do
    items_location
    |> cast(attrs, [:quantity])
    |> validate_required([:quantity])
  end
end
