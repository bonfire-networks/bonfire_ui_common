defmodule Bonfire.UI.Common.LayoutLive do
  @moduledoc """
  A simple Surface stateless component that sets default assigns needed for every view (eg. used in nav) and then shows some global components and the @inner_content
  """
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.UI.Common.PersistentLive

  def render(assigns) do
    # Note: since this is not a Surface component, we need to set default props this way
    # TODO: make this list of assigns config-driven so other extensions can add what they need?
    assigns =
      assigns
      # |> debug
      |> assign_new(:to_boundaries, fn -> nil end)
      |> assign_new(:hero, fn -> nil end)
      |> assign_new(:page_title, fn -> nil end)
      |> assign_new(:page, fn -> nil end)
      |> assign_new(:selected_tab, fn -> nil end)
      |> assign_new(:notification, fn -> nil end)
      |> assign_new(:page_header_aside, fn -> nil end)
      |> assign_new(:custom_page_header, fn -> nil end)
      |> assign_new(:inner_content, fn -> nil end)
      |> assign_new(:object_id, fn -> nil end)
      |> assign_new(:post_id, fn -> nil end)
      |> assign_new(:context_id, fn -> nil end)
      |> assign_new(:reply_to_id, fn -> nil end)
      |> assign_new(:create_object_type, fn -> nil end)
      |> assign_new(:nav_items, fn -> nil end)
      |> assign_new(:current_app, fn -> nil end)
      |> assign_new(:current_account, fn -> nil end)
      |> assign_new(:current_account_id, fn -> nil end)
      |> assign_new(:current_user, fn -> nil end)
      |> assign_new(:current_user_id, fn -> nil end)
      |> assign_new(:to_circles, fn -> [] end)
      |> assign_new(:smart_input_opts, fn ->
        [
          as: Bonfire.UI.Common.SmartInputLive.set_smart_input_as(assigns[:thread_mode], assigns)
        ]
      end)
      |> assign_new(:showing_within, fn -> nil end)
      |> assign_new(:without_sidebar, fn -> nil end)
      |> assign_new(:without_widgets, fn -> false end)
      |> assign_new(:sidebar_widgets, fn -> [] end)
      #     fn -> (not is_nil(current_user(assigns)) &&
      #         empty?(e(assigns, :sidebar_widgets, :users, :main, nil))) ||
      #        (!is_nil(current_user(assigns)) &&
      #           empty?(e(assigns, :sidebar_widgets, :guests, :main, nil)))
      # end)
      |> assign_new(:thread_mode, fn -> nil end)
      |> assign_new(:show_less_menu_items, fn -> false end)

    ~F"""
    <div
      data-id="bonfire_live"
      class=""
      x-data="{
          open_sidebar: false
        }"
    >
      <div
        :if={!@current_user or
          (@without_sidebar && empty?(e(assigns, :sidebar_widgets, :guests, :secondary, nil)))}
        class="py-3 border-b border-base-content/10 sticky top-0 bg-base-300 z-[99999999999999999999999999999]"
      >
        <div class="mx-auto max-w-[1260px]">
          <Bonfire.UI.Common.GuestHeaderLive
            current_user={@current_user}
            current_account={@current_account}
            page_title={@page_title}
            page={@page}
          />
        </div>
      </div>

      <div class={
        "w-full mx-auto grid max-w-[1260px] gap-0 md:gap-4 widget",
        "grid-cols-1 content-start": @without_sidebar && @without_widgets,
        "grid-cols-1": !@current_user,
        "grid-cols-1 md:grid-cols-1 content-start":
          @without_sidebar && empty?(e(assigns, :sidebar_widgets, :guests, :secondary, nil)),
        "grid-cols-1 md:grid-cols-[280px_1fr]": @current_user && @without_widgets && !@without_sidebar,
        "grid-cols-1 md:grid-cols-[280px_1fr] lg:grid-cols-[280px_1fr_320px] ":
          @current_user && !@without_sidebar && !@without_widgets
      }>
        <Bonfire.UI.Common.NavSidebarLive
          :if={@current_user && !@without_sidebar}
          page={@page}
          selected_tab={@selected_tab}
          nav_items={@nav_items}
          sidebar_widgets={@sidebar_widgets}
          showing_within={@showing_within}
          reply_to_id={@reply_to_id}
          context_id={@context_id}
          create_object_type={@create_object_type}
          thread_mode={@thread_mode}
          without_sidebar={@without_sidebar}
          to_boundaries={@to_boundaries}
          to_circles={@to_circles}
          smart_input_opts={@smart_input_opts}
        />

        <div
          data-id="main_section"
          class={
            "relative w-full max-w-[1280px]  gap-2 md:gap-0 z-[105] col-span-1 ",
            "!max-w-full": @without_widgets,
            "mx-auto order-last": @without_sidebar
          }
        >
          <div class={
            "h-full mt-0 grid tablet-lg:grid-cols-[1fr] desktop-lg:grid-cols-[1fr] grid-cols-1",
            "max-w-screen-lg gap-4 mx-auto": @without_widgets,
            "justify-between": !@without_widgets
          }>
            <div class="relative invisible_frame">
              <div class="pb-16 md:pb-0 md:overflow-y-visible">
                <Bonfire.UI.Common.PreviewContentLive id="preview_content" />
                <div
                  id="inner"
                  class={
                    "mt-[53px] md:mt-0 bg-base-100 min-h-[calc(var(--inner-window-height)_-_22px)] pb-[1px]":
                      @current_user && !@without_sidebar
                  }
                >
                  <div
                    :if={@current_user && !@without_sidebar}
                    class="sticky hidden md:block top-0  md:pt-3 bg-base-300 z-[999]"
                  >
                    <div class="flex flex-1 bg-base-100" :class="{'hidden': open_sidebar}">
                      <Dynamic.Component
                        module={elem(@custom_page_header || {Bonfire.UI.Common.PageHeaderLive, []}, 0)}
                        page_title={@page_title}
                        page={@page}
                        selected_tab={@selected_tab}
                        {...elem(@custom_page_header || {nil, []}, 1)}
                      >
                        <:right_action>
                          <Dynamic.Component
                            :if={@current_user && @page_header_aside}
                            :for={{component, component_assigns} <- e(@page_header_aside, [])}
                            module={component}
                            {...component_assigns}
                          />
                        </:right_action>
                      </Dynamic.Component>
                    </div>
                  </div>

                  {@inner_content}
                </div>
              </div>
            </div>
          </div>
        </div>
        <PersistentLive
          id={:persistent}
          :if={@current_user}
          sticky
          container={
            {:div, class: "order-first md:order-none md:static fixed left-0 right-0 top-0 z-[999]"}
          }
          session={%{
            "root_flash" => @flash,
            "context" => %{
              sticky: true,
              csrf_token: @csrf_token,
              # current_app: @current_app,
              # current_user: @current_user,
              # current_account: @current_account,
              current_user_id: @current_user_id,
              current_account_id: @current_account_id
            }
          }}
        />
      </div>

      <!-- <Bonfire.UI.Common.MobileSmartInputButtonLive
        :if={not is_nil(@current_user) and !@hide_smart_input}
        smart_input_opts={@smart_input_opts}
      /> -->
      <Bonfire.UI.Common.NavFooterMobileUserLive :if={not is_nil(@current_user)} page={@page} />

      <!--      {if module_enabled?(RauversionExtension.UI.TrackLive.Player, @current_user),
        do:
          live_render(@socket, RauversionExtension.UI.TrackLive.Player,
            id: "global-main-player",
            session: %{},
            sticky: true
          )} -->
    </div>

    <Bonfire.UI.Common.ReusableModalLive id="modal" />
    """
  end
end
