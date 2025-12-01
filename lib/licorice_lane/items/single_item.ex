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

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(single_item, attrs) do
    single_item
    |> cast(attrs, [:condition, :status])
    |> validate_required([:condition, :status])
  end
end
