defmodule Bonfire.UI.Common.EmojiPickerLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop id, :any, default: "editor_emoji"
  prop class, :css_class, default: ""
  prop target_field, :string, required: true
end
