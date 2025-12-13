defmodule LicoriceLane.CustomersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `LicoriceLane.Customers` context.
  """

  def unique_customer_name, do: "Customer #{System.unique_integer()}"
  def unique_email, do: "customer#{System.unique_integer()}@example.com"
  def unique_phone, do: "555-#{:rand.uniform(9000) + 1000}"

  def valid_customer_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: unique_customer_name(),
      phone: unique_phone(),
      email: unique_email(),
      contact_person: "John Doe",
      billing_address: "123 Main St, City, State 12345",
      notes: "Test customer notes"
    })
  end

  def customer_fixture(attrs \\ %{}) do
    {:ok, customer} =
      attrs
      |> valid_customer_attributes()
      |> LicoriceLane.Customers.create_customer()

    customer
  end
end
