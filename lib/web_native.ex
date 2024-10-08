if Bonfire.Common.Extend.module_enabled?(LiveViewNative) do
  defmodule Bonfire.UI.Common.Web.Native do
    @moduledoc """
    The entrypoint for defining your native interfaces, such as components, render components, layouts, and live views.

    This is a highly modified version of the one generated by LiveViewNative (the original is kept around for reference in `web_native_original.exs`)
    """
    import Untangle
    alias Bonfire.UI.Common.Web

    def native_formats,
      do: [
        # :swiftui
      ]

    def native_opts,
      do: [
        formats: native_formats(),
        layouts: [
          swiftui: {Bonfire.UI.Common.LayoutView.SwiftUI, :app}
        ]
      ]

    @doc ~S'''
    Set up an existing LiveView module for use with LiveView Native

        defmodule MyAppWeb.HomeLive do
          use Bonfire.UI.Common.Web, :live_view # or :surface_live_view
          use_if_enabled Bonfire.UI.Common.Web.Native, :view
        end

    An `on_mount` callback will be injected that will negotiate
    the inbound connection content type. If it is a LiveView Native
    type the `render/1` will be delegated to the format-specific
    render component.
    '''
    def view(caller, opts \\ []) do
      opts =
        opts
        |> Keyword.put_new(:formats, [:swiftui])
        |> Keyword.put_new(:layouts,
          swiftui: {Bonfire.UI.Common.LayoutView.SwiftUI, :app}
        )
        |> Keyword.take([:formats, :layouts])

      quote do
        # first define the on_mount delegation
        use LiveViewNative.LiveView, unquote(opts)

        # then define a format-specific render component that uses `embed_templates` to render `*.swiftui.neex` file(s)
        defmodule SwiftUI do
          unquote(Web.live_view_helpers())

          unquote(stateless_component(caller, format: :swiftui, as: :render))

          @before_compile {Bonfire.UI.Common.Web.Native, :__live_mount_before_compile__}
        end
      end
    end

    @doc ~S'''
    Set up an existing module as a LiveView Native Component

        defmodule MyApp.MyComponent do
          use Bonfire.UI.Common.Web, :stateless_component
          use_if_enabled Bonfire.UI.Common.Web.Native, :stateless_component

          # then put your SwiftUI component code in `my_component.swiftui.neex` next to the module
        end

    LiveView Native Components are identical to Phoenix Components. Please
    refer to the `Phoenix.Component` documentation for more information.
    '''
    def stateless_component(caller, opts \\ []) do
      opts =
        opts
        |> Keyword.put_new(:format, :swiftui)
        |> Keyword.put_new(:as, :render_native)
        |> Keyword.take([:format, :as])

      quote do
        use LiveViewNative.Component, unquote(opts)

        unquote(helpers(opts[:format]))
        unquote(extra_helpers(opts[:format]))
        import LiveViewNative.Renderer

        unquote(
          "#{Bonfire.UI.Common.filename_for_module_template(caller.module)}.#{opts[:format]}"
        )
        |> LiveViewNative.Renderer.embed_templates(name: unquote(opts[:as]))
        |> IO.inspect(label: "embed_templates layout")
      end
    end

    def stateful_component(caller, opts \\ []) do
      # TODO: change when LVN supports live components
      stateless_component(caller, opts)
    end

    @doc ~S'''
    Set up a module as a LiveView Native Layout Component

        defmodule MyAppWeb.Layouts.SwiftUI do
          use_if_enabled Bonfire.UI.Common.Web.Native, [:layout, format: :swiftui]
        end
    '''
    def layout(caller, opts \\ []) do
      opts =
        opts
        |> Keyword.put_new(:format, :swiftui)
        |> Keyword.take([:format, :root])

      quote do
        defmodule SwiftUI do
          use LiveViewNative.Component, unquote(opts)

          unquote(Web.live_view_helpers())
          unquote(helpers(opts[:format]))
          unquote(extra_helpers(opts[:format]))
          import LiveViewNative.Component, only: [csrf_token: 1]
          import LiveViewNative.Renderer

          unquote("*.#{opts[:format]}")
          |> LiveViewNative.Renderer.embed_templates()
          |> IO.inspect(label: "embed_templates layout")
        end
      end
    end

    def core(caller, opts \\ []) do
      opts =
        opts
        |> Keyword.put_new(:format, :swiftui)
        |> Keyword.take([:format, :root])

      quote do
        use LiveViewNative.Component, unquote(opts)

        unquote(Web.live_view_helpers())
        unquote(helpers(opts[:format]))
      end
    end

    def extra_helpers(format) do
      plugin = LiveViewNative.fetch_plugin!(format)

      shared_component_module =
        Module.concat([Bonfire.UI.Common, SharedComponents, plugin.module_suffix])

      shared_component_quoted =
        try do
          Code.ensure_compiled!(shared_component_module)

          quote do
            import unquote(shared_component_module)
          end
        rescue
          _ -> nil
        end

      [
        shared_component_quoted
      ]
    end

    def helpers(format) do
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

      common_component_quoted =
        try do
          Code.ensure_compiled!(core_component_module)

          quote do
            import unquote(core_component_module)
            import Phoenix.Component, except: [link: 1]
          end
        rescue
          _ -> nil
        end

      [
        gettext_quoted,
        plugin_component_quoted,
        live_form_quoted,
        common_component_quoted,
        Bonfire.UI.Common.Web.verified_routes()
      ]
    end

    defmacro __live_update_before_compile__(env) do
      live_update_before_compile(env)
    end

    defp live_update_before_compile(env) do
      if Module.defines?(env.module, {:update, 2}) do
        quote do
          defoverridable update: 2

          def update(assigns, socket) do
            # FIXME?
            undead_update(socket, fn ->
              super(assigns, socket)
            end)
          end
        end
      end
    end

    defmacro __live_mount_before_compile__(env) do
      live_mount_before_compile(env)
    end

    defp live_mount_before_compile(env) do
      if Module.defines?(env.module, {:mount, 3}) do
        quote do
          defoverridable mount: 3

          def mount(params, session, socket) do
            # undead_mount(socket, fn ->
            super(
              params,
              session,
              socket
              |> assign(module_default_assigns(Bonfire.UI.Common.LayoutLive))
              # ^ because we need some default assigns app-wide
            )

            # end)
          end
        end
      end
    end

    @doc """
    When used, dispatch to the appropriate controller/view/etc.
    """
    defmacro __using__([which | opts]) when is_atom(which) do
      apply(__MODULE__, which, [__CALLER__, opts])
    end

    defmacro __using__(which) when is_atom(which) do
      apply(__MODULE__, which, [__CALLER__])
    end

    defmacro __using__({which, opts}) when is_atom(which) and is_list(opts) do
      apply(__MODULE__, which, [__CALLER__, opts])
    end
  end
end
