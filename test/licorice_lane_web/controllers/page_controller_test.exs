defmodule LicoriceLaneWeb.PageControllerTest do
  use LicoriceLaneWeb.ConnCase, async: true

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Licorice Lane"
  end
end
