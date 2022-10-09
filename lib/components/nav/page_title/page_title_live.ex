defmodule Bonfire.UI.Common.PageTitleLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page_title, :string, default: "Bonfire"

end