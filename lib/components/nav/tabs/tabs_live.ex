defmodule Bonfire.UI.Common.TabsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop type, :atom, default: nil
  prop tabs, :any, required: true
  prop selected_tab, :any, default: nil
  prop selected_name, :string, default: nil
  prop path_prefix, :string, default: "?tab="
  prop path_suffix, :string, default: nil
  prop show_back_button, :boolean, default: false

  prop link_component, :atom, default: LinkPatchLive

  prop class, :css_class, default: "flex gap-3 pt-1 md:pt-4 p-3 px-4 scrollable"
  prop tab_class, :css_class
  prop item_class, :css_class, default: ""
  prop tab_primary_class, :css_class, default: "btn-primary"
  @doc "What LiveHandler and/or event name to send the patch event to (optional)"
  prop event_handler, :string, default: nil

  @doc "What element (and it's parent view or stateful component) to send the event to (optional)"
  prop event_target, :string, default: nil

  @doc "Module of the extension that *declares* these tab names, used to resolve their gettext domain. Tab names normally come from another extension's nav config (e.g. `[:ui, :topic, :settings, :navigation]`), and a gettext lookup only ever searches one domain — so without this they are looked up in `bonfire_ui_common`, where they were never extracted, and silently render in English."
  prop extension, :atom, default: nil

  slot default, required: false

  defp l_suffix(%{suffix: suffix}), do: "/#{suffix}"
  defp l_suffix({suffix, _}), do: "/#{suffix}"
  defp l_suffix([t]), do: l_suffix(t)
  defp l_suffix(_), do: nil

  defp l_name(tab_name, extension \\ nil)

  # was previously written as an `l_suffix/1` clause after its catch-all, so it never matched and
  # map-shaped tabs fell through to the clause below, handing a map to `localise_dynamic/3`
  defp l_name(%{name: tab_name}, extension), do: l_name(tab_name, extension)
  defp l_name({_, tab_name}, extension), do: l_name(tab_name, extension)
  defp l_name([t], extension), do: l_name(t, extension)

  defp l_name(tab_name, extension),
    do: localise_dynamic(tab_name, extension || __MODULE__)
end
