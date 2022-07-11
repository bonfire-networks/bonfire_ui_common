defmodule Bonfire.UI.Common.FeedbackButtonLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop text, :string, default: nil
  prop class, :css_class, default: "w-full mt-2 normal-case btn btn-sm btn-info btn-wide"
end
