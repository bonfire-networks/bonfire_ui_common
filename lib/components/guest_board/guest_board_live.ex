defmodule Bonfire.UI.Common.GuestBoardLive do
  @moduledoc """
  The public "board" shell for the guest Home, About, People directory and Code of conduct pages: one centred column that owns the header, navigation, banner and footer, so every section shares the same outer edges and gutter.

  Deliberately a page-level wrapper rather than a layout mode: only those guest pages opt in (by setting `without_sidebar`/`without_secondary_widgets`/`hide_mobile_dock` and rendering this), so other public pages keep their existing chrome. Styling is Tailwind/DaisyUI in the templates; `assets/css/app.css` only resets the app shell around the board (see `:has(#guest-board)`), which is outside this component's markup.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "Which page is being shown (`:home`, `:about`, `:people` or `:conduct`), for the current nav state."
  prop page, :atom, default: :home

  @doc "The page content, placed between the banner and the footer."
  slot default, required: true

  @doc """
  The layout assigns a view sets to render inside the board: the board owns all chrome (header, nav, footer), so the app sidebars, widgets, mobile dock and page header are turned off. Pass whether the viewer is a guest, since only guests get the board.

      iex> Bonfire.UI.Common.GuestBoardLive.layout_assigns(false)
      [without_sidebar: false, without_secondary_widgets: false, hide_mobile_dock: false, no_header: false]
  """
  def layout_assigns(guest?) do
    [
      without_sidebar: guest?,
      without_secondary_widgets: guest?,
      hide_mobile_dock: guest?,
      no_header: guest?
    ]
  end

  @doc "The configured instance name, falling back to the app name (same fallback as `LogoLive`)."
  def instance_name do
    Config.get([:ui, :theme, :instance_name], nil) || Bonfire.Application.name_and_flavour()
  end

  @doc "The configured instance banner image, if any."
  def banner_image, do: Config.get([:ui, :theme, :instance_image], nil)

  @doc "Whether guests may browse the people directory (same check as `GuestHeaderLive`)."
  def show_people?(context) do
    not is_nil(current_user_id(context)) or
      Config.get([Bonfire.UI.Me.UsersDirectoryLive, :show_to]) == :guests
  end

  @doc "The instance's configured community links, as `{name, url}` tuples."
  def community_links do
    Config.get([:ui, :theme, :instance_welcome, :links], [])
    |> Bonfire.UI.Common.WidgetCommunityLinksLive.normalize_links()
  end

  @doc """
  Link opts marking the current page for assistive tech and styling.

      iex> Bonfire.UI.Common.GuestBoardLive.current_opts(:about, :about)
      ["aria-current": "page"]

      iex> Bonfire.UI.Common.GuestBoardLive.current_opts(:home, :about)
      []
  """
  def current_opts(page, page), do: ["aria-current": "page"]
  def current_opts(_, _), do: []

  @doc "The board's navigation entries as `{page, path, label}`, respecting directory visibility."
  def nav_items(context) do
    [
      {:home, "/", l("Explore")},
      {:about, "/about", l("About")},
      show_people?(context) && {:people, "/users", l("People")},
      {:conduct, "/conduct", l("Code of conduct")}
    ]
    |> Enum.filter(& &1)
  end

  @doc "The instance's own pages linked in the footer, as `{path, label}`."
  def footer_pages do
    [
      {"/about", l("About")},
      {"/conduct", l("Code of conduct")},
      {"/privacy", l("Privacy")},
      Config.get([:terms, :impressum]) not in [nil, ""] && {"/impressum", l("Impressum")}
    ]
    |> Enum.filter(& &1)
  end
end
