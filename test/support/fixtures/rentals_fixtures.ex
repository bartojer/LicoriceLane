defmodule LicoriceLane.RentalsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `LicoriceLane.Rentals` context.
  """

  import LicoriceLane.CustomersFixtures
  import LicoriceLane.ItemsFixtures

  alias LicoriceLane.Repo
  alias LicoriceLane.Rentals.{Rental, RentalSingleItem, RentalBulkItem}

  def valid_rental_attributes(attrs \\ %{}) do
    customer = attrs[:customer] || customer_fixture()

    base_attrs = %{
      customer_id: customer.id,
      rented_at: DateTime.utc_now() |> DateTime.truncate(:second),
      return_by: DateTime.utc_now() |> DateTime.add(7, :day) |> DateTime.truncate(:second),
      returned_at: nil,
      event_date: DateTime.utc_now() |> DateTime.add(3, :day) |> DateTime.truncate(:second),
      event_type: :wedding,
      status: :active
    }

    # Truncate any DateTime values passed in attrs
    attrs =
      attrs
      |> Enum.map(fn
        {key, %DateTime{} = dt} -> {key, DateTime.truncate(dt, :second)}
        {key, value} -> {key, value}
      end)
      |> Enum.into(%{})

    Enum.into(attrs, base_attrs)
  end

  def rental_fixture(attrs \\ %{}) do
    attrs
    |> valid_rental_attributes()
    |> then(&struct(Rental, &1))
    |> Repo.insert!()
    |> Repo.preload([:customer, :rental_single_items, :rental_bulk_items])
  end

  def rental_with_single_items_fixture(attrs \\ %{}) do
    rental = rental_fixture(attrs)
    single_item = attrs[:single_item] || single_item_fixture()

    %RentalSingleItem{
      rental_id: rental.id,
      single_item_id: single_item.id
    }
    |> Repo.insert!()

    rental |> Repo.preload([:rental_single_items, :rental_bulk_items], force: true)
  end

  def rental_with_bulk_items_fixture(attrs \\ %{}) do
    rental = rental_fixture(attrs)
    bulk_item = attrs[:bulk_item] || bulk_item_fixture()
    quantity = attrs[:quantity] || 10

    %RentalBulkItem{
      rental_id: rental.id,
      item_id: bulk_item.id,
      quantity: quantity
    }
    |> Repo.insert!()

    rental |> Repo.preload([:rental_single_items, :rental_bulk_items], force: true)
  end
end
