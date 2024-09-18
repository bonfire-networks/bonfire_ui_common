defmodule Bonfire.UI.Common.Web do
  @moduledoc false

  # alias Bonfire.Common.Utils

  # TODO: configurable
  def static_paths,
    do:
      ~w(public assets css fonts images js favicon.ico pwa pwabuilder-sw.js robots.txt cache_manifest.json source.tar.gz index.html)

  def verified_routes do
    # TODO: fix this occasional compilation error during dev which gets in the way of using verified routes painlessly: `(UndefinedFunctionError) function Bonfire.Web.Router.__verify_route__/1 is undefined (module Bonfire.Web.Router is not available`
    # if Code.ensure_loaded?(Bonfire.Web.Endpoint) and Code.ensure_loaded?(Bonfire.Web.Router) do
    #   # IO.warn("Enabling...")
    #   quote do
    #     #  use Phoenix.VerifiedRoutes,
    #     #    endpoint: Bonfire.Web.Endpoint,
    #     #    router: Bonfire.Web.Router,
    #     #    statics: Bonfire.UI.Common.Web.static_paths() ++ ["data"]

    #     # NOTE: the above is the official way to use VerifiedRoutes but `path` conflicts with our existing reverse routing helper
    #     Phoenix.VerifiedRoutes.__using__(__MODULE__,
    #       endpoint: Bonfire.Web.Endpoint,
    #       router: Bonfire.Web.Router,
    #       statics: Bonfire.UI.Common.Web.static_paths() ++ ["data"]
    #     )

    #     import Phoenix.VerifiedRoutes, except: [path: 2, path: 3]
    #   end
    # else
    # IO.warn("Disabling...")
    quote do
      # fallback for when router and/or endpoint are not available
      defmacro sigil_p({:<<>>, _meta, _segments} = route, extra) do
        quote do
          Phoenix.VerifiedRoutes.unverified_path(%URI{}, nil, unquote(route), unquote(extra))
        end
      end
    end

    # end
  end

  def controller(opts \\ []) do
    opts =
      Keyword.put_new(
        opts,
        :namespace,
        Bonfire.Common.Config.get(:default_web_namespace, Bonfire.UI.Common)
      )

    quote do
      @moduledoc false
      use Phoenix.Controller, unquote(opts)
      import Plug.Conn
      import Phoenix.LiveView.Controller
      import Bonfire.UI.Common.Web, only: [render_inline: 2]

      alias Bonfire.UI.Common.Plugs.MustBeGuest
      alias Bonfire.UI.Common.Plugs.MustLogIn

      unquote(live_view_basic_helpers())
    end
  end

  def layout(opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:namespace, Bonfire.UI.Common.Web)
      |> Keyword.put_new(:root, "lib")

    # |> maybe_put_layout(:app)
    # |> IO.inspect(label: "layoutzzz")

    quote do
      @moduledoc false

      # use Phoenix.View, unquote(opts)
      #  TODO: switch away from deprecated Phoenix.View?
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [view_module: 1, view_template: 1, get_csrf_token: 0]

      # Include shared imports and aliases for views
      # import Surface

      unquote(live_view_helpers())
    end
  end

  def view(opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:namespace, Bonfire.UI.Common.Web)
      |> Keyword.put_new(:root, "lib")

    # |> maybe_put_layout(:app)

    quote do
      @moduledoc false

      use Phoenix.View, unquote(opts)
      # use Phoenix.Component # TODO: switch away from deprecated Phoenix.View?

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [view_module: 1, view_template: 1, get_csrf_token: 0]

      # Include shared imports and aliases for views
      import Surface
      use Surface.View, unquote(opts)

      # to support Surface components in the app layout and in non-LiveViews ^ - FIXME: not compatible with phx 1.7?

      unquote(live_view_helpers())
    end
  end

  # defp maybe_put_layout(opts, file) do
  #   Keyword.put_new(
  #     opts,
  #     :layout,
  #     {Bonfire.Common.Config.get(
  #        :default_layout_module,
  #        Bonfire.UI.Common.LayoutView
  #      ), file}
  #   )
  # end

  def layout_view(opts \\ []) do
    view(opts)
  end

  def live_view(opts \\ []) do
    # IO.inspect(live_view: opts)
    # maybe_put_layout(opts, :live) 
    opts =
      Keyword.put_new(
        opts,
        :layout,
        {Bonfire.UI.Common.LayoutLive, :live}
      )

    quote do
      @moduledoc false

      use Phoenix.LiveView, unquote(opts)

      @before_compile {Bonfire.UI.Common.Web, :__live_mount_before_compile__}
      @before_compile {Bonfire.UI.Common.Web, :__handle_params_before_compile__}
      @before_compile {Bonfire.UI.Common.Web, :__handle_info_before_compile__}
      @before_compile {Bonfire.UI.Common.Web, :__handle_event_before_compile__}
      @before_compile {Bonfire.UI.Common.Web, :__render_before_compile__}

      unquote(live_view_helpers())

      alias Bonfire.UI.Common.LivePlugs

      use_if_enabled(LiveViewNative.LiveView)

      # import Phoenix.Template, only: [embed_templates: 2]

      template_name = Bonfire.UI.Common.filename_for_module_template(__ENV__.module)

      embed_templates("#{template_name}.mjml", suffix: "_mjml")
      embed_templates("#{template_name}.text", suffix: "_text")

      # on_mount(PhoenixProfiler)
    end
  end

  def live_component(opts \\ []) do
    quote do
      @moduledoc false
      use Phoenix.LiveComponent, unquote(opts)

      @before_compile {Bonfire.UI.Common.Web, :__live_update_before_compile__}
      @before_compile {Bonfire.UI.Common.Web, :__handle_event_before_compile__}
      @before_compile {Bonfire.UI.Common.Web, :__render_before_compile__}

      unquote(live_view_helpers())

      use_if_enabled(LiveViewNative.LiveComponent)

      # import Phoenix.Template, only: [embed_templates: 2]

      template_name = Bonfire.UI.Common.filename_for_module_template(__ENV__.module)

      embed_templates("#{template_name}.mjml", suffix: "_mjml")
      embed_templates("#{template_name}.text", suffix: "_text")
      # unquote(source_inspector())
    end
  end

  def function_component(opts \\ []) do
    quote do
      @moduledoc false
      use Phoenix.Component, unquote(opts)

      unquote(live_view_helpers())

      use_if_enabled(LiveViewNative.Component)

      # import Phoenix.Template, only: [embed_templates: 2]

      template_name = Bonfire.UI.Common.filename_for_module_template(__ENV__.module)

      embed_templates("#{template_name}.mjml", suffix: "_mjml")
      embed_templates("#{template_name}.text", suffix: "_text")

      # unquote(source_inspector())
    end
  end

  def live_handler(_opts \\ []) do
    quote do
      import Phoenix.LiveView
      import Phoenix.Component
      alias Bonfire.UI.Common.ComponentID
      alias Phoenix.LiveView.JS

      unquote(view_helpers())
    end
  end

  # def source_inspector() do
  #   quote do
  #     require SourceInspector
  #     # mark the component as inspectable
  #     SourceInspector.debuggable()
  #   end
  # end

  def live_plug(_opts \\ []) do
    quote do
      unquote(common_helpers())

      import Phoenix.LiveView
      import Phoenix.Component
    end
  end

  def plug(_opts \\ []) do
    quote do
      unquote(common_helpers())

      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def router(opts \\ []) do
    quote do
      use Phoenix.Router, unquote(opts)
      unquote(common_helpers())

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router

      # unquote(Bonfire.Common.Extend.quoted_use_if_enabled(Thesis.Router))
    end
  end

  def channel(opts \\ []) do
    quote do
      use Phoenix.Channel, unquote(opts)
      import Untangle
    end
  end

  defp common_helpers do
    quote do
      use Bonfire.UI.Common

      # localisation
      require Bonfire.Common.Localise.Gettext
      import Bonfire.Common.Localise.Gettext.Helpers

      # deprecated: Phoenix's Helpers
      alias Bonfire.Web.Router.Helpers, as: Routes

      # use instead: Bonfire's voodoo routing, eg: `path(Bonfire.UI.Social.FeedsLive):
      import Bonfire.Common.URIs

      alias Bonfire.Common.Settings
      alias Bonfire.Common.Config
      import Config, only: [repo: 0]

      import Bonfire.Common.Extend

      import Untangle
      import Bonfire.UI.Common.ErrorHelpers
    end
  end

  defp basic_view_helpers do
    quote do
      unquote(common_helpers())

      # Use all HTML functionality (forms, tags, etc)
      import Phoenix.HTML
      import Phoenix.HTML.Form
      use PhoenixHTMLHelpers

      # unquote(Bonfire.Common.Extend.quoted_use_if_enabled(Thesis.View, Bonfire.PublisherThesis.ContentAreas))

      import Bonfire.Common.Modularity.DeclareHelpers

      unquote(verified_routes())
    end
  end

  defp view_helpers do
    quote do
      unquote(basic_view_helpers())

      # Import basic rendering functionality (render, render_layout, etc)
      # import Phoenix.View

      # unquote(Bonfire.Common.Extend.quoted_use_if_enabled(Thesis.View, Bonfire.PublisherThesis.ContentAreas))
    end
  end

  defp live_view_helpers do
    quote do
      unquote(live_view_basic_helpers())

      # Import component helpers
      import Phoenix.Component
    end
  end

  defp live_view_basic_helpers do
    quote do
      unquote(view_helpers())

      alias Bonfire.UI.Common.ComponentID

      alias Phoenix.LiveView.JS

      # Import Surface if any dep is using it
      Bonfire.Common.Extend.quoted_import_if_enabled(Surface)
    end
  end

  # defp __more_templates_before_compile__(env) do
  #   # import Phoenix.Template, only: [embed_templates: 2]

  #   template_name = Bonfire.UI.Common.template_name_for_module_template(env)

  #   embed_templates("#{template_name}.mjml", suffix: "_mjml")
  #   embed_templates("#{template_name}.text", suffix: "_text")
  # end

  # TODO: similar as the below for update_many and handle_progress

  defmacro __live_mount_before_compile__(env) do
    live_mount_before_compile(env)
  end

  defp live_mount_before_compile(env) do
    if Module.defines?(env.module, {:mount, 3}) do
      quote do
        defoverridable mount: 3

        def mount(params, session, socket) do
          undead_mount(socket, fn ->
            super(params, session, socket)
          end)
        end
      end
    end
  end

  defmacro __handle_params_before_compile__(env) do
    handle_params_before_compile(env)
  end

  defp handle_params_before_compile(env) do
    if Module.defines?(env.module, {:handle_params, 3}) do
      quote do
        defoverridable handle_params: 3

        def handle_params(params, uri, socket) do
          Bonfire.UI.Common.LiveHandlers.handle_params(params, uri, socket, __MODULE__, fn params,
                                                                                           uri,
                                                                                           socket ->
            super(params, uri, socket)
          end)
        end
      end
    else
      quote do
        def handle_params(params, uri, socket) do
          Bonfire.UI.Common.LiveHandlers.handle_params(params, uri, socket, __MODULE__)
        end
      end
    end
  end

  defmacro __handle_info_before_compile__(env) do
    handle_info_before_compile(env)
  end

  defp handle_info_before_compile(env) do
    if Module.defines?(env.module, {:handle_info, 2}) do
      quote do
        defoverridable handle_info: 2

        def handle_info(msg, socket) do
          Bonfire.UI.Common.LiveHandlers.handle_info(msg, socket, __MODULE__, fn msg, socket ->
            super(msg, socket)
          end)
        end
      end
    else
      quote do
        def handle_info(msg, socket) do
          Bonfire.UI.Common.LiveHandlers.handle_info(msg, socket, __MODULE__)
        end
      end
    end
  end

  defmacro __handle_event_before_compile__(env) do
    handle_event_before_compile(env)
  end

  defp handle_event_before_compile(env) do
    if Module.defines?(env.module, {:handle_event, 3}) do
      quote do
        defoverridable handle_event: 3

        def handle_event(event, params, socket) do
          Bonfire.UI.Common.LiveHandlers.handle_event(event, params, socket, __MODULE__, fn event,
                                                                                            params,
                                                                                            socket ->
            super(event, params, socket)
          end)
        end
      end
    else
      quote do
        def handle_event(event, params, socket) do
          Bonfire.UI.Common.LiveHandlers.handle_event(event, params, socket, __MODULE__)
        end
      end
    end
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

  defmacro __render_before_compile__(env) do
    render_before_compile(env)
  end

  defp render_before_compile(env) do
    if Module.defines?(env.module, {:render, 1}) do
      assigns = %{}

      quote do
        defoverridable render: 1

        def render(assigns) do
          undead_render(assigns, fn ->
            case assigns do
              %{__replace_render__with__: _} ->
                Bonfire.UI.Common.ErrorComponentLive.replace(assigns)

              %{__context__: %{current_params: %{"_email_format" => format}}} ->
                mod = unquote(env.module)

                case Bonfire.Common.Utils.maybe_apply(
                       Bonfire.Mailer.Render,
                       :render_templated,
                       [format, mod, assigns],
                       fallback_return: nil
                     )
                     |> IO.inspect(label: "render #{mod}") do
                  binary when is_binary(binary) and binary != "" ->
                    binary = if format == "text", do: "<pre>#{binary}</pre>", else: binary

                    Bonfire.UI.Common.Empty.render(
                      Phoenix.Component.assign(assigns,
                        html_content: binary,
                        comment: "email mode"
                      )
                    )

                  # ~H"<%= raw binary %>"
                  _ ->
                    super(assigns)
                end

              _ ->
                super(assigns)
            end
          end)
        end
      end
    end
  end

  if Bonfire.Common.Extend.module_exists?(Surface) do
    def surface_live_view_child(opts \\ []) do
      opts =
        Keyword.put_new(
          opts,
          :layout,
          {Bonfire.UI.Common.LayoutLive, :live}
        )

      quote do
        @moduledoc false

        use Surface.LiveView, unquote(opts)

        @before_compile {Bonfire.UI.Common.Web, :__live_mount_before_compile__}
        @before_compile {Bonfire.UI.Common.Web, :__handle_info_before_compile__}
        @before_compile {Bonfire.UI.Common.Web, :__handle_event_before_compile__}
        @before_compile {Bonfire.UI.Common.Web, :__render_before_compile__}

        unquote(surface_helpers())

        use_if_enabled(LiveViewNative.LiveView)

        alias Bonfire.UI.Common.LivePlugs

        # on_mount(PhoenixProfiler)
      end
    end

    def surface_live_view(opts \\ []) do
      opts =
        Keyword.put_new(
          opts,
          :layout,
          {Bonfire.UI.Common.LayoutLive, :live}
        )

      quote do
        @moduledoc false

        use Surface.LiveView, unquote(opts)

        @before_compile {Bonfire.UI.Common.Web, :__live_mount_before_compile__}
        @before_compile {Bonfire.UI.Common.Web, :__handle_params_before_compile__}
        @before_compile {Bonfire.UI.Common.Web, :__handle_info_before_compile__}
        @before_compile {Bonfire.UI.Common.Web, :__handle_event_before_compile__}
        @before_compile {Bonfire.UI.Common.Web, :__render_before_compile__}

        unquote(surface_helpers())

        template_name =
          Bonfire.UI.Common.filename_for_module_template(__ENV__.module)

        embed_templates("#{template_name}.mjml", suffix: "_mjml")
        embed_templates("#{template_name}.text", suffix: "_text")

        use_if_enabled(LiveViewNative.LiveView)

        alias Bonfire.UI.Common.LivePlugs

        # on_mount(PhoenixProfiler)
      end
    end

    def stateful_component(opts \\ []) do
      quote do
        @moduledoc false

        use Surface.LiveComponent, unquote(opts)

        @before_compile {Bonfire.UI.Common.Web, :__live_update_before_compile__}
        @before_compile {Bonfire.UI.Common.Web, :__handle_event_before_compile__}
        @before_compile {Bonfire.UI.Common.Web, :__render_before_compile__}

        # data current_account, :any, from_context: :current_account
        # data current_user, :any, from_context: :current_user
        # data socket, :any

        unquote(surface_component_helpers())

        use_if_enabled(LiveViewNative.LiveComponent)

        template_name = Bonfire.UI.Common.filename_for_module_template(__ENV__.module)

        embed_templates("#{template_name}.mjml", suffix: "_mjml")
        embed_templates("#{template_name}.text", suffix: "_text")
      end
    end

    def stateless_component(opts \\ []) do
      quote do
        @moduledoc false

        @before_compile {Bonfire.UI.Common.Web, :__render_before_compile__}

        use Surface.Component, unquote(opts)

        # prop current_account, :any, from_context: :current_account
        # prop current_user, :any, from_context: :current_user
        prop socket, :any

        unquote(surface_component_helpers())

        use_if_enabled(LiveViewNative.Component)

        template_name = Bonfire.UI.Common.filename_for_module_template(__ENV__.module)

        embed_templates("#{template_name}.mjml", suffix: "_mjml")
        embed_templates("#{template_name}.text", suffix: "_text")
      end
    end

    def macro_component(opts \\ []) do
      quote do
        @moduledoc false
        alias Surface.MacroComponent
        alias Surface.AST
        use MacroComponent, unquote(opts)
        import Phoenix.Component

        prop socket, :any

        unquote(surface_component_helpers())
      end
    end

    defp surface_component_helpers do
      quote do
        unquote(surface_helpers())

        # require SourceInspector
        # import Bonfire.UI.Common.Testing.Inspector

        alias Bonfire.UI.Common.Web

        prop source_inspector_attrs, :map, default: %{}
      end
    end

    defp surface_helpers do
      quote do
        unquote(live_view_basic_helpers())

        # alias Surface.Components.Dynamic
        # alias Bonfire.UI.Common.Modular.StatelessComponent
        # alias Bonfire.UI.Common.Modular.StatefulComponent
        alias Surface.Components.Dynamic.Component, as: StatelessComponent
        alias Surface.Components.Dynamic.LiveComponent, as: StatefulComponent

        alias Surface.Components.Link
        alias Surface.Components.Link.Button
        # alias Surface.Components.LivePatch
        # alias Surface.Components.LiveRedirect

        alias Surface.Components.Form
        alias Surface.Components.Form.Field
        alias Surface.Components.Form.FieldContext
        alias Surface.Components.Form.Label
        alias Surface.Components.Form.ErrorTag
        alias Surface.Components.Form.Inputs
        alias Surface.Components.Form.HiddenInput
        alias Surface.Components.Form.HiddenInputs
        alias Surface.Components.Form.TextInput
        alias Surface.Components.Form.TextArea
        alias Surface.Components.Form.NumberInput
        alias Surface.Components.Form.RadioButton
        alias Surface.Components.Form.Select
        alias Surface.Components.Form.MultipleSelect
        alias Surface.Components.Form.OptionsForSelect
        alias Surface.Components.Form.DateTimeSelect
        alias Surface.Components.Form.TimeSelect
        alias Surface.Components.Form.Checkbox
        alias Surface.Components.Form.ColorInput
        alias Surface.Components.Form.DateInput
        alias Surface.Components.Form.TimeInput
        alias Surface.Components.Form.DateTimeLocalInput
        alias Surface.Components.Form.EmailInput
        alias Surface.Components.Form.PasswordInput
        alias Surface.Components.Form.RangeInput
        alias Surface.Components.Form.SearchInput
        alias Surface.Components.Form.TelephoneInput
        alias Surface.Components.Form.UrlInput
        alias Surface.Components.Form.FileInput
        alias Surface.Components.Form.TextArea

        alias Bonfire.UI.Common.LazyImage
        alias Bonfire.UI.Common.LinkLive
        alias Bonfire.UI.Common.LinkPatchLive
        alias Bonfire.UI.Common.C

        alias Iconify.Icon
        require Iconify.Icon
      end
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end

  defmacro __using__({which, opts}) when is_atom(which) and is_list(opts) do
    apply(__MODULE__, which, [opts])
  end

  @doc """
  Renders a HEEx template inline in a controller.

  ## Example

      use Bonfire.UI.Common.Web, :controller
      use Phoenix.Component
    
      def index(conn, _) do
        render_inline conn, ~H"<u><%= @current_user.name %></u>"
      end
  """
  defmacro render_inline(conn, template) do
    quote do
      %Plug.Conn{assigns: var!(assigns)} = conn = unquote(conn)
      html(conn, Phoenix.HTML.Safe.to_iodata(unquote(template)))
    end
  end

  defmacro maybe_native_plug do
    if Bonfire.Common.Extend.extension_enabled?(:live_view_native) do
      quote do
        plug LiveViewNative.SessionPlug
      end
    end
  end
end
