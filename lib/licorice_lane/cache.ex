defmodule LicoriceLane.Cache do
  @moduledoc """
  Centralized cache operations for admin data.

  Uses Cachex with 5-minute TTL for caching expensive queries.
  Cache is invalidated automatically when data is modified.
  """

  @cache :admin_cache

  @doc """
  Invalidates all inventory-related cache entries.
  Call this after any inventory create/update/delete.
  """
  def invalidate_inventory do
    Cachex.del(@cache, :inventory_items)
    Cachex.del(@cache, :low_stock_items)
    Cachex.del(@cache, :dashboard_stats)
  end

  @doc """
  Invalidates all customer-related cache entries.
  """
  def invalidate_customers do
    Cachex.del(@cache, :customers)
    Cachex.del(@cache, :dashboard_stats)
  end

  @doc """
  Invalidates all rental/booking-related cache entries.
  """
  def invalidate_rentals do
    Cachex.del(@cache, :rentals)
    Cachex.del(@cache, :dashboard_stats)
  end

  @doc """
  Invalidates all message-related cache entries.
  """
  def invalidate_messages do
    Cachex.del(@cache, :messages)
    Cachex.del(@cache, :new_messages_count)
  end

  @doc """
  Fetches a value from cache, computing it if not present.
  The function will be called only if the key is not in cache.

  ## Examples
      Cache.fetch(:dashboard_stats, fn -> compute_expensive_stats() end)
  """
  def fetch(key, compute_fn) do
    case Cachex.fetch(@cache, key, fn _key -> {:commit, compute_fn.()} end) do
      {:ok, value} -> value
      {:commit, value} -> value
      {:error, _} -> compute_fn.()
    end
  end

  @doc """
  Gets a value from cache without computing if absent.
  Returns nil if not found.
  """
  def get(key) do
    case Cachex.get(@cache, key) do
      {:ok, value} -> value
      _ -> nil
    end
  end

  @doc """
  Puts a value in cache with optional TTL override.
  """
  def put(key, value, opts \\ []) do
    Cachex.put(@cache, key, value, opts)
    value
  end

  @doc """
  Clears the entire cache.
  Useful for testing or manual cache refresh.
  """
  def clear do
    Cachex.clear(@cache)
  end
end
