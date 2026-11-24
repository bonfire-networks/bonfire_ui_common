defmodule Bonfire.UI.Common.EmbedWidgetLive do
  @moduledoc "A widget declared embeddable, alone, for other sites to frame. Served by `Bonfire.UI.Common.EmbedWidgetController`."

  use Bonfire.UI.Common.Web,
      {:surface_live_view_child, layout: {Bonfire.UI.Common.LayoutView, :iframe}}

  # only the default plugs, which copy the controller's session `"params"` into `current_params`: no current user is loaded, so the widget shows what guests see
  on_mount {LivePlugs, []}

  def mount(raw_params, _session, socket) do
    params = socket.assigns[:current_params] || (is_map(raw_params) && raw_params) || %{}

    widget =
      case Bonfire.UI.Common.Widgets.embeddable(e(params, "id", nil)) do
        nil -> nil
        widget -> Map.update(widget, :data, [], &Keyword.merge(&1, embed_props(widget, params)))
      end

    {:ok,
     socket
     |> Bonfire.UI.Common.ThemeHelper.setup_embed(e(params, "theme", nil), true)
     |> assign(
       widget: widget,
       page_title: e(widget, :name, nil),
       max_width: max_width(e(params, "width", nil))
     )
     # links open on the instance, not inside the frame
     |> assign_global(:link_target, "_blank")}
  end

  # a widget that takes options from the embed's query (eg. the Spotlight's `?items=`) defines `embed_props/1`
  defp embed_props(%{module: module}, params) do
    if Code.ensure_loaded?(module) and function_exported?(module, :embed_props, 1),
      do: module.embed_props(params),
      else: []
  end

  @doc """
  The embed's width cap in pixels from `?width=`: `nil` for `full` (the frame's width), else a number of pixels, else 720.

      iex> Bonfire.UI.Common.EmbedWidgetLive.max_width("full")
      nil

      iex> Bonfire.UI.Common.EmbedWidgetLive.max_width("480")
      480

      iex> Bonfire.UI.Common.EmbedWidgetLive.max_width("wide")
      720
  """
  def max_width("full"), do: nil
  def max_width(width), do: Bonfire.Common.Types.maybe_to_pos_integer(width) || 720
end
