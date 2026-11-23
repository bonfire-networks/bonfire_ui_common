defmodule Bonfire.UI.Common.FeedFilterRowLive do
  @moduledoc """
  One collapsible row of the feed filters editor: a `<details>` with a summary (label, current value, chevron) and the row's controls as the body. Shared by the editor's own rows and by rows that extensions declare (see `Bonfire.UI.Common.FeedFilterControlModule`).
  """
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "The editor's DOM id, used to build this row's own id."
  prop id, :string, required: true
  @doc "The row's key, as in `data-row`."
  prop name, :string, required: true
  prop label, :string, required: true
  @doc "The text shown in the summary: the current value."
  prop value, :string, default: nil

  @doc "Whether the value differs from the default (shown in the primary colour, else muted). Leave unset for no colour class."
  prop active, :boolean, default: nil
  @doc "Extra classes for the value, eg. a max width."
  prop value_class, :string, default: nil
  @doc "Whether the row starts expanded."
  prop open, :boolean, default: false
  @doc "DOM id for the label, if something refers to it."
  prop label_id, :string, default: nil
  @doc "Event the summary itself sends when pressed, if any."
  prop click, :string, default: nil
  @doc "`phx-target` for that event."
  prop target, :any, default: nil

  slot default
end
