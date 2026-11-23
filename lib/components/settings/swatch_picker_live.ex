defmodule Bonfire.UI.Common.SwatchPickerLive do
  @moduledoc """
  A row of colour swatches (`Bonfire.Common.Swatches`) to choose one from, with a Reset to what the thing has when it has none of its own. It only shows and sends: each swatch sends `event` with the swatch's name as `swatch` (and `object_id` as `id`), Reset sends `reset_event`, both to `target`. What they do is the caller's, eg. `Bonfire.Classify.Web.AppearanceLive`.

  Each swatch is drawn from the class of its name (`topic-violet`, `topic_swatches.css`), so it is in the colour it will be shown in on the current theme.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop swatches, :list, default: nil
  @doc "The swatch the thing has of its own, if any"
  prop selected, :string, default: nil
  prop object_id, :any, default: nil
  prop event, :string, required: true
  prop reset_event, :string, required: true
  @doc "Where the events go, eg. `@myself`"
  prop target, :any, default: nil

  @doc "The swatches offered: the given ones, else all."
  def swatches(nil), do: Bonfire.Common.Swatches.names()
  def swatches(swatches), do: swatches
end
