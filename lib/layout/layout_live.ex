defmodule Bonfire.UI.Common.LayoutLive do
  @moduledoc """
  A simple Surface stateless component that sets default assigns needed for every view (eg. used in nav) and then shows some global components and the @inner_content
  """
  use Bonfire.UI.Common.Web, :stateless_component

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

  prop inner_content, :any, default: nil
  prop nav_items, :any, default: nil
  prop without_widgets, :boolean, default: false
  prop without_sidebar, :boolean, default: nil
  prop sidebar_widgets, :list, default: []
  prop transparent_header, :boolean, default: false
  prop back, :boolean, default: false
  prop page_header_aside, :any, default: nil
  prop page_header_icon, :string, default: nil

  prop smart_input_opts, :any, default: %{}
  prop create_object_type, :any, default: nil
  prop to_circles, :list, default: []
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

  def render(assigns) do
    # Note:
    assigns =
      assigns
      |> assign_new(:smart_input_opts, fn -> %{} end)
      # NOTE: we need to also set default props this way until we can convert LayoutView to use Surface
      |> assign_new(:to_boundaries, fn -> nil end)
      |> assign_new(:page_title, fn -> nil end)
      |> assign_new(:page, fn -> nil end)
      |> assign_new(:selected_tab, fn -> nil end)
      |> assign_new(:notification, fn -> nil end)
      |> assign_new(:page_header_aside, fn -> nil end)
      |> assign_new(:page_header_icon, fn -> nil end)
      |> assign_new(:transparent_header, fn -> false end)
      |> assign_new(:inner_content, fn -> nil end)
      |> assign_new(:back, fn -> false end)
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
      |> assign_new(:instance_settings, fn -> nil end)
      |> assign_new(:to_circles, fn -> [] end)
      |> assign_new(:showing_within, fn -> nil end)
      |> assign_new(:without_sidebar, fn -> nil end)
      |> assign_new(:without_widgets, fn -> false end)
      |> assign_new(:sidebar_widgets, fn -> [] end)

    # |> assign_new(:hero, fn -> nil end)
    # |> assign_new(:custom_page_header, fn -> nil end)
    #     fn -> (not is_nil(current_user(assigns)) &&
    #         empty?(e(assigns, :sidebar_widgets, :users, :main, nil))) ||
    #        (!is_nil(current_user(assigns)) &&
    #           empty?(e(assigns, :sidebar_widgets, :guests, :main, nil)))
    # end)

    ~F"""
    <div
      data-id="bonfire_live"
      class="antialiased"
      style={maybe_custom_theme(
        current_user: @current_user,
        current_account: @current_account,
        instance_settings: @instance_settings
      )}
      x-data="{
          open_sidebar: false
        }"
    >
      <!-- div
        :if={!@current_user or
          (@without_sidebar && empty?(e(assigns, :sidebar_widgets, :guests, :secondary, nil)))}
        class="px-4 tablet-lg:px-0 mb-6 border-b border-base-content/10 sticky top-0 bg-base-300 z-[99999999999999999999999999999]"
      >
        <Bonfire.UI.Common.GuestHeaderLive
          current_user={@current_user}
          current_account={@current_account}
          page_title={@page_title}
          page={@page}
        />
      </div -->

      <div class={
        "w-full px-0 md:px-4 grid max-w-[1260px] gap-0 md:gap-4 widget xl:px-0 mx-auto",
        "!grid-cols-1 content-start": @without_sidebar && @without_widgets,
        # "grid-cols-1 !max-w-full": !@current_user,
        "grid-cols-1 md:grid-cols-[280px_1fr] tablet-lg:grid-cols-[280px_1fr_320px]": !@current_user,
        "grid-cols-1 md:grid-cols-1 content-start !max-w-full":
          @without_sidebar && empty?(e(assigns, :sidebar_widgets, :guests, :secondary, nil)),
        "grid-cols-1 md:grid-cols-[280px_1fr]": @current_user && @without_widgets && !@without_sidebar,
        "grid-cols-1 md:grid-cols-[280px_1fr] tablet-lg:grid-cols-[280px_1fr_320px] ":
          @current_user && !@without_sidebar && !@without_widgets
      }>
        <Bonfire.UI.Common.MobileMenuLive />
        <div
          :if={!@without_sidebar}
          data-id="nav_sidebar"
          class="fixed md:sticky self-start order-first w-full mt-3 top-3 z-[9999] md:block"
        >
          <div class="hidden md:flex items-center justify-between h-[50px] pb-4 mt-2">
            <div data-id="logo" class="items-center place-content-center">
              <Bonfire.UI.Common.LogoLinkLive with_name href="/" />
            </div>

            <Bonfire.UI.Common.UserMenuLive />
          </div>

          <Bonfire.UI.Common.PersistentLive
            id={:persistent}
            sticky
            :if={@current_user}
            session={%{
              "context" => %{
                sticky: true,
                csrf_token: @csrf_token,
                current_user_id: @current_user_id,
                current_account_id: @current_account_id
              }
            }}
          />
          <nav
            class="hidden w-full mt-4 md:flex gap-4 flex-col overflow-y-auto max-h-[calc(var(--inner-window-height)_-_130px)] min-h-[calc(var(--inner-window-height)_-_130px)]"
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
          class={
            "relative w-full max-w-[1280px] gap-2 md:gap-0 z-[99] col-span-1 ",
            "!max-w-full": @without_widgets,
            "!max-w-full": !@current_user,
            "mx-auto order-last": @without_sidebar
          }
        >
          <div class={
            "h-full mt-0 grid tablet-lg:grid-cols-[1fr] desktop-lg:grid-cols-[1fr] grid-cols-1",
            "max-w-screen-lg gap-4 mx-auto": @without_widgets,
            "justify-between": !@without_widgets
          }>
            <div class="relative invisible_frame">
              <div class="md:pb-0 md:overflow-y-visible">
                <Bonfire.UI.Common.PreviewContentLive id="preview_content" />
                <div
                  id="inner"
                  class={
                    "md:mt-0 bg-base-100 min-h-[calc(var(--inner-window-height)_-_16px)] pb-40 md:pb-[1px]":
                      !@without_sidebar
                  }
                >
                  <div
                    :if={!@without_sidebar}
                    class={
                      "sticky top-0  md:pt-3 bg-base-300 z-[999]",
                      "!bg-transparent md:!bg-base-300 !fixed left-0 right-0 md:!sticky": @transparent_header
                    }
                  >
                    <div
                      x-data="{atTop: false}"
                      @scroll.window="atTop = (window.pageYOffset < 100) ? false: true"
                      class={
                        "flex flex-1 rounded-none md:rounded-t bg-base-100 transition-color duration-150 ease-in-out",
                        "bg-transparent md:bg-base-100": @transparent_header
                      }
                      :class="{'!bg-base-100': atTop}"
                    >
                      <Dynamic.Component
                        module={Bonfire.UI.Common.PageHeaderLive}
                        page_title={@page_title}
                        page_header_icon={@page_header_icon}
                        back={@back}
                      >
                        <:right_action>
                          <Dynamic.Component
                            :if={@page_header_aside}
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
          <Bonfire.UI.Common.NavFooterMobileUserLive page={@page} />
        </div>
        <div
          :if={!@without_sidebar}
          class="hidden tablet-lg:block order-first md:order-none md:static z-[999]"
        >
          <div
            data-id="right_nav_and_widgets"
            class="order-last hidden tablet-lg:block tablet-lg:sticky  w-auto tablet-lg:top-3 mt-3 self-start z-[998] tablet-lg:w-full  overflow-y-visible grid-flow-row gap-3 auto-rows-min items-start"
          >
            {#if not is_nil(current_user_id(@__context__))}
              <div class="w-full">
                <Dynamic.Component
                  :if={module_enabled?(Bonfire.Search.Web.FormLive, @__context__)}
                  module={Bonfire.Search.Web.FormLive}
                  search_limit={5}
                />
              </div>
            {#else}
              <Bonfire.UI.Common.GuestActionsLive />
            {/if}
            <div
              data-id="secondary_sidebar_widgets"
              class="hidden mt-4 overflow-x-hidden overflow-y-auto tablet-lg:block max-h-[calc(var(--inner-window-height)_-_90px)] min-h-[calc(var(--inner-window-height)_-_90px)]"
            >
              <!-- FIXME: use the widget system instead (see below) -->

              <Dynamic.Component
                :if={module_enabled?(Bonfire.UI.ValueFlows.ProcessesListLive, @__context__) and
                  not is_nil(current_user(@__context__))}
                module={Bonfire.UI.ValueFlows.ProcessesListLive}
                process_url="/coordination/list"
                title={l("Favourite milestones")}
              />

              <div
                :if={(is_list(@sidebar_widgets[:users][:secondary]) and not is_nil(current_user(@__context__))) or
                  (is_list(@sidebar_widgets[:guests][:secondary]) and is_nil(current_user(@__context__)))}
                class="flex flex-col gap-4"
              >
                <Dynamic.Component
                  :if={not is_nil(current_user(@__context__))}
                  :for={{component, component_assigns} <-
                    List.wrap(
                      @sidebar_widgets[:users][:secondary] ||
                        [
                          {Bonfire.Tag.Web.WidgetTagsLive, []},
                          {Bonfire.UI.Common.WidgetFeedbackLive, []}
                        ]
                    )}
                  module={component}
                  {...component_assigns}
                />

                <Dynamic.Component
                  :if={is_nil(current_user(@__context__))}
                  :for={{component, component_assigns} <- List.wrap(@sidebar_widgets[:guests][:secondary] || [])}
                  module={component}
                  {...component_assigns}
                />
              </div>

              <div class="mt-4 text-xs text-base-content/70">
                <div class="text-xs text-base-content/70"><span class="font-semibold">{Config.get([:ui, :theme, :instance_name]) || instance_domain()}</span>:
                  <LiveRedirect class="text-xs link-hover link text-base-content/70" to="/about">{l("About")}</LiveRedirect> ·
                  <!-- <LiveRedirect class="text-xs link-hover link text-base-content/70">{l "Defaults"}</LiveRedirect> · -->
                  <LiveRedirect class="text-xs link-hover link text-base-content/70" to="/conduct">{l("Code of conduct")}</LiveRedirect> ·
                  <LiveRedirect class="text-xs link-hover link text-base-content/70" to="/privacy">{l("Privacy")}</LiveRedirect> ·
                  <LiveRedirect
                    :if={current_user(@__context__) || Config.get([Bonfire.UI.Me.UsersDirectoryLive, :show_to]) == :guests}
                    class="text-xs link-hover link text-base-content/70"
                    to="/users"
                  >{l("Users")}</LiveRedirect></div>
                <div class="mt-4">
                  <a
                    href="https://bonfirenetworks.org/"
                    class="text-xs font-semibold link link-hover text-base-content/70"
                  >
                    {Bonfire.Application.name()}
                  </a>
                  ·
                  <LiveRedirect
                    to={Bonfire.Application.repository()}
                    class="text-xs link link-hover text-base-content/70"
                  >
                    {Bonfire.Application.version()}
                    <span class="ml-1" x-data="{msg: 'JS'}">
                      <span x-text="msg">no JS</span>
                    </span>
                    <span class="ml-1">{Bonfire.Common.Localise.get_locale_id()}</span>
                  </LiveRedirect>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!--      {if module_enabled?(RauversionExtension.UI.TrackLive.Player, @current_user),
        do:
          live_render(@socket, RauversionExtension.UI.TrackLive.Player,
            id: "global-main-player",
            session: %{},
            sticky: true
          )} -->
    </div>
    <Bonfire.UI.Common.ReusableModalLive id="modal" />
    <Bonfire.UI.Common.NotificationLive id={:notification} root_flash={@flash} />
    """
  end
end
