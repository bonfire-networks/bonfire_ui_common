defmodule Bonfire.UI.Common.LayoutView do
  use Bonfire.UI.Common.Web, {:layout_view, [namespace: Bonfire.UI.Common]}

  @message_types [:message, "message", :messages, "messages"]

  def is_messaging?(assigns) do
    e(assigns, :create_activity_type, nil) in @message_types or e(assigns, :page, nil) in @message_types or e(assigns, :showing_within, nil) in @message_types
  end

end
