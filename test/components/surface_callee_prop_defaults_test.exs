defmodule Bonfire.UI.Common.SurfaceCalleePropDefaultsTest do
  @moduledoc """
  During the Surface→LiveView migration a CONVERTED (plain HEEx) template calls
  a still-Surface `:stateless_component` via `<Mod.render …>`. Surface normally
  injects a component's `prop` defaults at the CALL SITE (in the caller's `~F`),
  so a plain-HEEx caller that omits a defaulted prop skips that injection and
  the callee's template hits `@prop` → `KeyError`.

  The callee shim (a `render/1` wrapper that `put_new`s the component's own
  `__props__` defaults) makes Surface stateless components self-sufficient:
  callable via a plain `.render/1` with defaults applied, regardless of caller.
  """
  use Bonfire.UI.Common.ConnCase, async: true

  import Phoenix.LiveViewTest

  defmodule Callee do
    use Bonfire.UI.Common.Web, :stateless_component

    prop label, :string, default: "DEFAULT_LABEL"
    # a prop with NO default — Surface still keeps it in assigns as nil, so
    # `@extra` never KeyErrors; the shim must reproduce that
    prop extra, :any

    def render(assigns) do
      ~F"<span>label:{@label} extra:{inspect(@extra)}</span>"
    end
  end

  test "a Surface stateless component applies its own prop defaults when rendered via plain .render/1 (default omitted)" do
    html = render_component(&Callee.render/1, %{})
    assert html =~ "label:DEFAULT_LABEL"
  end

  test "a prop with NO default resolves to nil (not KeyError) via plain .render/1" do
    html = render_component(&Callee.render/1, %{})
    assert html =~ "extra:nil"
  end

  test "an explicitly-passed prop still wins over the default" do
    html = render_component(&Callee.render/1, %{label: "PASSED"})
    assert html =~ "label:PASSED"
  end
end
