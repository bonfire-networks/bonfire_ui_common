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
  prop icon_class, :css_class, required: false, default: "w-[18px] h-[18px] text-primary"

  prop skip_badges, :any, default: false

  @impl true

  # Is this nav item the current page? (drives the active semibold/primary label)
  def active?(selected_tab, widget, context) do
    page = String.downcase(to_string(widget[:page]))
    prefix = widget[:href_prefix]

    (page != "" and String.downcase(to_string(selected_tab)) == page) or
      (is_binary(prefix) and
         String.starts_with?(to_string(e(context, :current_url, "")), prefix))
  end

  # Phosphor duotone → fill (Figma uses the filled variants); leaves non-duotone icons as-is
  def fill_icon(icon), do: String.replace(to_string(icon), "-duotone", "-fill")

  # Active-state label classes — evaluates active?/3 once per item (not twice in the template)
  def active_label_class(selected_tab, widget, context) do
    if active?(selected_tab, widget, context),
      do: "font-medium text-primary",
      else: "font-normal text-base-content"
  end
end
