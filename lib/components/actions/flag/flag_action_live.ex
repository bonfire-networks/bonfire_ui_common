defmodule Bonfire.UI.Common.FlagActionLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object, :any
  prop parent_id, :string, default: nil
  prop label, :string, default: nil
  prop flagged, :any, default: nil
  prop hide_icon, :boolean, default: false
end
