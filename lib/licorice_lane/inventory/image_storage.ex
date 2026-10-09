defmodule LicoriceLane.Inventory.ImageStorage do
  @moduledoc """
  Local storage for inventory images. URLs remain under `/uploads/`; both writes
  and static serving use the same runtime-configurable directory.
  """

  @extensions ~w(.jpg .jpeg .png .gif .webp)

  @doc "Returns the absolute local upload directory."
  def directory do
    Application.get_env(:licorice_lane, :inventory_upload_directory) ||
      Path.join([:code.priv_dir(:licorice_lane), "static", "uploads"])
  end

  @doc "Copies a temporary upload under a UUID filename and returns its public path."
  def store(source, client_name) do
    extension = client_name |> Path.extname() |> String.downcase()

    if extension in @extensions do
      filename = Ecto.UUID.generate() <> extension
      destination = Path.join(directory(), filename)

      with :ok <- File.mkdir_p(directory()),
           :ok <- File.cp(source, destination) do
        {:ok, "/uploads/" <> filename}
      else
        {:error, reason} ->
          File.rm(destination)
          {:error, reason}
      end
    else
      {:error, :invalid_file_type}
    end
  end

  @doc "Removes a newly stored image after a failed database save."
  def discard("/uploads/" <> filename) when filename != "" do
    if Path.basename(filename) == filename do
      File.rm(Path.join(directory(), filename))
    else
      {:error, :invalid_path}
    end
  end
end
