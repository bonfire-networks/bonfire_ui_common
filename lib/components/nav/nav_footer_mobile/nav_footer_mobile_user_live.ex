defmodule Bonfire.UI.Common.NavFooterMobileUserLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page, :string
  prop without_sidebar, :boolean, default: false
end
