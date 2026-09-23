defmodule Bonfire.UI.Common.Email.Bare do
  @moduledoc """
  The least an email layout can be: one MJML document around the content, with nothing added.

  For showing a page's components as email (`?_email_format=`), where each one needs a single `<mjml>` root to be turned into HTML, but a header repeated on every row of a feed would be noise. An email that is sent uses `Bonfire.UI.Common.Email.Basic`.
  """
  use Bonfire.UI.Common.Web, :function_component
end
