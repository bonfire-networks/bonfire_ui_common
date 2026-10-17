defmodule Bonfire.UI.Common.NavSidebarLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop sidebar_widgets, :list, default: []
  prop page, :any, default: nil
  prop selected_tab, :any, default: nil
  prop nav_items, :list, default: []

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

  @doc "The guest nav links, each marked `active?` once so the template doesn't recompute it per styled part."
  def guest_links(context, page) do
    [
      %{
        to: "/feed",
        icon: "ph:compass-duotone",
        label: l("Explore"),
        pages: ["home"],
        paths: ["/feed", "/"]
      },
      %{
        to: "/about",
        icon: "ph:info-duotone",
        label: l("About"),
        pages: ["about"],
        paths: ["/about"]
      },
      extension_enabled?(:bonfire_ui_groups, context) &&
        %{
          to: "/groups",
          icon: "ph:users-three-duotone",
          label: l("Public Groups"),
          pages: ["groups"],
          paths: ["/groups"]
        },
      Config.get([Bonfire.UI.Me.UsersDirectoryLive, :show_to]) == :guests &&
        %{
          to: "/users",
          icon: "ph:users-four-duotone",
          label: l("Members"),
          pages: ["users"],
          paths: ["/users"]
        },
      %{
        to: "/conduct",
        icon: "ph:newspaper-duotone",
        label: l("Code of Conduct"),
        pages: ["conduct"],
        paths: ["/conduct"]
      }
    ]
    |> Enum.filter(& &1)
    |> Enum.map(
      &Map.put(&1, :active?, nav_active?(context, page, pages: &1.pages, paths: &1.paths))
    )
  end
end
