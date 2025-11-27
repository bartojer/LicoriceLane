defmodule LicoriceLaneWeb.InventoryLive do
  use LicoriceLaneWeb, :live_view

  alias LicoriceLane.Inventory
  import LicoriceLaneWeb.InventoryComponents

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to inventory updates for real-time changes
    if connected?(socket) do
      Phoenix.PubSub.subscribe(LicoriceLane.PubSub, "inventory:updates")
    end

    items = Inventory.list_items()

    socket =
      socket
      |> stream(:items, items)
      |> assign(:search_term, "")
      |> assign(:selected_category, "all")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 py-10 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-7xl">
        <!-- Header -->
        <div class="text-center">
          <h1 class="text-4xl font-bold tracking-tight text-gray-900 sm:text-6xl">
            Event Decor Inventory
          </h1>
          <p class="mt-6 text-lg leading-8 text-gray-600">
            Discover our elegant collection of event decor, tableware, and ambiance essentials
          </p>
        </div>

    <!-- Filter/Search Section -->
        <div class="mt-10 flex flex-col sm:flex-row gap-4 justify-between items-center">
          <div class="flex gap-2">
            <button
              phx-click="show_all"
              class="px-4 py-2 bg-brand text-white rounded-lg hover:bg-brand/90 transition-colors"
            >
              All
            </button>
            <button
              phx-click="show_lighting"
              class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors"
            >
              Lighting
            </button>
            <button
              phx-click="show_tableware"
              class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors"
            >
              Tableware
            </button>
            <button
              phx-click="show_linen"
              class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors"
            >
              Linens
            </button>
          </div>
          <form phx-change="search" class="relative">
            <input
              type="text"
              placeholder="Search decor items..."
              value={@search_term}
              name="search_term"
              class="pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-brand focus:border-transparent"
            />
            <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                >
                </path>
              </svg>
            </div>
          </form>
        </div>

    <!-- Inventory Grid -->
        <div
          class="mt-10 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4"
          id="items"
          phx-update="stream"
        >
          <.inventory_card :for={{dom_id, item} <- @streams.items} item={item} id={dom_id} />
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("search", %{"search_term" => search_term}, socket) do
    items = Inventory.list_filtered_items(socket.assigns.selected_category, search_term)

    socket =
      socket
      |> assign(:search_term, search_term)
      |> stream(:items, items, reset: true)

    {:noreply, socket}
  end

  def handle_event("show_all", _payload, socket) do
    items = Inventory.list_filtered_items("all", socket.assigns.search_term)

    socket =
      socket
      |> assign(:selected_category, "all")
      |> stream(:items, items, reset: true)

    {:noreply, socket}
  end

  def handle_event("show_lighting", _payload, socket) do
    items = Inventory.list_filtered_items("lighting", socket.assigns.search_term)

    socket =
      socket
      |> assign(:selected_category, "lighting")
      |> stream(:items, items, reset: true)

    {:noreply, socket}
  end

  def handle_event("show_" <> category, _payload, socket) do
    items = Inventory.list_filtered_items(category, socket.assigns.search_term)

    socket =
      socket
      |> assign(:selected_category, category)
      |> stream(:items, items, reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:inventory_updated, _item_id}, socket) do
    # Reload items when inventory changes from admin
    items = Inventory.list_filtered_items(socket.assigns.selected_category, socket.assigns.search_term)

    socket =
      socket
      |> stream(:items, items, reset: true)

    {:noreply, socket}
  end
end
