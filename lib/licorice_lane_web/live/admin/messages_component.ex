defmodule LicoriceLaneWeb.Admin.MessagesComponent do
  use LicoriceLaneWeb, :live_component

  alias LicoriceLane.Messages
  import LicoriceLaneWeb.AdminHelpers

  @impl true
  def update(assigns, socket) do
    {updated_message_id, assigns} = Map.pop(assigns, :updated_message_id)

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:search_term, fn -> "" end)
      |> assign_new(:filter_status, fn -> :all end)
      |> assign_new(:selected_message, fn -> nil end)
      |> assign_new(:show_modal, fn -> false end)
      |> assign_new(:admin_notes, fn -> "" end)
      |> assign_new(:notes_dirty, fn -> false end)
      |> assign_new(:page, fn -> 1 end)
      |> refresh_selected_message(updated_message_id)
      |> load_messages()

    {:ok, socket}
  end

  defp load_messages(socket) do
    page = socket.assigns.page
    page_size = default_page_size()

    {messages, total_count} =
      Messages.list_messages_paginated(
        status: socket.assigns.filter_status,
        search_term: socket.assigns.search_term,
        page: page,
        page_size: page_size
      )

    pagination = paginate(total_count, page, page_size)

    socket
    |> assign(:page, pagination.page)
    |> assign(:pagination, pagination)
    |> stream(:messages, messages, reset: true)
  end

  @impl true
  def handle_event("search", %{"search_term" => search_term}, socket) do
    socket =
      socket
      |> assign(:search_term, search_term)
      |> assign(:page, 1)
      |> load_messages()

    {:noreply, socket}
  end

  def handle_event("filter_status", %{"status" => status}, socket) do
    filter_status =
      case status do
        "all" -> :all
        "new" -> :new
        "read" -> :read
        "archived" -> :archived
        _ -> :all
      end

    socket =
      socket
      |> assign(:filter_status, filter_status)
      |> assign(:search_term, "")
      |> assign(:page, 1)
      |> load_messages()

    {:noreply, socket}
  end

  def handle_event("page", %{"page" => page}, socket) do
    page = LicoriceLane.Pagination.page_number(page)

    socket =
      socket
      |> assign(:page, page)
      |> load_messages()

    {:noreply, socket}
  end

  def handle_event("view_message", %{"message-id" => message_id}, socket) do
    message = Messages.get_message!(message_id)

    # Auto-mark as read when opened
    message =
      if message.status == :new do
        case Messages.mark_as_read(message) do
          {:ok, updated} -> updated
          {:error, _changeset} -> message
        end
      else
        message
      end

    socket =
      socket
      |> assign(:selected_message, message)
      |> assign(:show_modal, true)
      |> assign(:admin_notes, message.admin_notes || "")
      |> assign(:notes_dirty, false)

    {:noreply, socket}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply,
     assign(socket, show_modal: false, selected_message: nil, admin_notes: "", notes_dirty: false)}
  end

  def handle_event("update_status", %{"status" => status}, socket) do
    message = socket.assigns.selected_message

    case status do
      "new" -> Messages.mark_as_new(message)
      "read" -> Messages.mark_as_read(message)
      "archived" -> Messages.mark_as_archived(message)
      _ -> {:ok, message}
    end

    # Refresh the message details
    updated_message = Messages.get_message!(message.id)

    {:noreply, assign(socket, selected_message: updated_message)}
  end

  def handle_event("change_admin_notes", %{"admin_notes" => notes}, socket) do
    {:noreply, assign(socket, admin_notes: notes, notes_dirty: true)}
  end

  def handle_event("update_admin_notes", %{"value" => notes}, socket) do
    message = socket.assigns.selected_message

    case Messages.update_message_status(message, %{admin_notes: notes}) do
      {:ok, updated} ->
        {:noreply,
         assign(socket, selected_message: updated, admin_notes: notes, notes_dirty: false)}

      {:error, _changeset} ->
        {:noreply, assign(socket, admin_notes: notes, notes_dirty: true)}
    end
  end

  defp refresh_selected_message(socket, message_id) do
    if socket.assigns.selected_message &&
         socket.assigns.selected_message.id == message_id do
      # Read current state rather than applying a potentially older queued broadcast.
      message = Messages.get_message(message_id)
      socket = assign(socket, :selected_message, message)

      cond do
        is_nil(message) ->
          assign(socket, show_modal: false, admin_notes: "", notes_dirty: false)

        socket.assigns.notes_dirty ->
          socket

        true ->
          assign(socket, :admin_notes, message.admin_notes || "")
      end
    else
      socket
    end
  end

  defp status_badge_class(:new), do: "bg-green-100 text-green-800"
  defp status_badge_class(:read), do: "bg-blue-100 text-blue-800"
  defp status_badge_class(:archived), do: "bg-gray-100 text-gray-800"

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="bg-white shadow rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <div class="flex justify-between items-center mb-6">
            <h3 class="text-lg leading-6 font-medium text-gray-900">Contact Messages</h3>
          </div>
          <!-- Filters -->
          <div class="mb-6 flex gap-4 items-center">
            <div class="flex gap-2">
              <button
                phx-click="filter_status"
                phx-value-status="all"
                phx-target={@myself}
                class={"px-4 py-2 rounded-lg transition-colors #{if @filter_status == :all, do: "bg-brand text-white", else: "bg-gray-200 text-gray-700 hover:bg-gray-300"}"}
              >
                All
              </button>
              <button
                phx-click="filter_status"
                phx-value-status="new"
                phx-target={@myself}
                class={"px-4 py-2 rounded-lg transition-colors #{if @filter_status == :new, do: "bg-brand text-white", else: "bg-gray-200 text-gray-700 hover:bg-gray-300"}"}
              >
                New
              </button>
              <button
                phx-click="filter_status"
                phx-value-status="read"
                phx-target={@myself}
                class={"px-4 py-2 rounded-lg transition-colors #{if @filter_status == :read, do: "bg-brand text-white", else: "bg-gray-200 text-gray-700 hover:bg-gray-300"}"}
              >
                Read
              </button>
              <button
                phx-click="filter_status"
                phx-value-status="archived"
                phx-target={@myself}
                class={"px-4 py-2 rounded-lg transition-colors #{if @filter_status == :archived, do: "bg-brand text-white", else: "bg-gray-200 text-gray-700 hover:bg-gray-300"}"}
              >
                Archived
              </button>
            </div>
            <!-- Search -->
            <div class="flex-1">
              <form phx-change="search" phx-submit="search" phx-target={@myself}>
                <input
                  type="text"
                  name="search_term"
                  value={@search_term}
                  placeholder="Search by name..."
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-brand focus:border-brand"
                />
              </form>
            </div>
          </div>
          <!-- Messages Table -->
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Name
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Email
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Message Preview
                  </th>

                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Received
                  </th>
                </tr>
              </thead>

              <tbody
                class="bg-white divide-y divide-gray-200"
                id="messages-list"
                phx-update="stream"
              >
                <tr
                  :for={{dom_id, message} <- @streams.messages}
                  id={dom_id}
                  phx-click="view_message"
                  phx-value-message-id={message.id}
                  phx-target={@myself}
                  class="hover:bg-gray-50 cursor-pointer"
                >
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={"px-2 inline-flex text-xs leading-5 font-semibold rounded-full #{status_badge_class(message.status)}"}>
                      {message.status |> Atom.to_string() |> String.capitalize()}
                    </span>
                  </td>

                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="text-sm font-medium text-gray-900">{message.name}</div>
                  </td>

                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{message.email}</td>

                  <td class="px-6 py-4 text-sm text-gray-500">
                    <div class="max-w-md truncate">{truncate(message.message)}</div>
                  </td>

                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {format_datetime(message.inserted_at)}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <.pagination pagination={@pagination} target={@myself} />
        </div>
      </div>
      <!-- Message Detail Modal -->
      <.modal
        :if={@show_modal && @selected_message}
        id="message-detail-modal"
        show
        on_cancel={JS.push("close_modal", target: @myself)}
      >
        <div class="space-y-4">
          <div class="flex justify-between items-start">
            <h3 class="text-lg font-semibold text-gray-900">Message Details</h3>

            <span class={"px-3 py-1 text-sm font-semibold rounded-full #{status_badge_class(@selected_message.status)}"}>
              {@selected_message.status |> Atom.to_string() |> String.capitalize()}
            </span>
          </div>

          <div class="border-t border-gray-200 pt-4 space-y-3">
            <div>
              <label class="block text-sm font-medium text-gray-700">Name</label>
              <p class="mt-1 text-sm text-gray-900">{@selected_message.name}</p>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700">Email</label>
              <p class="mt-1 text-sm text-gray-900">{@selected_message.email}</p>
            </div>

            <div :if={@selected_message.phone}>
              <label class="block text-sm font-medium text-gray-700">Phone</label>
              <p class="mt-1 text-sm text-gray-900">{@selected_message.phone}</p>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700">Message</label>
              <p class="mt-1 text-sm text-gray-900 whitespace-pre-wrap">
                {@selected_message.message}
              </p>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700">Received</label>
              <p class="mt-1 text-sm text-gray-900">
                {format_datetime(@selected_message.inserted_at)}
              </p>
            </div>
          </div>
          <!-- Admin Notes -->
          <form
            id="admin-notes-form"
            phx-change="change_admin_notes"
            phx-target={@myself}
            class="border-t border-gray-200 pt-4"
          >
            <label for="admin-notes" class="block text-sm font-medium text-gray-700 mb-2">
              Admin Notes (Internal)
            </label>
            <textarea
              id="admin-notes"
              name="admin_notes"
              phx-blur="update_admin_notes"
              phx-target={@myself}
              rows="3"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-brand focus:border-brand"
              placeholder="Add internal notes about this message..."
            >{@admin_notes}</textarea>
          </form>
          <!-- Status Actions -->
          <div class="border-t border-gray-200 pt-4">
            <label class="block text-sm font-medium text-gray-700 mb-2">Update Status</label>
            <div class="flex gap-2">
              <button
                phx-click="update_status"
                phx-value-status="new"
                phx-target={@myself}
                class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
              >
                Mark as New
              </button>
              <button
                phx-click="update_status"
                phx-value-status="read"
                phx-target={@myself}
                class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
              >
                Mark as Read
              </button>
              <button
                phx-click="update_status"
                phx-value-status="archived"
                phx-target={@myself}
                class="px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors"
              >
                Archive
              </button>
            </div>
          </div>
        </div>
      </.modal>
    </div>
    """
  end
end
