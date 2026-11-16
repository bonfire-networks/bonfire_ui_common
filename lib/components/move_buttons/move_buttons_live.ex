defmodule Bonfire.UI.Common.MoveButtonsLive do
  @moduledoc """
  Up and down buttons that move an item in an ordered list, for keyboard and touch users, who can't drag. Both send `event` with `values` plus `"direction" => "up" | "down"`.

  `first` and `last` turn off the button that would move the item off the list.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "The event both buttons send."
  prop event, :string, default: "move"

  @doc "Sent with the event as `phx-value-*`, beside `direction`: what moves, and where."
  prop values, :map, default: %{}

  @doc "The name of what moves, for screen readers."
  prop label, :string, required: true

  prop first, :boolean, default: false
  prop last, :boolean, default: false
  prop target, :any, default: nil

  @doc "Prefix of the buttons' ids, which end in `-up` and `-down`. No ids when `nil`."
  prop id, :string, default: nil

  prop class, :css_class, default: "btn btn-ghost btn-xs btn-square"
end
