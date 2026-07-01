defmodule Bonfire.UI.Common.Styleguide.NotificationCard do
  @moduledoc """
  Notification cards — reference rendering of the activity "context line" the way
  it appears in the **Benachrichtigungen** (Notifications) feed, derived from the
  Figma section `50:554` (file cieNS3trw8lHimqW60Ac5h).

  A notification = a **header line** ("X liked/boosted/replied …") optionally
  followed by the referenced **activity body** (post / profile / quote). The
  header is the same primitive `Bonfire.UI.Social.Activity.SubjectMinimalLive`
  renders, so this is the visual contract for normalising that component across
  notifications *and* feeds.

  Each item's `icon` / `phrase` mirror the `notification_icon/1` and verb-phrase
  mapping in `subject_minimal_live.ex` — keep them in lockstep. Verb icons are
  uniformly `text-primary` (the Jacobin all-red treatment).

  Confirmed Figma specs:
  - card: white (base-100), 0.7px secondary stroke, rounded-box, p-card (18px)
  - header: primary verb icon (≈18px) + name (Medium, base-content) + optional
    "and N others" (Medium) + verb phrase (Regular, --color-muted)
  - body avatar: 35px circle, 0.7px inset red ring, #d9d9d9 fill
  - follow → "Follow back" primary pill on the right; quote-request → "Decline" /
    "Accept quote" outline pills below the quoted card
  """
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "The notification examples to render (see `default_items/0` for the shape)."
  prop items, :list, default: nil

  @doc """
  The notification vocabulary, one entry per verb family. `icon` matches
  `SubjectMinimalLive.notification_icon/1`; `body` picks the example activity body
  (`:post` | `:profile` | `:quote` | `nil` for a header-only row); `action`
  renders the trailing affordance (`:follow_back` | `:quote_request`).
  """
  def default_items do
    [
      %{
        icon: "ph:chat-circle-fill",
        name: "Ivan",
        suffix: nil,
        phrase: l("replied to you"),
        body: :post,
        action: nil
      },
      %{
        icon: "ph:fire-fill",
        name: "Magdalena",
        suffix: l("and %{count} others", count: 12),
        phrase: l("liked your activity"),
        body: nil,
        action: nil
      },
      %{
        icon: "ph:arrows-counter-clockwise-fill",
        name: "Ole",
        suffix: nil,
        phrase: l("boosted your activity"),
        body: :post,
        action: nil
      },
      %{
        icon: "ph:chart-bar-fill",
        name: "Magdalena",
        suffix: l("and %{count} others", count: 12),
        phrase: l("voted on your poll"),
        body: :poll,
        action: nil
      },
      %{
        icon: "ph:at-fill",
        name: "shevek",
        suffix: nil,
        phrase: l("mentioned you"),
        body: :post,
        action: nil
      },
      %{
        icon: "ph:user-plus-fill",
        name: "Thomas Zimmermann",
        suffix: nil,
        phrase: l("followed you"),
        body: :profile,
        action: :follow_back
      },
      %{
        icon: "ph:quotes-fill",
        name: "Thomas",
        suffix: nil,
        phrase: l("wants to quote your post"),
        body: :quote,
        action: :quote_request
      }
    ]
  end
end
