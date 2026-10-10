defmodule LicoriceLane.Rentals.Rental do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rentals" do
    field :status, Ecto.Enum,
      values: [:reserved, :active, :returned, :late, :cancelled],
      default: :active

    field :event_type, Ecto.Enum, values: [:wedding, :corporate, :birthday]

    field :event_date, :utc_datetime
    field :rented_at, :utc_datetime
    field :return_by, :utc_datetime
    field :returned_at, :utc_datetime
    field :inventory_managed, :boolean, default: false
    field :lifecycle_version, :integer, default: 0
    field :checked_out_at, :utc_datetime
    field :destination_name, :string, virtual: true

    belongs_to :destination_location, LicoriceLane.Locations.Location
    has_many :allocations, LicoriceLane.Rentals.RentalAllocation

    belongs_to :customer, LicoriceLane.Customers.Customer
    has_many :rental_single_items, LicoriceLane.Rentals.RentalSingleItem
    has_many :rental_bulk_items, LicoriceLane.Rentals.RentalBulkItem

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(rental, attrs) do
    rental
    |> cast(attrs, [
      :customer_id,
      :rented_at,
      :return_by,
      :returned_at,
      :status,
      :event_type,
      :event_date
    ])
    |> validate_required([:customer_id, :rented_at, :return_by, :status])
  end
end
