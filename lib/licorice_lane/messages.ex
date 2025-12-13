defmodule LicoriceLane.Messages do
  @moduledoc """
  Context module for managing contact form messages.
  """

  import Ecto.Query
  alias LicoriceLane.Repo
  alias LicoriceLane.Messages.Message

  @doc """
  Returns all messages ordered by most recent first.
  """
  def list_messages do
    Message
    |> order_by([m], desc: m.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns messages filtered by status.
  """
  def list_messages_by_status(status) when status in [:new, :read, :archived] do
    Message
    |> where([m], m.status == ^status)
    |> order_by([m], desc: m.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns the count of messages with 'new' status.
  """
  def count_new_messages do
    Message
    |> where([m], m.status == :new)
    |> Repo.aggregate(:count)
  end

  @doc """
  Gets a single message by id.
  """
  def get_message(id) do
    Repo.get(Message, id)
  end

  @doc """
  Gets a single message by id, raises if not found.
  """
  def get_message!(id) do
    Repo.get!(Message, id)
  end

  @doc """
  Creates a new message from public contact form.
  """
  def create_message(attrs \\ %{}) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        broadcast_message_created(message)
        {:ok, message}

      error ->
        error
    end
  end

  @doc """
  Updates a message's status and admin notes.
  """
  def update_message_status(message, attrs) do
    message
    |> Message.admin_changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, message} ->
        broadcast_message_updated(message)
        {:ok, message}

      error ->
        error
    end
  end

  @doc """
  Marks a message as read.
  """
  def mark_as_read(message) do
    update_message_status(message, %{status: :read})
  end

  @doc """
  Marks a message as archived.
  """
  def mark_as_archived(message) do
    update_message_status(message, %{status: :archived})
  end

  @doc """
  Marks a message as new.
  """
  def mark_as_new(message) do
    update_message_status(message, %{status: :new})
  end

  @doc """
  Deletes a message.
  """
  def delete_message(%Message{} = message) do
    Repo.delete(message)
  end

  @doc """
  Searches messages by name using case-insensitive ILIKE pattern matching.
  """
  def search_messages_by_name(search_term) when is_binary(search_term) do
    search_pattern = "%#{search_term}%"

    Message
    |> where([m], ilike(m.name, ^search_pattern))
    |> order_by([m], desc: m.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking message changes.
  """
  def change_message(%Message{} = message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end

  @doc """
  Subscribes to message updates via PubSub.
  """
  def subscribe do
    Phoenix.PubSub.subscribe(LicoriceLane.PubSub, "messages")
  end

  defp broadcast_message_created(message) do
    Phoenix.PubSub.broadcast(
      LicoriceLane.PubSub,
      "messages",
      {:message_created, message}
    )
  end

  defp broadcast_message_updated(message) do
    Phoenix.PubSub.broadcast(
      LicoriceLane.PubSub,
      "messages",
      {:message_updated, message}
    )
  end
end
