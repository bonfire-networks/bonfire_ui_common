defmodule Bonfire.UI.Common.RedirectToSelfTest do
  @moduledoc """
  `redirect_to/3` doesn't send a LiveView to the page it is already on, which would load the page again and redirect again, forever.
  """
  use ExUnit.Case, async: true
  @moduletag :ui

  alias Bonfire.UI.Common

  # as a view's `handle_params` sees it: the current path is assigned before it runs
  defp socket_on(path) do
    %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, current_url: path}}
  end

  test "to another page, it redirects" do
    # the positive first, so the next test can't pass on a redirect that never happens
    assert %{redirected: {_kind, %{to: "/elsewhere"}}} =
             Common.redirect_to(socket_on("/here"), "/elsewhere")
  end

  test "to the page it's on, it stays" do
    assert %{redirected: nil} = Common.redirect_to(socket_on("/here"), "/here")
  end

  test "to the page it's on, with a fallback, it goes to the fallback" do
    assert %{redirected: {_kind, %{to: "/fallback"}}} =
             Common.redirect_to(socket_on("/here"), "/here", fallback: "/fallback")
  end

  test "to the page it's on, with reload: true, it reloads it" do
    assert %{redirected: {_kind, %{to: "/here"}}} =
             Common.redirect_to(socket_on("/here"), "/here", reload: true)
  end

  test "to the same page with another query, it redirects" do
    assert %{redirected: {_kind, %{to: "/here?tab=hidden"}}} =
             Common.redirect_to(socket_on("/here"), "/here?tab=hidden")
  end
end
