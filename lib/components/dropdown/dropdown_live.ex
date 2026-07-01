defmodule Bonfire.UI.Common.DropdownLive do
  @moduledoc """
  The single, standard dropdown / popover menu for Bonfire.

  Wraps the `Tooltip` JS hook (floating-ui: smart flip/shift positioning that
  escapes `overflow: hidden/clip` clipping) together with the `.dropdown-panel`
  surface, so every dropdown shares one mechanism, one look, and consistent
  accessibility wiring instead of hand-rolling the wrapper/trigger/panel each time.

  ## Example

      <Dropdown
        id={"post_more_menu_\#{id(@object)}"}
        position="bottom-end"
        trigger_class="btn btn-ghost btn-circle btn-sm"
        label={l("More actions")}
      >
        <:trigger>
          <#Icon iconify="ph:dots-three-outline-vertical-fill" class="w-[18px] h-[18px]" />
        </:trigger>

        <li><button phx-click="...">{l("Copy link")}</button></li>
      </Dropdown>

  A hover fly-out submenu:

      <Dropdown id="ext_submenu" open_on="hover" position="right-start" trigger_class="btn btn-sm btn-ghost btn-square">
        <:trigger><#Icon iconify="ph:caret-right" class="w-4 h-4" /></:trigger>
        ...
      </Dropdown>
  """
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "Unique DOM id — used to derive the trigger/panel ids and link them via aria."
  prop id, :string, required: true

  @doc "floating-ui placement, e.g. `bottom-end`, `top-end`, `right-start`. Sent to the hook as `data-position`."
  prop position, :string, default: "bottom-end"

  @doc "How the menu opens: `click` (default) or `hover` (for fly-out submenus). Sent to the hook as `data-trigger`."
  prop open_on, :string, default: "click"

  @doc "Set to `fixed` to position relative to the viewport — escapes `overflow: hidden/clip` ancestors."
  prop strategy, :string, default: nil

  @doc "Disable floating-ui's auto-flip (keep the menu on the requested side)."
  prop no_flip, :boolean, default: false

  @doc "Close the panel when an actionable element inside it is clicked — for select-style dropdowns."
  prop close_on_select, :boolean, default: false

  @doc "Extra classes on the hook wrapper (always includes `relative`), e.g. `w-full`."
  prop wrapper_class, :css_class, default: nil

  @doc "Classes for the trigger button, e.g. `btn btn-ghost btn-circle btn-sm`."
  prop trigger_class, :css_class, default: nil

  @doc "Extra classes appended to the panel's standard `tooltip menu dropdown-panel`, e.g. `!pt-0   divide-hair divide-secondary` or `!w-72`."
  prop panel_class, :css_class, default: nil

  @doc "Render the panel as a DaisyUI `menu` list (default). Set false for a plain content panel."
  prop menu, :boolean, default: true

  @doc "Accessible label for the trigger button."
  prop label, :string, default: nil

  @doc "Extra attributes spread onto the trigger button."
  prop trigger_opts, :keyword, default: []

  @doc "Extra attributes spread onto the hook wrapper (e.g. `[\"data-id\": \"more_menu\"]`)."
  prop wrapper_opts, :keyword, default: []

  @doc "The trigger content (icon/avatar). This component wraps it in the trigger button."
  slot trigger, required: true

  @doc "The menu items (`<li>`s) or panel content."
  slot default, required: true
end
