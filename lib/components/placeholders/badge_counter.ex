defmodule Bonfire.UI.Common.BadgeCounter do
  use Bonfire.UI.Common.Web, :stateless_component

  prop badge, :map, default: nil
  prop feed_id, :any, default: nil
  prop page, :string, default: nil
  prop widget, :any, default: %{}
end
