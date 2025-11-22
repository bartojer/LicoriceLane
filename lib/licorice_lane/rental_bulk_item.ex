defmodule LicoriceLane.RentalBulkItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rental_bulk_items" do
    field :quantity, :integer
    belongs_to :rental, LicoriceLane.Rental
    belongs_to :item, LicoriceLane.Item

    # field :rental_id, :id
    # field :item_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(rental_bulk_item, attrs) do
    rental_bulk_item
    |> cast(attrs, [:quantity, :rental_id, :item_id])
    |> validate_required([:quantity, :rental_id, :item_id])
  end
end
