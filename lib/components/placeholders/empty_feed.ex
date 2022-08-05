defmodule Bonfire.UI.Common.EmptyFeed do
  use Bonfire.UI.Common.Web, :stateless_component

  prop feedback_title, :string
  prop feedback_message, :string

end
