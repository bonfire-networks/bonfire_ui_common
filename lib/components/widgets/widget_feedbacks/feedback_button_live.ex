defmodule Bonfire.UI.Common.FeedbackButtonLive do
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "Pre-fill the feedback form with some text"
  prop text, :string, default: nil
  @doc "If the button is shown on the mobile navbar"
  prop mobile, :boolean, default: false
  @doc "Classes to style the link/button"
  prop class, :css_class, default: "w-full mt-2 normal-case btn btn-sm btn-info btn-wide"
  prop with_icon, :boolean, default: false

  prop event, :string, default: "Bonfire.Social.Posts:write_feedback"

  declare_nav_component("Open to composer ready to provide feedback")
end
