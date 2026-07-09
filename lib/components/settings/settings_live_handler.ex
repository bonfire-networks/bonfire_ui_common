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
       |> assign_flash(:info, l("Settings saved"))}
    end
  end

  def handle_event("set", attrs, socket) when is_map(attrs) do
    with {:ok, settings} <-
           Map.drop(attrs, ["_target"])
           |> drop_unused_form_keys()
           |> Map.put("scope", e(attrs, "scope", nil) || e(assigns(socket), :scope, nil))
           |> Bonfire.Common.Settings.set(socket: socket) do
      # debug(settings, "settings saved")
      {:noreply,
       socket
       |> maybe_assign_context(settings)
       |> maybe_push_font(attrs)
       |> assign_flash(:info, l("Settings saved"))}
    end
  end

  defp maybe_push_font(socket, %{
         "_target" => ["ui", "font_family"],
         "ui" => %{"font_family" => font}
       })
       when is_binary(font) and font != "",
       do: Bonfire.UI.Common.FontHelper.push_font(socket, font)

  defp maybe_push_font(socket, _attrs), do: socket

  # LiveView's client appends `_unused_<field>` markers for form inputs the user
  # didn't touch (see `Phoenix.Component.used_input?/1`). These are form-tracking
  # artifacts, not settings: if persisted they pollute stored config (e.g. a stray
  # `"_unused_reject_unsigned"` string key breaks `Keyword.keyword?` reads of the
  # whole branch). Strip them recursively before handing params to `Settings.set`.
  defp drop_unused_form_keys(attrs) when is_map(attrs) and not is_struct(attrs) do
    attrs
    |> Enum.reject(fn {k, _v} -> is_binary(k) and String.starts_with?(k, "_unused_") end)
    |> Map.new(fn {k, v} -> {k, drop_unused_form_keys(v)} end)
  end

  defp drop_unused_form_keys(other), do: other

  def handle_event("save", attrs, socket) when is_map(attrs) do
    with {:ok, settings} <-
           Map.drop(attrs, ["_target"])
           |> drop_unused_form_keys()
           |> Bonfire.Common.Settings.set(socket: socket) do
      {
        :noreply,
        socket
        |> maybe_assign_context(settings)
        |> assign_flash(:info, l("Settings saved"))
        #  |> redirect_to("/")
      }
    end
  end

  def handle_event("put_theme", %{"keys" => keys, "values" => value} = params, socket) do
    with {:ok, settings} <-
           keys
           |> String.split(":")
           |> Bonfire.Common.Settings.put(value, scope: params["scope"], socket: socket) do
      # refresh context + push the theme so it applies live without a reload
      {:noreply,
       socket
       |> maybe_assign_context(settings)
       |> Bonfire.UI.Common.ThemeHelper.push_current_theme()
       |> assign_flash(:info, l("Theme changed and loaded :-)"))}
    end
  end

  @doc """
  Non-destructively saves a single custom-theme colour.

  Uses `put_raw` rather than `put` so the colour key isn't run through `input_to_atoms`
  (which atomises a key only when that atom already exists, yielding an inconsistent
  atom/string key mix that `deep_merge` splits into duplicate entries). `deep_merge`
  preserves the other colours, so setting one never resets another.
  """
  def handle_event("put_custom_color", %{"keys" => keys, "values" => value} = params, socket)
      when is_binary(value) do
    # e.g. "ui:theme:custom:color-base-100" -> "color-base-100"
    color_key = keys |> String.split(":") |> List.last()
    theme_key = Bonfire.UI.Common.ThemeHelper.custom_theme_key(params["scope"])

    with {:ok, value} <- DaisyTheme.normalize_value(color_key, value),
         {:ok, settings} <-
           Bonfire.Common.Settings.put_raw([:ui, :theme, theme_key, color_key], value,
             scope: params["scope"],
             socket: socket
           ) do
      # close+reset the shared modal so the next swatch opens with fresh content
      Bonfire.UI.Common.OpenModalLive.close()

      {:noreply,
       socket
       |> maybe_assign_context(settings)
       # push the updated palette to <html> so it applies live, document-wide
       |> Bonfire.UI.Common.ThemeHelper.push_current_theme()
       |> assign_flash(:info, l("Settings saved"))}
    else
      :error ->
        {:noreply, assign_flash(socket, :error, l("Invalid colour value"))}
    end
  end

  @doc """
  Resets the whole custom-theme palette back to defaults by removing every stored override.

  Deletes the entire `[:ui, :theme, <custom_key>]` subtree so every colour, radius, etc.
  falls through to `DaisyTheme.default_theme/0` in the template, instead of persisting
  redundant copies of the defaults.
  """
  def handle_event("reset_custom_theme", params, socket) do
    theme_key = Bonfire.UI.Common.ThemeHelper.custom_theme_key(params["scope"])

    with {:ok, settings} <-
           Bonfire.Common.Settings.delete([:ui, :theme, theme_key],
             scope: params["scope"],
             socket: socket
           ) do
      {:noreply,
       socket
       |> maybe_assign_context(settings)
       |> Bonfire.UI.Common.ThemeHelper.push_current_theme()
       |> assign_flash(:info, l("Custom theme reset to defaults"))}
    end
  end

  def handle_event(
        "extension:toggle",
        %{"extension" => extension, "value" => "on"} = attrs,
        socket
      ) do
    extension_toggle(extension, nil, attrs, socket)
  end

  def handle_event("extension:toggle", %{"extension" => extension} = attrs, socket) do
    extension_toggle(extension, true, attrs, socket)
  end

  def handle_event("toggle_extensions_configuration", params, socket) do
    scope = e(params, "scope", nil) || e(assigns(socket), :scope, nil)
    current_user = current_user(socket)

    current_value =
      Bonfire.Common.Settings.get(
        [:ui, :enable_extensions_configuration],
        false,
        current_user: current_user,
        scope: scope,
        name: l("Power user mode"),
        description: l("Enable turning extensions on and off.")
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
       |> assign_flash(:info, l("Settings saved"))}
    end
  end

  # LiveHandler
  def handle_event(
        "set_locale",
        %{"Elixir.Bonfire.Common.Localise.Cldr" => %{"default_locale" => locale}} = params,
        socket
      ) do
    Bonfire.Common.Localise.put_locale(locale)
    |> debug("set current UI locale")

    handle_event("set", params, socket)
  end

  def handle_event("set_locale", %{"locale" => locale} = params, socket) do
    handle_event(
      "set_locale",
      Map.merge(params, %{"Elixir.Bonfire.Common.Localise.Cldr" => %{"default_locale" => locale}}),
      socket
    )
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
             |> Map.new(fn {item, index} -> {maybe_to_atom(item), index} end),
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
             |> Map.new(fn {item, index} -> {maybe_to_atom(item), index} end),
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
    |> maybe_load_setting_value()
  end

  defp maybe_load_setting_value(%{current_value: :load_from_settings} = assigns) do
    scope = assigns[:scope]
    scoped_opts = scoped(scope, assigns[:__context__])

    # For instance scope, return the merged value as-is (no higher scope to leak)
    if scope in [:instance, "instance"] do
      value =
        Bonfire.Common.Settings.__get__(
          assigns.keys,
          assigns[:default_value],
          scoped_opts
        )

      Map.put(assigns, :current_value, value)
    else
      # For user/account scope: fetch only this scope's own value
      own_opts =
        Utils.to_options(scoped_opts)
        |> Keyword.put(:one_scope_only, true)

      own_value =
        Bonfire.Common.Settings.__get__(assigns.keys, nil, own_opts)

      if not is_nil(own_value) do
        Map.put(assigns, :current_value, own_value)
      else
        # Check if a parent scope has a value
        inherited =
          Bonfire.Common.Settings.__get__(assigns.keys, nil, scoped_opts)

        if not is_nil(inherited) do
          assigns
          |> Map.put(:current_value, nil)
          |> Map.put(
            :placeholder,
            l("A default value is already provided. Enter your own to override it.")
          )
        else
          Map.put(assigns, :current_value, assigns[:default_value])
        end
      end
    end
  end

  defp maybe_load_setting_value(assigns), do: assigns

  def scoped(scope, context) do
    case scope do
      s when s in [:account, "account"] ->
        current_account(context)

      s when s in [:instance, "instance"] ->
        context[:instance_settings] || [scope: :instance]

      _ ->
        current_user(context)
    end
  end

  def input_name(keys) when is_list(keys) or is_map(keys) do
    keys
    |> debug("input")
    # |> List.wrap()
    |> Enum.with_index()
    |> Enum.map(fn
      {key, 0} ->
        "#{key}"

      {key, _} when is_atom(key) or is_binary(key) ->
        "[#{key}]"

      {other, _} ->
        error(other, "dunno how to handle this key part")
        ""
    end)
    |> debug("output")

    # |> Enum.reverse() |> Enum.reduce(& "#{&1}[#{&2}]")
  end

  def input_name(keys), do: List.wrap(keys) |> input_name()
end
