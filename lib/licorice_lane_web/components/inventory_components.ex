defmodule LicoriceLaneWeb.InventoryComponents do
  use Phoenix.Component

  attr :item, LicoriceLane.Items.Item, required: true
  attr :id, :string, required: true

  def inventory_card(assigns) do
    ~H"""
    <div
      id={@id}
      class="group relative bg-white rounded-lg shadow-sm border border-gray-200 hover:shadow-md transition-shadow duration-200"
    >
      <!-- Product Image -->
      <div class="aspect-square w-full overflow-hidden rounded-t-lg bg-gray-200">
        <%= if @item.image_path do %>
          <img src={@item.image_path} alt={@item.name} class="h-full w-full object-cover" />
        <% else %>
          <div class="h-full w-full bg-gradient-to-br from-purple-100 to-pink-100 flex items-center justify-center">
            <div class="text-center text-gray-500">
              <svg
                class="mx-auto h-16 w-16 mb-2"
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
              <p class="text-sm">Decor Item Image</p>
            </div>
          </div>
        <% end %>
      </div>
      
    <!-- Product Info -->
      <div class="p-4">
        <div class="flex justify-between items-start mb-2">
          <h3 class="text-lg font-semibold text-gray-900 group-hover:text-brand transition-colors">
            {@item.name}
          </h3>
          <%= if availability_status(@item) == :available do %>
            <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
              {availability_label(@item)}
            </span>
          <% else %>
            <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-red-100 text-red-800">
              Out of Stock
            </span>
          <% end %>
        </div>

        <p class="text-sm text-gray-600 mb-3">
          {@item.description}
        </p>

        <div class="flex justify-between items-center">
          <span class="text-xl font-bold text-brand">
            {format_price(@item.rental_price)}
          </span>
          <%= if availability_status(@item) == :available do %>
            <button class="px-4 py-2 bg-brand text-white text-sm rounded-lg hover:bg-brand/90 transition-colors">
              Add to Cart
            </button>
          <% else %>
            <button
              disabled
              class="px-4 py-2 bg-gray-300 text-gray-500 text-sm rounded-lg cursor-not-allowed"
            >
              Sold Out
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp availability_status(%{item_type: :single, single_item: single_item})
       when not is_nil(single_item) do
    if single_item.status == :available, do: :available, else: :unavailable
  end

  defp availability_status(%{item_type: :single, single_item: nil}) do
    :unavailable
  end

  defp availability_status(%{item_type: :bulk, items_locations: items_locations}) do
    total_quantity = calculate_warehouse_quantity(items_locations)
    if total_quantity > 0, do: :available, else: :unavailable
  end

  defp availability_label(%{item_type: :single}) do
    "Available"
  end

  defp availability_label(%{item_type: :bulk, items_locations: items_locations}) do
    quantity = calculate_warehouse_quantity(items_locations)
    "In Stock: #{quantity}"
  end

  defp calculate_warehouse_quantity(items_locations) when is_list(items_locations) do
    items_locations
    |> Enum.filter(fn il -> il.location.location_type == :warehouse end)
    |> Enum.map(& &1.quantity)
    |> Enum.sum()
  end

  defp format_price(nil), do: "$4.20"

  # I'll have to figure out what's going on here "%Decimal{} = price"
  defp format_price(%Decimal{} = price) do
    "$#{Decimal.to_string(price, :normal)}"
  end

  defp format_price(price) when is_number(price) do
    :erlang.float_to_binary(price / 1, decimals: 2)
    |> then(&"$#{&1}")
  end
end
