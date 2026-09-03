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
    filter_variant? = tags? and assigns[:variant] == :filter

    assigns =
      assigns
      |> assign(
        :ls_container_class,
        cond do
          filter_variant? ->
            "relative w-full min-h-[46px] flex flex-wrap items-center gap-1.5 rounded-[14px] border border-base-content/15 bg-base-content/[0.03] px-[7px] py-[5px] transition-[border-color,background-color,box-shadow] duration-150 hover:border-base-content/25 hover:bg-base-content/[0.06] focus-within:border-primary focus-within:ring-[3px] focus-within:ring-primary/20 [&>div]:min-w-[150px] [&>div]:flex-1"

          tags? ->
            "w-full flex flex-col gap-1.5 rounded-2xl border border-secondary bg-base-content/5 px-3 py-2 transition-colors focus-within:border-primary"

          true ->
            "w-full flex flex-col"
        end
      )
      # use class (not extra_class) — LiveSelect forbids passing both
      |> assign(
        :ls_text_input_class,
        cond do
          filter_variant? ->
            "w-full min-h-[34px] bg-transparent border-0 shadow-none outline-none focus:outline-none focus:ring-0 px-1.5 py-1 text-base h-auto placeholder:text-base-content/55"

          tags? ->
            "w-full bg-transparent border-0 shadow-none outline-none focus:outline-none focus:ring-0 px-1 py-1 text-sm h-auto"

          true ->
            "input input-sm border-hair border-secondary bg-base-100 flex items-center gap-2 w-full text-base"
        end
      )
      # "" avoids the default `input-primary` orange border on the ghost tags field
      |> assign(:ls_text_input_selected_class, if(tags?, do: "", else: nil))
      |> assign(
        :ls_dropdown_class,
        if(filter_variant?,
          do:
            "z-popover top-full mt-1 max-h-liveselect flex-nowrap overflow-y-auto rounded-[14px] border border-base-content/10 !bg-base-100 p-1.5 shadow-xl",
          else:
            "z-50 max-h-liveselect flex-nowrap border border-secondary !bg-base-100 overflow-y-auto " <>
              if(tags?, do: "top-full mt-1", else: "top-12")
        )
      )
      |> assign(
        :ls_tag_class,
        if(filter_variant?,
          do:
            "min-h-[34px] inline-flex items-center gap-[7px] rounded-full bg-primary/[0.14] py-[3px] pr-1 pl-2 text-[13px] font-semibold text-primary",
          else: "badge badge-primary rounded-full badge-md gap-1.5 font-medium"
        )
      )
      |> assign(
        :ls_tags_container_class,
        if(filter_variant?, do: "contents", else: "flex flex-wrap gap-1.5")
      )
      |> assign(
        :ls_clear_tag_button_class,
        if(filter_variant?,
          do:
            "touch-target-expanded focus-ring relative grid size-7 min-h-7 min-w-7 place-items-center rounded-full text-primary transition-colors duration-150 hover:bg-primary/10",
          else: nil
        )
      )
      |> assign(:ls_option_class, if(filter_variant?, do: "rounded-[10px] px-2 py-2", else: nil))
      |> assign(
        :ls_active_option_class,
        if(filter_variant?, do: "bg-primary/[0.12] text-base-content", else: nil)
      )
      |> assign(
        :ls_available_option_class,
        if(filter_variant?,
          do: "cursor-pointer rounded-[10px] hover:bg-base-content/[0.06]",
          else: nil
        )
      )
      |> assign(
        :ls_selected_option_class,
        if(filter_variant?,
          do: "cursor-pointer rounded-[10px] bg-primary/[0.08] text-primary",
          else: nil
        )
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
      tag_class={@ls_tag_class}
      dropdown_extra_class={@ls_dropdown_class}
      tags_container_class={@ls_tags_container_class}
      clear_tag_button_class={@ls_clear_tag_button_class}
      option_class={@ls_option_class}
      active_option_class={@ls_active_option_class}
      available_option_class={@ls_available_option_class}
      selected_option_class={@ls_selected_option_class}
      value_mapper={&value_mapper/1}
    >
      <:option :let={option}>
        <div class="flex p-0 gap-2 items-center">
          <%= if is_map(option.value) && Map.has_key?(option.value, :type) && option.value.type == "circle" do %>
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

      <:clear_button>
        <span class="touch-target-hit-area" aria-hidden="true"></span>
        <span class="sr-only">{l("Remove selection")}</span>
        <span class="pointer-events-none text-base leading-none" aria-hidden="true">×</span>
      </:clear_button>
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
