defmodule Bonfire.UI.Common.SmartInputModule do
  @moduledoc """
  Find a smart input module via the object type(s) it can create, or vice versa. Backed by a global cache of known smart input modules.

  To add a module to this list, you should declare `@behaviour Bonfire.UI.Common.SmartInputModule` in it and define a `smart_input_module/0` function which returns a list of object types that it can create.

  Example:
  ```
  @behaviour Bonfire.UI.Common.SmartInputModule
  def smart_input_module, do: [:page, Bonfire.Pages.Page]
  ```

  You can then open the smart input composer / object creator using that declared type, for example:
  ```
  <Bonfire.UI.Common.SmartInputButtonLive
    create_object_type={:page}
    prompt={l("New page")}
    icon="mdi:pencil"
  />
  ```
  """
  @behaviour Bonfire.Common.ExtensionBehaviour
  use Bonfire.Common.Utils, only: []

  @doc "Declares a smart input module"
  @callback smart_input_module() :: any

  def app_modules() do
    Bonfire.Common.ExtensionBehaviour.behaviour_app_modules(__MODULE__)
  end

  @spec modules() :: [atom]
  def modules() do
    Bonfire.Common.ExtensionBehaviour.behaviour_modules(__MODULE__)
  end

  @doc "Returns a list of smart input modules and the object type(s) it can create, and vice versa."
  def smart_input_modules_types() do
    Bonfire.Common.ExtensionBehaviour.apply_modules_cached(modules(), :smart_input_module)
  end
end
