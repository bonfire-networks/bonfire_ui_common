defmodule Bonfire.UI.Common.ExtensionDiffLive do
  use Bonfire.UI.Common.Web, :live_view

  alias Bonfire.UI.Common.ExtensionDiffLive
  import Bonfire.Common.Extensions.Diff
  import Untangle

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(params, session, socket) do
    # necessary to avoid running it twice (and interupting an already-running diffing)
    case connected?(socket) do
      true ->
        mounted_connected(params, session, socket)

      false ->
        {:ok,
         assign(
           socket,
           page_title: "Loading...",
           without_widgets: true,
           diffs: [],
           msg: "Loading..."
         )}
    end
  end

  defp mounted_connected(params, _session, socket) do
    {msg, diffs} =
      with {:ok, msg, patches} <- generate_diff(params["ref"], params["local"]) do
        {msg, patches}
      else
        {:error, error} ->
          error(error)
          {error, []}

        error ->
          error(error)
          {l("There was an unknown error."), []}
      end

    # TODO: handle errors
    {:ok,
     assign(
       socket,
       page_title: "Extension",
       without_widgets: true,
       diffs: diffs,
       msg: msg
     )}
  end

  def render_diff(patch) do
    # debug(patch)
    Phoenix.View.render_to_iodata(
      Bonfire.UI.Common.DiffRenderView,
      "diff_render_view.html",
      patch: patch
    )
  end

  def render_diff_stream(package, repo_path, stream) do
    path = tmp_path("html-#{package}-")

    # TODO: figure out how to stream the data to LiveView as it becomes available, in which case use something like this instead of `render_diff`

    File.open!(path, [:write, :raw, :binary, :write_delay], fn file ->
      Enum.each(stream, fn
        {:ok, patch} ->
          IO.binwrite(file, render_diff(patch))

        error ->
          error(
            "Failed to parse diff stream of #{package} at #{repo_path} with: #{inspect(error)}"
          )

          throw({:error, :invalid_diff})
      end)
    end)

    # path

    File.read(path)
  end
end
