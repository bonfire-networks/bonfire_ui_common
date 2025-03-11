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
  prop no_mobile_header, :boolean, default: false
  # prop force_live, :boolean, default: false

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

  def render(_, assigns) do
    prepare_assigns(assigns)
    |> render()
  end

  # @decorate time()
  # render_sface_or_native(prepare_assigns_fn: :prepare_assigns)

  @decorate time()
  def prepare_assigns(assigns) do
    # NOTE: we need to also set default props this way until we can convert LayoutView to use Surface
    assigns
    |> assign_new(:conn, fn -> nil end)
    |> assign_new(:__context__, fn -> %{} end)
    |> assign_new(:smart_input_opts, fn -> %{} end)
    |> assign_new(:to_boundaries, fn -> nil end)
    |> assign_new(:page_title, fn -> nil end)
    |> assign_new(:page, fn -> nil end)
    |> assign_new(:selected_tab, fn -> nil end)
    |> assign_new(:notification, fn -> nil end)
    |> assign_new(:no_header, fn -> false end)
    |> assign_new(:no_mobile_header, fn -> false end)
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
        ) || Bonfire.UI.Common.NavModule.nav(e(assigns[:__context__], :current_app, nil))
      ) || []
    )

    # |> assign_new(:hero, fn -> nil end)
    # |> assign_new(:custom_page_header, fn -> nil end)
    #     fn -> (not is_nil(current_user_id(assigns)) &&
    #         empty?(e(assigns, :sidebar_widgets, :users, :main, nil))) ||
    #        (not is_nil(current_user_id(assigns)) &&
    #           empty?(e(assigns, :sidebar_widgets, :guests, :main, nil)))
    # end)
  end
end
