defmodule Bonfire.UI.Common.OpenExternalLinkLive do
  @moduledoc """
  TODOC
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop prompt_external_links, :boolean, default: false

  slot default
end
