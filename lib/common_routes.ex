defmodule Bonfire.UI.Common.Routes do
  defmacro __using__(_) do

    quote do

      # pages anyone can view
      scope "/" do
        pipe_through :browser

        get "/guest/error", Bonfire.UI.Common.ErrorController, as: :error_guest

        post "/LiveHandler/:live_handler", Bonfire.UI.Common.FormsLiveHandlerFallbackController, :fallback
        get "/LiveHandler/:live_handler", Bonfire.UI.Common.FormsLiveHandlerFallbackController, :fallback

        post "/session_redirect", Bonfire.UI.Common.SessionRedirectController, :set_and_redirect
      end

      # pages only guests can view
      scope "/", Bonfire do
        pipe_through :browser
        pipe_through :guest_only
      end

      # pages you need an account to view
      scope "/", Bonfire do
        pipe_through :browser
        pipe_through :account_required
    end

      # pages you need to view as a user
      scope "/", Bonfire do
        pipe_through :browser
        pipe_through :user_required
      end

      # pages only admins can view
      scope "/settings/admin" do
        pipe_through :browser
        pipe_through :admin_required
      end




    end
  end
end
