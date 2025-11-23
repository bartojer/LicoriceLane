defmodule LicoriceLaneWeb.Admin.BookingsComponent do
  use LicoriceLaneWeb, :live_component

  alias LicoriceLane.Rentals

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:status_filter, "all")
      |> assign(:date_filter, nil)
      |> load_bookings()

    {:ok, socket}
  end

  defp load_bookings(socket) do
    rentals = get_filtered_rentals(socket.assigns.status_filter)
    stream(socket, :rentals, rentals, reset: true)
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    socket =
      socket
      |> assign(:status_filter, status)
      |> load_bookings()

    {:noreply, socket}
  end

  def handle_event("filter_date", %{"date" => date}, socket) do
    # TODO: Implement date filtering
    {:noreply, assign(socket, :date_filter, date)}
  end

  def handle_event("view_rental", %{"rental-id" => _rental_id}, socket) do
    # TODO: Implement view rental details (could open modal or navigate)
    {:noreply, socket}
  end

  def handle_event("update_rental", %{"rental-id" => _rental_id}, socket) do
    # TODO: Implement update rental functionality
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <h3 class="text-lg leading-6 font-medium text-gray-900 mb-6">Booking Management</h3>
        
    <!-- Booking Filters -->
        <div class="flex flex-col sm:flex-row gap-4 mb-6">
          <select
            phx-change="filter_status"
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
          <input
            type="date"
            phx-change="filter_date"
            name="date"
            phx-target={@myself}
            class="px-3 py-2 border border-gray-300 rounded-md focus:ring-brand focus:border-brand"
          />
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
                <td class="px-6 py-4 whitespace-nowrap">
                  <.status_badge status={rental.status} />
                </td>
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
      </div>
    </div>
    """
  end

  defp get_filtered_rentals("all"), do: Rentals.list_rentals()
  defp get_filtered_rentals("upcoming"), do: Rentals.list_upcoming_rentals()
  defp get_filtered_rentals("active"), do: Rentals.list_active_rentals()
  defp get_filtered_rentals("late"), do: Rentals.list_overdue_rentals()

  defp get_filtered_rentals(status),
    do: Rentals.list_rentals_by_status(String.to_existing_atom(status))

  defp event_type_label(nil), do: "—"
  defp event_type_label(:wedding), do: "Wedding"
  defp event_type_label(:corporate), do: "Corporate Event"
  defp event_type_label(:birthday), do: "Birthday Party"
  defp event_type_label(type), do: type |> to_string() |> String.capitalize()

  defp format_date(nil), do: "—"

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y")
  end

  defp format_datetime(nil), do: "—"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y %I:%M %p")
  end
end
