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
  # a sensitive post: its inline media are blurred, as in the attachment list
  prop cw, :any, default: nil
end
