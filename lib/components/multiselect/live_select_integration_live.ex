defmodule Bonfire.UI.Common.LiveSelectIntegrationLive do
  use Bonfire.UI.Common.Web, :function_component

  def live_select(assigns) do
    # field={@form[@form_input_name]}

    # TODO: fix warning: instead of passing separate form and field attributes, pass a single field attribute of type Phoenix.HTML.FormField
    ~H"""
    <LiveSelect.live_select
      field={@form[@field]}
      mode={@mode}
      phx-target={@event_target}
      options={@options}
      value={@value}
      allow_clear={true}
      update_min_len={@update_min_len || 1}
      debounce={0}
      placeholder={@placeholder}
      disabled={@disabled}
      style={:daisyui}
      text_input_extra_class={@text_input_class}
      container_extra_class="w-full flex flex-col"
      option_extra_class="{@option_extra_class}"
      tag_class="badge badge-neutral badge-lg gap-2"
      dropdown_extra_class="z-[99999999999999999999999999999999] max-h-60 flex-nowrap border border-base-content/10 !bg-base-100 overflow-y-auto "
      tags_container_class="flex flex-wrap gap-1 pt-2 order-last"
    >
      <:option :let={option}>
        <div class="flex p-0 gap-2 items-center">
          <%= if Map.has_key?(option.value, :type) && option.value.type == "circle" do %>
            <span class="w-8 h-8 rounded-full bg-info/10 flex items-center place-content-center">
              <div
                iconify="pajamas:group"
                class="inline-block w-4 h-4 text-base-content"
                aria-hidden="true"
              >
              </div>
            </span>
          <% end %>
          <%= if is_binary(option.value) do %>
            <p class="font-semibold text-base-content/70">
              {option.label}
            </p>
          <% else %>
            <%= if Map.has_key?(debug(option).value, :icon) or Map.has_key?(option.value, "icon") do %>
              <div class="w-8 h-8">
                <img src={e(option.value, :icon, nil)} alt="" class="w-full h-full rounded-full" />
              </div>
            <% end %>
            <div class="">
              <p class="font-semibold">
                {e(option.value, :name, nil) || e(option.value, :profile, :name, nil) ||
                  e(option.value, :named, :name, nil)}
              </p>
              <p class="font-light -mt-0.5 text-base-content/70">
                {e(option.value, :username, nil) || e(option.value, :character, :username, nil)}
              </p>
            </div>
          <% end %>
        </div>
      </:option>

      <:tag :let={option}>
        <div class="flex items-center gap-2">
          <%= if is_binary(option.value) do %>
            <p class="font-semibold text-sm">
              {option.label}
            </p>
          <% else %>
            <%= if Map.has_key?(debug(option.value), :icon) or Map.has_key?(option.value, "icon") do %>
              <div class="w-6 h-6">
                <img src={e(option.value, :icon, nil)} alt="" class="w-full h-full rounded-full" />
              </div>
            <% end %>
            <div class="text-sm">
              <p class="font-semibold">
                {e(debug(option, "tag oppppt"), :value, :name, nil) ||
                  e(option.value, :profile, :name, nil) || e(option.value, :username, nil) ||
                  e(option.value, :named, :name, nil)}
              </p>
            </div>
          <% end %>
        </div>
      </:tag>
    </LiveSelect.live_select>
    """
  end
end
