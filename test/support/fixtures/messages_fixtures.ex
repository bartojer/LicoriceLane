defmodule LicoriceLane.MessagesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `LicoriceLane.Messages` context.
  """

  def unique_email, do: "sender#{System.unique_integer()}@example.com"

  def valid_message_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: "Test Sender",
      email: unique_email(),
      message: "This is a test message"
    })
  end

  def message_fixture(attrs \\ %{}) do
    # Extract status if provided
    {status, attrs} = Map.pop(attrs, :status, :new)

    {:ok, message} =
      attrs
      |> valid_message_attributes()
      |> LicoriceLane.Messages.create_message()

    # Update status if different from :new
    message =
      if status != :new do
        {:ok, updated} = LicoriceLane.Messages.update_message_status(message, %{status: status})
        updated
      else
        message
      end

    message
  end
end
