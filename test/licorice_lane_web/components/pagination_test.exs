defmodule LicoriceLaneWeb.Components.PaginationTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  alias LicoriceLaneWeb.AdminHelpers
  alias LicoriceLaneWeb.Components.Pagination

  test "empty and single-page results do not offer navigation" do
    for count <- [0, 1, 25] do
      html =
        render_component(&Pagination.pagination/1, pagination: AdminHelpers.paginate(count, 1))

      assert LazyHTML.query(LazyHTML.from_document(html), "nav") |> Enum.empty?()
    end
  end

  test "large lists expose bounded, targeted page links and correct result ranges" do
    for {page, numbers, range, previous, next} <- [
          {1, [1, 2, 3, 4, 5, 10], "Showing 1 to 25 of 243 results", [], ["2"]},
          {6, [1, 5, 6, 7, 10], "Showing 126 to 150 of 243 results", ["5"], ["7"]},
          {99, [1, 6, 7, 8, 9, 10], "Showing 226 to 243 of 243 results", ["9"], []}
        ] do
      pagination = AdminHelpers.paginate(243, page)

      document =
        render_component(&Pagination.pagination/1, pagination: pagination, target: 42)
        |> LazyHTML.from_document()

      assert document
             |> LazyHTML.query("p")
             |> LazyHTML.text()
             |> String.replace(~r/\s+/, " ")
             |> String.trim() == range

      links = LazyHTML.query(document, "div.hidden.sm\\:flex button")
      assert LazyHTML.attribute(links, "phx-value-page") == Enum.map(numbers, &to_string/1)
      assert LazyHTML.attribute(links, "phx-target") == List.duplicate("42", length(numbers))

      assert document |> LazyHTML.query("button.bg-brand") |> LazyHTML.attribute("phx-value-page") ==
               [to_string(pagination.page)]

      buttons = LazyHTML.query(document, "button")

      for {label, expected} <- [{"Previous", previous}, {"Next", next}] do
        matching = Enum.filter(buttons, &(LazyHTML.text(&1) |> String.trim() == label))
        assert Enum.flat_map(matching, &LazyHTML.attribute(&1, "phx-value-page")) == expected
      end
    end
  end
end
