defmodule Bonfire.UI.Common.NavSidebarLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.Me.Users

  prop sidebar_widgets, :list, default: []
  prop page, :any, default: nil
  prop selected_tab, :any, default: nil
  prop nav_items, :list, default: []
  prop csrf_token, :any, default: nil
  prop current_user_id, :any, default: nil
  prop current_account_id, :any, default: nil
  prop exclude_circles, :list, default: []

  @doc """
  Returns true if the current nav item is active.

  Matches against the `page` assign first (set explicitly by each view, e.g.
  `"about"`, `"conduct"`, `"groups"`, `"users"`, `"home"`) and falls back to the
  current URL path (needed for `/feed`, which sets no `page`).
  """
  def nav_active?(context, page, opts \\ []) do
    pages = List.wrap(opts[:pages])
    paths = List.wrap(opts[:paths])

    (is_binary(page) and page in pages) or path_active?(context, paths)
  end

  defp path_active?(_context, []), do: false

  defp path_active?(context, paths) do
    current =
      case current_url(context) do
        url when is_binary(url) -> URI.parse(url).path || url
        _ -> nil
      end

    is_binary(current) and
      Enum.any?(paths, fn p -> current == p or String.starts_with?(current, p <> "/") end)
  end

  # the guest links share the signed-in nav's treatment (see `Bonfire.UI.Common.LinkWidgetLive`)

  @doc "Row classes for a nav link, highlighted when active."
  def nav_link_class(context, page, opts \\ []) do
    [
      "nav-row transition-colors duration-150",
      Bonfire.UI.Common.LinkWidgetLive.active_link_class(nav_active?(context, page, opts))
    ]
  end

  @doc "Icon classes for a nav link, highlighted when active (a string, as `<#Icon>` takes)."
  def nav_icon_class(context, page, opts \\ []) do
    "size-4.5 " <>
      Bonfire.UI.Common.LinkWidgetLive.active_icon_class(nav_active?(context, page, opts))
  end

  @doc "Text classes for a nav link, highlighted when active."
  def nav_text_class(context, page, opts \\ []) do
    [
      "truncate min-w-0 text-sm",
      Bonfire.UI.Common.LinkWidgetLive.active_label_class(nav_active?(context, page, opts))
    ]
  end
end
