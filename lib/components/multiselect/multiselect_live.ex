defmodule Bonfire.UI.Common.MultiselectLive do
  use Bonfire.UI.Common.Web, :stateless_component
  use Bonfire.Common.Utils

  @doc """
  A multiselect component that can use either LiveSelect or BasicMultiselect implementations.

  ## Props
    * `form` - The form to attach the multiselect to
    * `form_input_name` - The name of the form input field
    * `field` - The field name in the form
    * `label` - Label text for the input
    * `preloaded_options` - List of initial options
    * `selected_options` - List of initially selected options
    * `show_search` - Whether to show search functionality
    * `focus_event` - Event to trigger on focus
    * `pick_event` - Event to trigger when an option is picked
    * `remove_event` - Event to trigger when an option is removed
    * `event_target` - Target for events (usually @myself)
    * `context_id` - Context ID for the component
    * `is_editable` - Whether the component is editable
    * `implementation` - :live_select or :basic
    * `mode` - :single or :tags mode
    * `type` - Type of the multiselect
    * `max_selectable` - Maximum number of selectable items (0 for unlimited)
    * `update_min_len` - Minimum length of text before triggering updates
  """
  prop form, :any, default: :multi_select
  prop form_input_name, :any, required: true
  prop field, :any, default: nil
  prop label, :string, default: nil
  prop preloaded_options, :any, default: nil
  prop selected_options, :any, default: nil
  prop show_search, :boolean, default: false
  prop focus_event, :string, required: false
  prop pick_event, :string, required: false
  prop remove_event, :string, default: nil
  prop event_target, :any, default: nil
  prop context_id, :string, default: nil
  prop is_editable, :boolean, default: true
  prop implementation, :atom, default: nil
  prop mode, :atom, default: :single
  prop type, :atom, default: nil
  prop class, :string, default: "bg-transparent text-sm rounded h-10 w-full input liveselect"
  # 0 means unlimited
  prop max_selectable, :integer, default: 0
  prop update_min_len, :integer, default: 1

  prop text_input_class, :string,
    default: "bg-transparent text-sm rounded h-10 w-full input liveselect"

  def render(%{form: form_name} = assigns) when is_atom(form_name) do
    assigns
    |> assign(:form, to_form(%{}, as: form_name))
    |> render_sface()
  end

  def render(assigns) do
    assigns
    |> render_sface()
  end

  @doc """
  Prepares preloaded options for the multiselect.
  """
  def preloaded_options(preloaded_options) do
    Enum.map(preloaded_options || [], &prepare_entry/1)
  end

  @doc """
  Prepares selected options for the multiselect.
  """
  def selected_options(selected_options, field_name, context, preloaded_options) do
    do_selected_options(e(context, field_name, nil) || selected_options || [], preloaded_options)
  end

  defp do_selected_options(selected_options, preloaded_options) do
    Enum.map(List.wrap(selected_options), fn e -> prepare_entry(e, preloaded_options) end)
  end

  defp prepare_entry(entry, _preloaded_options \\ [])

  defp prepare_entry({id, name}, _preloaded_options) do
    {id, name}
  end

  defp prepare_entry(%{value: %{id: id}, label: name}, _preloaded_options) do
    {id, name}
  end

  defp prepare_entry(%{} = object, _preloaded_options) do
    {id(object),
     e(object, :name, nil) || e(object, :username, nil) || e(object, :profile, :name, nil) ||
       e(object, :character, :username, nil) ||
       e(object, :post_content, :name, "Unnamed")}
  end

  defp prepare_entry(entry, preloaded_options)
       when is_binary(entry) and is_list(preloaded_options) and preloaded_options != [] do
    preloaded_options(preloaded_options)
    |> Enum.filter(fn
      {_name, id} when id == entry -> true
      _ -> false
    end)
    |> List.first() ||
      {
        if(is_uid?(entry), do: l("Already selected"), else: entry),
        entry
      }
  end

  defp prepare_entry(_, _) do
    nil
  end
end
