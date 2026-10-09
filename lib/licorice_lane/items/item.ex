defmodule LicoriceLane.Items.Item do
  use Ecto.Schema
  import Ecto.Changeset

  schema "items" do
    field :name, :string
    field :description, :string
    field :category, Ecto.Enum, values: [:candle, :tableware, :linen, :electric_light, :tray]
    field :item_type, Ecto.Enum, values: [:single, :bulk]
    field :rental_price, :decimal
    field :image_path, :string
    field :min_stock, :integer, default: 0
    field :color, :string

    has_one :single_item, LicoriceLane.Items.SingleItem, foreign_key: :id
    has_many :items_locations, LicoriceLane.Locations.ItemsLocation
    has_many :rental_bulk_items, LicoriceLane.Rentals.RentalBulkItem
    has_many :rental_single_items, through: [:single_item, :rental_single_items]
    has_many :rentals, through: [:rental_bulk_items, :rental]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :name,
      :description,
      :category,
      :item_type,
      :rental_price,
      :image_path,
      :min_stock,
      :color
    ])
    |> validate_required([:name, :description, :item_type])
    |> validate_number(:min_stock, greater_than_or_equal_to: 0)
    |> set_min_stock_for_item_type()
  end

  defp set_min_stock_for_item_type(changeset) do
    case get_field(changeset, :item_type) do
      :single ->
        # Single items don't use min_stock for alerts, set to 0
        put_change(changeset, :min_stock, 0)

      :bulk ->
        # Bulk items keep their value; the creation context supplies 10 when absent.
        # The base schema default is 0 for callers that bypass that context.
        changeset

      _ ->
        changeset
    end
  end
end
