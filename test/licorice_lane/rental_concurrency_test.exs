defmodule LicoriceLane.RentalConcurrencyTest do
  use ExUnit.Case, async: false
  import Ecto.Query
  import LicoriceLane.{CustomersFixtures, ItemsFixtures, LocationsFixtures}
  alias Ecto.Adapters.SQL.Sandbox
  alias LicoriceLane.{Repo, Rentals, Cache}
  alias LicoriceLane.Rentals.{Rental, RentalSingleItem, RentalBulkItem}
  alias LicoriceLane.Items.{Item, SingleItem}
  alias LicoriceLane.Locations.{Location, ItemsLocation, LocationHistory}
  alias LicoriceLane.Customers.Customer

  test "separate database connections serialize capacity, checkout and partial-return races" do
    Sandbox.unboxed_run(Repo, fn ->
      customer = customer_fixture()
      source = warehouse_fixture()
      item = bulk_item_fixture(%{location: source, quantity: 5})

      try do
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        attrs = %{
          customer_id: customer.id,
          destination_name: "Concurrent test venue",
          rented_at: DateTime.add(now, -60),
          return_by: DateTime.add(now, 3600),
          allocations: [%{item_id: item.id, source_location_id: source.id, quantity: 5}]
        }

        results = race(Item, item.id, fn -> Rentals.create_rental(attrs) end)
        assert Enum.count(results, &match?({:ok, _}, &1)) == 1
        assert Enum.count(results, &match?({:error, _}, &1)) == 1
        {:ok, rental} = Enum.find(results, &match?({:ok, _}, &1))
        checkouts = race(Rental, rental.id, fn -> Rentals.checkout_rental(rental) end)
        assert Enum.count(checkouts, &match?({:ok, _}, &1)) == 1
        assert Enum.count(checkouts, &match?({:error, _}, &1)) == 1
        {:ok, out} = Enum.find(checkouts, &match?({:ok, _}, &1))
        allocation = hd(out.allocations)

        returns =
          race(Rental, rental.id, fn ->
            Rentals.return_rental(out, %{returns: [%{allocation_id: allocation.id, quantity: 2}]})
          end)

        assert Enum.count(returns, &match?({:ok, _}, &1)) == 1
        assert Enum.count(returns, &match?({:error, _}, &1)) == 1
        assert hd(Rentals.get_rental(rental.id).allocations).returned_quantity == 2

        assert Repo.one!(
                 from s in ItemsLocation,
                   where: s.item_id == ^item.id and s.location_id == ^source.id,
                   select: s.quantity
               ) == 2

        assert Repo.aggregate(from(h in LocationHistory, where: h.item_id == ^item.id), :count) ==
                 2
      after
        # These committed fixtures are isolated by exact IDs, never by table reset.
        ids = Repo.all(from r in Rental, where: r.customer_id == ^customer.id, select: r.id)
        Repo.delete_all(from h in LocationHistory, where: h.rental_id in ^ids)
        Repo.delete_all(from b in RentalBulkItem, where: b.rental_id in ^ids)
        Repo.delete_all(from s in RentalSingleItem, where: s.rental_id in ^ids)
        Repo.delete_all(from r in Rental, where: r.id in ^ids)
        Repo.delete_all(from s in SingleItem, where: s.id == ^item.id)
        Repo.delete_all(from s in ItemsLocation, where: s.item_id == ^item.id)
        Repo.delete_all(from i in Item, where: i.id == ^item.id)

        Repo.delete_all(
          from l in Location, where: l.id == ^source.id or l.customer_id == ^customer.id
        )

        Repo.delete_all(from c in Customer, where: c.id == ^customer.id)
        Cache.clear()
      end
    end)
  end

  defp race(schema, id, operation) do
    parent = self()

    tasks =
      for _ <- 1..2,
          do:
            Task.async(fn ->
              Sandbox.unboxed_run(Repo, fn ->
                [[backend]] = Repo.query!("SELECT pg_backend_pid()").rows
                send(parent, {:ready, self(), backend})

                receive do
                  :go -> operation.()
                after
                  5_000 -> raise "race barrier timed out"
                end
              end)
            end)

    try do
      assert {:ok, :contended} =
               Repo.transaction(fn ->
                 Repo.one!(from row in schema, where: row.id == ^id, lock: "FOR UPDATE")

                 backends =
                   for task <- tasks do
                     pid = task.pid
                     assert_receive {:ready, ^pid, backend}, 5_000
                     backend
                   end

                 assert length(Enum.uniq(backends)) == 2
                 Enum.each(tasks, &send(&1.pid, :go))
                 # Starting together alone can still execute sequentially. Prove both
                 # connections are waiting on the held row before allowing either write.
                 assert wait_for_contention(backends, System.monotonic_time(:millisecond) + 5_000)
                 :contended
               end)

      Enum.map(tasks, &Task.await(&1, 10_000))
    after
      Enum.each(tasks, fn task ->
        if Process.alive?(task.pid), do: Task.shutdown(task, :brutal_kill)
      end)
    end
  end

  defp wait_for_contention(backends, deadline) do
    [[waiting]] =
      Repo.query!(
        "SELECT COUNT(DISTINCT pid) FROM pg_locks WHERE pid = ANY($1::int[]) AND NOT granted",
        [backends]
      ).rows

    cond do
      waiting == length(backends) ->
        true

      System.monotonic_time(:millisecond) >= deadline ->
        false

      true ->
        Process.sleep(10)
        wait_for_contention(backends, deadline)
    end
  end
end
