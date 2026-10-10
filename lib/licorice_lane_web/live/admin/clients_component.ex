defmodule LicoriceLaneWeb.Admin.ClientsComponent do
  use LicoriceLaneWeb, :live_component

  alias LicoriceLane.Customers
  import LicoriceLaneWeb.AdminHelpers

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:search_term, fn -> "" end)
      |> assign_new(:page, fn -> 1 end)
      |> assign_new(:selected_customer, fn -> nil end)
      |> assign_new(:customer_mode, fn -> nil end)
      |> assign_new(:customer_form, fn -> nil end)
      |> assign_new(:customer_notice, fn -> nil end)
      |> load_customers()

    {:ok, socket}
  end

  defp load_customers(socket) do
    page = socket.assigns.page
    page_size = default_page_size()

    {customers, total_count} =
      Customers.list_customers_paginated(
        socket.assigns.search_term,
        page: page,
        page_size: page_size
      )

    pagination = paginate(total_count, page, page_size)

    socket
    |> assign(:page, pagination.page)
    |> assign(:pagination, pagination)
    |> stream(:customers, customers, reset: true)
  end

  @impl true
  def handle_event("search", %{"search_term" => search_term}, socket) do
    socket =
      socket
      |> assign(:search_term, search_term)
      |> assign(:page, 1)
      |> load_customers()

    {:noreply, socket}
  end

  def handle_event("page", %{"page" => page}, socket) do
    page = LicoriceLane.Pagination.page_number(page)

    socket =
      socket
      |> assign(:page, page)
      |> load_customers()

    {:noreply, socket}
  end

  def handle_event("view_customer", params, socket) do
    {:noreply, open_customer(socket, params["customer-id"], :view)}
  end

  def handle_event("edit_customer", params, socket) do
    {:noreply, open_customer(socket, params["customer-id"], :edit)}
  end

  def handle_event("close_customer", _params, socket) do
    {:noreply, socket |> close_customer() |> load_customers()}
  end

  def handle_event(
        "validate_customer",
        %{"customer" => params},
        %{assigns: %{customer_mode: :edit}} = socket
      ) do
    changeset =
      socket.assigns.selected_customer
      |> Customers.change_customer(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :customer_form, to_form(changeset))}
  end

  def handle_event(
        "save_customer",
        %{"customer" => params},
        %{assigns: %{customer_mode: :edit}} = socket
      ) do
    case Customers.update_customer(socket.assigns.selected_customer, params) do
      {:ok, _customer} ->
        {:noreply,
         socket
         |> close_customer()
         |> assign(:customer_notice, {:info, "Customer updated successfully."})
         |> load_customers()}

      {:error, changeset} ->
        notice =
          if Keyword.has_key?(changeset.errors, :id) do
            "Customer is no longer available. Close this form and choose another customer."
          else
            "Could not save customer. Please correct the errors below."
          end

        {:noreply,
         socket
         |> assign(:customer_form, to_form(changeset))
         |> assign(:customer_notice, {:error, notice})}
    end
  end

  def handle_event(event, _params, socket)
      when event in ["validate_customer", "save_customer"] do
    {:noreply, socket}
  end

  defp open_customer(socket, id, mode) do
    case find_customer(id) do
      nil ->
        socket
        |> close_customer()
        |> assign(:customer_notice, {:error, "Customer is no longer available."})
        |> load_customers()

      customer ->
        socket
        |> assign(:selected_customer, customer)
        |> assign(:customer_mode, mode)
        |> assign(:customer_form, to_form(Customers.change_customer(customer)))
        |> assign(:customer_notice, nil)
    end
  end

  defp find_customer(id) when is_binary(id) do
    case Integer.parse(id) do
      {id, ""} when id > 0 and id <= 9_223_372_036_854_775_807 -> Customers.get_customer(id)
      _ -> nil
    end
  end

  defp find_customer(_id), do: nil

  defp close_customer(socket) do
    assign(socket,
      selected_customer: nil,
      customer_mode: nil,
      customer_form: nil,
      customer_notice: nil
    )
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
        <p
          :if={@customer_notice && @customer_mode != :edit}
          id="customer-notice"
          role={if elem(@customer_notice, 0) == :error, do: "alert", else: "status"}
          class="mb-4 rounded bg-gray-50 p-3 text-sm text-gray-900"
        >
          {elem(@customer_notice, 1)}
        </p>
        <!-- Search -->
        <div class="mb-6">
          <form phx-change="search" phx-submit="search" phx-target={@myself}>
            <input
              type="text"
              name="search_term"
              value={@search_term}
              placeholder="Search names or exact email/phone..."
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

                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{customer.email}</td>

                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{customer.phone}</td>

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
        <.pagination pagination={@pagination} target={@myself} />
      </div>
      <.modal
        :if={@selected_customer}
        id="customer-detail-modal"
        show
        on_cancel={JS.push("close_customer", target: @myself)}
      >
        <h3 id="customer-detail-modal-title" class="text-lg font-semibold text-gray-900">
          {if @customer_mode == :edit, do: "Edit Customer", else: "Customer Details"}
        </h3>
        <p id="customer-detail-modal-description" class="mt-2 text-sm text-gray-500">
          {if @customer_mode == :edit,
            do: "Update this customer's contact information, billing address and notes.",
            else: "Contact information, billing details, notes and recorded locations."}
        </p>
        <div :if={@customer_mode == :view} class="mt-4 space-y-6">
          <dl class="space-y-4">
            <div :for={
              {label, field} <- [
                {"Name", :name},
                {"Contact Person", :contact_person},
                {"Email", :email},
                {"Phone", :phone},
                {"Billing Address", :billing_address},
                {"Notes", :notes}
              ]
            }>
              <dt class="text-sm font-medium text-gray-500">{label}</dt>
              <dd class="mt-1 whitespace-pre-wrap break-words text-sm text-gray-900">
                {Map.get(@selected_customer, field) || "Not provided"}
              </dd>
            </div>
          </dl>
          <div>
            <h4 class="text-sm font-medium text-gray-500">Locations</h4>
            <p :if={@selected_customer.locations == []} class="mt-1 text-sm text-gray-900">
              No locations recorded.
            </p>
            <ul class="mt-1 space-y-1 text-sm text-gray-900">
              <li :for={location <- @selected_customer.locations}>{location.name}</li>
            </ul>
          </div>
          <div class="flex justify-end gap-3">
            <.button type="button" phx-click="close_customer" phx-target={@myself}>Close</.button>
            <.button
              type="button"
              phx-click="edit_customer"
              phx-value-customer-id={@selected_customer.id}
              phx-target={@myself}
            >
              Edit Customer
            </.button>
          </div>
        </div>
        <.simple_form
          :if={@customer_mode == :edit}
          for={@customer_form}
          id="customer-edit-form"
          phx-change="validate_customer"
          phx-submit="save_customer"
          phx-target={@myself}
        >
          <p :if={@customer_notice} id="customer-edit-error" role="alert" class="text-sm text-red-600">
            {elem(@customer_notice, 1)}
          </p>
          <.input field={@customer_form[:name]} label="Name" required />
          <.input field={@customer_form[:contact_person]} label="Contact Person" />
          <.input field={@customer_form[:email]} type="email" label="Email" />
          <.input
            field={@customer_form[:phone]}
            type="tel"
            label="Phone (123-4567)"
            placeholder="555-1234"
          />
          <.input field={@customer_form[:billing_address]} type="textarea" label="Billing Address" />
          <.input field={@customer_form[:notes]} type="textarea" label="Notes" />
          <:actions>
            <.button type="button" phx-click="close_customer" phx-target={@myself}>Cancel</.button>
            <.button type="submit" phx-disable-with="Saving...">Save Customer</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end
end
