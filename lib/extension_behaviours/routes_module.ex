# SPDX-License-Identifier: AGPL-3.0-only
defmodule Bonfire.UI.Common.RoutesModule do
  @moduledoc """
  Add modules to the app's web routes.

  usage: include this in your module: `@behaviour Bonfire.UI.Common.RoutesModule` and define a `__using__/1` macro with your routes in a `quote` block.
  """

  @behaviour Bonfire.Common.ExtensionBehaviour

  @callback declare_routes() :: any
  @optional_callbacks declare_routes: 0

  require Bonfire.Common.Extend

  def app_modules() do
    Bonfire.Common.ExtensionBehaviour.behaviour_app_modules(__MODULE__)
  end

  @spec modules() :: [atom]
  def modules() do
    Bonfire.Common.ExtensionBehaviour.behaviour_modules(__MODULE__)
  end

  defmacro use_modules do
    quote do
      unquote(
        Bonfire.Common.Extend.quoted_use_many_if_enabled(Bonfire.UI.Common.RoutesModule.modules())
        |> IO.inspect(label: "use_modules")
      )
    end
  end
end
