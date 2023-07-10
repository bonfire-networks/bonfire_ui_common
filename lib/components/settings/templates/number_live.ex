defmodule Bonfire.UI.Common.Settings.NumberLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop field_key, :any, default: nil
  prop settings_key, :any, required: true
  prop default, :number, default: 0
  prop name, :string, required: true
  prop description, :string, default: nil
  prop unit, :string, default: nil
  prop scope, :any, default: nil
  prop read_only, :boolean, default: false
  prop class, :css_class, default: "input input-sm w-20"
end
