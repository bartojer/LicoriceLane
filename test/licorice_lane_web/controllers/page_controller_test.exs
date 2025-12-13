defmodule LicoriceLaneWeb.PageControllerTest do
  use LicoriceLaneWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Licorice Lane"
  end
end
