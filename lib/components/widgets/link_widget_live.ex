defmodule Bonfire.UI.Common.LinkWidgetLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop to, :string, default: nil
  prop text, :string, default: nil
  prop icon, :string, default: nil

  prop widget, :any, default: %{}
  prop without_icon, :boolean, default: false
  prop without_label, :boolean, default: false

  prop content_class, :css_class,
    default:
      "flex-1  h-auto justify-start relative flex items-center gap-2 widget_content p-2 py-1 text-muted font-medium"

  prop text_class, :css_class, default: nil

  prop parent_id, :string, default: nil
  prop page, :string, default: nil
  prop selected_tab, :any, default: nil
  prop showing_within, :atom, default: :sidebar
  prop order, :integer, default: nil

  prop wrapper_class, :css_class, default: "m-0 p-0 justify-end !block"
  # nav row: 16px gap between icon and label (Figma). `!gap` beats DaisyUI's .menu grid gap (8px).
  prop link_class, :any, default: "!px-0 flex items-center !gap-[16px]"
  prop icon_class, :css_class, required: false, default: "size-5"

  prop skip_badges, :any, default: false

  @doc "Returns whether a navigation widget represents the current page."
  def active?(current_page, selected_tab, widget, context) do
    widget_page = String.downcase(to_string(widget[:page]))
    current_pages = Enum.map([current_page, selected_tab], &String.downcase(to_string(&1)))
    prefix = widget[:href_prefix]

    (widget_page != "" and widget_page in current_pages) or
      (is_binary(prefix) and
         String.starts_with?(to_string(e(context, :current_url, "")), prefix))
  end

  @doc "Returns the filled Phosphor variant while leaving other icon names unchanged."
  def fill_icon(icon), do: String.replace(to_string(icon), "-duotone", "-fill")

  # the class helpers take the precomputed boolean so the template evaluates active?/4
  # once per nav item, not once per styled part

  @doc "Returns the label classes for an active or inactive navigation item."
  def active_label_class(active?) do
    if active?,
      do: "font-semibold text-base-content",
      else: "font-normal text-base-content/80"
  end

  @doc "Returns the icon colour classes for an active or inactive navigation item."
  def active_icon_class(active?) do
    if active?,
      do: "text-primary",
      else: "text-muted"
  end

  @doc "Returns the surface classes for an active or inactive navigation item."
  def active_link_class(active?) do
    if active?,
      do: "",
      else: "hover:bg-base-content/5"
  end
end
