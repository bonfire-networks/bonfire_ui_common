defmodule Bonfire.UI.Common.HtmlBodyPartsLive do
  @moduledoc """
  An object's body, with the media it places where they sit (see `Bonfire.Files.InlineMedia`): each one renders as `Bonfire.UI.Social.Activity.MediaLive` there, between the parts of the text around it (`Bonfire.Common.Text.markdown_parts/3`). Without such media, the body as `rich/2` renders it.

  Only the content: the caller wraps it in its own element, as `Bonfire.UI.Common.HtmlBodyLive` does for a post and a poll's preview does for its question.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop html_body, :any, default: nil
  # the options for `rich/2`, as the caller renders its body
  prop rich_opts, :list, default: []
  # media the body places where it sits, by the URL the body has for it
  prop inline_media, :map, default: %{}
  # a sensitive object: its inline media are blurred, as in the attachment list
  prop cw, :any, default: nil
  prop is_remote, :boolean, default: false
  # the DOM ids of each inline media are built from it
  prop parent_id, :any, default: nil
  prop showing_within, :atom, default: nil
  prop viewing_main_object, :boolean, default: false
  prop activity_inception, :boolean, default: false

  @doc "The body cut at each URL of `inline_media` (see `Bonfire.Common.Text.markdown_parts/3`), rendered with the same options as the whole body."
  def body_parts(html_body, inline_media, rich_opts) do
    Bonfire.Common.Text.markdown_parts(
      html_body,
      Map.keys(inline_media),
      [link_rel: nil] ++ Keyword.drop(rich_opts, [:skip_markdown, :__unsafe__])
    )
  end
end
