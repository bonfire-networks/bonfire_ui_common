defmodule Bonfire.UI.Common.GuestHeaderLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page_title, :string, default: nil
  prop page, :string, default: nil

end
