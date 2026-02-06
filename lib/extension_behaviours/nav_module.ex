# SPDX-License-Identifier: AGPL-3.0-only
defmodule Bonfire.UI.Common.NavModule do
  @moduledoc """
  Add items to extensions' navigation sidebar.
  """
  @behaviour Bonfire.Common.ExtensionBehaviour
  use Bonfire.Common.Utils, only: []
  import Bonfire.Common.Enums, only: [filter_empty: 2]

  @doc "Declares a nav module, with links or nav components"
  @callback declared_nav() :: any

  @doc "Get navs for an extension"
  def nav(app) when is_atom(app) and not is_nil(app) do
    app_modules()[app]
    # |> debug
    |> nav()
  end

  def nav({app, modules}), do: {app, nav(modules)}

  def nav(modules) when is_list(modules) do
    Enum.map(modules, fn
      {module, props} ->
        ret = Utils.maybe_apply(module, :declared_nav, [], &nav_function_error/2)
        if ret, do: Enum.into(ret, %{props: props, module: module})

      module ->
        ret = Utils.maybe_apply(module, :declared_nav, [], &nav_function_error/2)
        if ret, do: Enum.into(ret, %{module: module})
    end)
    |> filter_empty([])
  end

  def nav(_), do: nil

  @doc "Load all navs"
  def nav() do
    Enum.map(modules(), &nav/1)
  end

  def nav_function_error(error, _args) do
    warn(
      error,
      "NavModule - there's no nav module declared for this schema: 1) No function declared_nav/0 that returns this schema atom. 2)"
    )

    nil
  end

  def app_modules() do
    Bonfire.Common.ExtensionBehaviour.behaviour_app_modules(__MODULE__)
  end

  @spec modules() :: [atom]
  def modules() do
    Bonfire.Common.ExtensionBehaviour.behaviour_modules(__MODULE__)
  end

  def default_nav(%{default_nav: default_nav}) do
    nav(default_nav) || []
  end

  def default_nav(app) when is_atom(app) do
    nav(Bonfire.Common.ExtensionModule.extension(app)[:default_nav]) || []
  end

  def default_nav(apps) when is_list(apps) do
    Enum.flat_map(apps, &default_nav/1)
  end

  def default_nav(_) do
    []
  end

  def default_nav() do
    Bonfire.Common.Cache.maybe_apply_cached(
      &do_default_nav/0,
      [],
      expire: 120_000
    )
  end

  def do_default_nav() do
    default_nav_apps()
    |> default_nav()
  end

  defp default_nav_apps() do
    Config.get([:ui, :default_nav_extensions], [:bonfire_ui_common, :bonfire_ui_social])
  end
end
