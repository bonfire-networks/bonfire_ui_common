defmodule Bonfire.UI.Common.InlineReplyFallbackLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop dom_id, :any, default: nil
  prop prompt, :any, default: nil
end
