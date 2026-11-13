defmodule Bonfire.UI.Common.ComposerPolicyControlsLive do
  @moduledoc "Where a composer post goes and who can see it, as chips, on the line above the composer toolbar (every composer form renders it through `InputControlsLive`)."
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Common.SmartInputLive

  prop replying, :boolean, default: false
  prop smart_input_opts, :map, default: %{}
  prop showing_within, :atom, default: nil
  prop to_boundaries, :any, default: nil
  prop to_circles, :list, default: []
  prop exclude_circles, :list, default: []
  prop verb_permissions, :map, default: %{}
  prop boundary_preset, :any, default: nil
  prop preview_boundary_for_id, :any, default: nil
  prop preview_boundary_for_username, :any, default: nil
  prop preview_boundary_verbs, :list, default: []
  prop context_id, :any, default: nil
  prop context_group, :any, default: nil
  prop event_target, :any, default: nil
end
