defmodule LicoriceLane.Item do
  use Ecto.Schema
  import Ecto.Changeset

  schema "items" do
    field :name, :string
    field :description, :string
    field :category, Ecto.Enum, values: [:candle, :tableware, :linen, :electric_light, :tray]
    field :item_type, Ecto.Enum, values: [:single, :bulk]
    field :rental_price, :decimal
    field :image_path, :string
    field :min_stock, :integer, default: 10

    has_one :single_item, LicoriceLane.SingleItem, foreign_key: :id
    has_many :items_locations, LicoriceLane.ItemsLocation
    has_many :rental_bulk_items, LicoriceLane.RentalBulkItem
    has_many :rental_single_items, through: [:single_item, :rental_single_items]
    has_many :rentals, through: [:rental_bulk_items, :rental]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [:name, :description, :item_type, :rental_price, :image_path, :min_stock])
    |> validate_required([:name, :description, :item_type])
    |> validate_number(:min_stock, greater_than_or_equal_to: 0)
  end
end
