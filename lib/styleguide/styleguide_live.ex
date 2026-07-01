defmodule Bonfire.UI.Common.StyleguideLive do
  @moduledoc """
  Design-system styleguide. Renders the core component vocabulary (color, type,
  shape, buttons, nav, post/poll/follow/article cards, onboarding stepper, the
  signature section divider) using DaisyUI + Tailwind utilities against the
  *live* theme — so it re-skins automatically with whatever `data-theme` is
  active (e.g. the Jacobin flavour).

  Public page, no auth required. Serves as the approval gate / visual-regression
  anchor for theme work before component markup is migrated app-wide.
  """
  use Bonfire.UI.Common.Web, :surface_live_view

  # Load the current user if present, but don't require it (public page).
  on_mount({LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]})

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page: "styleguide",
       selected_tab: :styleguide,
       page_title: l("Design system"),
       # Focused, full-width canvas — the styleguide is the content.
       without_sidebar: true,
       without_secondary_widgets: true,
       no_header: false,
       nav_items: [],
       sidebar_widgets: []
     )}
  end
end
