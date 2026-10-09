defmodule LicoriceLane.Pagination do
  @moduledoc """
  Shared pagination bounds for context queries and presentation metadata.
  """

  import Ecto.Query
  alias LicoriceLane.Repo

  @doc """
  Returns a page and the filtered total count from an ordered query.
  Clamps the page before fetching rows, including after the result set shrinks.
  Callers must supply a deterministic ordering, including a unique tie breaker.
  """
  def query(query, opts) do
    total_count = query |> exclude(:preload) |> exclude(:order_by) |> Repo.aggregate(:count)
    %{page_size: page_size, offset: offset} = bounds(total_count, opts)
    records = query |> limit(^page_size) |> offset(^offset) |> Repo.all()
    {records, total_count}
  end

  @doc """
  Calculates positive page bounds from a total count and pagination options.
  Invalid page/page-size values fall back to 1 and 25 respectively.
  """
  def bounds(total_count, opts) do
    page_size = positive_integer(Keyword.get(opts, :page_size), 25)
    total_pages = max(1, div(total_count + page_size - 1, page_size))
    page = min(page_number(Keyword.get(opts, :page)), total_pages)

    %{
      page: page,
      page_size: page_size,
      total_count: total_count,
      total_pages: total_pages,
      has_prev: page > 1,
      has_next: page < total_pages,
      offset: (page - 1) * page_size
    }
  end

  @doc """
  Parses a page from a component event or context option, defaulting to page 1.
  """
  def page_number(value), do: positive_integer(value, 1)

  defp positive_integer(value, _default) when is_integer(value) and value > 0, do: value

  defp positive_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} when number > 0 -> number
      _ -> default
    end
  end

  defp positive_integer(_value, default), do: default
end
