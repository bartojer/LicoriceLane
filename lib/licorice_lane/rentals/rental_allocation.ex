defmodule LicoriceLane.Rentals.RentalAllocation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rental_allocations" do
    field :quantity, :integer
    field :returned_quantity, :integer, default: 0
    belongs_to :rental, LicoriceLane.Rentals.Rental
    belongs_to :item, LicoriceLane.Items.Item
    belongs_to :source_location, LicoriceLane.Locations.Location
    timestamps(type: :utc_datetime)
  end

  def changeset(allocation, attrs) do
    allocation
    |> cast(attrs, [:rental_id, :item_id, :source_location_id, :quantity, :returned_quantity])
    |> validate_required([:rental_id, :item_id, :source_location_id, :quantity])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:returned_quantity, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:rental_id)
    |> foreign_key_constraint(:item_id)
    |> foreign_key_constraint(:source_location_id)
    |> unique_constraint([:rental_id, :item_id, :source_location_id])
    |> check_constraint(:quantity, name: :valid_allocation_quantities)
  end
end
