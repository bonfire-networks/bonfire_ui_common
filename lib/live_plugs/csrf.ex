defmodule Bonfire.UI.Common.LivePlugs.Csrf do
  use Bonfire.UI.Common.Web, :live_plug

  def mount(_, %{"_csrf_token" => token}, socket),
    do:
      {:ok,
       assign_global(socket,
         csrf_token: token
         # csrf_token_value: Phoenix.HTML.Tag.csrf_token_value()
       )}

  def mount(_, session, socket) do
    warn(session, "No _csrf_token found in session")

    {:ok,
     assign(socket,
       csrf_token: nil
       # csrf_token_value: nil
     )}
  end
end
