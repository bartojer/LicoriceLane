defmodule LicoriceLane.RentalSingleItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rental_single_items" do

    field :rental_id, :id
    field :single_item_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(rental_single_item, attrs) do
    rental_single_item
    |> cast(attrs, [])
    |> validate_required([])
  end
end
