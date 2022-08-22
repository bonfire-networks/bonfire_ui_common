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
    # |> debug()

    ~F"""
    <div
      id="layout-live"
      x-data={"{
        smart_input_title_text: null,
        smart_input_open: false,
        smart_input_fullscreen: false,
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
        x-data="{
          open_sidebar_drawer: false,
          open_drawer: false,
          smart_input_open: false,
          width: window.innerWidth,
        }"
        @resize.window.debounce.100="width = window.innerWidth"
        class={"bonfire_layout justify-center w-full wide:max-w-screen-xl mx-auto wide:justify-center grid-cols-1 md:grid-cols-[290px_minmax(auto,_580px)]  tablet-lg:grid-cols-[280px_minmax(500px,_680px)_280px] desktop-lg:grid-cols-[360px_680px_360px] grid md:gap-8 "}>
        <Bonfire.UI.Common.SidebarLive
          page={@page}
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


        <div
          class="gap-2 md:gap-0 relative  w-full col-span-1 grid grid-rows-[1fr_48px] md:grid-rows-1">
          <Bonfire.UI.Common.HeaderMobileGuestLive :if={!current_user(@__context__)} />
          <div
            class={"grid relative invisible_frame",
            "grid-rows-[60px_1fr]": !Settings.get([:ui, :compact], false, @__context__),
            "grid-rows-[40px_1fr]": Settings.get([:ui, :compact], false, @__context__)
            }>
            <Bonfire.UI.Common.PageHeaderLive
              page_title={@page_title}
              without_header={e(@without_header, false)}
              page_header_drawer={e(@page_header_drawer, false)}
              >
              <:right_action>
                <Surface.Components.Dynamic.Component
                  :if={current_user(@__context__) && @page_header_aside}
                  :for={{component, component_assigns} <- e(@page_header_aside, [])}
                  module={component}
                  {...component_assigns}
                />
              </:right_action>
            </Bonfire.UI.Common.PageHeaderLive>

            <div data-id="inner_content" class="mt-3 px-3 overflow-y-auto rounded-b-none md:overflow-y-visible md:px-0 full-height ">
              {#if @preview_module !=nil and is_atom(@preview_module)}
                <Surface.Components.Dynamic.Component
                  module={@preview_module}
                  {...assigns}
                />
              {/if}
              <div x-show={if @preview_module, do: "false", else: "true"}>
                {@inner_content}
              </div>
            </div>

          </div>
          <Bonfire.UI.Common.HeaderUserLive
            :if={current_user(@__context__)}
            page={@page}
          />
        </div>
        <div
          class={
            "items-start sticky z-[100] top-3  grid-flow-row gap-3 overflow-x-hidden overflow-y-auto auto-rows-min widget hidden tablet-lg:grid ",
            "!gap-5": !Settings.get([:ui, :compact], false, @__context__),
          }>
          <!-- <div
            :if={module_enabled?(Bonfire.Search.Web.FormLive) && current_user(@__context__)}
            class="sticky top-0 z-20">
            <Surface.Components.Dynamic.Component
              module={Bonfire.Search.Web.FormLive}
              search_limit={5}
            />
          </div> -->
          <Surface.Components.Dynamic.Component
            :if={current_user(@__context__)}
            :for={{component, component_assigns} <- @sidebar_widgets[:users][:secondary] || [
              {Bonfire.UI.Social.WidgetTagsLive, []},
              {Bonfire.UI.Common.WidgetFeedbackLive, []}
            ]}
            module={component}
            {...component_assigns}
          />

          <Surface.Components.Dynamic.Component
            :if={!current_user(@__context__)}
            :for={{component, component_assigns} <- @sidebar_widgets[:guests][:secondary] || [
                {Bonfire.UI.Social.WidgetTagsLive, []}
            ]}
            module={component}
            {...component_assigns}
          />
        </div>

        <Bonfire.UI.Common.MobileSmartInputButtonLive
          smart_input_prompt={@smart_input_prompt}
        />
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
