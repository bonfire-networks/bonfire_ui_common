defmodule Bonfire.UI.Common.LayoutLive do
  @moduledoc """
  A simple Phoenix function component that sets default assigns needed for every view (eg. used in nav) and then embeds some Surface stateful and stateless components (passing along inner_content to be shown in one of them)
  """
  use Bonfire.UI.Common.Web, :function_component

  def page(assigns) do

    # TODO: make this list of assigns config-driven so other extensions can add what they need
    assigns = assigns
    |> assign_new(:page_title, fn -> nil end)
    |> assign_new(:page, fn -> nil end)
    |> assign_new(:notification, fn -> nil end)
    |> assign_new(:page_header_aside, fn -> nil end)
    |> assign_new(:page_header_drawer, fn -> false end)
    |> assign_new(:inner_content, fn -> nil end)
    |> assign_new(:reply_to_id, fn -> nil end)
    |> assign_new(:thread_id, fn -> nil end)
    |> assign_new(:create_activity_type, fn -> nil end)
    |> assign_new(:to_boundaries, fn -> [] end)
    |> assign_new(:to_circles, fn -> [] end)
    |> assign_new(:smart_input_prompt, fn -> nil end)
    |> assign_new(:smart_input_text, fn -> nil end)
    |> assign_new(:showing_within, fn -> nil end)
    |> assign_new(:without_sidebar, fn -> false end)
    |> assign_new(:sidebar_widgets, fn -> [] end)
    |> assign_new(:hide_smart_input, fn -> false end)
    |> assign_new(:thread_mode,  fn -> nil end)
    |> assign_new(:show_less_menu_items, fn -> false end)
    # |> debug()

    ~H"""
    <div
      id="layout-live"
      x-data="{
        title_text: null,
        show_smart_input_modal: false,
        show_smart_input_fullscreen: false,
        show_smart_input_modal_fullscreen: false,
        maximize_smart_input_modal() {
          if (!this.show_smart_input_modal) {
            this.show_smart_input_modal = true;
            return this.show_smart_input_modal_fullscreen = true
          } else {
            return this.show_smart_input_modal_fullscreen = true
          }
        }
      }"
    >

      <%= Bonfire.UI.Common.NavLive.render(assigns) %>

    </div>

    <.live_component
      module={Bonfire.UI.Common.ReusableModalLive}
      id="modal"
    />

    <.live_component
      module={Bonfire.UI.Common.NotificationLive}
      id="notification"
      notification={@notification}
      __context__={@__context__}
      root_flash={@flash}
    />
    """
  end
end
