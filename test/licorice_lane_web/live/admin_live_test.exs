defmodule LicoriceLaneWeb.AdminLiveTest do
  use LicoriceLaneWeb.ConnCase

  alias LicoriceLane.Repo

  import Phoenix.LiveViewTest
  import LicoriceLane.AccountsFixtures

  describe "admin access" do
    test "redirects anonymous visitors to login", %{conn: conn} do
      conn = get(conn, ~p"/admin")
      assert redirected_to(conn) == ~p"/users/log_in"
      assert conn.halted
    end

    test "rejects logged-in users without admin access", %{conn: conn} do
      conn = conn |> log_in_user(user_fixture()) |> get(~p"/admin")
      assert redirected_to(conn) == ~p"/users/log_in"
      assert conn.halted
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must be an admin"
    end

    test "allows an admin to mount the dashboard", %{conn: conn} do
      conn = log_in_user(conn, admin_user_fixture())
      assert {:ok, view, _html} = live(conn, ~p"/admin")
      assert has_element?(view, "h1", "Admin Dashboard")
      assert has_element?(view, "button[phx-value-tab=inventory]", "Inventory")
    end

    test "rejects an existing session after admin access is revoked", %{conn: conn} do
      user = admin_user_fixture()
      conn = log_in_user(conn, user)

      user |> Ecto.Changeset.change(admin: false) |> Repo.update!()

      conn = get(conn, ~p"/admin")
      assert redirected_to(conn) == ~p"/users/log_in"
      assert conn.halted
    end
  end
end
