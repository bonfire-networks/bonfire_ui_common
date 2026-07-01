defmodule Bonfire.UI.Common.Styleguide.PollCard do
  @moduledoc """
  Poll card — Jacobin design system reference component, derived from the Figma
  dashboard ("POLLS CLOSING SOON" full poll). Uses only the locked token layer
  (no new tokens were needed).

  Confirmed Figma specs:
  - card: base-100, 0.7px secondary stroke, rounded-box, overflow-hidden
  - header: 35px avatar (0.7px red ring), name text-body Medium, @handle text-muted + red middot
  - badges: text-body uppercase, rounded-selector (pill), 0.7px border —
    UMFRAGE = primary (red), OFFEN = success (green) + green dot
  - vote count: text-body Medium, base-content
  - question: text-display (23px Medium) — the FULL poll variant (compact/sidebar poll is 15px)
  - option row: hairline divider (base-300), real `<input type="radio">` with DaisyUI
    `radio radio-primary radio-xs` (binds to --border 0.7px / --radius-selector / primary;
    checked renders the red ring + center dot), label text-body
  - actions: Abstimmen = filled primary; Siehe Ergebnisse = muted-outline variant
    (secondary border + base-content text). Buttons use the canonical py-[11px] height (not Figma's 27px).
  - action row: comment / boost / like(red flame) / bookmark / more
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop display_name, :string, default: "shevek"
  prop username, :string, default: "@colin"
  prop time_text, :string, default: "vor 3 Tagen"
  prop avatar_url, :string, default: "/gen_avatar/colin"
  prop status_label, :string, default: "OFFEN"
  prop vote_count, :string, default: "123 Stimmen"

  prop question, :string,
    default: "Die Linkspartei Druck, sich der etablierten Politik anzupassen?"

  prop options, :list,
    default: [
      %{label: "Kapitalismus", selected: false},
      %{
        label:
          "Dem entgegen muss sie es als ihre vorrangige Aufgabe begreifen, den Unmut gegenüber sich als die wahre Alternative zu profilieren.",
        selected: true
      },
      %{
        label: "Jordan Peterson: Amoebas reproduce asexually and therefore humans should too",
        selected: false
      },
      %{label: "Government sponsored amoebas", selected: false}
    ]

  prop vote_label, :string, default: "Abstimmen"
  prop results_label, :string, default: "Siehe Ergebnisse"
end
