defmodule LicoriceLane.Customers do
  @moduledoc """
  Context module for managing customers.
  """

  import Ecto.Query
  alias LicoriceLane.{Repo, Customer}

  @doc """
  Returns all customers ordered by name.
  """
  def list_customers do
    Customer
    |> order_by([c], asc: c.name)
    |> Repo.all()
  end

  @doc """
  Gets a single customer by id with locations preloaded.
  """
  def get_customer(id) do
    Customer
    |> preload([:locations])
    |> Repo.get(id)
  end

  @doc """
  Gets a single customer by id, raises if not found.
  """
  def get_customer!(id) do
    Customer
    |> preload([:locations])
    |> Repo.get!(id)
  end

  @doc """
  Searches customers by name, email, or phone.
  Case-insensitive search.
  """
  def search_customers(search_term) when is_binary(search_term) do
    search_pattern = "%#{search_term}%"

    Customer
    |> where(
      [c],
      ilike(c.name, ^search_pattern) or
        ilike(c.email, ^search_pattern) or
        ilike(c.phone, ^search_pattern)
    )
    |> order_by([c], asc: c.name)
    |> Repo.all()
  end

  @doc """
  Returns customers with their rental count.
  """
  def list_customers_with_rental_count do
    from(c in Customer,
      left_join: r in assoc(c, :rentals),
      group_by: c.id,
      select: %{customer: c, rental_count: count(r.id)},
      order_by: [asc: c.name]
    )
    |> Repo.all()
  end

  @doc """
  Creates a customer.
  """
  def create_customer(attrs \\ %{}) do
    %Customer{}
    |> Customer.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a customer.
  """
  def update_customer(%Customer{} = customer, attrs) do
    customer
    |> Customer.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a customer.
  """
  def delete_customer(%Customer{} = customer) do
    Repo.delete(customer)
  end
end
