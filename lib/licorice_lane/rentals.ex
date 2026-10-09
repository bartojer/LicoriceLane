defmodule LicoriceLane.Rentals do
  @moduledoc """
  Context module for managing rentals and bookings.
  """

  import Ecto.Query
  alias LicoriceLane.Repo
  alias LicoriceLane.Rentals.Rental

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
  Returns paginated rentals with optional status and event date filters.
  Returns {rentals, total_count} for pagination display.

  ## Parameters
    - status_filter: "all", "upcoming", "active", "late", "returned", "cancelled"
    - opts: Keyword list with :page (1-indexed), :page_size, and :date_filter

  The :date_filter option accepts a Date or ISO 8601 date string and matches
  event_date from midnight UTC (inclusive) to the next midnight (exclusive).
  Rentals without an event date are excluded when a date is selected.
  Blank, missing, or invalid date filters leave the status-filtered query unchanged.
  """
  def list_rentals_paginated(status_filter \\ "all", opts \\ []) do
    build_filtered_rentals_query(status_filter)
    |> filter_event_date(Keyword.get(opts, :date_filter))
    |> order_by([r], asc: r.id)
    |> LicoriceLane.Pagination.query(opts)
  end

  defp filter_event_date(query, %Date{} = date) do
    start_at = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    end_at = DateTime.add(start_at, 1, :day)

    where(query, [r], r.event_date >= ^start_at and r.event_date < ^end_at)
  end

  defp filter_event_date(query, date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, date} -> filter_event_date(query, date)
      {:error, _} -> query
    end
  end

  defp filter_event_date(query, _date), do: query

  defp build_filtered_rentals_query("all") do
    Rental
    |> order_by([r], desc: r.rented_at)
    |> preload([:customer, :rental_single_items, :rental_bulk_items])
  end

  defp build_filtered_rentals_query("upcoming") do
    now = DateTime.utc_now()

    Rental
    |> where([r], r.rented_at > ^now)
    |> order_by([r], asc: r.rented_at)
    |> preload([:customer, :rental_single_items, :rental_bulk_items])
  end

  defp build_filtered_rentals_query("active") do
    Rental
    |> where([r], r.status == :active)
    |> order_by([r], desc: r.rented_at)
    |> preload([:customer, :rental_single_items, :rental_bulk_items])
  end

  defp build_filtered_rentals_query("late") do
    now = DateTime.utc_now()

    Rental
    |> where([r], r.return_by < ^now)
    |> where([r], is_nil(r.returned_at))
    |> where([r], r.status in [:active, :late])
    |> order_by([r], asc: r.return_by)
    |> preload([:customer, :rental_single_items, :rental_bulk_items])
  end

  defp build_filtered_rentals_query(status) when status in ["returned", "cancelled"] do
    status_atom = String.to_existing_atom(status)

    Rental
    |> where([r], r.status == ^status_atom)
    |> order_by([r], desc: r.rented_at)
    |> preload([:customer, :rental_single_items, :rental_bulk_items])
  end

  defp build_filtered_rentals_query(_), do: build_filtered_rentals_query("all")

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
