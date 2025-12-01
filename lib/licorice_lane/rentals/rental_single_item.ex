defmodule LicoriceLane.Rentals.RentalSingleItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rental_single_items" do
    belongs_to :rental, LicoriceLane.Rentals.Rental
    belongs_to :single_item, LicoriceLane.Items.SingleItem

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(rental_single_item, attrs) do
    rental_single_item
    |> cast(attrs, [:rental_id, :single_item])
    |> validate_required([:rental_id, :single_item])
  end
end
