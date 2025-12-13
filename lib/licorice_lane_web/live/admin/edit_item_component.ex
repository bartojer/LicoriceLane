defmodule LicoriceLaneWeb.Admin.EditItemComponent do
  use LicoriceLaneWeb, :live_component

  alias LicoriceLane.Inventory

  @impl true
  def update(assigns, socket) do
    item = Inventory.get_item!(assigns.item_id)
    changeset = Inventory.change_item(item)

    socket =
      socket
      |> assign(assigns)
      |> assign(:item, item)
      |> assign(:changeset, changeset)
      |> assign(:selected_category, item.category |> to_string())

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
      |> assign(:selected_category, selected_category)

    {:noreply, socket}
  end

  def handle_event("save", %{"item" => item_params}, socket) do
    item = socket.assigns.item

    result =
      case item.item_type do
        :single -> update_single_item(item, item_params)
        :bulk -> Inventory.update_item(item, item_params)
      end

    case result do
      {:ok, _item} ->
        send(self(), {:switch_tab, "inventory"})
        {:noreply, put_flash(socket, :info, "Item updated successfully!")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("cancel", _params, socket) do
    send(self(), {:switch_tab, "inventory"})
    {:noreply, socket}
  end

  # Helper function to update single items with their SingleItem association
  defp update_single_item(item, item_params) do
    # Extract single_item specific fields
    single_item_attrs = %{
      "condition" => Map.get(item_params, "condition"),
      "status" => Map.get(item_params, "status")
    }

    # Remove single_item fields from item_params
    item_attrs =
      item_params
      |> Map.delete("condition")
      |> Map.delete("status")

    # Update item
    with {:ok, updated_item} <- Inventory.update_item(item, item_attrs),
         {:ok, _single_item} <-
           update_single_item_record(updated_item.single_item, single_item_attrs) do
      {:ok, updated_item}
    else
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp update_single_item_record(nil, _attrs), do: {:ok, nil}

  defp update_single_item_record(single_item, attrs) do
    single_item
    |> LicoriceLane.Items.SingleItem.changeset(attrs)
    |> LicoriceLane.Repo.update()
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
                {item_type_label(@item.item_type)}
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
                value={Phoenix.HTML.Form.normalize_value("text", @changeset.data.name || "")}
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
              >{Phoenix.HTML.Form.normalize_value("textarea", @changeset.data.description || "")}</textarea>
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
                    Phoenix.HTML.Form.normalize_value("number", @changeset.data.rental_price || "")
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
                value={Phoenix.HTML.Form.normalize_value("text", @changeset.data.color || "")}
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-brand focus:ring-brand sm:text-sm"
                placeholder="e.g., Gold, White, Silver"
              />
              <.error :for={error <- Keyword.get_values(@changeset.errors || [], :color)}>
                {error_message(error)}
              </.error>
            </div>
            
    <!-- Image Path -->
            <div class="sm:col-span-2">
              <label for="item-image-path" class="block text-sm font-medium text-gray-700">
                Image Path
              </label>
              <input
                type="text"
                name="item[image_path]"
                id="item-image-path"
                value={Phoenix.HTML.Form.normalize_value("text", @changeset.data.image_path || "")}
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-brand focus:ring-brand sm:text-sm"
                placeholder="images/placeholder.png"
              />
              <p class="mt-1 text-xs text-gray-500">
                Path to the item's image (drag and drop feature coming soon)
              </p>
              <.error :for={error <- Keyword.get_values(@changeset.errors || [], :image_path)}>
                {error_message(error)}
              </.error>
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
                        (@item.single_item && @item.single_item.condition) || ""
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
                      selected={@item.single_item && @item.single_item.status == :available}
                    >
                      Available
                    </option>
                    <option
                      value="rented"
                      selected={@item.single_item && @item.single_item.status == :rented}
                    >
                      Rented
                    </option>
                    <option
                      value="damaged"
                      selected={@item.single_item && @item.single_item.status == :damaged}
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
                      Phoenix.HTML.Form.normalize_value("number", @changeset.data.min_stock || 0)
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

  defp item_type_label(:single), do: "Single Item (Individual Tracking)"
  defp item_type_label(:bulk), do: "Bulk Item (Quantity Tracking)"
  defp item_type_label(type), do: type |> to_string() |> String.capitalize()

  defp error_message({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
