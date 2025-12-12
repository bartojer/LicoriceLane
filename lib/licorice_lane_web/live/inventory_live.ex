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
      |> assign(:selected_item, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    case Inventory.get_item_with_full_preloads(id) do
      nil ->
        socket
        # add item id
        |> put_flash(:error, "Item not found")
        |> assign(:selected_item, nil)

      item ->
        assign(socket, :selected_item, item)
    end
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, :selected_item, nil)
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

    <!-- Item Detail Modal -->
    <.modal :if={@selected_item} id="item-detail-modal" show on_cancel={JS.patch(~p"/inventory")}>
      <div class="space-y-6">
        <!-- Item Image -->
        <div class="aspect-square w-full overflow-hidden rounded-lg bg-gray-200">
          <%= if @selected_item.image_path do %>
            <img
              src={@selected_item.image_path}
              alt={@selected_item.name}
              class="h-full w-full object-cover"
            />
          <% else %>
            <div class="h-full w-full bg-gradient-to-br from-purple-100 to-pink-100 flex items-center justify-center">
              <div class="text-center text-gray-500">
                <svg
                  class="mx-auto h-24 w-24 mb-4"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="1"
                    d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                  >
                  </path>
                </svg>
                <p class="text-lg">Decor Item Image</p>
              </div>
            </div>
          <% end %>
        </div>

    <!-- Item Info -->
        <div>
          <h2 class="text-3xl font-bold text-gray-900">{@selected_item.name}</h2>
          <div class="mt-3 flex items-center gap-2">
            <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-purple-100 text-purple-800">
              {category_label(@selected_item.category)}
            </span>
            <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-blue-100 text-blue-800">
              {item_type_label(@selected_item.item_type)}
            </span>
            <%= if availability_status(@selected_item) == :available do %>
              <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-green-100 text-green-800">
                Available
              </span>
            <% else %>
              <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-red-100 text-red-800">
                Out of Stock
              </span>
            <% end %>
          </div>
        </div>

    <!-- Description -->
        <div>
          <h3 class="text-lg font-semibold text-gray-900 mb-2">Description</h3>
          <p class="text-gray-600 leading-relaxed">{@selected_item.description}</p>
        </div>

    <!-- Price -->
        <div class="border-t pt-4">
          <div class="flex items-baseline gap-2">
            <span class="text-sm text-gray-500">Rental Price:</span>
            <span class="text-3xl font-bold text-brand">
              {format_price(@selected_item.rental_price)}
            </span>
          </div>
        </div>

    <!-- Action Button -->
        <div class="border-t pt-4">
          <%= if availability_status(@selected_item) == :available do %>
            <button class="w-full px-6 py-3 bg-brand text-white text-lg font-medium rounded-lg hover:bg-brand/90 transition-colors">
              Add to Cart
            </button>
          <% else %>
            <button
              disabled
              class="w-full px-6 py-3 bg-gray-300 text-gray-500 text-lg font-medium rounded-lg cursor-not-allowed"
            >
              Currently Unavailable
            </button>
          <% end %>
        </div>
      </div>
    </.modal>
    """
  end

  # Helper functions for modal display
  defp category_label(:candle), do: "Candles"
  defp category_label(:electric_light), do: "Electric Lighting"
  defp category_label(:tableware), do: "Tableware"
  defp category_label(:linen), do: "Linens"
  defp category_label(:tray), do: "Trays"
  defp category_label(cat), do: cat |> to_string() |> String.capitalize()

  defp item_type_label(:single), do: "Single Item"
  defp item_type_label(:bulk), do: "Bulk Item"
  defp item_type_label(type), do: type |> to_string() |> String.capitalize()

  defp format_price(nil), do: "N/A"

  defp format_price(price) do
    price
    |> Decimal.round(2)
    |> Decimal.to_string()
    |> then(&"$#{&1}")
  end

  defp availability_status(item) do
    # Use the same logic from inventory_components
    cond do
      item.item_type == :single and item.single_item != nil -> :available
      item.item_type == :bulk -> check_bulk_availability(item)
      true -> :unavailable
    end
  end

  defp check_bulk_availability(item) do
    total_quantity =
      item.items_locations
      |> Enum.filter(fn il -> il.location.location_type == :warehouse end)
      |> Enum.reduce(0, fn il, acc -> acc + il.quantity end)

    if total_quantity > 0, do: :available, else: :unavailable
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
    items =
      Inventory.list_filtered_items(socket.assigns.selected_category, socket.assigns.search_term)

    socket =
      socket
      |> stream(:items, items, reset: true)

    {:noreply, socket}
  end
end
