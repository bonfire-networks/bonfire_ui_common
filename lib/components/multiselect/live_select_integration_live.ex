defmodule Bonfire.UI.Common.LiveSelectIntegrationLive do
  use Bonfire.UI.Common.Web, :function_component

  @doc """
  A LiveSelect integration component for Bonfire that handles form integration and events.

  ## Examples
      <LiveSelectIntegrationLive.live_select
        form={@form}
        field={:my_field}
        mode={:tags}
        event_target={@myself}
        options={@options}
        value={@selected_values}
      />
  """
  def live_select(assigns) do
    ~H"""
    <LiveSelect.live_select
      field={@form[@field]}
      mode={@mode}
      phx-target={@event_target}
      options={@options}
      value={@value}
      allow_clear={Map.get(assigns, :allow_clear, true)}
      update_min_len={@update_min_len || 2}
      debounce={Map.get(assigns, :debounce, 0)}
      placeholder={@placeholder}
      disabled={@disabled}
      style={:daisyui}
      container_extra_class="w-full flex flex-col"
      tag_class="badge badge-neutral badge-soft badge-lg gap-2"
      dropdown_extra_class="z-50 max-h-liveselect flex-nowrap border border-base-content/10 !bg-base-100 overflow-y-auto top-12"
      tags_container_class="flex flex-wrap gap-1 order-last mt-1"
      value_mapper={&value_mapper/1}
    >
      <:option :let={option}>
        <div class="flex p-0 gap-2 items-center">
          <%= if Map.has_key?(option.value, :type) && option.value.type == "circle" do %>
            <span class="w-8 h-8 rounded-full bg-info/10 flex items-center place-content-center">
              <div
                iconify="rivet-icons:circle"
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
            <%= if Map.has_key?(option.value, :icon) or Map.has_key?(option.value, "icon") do %>
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
            <%= if Map.has_key?(option.value, :icon) or Map.has_key?(option.value, "icon") do %>
              <div class="w-6 h-6">
                <img src={e(option.value, :icon, nil)} alt="" class="w-full h-full rounded-full" />
              </div>
            <% end %>
            <div class="text-sm">
              <p class="font-semibold">
                {e(option.value, :name, nil) ||
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

  defp value_mapper(%{id: id, name: name} = value) do
    %{label: name, value: value}
  end

  defp value_mapper(%{id: id} = value) do
    name =
      e(value, :name, nil) || e(value, :profile, :name, nil) ||
        e(value, :username, nil) || e(value, :named, :name, nil)

    %{label: name, value: value}
  end

  defp value_mapper(value) when is_binary(value), do: %{label: value, value: value}
  defp value_mapper(value), do: value
end
