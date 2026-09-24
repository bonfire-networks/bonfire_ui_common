defmodule Bonfire.UI.Common.Email.Basic do
  @moduledoc """
  The frame of an email that is sent (a notification, a digest): the instance's name, then the content on a card, in the instance's email theme.

  The content is MJML sections (`mj-section`), which go inside the card. `preheader`, when given, is what an inbox shows next to the subject.
  """
  use Bonfire.UI.Common.Web, :function_component

  # for whatever a flavour's or an instance's `email_theme` leaves out, since an email has no stylesheet to fall back on
  @default_theme [
    primary: "#e63946",
    primary_content: "#ffffff",
    body_bg: "#fff7f7",
    body_text: "#1f1f1f",
    muted: "#6b6b6b"
  ]

  @doc "The colours an email is drawn in, from `[:ui, :auth, :email_theme]` (which the account emails use too, through this): `primary`, `primary_content`, `body_bg`, `body_text` and `muted`."
  def theme do
    @default_theme
    |> Keyword.merge(Bonfire.Common.Config.get([:ui, :auth, :email_theme], []))
    |> Map.new()
  end

  @doc "The instance's icon, at an address an inbox can load."
  def icon,
    do:
      Bonfire.Common.Config.get([:ui, :theme, :instance_icon], nil)
      |> Bonfire.UI.Common.SEOImage.absolute_url()

  @doc "The stylesheet MJML inlines into every element, since an email client has none of the app's CSS."
  def css do
    theme = theme()

    """
    a { color: #{theme[:primary]}; }
    .muted { color: #{theme[:muted]}; }
    .muted a { color: #{theme[:muted]}; }
    """
  end
end
