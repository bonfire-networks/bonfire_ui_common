defmodule Bonfire.UI.Common.FeedFilterControlModule do
  @moduledoc """
  Controls that extensions add to the feed filters editor, one row each, for a filter they own (the query half of that filter is a `Bonfire.Common.FeedFilterModule`, and the field is declared in the extension's config).

  A control is a stateless component, declared with `declare_feed_filter_control/2`:

      declare_feed_filter_control(:nearby, filters: [nearby: nil], after: :happening)

  - the name is the section key, which a host lists in its `sections` to show the control
  - `filters` lists the filter keys the control owns, each with the value that means "off", so the editor's Reset and Apply know them
  - `after` is an optional anchor: the built-in row to show it after (`:happening` is the only one supported), else it comes last

  The control's events carry the owning extension's name as a prefix (eg. `Bonfire.Geolocate:set_location`), so they reach that extension's `LiveHandler`.
  """
  @behaviour Bonfire.Common.ExtensionBehaviour
  use Bonfire.Common.Utils, only: []

  @doc "Declares a feed filter control: a map with `name`, `module`, `app`, `type`, `filters` and optionally `after`"
  @callback declared_feed_filter_control() :: map

  @doc "What a module declared as a control, or nil if it declares none"
  def declared(module) when is_atom(module) do
    if Code.ensure_loaded?(module) and
         function_exported?(module, :declared_feed_filter_control, 0) do
      module.declared_feed_filter_control()
    end
  end

  @doc "The controls declared by the given modules (all of those found by default), in the given order"
  def controls(modules \\ modules()) do
    modules
    |> Enum.map(&declared/1)
    |> Enum.reject(&is_nil/1)
  end

  def app_modules() do
    Bonfire.Common.ExtensionBehaviour.behaviour_app_modules(__MODULE__)
  end

  @spec modules() :: [atom]
  def modules() do
    Bonfire.Common.ExtensionBehaviour.behaviour_modules(__MODULE__)
  end
end
