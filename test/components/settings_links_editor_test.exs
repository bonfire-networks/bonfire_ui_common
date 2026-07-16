defmodule Bonfire.UI.Common.SettingsLinksEditorLiveTest do
  @moduledoc """
  Regression tests for `Bonfire.UI.Common.SettingsLinksEditorLive`.

  Reproduces reported bugs when deleting the default/seeded links:
    * deleting multiple rows and then clicking Save once does not remove them
    * deleting down to (or removing) the last remaining row does not persist
    * (control) deleting one row at a time and saving does work
  """
  use Bonfire.UI.Common.ConnCase, async: false

  use Bonfire.Common.Settings

  @url "/settings/instance/about"
  @keys [:ui, :theme, :instance_welcome, :links]
  @form ~s(form[phx-submit="save_links"])

  @seed_links [
    %{name: "Forum", url: "https://forum.example.com"},
    %{name: "Chat", url: "https://chat.example.com"},
    %{name: "Docs", url: "https://docs.example.com"}
  ]

  setup do
    account = fake_account!()
    admin = fake_admin!(account)
    conn = conn(user: admin, account: account)

    Settings.put(@keys, @seed_links, scope: :instance, skip_boundary_check: true)

    {:ok, conn: conn, admin: admin, account: account}
  end

  defp stored_links do
    Settings.get(@keys, [], scope: :instance)
    |> Bonfire.UI.Common.WidgetCommunityLinksLive.normalize_links(as: :map)
  end

  defp names(links), do: Enum.map(links, & &1.name)

  describe "the seed renders" do
    test "all seeded links are shown in the editor", %{conn: conn} do
      {:ok, view, _html} = live(conn, @url)

      html = render(view)
      assert html =~ "Forum"
      assert html =~ "Chat"
      assert html =~ "Docs"
    end
  end

  describe "deleting via the UI then saving (integration)" do
    test "CONTROL: deleting one row and saving removes exactly that row", %{conn: conn} do
      {:ok, view, _html} = live(conn, @url)

      view
      |> element(~s(button[phx-value-index="0"]))
      |> render_click()

      view
      |> form(@form)
      |> render_submit()

      links = stored_links()
      assert names(links) == ["Chat", "Docs"]
    end

    test "deleting MULTIPLE rows then saving once removes all of them", %{conn: conn} do
      {:ok, view, _html} = live(conn, @url)

      # remove first two rows (index shifts to 0 after each removal)
      view |> element(~s(button[phx-value-index="0"])) |> render_click()
      view |> element(~s(button[phx-value-index="0"])) |> render_click()

      view
      |> form(@form)
      |> render_submit()

      links = stored_links()
      assert names(links) == ["Docs"]
    end

    test "removing the LAST remaining row and saving persists an empty list", %{conn: conn} do
      {:ok, view, _html} = live(conn, @url)

      # remove all three rows
      view |> element(~s(button[phx-value-index="0"])) |> render_click()
      view |> element(~s(button[phx-value-index="0"])) |> render_click()
      view |> element(~s(button[phx-value-index="0"])) |> render_click()

      view
      |> form(@form)
      |> render_submit()

      assert stored_links() == []
    end
  end

  describe "add + remove then save" do
    test "adding a row, removing an existing one, then saving keeps only the new row",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, @url)

      # remove all three seeded rows
      view |> element(~s(button[phx-value-index="0"])) |> render_click()
      view |> element(~s(button[phx-value-index="0"])) |> render_click()
      view |> element(~s(button[phx-value-index="0"])) |> render_click()

      # add a fresh empty row and fill it via the submit params
      view |> element(~s(button[phx-click="add_link"])) |> render_click()

      view
      |> form(@form, %{"links" => %{"0" => %{"name" => "New", "url" => "https://new.example.com"}}})
      |> render_submit()

      assert names(stored_links()) == ["New"]
    end
  end
end
