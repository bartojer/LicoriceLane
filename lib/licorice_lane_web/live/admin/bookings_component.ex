defmodule LicoriceLaneWeb.Admin.BookingsComponent do
  use LicoriceLaneWeb, :live_component

  alias LicoriceLane.Rentals
  import LicoriceLaneWeb.AdminHelpers

  @impl true
  def update(assigns, socket) do
    {updated_rental_id, assigns} = Map.pop(assigns, :updated_rental_id)

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:status_filter, fn -> "all" end)
      |> assign_new(:date_filter, fn -> nil end)
      |> assign_new(:page, fn -> 1 end)
      |> assign_new(:selected_rental, fn -> nil end)
      |> assign_new(:rental_mode, fn -> nil end)
      |> assign_new(:rental_form, fn -> nil end)
      |> assign_new(:rental_notice, fn -> nil end)
      |> refresh_details(updated_rental_id)
      |> load_bookings()

    {:ok, socket}
  end

  defp load_bookings(socket) do
    page = socket.assigns.page
    page_size = default_page_size()

    {rentals, total_count} =
      Rentals.list_rentals_paginated(
        socket.assigns.status_filter,
        date_filter: socket.assigns.date_filter,
        page: page,
        page_size: page_size
      )

    pagination = paginate(total_count, page, page_size)

    socket
    |> assign(:page, pagination.page)
    |> assign(:pagination, pagination)
    |> stream(:rentals, rentals, reset: true)
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    socket =
      socket
      |> assign(:status_filter, status)
      |> assign(:page, 1)
      |> load_bookings()

    {:noreply, socket}
  end

  def handle_event("filter_date", %{"date" => date}, socket) when is_binary(date) do
    date_filter =
      case Date.from_iso8601(date) do
        {:ok, date} -> date
        {:error, _} -> nil
      end

    socket =
      socket
      |> assign(:date_filter, date_filter)
      |> assign(:page, 1)
      |> load_bookings()

    {:noreply, socket}
  end

  def handle_event("filter_date", _params, socket), do: {:noreply, socket}

  def handle_event("page", %{"page" => page}, socket) do
    page = LicoriceLane.Pagination.page_number(page)

    socket =
      socket
      |> assign(:page, page)
      |> load_bookings()

    {:noreply, socket}
  end

  def handle_event("view_rental", params, socket) do
    {:noreply, open_rental(socket, params["rental-id"], :view)}
  end

  def handle_event("update_rental", params, socket) do
    {:noreply, open_rental(socket, params["rental-id"], :edit)}
  end

  def handle_event("close_rental", _params, socket) do
    {:noreply, socket |> close_rental() |> load_bookings()}
  end

  def handle_event(
        "validate_rental",
        %{"rental" => params},
        %{assigns: %{rental_mode: :edit}} = socket
      ) do
    changeset =
      socket.assigns.selected_rental
      |> Rentals.change_rental_details(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :rental_form, to_form(changeset))}
  end

  def handle_event(
        "save_rental",
        %{"rental" => params},
        %{assigns: %{rental_mode: :edit}} = socket
      ) do
    case Rentals.update_rental_details(socket.assigns.selected_rental, params) do
      {:ok, _rental} ->
        {:noreply,
         socket
         |> close_rental()
         |> assign(:rental_notice, {:info, "Booking updated successfully."})
         |> load_bookings()}

      {:error, changeset} ->
        notice =
          case Keyword.get(changeset.errors, :id) do
            {message, _opts} -> "Booking #{message}."
            nil -> "Could not save booking. Please correct the errors below."
          end

        {:noreply,
         socket
         |> assign(:rental_form, to_form(changeset))
         |> assign(:rental_notice, {:error, notice})}
    end
  end

  def handle_event(event, _params, socket) when event in ["save_rental", "validate_rental"] do
    {:noreply, socket}
  end

  defp open_rental(socket, id, mode) do
    case find_rental(id) do
      nil ->
        socket
        |> close_rental()
        |> assign(:rental_notice, {:error, "Booking is no longer available."})
        |> load_bookings()

      rental ->
        socket
        |> assign(:selected_rental, rental)
        |> assign(:rental_mode, mode)
        |> assign(:rental_form, to_form(Rentals.change_rental_details(rental)))
        |> assign(:rental_notice, nil)
    end
  end

  defp find_rental(id) when is_binary(id) do
    case Integer.parse(id) do
      {id, ""} when id > 0 and id <= 9_223_372_036_854_775_807 -> Rentals.get_rental(id)
      _ -> nil
    end
  end

  defp find_rental(_id), do: nil

  defp close_rental(socket) do
    assign(socket, selected_rental: nil, rental_mode: nil, rental_form: nil, rental_notice: nil)
  end

  defp refresh_details(%{assigns: %{rental_mode: :view, selected_rental: rental}} = socket, id)
       when not is_nil(rental) and rental.id == id do
    case Rentals.get_rental(id) do
      nil -> close_rental(socket)
      current -> assign(socket, :selected_rental, current)
    end
  end

  defp refresh_details(socket, _id), do: socket

  # Phoenix's default datetime-local normalization drops seconds. Preserve them on edits.
  defp datetime_input(%DateTime{} = value), do: Calendar.strftime(value, "%Y-%m-%dT%H:%M:%S")
  defp datetime_input(value) when is_binary(value), do: value
  defp datetime_input(_value), do: ""

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <h3 class="text-lg leading-6 font-medium text-gray-900 mb-6">Booking Management</h3>
        <p
          :if={@rental_notice && @rental_mode != :edit}
          id="booking-notice"
          role={if elem(@rental_notice, 0) == :error, do: "alert", else: "status"}
          class="mb-4 rounded bg-gray-50 p-3 text-sm text-gray-900"
        >
          {elem(@rental_notice, 1)}
        </p>
        <!-- Booking Filters -->
        <div class="flex flex-col sm:flex-row gap-4 mb-6">
          <form phx-change="filter_status" phx-target={@myself}>
            <select
              name="status"
              phx-target={@myself}
              class="px-3 py-2 border border-gray-300 rounded-md focus:ring-brand focus:border-brand"
            >
              <option value="all" selected={@status_filter == "all"}>All Bookings</option>

              <option value="upcoming" selected={@status_filter == "upcoming"}>Upcoming</option>

              <option value="active" selected={@status_filter == "active"}>Active</option>

              <option value="returned" selected={@status_filter == "returned"}>Returned</option>

              <option value="late" selected={@status_filter == "late"}>Late</option>

              <option value="cancelled" selected={@status_filter == "cancelled"}>Cancelled</option>
            </select>
          </form>
          <form phx-change="filter_date" phx-target={@myself}>
            <label for="booking-event-date" class="sr-only">Event date</label>
            <input
              id="booking-event-date"
              type="date"
              name="date"
              aria-label="Event date"
              value={@date_filter}
              phx-target={@myself}
              class="px-3 py-2 border border-gray-300 rounded-md focus:ring-brand focus:border-brand"
            />
          </form>
        </div>
        <!-- Bookings Table -->
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Booking ID
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Client
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Event Type
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Event Date
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Pickup Date
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Return By
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>

            <tbody class="bg-white divide-y divide-gray-200" id="bookings-list" phx-update="stream">
              <tr :for={{dom_id, rental} <- @streams.rentals} id={dom_id}>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                  #{rental.id}
                </td>

                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {rental.customer.name}
                </td>

                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {event_type_label(rental.event_type)}
                </td>

                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {format_date(rental.event_date)}
                </td>

                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {format_datetime(rental.rented_at)}
                </td>

                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {format_datetime(rental.return_by)}
                </td>

                <td class="px-6 py-4 whitespace-nowrap"><.status_badge status={rental.status} /></td>

                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium space-x-2">
                  <button
                    phx-click="view_rental"
                    phx-value-rental-id={rental.id}
                    phx-target={@myself}
                    class="text-brand hover:text-brand/80"
                  >
                    View
                  </button>
                  <button
                    phx-click="update_rental"
                    phx-value-rental-id={rental.id}
                    phx-target={@myself}
                    class="text-gray-600 hover:text-gray-900"
                  >
                    Update
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <.pagination pagination={@pagination} target={@myself} />
      </div>
      <.modal
        :if={@selected_rental}
        id="booking-detail-modal"
        show
        on_cancel={JS.push("close_rental", target: @myself)}
      >
        <h3 id="booking-detail-modal-title" class="text-lg font-semibold text-gray-900">
          {if @rental_mode == :edit, do: "Update Booking", else: "Booking Details"} #{@selected_rental.id}
        </h3>
        <p id="booking-detail-modal-description" class="mt-2 text-sm text-gray-500">
          {if @rental_mode == :edit,
            do: "Edit the event and scheduled pickup/return dates. All times are in UTC.",
            else: "All dates and times are in UTC."}
        </p>
        <div :if={@rental_mode == :view} class="mt-4 space-y-6">
          <dl class="space-y-4">
            <div>
              <dt class="text-sm font-medium text-gray-500">Client</dt>
              <dd class="mt-1 text-sm text-gray-900">{@selected_rental.customer.name}</dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Status</dt>
              <dd class="mt-1"><.status_badge status={@selected_rental.status} /></dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Event Type</dt>
              <dd class="mt-1 text-sm text-gray-900">
                {event_type_label(@selected_rental.event_type)}
              </dd>
            </div>
            <div :for={
              {label, field} <- [
                {"Event Date", :event_date},
                {"Pickup", :rented_at},
                {"Return By", :return_by},
                {"Actual Return", :returned_at}
              ]
            }>
              <dt class="text-sm font-medium text-gray-500">{label}</dt>
              <dd class="mt-1 text-sm text-gray-900">
                {format_datetime(Map.get(@selected_rental, field))}
              </dd>
            </div>
          </dl>
          <div>
            <h4 class="text-sm font-medium text-gray-500">Assigned Items</h4>
            <p
              :if={
                @selected_rental.rental_single_items == [] && @selected_rental.rental_bulk_items == []
              }
              class="mt-1 text-sm text-gray-900"
            >
              No items assigned.
            </p>
            <ul id="booking-single-items" class="mt-2 space-y-2 text-sm text-gray-900">
              <li :for={row <- @selected_rental.rental_single_items}>
                {row.single_item.item.name} — Single item
                <span class="block text-gray-500">
                  Current location: {if row.single_item.location,
                    do: row.single_item.location.name,
                    else: "Not recorded"}
                </span>
              </li>
            </ul>
            <ul id="booking-bulk-items" class="mt-2 space-y-2 text-sm text-gray-900">
              <li :for={row <- @selected_rental.rental_bulk_items}>
                {row.item.name} — Quantity: {row.quantity}
              </li>
            </ul>
          </div>
          <div class="flex justify-end gap-3">
            <.button type="button" phx-click="close_rental" phx-target={@myself}>Close</.button>
            <.button
              type="button"
              phx-click="update_rental"
              phx-value-rental-id={@selected_rental.id}
              phx-target={@myself}
            >
              Update Booking
            </.button>
          </div>
        </div>
        <.simple_form
          :if={@rental_mode == :edit}
          for={@rental_form}
          id="booking-edit-form"
          phx-change="validate_rental"
          phx-submit="save_rental"
          phx-target={@myself}
        >
          <p :if={@rental_notice} id="booking-edit-error" role="alert" class="text-sm text-red-600">
            {elem(@rental_notice, 1)}
          </p>
          <.input
            field={@rental_form[:event_type]}
            type="select"
            label="Event Type"
            prompt="Not specified"
            options={[
              {"Wedding", :wedding},
              {"Corporate Event", :corporate},
              {"Birthday Party", :birthday}
            ]}
          />
          <.input
            :for={
              {label, field} <- [
                {"Event Date (UTC)", :event_date},
                {"Pickup (UTC)", :rented_at},
                {"Return By (UTC)", :return_by}
              ]
            }
            field={@rental_form[field]}
            value={datetime_input(@rental_form[field].value)}
            type="datetime-local"
            step="1"
            label={label}
            required={field != :event_date}
          />
          <:actions>
            <.button type="button" phx-click="close_rental" phx-target={@myself}>Cancel</.button>
            <.button type="submit" phx-disable-with="Saving...">Save Booking</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end
end
