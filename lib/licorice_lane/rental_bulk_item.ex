defmodule LicoriceLane.RentalBulkItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rental_bulk_items" do
    field :quantity, :integer
    field :rental_id, :id
    field :item_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(rental_bulk_item, attrs) do
    rental_bulk_item
    |> cast(attrs, [:quantity])
    |> validate_required([:quantity])
  end
end
