defmodule Bonfire.UI.Common.VersionLiveTest do
  @moduledoc "The version shown in the footer and on the guest board: Bonfire's alone, or, for a distribution whose flavour config sets `config :bonfire, :flavour_overrides, version: true`, the distribution's name and version followed by Bonfire's."
  use Bonfire.UI.Common.ConnCase, async: false
  use Surface.LiveViewTest

  alias Bonfire.UI.Common.VersionLive

  setup do
    previous = for key <- [:flavour, :app_name], do: {key, Application.fetch_env(:bonfire, key)}

    on_exit(fn ->
      for {key, value} <- previous do
        case value do
          {:ok, value} -> Application.put_env(:bonfire, key, value)
          :error -> Application.delete_env(:bonfire, key)
        end
      end
    end)

    # ember is always a dependency (the base flavour), so it has a version to show
    Application.put_env(:bonfire, :flavour, "ember")
    Application.put_env(:bonfire, :app_name, "Example Archives")
  end

  defp render_version do
    assigns = %{}

    render_surface do
      ~F"""
      <VersionLive />
      """
    end
  end

  test "shows Bonfire's version alone when the flavour does not show its own" do
    html = render_version()

    assert html =~ Bonfire.Application.version()
    refute html =~ "Example Archives"
  end

  describe "when the flavour shows its own version" do
    setup do
      Process.put([:bonfire, :flavour_overrides, :version], true)
      :ok
    end

    test "links the distribution to the url its powered_by config sets, and credits Bonfire once" do
      Process.put([:bonfire, :ui, :theme, :powered_by, :url], "https://example.org/archives")

      doc = render_version() |> Floki.parse_fragment!()

      assert ["https://example.org/archives"] ==
               Floki.attribute(doc, "[data-role=flavour_version] a", "href")

      assert Floki.text(Floki.find(doc, "[data-role=flavour_version]")) =~ "Example Archives"

      assert [powered_by] = Floki.find(doc, "[data-role=powered_by]")

      assert ["https://bonfirenetworks.org/"] ==
               Floki.attribute(powered_by, "a[data-role=software]", "href")

      assert Floki.text(powered_by) =~ Bonfire.Application.version()
    end

    test "shows the distribution as plain text when its config sets no url" do
      doc = render_version() |> Floki.parse_fragment!()

      assert Floki.text(Floki.find(doc, "[data-role=flavour_version]")) =~ "Example Archives"
      assert [] == Floki.find(doc, "[data-role=flavour_version] a")
    end
  end

  test "shows the distribution's name and version, then Bonfire's, when the flavour turns it on" do
    Process.put([:bonfire, :flavour_overrides, :version], true)

    html = render_version()

    assert html =~ "Example Archives"
    assert html =~ Bonfire.Application.flavour_version()
    assert html =~ Bonfire.Application.version()
  end
end
