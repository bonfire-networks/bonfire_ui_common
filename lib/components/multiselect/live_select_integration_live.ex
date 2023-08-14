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
      value={Enums.filter_empty(@value, nil)}
      allow_clear={@mode == :tags}
      update_min_len={@update_min_len || 1}
      debounce={0}
      placeholder={@placeholder}
      disabled={@disabled}
      style={:daisyui}
      text_input_extra_class={@text_input_class}
      container_extra_class="flex flex-col w-full"
      option_extra_class="rounded-box px-4 py-2"
      tag_class="text-sm badge badge-outline badge-lg !border !border-base-content/30 gap-2 !h-[2rem]"
      dropdown_class="cursor-pointer absolute top-12 p-1 z-[999999999999] dropdown-content menu shadow w-full bg-base-100 shadow-lg text-base-content rounded"
      tags_container_class="flex flex-wrap gap-1 pt-2 order-last"
    >
      <:option :let={option}>
        <div class="flex gap-2 items-center">
          <%= if is_binary(option.value) do %>
            <p class="font-semibold text-base-content/70">
              <%= option.label %>
            </p>
          <% else %>
            <%= if Map.has_key?(debug(option).value, :icon) or Map.has_key?(option.value, "icon") do %>
              <div class="w-8 h-8">
                <img src={e(option.value, :icon, nil)} alt="" class="w-full h-full rounded-full" />
              </div>
            <% end %>
            <div class="">
              <p class="font-semibold">
                <%= e(option.value, :name, nil) || e(option.value, :profile, :name, nil) ||
                  e(option.value, :named, :name, nil) %>
              </p>
              <p class="font-light text-base-content/70">
                <%= e(option.value, :username, nil) || e(option.value, :character, :username, nil) %>
              </p>
            </div>
          <% end %>
        </div>
      </:option>

      <:tag :let={option}>
        <div class="flex items-center gap-2">
          <%= if is_binary(option.value) do %>
            <p class="font-semibold text-sm">
              <%= option.label %>
            </p>
          <% else %>
            <%= if Map.has_key?(debug(option.value), :icon) or Map.has_key?(option.value, "icon") do %>
              <div class="w-6 h-6">
                <img src={e(option.value, :icon, nil)} alt="" class="w-full h-full rounded-full" />
              </div>
            <% end %>
            <div class="text-sm">
              <p class="font-semibold">
                <%= e(option.value, :name, nil) || e(option.value, :profile, :name, nil) ||
                  e(option.value, :named, :name, nil) %>
              </p>
              <p class="font-light text-base-content/70">
                <%= e(option.value, :username, nil) || e(option.value, :character, :username, nil) %>
              </p>
            </div>
          <% end %>
        </div>
      </:tag>
    </LiveSelect.live_select>
    """
  end
end
