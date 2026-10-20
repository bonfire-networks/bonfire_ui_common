defmodule Bonfire.UI.Common.SmartInputModuleToggleTest do
  @moduledoc """
  A smart input type declared by a module of an extension that is enabled and disabled at runtime follows that toggle: it is not offered while disabled, and it is back as soon as it is enabled again, with no cache to clear in between.

  `all_smart_input_components/0` reads the map `SmartInputModule.smart_input_modules_types/0` builds through `ExtensionBehaviour.apply_modules_cached/2`. The divlab test (`group_tasks_setting_test.exs`) resets that cache entry in `on_exit` because filling it while the extension is disabled used to leave the type out of every later test.
  """
  use ExUnit.Case, async: false

  @moduletag :ui

  alias Bonfire.Common.Testing
  alias Bonfire.UI.Common.SmartInput.LiveHandler, as: SmartInputLiveHandler

  # declares a smart input type, in an extension that is enabled in every flavour
  @module Bonfire.UI.Social.WritePostContentLive
  @extension :bonfire_ui_social

  # the components are a map holding both directions (`type => module`, `schema => module`, `module => types`), so a component is named by the first type it declares
  test "smart_input_name/1 names a component by its first declared type, and has none while the extension is disabled" do
    [type | _] = List.wrap(@module.smart_input_module())
    name = to_string(type)

    assert SmartInputLiveHandler.smart_input_name(@module) == name

    during =
      Testing.with_extension_disabled(@extension, fn ->
        SmartInputLiveHandler.smart_input_name(@module)
      end)

    refute during == name

    assert SmartInputLiveHandler.smart_input_name(@module) == name
  end

  test "a type of a toggled extension is not offered while it is disabled, and is back once it is enabled" do
    during =
      Testing.with_extension_disabled(@extension, fn ->
        SmartInputLiveHandler.all_smart_input_components()
      end)

    refute Map.has_key?(during, @module)

    # the map the lookup above built is what the module declares, enabled or not: it is cached, and must not keep the module out once it is enabled
    assert Map.has_key?(SmartInputLiveHandler.all_smart_input_components(), @module)
  end
end
