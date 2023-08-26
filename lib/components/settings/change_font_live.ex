defmodule Bonfire.UI.Common.ChangeFontLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop font_family, :any
  prop scope, :any, default: nil

  def render(assigns) do
    scoped =
      case assigns[:scope] do
        :account -> current_account(assigns[:__context__])
        :instance -> :instance
        _ -> current_user(assigns[:__context__])
      end

    assigns
    |> assign(scoped: scoped)
    |> render_sface()
  end
end
