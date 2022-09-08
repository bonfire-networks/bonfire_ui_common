defmodule Bonfire.UI.Common.FeedbackButtonLive do
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "Pre-fill the feedback form with some text"
  prop text, :string, default: nil

  @doc "Classes to style the link/button"
  prop class, :css_class, default: "w-full mt-2 normal-case btn btn-sm btn-info btn-wide"

  import Bonfire.Common.Modularity.DeclareExtensions
  declare_nav_component("Open to composer ready to provide feedback")

end
