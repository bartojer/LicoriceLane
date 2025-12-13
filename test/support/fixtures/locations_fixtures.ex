defmodule LicoriceLane.LocationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `LicoriceLane.Locations` context.
  """

  import LicoriceLane.CustomersFixtures

  alias LicoriceLane.Repo
  alias LicoriceLane.Locations.Location

  def unique_location_name, do: "Location #{System.unique_integer()}"

  def valid_warehouse_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: unique_location_name(),
      location_type: :warehouse,
      customer_id: nil
    })
  end

  def valid_customer_location_attributes(attrs \\ %{}) do
    customer = attrs[:customer] || customer_fixture()

    Enum.into(attrs, %{
      name: unique_location_name(),
      location_type: :customer,
      customer_id: customer.id
    })
  end

  def warehouse_fixture(attrs \\ %{}) do
    attrs
    |> valid_warehouse_attributes()
    |> then(&struct(Location, &1))
    |> Repo.insert!()
  end

  def customer_location_fixture(attrs \\ %{}) do
    attrs
    |> valid_customer_location_attributes()
    |> then(&struct(Location, &1))
    |> Repo.insert!()
  end
end
