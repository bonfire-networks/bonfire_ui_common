defmodule Bonfire.UI.Common.ViewCodeLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  # import Bonfire.Common.Extensions.Diff
  import Untangle

  # NOTE: see for inspiration: https://github.com/hexpm/preview/blob/main/lib/preview_web/live/preview_live.ex

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(_params, _session, socket) do
    {:ok,
     assign(
       socket,
       page_title: l("View Code"),
       module: nil,
       modules: [],
       filename: nil,
       back: true,
       docs: nil,
       code: nil,
       lines: 0,
       line: 0,
       selected_line: 0,
       without_sidebar: false,
       nav_items: []
     )}
  end

  def handle_params(%{"module" => app_or_module} = params, _url, socket)
      when is_binary(app_or_module) do
    with true <- connected?(socket),
         {:ok, data} <- load_code(params["from"] == "compiled", params["function"], app_or_module) do
      {:noreply,
       socket
       |> assign(data)}
    else
      false ->
        {:noreply, socket}

      e ->
        error(e)
        error(app_or_module, "Cannot load code of app or module")
    end
  end

  def load_code(from_beam? \\ false, function \\ nil, app_or_module) do
    module = Types.maybe_to_module(app_or_module)

    app =
      if module do
        Extend.application_for_module(module)
      else
        maybe_to_atom!(app_or_module)
      end

    modules =
      if app do
        Application.spec(app, :modules)
      end || []

    module =
      module ||
        app_or_module
        |> Recase.to_title()
        |> String.replace(" ", ".")
        |> String.replace(".Ui.", ".UI.")
        |> Types.maybe_to_module() || List.first(modules)

    if module || modules do
      do_load_code(from_beam?, maybe_to_atom!(function), module, modules, app)
    end
  end

  defp do_load_code(from_beam?, function, module, modules, app) do
    with {:ok, filename, code} <- Extend.module_file_code(module, from_beam: from_beam?) do
      name = Types.module_to_str(module)

      {:ok,
       %{
         page_title: l("View Code") <> ": #{name}",
         app: app,
         module: module,
         #  modules: Application.spec(Extend.application_for_module(module), :modules),
         filename: filename,
         docs: Bonfire.Common.Extend.fetch_docs_as_markdown(module),
         code: code,
         #  enable_formatter: !from_beam?,
         enable_formatter: true,
         selected_line:
           if(function,
             do: Extend.function_line_number(code, function, from_beam: from_beam?)
           ) || 0,
         lines: String.split(code, "\n") |> length(),
         # no right sidebar
         without_secondary_widgets: true,
         sidebar_widgets: [
           users: [
             main:
               Enum.map(modules, fn module ->
                 %{
                   name: String.trim_leading(Types.module_to_str(module), "Bonfire."),
                   href:
                     "/settings/extensions/code/#{module}#{if from_beam?, do: "?from=compiled"}",
                   link_class:
                     "flex items-center w-full rounded-md text-sm hover:bg-base-content/10",
                   type: :link,
                   icon: "fluent:code-text-20-filled"
                 }
               end)
               |> debug("widgetss")
           ]
         ]
       }}
    end
  end

  def handle_event("highlight_line", %{"line-number" => line_number}, socket) do
    {line_number, _} = Integer.parse(line_number)

    {:noreply, assign(socket, :selected_line, line_number)}
  end
end
