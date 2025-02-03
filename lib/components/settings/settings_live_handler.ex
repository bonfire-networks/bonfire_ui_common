defmodule Bonfire.Common.Settings.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  # import Bonfire.Boundaries.Integration

  def handle_event("put", %{"keys" => keys, "values" => value} = params, socket) do
    with {:ok, settings} <-
           keys
           |> String.split(":")
           #  |> debug()
           |> Bonfire.Common.Settings.put(value, scope: params["scope"], socket: socket) do
      # debug(settings, "done")
      {:noreply,
       socket
       |> maybe_assign_context(settings)
       |> assign_flash(:info, l("Settings saved :-)"))}
    end
  end

  def handle_event("set", attrs, socket) when is_map(attrs) do
    with {:ok, settings} <-
           Map.drop(attrs, ["_target"])
           |> Map.put("scope", e(attrs, "scope", nil) || e(assigns(socket), :scope, nil))
           |> Bonfire.Common.Settings.set(socket: socket) do
      # debug(settings, "settings saved")
      {:noreply,
       socket
       |> maybe_assign_context(settings)
       |> assign_flash(:info, l("Settings saved :-)"))}
    end
  end

  def handle_event("save", attrs, socket) when is_map(attrs) do
    with {:ok, settings} <-
           Map.drop(attrs, ["_target"]) |> Bonfire.Common.Settings.set(socket: socket) do
      {
        :noreply,
        socket
        |> maybe_assign_context(settings)
        |> assign_flash(:info, l("Settings saved :-)"))
        #  |> redirect_to("/")
      }
    end
  end

  def handle_event("put_theme", %{"keys" => keys, "values" => value} = params, socket) do
    # IO.inspect(params, label: "CCCC")

    with {:ok, _settings} <-
           keys
           |> String.split(":")
           |> Bonfire.Common.Settings.put(value, scope: params["scope"], socket: socket) do
      {:noreply,
       socket
       #  |> maybe_assign_context(settings)
       |> assign_flash(:info, l("Theme changed and loaded :-)"))
       |> push_navigate(to: current_url(socket) || "/")}
    end
  end

  def handle_event("extension:disable", %{"extension" => extension} = attrs, socket) do
    extension_toggle(extension, true, attrs, socket)
  end

  def handle_event("extension:enable", %{"extension" => extension} = attrs, socket) do
    extension_toggle(extension, nil, attrs, socket)
  end

  def handle_event("toggle_extensions_configuration", params, socket) do
    scope = e(params, "scope", nil) || e(assigns(socket), :scope, nil)
    current_user = current_user(socket)

    current_value =
      Bonfire.Common.Settings.get(
        [:ui, :enable_extensions_configuration],
        false,
        scope: scope,
        current_user: current_user
      )

    with {:ok, settings} <-
           Bonfire.Common.Settings.put(
             [:ui, :enable_extensions_configuration],
             !current_value,
             scope: scope,
             current_user: current_user
           ) do
      {:noreply,
       socket
       |> maybe_assign_context(settings)
       |> assign_flash(:info, l("Settings saved :-)"))}
    end
  end

  # LiveHandler
  def handle_event("set_locale", %{"locale" => locale}, socket) do
    Bonfire.Common.Localise.put_locale(locale)
    |> debug("set current UI locale")

    # then save to settings
    %{"Bonfire.Common.Localise.Cldr" => %{"default_locale" => locale}}
    |> handle_event("set", ..., socket)
  end

  def handle_event(
        "reorder_widget",
        %{
          "old_index" => old_index,
          "new_index" => new_index,
          "parent_item" => parent_item,
          "source_item" => source_item,
          "target_order" => target_order
        },
        socket
      ) do
    with {:ok, settings} <-
           Bonfire.Common.Settings.put(
             [:ui, :widget_order, parent_item],
             target_order
             |> Enum.reject(&is_nil/1)
             |> Enum.with_index()
             |> Map.new(fn {item, index} -> {String.to_atom(item), index} end),
             current_user: current_user(socket)
           ) do
      {
        :noreply,
        socket |> maybe_assign_context(settings)
      }
    end
  end

  def handle_event(
        "reorder_sub_widget",
        %{
          "old_index" => old_index,
          "new_index" => new_index,
          "parent_item" => parent_item,
          "source_item" => source_item,
          "target_order" => target_order
        },
        socket
      ) do
    with {:ok, settings} <-
           Bonfire.Common.Settings.put(
             [:ui, :sub_widget_order, parent_item],
             target_order
             |> Enum.with_index()
             |> Map.new(fn {item, index} -> {String.to_atom(item), index} end),
             current_user: current_user(socket)
           ) do
      {
        :noreply,
        socket |> maybe_assign_context(settings)
      }
    end
  end

  defp extension_toggle(extension, disabled?, attrs, socket) do
    scope =
      maybe_to_atom(e(attrs, "scope", nil))
      |> debug("scope")

    set = if disabled?, do: :disabled

    with {:ok, settings} <-
           Bonfire.Common.Settings.put([extension, :modularity], set,
             scope: scope,
             socket: socket
           ) do
      # generate an updated reverse router based on extensions that are enabled/disabled
      if scope == :instance, do: Bonfire.Common.Extend.generate_reverse_router!()

      {
        :noreply,
        socket
        |> maybe_assign_context(settings)
        |> assign_flash(:info, "Extension toggled :-)")
        #  |> redirect_to(current_url(socket))
      }
    end
  end

  def maybe_assign_input_value_from_keys(assigns) do
    assigns
    |> update(:input, fn custom_input ->
      custom_input || input_name(assigns.keys)
    end)
    |> update(:current_value, fn
      :load_from_settings ->
        Bonfire.Common.Settings.get(
          assigns.keys,
          assigns[:default_value],
          scoped(assigns[:scope], assigns[:__context__])
        )

      custom_value ->
        custom_value
    end)
  end

  def scoped(scope, context) do
    case scope do
      :account -> current_account(context)
      "account" -> current_account(context)
      :instance -> context[:instance_settings] || :instance
      "instance" -> context[:instance_settings] || :instance
      _ -> current_user(context)
    end
  end

  def input_name(keys) do
    keys
    |> Enum.with_index()
    |> Enum.map(fn
      {k, 0} -> "#{k}"
      {k, _} -> "[#{k}]"
    end)

    # |> Enum.reverse() |> Enum.reduce(& "#{&1}[#{&2}]")
  end
end
