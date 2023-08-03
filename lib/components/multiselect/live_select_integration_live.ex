defmodule Bonfire.UI.Common.LiveSelectIntegrationLive do
  use Bonfire.UI.Common.Web, :function_component

  def live_select(assigns) do
    # field={@form[@form_input_name]}

    ~H"""
    <LiveSelect.live_select
      form={@form}
      field={@field}
      mode={@mode}
      phx-target={@event_target}
      options={@options}
      value={Enums.filter_empty(@value, nil) |> debug("selected_value")}
      allow_clear={@mode == :tags}
      update_min_len={@update_min_len || 1}
      debounce={0}
      placeholder={@placeholder}
      disabled={@disabled}
      style={:daisyui}
      text_input_extra_class={@text_input_class}
      container_extra_class="flex flex-col w-full "
      option_extra_class="rounded-box px-4 py-2"
      dropdown_class="cursor-pointer absolute top-12 p-2 z-50 dropdown-content menu shadow w-full bg-base-100 shadow-lg text-base-content rounded"
      tags_container_extra_class="order-last"
      tag_extra_class="badge-lg"
    />
    """
  end
end
