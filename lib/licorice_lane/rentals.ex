defmodule LicoriceLane.Rentals do
  @moduledoc """
  Context module for managing rentals and bookings.
  """

  import Ecto.Query
  alias LicoriceLane.Repo
  alias LicoriceLane.Rentals.Rental
  alias LicoriceLane.Cache

  @detail_fields [:event_type, :event_date, :rented_at, :return_by]
  @detail_preloads [
    :customer,
    rental_single_items: [single_item: [:item, :location]],
    rental_bulk_items: :item
  ]

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
    |> preload(^@detail_preloads)
    |> Repo.get(id)
  end

  @doc """
  Validates event and scheduling edits without persisting them.

  Only event_type, event_date, rented_at and return_by are editable here.
  Pickup and return-by are required, return-by cannot precede pickup, and pickup
  cannot follow an already recorded actual return. Event date/type are optional.
  Datetimes without an offset are interpreted as UTC by the schema type.
  Status, customer, actual return and item allocations are lifecycle operations.
  """
  def change_rental_details(%Rental{} = rental, attrs \\ %{}) do
    rental
    |> Ecto.Changeset.cast(attrs, @detail_fields)
    |> Ecto.Changeset.validate_required([:rented_at, :return_by])
    |> validate_schedule()
  end

  defp validate_schedule(changeset) do
    pickup = Ecto.Changeset.get_field(changeset, :rented_at)
    due = Ecto.Changeset.get_field(changeset, :return_by)
    returned = Ecto.Changeset.get_field(changeset, :returned_at)

    changeset =
      if match?(%DateTime{}, pickup) and match?(%DateTime{}, due) and
           DateTime.compare(due, pickup) == :lt do
        Ecto.Changeset.add_error(changeset, :return_by, "must be on or after pickup")
      else
        changeset
      end

    if match?(%DateTime{}, pickup) and match?(%DateTime{}, returned) and
         DateTime.compare(pickup, returned) == :gt do
      Ecto.Changeset.add_error(changeset, :rented_at, "cannot be after the actual return")
    else
      changeset
    end
  end

  @doc """
  Updates a booking's event and schedule while preserving its lifecycle and stock.

  Locks the current rental row and rejects edits based on an older schedule.
  Returns {:error, changeset} for invalid, deleted or concurrently changed records.
  Successful writes return full details, invalidate rental/dashboard cache entries
  and broadcast {:rental_updated, id} on "rentals:updates" after commit.
  This operation does not move, reserve or return inventory.
  """
  def update_rental_details(%Rental{} = rental, attrs) do
    result =
      Repo.transaction(fn ->
        current = Repo.one(from r in Rental, where: r.id == ^rental.id, lock: "FOR UPDATE")

        cond do
          is_nil(current) ->
            rollback_details(rental, attrs, "is no longer available")

          Map.take(current, @detail_fields) != Map.take(rental, @detail_fields) ->
            rollback_details(rental, attrs, "has changed; close and reopen this booking")

          true ->
            case current |> change_rental_details(attrs) |> Repo.update() do
              {:ok, updated} -> Repo.preload(updated, @detail_preloads)
              {:error, changeset} -> Repo.rollback(changeset)
            end
        end
      end)

    case result do
      {:ok, updated} ->
        Cache.invalidate_rentals()

        Phoenix.PubSub.broadcast(
          LicoriceLane.PubSub,
          "rentals:updates",
          {:rental_updated, updated.id}
        )

        {:ok, updated}

      error ->
        error
    end
  end

  defp rollback_details(rental, attrs, message) do
    changeset =
      rental
      |> change_rental_details(attrs)
      |> Ecto.Changeset.add_error(:id, message)
      |> Map.put(:action, :update)

    Repo.rollback(changeset)
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
