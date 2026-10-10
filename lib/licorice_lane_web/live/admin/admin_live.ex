defmodule LicoriceLaneWeb.Admin.AdminLive do
  use LicoriceLaneWeb, :live_view

  alias LicoriceLaneWeb.Admin.{
    DashboardComponent,
    InventoryComponent,
    BookingsComponent,
    ClientsComponent,
    MessagesComponent,
    AddItemComponent,
    EditItemComponent
  }

  alias LicoriceLane.Messages

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Messages.subscribe()
      Phoenix.PubSub.subscribe(LicoriceLane.PubSub, "inventory:updates")
    end

    socket =
      socket
      |> assign(:active_tab, "dashboard")
      |> assign(:editing_item_id, nil)
      |> assign(:new_messages_count, Messages.count_new_messages())

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
  def handle_info({:edit_item, item_id}, socket) do
    socket =
      socket
      |> assign(:active_tab, "edit_item")
      |> assign(:editing_item_id, item_id)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:inventory_updated, _item_id}, socket) do
    case socket.assigns.active_tab do
      "dashboard" -> send_update(DashboardComponent, id: "dashboard-component")
      "inventory" -> send_update(InventoryComponent, id: "inventory-component")
      _ -> :ok
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:message_created, _message}, socket) do
    if socket.assigns.active_tab == "messages" do
      send_update(MessagesComponent, id: "messages-component")
    end

    {:noreply, assign(socket, :new_messages_count, Messages.count_new_messages())}
  end

  @impl true
  def handle_info({:message_updated, message}, socket) do
    if socket.assigns.active_tab == "messages" do
      send_update(MessagesComponent, id: "messages-component", updated_message_id: message.id)
    end

    {:noreply, assign(socket, :new_messages_count, Messages.count_new_messages())}
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
              <button
                phx-click="switch_tab"
                phx-value-tab="add_item"
                class="bg-brand text-white px-4 py-2 rounded-lg hover:bg-brand/90 transition-colors"
              >
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
              phx-value-tab="add_item"
              class={"py-4 px-1 border-b-2 font-medium text-sm #{if @active_tab == "add_item", do: "border-brand text-brand", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"}"}
            >
              Add Item
            </button>
            <button
              :if={@active_tab == "edit_item"}
              phx-click="switch_tab"
              phx-value-tab="edit_item"
              class={"py-4 px-1 border-b-2 font-medium text-sm #{if @active_tab == "edit_item", do: "border-brand text-brand", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"}"}
            >
              Edit Item
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
            <button
              phx-click="switch_tab"
              phx-value-tab="messages"
              class={"py-4 px-1 border-b-2 font-medium text-sm #{if @active_tab == "messages", do: "border-brand text-brand", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"}"}
            >
              Messages
              <%= if @new_messages_count > 0 do %>
                <span class="ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                  {@new_messages_count}
                </span>
              <% end %>
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

        <%= if @active_tab == "add_item" do %>
          <.live_component module={AddItemComponent} id="add-item-component" />
        <% end %>

        <%= if @active_tab == "edit_item" do %>
          <.live_component
            module={EditItemComponent}
            id="edit-item-component"
            item_id={@editing_item_id}
          />
        <% end %>

        <%= if @active_tab == "bookings" do %>
          <.live_component module={BookingsComponent} id="bookings-component" />
        <% end %>

        <%= if @active_tab == "clients" do %>
          <.live_component module={ClientsComponent} id="clients-component" />
        <% end %>

        <%= if @active_tab == "messages" do %>
          <.live_component module={MessagesComponent} id="messages-component" />
        <% end %>
      </div>
    </div>
    """
  end
end
