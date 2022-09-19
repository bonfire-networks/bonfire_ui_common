defmodule Bonfire.UI.Common.LayoutLive do
  @moduledoc """
  A simple Phoenix function component that sets default assigns needed for every view (eg. used in nav) and then embeds some Surface stateful and stateless components (passing along inner_content to be shown in one of them)
  """
  use Bonfire.UI.Common.Web, :stateless_component

  def render(assigns) do
    current_app = assigns[:__context__][:current_app]
    # |> debug("current_app")

    nav_items =
      assigns[:nav_items] ||
        Bonfire.Common.ExtensionModules.default_nav(current_app) ||
        Bonfire.Common.NavModules.nav(current_app)

    # Note: since this is not a Surface component, we need to set default props this way
    # TODO: make this list of assigns config-driven so other extensions can add what they need?
    assigns =
      assigns
      # |> debug
      |> assign(
        :to_boundaries,
        boundaries_or_default(e(assigns, :to_boundaries, nil), assigns)
      )
      |> assign_new(:page_title, fn -> nil end)
      |> assign_new(:without_guest_header, fn -> nil end)
      |> assign_new(:page, fn -> nil end)
      |> assign_new(:selected_tab, fn -> nil end)
      |> assign_new(:notification, fn -> nil end)
      |> assign_new(:page_header_aside, fn -> nil end)
      |> assign_new(:page_header_drawer, fn -> false end)
      |> assign_new(:custom_page_header, fn -> nil end)
      |> assign_new(:inner_content, fn -> nil end)
      |> assign_new(:object_id, fn -> nil end)
      |> assign_new(:post_id, fn -> nil end)
      |> assign_new(:thread_id, fn -> nil end)
      |> assign_new(:reply_to_id, fn -> nil end)
      |> assign_new(:create_activity_type, fn -> nil end)
      |> assign_new(:to_circles, fn -> [] end)
      |> assign_new(:smart_input_prompt, fn -> nil end)
      |> assign_new(:smart_input_text, fn -> nil end)
      |> assign_new(:showing_within, fn -> nil end)
      |> assign_new(:sidebar_widgets, fn -> [] end)
      |> assign_new(:nav_items, fn -> nav_items end)
      |> assign_new(:without_sidebar, fn ->
        empty?(nav_items) &&
          ((ulid(current_user(assigns)) &&
              empty?(e(assigns, :sidebar_widgets, :users, :main, nil))) ||
             (!ulid(current_user(assigns)) &&
                empty?(e(assigns, :sidebar_widgets, :guests, :main, nil))))
      end)
      |> assign_new(:hide_smart_input, fn -> false end)
      |> assign_new(:thread_mode, fn -> nil end)
      |> assign_new(:show_less_menu_items, fn -> false end)
      |> assign_new(:preview_module, fn -> nil end)
      |> assign_new(:preview_assigns, fn -> nil end)

    # |> debug()

    ~F"""
    <div
      id="layout-live"
      x-data={"{
        smart_input_title_text: null,
        smart_input_open: false,
        smart_input_fullscreen: false,
        open_extensions_sidebar: false,
        toggle_sidebar_widgets: false,
        smart_input_minimized: false,
        show_smart_input() {
          if (#{Settings.get([:ui, :smart_input_as], nil, @current_user || @__context__) != :sidebar} || ((window.innerWidth > 0) ? window.innerWidth : screen.width) <= 768) {
            this.smart_input_open = true
            this.smart_input_minimized = false
          }
        }
      }"}
    >
      <Bonfire.UI.Common.LoggedHeaderLive
        :if={@current_user}
        page_header_aside={@page_header_aside}
        page_title={@page_title}
        page_header_drawer={e(@page_header_drawer, false)}
        hide_smart_input={@hide_smart_input}
        showing_within={@showing_within}
        reply_to_id={e(@reply_to_id, "")}
        thread_id={@thread_id}
        create_activity_type={@create_activity_type}
        thread_mode={@thread_mode}
        without_sidebar={@without_sidebar}
        custom_page_header={@custom_page_header}
        to_boundaries={@to_boundaries}
        to_circles={e(@to_circles, [])}
        smart_input_prompt={@smart_input_prompt}
        smart_input_text={@smart_input_text}
        sidebar_widgets={@sidebar_widgets}
      />
      <Bonfire.UI.Common.GuestHeaderLive :if={!@current_user && @without_guest_header != true} />
      <div class="transition duration-150 ease-in-out transform">
        <!-- :class="{'ml-[240px]': open_extensions_sidebar}" -->
        <div
          x-data="{
            open_sidebar_drawer: false,
            open_drawer: false,
            smart_input_open: false,
            width: window.innerWidth,
          }"
          @resize.window.debounce.100="width = window.innerWidth"
          id="bonfire_layout"
          class={
            "w-full md:px-4  desktop-lg:pl-[32px] items-start mx-auto grid grid-cols-1 md:grid-cols-[230px_1fr] desktop-lg:grid-cols-[280px_minmax(min-content,_980px)] gap-4 desktop-lg:gap-8 justify-center",
            "!grid-cols-1": @without_sidebar,
            "!pl-3": !@current_user
          }
        >
          <div :if={!@without_sidebar} class="px-0 pt-3 md:pt-6 relative z-[110] sticky top-0">
            <Bonfire.UI.Common.NavSidebarLive
              items={@nav_items}
              sidebar_widgets={@sidebar_widgets}
              page={@page}
              selected_tab={@selected_tab}
            />
          </div>

          <div class={
            "gap-2 md:gap-0 relative z-[105] w-full col-span-1",
            "!max-w-screen-lg mx-auto": @without_sidebar
          }>
            <div class={
              "justify-center md:mt-6 grid tablet-lg:grid-cols-[1fr_320px] desktop-lg:grid-cols-[680px_320px] gap-4 desktop-lg:gap-8 grid-cols-1",
              "!grid-cols-1": !is_list(@sidebar_widgets[:users][:secondary])
            }>
              <div class="relative grid invisible_frame">
                <div class={
                  "h-[calc(var(--inner-window-height)-117px)] px-3 overflow-y-auto rounded-b-none md:overflow-y-visible md:px-0 md:h-full",
                  "h-[calc(var(--inner-window-height)-207px)]": !@without_sidebar
                }>
                  <div id="inner_content">
                    {@inner_content}
                  </div>
                </div>
              </div>

              <div
                :if={is_list(@sidebar_widgets[:users][:secondary])}
                x-show={if @preview_module, do: "false", else: "true"}
                class={
                  "items-start sticky z-[97] top-6 grid-flow-row gap-3 overflow-x-hidden overflow-y-auto auto-rows-min widget hidden tablet-lg:grid ",
                  "!gap-5": !Settings.get([:ui, :compact], false, @__context__)
                }
              >
                <!-- USER WIDGET SIDEBAR -->
                <Dynamic.Component
                  :if={ulid(@current_user)}
                  :for={{component, component_assigns} <-
                    @sidebar_widgets[:users][:secondary] ||
                      [
                        {Bonfire.UI.Social.WidgetTagsLive, []},
                        {Bonfire.UI.Common.WidgetFeedbackLive, []}
                      ]}
                  module={component}
                  {...component_assigns}
                />

                <!-- GUEST WIDGET SIDEBAR -->
                <Dynamic.Component
                  :if={!@current_user}
                  :for={{component, component_assigns} <- @sidebar_widgets[:guests][:secondary] || []}
                  module={component}
                  {...component_assigns}
                />
              </div>
            </div>
          </div>

          <Bonfire.UI.Common.MobileSmartInputButtonLive
            :if={ulid(@current_user)}
            smart_input_prompt={@smart_input_prompt}
          />
        </div>
      </div>
      <Bonfire.UI.Common.NavFooterMobileUserLive :if={ulid(@current_user)} page={@page} />
    </div>

    <Bonfire.UI.Common.ReusableModalLive id="modal" />

    <Bonfire.UI.Common.NotificationLive
      id="notification"
      notification={@notification}
      __context__={@__context__}
      root_flash={@flash}
    />
    """
  end
end
