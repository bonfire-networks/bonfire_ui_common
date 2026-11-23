defmodule Bonfire.UI.Common.FeedFilterRowLiveTest do
  use ExUnit.Case, async: true
  use Surface.LiveViewTest

  # bare `ExUnit.Case` skips the tag the extension case templates apply, so without this it also runs in the federation CI leg
  @moduletag :ui

  alias Bonfire.UI.Common.FeedFilterRowLive

  defp row(attrs) do
    assigns = %{
      attrs:
        Map.merge(
          %{id: "ed", name: "origin", label: "Origin", value: "Anywhere", active: false},
          attrs
        )
    }

    render_surface do
      ~F"""
      <FeedFilterRowLive {...@attrs}>BODY_OK</FeedFilterRowLive>
      """
    end
    |> Floki.parse_fragment!()
  end

  test "renders the details row, summary, label and body" do
    html = row(%{})

    assert [{"details", attrs, _}] = Floki.find(html, "details[data-row=origin]")
    assert {"id", "ed_origin_section"} in attrs
    assert {"class", "group"} in attrs
    assert {"phx-mounted", _} = List.keyfind(attrs, "phx-mounted", 0)

    assert Floki.find(html, "details > summary.feed-filter-summary h4") |> Floki.text() =~
             "Origin"

    assert Floki.text(html) =~ "BODY_OK"
  end

  test "value is muted when inactive and primary when active" do
    inactive = row(%{}) |> Floki.find("[data-role=row_value]")
    assert Floki.text(inactive) =~ "Anywhere"
    assert [class] = Floki.attribute(inactive, "class")
    assert class =~ "text-muted"
    refute class =~ "text-primary"

    active = row(%{active: true, value: "Local"}) |> Floki.find("[data-role=row_value]")
    assert [class] = Floki.attribute(active, "class")
    assert class =~ "text-primary"
    refute class =~ "text-muted"
  end

  test "optional value class, label id and summary click" do
    html =
      row(%{value_class: "max-w-45", label_id: "ed_origin_label", click: "locate", target: "#x"})

    assert [class] = html |> Floki.find("[data-role=row_value]") |> Floki.attribute("class")
    assert class =~ "max-w-45"
    assert [_] = Floki.find(html, "h4#ed_origin_label")
    assert [_] = Floki.find(html, "summary[phx-click=locate][phx-target='#x']")

    plain = row(%{})
    assert [] = Floki.find(plain, "summary[phx-click]")
  end
end
