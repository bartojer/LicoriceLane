defmodule LicoriceLane.Customers do
  @moduledoc """
  Context module for managing customers.
  """

  import Ecto.Query
  alias LicoriceLane.Repo
  alias LicoriceLane.Customers.Customer
  alias LicoriceLane.Cache

  @doc """
  Returns all customers ordered by name.
  """
  def list_customers do
    Customer
    |> order_by([c], asc: c.name)
    |> Repo.all()
  end

  @doc """
  Returns paginated customers with optional search.
  Returns {customers, total_count} for pagination display.

  ## Parameters
    - search_term: String to search by name (or exact email/phone match)
    - opts: Keyword list with :page (1-indexed) and :page_size
  """
  def list_customers_paginated(search_term \\ "", opts \\ []) do
    if search_term == "" do
      Customer
      |> order_by([c], asc: c.name, asc: c.id)
      |> LicoriceLane.Pagination.query(opts)
    else
      # Preserve exact encrypted-field lookups and deduplicate before counting.
      all_results = search_customers(search_term) |> Enum.sort_by(&{&1.name, &1.id})
      total_count = length(all_results)
      pagination = LicoriceLane.Pagination.bounds(total_count, opts)
      customers = Enum.slice(all_results, pagination.offset, pagination.page_size)
      {customers, total_count}
    end
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
  Searches customers by name (ILIKE), or exact email/phone match.

  Note: Email, phone, contact_person, billing_address, and notes are encrypted
  for security. Only name supports partial/fuzzy search (ILIKE). Email and phone
  can be found via exact match using hash comparison. This trade-off maintains
  data security while enabling basic search functionality.
  """
  def search_customers(search_term) when is_binary(search_term) do
    # Search by name (unencrypted, supports ILIKE)
    name_results = search_customers_by_name(search_term)

    # Search by exact email match (encrypted field, using hash)
    email_results = find_customer_by_email(search_term)

    # Search by exact phone match (encrypted field, using hash)
    phone_results = find_customer_by_phone(search_term)

    # Combine results, remove duplicates, maintain alphabetical order
    (name_results ++ email_results ++ phone_results)
    |> Enum.uniq_by(& &1.id)
    |> Enum.sort_by(& &1.name)
  end

  @doc """
  Searches customers by name using case-insensitive ILIKE pattern matching.
  """
  def search_customers_by_name(search_term) when is_binary(search_term) do
    search_pattern = "%#{search_term}%"

    Customer
    |> where([c], ilike(c.name, ^search_pattern))
    |> order_by([c], asc: c.name)
    |> Repo.all()
  end

  @doc """
  Finds customers by exact email match using hash comparison.
  Returns a list to maintain consistency with search functions.
  """
  def find_customer_by_email(email) when is_binary(email) do
    Customer
    |> where([c], c.email_hash == ^email)
    |> Repo.all()
  end

  @doc """
  Finds customers by exact phone match using hash comparison.
  Returns a list to maintain consistency with search functions.
  """
  def find_customer_by_phone(phone) when is_binary(phone) do
    Customer
    |> where([c], c.phone_hash == ^phone)
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
    result =
      %Customer{}
      |> Customer.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, customer} ->
        Cache.invalidate_customers()
        {:ok, customer}

      error ->
        error
    end
  end

  @doc """
  Returns a changeset for validating customer fields without persisting them.
  """
  def change_customer(%Customer{} = customer, attrs \\ %{}) do
    Customer.changeset(customer, attrs)
  end

  @doc """
  Updates a customer and invalidates dependent cache entries after success.
  Returns an error changeset if validation fails or the record was deleted.
  """
  def update_customer(%Customer{} = customer, attrs) do
    result =
      customer
      |> Customer.changeset(attrs)
      |> Repo.update(stale_error_field: :id, stale_error_message: "is no longer available")

    case result do
      {:ok, updated} ->
        Cache.invalidate_customers()
        {:ok, updated}

      error ->
        error
    end
  end

  @doc """
  Deletes a customer.
  """
  def delete_customer(%Customer{} = customer) do
    result = Repo.delete(customer)

    case result do
      {:ok, deleted} ->
        Cache.invalidate_customers()
        {:ok, deleted}

      error ->
        error
    end
  end
end
