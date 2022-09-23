defmodule Bonfire.UI.Common.MultiselectLive.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler

  def handle_event(
        "select",
        %{"id" => id, "name" => name, "field" => field} = _attrs,
        socket
      )
      when is_binary(id) do
    field = maybe_to_atom(field)
    debug("selected for #{field} : #{name}")
    # TODO, handle cases when we want to select multiple
    {:noreply,
     assign_global(
       socket,
       {field, [{name, id}]}
     )}
  end

  def handle_event(
        "deselect",
        %{"id" => _deselected, "field" => field} = _attrs,
        socket
      ) do
    field = maybe_to_atom(field)

    {:noreply,
     assign_global(
       socket,
       [
         {field, []},
         {:preloaded_options, []}
       ]
     )}
  end
end
