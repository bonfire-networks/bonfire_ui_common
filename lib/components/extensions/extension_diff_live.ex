defmodule Bonfire.UI.Common.ExtensionDiffLive do
  use Bonfire.UI.Common.Web, :live_view

  import Bonfire.Common.Extensions.Diff
  import Untangle
  alias Bonfire.UI.Me.LivePlugs

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

  defp mounted_connected(params, _session, socket) do
    diffs = with {:ok, patches} <- generate_diff(params["local"]) do
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

  def render_diff(patch) do

    #IO.inspect(patch)
    Phoenix.View.render_to_iodata(Bonfire.UI.Common.DiffRenderView, "diff_render_view.html", patch: patch)

  end

  def render_diff_stream(package, repo_path, stream) do
    path = tmp_path("html-#{package}-")

    # TODO: figure out how to stream the data to LiveView as it becomes available, in which case use something like this instead of `render_diff`

    File.open!(path, [:write, :raw, :binary, :write_delay], fn file ->
      Enum.each(stream, fn
        {:ok, patch} ->

          html_patch =
            Phoenix.View.render_to_iodata(Bonfire.UI.Common.DiffRenderView, "diff_render_view.html", patch: patch)

          IO.binwrite(file, html_patch)

        error ->
          error("Failed to parse diff stream of #{package} at #{repo_path} with: #{inspect(error)}")
          throw({:error, :invalid_diff})
      end)
    end)

    # path

    File.read(path)

  end
end
