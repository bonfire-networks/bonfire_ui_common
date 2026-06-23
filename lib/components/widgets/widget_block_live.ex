defmodule Bonfire.UI.Common.WidgetBlockLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget_title, :string, default: nil

  prop class, :css_class,
    default: "w-full p-4 flex-auto mx-auto rounded-box border border-base-content/20"

  prop title_class, :css_class,
    default: "pb-2 text-xs font-medium uppercase tracking-wide text-base-content/60"

  prop empty, :boolean, default: false
  prop empty_message, :string, default: nil
  prop empty_icon, :string, default: "ph:sparkle-duotone"

  @doc "LiveHandler event (`\"Module:event\"`) to bust this widget's cache. When set, a refresh button is shown in the title bar."
  prop reset_cache_event, :string, default: nil

  @doc "Params echoed to the reset event as `phx-value-*` — MUST mirror the args the widget's cached loader was called with (so the reset busts the same key)."
  prop reset_cache_values, :map, default: %{}

  @doc "Gate override for the refresh button. `nil` (default) = mod-only (`can?(:mediate, :instance)`); set `true`/`false` to override (e.g. per-user caches can pass `true`)."
  prop can_reset, :boolean, default: nil

  @doc "Optional `phx-target` for the reset button — pass `@myself` from a STATEFUL widget so its own `handle_event` runs and it can re-render with fresh data. Stateless widgets leave this `nil` and use the `\"Module:event\"` form in `reset_cache_event`."
  prop reset_cache_target, :any, default: nil

  @doc "A call to action, usually redirect to the specific page"
  slot action

  @doc "Override the default empty-state placeholder."
  slot empty_state

  @doc "The main content of the widget"
  slot default, required: true

  @doc "Whether to show the refresh button: only when a reset event is set AND the (overridable, mod-by-default) gate passes."
  def show_reset?(nil, _can_reset, _context), do: false
  def show_reset?(_event, can_reset, _context) when is_boolean(can_reset), do: can_reset

  def show_reset?(_event, nil, context),
    do: Bonfire.Boundaries.can?(context, :mediate, :instance)

  @doc "Turns the `reset_cache_values` map into `phx-value-*` attributes."
  def phx_values(values) when is_map(values),
    do: Enum.map(values, fn {k, v} -> {:"phx-value-#{k}", v} end)

  def phx_values(_), do: []
end
