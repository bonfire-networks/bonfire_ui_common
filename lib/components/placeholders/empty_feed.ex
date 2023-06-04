defmodule Bonfire.UI.Common.EmptyFeed do
  use Bonfire.UI.Common.Web, :stateless_component

  prop feedback_title, :string
  prop feedback_message, :string
  prop feed_name, :any, default: nil

  slot empty_feed
end
