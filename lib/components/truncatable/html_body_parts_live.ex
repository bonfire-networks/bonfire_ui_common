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

  # the body already cut at that media, by whoever found it (see `Bonfire.Files.InlineMedia.split/3`), so it isn't cut again
  prop body_parts, :any, default: nil
  # a sensitive object: its inline media are blurred, as in the attachment list
  prop cw, :any, default: nil
  prop is_remote, :boolean, default: false
  # the DOM ids of each inline media are built from it
  prop parent_id, :any, default: nil
  prop showing_within, :atom, default: nil
  prop viewing_main_object, :boolean, default: false
  prop activity_inception, :boolean, default: false

  @doc "The body cut at each URL of `inline_media` (see `Bonfire.Common.Text.markdown_parts/3`, and `html_parts/3` for an HTML body), rendered with the same options as the whole body: a body `rich/2` takes as it is (`skip_markdown`, eg. a remote one) gets no other processing in parts either."
  def body_parts(html_body, inline_media, rich_opts) do
    Bonfire.Common.Text.markdown_parts(html_body, Map.keys(inline_media), parts_opts(rich_opts))
  end

  @doc "The options a body is cut with (`Bonfire.Common.Text.markdown_parts/3`), from the `rich_opts` it's rendered with, for a caller that cuts it ahead (see `Bonfire.Files.InlineMedia.split/3`)."
  def parts_opts(rich_opts) do
    drop =
      if rich_opts[:skip_markdown],
        do: [:skip_markdown, :__unsafe__, :hide_trailing_hashtags],
        else: [:skip_markdown, :__unsafe__]

    [link_rel: nil] ++ Keyword.drop(rich_opts, drop)
  end
end
