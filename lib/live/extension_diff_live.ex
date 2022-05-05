defmodule Bonfire.UI.Common.ExtensionDiffLive do
  use Bonfire.UI.Common.Web, :live_view
  import Bonfire.Common.Extensions.Diff
  import Where
  alias Bonfire.Me.Web.LivePlugs

  def mount(params, session, socket) do
    live_plug params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      Bonfire.UI.Common.LivePlugs.StaticChanged,
      Bonfire.UI.Common.LivePlugs.Csrf,
      Bonfire.UI.Common.LivePlugs.Locale,
      &mounted/3,
    ]
  end

  defp mounted(params, session, socket) do
    # necessary to avoid running it twice (and interupting an already-running diffing)
    case connected?(socket) do
      true -> mounted_connected(params, session, socket)
      false ->  {:ok,
        socket
        |> assign(
        page_title: "Loading...",
        diffs: [],
        without_sidebar: true
        )}
    end
  end

  defp mounted_connected(params, session, socket) do
    # diff = generate_diff(package, repo_path)
    diffs = with {:ok, patches} <- generate_diff(:bonfire_me, "./forks/bonfire_me") do
      patches
    else
      {:error, error} ->
        error(inspect(error))
        []
      error ->
        error(inspect(error))
        []
    end
    # TODO: handle errors
    {:ok,
        socket
        |> assign(
        page_title: "Extension",
        diffs: diffs,
        without_sidebar: true
        )}
  end

end
