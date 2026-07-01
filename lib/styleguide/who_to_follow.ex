defmodule Bonfire.UI.Common.Styleguide.WhoToFollow do
  @moduledoc """
  "Who to follow" suggestion card — Jacobin design system reference component,
  derived from the Figma dashboard frame. Uses only the locked token layer.

  Confirmed Figma specs:
  - card: base-100, 0.7px secondary stroke, rounded-box, ~19px padding
  - avatar: 35px circle, 0.7px inset red ring
  - name: text-body Medium; @handle: text-body --color-muted (#868686), red middot
  - bio: text-body (15/20) base-content, -0.3px tracking (NOT muted)
  - follow button: full-width, pill (rounded-field), text-body. Height uses the
    canonical button padding (py-[11px], from the styleguide button section) — NOT
    Figma's 27px, which is below the ~44px touch-target minimum (deliberate deviation).
    - not-following → filled: bg-primary / primary-content + people icon ("Folgen")
    - following → muted outline: bg-base-200 + 0.7px secondary border + base-content ("Du folgst")
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop display_name, :string, default: "shevek"
  prop username, :string, default: "@colin"

  prop bio, :string,
    default:
      "A very interesting biography. Unlike others, I like music, having fun and walking along the beach."

  prop avatar_url, :string, default: "/gen_avatar/colin"
  prop following, :boolean, default: false
  prop follow_label, :string, default: "Folgen"
  prop following_label, :string, default: "Du folgst"
end
