defmodule Bonfire.UI.Common.LayoutLive do
  @moduledoc """
  A simple Surface stateless component that sets default assigns needed for every view (eg. used in nav) and then shows some global components and the @inner_content
  """
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.UI.Common.PersistentLive

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
  prop instance_settings, :any, default: :settings, required: false

  prop notification, :any, default: nil

  prop object_id, :string, default: nil
  prop post_id, :string, default: nil
  prop context_id, :string, default: nil
  prop reply_to_id, :string, default: nil
  prop showing_within, :any, default: nil

  prop inner_content, :any, default: nil
  prop nav_items, :any, default: nil
  prop without_widgets, :boolean, default: false
  prop without_sidebar, :boolean, default: nil
  prop sidebar_widgets, :list, default: []
  prop thread_mode, :atom, default: nil
  prop transparent_header, :boolean, default: false
  prop back, :boolean, default: false
  prop page_header_aside, :any, default: nil
  prop page_header_icon, :string, default: nil

  prop smart_input_opts, :any, default: nil
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
    # Note: since this is not a Surface component, we need to set default props this way
    # TODO: make this list of assigns config-driven so other extensions can add what they need?
    assigns =
      assigns
      # |> debug
      |> assign_new(:smart_input_opts, fn ->
        %{
          as: Bonfire.UI.Common.SmartInputLive.set_smart_input_as(assigns[:thread_mode], assigns)
        }
      end)

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
        instance_settings: e(assigns, :instance_settings, nil)
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
          page_title={e(assigns, :page_title, nil)}
          page={e(assigns, :page, nil)}
        />
      </div -->

      <div class={
        "w-full px-0 md:px-4 grid max-w-[1260px] gap-0 md:gap-4 widget xl:px-0 mx-auto",
        "!grid-cols-1 content-start": e(assigns, :without_sidebar, nil) && e(assigns, :without_widgets, nil),
        # "grid-cols-1 !max-w-full": !@current_user,
        "grid-cols-1 md:grid-cols-[280px_1fr] tablet-lg:grid-cols-[280px_1fr_320px]": !@current_user,
        "grid-cols-1 md:grid-cols-1 content-start !max-w-full":
          e(assigns, :without_sidebar, nil) && empty?(e(assigns, :sidebar_widgets, :guests, :secondary, nil)),
        "grid-cols-1 md:grid-cols-[280px_1fr]": @current_user && e(assigns, :without_widgets, nil) && !e(assigns, :without_sidebar, nil),
        "grid-cols-1 md:grid-cols-[280px_1fr] tablet-lg:grid-cols-[280px_1fr_320px] ":
          @current_user && !e(assigns, :without_sidebar, nil) && !e(assigns, :without_widgets, nil)
      }>
        <Bonfire.UI.Common.NavSidebarLive
          :if={!e(assigns, :without_sidebar, nil)}
          page={e(assigns, :page, nil)}
          selected_tab={e(assigns, :selected_tab, nil)}
          nav_items={e(assigns, :nav_items, nil)}
          sidebar_widgets={e(assigns, :sidebar_widgets, [])}
        />

        <div
          data-id="main_section"
          class={
            "relative w-full max-w-[1280px] gap-2 md:gap-0 z-[105] col-span-1 ",
            "!max-w-full": e(assigns, :without_widgets, nil),
            "!max-w-full": !@current_user,
            "mx-auto order-last": e(assigns, :without_sidebar, nil)
          }
        >
          <div class={
            "h-full mt-0 grid tablet-lg:grid-cols-[1fr] desktop-lg:grid-cols-[1fr] grid-cols-1",
            "max-w-screen-lg gap-4 mx-auto": e(assigns, :without_widgets, nil),
            "justify-between": !e(assigns, :without_widgets, nil)
          }>
            <div class="relative invisible_frame">
              <div class="pb-16 md:pb-0 md:overflow-y-visible">
                <Bonfire.UI.Common.PreviewContentLive id="preview_content" />
                <div
                  id="inner"
                  class={
                    "md:mt-0 bg-base-100 min-h-[calc(var(--inner-window-height)_-_22px)] pb-40 md:pb-[1px]":
                      !e(assigns, :without_sidebar, nil)
                  }
                >
                  <div
                    :if={!e(assigns, :without_sidebar, nil)}
                    class={
                      "sticky top-0  md:pt-3 bg-base-300 z-[999]",
                      "!bg-transparent md:!bg-base-300 !fixed left-0 right-0 md:!sticky": e(assigns, :transparent_header, false)
                    }
                  >
                    <div
                      x-data="{atTop: false}"
                      @scroll.window="atTop = (window.pageYOffset < 100) ? false: true"
                      class={
                        "flex flex-1 rounded-none md:rounded-t bg-base-100 transition-color duration-150 ease-in-out",
                        "bg-transparent md:bg-base-100": e(assigns, :transparent_header, false)
                      }
                      :class="{'!bg-base-100': atTop}"
                    >
                      <Dynamic.Component
                        module={Bonfire.UI.Common.PageHeaderLive}
                        page_title={e(assigns, :page_title, nil)}
                        page_header_icon={e(assigns, :page_header_icon, nil)}
                        back={e(assigns, :back, nil)}
                      >
                        <:right_action>
                          <Dynamic.Component
                            :if={e(assigns, :page_header_aside, nil)}
                            :for={{component, component_assigns} <- e(e(assigns, :page_header_aside, nil), [])}
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
          :if={!e(assigns, :without_sidebar, nil)}
          sticky
          container={
            {:div, class: "order-first md:order-none md:static fixed left-0 right-0 top-0 z-[999]"}
          }
          session={%{
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
