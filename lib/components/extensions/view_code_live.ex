defmodule Bonfire.UI.Common.ViewCodeLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  import Bonfire.Common.Extensions.Diff
  import Untangle
  alias Bonfire.UI.Me.LivePlugs

  # NOTE: see for inspiration: https://github.com/hexpm/preview/blob/main/lib/preview_web/live/preview_live.ex

  def mount(params, session, socket) do
    live_plug(params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      Bonfire.UI.Common.LivePlugs.StaticChanged,
      Bonfire.UI.Common.LivePlugs.Csrf,
      Bonfire.UI.Common.LivePlugs.Locale,
      &mounted/3
    ])
  end

  defp mounted(params, session, socket) do
    {:ok,
     assign(
       socket,
       page_title: l("View Code"),
       module: nil,
       filename: nil,
       code: nil,
       lines: 0,
       line: 0,
       selected_line: 0,
       without_sidebar: false
     )}
  end

  def do_handle_params(%{"module" => module} = params, url, socket) when is_binary(module) do
    with true <- connected?(socket),
         module when not is_nil(module) <- Types.maybe_to_module(module),
         {:ok, filename, code} <- Extend.module_file_code(module) do
      {:noreply,
       socket
       |> assign(
         page_title: l("View Code") <> ": #{module}",
         module: module,
         filename: filename,
         code: code,
         selected_line:
           if(params["function"],
             do: Extend.function_line_number(code, maybe_to_atom(params["function"]))
           ) || 0,
         lines: String.split(code, "\n") |> length()
       )}
    else
      false ->
        {:noreply, socket}

      {:error, e} ->
        error(e)

      _ ->
        error(module, "Not a known module")
    end
  end

  def do_handle_event("highlight_line", %{"line-number" => line_number}, socket) do
    {line_number, _} = Integer.parse(line_number)

    {:noreply, assign(socket, :selected_line, line_number)}
  end

  def handle_params(params, uri, socket),
    do:
      Bonfire.UI.Common.LiveHandlers.handle_params(
        params,
        uri,
        socket,
        __MODULE__,
        &do_handle_params/3
      )

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

  def handle_event(
        action,
        attrs,
        socket
      ),
      do:
        Bonfire.UI.Common.LiveHandlers.handle_event(
          action,
          attrs,
          socket,
          __MODULE__
          # &do_handle_event/3
        )
end
