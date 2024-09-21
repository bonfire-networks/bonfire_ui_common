defmodule Bonfire.UI.Common.Web.Native do
  @moduledoc """
  The entrypoint for defining your native interfaces, such
  as components, render components, layouts, and live views.

  This can be used in your application as:

      use Bonfire.UI.Common.Web.Native, :live_view

  The definitions below will be executed for every
  component, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def native_formats,
    do: [
      :swiftui
    ]

  def native_opts,
    do: [
      formats: native_formats(),
      layouts: [
        swiftui: {Bonfire.UI.Common.LayoutLive.SwiftUI, :app}
      ]
    ]

  @doc ~S'''
  Set up an existing LiveView module for use with LiveView Native

      defmodule MyAppWeb.HomeLive do
        use Bonfire.UI.Common.Web, :live_view
        use Bonfire.UI.Common.Web.Native, :live_view
      end

  An `on_mount` callback will be injected that will negotiate
  the inbound connection content type. If it is a LiveView Native
  type the `render/1` will be delegated to the format-specific
  render component.
  '''
  def live_view(opts \\ []) do
    quote do
      use LiveViewNative.LiveView, unquote(native_opts())
      # formats: unquote(Bonfire.UI.Common.Web.native_formats())
      # # layouts: [
      # #   swiftui: {BonfireUmbrellaWeb.Layouts.SwiftUI, :app}
      # # ]

      # require LiveViewNative.Renderer
      # LiveViewNative.Renderer.embed_templates(IO.inspect("#{unquote(opts)[:template_name] || "*"}.*.neex", label: "embed_templates_*"))
      # |> IO.inspect(label: "embed_templates")

      # unquote(Bonfire.UI.Common.Web.verified_routes())
    end
  end

  @doc ~S'''
  Set up a module as a LiveView Native format-specific render component

      defmodule MyAppWeb.HomeLive.SwiftUI do
        use Bonfire.UI.Common.Web.Native, [:render_component, format: :swiftui]

        def render(assigns, _interface) do
          ~LVN"""
          <Text>Hello, world!</Text>
          """
        end
      end
  '''
  def render_component(opts) do
    opts =
      opts
      |> Keyword.take([:format])
      |> Keyword.put(:as, :render)

    quote do
      use LiveViewNative.Component, unquote(opts)

      unquote(helpers(opts[:format]))
    end
  end

  @doc ~S'''
  Set up a module as a LiveView Native Component

      defmodule MyAppWeb.Components.CustomSwiftUI do
        use Bonfire.UI.Common.Web.Native, [:component, format: :swiftui]

        attr :msg, :string, :required
        def home_text(assigns) do
          ~LVN"""
          <Text>@msg</Text>
          """
        end
      end

  LiveView Native Components are identical to Phoenix Components. Please
  refer to the `Phoenix.Component` documentation for more information.
  '''
  def component(opts) do
    opts = Keyword.take(opts, [:format, :root, :as])

    quote do
      use LiveViewNative.Component, unquote(opts)

      unquote(helpers(opts[:format]))
    end
  end

  @doc ~S'''
  Set up a module as a LiveView Native Layout Component

      defmodule MyAppWeb.Layouts.SwiftUI do
        use Bonfire.UI.Common.Web.Native, [:layout, format: :swiftui]

        embed_templates "layouts_swiftui/*"
      end
  '''
  def layout(opts) do
    opts = Keyword.take(opts, [:format, :root])

    quote do
      use LiveViewNative.Component, unquote(opts)

      import LiveViewNative.Component, only: [csrf_token: 1]

      unquote(helpers(opts[:format]))
    end
  end

  defp helpers(format) do
    gettext_quoted =
      quote do
        import Bonfire.Common.Localise.Gettext
      end

    plugin = LiveViewNative.fetch_plugin!(format)

    plugin_component_quoted =
      try do
        Code.ensure_compiled!(plugin.component)

        quote do
          import unquote(plugin.component)
        end
      rescue
        _ -> nil
      end

    live_form_quoted =
      quote do
        import LiveViewNative.LiveForm.Component
      end

    core_component_module =
      Module.concat([Bonfire.UI.Common, CoreComponents, plugin.module_suffix])

    core_component_quoted =
      try do
        Code.ensure_compiled!(core_component_module)

        quote do
          import unquote(core_component_module)
        end
      rescue
        _ -> nil
      end

    [
      gettext_quoted,
      plugin_component_quoted,
      live_form_quoted,
      core_component_quoted,
      Bonfire.UI.Common.Web.verified_routes()
    ]
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__([which | opts]) when is_atom(which) do
    apply(__MODULE__, which, [opts])
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
