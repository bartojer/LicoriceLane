defmodule LicoriceLaneWeb.Admin.DashboardComponent do
  use LicoriceLaneWeb, :live_component

  alias LicoriceLane.{Inventory, Rentals}
  import LicoriceLaneWeb.AdminHelpers

  @impl true
  def update(assigns, socket) do
    # Subscribe to inventory updates on first mount
    socket =
      if connected?(socket) && !Map.has_key?(socket.assigns, :subscribed) do
        Phoenix.PubSub.subscribe(LicoriceLane.PubSub, "inventory:updates")
        assign(socket, :subscribed, true)
      else
        socket
      end

    socket =
      socket
      |> assign(assigns)
      |> load_dashboard_data()

    {:ok, socket}
  end

  defp load_dashboard_data(socket) do
    # Get stats
    low_stock_data = Inventory.list_low_stock_items()
    recent_bookings = Rentals.list_recent_rentals(5)

    stats = %{
      total_bookings: Enum.count(Rentals.list_rentals()),
      low_stock_items: Enum.count(low_stock_data)
    }

    socket
    |> assign(:stats, stats)
    |> stream_configure(:low_stock_items,
      dom_id: fn item_data -> "low-stock-item-#{item_data.item.id}" end
    )
    |> stream(:low_stock_items, low_stock_data, reset: true)
    |> stream(:recent_bookings, recent_bookings, reset: true)
  end

  def handle_info({:inventory_updated, _item_id}, socket) do
    # Reload low stock items when inventory changes
    {:noreply, load_dashboard_data(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <!-- Stats Grid -->
      <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-green-500 rounded-md flex items-center justify-center">
                  <svg
                    class="w-5 h-5 text-white"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                    />
                  </svg>
                </div>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Total Bookings</dt>
                  <dd class="text-lg font-medium text-gray-900">{@stats.total_bookings}</dd>
                </dl>
              </div>
            </div>
          </div>
        </div>

        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-red-500 rounded-md flex items-center justify-center">
                  <svg
                    class="w-5 h-5 text-white"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"
                    />
                  </svg>
                </div>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Low Stock Items</dt>
                  <dd class="text-lg font-medium text-gray-900">{@stats.low_stock_items}</dd>
                </dl>
              </div>
            </div>
          </div>
        </div>
      </div>

    <!-- Recent Activity Section -->
      <div class="grid grid-cols-1 gap-8 lg:grid-cols-2">
        <!-- Recent Bookings -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Recent Bookings</h3>
            <div class="space-y-3" id="recent-bookings" phx-update="stream">
              <div
                :for={{dom_id, booking} <- @streams.recent_bookings}
                id={dom_id}
                class="flex items-center justify-between py-3 border-b border-gray-200 last:border-b-0"
              >
                <div class="flex items-center space-x-3">
                  <div>
                    <p class="text-sm font-medium text-gray-900">
                      Rental #{booking.id}
                    </p>
                    <p class="text-sm text-gray-500">{booking.customer.name}</p>
                    <p :if={booking.event_type} class="text-xs text-gray-400">
                      {event_type_label(booking.event_type)}
                    </p>
                  </div>
                </div>
                <div class="flex items-center space-x-3">
                  <.status_badge status={booking.status} />
                </div>
              </div>
            </div>
            <div class="mt-4">
              <button
                phx-click="switch_tab"
                phx-value-tab="bookings"
                phx-target={@myself}
                class="text-sm text-brand hover:text-brand/80"
              >
                View all bookings →
              </button>
            </div>
          </div>
        </div>

    <!-- Low Stock Items -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Inventory Alert</h3>
            <div class="space-y-3" id="low-stock-items" phx-update="stream">
              <div
                :for={{dom_id, item_data} <- @streams.low_stock_items}
                id={dom_id}
                class="flex items-center justify-between py-3 border-b border-gray-200 last:border-b-0"
              >
                <div>
                  <p class="text-sm font-medium text-gray-900">{item_data.item.name}</p>
                  <p class="text-sm text-gray-500">
                    Category: {category_label(item_data.item.category)}
                  </p>
                </div>
                <div class="text-right">
                  <p class="text-sm font-medium text-red-600">
                    {item_data.warehouse_quantity} in stock
                  </p>
                  <p class="text-xs text-gray-500">Min: {item_data.item.min_stock}</p>
                </div>
              </div>
            </div>
            <div class="mt-4">
              <button
                phx-click="switch_tab"
                phx-value-tab="inventory"
                phx-target={@myself}
                class="text-sm text-brand hover:text-brand/80"
              >
                Restock items →
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    send(self(), {:switch_tab, tab})
    {:noreply, socket}
  end
end
