defmodule LicoriceLane.WriteCacheTest do
  use LicoriceLane.DataCase

  alias LicoriceLane.{Cache, Customers, Messages}
  import LicoriceLane.CustomersFixtures
  import LicoriceLane.MessagesFixtures

  setup do
    Cache.clear()
    on_exit(fn -> Cache.clear() end)
    :ok
  end

  test "customer create, update and delete invalidate dependent cache entries" do
    warm([:customers, :dashboard_stats])
    assert {:ok, customer} = Customers.create_customer(valid_customer_attributes())
    assert_invalidated([:customers, :dashboard_stats])

    warm([:customers, :dashboard_stats])
    assert {:ok, updated} = Customers.update_customer(customer, %{name: "Updated fixture"})
    assert_invalidated([:customers, :dashboard_stats])

    warm([:customers, :dashboard_stats])
    assert {:ok, _} = Customers.delete_customer(updated)
    assert_invalidated([:customers, :dashboard_stats])
  end

  test "failed customer writes preserve cached values" do
    customer = customer_fixture()
    warm([:customers, :dashboard_stats])
    assert {:error, _} = Customers.create_customer(%{name: nil})
    assert {:error, _} = Customers.update_customer(customer, %{name: nil})
    assert Cache.get(:customers) == :cached
    assert Cache.get(:dashboard_stats) == :cached
  end

  test "message create, status update and delete invalidate dependent cache entries" do
    warm([:messages, :new_messages_count])
    assert {:ok, message} = Messages.create_message(valid_message_attributes())
    assert_invalidated([:messages, :new_messages_count])

    warm([:messages, :new_messages_count])
    assert {:ok, updated} = Messages.mark_as_read(message)
    assert_invalidated([:messages, :new_messages_count])

    warm([:messages, :new_messages_count])
    assert {:ok, _} = Messages.delete_message(updated)
    assert_invalidated([:messages, :new_messages_count])
  end

  test "failed message writes preserve cached values" do
    message = message_fixture()
    warm([:messages, :new_messages_count])
    assert {:error, _} = Messages.create_message(%{name: nil})
    assert {:error, _} = Messages.update_message_status(message, %{status: :invalid})
    assert Cache.get(:messages) == :cached
    assert Cache.get(:new_messages_count) == :cached
  end

  defp warm(keys) do
    Enum.each(keys, &Cache.put(&1, :cached))
    Cache.put(:unrelated, :preserved)
  end

  defp assert_invalidated(keys) do
    Enum.each(keys, &assert(is_nil(Cache.get(&1))))
    assert Cache.get(:unrelated) == :preserved
  end
end
