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

    # |> debug("nav_items")

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
      |> assign_new(:page, fn -> nil end)
      |> assign_new(:selected_tab, fn -> nil end)
      |> assign_new(:notification, fn -> nil end)
      |> assign_new(:page_header_aside, fn -> nil end)
      |> assign_new(:page_header_drawer, fn -> false end)
      |> assign_new(:without_header, fn -> false end)
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
        smart_input_minimized: false,
        show_smart_input() {
          if (#{Settings.get([:ui, :smart_input_as], nil, @current_user || @__context__) != :sidebar} || ((window.innerWidth > 0) ? window.innerWidth : screen.width) <= 768) {
            this.smart_input_open = true
            this.smart_input_minimized = false
          }
        }
      }"}
    >
      <div class="flex items-center shadow justify-between px-4 py-2 bg-base-100 sticky z-[999] top-0">
        <div class="flex items-center flex-1 w-full gap-3">
          <Bonfire.UI.Common.AppsLive />
          <Bonfire.UI.Common.LogoLive />
          <Dynamic.Component
            :if={module_enabled?(Bonfire.Search.Web.FormLive)}
            module={Bonfire.Search.Web.FormLive}
            search_limit={5}
          />
          <Bonfire.UI.Common.PageHeaderLive
            :if={!@without_header}
            page_title={@page_title}
            page_header_drawer={e(@page_header_drawer, false)}
          >
            <:right_action>
              <Dynamic.Component
                :if={@current_user && @page_header_aside}
                :for={{component, component_assigns} <- e(@page_header_aside, [])}
                module={component}
                {...component_assigns}
              />
            </:right_action>
          </Bonfire.UI.Common.PageHeaderLive>
        </div>

        <div class="flex items-center gap-4">
          <Bonfire.UI.Common.SmartInputContainerLive
            hide_smart_input={@hide_smart_input}
            showing_within={@showing_within}
            reply_to_id={e(@reply_to_id, "")}
            thread_id={@thread_id}
            create_activity_type={@create_activity_type}
            thread_mode={@thread_mode}
            without_sidebar={@without_sidebar}
            to_boundaries={@to_boundaries}
            to_circles={e(@to_circles, [])}
            smart_input_prompt={@smart_input_prompt}
            smart_input_text={@smart_input_text}
          />

          <LiveRedirect
            to={path(Bonfire.Data.Social.Message)}
            class={
              "btn btn-circle h-[40px] w-[40px] btn-sm btn-outline border-base-content/30 border",
              "!text-primary border-current": @page == "messages"
            }
          >
            <Icon solid="Mail" class={"w-5 h-5", "!text-primary": @page == "messages"} />
            <span :if={@page == "messages"} class="sr-only">{l("Current Page:")}
            </span>
            <Bonfire.UI.Common.BadgeCounterLive id={:inbox} class="indicator-item badge badge-secondary" />
          </LiveRedirect>

          <LiveRedirect
            to={path(:notifications)}
            class={
              "btn btn-circle btn-sm h-[40px] w-[40px] btn-outline border-base-content/30 border",
              "!text-primary border-current": @page == "notifications"
            }
          >
            <Icon solid="Bell" class={"w-5 h-5", "!text-primary": @page == "notifications"} />
            <span :if={@page == "notifications"} class="sr-only">{l("Current Page:")}
            </span>
            <Bonfire.UI.Common.BadgeCounterLive
              id={:notifications}
              class="indicator-item badge badge-secondary"
            />
          </LiveRedirect>

          <Bonfire.UI.Common.UserMenuLive />
        </div>
      </div>

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
            "w-full items-start mx-auto grid grid-cols-[280px_auto] gap-8 justify-center",
            "grid-cols-[240px_auto]": @without_sidebar
          }
        >
          <div :if={!@without_sidebar} class="px-0 pt-6 relative z-[110] sticky top-0">
            <Bonfire.UI.Common.NavSidebarLive
              items={@nav_items}
              sidebar_widgets={@sidebar_widgets}
              page={@page}
              selected_tab={@selected_tab}
            />
          </div>

          <div class={
            "gap-2 md:gap-0 relative z-[105] w-full col-span-1",
            "max-w-screen-lg mx-auto": @without_sidebar
          }>
            <Bonfire.UI.Common.HeaderMobileGuestLive :if={!@current_user} />

            <div class={
              "justify-center mt-6 grid grid-cols-[680px_320px] gap-8",
              "!grid-cols-[1020px]": !is_list(@sidebar_widgets[:users][:secondary])
            }>
              <div class="relative grid invisible_frame">
                <div class="px-3 overflow-y-auto rounded-b-none md:overflow-y-visible md:px-0 full-height">
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

            <Bonfire.UI.Common.NavFooterMobileUserLive :if={ulid(@current_user)} page={@page} />
          </div>

          <Bonfire.UI.Common.MobileSmartInputButtonLive smart_input_prompt={@smart_input_prompt} />
        </div>
      </div>
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
