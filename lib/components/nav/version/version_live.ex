defmodule Bonfire.UI.Common.VersionLive do
  @moduledoc """
  The version shown in the footer and on the guest board. Bonfire's alone, linked to its source. A distribution whose flavour config sets `config :bonfire, :flavour_overrides, version: true` gets its own name (`Bonfire.Application.flavour_name/0`) and version first, linked to the url its `powered_by` config sets, then "Powered by Bonfire" and Bonfire's version. In that case the footer and guest board leave out their own powered-by part, so nothing shows twice.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "Classes for each part (the links and the distribution's name)"
  prop class, :css_class, default: nil

  @doc "Passed on to the link to Bonfire's source"
  prop parent_id, :string, default: nil
end
