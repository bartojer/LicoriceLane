defmodule LicoriceLaneWeb.Admin.InventoryComponent do
  use LicoriceLaneWeb, :live_component

  alias LicoriceLane.Inventory

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:search_term, "")
      |> assign(:selected_category, "all")
      |> stream_configure(:items,
        dom_id: fn item_data -> "inventory-item-#{item_data.item.id}" end
      )
      |> load_inventory()

    {:ok, socket}
  end

  defp load_inventory(socket) do
    items =
      Inventory.list_filtered_items(
        socket.assigns.selected_category,
        socket.assigns.search_term
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

    stream(socket, :items, items_with_quantities, reset: true)
  end

  @impl true
  def handle_event("search", %{"search_term" => search_term}, socket) do
    socket =
      socket
      |> assign(:search_term, search_term)
      |> load_inventory()

    {:noreply, socket}
  end

  def handle_event("filter_category", %{"category" => category}, socket) do
    socket =
      socket
      |> assign(:selected_category, category)
      |> load_inventory()

    {:noreply, socket}
  end

  def handle_event("edit_item", %{"item-id" => _item_id}, socket) do
    # TODO: Implement edit functionality
    # This could open a modal or navigate to an edit page
    {:noreply, socket}
  end

  def handle_event("delete_item", %{"item-id" => _item_id}, socket) do
    # TODO: Implement delete functionality with confirmation
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <div class="flex justify-between items-center mb-6">
          <h3 class="text-lg leading-6 font-medium text-gray-900">Inventory Management</h3>
          <button class="bg-brand text-white px-4 py-2 rounded-lg hover:bg-brand/90 transition-colors">
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
      </div>
    </div>
    """
  end

  defp category_label(:candle), do: "Candles"
  defp category_label(:electric_light), do: "Electric Lights"
  defp category_label(:tableware), do: "Tableware"
  defp category_label(:linen), do: "Linens"
  defp category_label(:tray), do: "Trays"
  defp category_label(cat), do: cat |> to_string() |> String.capitalize()

  defp item_type_label(:single), do: "Single"
  defp item_type_label(:bulk), do: "Bulk"
  defp item_type_label(type), do: type |> to_string() |> String.capitalize()

  defp format_price(nil), do: "N/A"

  defp format_price(price) do
    price
    |> Decimal.round(2)
    |> Decimal.to_string()
    |> then(&"$#{&1}")
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
