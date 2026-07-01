defmodule Bonfire.UI.Common.Styleguide.MediaPreview do
  @moduledoc """
  Media preview — the link/article *unfurl* card, derived from the Figma
  "Media preview" artboard (`62:1056`, file cieNS3trw8lHimqW60Ac5h).

  A post card whose body is a rich link preview: source URL → hero image →
  publisher eyebrow → headline → description. The visual contract for refactoring
  the feed media components (`top_level_media_live` / `media_link_live`) onto the
  token system.

  Confirmed Figma specs (all map to existing tokens — no new tokens needed):
  - card: white (base-100), 0.7px secondary stroke, rounded-box, p-card (18px)
  - 18-based vertical rhythm (`--spacing-base`); the publisher eyebrow hugs the
    headline (tight) as one group
  - hero image: rounded-box, 0.7px secondary hairline border, neutral placeholder
    (`--color-placeholder` #c6c6c6)
  - headline: text-display (23px Medium, lh 25, -0.03em tracking)
  - URL / publisher / description: text-body (15px); URL underlined, publisher
    uppercase, both muted (`--color-muted`)
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop display_name, :string, default: "shevek"
  prop username, :string, default: "@colin"
  prop time_text, :string, default: "vor 3 Tagen"
  prop avatar_url, :string, default: "/gen_avatar/colin"

  prop url, :string, default: "https://www.theguardian.com/world/2026…"
  prop source, :string, default: "The Guardian"

  prop headline, :string,
    default:
      "Spanish PM's wife to stand trial on corruption charges and banned from leaving country"

  prop description, :string,
    default:
      "Begoña Gómez has been ordered to surrender her passport as her husband, Pedro Sánchez, says the case is politically motivated."
end
