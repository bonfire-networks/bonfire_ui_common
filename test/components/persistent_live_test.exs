defmodule Bonfire.UI.Common.PersistentLiveTest do
  use ExUnit.Case, async: true

  @moduletag :ui

  alias Bonfire.UI.Common.PersistentLive

  test "forwards the outer page and selected tab to sticky navigation" do
    assigns = %{
      __context__: %{sticky: true},
      page: "profile",
      selected_tab: :followers
    }

    assert PersistentLive.maybe_send_assigns(assigns)

    assert_receive {:assign_persistent_self,
                    %{page: "profile", selected_tab: :followers}}
  end
end
