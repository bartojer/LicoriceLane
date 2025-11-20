defmodule LicoriceLane.Rental do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rentals" do
    field :status, Ecto.Enum,
      values: [:active, :returned, :late, :cancelled],
      default: :active

    field :rented_at, :utc_datetime
    field :return_by, :utc_datetime
    field :returned_at, :utc_datetime

    belongs_to :customer, LicoriceLane.Customer
    has_many :rental_single_items, LicoriceLane.RentalSingleItem
    has_many :rental_bulk_items, LicoriceLane.RentalBulkItem

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(rental, attrs) do
    rental
    |> cast(attrs, [:customer_id, :rented_at, :return_by, :returned_at, :status])
    |> validate_required([:customer_id, :rented_at, :return_by, :status])
  end
end
