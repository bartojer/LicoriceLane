defmodule LicoriceLaneWeb.AdminHelpers do
  @moduledoc """
  Shared helper functions for admin LiveView components.
  Includes formatting, labels, and pagination utilities.
  """

  @doc """
  Default items per page for paginated lists.
  Change this value to adjust pagination across all admin components.
  """
  def default_page_size, do: 25

  # Category Labels
  def category_label(:candle), do: "Candles"
  def category_label(:electric_light), do: "Electric Lights"
  def category_label(:tableware), do: "Tableware"
  def category_label(:linen), do: "Linens"
  def category_label(:tray), do: "Trays"
  def category_label(cat), do: cat |> to_string() |> String.capitalize()

  # Item Type Labels (short version for tables)
  def item_type_label(:single), do: "Single"
  def item_type_label(:bulk), do: "Bulk"
  def item_type_label(type), do: type |> to_string() |> String.capitalize()

  # Item Type Labels (long version for forms)
  def item_type_label_long(:single), do: "Single Item (Individual Tracking)"
  def item_type_label_long(:bulk), do: "Bulk Item (Quantity Tracking)"
  def item_type_label_long(type), do: item_type_label(type)

  # Event Type Labels
  def event_type_label(nil), do: "—"
  def event_type_label(:wedding), do: "Wedding"
  def event_type_label(:corporate), do: "Corporate Event"
  def event_type_label(:birthday), do: "Birthday Party"
  def event_type_label(type), do: type |> to_string() |> String.capitalize()

  # Price Formatting
  def format_price(nil), do: "N/A"

  def format_price(price) do
    price
    |> Decimal.round(2)
    |> Decimal.to_string()
    |> then(&"$#{&1}")
  end

  # Date/Time Formatting
  def format_date(nil), do: "—"

  def format_date(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y")
  end

  def format_datetime(nil), do: "—"

  def format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y %I:%M %p")
  end

  def format_short_date(nil), do: "—"

  def format_short_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  @doc """
  Calculates pagination metadata from total count and current page.

  Returns a map with:
    - :page - current page (1-indexed)
    - :page_size - items per page
    - :total_count - total number of items
    - :total_pages - total number of pages
    - :has_prev - whether there's a previous page
    - :has_next - whether there's a next page
    - :offset - offset for database query
  """
  def paginate(total_count, page, page_size \\ nil) do
    LicoriceLane.Pagination.bounds(total_count,
      page: page,
      page_size: page_size || default_page_size()
    )
  end

  @doc """
  Truncates text to specified length with ellipsis.
  """
  def truncate(text, length \\ 50)
  def truncate(nil, _length), do: ""

  def truncate(text, length) when is_binary(text) do
    if String.length(text) > length do
      String.slice(text, 0, length) <> "..."
    else
      text
    end
  end
end
