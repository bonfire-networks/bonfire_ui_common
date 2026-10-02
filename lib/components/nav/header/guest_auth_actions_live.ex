defmodule Bonfire.UI.Common.GuestAuthActionsLive do
  @moduledoc """
  The guest log in / sign up buttons, shared by the mobile dock, the widgets sidebar and the guest board header so they offer the same actions: "Log in" and "Sign up" when signups are open, a single "Sign in" on invite-only instances. Renders bare links, so the caller owns the wrapper and layout.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop login_class, :css_class, default: "btn btn-soft"
  prop signup_class, :css_class, default: "btn btn-primary"
  prop login_id, :string, default: nil
  prop signup_id, :string, default: nil
end
