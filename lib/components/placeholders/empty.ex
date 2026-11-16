defmodule Bonfire.UI.Common.Empty do
  use Bonfire.UI.Common.Web, :stateless_component

  prop comment, :any, default: nil
  # prop html_content, :any, default: nil

  @doc "Markup rendered as is, unescaped: only our own rendered output, never text that came from users."
  prop trusted_html, :any, default: nil

  @doc "Text shown escaped, as preformatted text."
  prop text, :any, default: nil

  slot default
end
