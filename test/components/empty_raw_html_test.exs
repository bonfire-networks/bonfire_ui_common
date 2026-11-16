defmodule Bonfire.UI.Common.EmptyRawHtmlTest do
  @moduledoc "The empty-state placeholder shows `trusted_html` as markup (only our own rendered output goes there) and `text` as escaped text, so text that reaches it from users never renders as markup."

  use Bonfire.UI.Common.ConnCase, async: true
  @moduletag :ui

  alias Bonfire.UI.Common.Empty

  defp render_empty(assigns) do
    render_component(
      &Empty.render/1,
      Map.merge(%{comment: nil, __context__: %{}, inner_block: []}, assigns)
    )
  end

  test "control: trusted markup is shown as markup" do
    html = render_empty(%{trusted_html: "<p class=\"note\">nothing here <b>yet</b></p>"})

    assert html =~ "nothing here"
    assert html =~ "<b>yet</b>"
  end

  test "a script or event handler in text is shown as text, not rendered" do
    html =
      render_empty(%{
        text: ~s|nothing here <script>alert(1)</script><img src=x onerror="alert(2)">|
      })

    assert html =~ "nothing here"
    refute html =~ "<script"
    refute html =~ "<img"
    assert html =~ "&lt;script&gt;"
  end
end
