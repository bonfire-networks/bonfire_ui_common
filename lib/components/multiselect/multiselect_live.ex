defmodule Bonfire.UI.Common.MultiselectLive do
  use Bonfire.UI.Common.Web, :stateful_component
  use Bonfire.Common.Utils

  prop form_input_name, :string, required: true
  prop label, :string, default: nil
  prop preloaded_options, :any, default: nil
  prop selected_options, :any, default: nil
  prop show_search, :boolean, default: false
  prop focus_event, :string, required: false
  # prop autocomplete_event, :string, required: false
  prop pick_event, :string, required: false
  prop remove_event, :string, default: nil
  prop event_target, :any, default: nil
  prop context_id, :string, default: nil

  def selected_options(selected_options, field_name, context) do
    Enum.map(e(context, field_name, nil) || selected_options || [], &prepare_entry/1)
  end

  def preloaded_options(preloaded_options) do
    Enum.map(preloaded_options || [], &prepare_entry/1)
  end

  defp prepare_entry({name, id}) do
    {name, id}
  end

  defp prepare_entry(%{} = object) do
    {e(object, :name, nil) || e(object, :profile, :name, nil) ||
       e(object, :post_content, :name, "Unnamed"), ulid(object)}
  end

  defp prepare_entry(_) do
    nil
  end

  def handle_event(action, attrs, socket),
    do:
      Bonfire.UI.Common.LiveHandlers.handle_event(
        action,
        attrs,
        socket,
        __MODULE__
      )

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)
end
