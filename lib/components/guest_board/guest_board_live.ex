defmodule Bonfire.UI.Common.GuestBoardLive do
  @moduledoc """
  The public "board" shell for the pages people see outside the app: the guest Home, About, People directory, Code of conduct, Privacy and Impressum, and the auth pages (log in, sign up, password and email forms).

  """
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "The page shown, for the nav state and to leave out its own masthead action."
  prop page, :atom, default: :home

  @doc "Whether to show the community tabs."
  prop nav, :boolean, default: true

  @doc "Whether to show the masthead's log in / sign up actions."
  prop actions, :boolean, default: true

  @doc "`:page` (720px) or `:form` (580px)."
  prop size, :atom, default: :page, values: [:page, :form]

  @doc "The page lays out its own sheet instead of the default one."
  prop bare, :boolean, default: false

  @doc "DOM id of the default sheet."
  prop sheet_id, :string, default: "guest-board-sheet"

  @doc "Id of the heading that names the default sheet."
  prop labelledby, :string, default: nil

  slot default, required: true

  @doc """
  The layout assigns a view sets to render inside the board: the board owns its chrome (header, nav, footer), so the app sidebars, widgets and page header are turned off. The mobile dock stays, since below `lg` it carries the guest log in / sign up actions. Pass whether the viewer is a guest, since only guests get the board.

      iex> Bonfire.UI.Common.GuestBoardLive.layout_assigns(false)
      [without_sidebar: false, without_secondary_widgets: false, no_header: false]
  """
  def layout_assigns(guest?) do
    [
      without_sidebar: guest?,
      without_secondary_widgets: guest?,
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
