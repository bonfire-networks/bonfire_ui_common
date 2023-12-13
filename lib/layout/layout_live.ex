defmodule Bonfire.UI.Common.LayoutLive do
  @moduledoc """
  A simple Surface stateless component that sets default assigns needed for every view (eg. used in nav) and then shows some global components and the @inner_content
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop conn, :any, default: nil
  prop page, :string, default: nil
  prop page_title, :string, default: nil
  prop selected_tab, :any, default: nil

  # prop current_account, :any, default: nil
  prop current_account_id, :any, default: nil
  # prop current_user, :any, default: nil
  prop current_user_id, :any, default: nil

  # prop current_app, :any, default: nil
  prop flash, :any, default: nil
  prop csrf_token, :any, default: nil
  prop instance_settings, :any, default: nil

  prop notification, :any, default: nil

  prop object_id, :string, default: nil
  prop post_id, :string, default: nil
  prop context_id, :string, default: nil
  prop reply_to_id, :string, default: nil
  prop showing_within, :atom, default: nil
  prop no_header, :boolean, default: false

  prop inner_content, :any, default: nil
  prop nav_items, :list, default: []
  prop without_secondary_widgets, :boolean, default: false
  prop without_sidebar, :boolean, default: nil
  prop sidebar_widgets, :list, default: []
  prop back, :boolean, default: false
  prop extra, :string, default: false
  prop page_header_aside, :any, default: nil
  prop page_header_icon, :string, default: nil

  prop smart_input_opts, :any, default: %{}
  prop create_object_type, :any, default: nil
  prop to_circles, :list, default: []
  prop exclude_circles, :list, default: []
  prop to_boundaries, :any, default: nil

  def maybe_custom_theme(context) do
    if Settings.get([:ui, :theme, :preferred], nil, context) == :custom do
      config =
        Enums.stringify_keys(Settings.get([:ui, :theme, :custom], %{}, context))
        |> debug("custom theme config")

      # Cache.maybe_apply_cached(&custom_theme_attr/1, [config])
      custom_theme_attr(config)
    else
      ""
    end
  end

  def custom_theme_attr(config), do: DaisyTheme.style_attr(config) |> debug("custom theme style")

  # def render(%{platform_id: :swiftui} = assigns) do
  #   # This renders a layout for the iOS/Mac app
  #   ~SWIFTUI"""
  #   <VStack>
  #     <%= @inner_content %>
  #   </VStack>
  #   """
  # end

  def render(assigns) do
    # NOTE: we need to also set default props this way until we can convert LayoutView to use Surface
    assigns =
      assigns
      |> assign_new(:smart_input_opts, fn -> %{} end)
      |> assign_new(:to_boundaries, fn -> nil end)
      |> assign_new(:page_title, fn -> nil end)
      |> assign_new(:page, fn -> nil end)
      |> assign_new(:selected_tab, fn -> nil end)
      |> assign_new(:notification, fn -> nil end)
      |> assign_new(:no_header, fn -> false end)
      |> assign_new(:page_header_aside, fn -> nil end)
      |> assign_new(:page_header_icon, fn -> nil end)
      |> assign_new(:inner_content, fn -> nil end)
      |> assign_new(:back, fn -> false end)
      |> assign_new(:extra, fn -> nil end)
      |> assign_new(:object_id, fn -> nil end)
      |> assign_new(:post_id, fn -> nil end)
      |> assign_new(:context_id, fn -> nil end)
      |> assign_new(:reply_to_id, fn -> nil end)
      |> assign_new(:create_object_type, fn -> nil end)
      |> assign_new(:current_app, fn -> nil end)
      |> assign_new(:current_account, fn -> nil end)
      |> assign_new(:current_account_id, fn -> nil end)
      |> assign_new(:current_user, fn -> nil end)
      |> assign_new(:current_user_id, fn -> nil end)
      |> assign_new(:instance_settings, fn -> nil end)
      |> assign_new(:to_circles, fn -> [] end)
      |> assign_new(:showing_within, fn -> nil end)
      |> assign_new(:without_sidebar, fn -> nil end)
      |> assign_new(:without_secondary_widgets, fn -> false end)
      |> assign_new(:sidebar_widgets, fn -> [] end)
      |> assign(
        :nav_items,
        e(
          assigns[:nav_items],
          Bonfire.Common.ExtensionModule.default_nav(
            e(assigns[:__context__], :current_extension, nil) ||
              e(assigns[:__context__], :current_app, nil)
          ) || Bonfire.Common.NavModule.nav(e(assigns[:__context__], :current_app, nil)) || []
        )
      )

    # |> assign_new(:hero, fn -> nil end)
    # |> assign_new(:custom_page_header, fn -> nil end)
    #     fn -> (not is_nil(current_user_id(assigns)) &&
    #         empty?(e(assigns, :sidebar_widgets, :users, :main, nil))) ||
    #        (not is_nil(current_user_id(assigns)) &&
    #           empty?(e(assigns, :sidebar_widgets, :guests, :main, nil)))
    # end)
    debug("Rendering layout")

    ~F"""
    <div
      data-id="bonfire_live"
      class="antialiased"
      data-theme={if Settings.get(
           [:ui, :theme, :preferred],
           :system,
           assigns[:__context__] || assigns[:current_user] || @conn
         ) == :light,
         do:
           Settings.get(
             [:ui, :theme, :instance_theme_light],
             "light",
             assigns[:__context__] || assigns[:current_user] || @conn
           ),
         else:
           Settings.get(
             [:ui, :theme, :instance_theme],
             "bonfire",
             assigns[:__context__] || assigns[:current_user] || @conn
           )}
      x-data="{
        open_sidebar: false
      }"
      style={maybe_custom_theme(
        current_user: current_user(@__context__),
        current_account: current_account(@__context__),
        instance_settings: @instance_settings
      )}
    >
      {!-- div
        :if={!@current_user_id or
          (@without_sidebar && empty?(e(assigns, :sidebar_widgets, :guests, :secondary, nil)))}
        class="px-4 lg:px-0 mb-6 border-b border-base-content/20 sticky top-0 bg-base-300 z-[99999999999999999999999999999]"
      >
        <Bonfire.UI.Common.GuestHeaderLive
          current_user={current_user(@__context__)}
          current_account={current_account(@__context__)}
          page_title={@page_title}
          page={@page}
        />
      </div --}

      <div
        data-id="layout"
        data-single-column={@without_sidebar}
        class="w-full px-0 md:px-4 grid max-w-[600px] md:max-w-[680px] lg:max-w-[1040px] tablet-lg:max-w-[1200px] gap-0 md:gap-4 widget xl:px-0 mx-auto grid-cols-1 md:grid-cols-[60px_1fr] lg:grid-cols-[60px_1fr_320px] tablet-lg:grid-cols-[250px_1fr_320px]"
      >
        <Bonfire.UI.Common.MobileMenuLive
          :if={@current_user_id}
          page={@page}
          selected_tab={@selected_tab}
          nav_items={@nav_items}
        />
        <div
          :if={!@without_sidebar}
          data-id="nav_sidebar"
          class="fixed md:sticky self-start order-first w-full mt-4 top-4 z-[9999] md:block"
        >
          <div class="hidden md:flex items-center justify-end tablet-lg:justify-between h-[50px]">
            <div data-id="logo" class="items-center ml-1 place-content-center">
              <Bonfire.UI.Common.LogoLinkLive with_name href="/" />
            </div>
          </div>

          <Bonfire.UI.Common.PersistentLive
            id={:persistent}
            sticky
            :if={@current_user_id}
            session={%{
              "context" => %{
                sticky: true,
                csrf_token: @csrf_token,
                # csrf_socket_token: @__context__[:csrf_socket_token],
                current_user_id: @current_user_id,
                current_account_id: @current_account_id
              }
            }}
          />
          <nav
            class="hidden mt-4 w-full md:flex gap-4 flex-col pb-1 max-h-[calc(var(--inner-window-height)_-_156px)] min-h-[calc(var(--inner-window-height)_-_156px)]"
            role="navigation"
            aria-label={l("Extension navigation")}
          >
            <Bonfire.UI.Common.NavSidebarLive
              :if={!@without_sidebar}
              page={@page}
              selected_tab={@selected_tab}
              nav_items={@nav_items}
              sidebar_widgets={@sidebar_widgets}
            />
          </nav>
        </div>
        <div
          data-id="main_section"
          data-single-column={@without_sidebar}
          class="relative w-full sm:min-w-[600px] gap-2 md:gap-0 z-[99] col-span-1"
        >
          <div class="justify-between h-full mt-0">
            <div class="relative invisible_frame">
              <div class="md:pb-0 md:overflow-y-visible">
                <Bonfire.UI.Common.PreviewContentLive id="preview_content" />
                <div
                  id="inner"
                  class="md:mt-0 flex flex-col md:border-l md:border-r border-base-content/20 min-h-[calc(var(--inner-window-height))] pb-40 md:pb-[1px]"
                >
                  <div :if={!@without_sidebar && !@no_header} class="sticky top-0 z-[999]">
                    <div class="flex flex-1 backdrop-blur-sm rounded-none md:rounded-t bg-base-100/70 transition-color duration-150 ease-in-out">
                      <Dynamic.Component
                        module={Bonfire.UI.Common.PageHeaderLive}
                        page={@page}
                        page_title={@page_title}
                        page_header_icon={@page_header_icon}
                        back={@back}
                        extra={@extra}
                      >
                        <:right_action>
                          <Dynamic.Component
                            :if={@page_header_aside}
                            :for={{component, component_assigns} <- e(@page_header_aside, [])}
                            module={component}
                            {...component_assigns || []}
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
          <Bonfire.UI.Common.NavFooterMobileUserLive page={@page} />
        </div>
        <div
          :if={!@without_secondary_widgets}
          class="hidden lg:block order-first md:order-none md:static z-[999]"
        >
          <div
            data-id="right_nav_and_widgets"
            class="order-last hidden lg:block lg:sticky  w-auto lg:top-3 mt-3 self-start z-[998] lg:w-full  overflow-y-visible grid-flow-row gap-3 auto-rows-min items-start"
          >
            {#if not is_nil(@current_user_id)}
              <div class="w-full mb-4">
                <Dynamic.Component
                  :if={module_enabled?(Bonfire.Search.Web.FormLive, @__context__)}
                  module={Bonfire.Search.Web.FormLive}
                  search_limit={5}
                />
              </div>
            {#else}
              <Bonfire.UI.Common.GuestActionsLive page={@page} />
            {/if}
            <div
              data-id="secondary_sidebar_widgets"
              class="hidden overflow-x-hidden overflow-y-auto lg:block max-h-[calc(var(--inner-window-height)_-_90px)] min-h-[calc(var(--inner-window-height)_-_90px)]"
            >
              {!-- FIXME: use the widget system instead (see below) --}

              <Dynamic.Component
                :if={module_enabled?(Bonfire.UI.ValueFlows.ProcessesListLive, @__context__) and
                  not is_nil(@current_user_id)}
                module={Bonfire.UI.ValueFlows.ProcessesListLive}
                process_url="/coordination/list"
                title={l("Favourite milestones")}
              />

              <Bonfire.UI.Common.SidebarWidgetsLive
                widgets={@sidebar_widgets}
                key={:secondary}
                page={@page}
                selected_tab={@selected_tab}
              />

              <div class="mt-4 text-xs text-base-content/70">
                <div class="flex flex-col gap-2 mb-4">
                  <!-- img
                    src={Config.get([:ui, :theme, :instance_image])}
                    class="h-[180px] object-cover w-full rounded"
                  / -->
                  <div class="prose prose-sm !text-xs">{Config.get([:ui, :theme, :instance_description])}</div>
                </div>

                <Bonfire.UI.Common.ImpressumLive />
              </div>
            </div>
          </div>
        </div>
      </div>

      {!--
      {if module_enabled?(RauversionExtension.UI.TrackLive.Player, current_user(@__context__)),
        do:
          live_render(@socket, RauversionExtension.UI.TrackLive.Player,
            id: "global-main-player",
            session: %{},
            sticky: true
          )} --}
    </div>
    <Bonfire.UI.Common.ReusableModalLive id="modal" />
    <Bonfire.UI.Common.NotificationLive id={:notification} root_flash={@flash} />
    """
  end
end
