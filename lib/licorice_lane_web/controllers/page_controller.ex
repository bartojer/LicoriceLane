defmodule LicoriceLaneWeb.PageController do
  use LicoriceLaneWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def contact(conn, _params) do
    render(conn, :contact)
  end

  def faq(conn, _params) do
    render(conn, :faq)
  end

  def about(conn, _params) do
    render(conn, :about)
  end
end
