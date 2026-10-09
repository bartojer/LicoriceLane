defmodule LicoriceLaneWeb.Components.Pagination do
  @moduledoc """
  Reusable pagination component for admin tables.
  """
  use Phoenix.Component

  @doc """
  Renders a pagination control with page numbers and navigation.

  ## Attributes
    * `:pagination` - Map from AdminHelpers.paginate/3 with page info
    * `:target` - Optional phx-target for the click events

  ## Events
  Sends "page" event with %{"page" => page_number} when a page is clicked.

  ## Example
      <.pagination pagination={@pagination} target={@myself} />
  """
  attr :pagination, :map, required: true
  attr :target, :any, default: nil

  def pagination(assigns) do
    ~H"""
    <nav
      :if={@pagination.total_pages > 1}
      class="flex items-center justify-between border-t border-gray-200 bg-white px-4 py-3 sm:px-6"
      aria-label="Pagination"
    >
      <div class="hidden sm:block">
        <p class="text-sm text-gray-700">
          Showing <span class="font-medium">{start_item(@pagination)}</span>
          to <span class="font-medium">{end_item(@pagination)}</span>
          of <span class="font-medium">{@pagination.total_count}</span>
          results
        </p>
      </div>
      <div class="flex flex-1 justify-between sm:justify-end gap-2">
        <button
          :if={@pagination.has_prev}
          phx-click="page"
          phx-value-page={@pagination.page - 1}
          phx-target={@target}
          class="relative inline-flex items-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
        >
          Previous
        </button>
        <span
          :if={!@pagination.has_prev}
          class="relative inline-flex items-center rounded-md bg-gray-100 px-3 py-2 text-sm font-semibold text-gray-400 ring-1 ring-inset ring-gray-300 cursor-not-allowed"
        >
          Previous
        </span>

        <div class="hidden sm:flex gap-1">
          <%= for page <- visible_pages(@pagination) do %>
            <%= if page == :ellipsis do %>
              <span class="relative inline-flex items-center px-3 py-2 text-sm text-gray-700">
                ...
              </span>
            <% else %>
              <button
                phx-click="page"
                phx-value-page={page}
                phx-target={@target}
                class={[
                  "relative inline-flex items-center px-3 py-2 text-sm font-semibold rounded-md",
                  if(page == @pagination.page,
                    do: "bg-brand text-white",
                    else: "text-gray-900 ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
                  )
                ]}
              >
                {page}
              </button>
            <% end %>
          <% end %>
        </div>

        <button
          :if={@pagination.has_next}
          phx-click="page"
          phx-value-page={@pagination.page + 1}
          phx-target={@target}
          class="relative inline-flex items-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
        >
          Next
        </button>
        <span
          :if={!@pagination.has_next}
          class="relative inline-flex items-center rounded-md bg-gray-100 px-3 py-2 text-sm font-semibold text-gray-400 ring-1 ring-inset ring-gray-300 cursor-not-allowed"
        >
          Next
        </span>
      </div>
    </nav>
    """
  end

  defp start_item(%{page: page, page_size: page_size, total_count: total}) do
    if total == 0, do: 0, else: (page - 1) * page_size + 1
  end

  defp end_item(%{page: page, page_size: page_size, total_count: total}) do
    min(page * page_size, total)
  end

  # Generate visible page numbers with ellipsis for large page counts
  defp visible_pages(%{page: _current, total_pages: total}) when total <= 7 do
    Enum.to_list(1..total)
  end

  defp visible_pages(%{page: current, total_pages: total}) do
    cond do
      current <= 4 ->
        Enum.to_list(1..5) ++ [:ellipsis, total]

      current >= total - 3 ->
        [1, :ellipsis] ++ Enum.to_list((total - 4)..total)

      true ->
        [1, :ellipsis] ++ Enum.to_list((current - 1)..(current + 1)) ++ [:ellipsis, total]
    end
  end
end
