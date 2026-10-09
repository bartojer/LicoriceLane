defmodule LicoriceLaneWeb.Admin.EditItemComponent do
  use LicoriceLaneWeb, :live_component

  alias LicoriceLane.Inventory
  alias LicoriceLaneWeb.InventoryImageUpload
  import LicoriceLaneWeb.AdminHelpers

  @impl true
  def mount(socket) do
    {:ok,
     allow_upload(socket, :edit_item_image,
       accept: ~w(.jpg .jpeg .png .gif .webp),
       max_entries: 1,
       max_file_size: 10_000_000
     )}
  end

  @impl true
  def update(assigns, socket) do
    item_id = Map.get(assigns, :item_id, socket.assigns[:item_id])

    socket =
      if socket.assigns[:item] && socket.assigns.item.id == item_id do
        assign(socket, assigns)
      else
        socket =
          Enum.reduce(socket.assigns.uploads.edit_item_image.entries, socket, fn entry, acc ->
            cancel_upload(acc, :edit_item_image, entry.ref)
          end)

        item = Inventory.get_item!(item_id)

        socket
        |> assign(assigns)
        |> assign(:item, item)
        |> assign(:changeset, Inventory.change_item(item))
        |> assign(:form_params, %{})
        |> assign(:selected_category, to_string(item.category))
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"item" => item_params}, socket) do
    # Update selected category from params to persist in UI
    selected_category = Map.get(item_params, "category", socket.assigns.selected_category)

    # Apply changes from the current changeset to preserve form state
    # This prevents fields from clearing when user clicks into a new field
    current_item = Ecto.Changeset.apply_changes(socket.assigns.changeset)

    changeset =
      current_item
      |> Inventory.change_item(item_params)
      |> Map.put(:action, :validate)

    socket =
      socket
      |> assign(:changeset, changeset)
      |> assign(:form_params, item_params)
      |> assign(:selected_category, selected_category)

    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :edit_item_image, ref)}
  end

  def handle_event("save", %{"item" => item_params}, socket) do
    socket = socket |> assign(:form_params, item_params) |> clear_flash(:error)
    item = socket.assigns.item
    persist = &Inventory.update_item_with_details(item, &1)

    case InventoryImageUpload.save(socket, :edit_item_image, item_params, persist) do
      {:ok, _item} ->
        send(self(), {:switch_tab, "inventory"})
        {:noreply, put_flash(socket, :info, "Item updated successfully!")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}

      {:error, :upload, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_event("cancel", _params, socket) do
    send(self(), {:switch_tab, "inventory"})
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <div class="flex justify-between items-center mb-6">
          <h3 class="text-lg leading-6 font-medium text-gray-900">Edit Item</h3>
          <button
            type="button"
            phx-click="cancel"
            phx-target={@myself}
            class="text-gray-400 hover:text-gray-500"
          >
            <span class="sr-only">Close</span>
            <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          </button>
        </div>

        <p
          :if={Phoenix.Flash.get(@flash, :error)}
          id="edit-item-error"
          role="alert"
          class="mb-4 rounded bg-red-50 p-3 text-sm text-red-700"
        >
          {Phoenix.Flash.get(@flash, :error)}
        </p>

        <.form
          for={@changeset}
          id="edit-item-form"
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save"
        >
          <!-- Item Type Display (Read-only) -->
          <div class="mb-6 p-4 bg-gray-50 rounded-md">
            <label class="block text-sm font-medium text-gray-700 mb-2">Item Type</label>
            <div class="flex items-center">
              <span class="inline-flex items-center px-3 py-1 rounded-md text-sm font-medium bg-blue-100 text-blue-800">
                {item_type_label_long(@item.item_type)}
              </span>
              <span class="ml-3 text-sm text-gray-500">
                (Item type cannot be changed after creation)
              </span>
            </div>
          </div>

          <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
            <!-- Name -->
            <div>
              <label for="item-name" class="block text-sm font-medium text-gray-700">
                Name *
              </label>
              <input
                type="text"
                name="item[name]"
                id="item-name"
                value={
                  Phoenix.HTML.Form.normalize_value(
                    "text",
                    Ecto.Changeset.get_field(@changeset, :name) || ""
                  )
                }
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-brand focus:ring-brand sm:text-sm"
                placeholder="e.g., Gold Chiavari Chair"
              />
              <.error :for={error <- Keyword.get_values(@changeset.errors || [], :name)}>
                {error_message(error)}
              </.error>
            </div>
            <!-- Category -->
            <div>
              <label for="item-category" class="block text-sm font-medium text-gray-700">
                Category *
              </label>
              <select
                name="item[category]"
                id="item-category"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-brand focus:ring-brand sm:text-sm"
              >
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
              <.error :for={error <- Keyword.get_values(@changeset.errors || [], :category)}>
                {error_message(error)}
              </.error>
            </div>
            <!-- Description (full width) -->
            <div class="sm:col-span-2">
              <label for="item-description" class="block text-sm font-medium text-gray-700">
                Description *
              </label>
              <textarea
                name="item[description]"
                id="item-description"
                rows="3"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-brand focus:ring-brand sm:text-sm"
                placeholder="Detailed description of the item..."
              >{Phoenix.HTML.Form.normalize_value("textarea", Ecto.Changeset.get_field(@changeset, :description) || "")}</textarea>
              <.error :for={error <- Keyword.get_values(@changeset.errors || [], :description)}>
                {error_message(error)}
              </.error>
            </div>
            <!-- Rental Price -->
            <div>
              <label for="item-rental-price" class="block text-sm font-medium text-gray-700">
                Rental Price
              </label>
              <div class="mt-1 relative rounded-md shadow-sm">
                <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                  <span class="text-gray-500 sm:text-sm">$</span>
                </div>
                <input
                  type="number"
                  name="item[rental_price]"
                  id="item-rental-price"
                  step="0.01"
                  value={
                    Phoenix.HTML.Form.normalize_value(
                      "number",
                      Ecto.Changeset.get_field(@changeset, :rental_price) || ""
                    )
                  }
                  class="pl-7 block w-full rounded-md border-gray-300 shadow-sm focus:border-brand focus:ring-brand sm:text-sm"
                  placeholder="0.00"
                />
              </div>
              <.error :for={error <- Keyword.get_values(@changeset.errors || [], :rental_price)}>
                {error_message(error)}
              </.error>
            </div>
            <!-- Color -->
            <div>
              <label for="item-color" class="block text-sm font-medium text-gray-700">Color</label>
              <input
                type="text"
                name="item[color]"
                id="item-color"
                value={
                  Phoenix.HTML.Form.normalize_value(
                    "text",
                    Ecto.Changeset.get_field(@changeset, :color) || ""
                  )
                }
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-brand focus:ring-brand sm:text-sm"
                placeholder="e.g., Gold, White, Silver"
              />
              <.error :for={error <- Keyword.get_values(@changeset.errors || [], :color)}>
                {error_message(error)}
              </.error>
            </div>
            <!-- Item Image Upload -->
            <div class="sm:col-span-2">
              <label class="block text-sm font-medium text-gray-700 mb-2">Item Image</label>
              <!-- Current Image Preview -->
              <%= if @item.image_path && Enum.empty?(@uploads.edit_item_image.entries) do %>
                <div class="mb-4 flex items-center gap-4">
                  <div class="relative">
                    <img
                      src={@item.image_path}
                      alt={@item.name}
                      class="h-24 w-24 object-cover rounded-md border border-gray-200"
                    />
                    <span class="absolute -top-2 -right-2 bg-gray-100 text-gray-600 text-xs px-2 py-0.5 rounded-full">
                      Current
                    </span>
                  </div>
                  <div class="text-sm text-gray-500">
                    <p>Current image: {@item.image_path}</p>
                    <p class="text-xs">Upload a new image below to replace it</p>
                  </div>
                </div>
              <% end %>

              <div
                class="flex justify-center px-6 pt-5 pb-6 border-2 border-gray-300 border-dashed rounded-md hover:border-brand transition-colors"
                phx-drop-target={@uploads.edit_item_image.ref}
              >
                <.live_file_input upload={@uploads.edit_item_image} class="sr-only" />
                <div class="space-y-1 text-center">
                  <%= if Enum.empty?(@uploads.edit_item_image.entries) do %>
                    <svg
                      class="mx-auto h-12 w-12 text-gray-400"
                      stroke="currentColor"
                      fill="none"
                      viewBox="0 0 48 48"
                      aria-hidden="true"
                    >
                      <path
                        d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02"
                        stroke-width="2"
                        stroke-linecap="round"
                        stroke-linejoin="round"
                      />
                    </svg>
                    <div class="flex text-sm text-gray-600">
                      <label
                        for={@uploads.edit_item_image.ref}
                        class="relative cursor-pointer bg-white rounded-md font-medium text-brand hover:text-brand/80 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-brand"
                      >
                        <span>Upload a new image</span>
                      </label>
                      <p class="pl-1">or drag and drop</p>
                    </div>
                    <p class="text-xs text-gray-500">PNG, JPG, GIF, WebP up to 10MB</p>
                  <% else %>
                    <%= for entry <- @uploads.edit_item_image.entries do %>
                      <div class="flex items-center gap-4">
                        <.live_img_preview entry={entry} class="h-24 w-24 object-cover rounded-md" />
                        <div class="flex-1 text-left">
                          <p class="text-sm font-medium text-gray-900">{entry.client_name}</p>
                          <p class="text-xs text-gray-500">
                            {Float.round(entry.client_size / 1_000_000, 2)} MB
                          </p>
                          <div class="mt-1 w-full bg-gray-200 rounded-full h-2">
                            <div
                              class="bg-brand h-2 rounded-full transition-all"
                              style={"width: #{entry.progress}%"}
                            >
                            </div>
                          </div>
                        </div>
                        <button
                          type="button"
                          phx-click="cancel-upload"
                          phx-value-ref={entry.ref}
                          phx-target={@myself}
                          class="text-red-500 hover:text-red-700"
                        >
                          <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M6 18L18 6M6 6l12 12"
                            />
                          </svg>
                        </button>
                      </div>
                      <%= for err <- upload_errors(@uploads.edit_item_image, entry) do %>
                        <p class="mt-2 text-sm text-red-600">{error_to_string(err)}</p>
                      <% end %>
                    <% end %>
                  <% end %>
                  <%= for err <- upload_errors(@uploads.edit_item_image) do %>
                    <p class="mt-2 text-sm text-red-600">{error_to_string(err)}</p>
                  <% end %>
                </div>
              </div>
            </div>
            <!-- Conditional Fields for Single Items -->
            <div :if={@item.item_type == :single} class="sm:col-span-2 border-t pt-6">
              <h4 class="text-sm font-medium text-gray-900 mb-4">Single Item Details</h4>
              <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
                <!-- Condition -->
                <div>
                  <label for="item-condition" class="block text-sm font-medium text-gray-700">
                    Condition
                  </label>
                  <input
                    type="text"
                    name="item[condition]"
                    id="item-condition"
                    value={
                      Phoenix.HTML.Form.normalize_value(
                        "text",
                        Map.get(
                          @form_params,
                          "condition",
                          (@item.single_item && @item.single_item.condition) || ""
                        )
                      )
                    }
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-brand focus:ring-brand sm:text-sm"
                    placeholder="e.g., New, Excellent, Good"
                  />
                  <.error :for={error <- Keyword.get_values(@changeset.errors || [], :condition)}>
                    {error_message(error)}
                  </.error>
                </div>
                <!-- Status -->
                <div>
                  <label for="item-status" class="block text-sm font-medium text-gray-700">
                    Status
                  </label>
                  <select
                    name="item[status]"
                    id="item-status"
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-brand focus:ring-brand sm:text-sm"
                  >
                    <option
                      value="available"
                      selected={
                        Map.get(
                          @form_params,
                          "status",
                          to_string(@item.single_item && @item.single_item.status)
                        ) == "available"
                      }
                    >
                      Available
                    </option>
                    <option
                      value="rented"
                      selected={
                        Map.get(
                          @form_params,
                          "status",
                          to_string(@item.single_item && @item.single_item.status)
                        ) == "rented"
                      }
                    >
                      Rented
                    </option>
                    <option
                      value="damaged"
                      selected={
                        Map.get(
                          @form_params,
                          "status",
                          to_string(@item.single_item && @item.single_item.status)
                        ) == "damaged"
                      }
                    >
                      Damaged
                    </option>
                  </select>
                  <.error :for={error <- Keyword.get_values(@changeset.errors || [], :status)}>
                    {error_message(error)}
                  </.error>
                </div>
              </div>
            </div>
            <!-- Conditional Fields for Bulk Items -->
            <div :if={@item.item_type == :bulk} class="sm:col-span-2 border-t pt-6">
              <h4 class="text-sm font-medium text-gray-900 mb-4">Bulk Item Details</h4>
              <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
                <!-- Min Stock -->
                <div>
                  <label for="item-min-stock" class="block text-sm font-medium text-gray-700">
                    Minimum Stock Threshold
                  </label>
                  <input
                    type="number"
                    name="item[min_stock]"
                    id="item-min-stock"
                    min="0"
                    value={
                      Phoenix.HTML.Form.normalize_value(
                        "number",
                        Ecto.Changeset.get_field(@changeset, :min_stock) || 0
                      )
                    }
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-brand focus:ring-brand sm:text-sm"
                    placeholder="10"
                  />
                  <p class="mt-1 text-xs text-gray-500">
                    Alert when stock falls below this number
                  </p>
                  <.error :for={error <- Keyword.get_values(@changeset.errors || [], :min_stock)}>
                    {error_message(error)}
                  </.error>
                </div>
                <!-- Current Quantity Display (Read-only) -->
                <div>
                  <label class="block text-sm font-medium text-gray-700">Current Quantities</label>
                  <div class="mt-1 p-3 bg-gray-50 rounded-md">
                    <div :for={il <- @item.items_locations} class="text-sm text-gray-700">
                      <span class="font-medium">{il.location.name}:</span>
                      <span class="ml-2">{il.quantity} units</span>
                    </div>
                    <p class="mt-2 text-xs text-gray-500">
                      (Quantities managed separately)
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <!-- Action Buttons -->
          <div class="mt-6 flex justify-end gap-3">
            <button
              type="button"
              phx-click="cancel"
              phx-target={@myself}
              class="inline-flex justify-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-brand focus:ring-offset-2"
            >
              Cancel
            </button>
            <button
              type="submit"
              class="inline-flex justify-center rounded-md border border-transparent bg-brand px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-brand/90 focus:outline-none focus:ring-2 focus:ring-brand focus:ring-offset-2"
            >
              Update Item
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  # Helper functions

  defp error_message({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  defp error_to_string(:too_large), do: "File is too large (max 10MB)"

  defp error_to_string(:not_accepted),
    do: "Invalid file type. Please upload an image (PNG, JPG, GIF, WebP)"

  defp error_to_string(:too_many_files), do: "Only one file allowed"
  defp error_to_string(err), do: "Upload error: #{inspect(err)}"
end
