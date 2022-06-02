defmodule Bonfire.UI.Common.HeaderUserLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Common.BadgeCounterLive

  prop page, :string
  prop without_sidebar, :boolean, default: false
end
