defmodule Bonfire.UI.Common.Styleguide.PostCard do
  @moduledoc """
  Post card — the first reference component of the Jacobin design system,
  derived directly from the Figma dashboard frame (file cieNS3trw8lHimqW60Ac5h).

  Built from the locked token layer only — no hardcoded design values except the
  few Figma specifics that have no token yet (avatar fill #d9d9d9, 0.7px ring,
  35px avatar). Spacing marked `diff:` is provisional and gets tuned against the
  visual-diff gate (Figma PNG vs rendered screenshot).

  Confirmed Figma specs used here:
  - card: white (base-100), 0.7px stroke (secondary), rounded-box
  - avatar: 35px circle, 0.7px inset red ring, #d9d9d9 fill
  - name: 15px Lateral Medium, base-content
  - @handle/time: 15px Lateral Regular, #868686 (--color-muted), red middot
  - body: 15px Lateral Regular, line-height 19px (text-body)
  - "SEE FULL POST": 12px uppercase, base-content (NOT red — Figma shows black), right-aligned
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop display_name, :string, default: "shevek"
  prop username, :string, default: "@colin"
  prop time_text, :string, default: "vor 3 Tagen"
  prop avatar_url, :string, default: "/gen_avatar/colin"

  prop body, :string,
    default:
      "After decades of neoliberal orthodoxy treating state intervention in the economy as either futile or corrupt — the linearity they teach is a prison. Time doesn't flow, it connects."

  prop more_label, :string, default: "See full post"
end
