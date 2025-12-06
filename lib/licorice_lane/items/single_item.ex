defmodule LicoriceLane.Items.SingleItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: false}
  schema "single_items" do
    field :status, Ecto.Enum,
      values: [:available, :rented, :damaged],
      default: :available

    field :condition, :string

    belongs_to :location, LicoriceLane.Locations.Location

    belongs_to :item, LicoriceLane.Items.Item,
      foreign_key: :id,
      define_field: false

    has_many :rental_single_items, LicoriceLane.Rentals.RentalSingleItem

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(single_item, attrs) do
    single_item
    |> cast(attrs, [:id, :condition, :status, :location_id])
    |> validate_required([:id, :condition, :status, :location_id])
  end
end
