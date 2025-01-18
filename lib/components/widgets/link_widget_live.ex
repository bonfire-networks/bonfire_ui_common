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
      "flex-1  h-auto justify-start relative flex items-center gap-3 widget_content p-2 py-1"

  prop text_class, :css_class, default: nil

  prop badge_class, :css_class,
    default:
      "flex absolute right-[6px] top-[-8px] lg:!right-auto lg:left-5 lg:!top-[-6px] items-center place-content-center widget_notification"

  prop parent_id, :string, default: nil
  prop page, :string, default: nil
  prop selected_tab, :any, default: nil
  prop showing_within, :atom, default: :sidebar
  prop order, :integer, default: nil

  prop wrapper_class, :css_class, default: "m-0 p-0 justify-end  !block"
  prop link_class, :any, default: "!px-0"
  prop icon_class, :css_class, required: false, default: "w-4 h-4 text-base-content"

  prop skip_badges, :any, default: false

  @impl true
end
