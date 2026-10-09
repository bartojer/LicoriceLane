defmodule LicoriceLaneWeb.InventoryImageUpload do
  @moduledoc """
  Coordinates a local image upload with an inventory save. Failed saves postpone
  consumption, keeping the temporary upload available for correction or cancellation.
  """

  import Phoenix.LiveView
  alias LicoriceLane.Inventory.ImageStorage
  require Logger

  @doc "Saves inventory parameters with an optional image, consuming only after success."
  def save(socket, name, params, persist) do
    config = socket.assigns.uploads[name]
    params = Map.delete(params, "image_path")

    cond do
      config.errors != [] ->
        {:error, :upload, "Please choose one supported image up to 10MB."}

      true ->
        case uploaded_entries(socket, name) do
          {[], []} ->
            persist.(params)

          {_, [_ | _]} ->
            {:error, :upload, "Please wait for the image upload to finish."}

          {[_], []} ->
            [result] =
              consume_uploaded_entries(socket, name, fn %{path: path}, entry ->
                save_entry(path, entry.client_name, params, persist)
              end)

            result
        end
    end
  end

  defp save_entry(path, filename, params, persist) do
    case ImageStorage.store(path, filename) do
      {:ok, image_path} ->
        try do
          case persist.(Map.put(params, "image_path", image_path)) do
            {:ok, _item} = result ->
              {:ok, result}

            error ->
              discard(image_path)
              {:postpone, error}
          end
        rescue
          exception ->
            discard(image_path)
            reraise exception, __STACKTRACE__
        end

      {:error, reason} ->
        Logger.error("Inventory image storage failed: #{inspect(reason)}")
        {:postpone, {:error, :upload, "Could not save the image. Please try again."}}
    end
  end

  defp discard(image_path) do
    case ImageStorage.discard(image_path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> Logger.error("Inventory image cleanup failed: #{inspect(reason)}")
    end
  end
end
