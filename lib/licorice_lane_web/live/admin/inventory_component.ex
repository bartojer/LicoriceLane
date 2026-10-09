defmodule LicoriceLaneWeb.Admin.InventoryComponent do
  use LicoriceLaneWeb, :live_component

  alias LicoriceLane.Inventory
  import LicoriceLaneWeb.AdminHelpers

  @impl true
  def mount(socket) do
    socket =
      stream_configure(socket, :items, dom_id: fn data -> "inventory-item-#{data.item.id}" end)

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:search_term, fn -> "" end)
      |> assign_new(:selected_category, fn -> "all" end)
      |> assign_new(:page, fn -> 1 end)
      |> load_inventory()

    {:ok, socket}
  end

  defp load_inventory(socket) do
    page = socket.assigns.page
    page_size = default_page_size()

    {items, total_count} =
      Inventory.list_filtered_items_paginated(
        socket.assigns.selected_category,
        socket.assigns.search_term,
        page: page,
        page_size: page_size
      )

    # Calculate warehouse quantities for each item
    items_with_quantities =
      Enum.map(items, fn item ->
        warehouse_qty =
          item.items_locations
          |> Enum.filter(fn il -> il.location.location_type == :warehouse end)
          |> Enum.reduce(0, fn il, acc -> acc + il.quantity end)

        %{item: item, warehouse_quantity: warehouse_qty}
      end)

    pagination = paginate(total_count, page, page_size)

    socket
    |> assign(:page, pagination.page)
    |> assign(:pagination, pagination)
    |> stream(:items, items_with_quantities, reset: true)
  end

  @impl true
  def handle_event("search", %{"search_term" => search_term}, socket) do
    socket =
      socket
      |> assign(:search_term, search_term)
      |> assign(:page, 1)
      |> load_inventory()

    {:noreply, socket}
  end

  def handle_event("filter_category", %{"category" => category}, socket) do
    socket =
      socket
      |> assign(:selected_category, category)
      |> assign(:page, 1)
      |> load_inventory()

    {:noreply, socket}
  end

  def handle_event("page", %{"page" => page}, socket) do
    page = LicoriceLane.Pagination.page_number(page)

    socket =
      socket
      |> assign(:page, page)
      |> load_inventory()

    {:noreply, socket}
  end

  def handle_event("edit_item", %{"item-id" => item_id}, socket) do
    send(self(), {:edit_item, String.to_integer(item_id)})
    {:noreply, socket}
  end

  def handle_event("delete_item", %{"item-id" => _item_id}, socket) do
    # TODO: Implement delete functionality with confirmation
    {:noreply, socket}
  end

  def handle_event("switch_to_add_item", _params, socket) do
    send(self(), {:switch_tab, "add_item"})
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <div class="flex justify-between items-center mb-6">
          <h3 class="text-lg leading-6 font-medium text-gray-900">Inventory Management</h3>

          <button
            phx-click="switch_to_add_item"
            phx-target={@myself}
            class="bg-brand text-white px-4 py-2 rounded-lg hover:bg-brand/90 transition-colors"
          >
            Add New Item
          </button>
        </div>
        <!-- Search and Filter -->
        <div class="flex flex-col sm:flex-row gap-4 mb-6">
          <div class="flex-1">
            <form phx-change="search" phx-submit="search" phx-target={@myself}>
              <input
                type="text"
                name="search_term"
                value={@search_term}
                placeholder="Search inventory..."
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-brand focus:border-brand"
              />
            </form>
          </div>

          <form phx-change="filter_category" phx-target={@myself}>
            <select
              name="category"
              class="px-3 py-2 border border-gray-300 rounded-md focus:ring-brand focus:border-brand"
            >
              <option value="all" selected={@selected_category == "all"}>All Categories</option>

              <option value="candle" selected={@selected_category == "candle"}>Candles</option>

              <option value="electric_light" selected={@selected_category == "electric_light"}>
                Electric Lights
              </option>

              <option value="tableware" selected={@selected_category == "tableware"}>
                Tableware
              </option>

              <option value="linen" selected={@selected_category == "linen"}>Linens</option>

              <option value="tray" selected={@selected_category == "tray"}>Trays</option>
            </select>
          </form>
        </div>
        <!-- Inventory Table -->
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Thumbnail
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Item
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Category
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Type
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Warehouse Stock
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Min Stock
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Price
                </th>

                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>

            <tbody class="bg-white divide-y divide-gray-200" id="inventory-items" phx-update="stream">
              <tr :for={{dom_id, item_data} <- @streams.items} id={dom_id}>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="h-12 w-12 flex-shrink-0">
                    <%= if item_data.item.image_path do %>
                      <img
                        src={item_data.item.image_path}
                        alt={item_data.item.name}
                        class="h-12 w-12 rounded object-cover"
                      />
                    <% else %>
                      <div class="h-12 w-12 rounded bg-gray-200 flex items-center justify-center">
                        <svg
                          class="h-6 w-6 text-gray-400"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="1.5"
                            d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                          />
                        </svg>
                      </div>
                    <% end %>
                  </div>
                </td>

                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="text-sm font-medium text-gray-900">{item_data.item.name}</div>

                  <div class="text-sm text-gray-500">{item_data.item.description}</div>
                </td>

                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {category_label(item_data.item.category)}
                </td>

                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {item_type_label(item_data.item.item_type)}
                </td>

                <td class="px-6 py-4 whitespace-nowrap">
                  <span class={
                    "text-sm #{if item_data.warehouse_quantity <= item_data.item.min_stock, do: "text-red-600 font-medium", else: "text-gray-900"}"
                  }>
                    {item_data.warehouse_quantity}
                  </span>
                  <div :if={item_data.item.item_type == :bulk} class="text-xs text-gray-500 mt-1">
                    {render_warehouse_breakdown(item_data.item)}
                  </div>
                </td>

                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {item_data.item.min_stock}
                </td>

                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {format_price(item_data.item.rental_price)}
                </td>

                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium space-x-2">
                  <button
                    phx-click="edit_item"
                    phx-value-item-id={item_data.item.id}
                    phx-target={@myself}
                    class="text-brand hover:text-brand/80"
                  >
                    Edit
                  </button>
                  <button
                    phx-click="delete_item"
                    phx-value-item-id={item_data.item.id}
                    phx-target={@myself}
                    class="text-red-600 hover:text-red-900"
                  >
                    Delete
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
         <.pagination pagination={@pagination} target={@myself} />
      </div>
    </div>
    """
  end

  defp render_warehouse_breakdown(item) do
    warehouses =
      item.items_locations
      |> Enum.filter(fn il -> il.location.location_type == :warehouse end)
      |> Enum.map(fn il -> "#{il.location.name}: #{il.quantity}" end)
      |> Enum.join(", ")

    if warehouses == "", do: "No warehouse stock", else: warehouses
  end
end
