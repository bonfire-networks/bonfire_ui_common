defmodule Bonfire.UI.Common.ComposerRemoveReplyLive do
  @moduledoc "\"Remove reply\": asks, then turns the reply into a new post keeping text and attachments (`remove_data`). Rendered in the header's reply menu and, on phones, in the reply excerpt (`compact`); `id_prefix` keeps their ids apart."
  use Bonfire.UI.Common.Web, :stateless_component

  prop id_prefix, :string, default: ""
  prop compact, :boolean, default: false
end
