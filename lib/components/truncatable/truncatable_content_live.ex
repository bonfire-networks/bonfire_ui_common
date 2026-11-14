# was `Bonfire.UI.Social.Activity.TruncatableContentLive`: generic once it no longer read the activity or object
defmodule Bonfire.UI.Common.TruncatableContentLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop html_body, :string, required: true
  # prop activity, :any, default: nil
  # prop object, :any, required: true
  # the DOM ids are built from `parent_id` alone, which the caller derives from its activity's component id (so it already names the object): the activity and object were only read for their ids
  prop parent_id, :any, required: true
  prop showing_within, :atom, default: nil
  prop viewing_main_object, :boolean, default: false
  prop activity_inception, :boolean, default: false
  prop object_type, :atom, default: nil
end
