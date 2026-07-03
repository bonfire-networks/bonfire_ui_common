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
    # In tags mode LiveSelect renders the tags in a block ABOVE the input, so a bordered
    # input would read as a second pill below the tags. Make the container the bordered
    # box with a ghost field inside; single mode keeps the input as the pill.
    tags? = assigns[:mode] in [:tags, :quick_tags]

    assigns =
      assigns
      |> assign(
        :ls_container_class,
        if(tags?,
          do:
            "w-full flex flex-col gap-1.5 rounded-2xl border border-base-content/20 bg-base-content/5 px-3 py-2 transition-colors focus-within:border-primary",
          else: "w-full flex flex-col"
        )
      )
      # use class (not extra_class) — LiveSelect forbids passing both
      |> assign(
        :ls_text_input_class,
        if(tags?,
          do:
            "w-full bg-transparent border-0 shadow-none outline-none focus:outline-none focus:ring-0 px-1 py-1 text-sm h-auto",
          else: "input input-sm border-hair border-secondary bg-base-100 flex items-center gap-2 w-full text-base"
        )
      )
      # "" avoids the default `input-primary` orange border on the ghost tags field
      |> assign(:ls_text_input_selected_class, if(tags?, do: "", else: nil))
      |> assign(
        :ls_dropdown_class,
        "z-50 max-h-liveselect flex-nowrap border border-base-content/10 !bg-base-100 overflow-y-auto " <>
          if(tags?, do: "top-full mt-1", else: "top-12")
      )

    ~H"""
    <LiveSelect.live_select
      field={@form[@field]}
      mode={@mode}
      phx-target={@event_target}
      options={@options}
      value={@value}
      allow_clear={Map.get(assigns, :allow_clear, true)}
      keep_options_on_select={true}
      update_min_len={@update_min_len || 2}
      debounce={Map.get(assigns, :debounce, 300)}
      placeholder={@placeholder}
      disabled={@disabled}
      style={:daisyui}
      text_input_class={@ls_text_input_class}
      text_input_selected_class={@ls_text_input_selected_class}
      container_extra_class={@ls_container_class}
      tag_class="badge badge-primary rounded-full badge-md gap-1.5 font-medium"
      dropdown_extra_class={@ls_dropdown_class}
      tags_container_class="flex flex-wrap gap-1.5"
      value_mapper={&value_mapper/1}
    >
      <:option :let={option}>
        <div class="flex p-0 gap-2 items-center">
          <%= if Map.has_key?(option.value, :type) && option.value.type == "circle" do %>
            <span class="w-8 h-8 flex items-center place-content-center">
              <div
                iconify="ph:circle-fill"
                class="inline-block w-4 h-4 text-primary"
                aria-hidden="true"
              >
              </div>
            </span>
          <% end %>
          <%= if is_binary(option.value) do %>
            <p class="font-medium text-muted">
              {option.label}
            </p>
          <% else %>
            <%= if Map.has_key?(option.value, :icon) or Map.has_key?(option.value, "icon") do %>
              <div class="w-8 h-8">
                <img src={e(option.value, :icon, nil)} alt="" class="w-full h-full rounded-full" />
              </div>
            <% end %>
            <div class="">
              <p class="font-medium">
                {e(option.value, :name, nil) || e(option.value, :profile, :name, nil) ||
                  e(option.value, :named, :name, nil)}
              </p>
              <p class="font-light -mt-0.5 text-muted">
                {e(option.value, :username, nil) || e(option.value, :character, :username, nil)}
              </p>
            </div>
          <% end %>
        </div>
      </:option>

      <:tag :let={option}>
        <div class="flex items-center gap-2">
          <%= if is_binary(option.value) do %>
            <p class="font-medium text-sm">
              {option.label}
            </p>
          <% else %>
            <div class="text-sm">
              <p class="font-medium">
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
