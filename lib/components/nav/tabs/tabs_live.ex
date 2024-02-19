defmodule Bonfire.UI.Common.TabsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop type, :atom, default: nil
  prop tabs, :any, required: true
  prop selected_tab, :any, default: nil
  prop selected_name, :string, default: nil
  prop path_prefix, :string, default: "?tab="
  prop path_suffix, :string, default: nil

  prop link_component, :atom, default: LinkPatchLive

  prop class, :css_class, default: "flex gap-3 pt-1 md:pt-4 p-3 px-4 scrollable"
  prop tab_class, :css_class
  prop item_class, :css_class, default: ""
  prop tab_primary_class, :css_class, default: "btn-primary"
  @doc "What LiveHandler and/or event name to send the patch event to (optional)"
  prop event_handler, :string, default: nil

  @doc "What element (and it's parent view or stateful component) to send the event to (optional)"
  prop event_target, :string, default: nil

  slot default, required: false

  defp l_suffix({suffix, _}), do: "/#{suffix}"
  defp l_suffix([t]), do: l_suffix(t)
  defp l_suffix(_), do: nil

  defp l_name({_, tab_name}), do: localise_dynamic(tab_name)
  defp l_name([t]), do: l_name(t)
  defp l_name(tab_name), do: localise_dynamic(tab_name)
end
