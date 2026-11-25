defmodule Bonfire.UI.Common.ImportSanitiseSettingLive do
  @moduledoc """
  An admin's choice of how the bodies of articles imported from a source are sanitised (see `Bonfire.Common.Text.maybe_sane_html/2`), as an instance setting under `keys`: keep their structure, or strict (basic formatting only). Unsafe (no sanitising) is only settable in config; when it's the current value, it shows as the choice, with a warning about what it allows, so saving the form doesn't change it unseen.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  # the instance setting, eg. `[:bonfire_wordpress, :sanitise]`
  prop keys, :list, required: true
  # the choice in effect, as the source reads it (its default when unset), eg. `:imported`
  prop current_value, :any, required: true
  prop id, :string, required: true
  prop data_role, :string, default: "sanitise_form"

  def options(current_value) do
    [
      {"imported", l("Keep their structure")},
      {"strict", l("Strict: basic formatting only")}
    ] ++ if(unsafe?(current_value), do: [{"unsafe", l("Unsafe (no sanitising)")}], else: [])
  end

  def unsafe?(current_value), do: to_string(current_value) == "unsafe"
end
