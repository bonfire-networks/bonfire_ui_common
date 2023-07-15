defmodule Bonfire.UI.Common.BasicMultiselectLive do
  use Bonfire.UI.Common.Web, :stateful_component
  alias Bonfire.UI.Common.MultiselectLive

  prop form, :any, default: :multi_select
  prop form_input_name, :any, required: true
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
  prop is_editable, :boolean, default: true
  prop implementation, :atom, default: nil

  prop class, :css_class,
    default:
      "flex items-center w-full px-2 bg-opacity-75 border rounded-md cursor-pointer border-base-content/30 bg-base-100 sm:text-sm"

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

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)
end
