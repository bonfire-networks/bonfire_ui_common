defmodule Bonfire.UI.Common.Modularity.DeclareHelpers do
  # alias Bonfire.Common.Extend

  defmacro declare_widget(name, opts \\ []) do
    quote do
      @behaviour Bonfire.UI.Common.WidgetModule
      # @props_specs component_props(__MODULE__)

      def declared_widget do
        Enum.into(unquote(opts), %{
          name: unquote(name),
          module: __MODULE__,
          app: app(__MODULE__),
          type: component_type(__MODULE__)
          # data: @props_specs
        })
      end
    end
  end

  defmacro declare_nav_component(name, opts \\ []) do
    quote do
      @behaviour Bonfire.UI.Common.NavModule
      # @props_specs component_props(__MODULE__)

      def declared_nav do
        Enum.into(unquote(opts), %{
          name: unquote(name),
          module: __MODULE__,
          app: app(__MODULE__),
          type: component_type(__MODULE__)
          # data: @props_specs
        })
      end
    end
  end

  defmacro declare_nav_link(name, opts \\ [])

  defmacro declare_nav_link(name, opts) do
    quote do
      @behaviour Bonfire.UI.Common.NavModule

      def declared_nav do
        case unquote(name) do
          list when is_list(list) ->
            Enum.map(list, fn {name, opts} ->
              generate_link(name, __MODULE__, opts)
            end)

          name ->
            generate_link(name, __MODULE__, unquote(opts))
            # Enum.into(unquote(opts), %{
            #   name: unquote(name),
            #   module: __MODULE__,
            #   href: unquote(opts)[:href] || path(__MODULE__),
            #   type: :link
            # })
        end
      end
    end
  end

  defmacro declare_settings(type, name, opts \\ []) do
    do_declare_settings(type, name, opts)
  end

  defmacro declare_module_optional(name, opts \\ []) do
    caller = __CALLER__.module

    do_declare_settings(
      :toggle,
      name,
      opts
      |> Keyword.put_new(:keys, [caller, :modularity])
      |> Keyword.put_new(:disabled_value, :disabled)
      |> Keyword.put_new(:default_value, opts[:default])
    )
  end

  defp do_declare_settings(type, name, opts) do
    module =
      case type do
        :toggle -> Bonfire.UI.Common.SettingsToggleLive
        :toggles -> Bonfire.UI.Common.SettingsTogglesLive
        :radios -> Bonfire.UI.Common.SettingsRadiosLive
        :select -> Bonfire.UI.Common.SettingsSelectLive
        :input -> Bonfire.UI.Common.SettingsInputLive
        :textarea -> Bonfire.UI.Common.SettingsTextareaLive
        :number -> Bonfire.UI.Common.Settings.NumberLive
        custom_module -> custom_module
      end

    quote do
      @behaviour Bonfire.UI.Common.SettingsModule

      def declared_component do
        module = unquote(module)

        %{
          name: unquote(name),
          module: module,
          app: app(__MODULE__),
          type: component_type(module),
          scope: unquote(opts)[:scope] || :user,
          data: unquote(opts)
        }
      end
    end
  end

  defmacro declare_settings_component(name, opts \\ []) do
    quote do
      @behaviour Bonfire.UI.Common.SettingsModule
      # @props_specs component_props(__MODULE__)

      def declared_component do
        Enum.into(unquote(opts), %{
          name: unquote(name),
          module: __MODULE__,
          app: app(__MODULE__),
          type: component_type(__MODULE__),
          scope: unquote(opts)[:scope] || :user,
          # Added description field
          description: unquote(opts)[:description]
          # data: @props_specs
        })
      end
    end
  end

  defmacro declare_settings_nav_component(name, opts \\ []) do
    quote do
      @behaviour Bonfire.UI.Common.SettingsModule
      # @props_specs component_props(__MODULE__)

      def declared_settings_nav do
        Enum.into(unquote(opts), %{
          name: unquote(name),
          module: __MODULE__,
          app: app(__MODULE__),
          type: component_type(__MODULE__),
          scope: unquote(opts)[:scope] || :user
          # data: @props_specs
        })
      end
    end
  end

  defmacro declare_settings_nav_link(name, opts \\ [])

  defmacro declare_settings_nav_link(name, opts) do
    quote do
      @behaviour Bonfire.UI.Common.SettingsModule

      def declared_settings_nav do
        case unquote(name) do
          list when is_list(list) ->
            Enum.map(list, fn {name, opts} ->
              generate_link(name, __MODULE__, opts)
            end)

          name ->
            generate_link(name, __MODULE__, unquote(opts))
            # Enum.into(unquote(opts), %{
            #   name: unquote(name),
            #   module: __MODULE__,
            #   href: unquote(opts)[:href] || path(__MODULE__),
            #   type: :link
            # })
        end
      end
    end
  end

  def component_type(module),
    do:
      List.first(
        module.__info__(:attributes)[:component_type] ||
          module.__info__(:attributes)[:behaviour]
      )

  def component_props(module),
    do:
      Surface.API.get_props(module)
      |> Enum.map(&Map.drop(&1, [:opts_ast, :func, :line]))
end
