defmodule Bonfire.UI.Common.ChangeLocaleLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.Common.Localise

  prop locale, :any
  prop scope, :any, default: nil
  prop live_handler, :string
end
