defmodule Bonfire.UI.Common.ExtensionDiffRenderTest do
  use ExUnit.Case, async: true

  @moduletag :ui

  @diff """
  diff --git a/lib/a.ex b/lib/a.ex
  index 1111111..2222222 100644
  --- a/lib/a.ex
  +++ b/lib/a.ex
  @@ -1,3 +1,3 @@
   defmodule A do
  -  def x, do: "old"
  +  def x, do: "new"
   end
  """

  defp render do
    {:ok, [patch]} = GitDiff.parse_patch(@diff)
    patch |> Bonfire.UI.Common.ExtensionDiffLive.render_diff() |> IO.iodata_to_binary()
  end

  test "diff lines are highlighted in the changed file's language, as token spans inside the table cells" do
    html = render()

    assert html =~ ~s(<span class="l-keyword-function">defmodule</span>)
    assert html =~ ~s(<span class="l-string">&quot;new&quot;</span>)
    refute html =~ "<pre"
  end

  test "an extension's deps.hex is highlighted as TOML" do
    {:ok, [patch]} =
      GitDiff.parse_patch("""
      diff --git a/deps.hex b/deps.hex
      index 1111111..2222222 100644
      --- a/deps.hex
      +++ b/deps.hex
      @@ -1 +1 @@
      -mdex = "~> 0.13.2" # handle markdown
      +mdex = "~> 0.14.1" # handle markdown
      """)

    html = patch |> Bonfire.UI.Common.ExtensionDiffLive.render_diff() |> IO.iodata_to_binary()

    assert html =~ ~s(<span class="l-string">&quot;~&gt; 0.14.1&quot;</span>)
    assert html =~ ~s(<span class="l-comment">)
  end

  test "each diff line's number links to the line's own id" do
    ids = Regex.scan(~r/<tr id="([^"]+)" class="ghd-line /, render(), capture: :all_but_first)

    assert length(ids) == 4

    for [id] <- ids do
      assert render() =~ ~s(<a href="##{id}" class="ghd-line-number-link")
    end
  end
end
