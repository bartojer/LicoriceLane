defmodule LicoriceLaneWeb.AdminLive do
  use LicoriceLaneWeb, :live_view

  def mount(_params, _session, socket) do
    # Mock admin data - replace with real data later
    stats = %{
      total_products: 127,
      total_orders: 89,
      revenue_today: "$1,247.50",
      low_stock_items: 8
    }

    recent_orders = [
      %{
        id: "ORD-001",
        customer: "Sarah Johnson",
        total: "$23.97",
        status: "shipped",
        date: "2025-10-29"
      },
      %{
        id: "ORD-002",
        customer: "Mike Chen",
        total: "$15.49",
        status: "processing",
        date: "2025-10-29"
      },
      %{
        id: "ORD-003",
        customer: "Emily Davis",
        total: "$41.25",
        status: "pending",
        date: "2025-10-28"
      }
    ]

    low_stock_products = [
      %{
        id: 1,
        name: "Swedish Fish Assortment",
        current_stock: 3,
        min_stock: 10,
        category: "red"
      },
      %{
        id: 2,
        name: "Classic Dutch Black Licorice",
        current_stock: 7,
        min_stock: 15,
        category: "black"
      },
      %{
        id: 3,
        name: "Artisan Anise Drops",
        current_stock: 2,
        min_stock: 8,
        category: "black"
      }
    ]

    socket =
      socket
      |> assign(:stats, stats)
      |> assign(:recent_orders, recent_orders)
      |> assign(:low_stock_products, low_stock_products)
      |> assign(:active_tab, "dashboard")

    {:ok, socket}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Admin Header -->
      <div class="bg-white shadow">
        <div class="px-4 sm:px-6 lg:px-8">
          <div class="flex justify-between items-center py-6">
            <div>
              <h1 class="text-3xl font-bold text-gray-900">Admin Dashboard</h1>
              <p class="mt-1 text-sm text-gray-500">Manage your Licorice Lane store</p>
            </div>
            <div class="flex items-center space-x-4">
              <button class="bg-brand text-white px-4 py-2 rounded-lg hover:bg-brand/90 transition-colors">
                Add Product
              </button>
              <div class="flex items-center space-x-2">
                <div class="w-8 h-8 bg-brand rounded-full flex items-center justify-center">
                  <span class="text-white text-sm font-medium">A</span>
                </div>
                <span class="text-sm font-medium text-gray-700">Admin User</span>
              </div>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Navigation Tabs -->
      <div class="bg-white border-b border-gray-200">
        <div class="px-4 sm:px-6 lg:px-8">
          <nav class="flex space-x-8" aria-label="Tabs">
            <button
              phx-click="switch_tab"
              phx-value-tab="dashboard"
              class={"py-4 px-1 border-b-2 font-medium text-sm #{if @active_tab == "dashboard", do: "border-brand text-brand", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"}"}
            >
              Dashboard
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="products"
              class={"py-4 px-1 border-b-2 font-medium text-sm #{if @active_tab == "products", do: "border-brand text-brand", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"}"}
            >
              Products
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="orders"
              class={"py-4 px-1 border-b-2 font-medium text-sm #{if @active_tab == "orders", do: "border-brand text-brand", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"}"}
            >
              Orders
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="customers"
              class={"py-4 px-1 border-b-2 font-medium text-sm #{if @active_tab == "customers", do: "border-brand text-brand", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"}"}
            >
              Customers
            </button>
          </nav>
        </div>
      </div>
      
    <!-- Main Content -->
      <div class="px-4 sm:px-6 lg:px-8 py-8">
        <%= if @active_tab == "dashboard" do %>
          {render_dashboard(assigns)}
        <% end %>

        <%= if @active_tab == "products" do %>
          {render_products(assigns)}
        <% end %>

        <%= if @active_tab == "orders" do %>
          {render_orders(assigns)}
        <% end %>

        <%= if @active_tab == "customers" do %>
          {render_customers(assigns)}
        <% end %>
      </div>
    </div>
    """
  end

  defp render_dashboard(assigns) do
    ~H"""
    <div class="space-y-8">
      <!-- Stats Grid -->
      <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-blue-500 rounded-md flex items-center justify-center">
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
                      d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"
                    />
                  </svg>
                </div>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Total Products</dt>
                  <dd class="text-lg font-medium text-gray-900">{@stats.total_products}</dd>
                </dl>
              </div>
            </div>
          </div>
        </div>

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
                  <dt class="text-sm font-medium text-gray-500 truncate">Total Orders</dt>
                  <dd class="text-lg font-medium text-gray-900">{@stats.total_orders}</dd>
                </dl>
              </div>
            </div>
          </div>
        </div>

        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-yellow-500 rounded-md flex items-center justify-center">
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
                      d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1"
                    />
                  </svg>
                </div>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Today's Revenue</dt>
                  <dd class="text-lg font-medium text-gray-900">{@stats.revenue_today}</dd>
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
        <!-- Recent Orders -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Recent Orders</h3>
            <div class="space-y-3">
              <%= for order <- @recent_orders do %>
                <div class="flex items-center justify-between py-3 border-b border-gray-200 last:border-b-0">
                  <div class="flex items-center space-x-3">
                    <div>
                      <p class="text-sm font-medium text-gray-900">{order.id}</p>
                      <p class="text-sm text-gray-500">{order.customer}</p>
                    </div>
                  </div>
                  <div class="flex items-center space-x-3">
                    <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{order_status_class(order.status)}"}>
                      {String.capitalize(order.status)}
                    </span>
                    <span class="text-sm font-medium text-gray-900">{order.total}</span>
                  </div>
                </div>
              <% end %>
            </div>
            <div class="mt-4">
              <button class="text-sm text-brand hover:text-brand/80">View all orders →</button>
            </div>
          </div>
        </div>
        
    <!-- Low Stock Items -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Low Stock Alert</h3>
            <div class="space-y-3">
              <%= for product <- @low_stock_products do %>
                <div class="flex items-center justify-between py-3 border-b border-gray-200 last:border-b-0">
                  <div>
                    <p class="text-sm font-medium text-gray-900">{product.name}</p>
                    <p class="text-sm text-gray-500">
                      Category: {String.capitalize(product.category)}
                    </p>
                  </div>
                  <div class="text-right">
                    <p class="text-sm font-medium text-red-600">{product.current_stock} left</p>
                    <p class="text-xs text-gray-500">Min: {product.min_stock}</p>
                  </div>
                </div>
              <% end %>
            </div>
            <div class="mt-4">
              <button class="text-sm text-brand hover:text-brand/80">Reorder products →</button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_products(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <div class="flex justify-between items-center mb-6">
          <h3 class="text-lg leading-6 font-medium text-gray-900">Product Management</h3>
          <button class="bg-brand text-white px-4 py-2 rounded-lg hover:bg-brand/90 transition-colors">
            Add New Product
          </button>
        </div>
        
    <!-- Search and Filter -->
        <div class="flex flex-col sm:flex-row gap-4 mb-6">
          <div class="flex-1">
            <input
              type="text"
              placeholder="Search products..."
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-brand focus:border-brand"
            />
          </div>
          <select class="px-3 py-2 border border-gray-300 rounded-md focus:ring-brand focus:border-brand">
            <option>All Categories</option>
            <option>Black Licorice</option>
            <option>Red Licorice</option>
            <option>Mixed</option>
          </select>
        </div>
        
    <!-- Products Table -->
        <div class="overflow-hidden">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Product
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Category
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Stock
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Price
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="text-sm font-medium text-gray-900">Classic Dutch Black Licorice</div>
                  <div class="text-sm text-gray-500">Traditional salt licorice</div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">Black</td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">45</td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">$8.99</td>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium space-x-2">
                  <button class="text-brand hover:text-brand/80">Edit</button>
                  <button class="text-red-600 hover:text-red-900">Delete</button>
                </td>
              </tr>
              <!-- More rows would go here -->
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  defp render_orders(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <h3 class="text-lg leading-6 font-medium text-gray-900 mb-6">Order Management</h3>
        
    <!-- Order Filters -->
        <div class="flex flex-col sm:flex-row gap-4 mb-6">
          <select class="px-3 py-2 border border-gray-300 rounded-md focus:ring-brand focus:border-brand">
            <option>All Orders</option>
            <option>Pending</option>
            <option>Processing</option>
            <option>Shipped</option>
            <option>Delivered</option>
          </select>
          <input
            type="date"
            class="px-3 py-2 border border-gray-300 rounded-md focus:ring-brand focus:border-brand"
          />
        </div>
        
    <!-- Orders Table -->
        <div class="overflow-hidden">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Order ID
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Customer
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Date
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Total
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for order <- @recent_orders do %>
                <tr>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    {order.id}
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{order.customer}</td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{order.date}</td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{order.total}</td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{order_status_class(order.status)}"}>
                      {String.capitalize(order.status)}
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium space-x-2">
                    <button class="text-brand hover:text-brand/80">View</button>
                    <button class="text-gray-600 hover:text-gray-900">Update</button>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  defp render_customers(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <h3 class="text-lg leading-6 font-medium text-gray-900 mb-6">Customer Management</h3>

        <div class="text-center py-12">
          <svg
            class="mx-auto h-12 w-12 text-gray-400"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"
            />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">Customer Management</h3>
          <p class="mt-1 text-sm text-gray-500">Customer management features coming soon.</p>
        </div>
      </div>
    </div>
    """
  end

  defp order_status_class("pending"), do: "bg-yellow-100 text-yellow-800"
  defp order_status_class("processing"), do: "bg-blue-100 text-blue-800"
  defp order_status_class("shipped"), do: "bg-green-100 text-green-800"
  defp order_status_class("delivered"), do: "bg-green-100 text-green-800"
  defp order_status_class(_), do: "bg-gray-100 text-gray-800"
end
