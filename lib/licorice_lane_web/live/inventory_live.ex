defmodule LicoriceLaneWeb.InventoryLive do
  use LicoriceLaneWeb, :live_view

  def mount(_params, _session, socket) do
    # Mock inventory data - replace with real data later
    inventory = [
      %{
        id: 1,
        name: "Elegant Pillar Candles Set",
        description: "Set of 3 ivory pillar candles, 6\" tall, perfect for centerpieces",
        price: "$24.99",
        image: "/images/placeholder-decor.jpg",
        in_stock: true,
        category: "candles"
      },
      %{
        id: 2,
        name: "Silver Charger Plates",
        description: "Premium silver-rimmed glass charger plates, set of 8",
        price: "$45.99",
        image: "/images/placeholder-decor.jpg",
        in_stock: true,
        category: "tableware"
      },
      %{
        id: 3,
        name: "Burgundy Velvet Tablecloth",
        description: "Luxurious 90\"x156\" burgundy velvet tablecloth for rectangular tables",
        price: "$89.99",
        image: "/images/placeholder-decor.jpg",
        in_stock: false,
        category: "linens"
      },
      %{
        id: 4,
        name: "Crystal Centerpiece Bowl",
        description:
          "Hand-cut crystal bowl perfect for floral arrangements or decorative displays",
        price: "$125.99",
        image: "/images/placeholder-decor.jpg",
        in_stock: true,
        category: "tableware"
      },
      %{
        id: 5,
        name: "Gold Tea Light Holders",
        description: "Set of 12 antique gold mercury glass tea light holders",
        price: "$36.99",
        image: "/images/placeholder-decor.jpg",
        in_stock: true,
        category: "candles"
      },
      %{
        id: 6,
        name: "Champagne Satin Napkins",
        description: "Premium satin napkins in champagne color, set of 20",
        price: "$32.99",
        image: "/images/placeholder-decor.jpg",
        in_stock: true,
        category: "linens"
      },
      %{
        id: 7,
        name: "Rustic Wood Cake Stand",
        description: "Natural wood cake stand with metal base, 12\" diameter",
        price: "$42.99",
        image: "/images/placeholder-decor.jpg",
        in_stock: true,
        category: "tableware"
      },
      %{
        id: 8,
        name: "LED String Lights",
        description: "Warm white LED fairy lights, 100ft, battery operated with timer",
        price: "$28.99",
        image: "/images/placeholder-decor.jpg",
        in_stock: true,
        category: "lighting"
      }
    ]

    socket =
      socket
      |> assign(:inventory, inventory)
      |> assign(:full_inventory, inventory)

    {:ok, socket}
  end

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
              phx-click="show_candles_and_lighting"
              class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors"
            >
              Candles & Lighting
            </button>
            <button
              phx-click="show_tableware"
              class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors"
            >
              Tableware
            </button>
            <button
              phx-click="show_linens"
              class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors"
            >
              Linens
            </button>
          </div>
          <div class="relative">
            <input
              type="text"
              placeholder="Search decor items..."
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
          </div>
        </div>
        
    <!-- Inventory Grid -->
        <div class="mt-10 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          <%= for item <- @inventory do %>
            <div class="group relative bg-white rounded-lg shadow-sm border border-gray-200 hover:shadow-md transition-shadow duration-200">
              <!-- Product Image -->
              <div class="aspect-square w-full overflow-hidden rounded-t-lg bg-gray-200">
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
              </div>
              
    <!-- Product Info -->
              <div class="p-4">
                <div class="flex justify-between items-start mb-2">
                  <h3 class="text-lg font-semibold text-gray-900 group-hover:text-brand transition-colors">
                    {item.name}
                  </h3>
                  <%= if item.in_stock do %>
                    <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                      In Stock
                    </span>
                  <% else %>
                    <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-red-100 text-red-800">
                      Out of Stock
                    </span>
                  <% end %>
                </div>

                <p class="text-sm text-gray-600 mb-3">
                  {item.description}
                </p>

                <div class="flex justify-between items-center">
                  <span class="text-xl font-bold text-brand">
                    {item.price}
                  </span>
                  <%= if item.in_stock do %>
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
          <% end %>
        </div>
        
    <!-- Load More Section -->
        <div class="mt-12 text-center">
          <button class="px-6 py-3 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors">
            Load More Items
          </button>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("show_all", _payload, socket) do
    {:noreply, assign(socket, :inventory, socket.assigns.full_inventory)}
  end

  def handle_event("show_candles_and_lighting", _payload, socket) do
    candles = filter_inventory(socket.assigns.inventory, "candles")

    socket =
      assigns(socket, :inventory, candles)
      |> update(:inventory, "fn that adds lights")

    {:noreply, socket}
  end

  def handle_event("show_tableware", _payload, socket) do
    inventory = filter_inventory(socket.assigns.inventory, "tableware")
    socket = update(socket, :inventory, inventory)

    {:noreply, socket}
  end

  def handle_event("show_", _payload, socket) do
    inventory = filter_inventory(socket.assigns.inventory, "asdf")
    socket = update(socket, :inventory, inventory)

    {:noreply, socket}
  end

  def filter_inventory(inventory, inv_type) do
    Enum.filter(inventory, fn item -> item.category == inv_type end)
  end
end
