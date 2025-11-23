defmodule LicoriceLaneWeb.Admin.ClientsComponent do
  use LicoriceLaneWeb, :live_component

  alias LicoriceLane.Customers

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:search_term, "")
      |> load_customers()

    {:ok, socket}
  end

  defp load_customers(socket) do
    customers =
      if socket.assigns.search_term == "" do
        Customers.list_customers()
      else
        Customers.search_customers(socket.assigns.search_term)
      end

    stream(socket, :customers, customers, reset: true)
  end

  @impl true
  def handle_event("search", %{"search_term" => search_term}, socket) do
    socket =
      socket
      |> assign(:search_term, search_term)
      |> load_customers()

    {:noreply, socket}
  end

  def handle_event("view_customer", %{"customer-id" => _customer_id}, socket) do
    # TODO: Implement view customer details
    {:noreply, socket}
  end

  def handle_event("edit_customer", %{"customer-id" => _customer_id}, socket) do
    # TODO: Implement edit customer functionality
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <div class="flex justify-between items-center mb-6">
          <h3 class="text-lg leading-6 font-medium text-gray-900">Client Management</h3>
          <button class="bg-brand text-white px-4 py-2 rounded-lg hover:bg-brand/90 transition-colors">
            Add New Client
          </button>
        </div>
        
    <!-- Search -->
        <div class="mb-6">
          <form phx-change="search" phx-submit="search" phx-target={@myself}>
            <input
              type="text"
              name="search_term"
              value={@search_term}
              placeholder="Search clients by name, email, or phone..."
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-brand focus:border-brand"
            />
          </form>
        </div>
        
    <!-- Clients Table -->
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Name
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Contact Person
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Email
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Phone
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Address
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200" id="clients-list" phx-update="stream">
              <tr :for={{dom_id, customer} <- @streams.customers} id={dom_id}>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="text-sm font-medium text-gray-900">{customer.name}</div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {customer.contact_person}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {customer.email}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {customer.phone}
                </td>
                <td class="px-6 py-4 text-sm text-gray-900">
                  <div class="max-w-xs truncate">{customer.billing_address}</div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium space-x-2">
                  <button
                    phx-click="view_customer"
                    phx-value-customer-id={customer.id}
                    phx-target={@myself}
                    class="text-brand hover:text-brand/80"
                  >
                    View
                  </button>
                  <button
                    phx-click="edit_customer"
                    phx-value-customer-id={customer.id}
                    phx-target={@myself}
                    class="text-gray-600 hover:text-gray-900"
                  >
                    Edit
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
end
