defmodule Bonfire.UI.Common.EmptyFeed do
  use Bonfire.UI.Common.Web, :stateless_component
  
  prop feedback_message, :string
  prop feedback_title, :string
end
