defmodule Bonfire.UI.Common.ComposerLive do
  use Bonfire.UI.Common.Web, :stateless_component
  use Bonfire.Common.Utils

  # needed by apps to use this editor to know how to process text they receive from it
  def output_format, do: :markdown
end
