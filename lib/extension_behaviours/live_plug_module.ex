# SPDX-License-Identifier: AGPL-3.0-only
defmodule Bonfire.UI.Common.LivePlugModule do
  @moduledoc """
  Add modules to the app's web routes.

  usage: include this in your module: `@behaviour Bonfire.UI.Common.RoutesModule` and define a `__using__/1` macro with your routes in a `quote` block.
  """

  @behaviour Bonfire.Common.ExtensionBehaviour
  @optional_callbacks pipeline_name: 0

  @callback on_mount(name :: any(), params :: map(), session :: map(), socket :: map()) :: any
  @callback mount(params :: map(), session :: map(), socket :: map()) :: any
  @callback pipeline_name() :: atom

  require Bonfire.Common.Extend
  use Untangle

  def app_modules() do
    Bonfire.Common.ExtensionBehaviour.behaviour_app_modules(__MODULE__)
  end

  @spec modules() :: [atom]
  def modules() do
    Bonfire.Common.ExtensionBehaviour.behaviour_modules(__MODULE__)
  end

  def pipeline_names(modules \\ modules())

  def pipeline_names(modules) when is_list(modules) do
    Enum.map(modules, fn
      module ->
        case Bonfire.Common.Utils.maybe_apply(
               module,
               :pipeline_name,
               [],
               &pipeline_function_error/2
             ) do
          nil -> nil
          name -> {name, module}
        end
    end)
    |> Bonfire.Common.Enums.filter_empty([])
  end

  def pipeline_names(_), do: nil

  def pipeline_function_error(error, _args) do
    warn(
      error,
      "there's no name declared for this LivePlug: No function pipeline_name/0 2)"
    )

    nil
  end
end
