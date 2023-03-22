defmodule Bonfire.UI.Common.Web do
  @moduledoc false

  # alias Bonfire.Common.Utils

  # TODO: configurable
  def static_paths,
    do:
      ~w(public assets css fonts images js favicon.ico pwa pwabuilder-sw.js robots.txt cache_manifest.json source.tar.gz index.html)

  def verified_routes do
    if Code.ensure_loaded?(Bonfire.Web.Endpoint) and Code.ensure_loaded?(Bonfire.Web.Router) do
      # IO.warn("Enabling...")
      quote do
        #  use Phoenix.VerifiedRoutes,
        #    endpoint: Bonfire.Web.Endpoint,
        #    router: Bonfire.Web.Router,
        #    statics: Bonfire.UI.Common.Web.static_paths() ++ ["data"]

        # NOTE: the above is the official way to use VerifiedRoutes but `path` conflicts with our existing reverse routing helper
        Phoenix.VerifiedRoutes.__using__(__MODULE__,
          endpoint: Bonfire.Web.Endpoint,
          router: Bonfire.Web.Router,
          statics: Bonfire.UI.Common.Web.static_paths() ++ ["data"]
        )

        import Phoenix.VerifiedRoutes, except: [path: 2, path: 3]
      end
    else
      # IO.warn("Disabling...")
      quote do
        # fallback for when router and/or endpoint are not available
        defmacro sigil_p({:<<>>, _meta, _segments} = route, extra) do
          quote do
            Phoenix.VerifiedRoutes.unverified_path(%URI{}, nil, unquote(route), unquote(extra))
          end
        end
      end
    end
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
      alias Bonfire.UI.Common.Plugs.MustBeGuest
      alias Bonfire.UI.Common.Plugs.MustLogIn

      import Phoenix.LiveView.Controller

      unquote(live_view_basic_helpers())
    end
  end

  def view(opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:namespace, Bonfire.UI.Common.Web)
      |> Keyword.put_new(:root, "lib")
      |> maybe_put_layout(:app)

    quote do
      @moduledoc false

      use Phoenix.View, unquote(opts)
      # use Phoenix.Component # TODO: switch away from deprecated Phoenix.View?

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [view_module: 1, view_template: 1]

      # Include shared imports and aliases for views
      import Surface
      use Surface.View, unquote(opts)

      # to support Surface components in the app layout and in non-LiveViews ^ - FIXME: not compatible with phx 1.7? 

      unquote(live_view_helpers())
    end
  end

  defp maybe_put_layout(opts, file) do
    Keyword.put_new(
      opts,
      :layout,
      {Bonfire.Common.Config.get(
         :default_layout_module,
         Bonfire.UI.Common.LayoutView
       ), file}
    )
  end

  def layout_view(opts \\ []) do
    view(opts)
  end

  def live_view(opts \\ []) do
    # IO.inspect(live_view: opts)
    opts = maybe_put_layout(opts, :live)

    quote do
      @moduledoc false
      use Phoenix.LiveView, unquote(opts)

      unquote(live_view_helpers())

      alias Bonfire.UI.Common.LivePlugs

      # on_mount(PhoenixProfiler)
    end
  end

  def live_component(opts \\ []) do
    quote do
      @moduledoc false
      use Phoenix.LiveComponent, unquote(opts)

      unquote(live_view_helpers())
    end
  end

  def function_component(opts \\ []) do
    quote do
      @moduledoc false
      use Phoenix.Component, unquote(opts)

      unquote(live_view_helpers())
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

      alias Bonfire.Me.Settings
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
      use Phoenix.HTML

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

  if Bonfire.Common.Extend.module_exists?(Surface) do
    def surface_live_view(opts \\ []) do
      opts =
        maybe_put_layout(
          opts,
          :live
        )

      quote do
        @moduledoc false
        use Surface.LiveView, unquote(opts)

        unquote(surface_helpers())

        alias Bonfire.UI.Common.LivePlugs

        # on_mount(PhoenixProfiler)
      end
    end

    def stateful_component(opts \\ []) do
      quote do
        @moduledoc false
        use Surface.LiveComponent, unquote(opts)

        data current_account, :any, from_context: :current_account
        data current_user, :any, from_context: :current_user
        # data socket, :any

        unquote(surface_component_helpers())
      end
    end

    def stateless_component(opts \\ []) do
      quote do
        @moduledoc false
        use Surface.Component, unquote(opts)

        prop current_account, :any, from_context: :current_account
        prop current_user, :any, from_context: :current_user
        prop socket, :any

        unquote(surface_component_helpers())
      end
    end

    defp surface_component_helpers do
      quote do
        unquote(surface_helpers())
      end
    end

    defp surface_helpers do
      quote do
        unquote(live_view_basic_helpers())

        alias Surface.Components.Dynamic

        alias Surface.Components.Link
        alias Surface.Components.Link.Button
        alias Surface.Components.LivePatch
        alias Surface.Components.LiveRedirect

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
        alias Bonfire.UI.Common.Icon
        alias Bonfire.UI.Common.LinkPatchLive
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
end
