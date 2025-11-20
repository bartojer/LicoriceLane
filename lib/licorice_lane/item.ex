defmodule LicoriceLane.Item do
  use Ecto.Schema
  import Ecto.Changeset

  schema "items" do
    field :name, :string
    field :description, :string
    field :item_type, Ecto.Enum, values: [:single, :bulk]
    field :rental_price, :decimal
    field :image_path, :string

    has_one :single_item, LicoriceLane.SingleItem, foreign_key: :id
    has_many :items_locations, LicoriceLane.ItemsLocation

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [:name, :description, :item_type, :rental_price, :image_path])
    |> validate_required([:name, :description, :item_type])
  end
end
