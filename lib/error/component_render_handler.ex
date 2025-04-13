defmodule Bonfire.UI.Common.ComponentRenderHandler do
  @moduledoc """
  WIP: A module for handling component rendering with enhanced error reporting.

  Usage in your LiveView modules: `use Bonfire.UI.Common.ComponentRenderHandler` before your `use Phoenix.Component` or equivalent
  """
  defmacro __using__(_opts) do
    quote do
      # Override the render_component function to provide better error reporting
      import Phoenix.LiveView.TagEngine, except: [component: 3]

      # Custom component renderer that catches problematic cases
      def component(assigns, module, attrs) when is_atom(module) do
        component_name = module |> to_string() |> String.replace("Elixir.", "")

        try do
          result = Phoenix.Component.component(assigns, module, attrs)

          case result do
            %Phoenix.LiveView.Rendered{} ->
              result

            {:render, map} when is_map(map) ->
              # This captures your specific error case
              msg = """
              Component #{component_name} returned invalid value: {:render, map}
              Expected a %Phoenix.LiveView.Rendered{} struct
              This often happens when a child component has a bug
              Assign keys in map: #{inspect(Map.keys(map) |> Enum.take(10))}
              """

              require Logger
              Logger.error(msg)

              # You could construct a fallback rendered struct here,
              # but it might be better to fail loudly in dev/test
              raise RuntimeError,
                message:
                  "Component #{component_name} returned {:render, map} instead of a %Phoenix.LiveView.Rendered{} struct"

            other ->
              require Logger

              Logger.error(
                "Component #{component_name} returned unexpected value: #{inspect(other)}"
              )

              result
          end
        catch
          :exit, e ->
            require Logger
            Logger.error("Component rendering #{component_name} exited with error: #{inspect(e)}")
            reraise e, __STACKTRACE__

          e ->
            require Logger

            Logger.error("""
            Error rendering component #{component_name}:
            #{Exception.message(e)}
            #{Exception.format_stacktrace(__STACKTRACE__)}
            """)

            reraise e, __STACKTRACE__
        rescue
          e ->
            require Logger

            Logger.error("""
            Error rendering component #{component_name}:
            #{Exception.message(e)}
            #{Exception.format_stacktrace(__STACKTRACE__)}
            """)

            reraise e, __STACKTRACE__
        end
      end
    end
  end
end
