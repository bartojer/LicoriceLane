defmodule LicoriceLane.Rentals do
  @moduledoc """
  Context module for managing rentals and bookings.
  """

  import Ecto.Query
  alias LicoriceLane.{Repo, Rental}

  @doc """
  Returns all rentals with customer preloaded.
  Ordered by rented_at descending (most recent first).
  """
  def list_rentals do
    Rental
    |> order_by([r], desc: r.rented_at)
    |> preload([:customer, :rental_single_items, :rental_bulk_items])
    |> Repo.all()
  end

  @doc """
  Returns the most recent N rentals.
  Default limit is 5.
  """
  def list_recent_rentals(limit \\ 5) do
    Rental
    |> order_by([r], desc: r.rented_at)
    |> limit(^limit)
    |> preload([:customer, :rental_single_items, :rental_bulk_items])
    |> Repo.all()
  end

  @doc """
  Returns rentals filtered by status.
  """
  def list_rentals_by_status(status) when is_atom(status) do
    Rental
    |> where([r], r.status == ^status)
    |> order_by([r], desc: r.rented_at)
    |> preload([:customer, :rental_single_items, :rental_bulk_items])
    |> Repo.all()
  end

  @doc """
  Returns upcoming rentals (rented_at is in the future).
  """
  def list_upcoming_rentals do
    now = DateTime.utc_now()

    Rental
    |> where([r], r.rented_at > ^now)
    |> order_by([r], asc: r.rented_at)
    |> preload([:customer, :rental_single_items, :rental_bulk_items])
    |> Repo.all()
  end

  @doc """
  Returns active rentals (status is :active).
  """
  def list_active_rentals do
    list_rentals_by_status(:active)
  end

  @doc """
  Returns overdue rentals (return_by is in the past and not yet returned).
  """
  def list_overdue_rentals do
    now = DateTime.utc_now()

    Rental
    |> where([r], r.return_by < ^now)
    |> where([r], is_nil(r.returned_at))
    |> where([r], r.status in [:active, :late])
    |> order_by([r], asc: r.return_by)
    |> preload([:customer, :rental_single_items, :rental_bulk_items])
    |> Repo.all()
  end

  @doc """
  Returns rentals for the upcoming week (rented_at within next 7 days).
  """
  def list_upcoming_this_week do
    now = DateTime.utc_now()
    week_from_now = DateTime.add(now, 7, :day)

    Rental
    |> where([r], r.rented_at >= ^now and r.rented_at <= ^week_from_now)
    |> order_by([r], asc: r.rented_at)
    |> preload([:customer, :rental_single_items, :rental_bulk_items])
    |> Repo.all()
  end

  @doc """
  Gets a single rental by id with preloads.
  """
  def get_rental(id) do
    Rental
    |> preload([:customer, :rental_single_items, :rental_bulk_items])
    |> Repo.get(id)
  end

  @doc """
  Searches rentals by customer name or rental ID.
  """
  def search_rentals(search_term) when is_binary(search_term) do
    search_pattern = "%#{search_term}%"

    Rental
    |> join(:inner, [r], c in assoc(r, :customer))
    |> where(
      [r, c],
      ilike(c.name, ^search_pattern) or
        ilike(fragment("CAST(? AS TEXT)", r.id), ^search_pattern)
    )
    |> order_by([r], desc: r.rented_at)
    |> preload([:customer, :rental_single_items, :rental_bulk_items])
    |> Repo.all()
  end
end
