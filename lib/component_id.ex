defmodule Bonfire.UI.Common.ComponentID do
  use Bonfire.UI.Common

  def new(component_module, object_id, context)
      when is_binary(object_id) or is_number(object_id) do
    context =
      context ||
        (
          error(context, "expected a string or atom context for #{component_module}, but got")
          Pointers.ULID.generate()
        )

    component_id = "#{component_module}-via-#{context}-for-#{object_id}"

    debug("created stateful component with ID: #{component_id}")

    save(component_module, object_id, component_id)

    component_id
  end

  def new(component_module, object, context)
      when is_map(object) or is_list(object) or is_tuple(object) do
    new(component_module, Enums.id(object) || Pointers.ULID.generate(), context)
  end

  def new(component_module, other, context) do
    error(other, "expected an object id for #{component_module} with context #{context}, but got")
    Pointers.ULID.generate()
  end

  def send_updates(component_module, object_id, assigns) do
    component_module = Types.maybe_to_atom(component_module)

    debug("try to send_updates to #{component_module} for object id #{object_id}")

    for component_id <- ids(component_module, object_id) do
      debug("ComponentID: try stateful component with ID #{component_id}")

      Bonfire.UI.Common.maybe_send_update(
        component_module,
        component_id,
        assigns
      )
    end
  end

  def send_assigns(component_module, id, set, socket) do
    send_updates(component_module, id, set)

    {:noreply, assign_generic(socket, set)}
    # {:noreply, socket}
  end

  def ids(component_module, object_id),
    do: dictionary_key_id(component_module, object_id) |> ids()

  defp ids(dictionary_key_id) when is_binary(dictionary_key_id) do
    Process.get(dictionary_key_id, [])
  end

  # |> debug()
  defp dictionary_key_id(component_module, object_id),
    do: "cid_" <> to_string(component_module) <> "_" <> object_id

  defp save(component_module, object_id, component_id)
       when is_binary(object_id) and is_binary(component_id) do
    dictionary_key_id = dictionary_key_id(component_module, object_id)

    Process.put(
      dictionary_key_id,
      ids(dictionary_key_id) ++ [component_id]
      # |> debug()
    )
  end
end
