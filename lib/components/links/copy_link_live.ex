defmodule Bonfire.UI.Common.CopyLinkLive do
  @moduledoc """
  A "Copy link" item for a dropdown menu: the content of an `<li>`, one `<a phx-hook="Copy">` whose `href` and `data-clipboard-text` are both the URL. The `Copy` hook (`assets/js/copy.js`) copies `data-clipboard-text`; without JS the link still opens the URL.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "The DOM id of the link, as the caller had it before (the `Copy` hook needs one)"
  prop id, :string, required: true

  @doc "The URL to copy"
  prop url, :string, required: true

  @doc "The text of the item"
  prop label, :string, default: nil

  @doc "When true, the item offers to share the URL where the browser can (`data-share`), and says \"Share\" there"
  prop share, :boolean, default: false

  @doc "An optional `data-role` for the link"
  prop role, :string, default: nil
end
