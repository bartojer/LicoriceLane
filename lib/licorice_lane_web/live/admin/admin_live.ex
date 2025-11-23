defmodule LicoriceLaneWeb.Admin.AdminLive do
  use LicoriceLaneWeb, :live_view

  alias LicoriceLaneWeb.Admin.{
    DashboardComponent,
    InventoryComponent,
    BookingsComponent,
    ClientsComponent
  }

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:active_tab, "dashboard")

    {:ok, socket}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_info({:switch_tab, tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Admin Header -->
      <div class="bg-white shadow">
        <div class="px-4 sm:px-6 lg:px-8">
          <div class="flex justify-between items-center py-6">
            <div>
              <h1 class="text-3xl font-bold text-gray-900">Admin Dashboard</h1>
              <p class="mt-1 text-sm text-gray-500">Manage your event decor business</p>
            </div>
            <div class="flex items-center space-x-4">
              <button class="bg-brand text-white px-4 py-2 rounded-lg hover:bg-brand/90 transition-colors">
                Add Inventory Item
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
              phx-value-tab="inventory"
              class={"py-4 px-1 border-b-2 font-medium text-sm #{if @active_tab == "inventory", do: "border-brand text-brand", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"}"}
            >
              Inventory
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="bookings"
              class={"py-4 px-1 border-b-2 font-medium text-sm #{if @active_tab == "bookings", do: "border-brand text-brand", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"}"}
            >
              Bookings
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="clients"
              class={"py-4 px-1 border-b-2 font-medium text-sm #{if @active_tab == "clients", do: "border-brand text-brand", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"}"}
            >
              Clients
            </button>
          </nav>
        </div>
      </div>
      
    <!-- Main Content -->
      <div class="px-4 sm:px-6 lg:px-8 py-8">
        <%= if @active_tab == "dashboard" do %>
          <.live_component module={DashboardComponent} id="dashboard-component" />
        <% end %>

        <%= if @active_tab == "inventory" do %>
          <.live_component module={InventoryComponent} id="inventory-component" />
        <% end %>

        <%= if @active_tab == "bookings" do %>
          <.live_component module={BookingsComponent} id="bookings-component" />
        <% end %>

        <%= if @active_tab == "clients" do %>
          <.live_component module={ClientsComponent} id="clients-component" />
        <% end %>
      </div>
    </div>
    """
  end
end
