# was `Bonfire.UI.Social.Activity.HtmlBodyLive`: generic once it no longer read the activity or object
defmodule Bonfire.UI.Common.HtmlBodyLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop html_body, :any, default: nil

  # the DOM ids are built from `parent_id` alone, which names the object already: the activity and object were only read for their ids
  prop parent_id, :any, default: nil
  # prop object, :any
  prop object_type, :any, default: nil
  # prop activity, :any, default: nil
  prop activity_inception, :boolean, default: false
  prop showing_within, :atom, default: nil
  prop viewing_main_object, :boolean, default: false
  prop is_remote, :boolean, default: false

  # media the body places where it sits, by the URL the body has for it (see `Bonfire.UI.Common.HtmlBodyPartsLive`)
  prop inline_media, :map, default: %{}

  # the body already cut at that media, by whoever found it (see `Bonfire.Files.InlineMedia.split/3`), so it isn't cut again
  prop body_parts, :any, default: nil
  # a sensitive post: its inline media are blurred, as in the attachment list
  prop cw, :any, default: nil

  @doc "The options for `rich/2` a body is rendered with: remote content is stored as HTML, while local content may hold markdown and/or HTML, which is sanitised rather than escaped; a last line of only hashtags stays tagged but isn't shown."
  def rich_opts(is_remote \\ false) do
    [skip_markdown: is_remote, sanitize: !is_remote, hide_trailing_hashtags: true]
  end
end
