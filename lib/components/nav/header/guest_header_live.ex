defmodule Bonfire.UI.Common.GuestHeaderLive do
  use Bonfire.UI.Common.Web, :stateless_component
  prop selected_tab, :any, default: nil
  prop page, :string, default: "home"

  # @decorate time()
  render_sface_or_native()
end
