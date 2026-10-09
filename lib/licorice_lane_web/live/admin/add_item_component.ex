defmodule LicoriceLaneWeb.Admin.AddItemComponent do
  use LicoriceLaneWeb, :live_component

  require Logger

  alias LicoriceLane.Inventory
  alias LicoriceLane.Items.Item
  alias LicoriceLaneWeb.InventoryImageUpload
  import LicoriceLaneWeb.AdminHelpers

  @impl true
  def mount(socket) do
    {:ok,
     allow_upload(socket, :new_item_image,
       accept: ~w(.jpg .jpeg .png .gif .webp),
       max_entries: 1,
       max_file_size: 10_000_000
     )}
  end

  @impl true
  def update(assigns, socket) do
    warehouses = Inventory.list_warehouse_locations()
    default_warehouse = List.first(warehouses)

    socket =
      socket
      |> assign(assigns)
      |> assign(:warehouses, warehouses)
      |> assign_new(:changeset, fn -> Item.changeset(%Item{}, %{}) end)
      |> assign_new(:created_item, fn -> nil end)
      |> assign_new(:form_params, fn -> %{} end)
      |> assign_new(:selected_item_type, fn -> "single" end)
      |> assign_new(:selected_category, fn -> "candle" end)
      |> assign_new(:selected_location_id, fn ->
        if(default_warehouse, do: default_warehouse.id)
      end)

    {:ok, socket}
  end

  @impl true
  def handle_event("change_item_type", %{"item-type" => item_type}, socket) do
    {:noreply, assign(socket, :selected_item_type, item_type)}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :new_item_image, ref)}
  end

  def handle_event("validate", %{"item" => item_params}, socket) do
    # Update selected category and location from params to persist in UI
    selected_category = Map.get(item_params, "category", socket.assigns.selected_category)

    selected_location_id =
      case Map.get(item_params, "location_id") do
        nil ->
          socket.assigns.selected_location_id

        "" ->
          socket.assigns.selected_location_id

        id when is_binary(id) ->
          case Integer.parse(id) do
            {parsed_id, ""} -> parsed_id
            _ -> socket.assigns.selected_location_id
          end

        id ->
          id
      end

    # Get the current item data from the changeset if it exists
    current_item =
      if socket.assigns.changeset.data.id do
        socket.assigns.changeset.data
      else
        # Apply changes from the current changeset to preserve form state
        Ecto.Changeset.apply_changes(socket.assigns.changeset)
      end

    changeset =
      current_item
      |> Item.changeset(item_params)
      |> Map.put(:action, :validate)

    socket =
      socket
      |> assign(:changeset, changeset)
      |> assign(:form_params, item_params)
      |> assign(:selected_category, selected_category)
      |> assign(:selected_location_id, selected_location_id)

    {:noreply, socket}
  end

  def handle_event("save", %{"item" => item_params}, socket) do
    socket = socket |> assign(:form_params, item_params) |> clear_flash(:error)

    persist = fn params ->
      params
      |> Map.put_new("image_path", "/images/placeholder.png")
      |> Inventory.create_item_with_location()
    end

    case InventoryImageUpload.save(socket, :new_item_image, item_params, persist) do
      {:ok, item} ->
        new_item_data = %{"category" => socket.assigns.selected_category}

        socket =
          socket
          |> assign(:changeset, Item.changeset(%Item{}, new_item_data))
          |> assign(:created_item, item)
          |> assign(:form_params, %{})
          |> put_flash(:info, "Item created successfully!")

        {:noreply, socket}

      {:error, :item, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}

      {:error, :location_data, changeset} ->
        item_changeset = Item.changeset(%Item{}, item_params)

        item_changeset =
          Enum.reduce(changeset.errors, item_changeset, fn {field, {message, opts}}, acc ->
            Ecto.Changeset.add_error(acc, field, message, opts)
          end)

        {:noreply,
         socket
         |> assign(:changeset, %{item_changeset | action: :insert})
         |> put_flash(:error, "Please check the item location and details.")}

      {:error, kind, message} when kind in [:validation, :constraint_violation, :upload] ->
        {:noreply,
         socket
         |> assign(:changeset, %{Item.changeset(%Item{}, item_params) | action: :insert})
         |> put_flash(:error, message)}

      _other ->
        Logger.error("Unexpected inventory creation failure")
        {:noreply, put_flash(socket, :error, "Failed to create item. Please try again.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <h3 class="text-lg leading-6 font-medium text-gray-900 mb-6">Add New Item</h3>
        <p
          :if={Phoenix.Flash.get(@flash, :error)}
          id="add-item-error"
          role="alert"
          class="mb-4 rounded bg-red-50 p-3 text-sm text-red-700"
        >
          {Phoenix.Flash.get(@flash, :error)}
        </p>
        <!-- Success Message with Item Preview -->
        <div :if={@created_item} class="mb-6 p-4 bg-green-50 border border-green-200 rounded-lg">
          <div class="flex items-start">
            <div class="flex-shrink-0">
              <svg
                class="h-5 w-5 text-green-400"
                viewBox="0 0 20 20"
                fill="currentColor"
                aria-hidden="true"
              >
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
            <div class="ml-3 flex-1">
              <h3 class="text-sm font-medium text-green-800">Item created successfully!</h3>
              <div class="mt-3 p-3 bg-white border border-green-100 rounded">
                <div class="flex items-start space-x-3">
                  <div class="flex-shrink-0 w-16 h-16 bg-gradient-to-br from-purple-100 to-pink-100 rounded flex items-center justify-center">
                    <img
                      src={@created_item.image_path}
                      alt={@created_item.name}
                      class="h-16 w-16 object-cover rounded"
                    />
                  </div>
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-semibold text-gray-900">{@created_item.name}</p>
                    <p class="text-xs text-gray-600 mt-1">{@created_item.description}</p>
                    <div class="flex items-center gap-3 mt-2">
                      <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
                        {item_type_label(@created_item.item_type)}
                      </span>
                      <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-purple-100 text-purple-800">
                        {category_label(@created_item.category)}
                      </span>
                      <span class="text-sm font-medium text-brand">
                        {format_price(@created_item.rental_price)}
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <.form
          for={@changeset}
          id="add-item-form"
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save"
        >
          <!-- Item Type Selection -->
          <div class="mb-6">
            <label class="block text-sm font-medium text-gray-700 mb-2">Item Type *</label>
            <div class="flex gap-4">
              <label class="flex items-center">
                <input
                  type="radio"
                  name="item_type_selector"
                  value="single"
                  checked={@selected_item_type == "single"}
                  phx-click="change_item_type"
                  phx-value-item-type="single"
                  phx-target={@myself}
                  class="h-4 w-4 text-brand focus:ring-brand border-gray-300"
                />
                <span class="ml-2 text-sm text-gray-700">Single Item (individual tracking)</span>
              </label>
              <label class="flex items-center">
                <input
                  type="radio"
                  name="item_type_selector"
                  value="bulk"
                  checked={@selected_item_type == "bulk"}
                  phx-click="change_item_type"
                  phx-value-item-type="bulk"
                  phx-target={@myself}
                  class="h-4 w-4 text-brand focus:ring-brand border-gray-300"
                />
                <span class="ml-2 text-sm text-gray-700">Bulk Item (quantity tracking)</span>
              </label>
            </div>
            <input type="hidden" name="item[item_type]" value={@selected_item_type} />
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
              <div
                class="mt-1 flex justify-center px-6 pt-5 pb-6 border-2 border-gray-300 border-dashed rounded-md hover:border-brand transition-colors"
                phx-drop-target={@uploads.new_item_image.ref}
              >
                <.live_file_input upload={@uploads.new_item_image} class="sr-only" />
                <div class="space-y-1 text-center">
                  <%= if Enum.empty?(@uploads.new_item_image.entries) do %>
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
                        for={@uploads.new_item_image.ref}
                        class="relative cursor-pointer bg-white rounded-md font-medium text-brand hover:text-brand/80 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-brand"
                      >
                        <span>Upload a file</span>
                      </label>
                      <p class="pl-1">or drag and drop</p>
                    </div>
                    <p class="text-xs text-gray-500">PNG, JPG, GIF, WebP up to 10MB</p>
                  <% else %>
                    <%= for entry <- @uploads.new_item_image.entries do %>
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
                      <%= for err <- upload_errors(@uploads.new_item_image, entry) do %>
                        <p class="mt-2 text-sm text-red-600">{error_to_string(err)}</p>
                      <% end %>
                    <% end %>
                  <% end %>
                  <%= for err <- upload_errors(@uploads.new_item_image) do %>
                    <p class="mt-2 text-sm text-red-600">{error_to_string(err)}</p>
                  <% end %>
                </div>
              </div>
            </div>
            <!-- Warehouse Location -->
            <div class="sm:col-span-2">
              <label class="block text-sm font-medium text-gray-700 mb-2">
                Warehouse Location *
              </label>
              <div class="flex flex-wrap gap-4">
                <label :for={warehouse <- @warehouses} class="flex items-center">
                  <input
                    type="radio"
                    name="item[location_id]"
                    value={warehouse.id}
                    checked={@selected_location_id == warehouse.id}
                    class="h-4 w-4 text-brand focus:ring-brand border-gray-300"
                  />
                  <span class="ml-2 text-sm text-gray-700">{warehouse.name}</span>
                </label>
              </div>
              <.error :for={error <- Keyword.get_values(@changeset.errors || [], :location_id)}>
                {error_message(error)}
              </.error>
            </div>
            <!-- Conditional Fields for Single Items -->
            <div :if={@selected_item_type == "single"} class="sm:col-span-2 border-t pt-6">
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
                    value={Map.get(@form_params, "condition", "New")}
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
                      selected={Map.get(@form_params, "status", "available") == "available"}
                    >
                      Available
                    </option>
                    <option value="rented" selected={@form_params["status"] == "rented"}>
                      Rented
                    </option>
                    <option value="damaged" selected={@form_params["status"] == "damaged"}>
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
            <div :if={@selected_item_type == "bulk"} class="sm:col-span-2 border-t pt-6">
              <h4 class="text-sm font-medium text-gray-900 mb-4">Bulk Item Details</h4>
              <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
                <!-- Quantity -->
                <div>
                  <label for="item-quantity" class="block text-sm font-medium text-gray-700">
                    Initial Quantity *
                  </label>
                  <input
                    type="number"
                    name="item[quantity]"
                    id="item-quantity"
                    value={Map.get(@form_params, "quantity", "")}
                    min="1"
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-brand focus:ring-brand sm:text-sm"
                    placeholder="e.g., 100"
                  />
                  <.error :for={error <- Keyword.get_values(@changeset.errors || [], :quantity)}>
                    {error_message(error)}
                  </.error>
                </div>
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
                    value={Map.get(@form_params, "min_stock", "10")}
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
              </div>
            </div>
          </div>
          <!-- Submit Button -->
          <div class="mt-6 flex justify-end">
            <button
              type="submit"
              class="inline-flex justify-center rounded-md border border-transparent bg-brand px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-brand/90 focus:outline-none focus:ring-2 focus:ring-brand focus:ring-offset-2"
            >
              Create Item
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
