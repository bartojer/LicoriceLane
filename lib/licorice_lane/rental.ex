defmodule LicoriceLane.Rental do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rentals" do
    field :status, Ecto.Enum,
      values: [:active, :returned, :late],
      default: :active

    field :rented_at, :utc_datetime
    field :return_by, :utc_datetime
    field :customer_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(rental, attrs) do
    rental
    |> cast(attrs, [:rented_at, :return_by, :status])
    |> validate_required([:rented_at, :return_by, :status])
  end
end
