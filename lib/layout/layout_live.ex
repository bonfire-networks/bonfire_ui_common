defmodule Bonfire.UI.Common.LayoutLive do
  @moduledoc """
  A simple Phoenix function component that sets default assigns needed for every view (eg. used in nav) and then embeds some Surface stateful and stateless components (passing along inner_content to be shown in one of them)
  """
  use Bonfire.UI.Common.Web, :stateless_component

  def render(assigns) do

    # Note: since this is not a Surface component, we need to set default props this way
    # TODO: make this list of assigns config-driven so other extensions can add what they need?
    assigns = assigns
    |> assign_new(:page_title, fn -> nil end)
    |> assign_new(:page, fn -> nil end)
    |> assign_new(:notification, fn -> nil end)
    |> assign_new(:page_header_aside, fn -> nil end)
    |> assign_new(:page_header_drawer, fn -> false end)
    |> assign_new(:without_header, fn -> false end)
    |> assign_new(:layout_mode, fn -> nil end)
    |> assign_new(:inner_content, fn -> nil end)
    |> assign_new(:object_id, fn -> nil end)
    |> assign_new(:post_id, fn -> nil end)
    |> assign_new(:thread_id, fn -> nil end)
    |> assign_new(:reply_to_id, fn -> nil end)
    |> assign_new(:create_activity_type, fn -> nil end)
    |> assign_new(:to_boundaries, fn -> boundaries_or_default(e(assigns, :to_boundaries, nil), assigns) end)
    |> assign_new(:to_circles, fn -> [] end)
    |> assign_new(:smart_input_prompt, fn -> nil end)
    |> assign_new(:smart_input_text, fn -> nil end)
    |> assign_new(:showing_within, fn -> nil end)
    |> assign_new(:without_sidebar, fn -> false end)
    |> assign_new(:sidebar_widgets, fn -> [] end)
    |> assign_new(:hide_smart_input, fn -> false end)
    |> assign_new(:thread_mode,  fn -> nil end)
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
          if (#{Settings.get([:ui, :smart_input_as], nil, @__context__) !=:sidebar} || ((window.innerWidth > 0) ? window.innerWidth : screen.width) <= 768) {
            this.smart_input_open = true
            this.smart_input_minimized = false
          }
        }
      }"}
      >
      
        <div 
          x-cloak
          x-show="open_extensions_sidebar" 
          @keydown.window.escape="open_extensions_sidebar = false;" 
          class="fixed top-0 bottom-0 left-0 z-[200] overflow-hidden">
          <div class="inset-0 h-full">
            <section class="h-full" aria-labelledby="slide-over-heading">
              <div class="h-full w-[230px]" x-description="Slide-over panel, show/hide based on slide-over state."
                x-show="open_extensions_sidebar"
                x-transition:enter="transform transition ease-in-out duration-150 sm:duration-500"
                x-transition:enter-start="-translate-x-full"
                x-transition:enter-end="-translate-x-0"
                x-transition:leave="transform transition ease-in-out duration-150 sm:duration-500"
                x-transition:leave-start="-translate-x-0"
                x-transition:leave-end="-translate-x-full">
                <div class="w-full h-full bg-base-100">
                  <div class="px-2">
                    <div class="flex items-start justify-between py-4">
                      <LiveRedirect 
                        class="flex items-center gap-2"
                        to={path(Config.get(:home_page, Bonfire.Web.HomeLive))}>
                        <div class="w-8 h-8 bg-center bg-no-repeat bg-cover" style={"background-image: url(#{ Config.get([:ui, :theme, :instance_icon], nil)})"}></div>
                        <div class="text-lg font-bold text-base-content">{Config.get([:ui, :theme, :instance_name], Bonfire.Application.name())}</div>
                      </LiveRedirect>
                    </div>
                  </div>
                    <ul class="p-2 mb-3 menu">
                      <li class="text-xs font-medium tracking-wider uppercase menu-title text-primary-content-800">
                        <span>{"Timelines"}</span>
                      </li>
                      <li>
                        <LiveRedirect 
                          :if={module_enabled?(Bonfire.Classify.Web.CategoriesLive)}
                          to={path(Config.get(:user_home_page, Bonfire.UI.Social.HomeLive))} >
                            <div class="flex items-center w-full">
                              <Icon solid="Newspaper" class="w-5 h-5" />
                              <div class="flex-1 ml-2 text-sm font-normal text-primary-content-800">{l "My feed"}</div>
                            </div>
                        </LiveRedirect>
                      </li>
                      <li>
                        <LiveRedirect 
                          :if={module_enabled?(Bonfire.Classify.Web.CategoriesLive)}
                          to={"/feed/local"} >
                            <div class="flex items-center w-full">
                              <Icon solid="LocationMarker" class="w-5 h-5" />
                              <div class="flex-1 ml-2 text-sm font-normal text-primary-content-800">{l "Local"}</div>
                            </div>
                        </LiveRedirect>
                      </li>
                      <li>
                        <LiveRedirect 
                          :if={module_enabled?(Bonfire.Classify.Web.CategoriesLive)}
                          to={"/feed/federation"} >
                            <div class="flex items-center w-full">
                              <Icon solid="Globe" class="w-5 h-5" />
                              <div class="flex-1 ml-2 text-sm font-normal text-primary-content-800">{l "Federated"}</div>
                            </div>
                        </LiveRedirect>
                      </li>
                    </ul>
                    <ul class="p-2 mb-3 menu">
                      <li class="text-xs font-medium tracking-wider uppercase menu-title text-primary-content-800">
                        <span>{"Extensions"}</span>
                      </li>
                      <li>
                        <LiveRedirect 
                          :if={module_enabled?(Bonfire.Classify.Web.CategoriesLive)}
                          to={path(Bonfire.Classify.Web.CategoriesLive)}>
                            <div class="flex items-center w-full">
                              <Icon solid="Collection" class="w-5 h-5" />
                              <div class="flex-1 ml-2 text-sm font-normal text-primary-content-800">{l "Topics"}</div>
                            </div>
                        </LiveRedirect>
                      </li>
                      <li>
                        <LiveRedirect 
                          :if={module_enabled?(Bonfire.UI.Coordination.MyTasksLive)}
                          to={path(Bonfire.UI.Coordination.MyTasksLive)}>
                            <div class="flex items-center w-full">
                              <Icon solid="LightningBolt" class="w-5 h-5" />
                              <div class="flex-1 ml-2 text-sm font-normal text-primary-content-800">{l "Coordination"}</div>
                            </div>
                        </LiveRedirect>
                      </li>
                      
                      <li>
                        <LiveRedirect 
                          :if={module_enabled?(Bonfire.Breadpub.BreadDashboardLive)}
                          to={path(Bonfire.Breadpub.BreadDashboardLive)}>
                            <div class="flex items-center w-full">
                              <Icon solid="ChevronRight" class="w-5 h-5" />
                              <div class="flex-1 ml-2 text-sm font-normal text-primary-content-800">BreadPub</div>
                            </div>
                        </LiveRedirect>
                      </li>
                  </ul>
                </div>
              </div>
            </section>
          </div>
        </div>

      <div :class="{'pl-[230px]': open_extensions_sidebar}">
        <Bonfire.UI.Common.HeaderFullLayoutLive 
          reply_to_id={@reply_to_id}
          layout_mode={e(@layout_mode, nil)}
          thread_id={@thread_id}
          showing_within={@showing_within}
          create_activity_type={@create_activity_type}
          to_boundaries={e(@to_boundaries, [])}
          to_circles={e(@to_circles, [])}
          smart_input_prompt={@smart_input_prompt}
          smart_input_text={@smart_input_text}
          sidebar_widgets={@sidebar_widgets}
          thread_mode={@thread_mode}
          hide_smart_input={e(@hide_smart_input, false)}
          show_less_menu_items={@show_less_menu_items}
          user={@current_user} 
          page={@page} />

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
            "w-full mx-auto grid grid-cols-[280px_auto] justify-center",
            "grid-cols-[240px_auto]": e(@layout_mode, nil) == "full"        }>

          <Bonfire.UI.Common.SidebarLive
            page={@page}
            layout_mode={e(@layout_mode, nil)}
            reply_to_id={@reply_to_id}
            thread_id={@thread_id}
            showing_within={@showing_within}
            create_activity_type={@create_activity_type}
            to_boundaries={e(@to_boundaries, [])}
            to_circles={e(@to_circles, [])}
            smart_input_prompt={@smart_input_prompt}
            smart_input_text={@smart_input_text}
            sidebar_widgets={@sidebar_widgets}
            thread_mode={@thread_mode}
            hide_smart_input={e(@hide_smart_input, false)}
            show_less_menu_items={@show_less_menu_items}
          />

          <div class={
            "gap-2 md:gap-0 relative z-[105] w-full col-span-1",
            "max-w-screen-lg mx-auto": e(@layout_mode, nil) == "full"
            }>
            <Bonfire.UI.Common.HeaderMobileGuestLive :if={!@current_user} />
            
            <div class={"justify-center mt-6 grid grid-cols-[680px_320px] gap-8",
            "!grid-cols-[1020px]": !is_list(@sidebar_widgets[:users][:secondary])
            }>
              <div
                class={"grid relative invisible_frame",
                "grid-rows-[60px_auto]": !Settings.get([:ui, :compact], false, @__context__),
                "grid-rows-[40px_auto]": Settings.get([:ui, :compact], false, @__context__)
                }>
                <Bonfire.UI.Common.PageHeaderLive
                  :if={!@without_header}
                  page_title={@page_title}
                  page_header_drawer={e(@page_header_drawer, false)}
                  >
                  <:right_action>
                    <Surface.Components.Dynamic.Component
                      :if={@current_user && @page_header_aside}
                      :for={{component, component_assigns} <- e(@page_header_aside, [])}
                      module={component}
                      {...component_assigns}
                    />
                  </:right_action>
                </Bonfire.UI.Common.PageHeaderLive>

                <div class={
                  "mt-4 px-3 overflow-y-auto rounded-b-none md:overflow-y-visible md:px-0 full-height"
                }
                >
                  <!-- {#if @preview_module !=nil and is_atom(@preview_module)}
                    <Surface.Components.Dynamic.Component
                      module={@preview_module}
                      {...(@preview_assigns || %{})}
                    />
                    <style>
                    #inner_content {visibility: hidden}
                    </style>
                  {/if} -->
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
                  "!gap-5": !Settings.get([:ui, :compact], false, @__context__),
                }>
                <Surface.Components.Dynamic.Component
                  :if={@current_user}
                  :for={{component, component_assigns} <- @sidebar_widgets[:users][:secondary] || [
                    {Bonfire.UI.Social.WidgetTagsLive, []},
                    {Bonfire.UI.Common.WidgetFeedbackLive, []}
                  ]}
                  module={component}
                  {...component_assigns}
                />

                <Surface.Components.Dynamic.Component
                  :if={!@current_user}
                  :for={{component, component_assigns} <- @sidebar_widgets[:guests][:secondary] || [
                      {Bonfire.UI.Social.WidgetTagsLive, []}
                  ]}
                  module={component}
                  {...component_assigns}
                />
              </div>

            </div>



            <Bonfire.UI.Common.HeaderUserLive
              :if={@current_user}
              page={@page}
            />
          </div>

          

          <Bonfire.UI.Common.MobileSmartInputButtonLive
            smart_input_prompt={@smart_input_prompt}
          />
        </div>
      </div>
    </div>

    <Bonfire.UI.Common.ReusableModalLive
      id="modal"
    />

    <Bonfire.UI.Common.NotificationLive
      id="notification"
      notification={@notification}
      __context__={@__context__}
      root_flash={@flash}
    />
    """
  end
end
