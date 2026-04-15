defmodule Bonfire.UI.Common.ComponentID do
  use Bonfire.UI.Common

  def new(component_module, object_id, parent_id \\ nil)

  def new(component_module, object_id, parent_id)
      when is_binary(object_id) or is_number(object_id) or
             (is_atom(object_id) and not is_nil(object_id)) do
    component_id = "#{deterministic_id(component_module, parent_id)}_for_#{object_id}"

    debug(component_id, "created stateful component with ID")

    save(component_module, object_id, component_id)

    component_id
  end

  def new(component_module, objects, parent_id)
      when is_list(objects) and objects != [] do
    ids = Enums.ids(objects)

    #  use first one just to identify component
    object_id = List.first(ids)

    component_id = "#{deterministic_id(component_module, parent_id)}_for_#{object_id}"

    debug(component_id, "created stateful component with ID")

    save(component_module, ids, component_id)

    component_id
  end

  def new(component_module, object, parent_id)
      when not is_nil(object) and (is_map(object) or is_tuple(object)) do
    case Enums.id(object) do
      id when is_binary(id) or is_number(id) ->
        debug(id, "creating stateful component using extracted ID")
        new(component_module, id, parent_id)

      nil ->
        error(
          object,
          "cannot save ComponentID to process, because expected an object with id for #{component_module} (with parent_id #{parent_id}) but got"
        )

        deterministic_id(component_module, parent_id)
    end
  end

  def new(component_module, other, parent_id) do
    error(
      other,
      "cannot save ComponentID to process, because expected an object id for #{component_module} (with parent_id #{parent_id}) but got"
    )

    deterministic_id(component_module, parent_id)
  end

  def deterministic_id(component_module, parent_id) do
    "#{component_module |> Types.module_to_str() |> String.replace(".", "-")}_#{parent_id |> Types.module_to_str() |> String.replace(".", "-")}"
  end

  def send_updates(component_module, object_id, assigns, pid \\ nil) do
    component_module = Types.maybe_to_atom(component_module)

    component_ids = component_ids(component_module, object_id)

    if component_ids == [] do
      warn(
        object_id,
        "ComponentID: no such components found #{component_module} for object(s), try as regular ID"
      )

      Bonfire.UI.Common.maybe_send_update(
        component_module,
        object_id,
        assigns,
        pid
      )
    else
      for component_id <- component_ids do
        debug(component_id, "ComponentID: try stateful component with ID")

        Bonfire.UI.Common.maybe_send_update(
          component_module,
          component_id,
          assigns,
          pid
        )
      end
    end
  end

  def send_assigns(component_module, id, set, socket, pid \\ nil) do
    send_updates(component_module, id, set, pid)

    {:noreply, assign_generic(socket, set)}
    # {:noreply, socket}
  end

  defp component_ids(component_module, object_ids) when is_list(object_ids) do
    Enum.map(object_ids, &component_ids(component_module, &1))
  end

  defp component_ids(component_module, object_id),
    do: dictionary_key_id(component_module, object_id) |> component_ids()

  defp component_ids(dictionary_key_id) when is_binary(dictionary_key_id) do
    Process.get(dictionary_key_id, [])
  end

  # |> debug()
  defp dictionary_key_id(component_module, object_id),
    do: "bcid_#{component_module}_#{object_id}"

  @doc """
  Alias an existing component_id under additional object_id(s) so that
  `send_updates/3` can find it by any of those keys. Use when a component
  is discoverable by multiple identities (e.g. a feed named preset *and*
  its underlying feed_id).
  """
  def register_alias(component_module, object_id_or_ids, component_id),
    do: save(component_module, object_id_or_ids, component_id)

  defp save(component_module, object_ids, component_id) when is_list(object_ids) do
    Enum.map(object_ids, &save(component_module, &1, component_id))
  end

  defp save(component_module, object_id, component_id) do
    dictionary_key_id = dictionary_key_id(component_module, object_id)
    existing = component_ids(dictionary_key_id)

    if component_id in existing do
      existing
    else
      Process.put(dictionary_key_id, existing ++ [component_id])
    end
  end
end
