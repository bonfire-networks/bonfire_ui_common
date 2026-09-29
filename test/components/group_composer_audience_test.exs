defmodule Bonfire.UI.Common.GroupComposerAudienceTest do
  use ExUnit.Case, async: true
  @moduletag :ui

  alias Bonfire.UI.Common.SmartInputLive
  doctest SmartInputLive, import: true, only: [group_audience_label: 3, group_audience_icon: 3]

  test "uses the current post visibility instead of inferring privacy from the group" do
    assert SmartInputLive.group_audience_label(["public"], [], %{}) == "Public (federated)"
    assert SmartInputLive.group_audience_label("nonfederated", [], %{}) == "Public"
    assert SmartInputLive.group_audience_label(["local:unlisted"], [], %{}) == "Unlisted (local)"
  end

  test "unknown or overridden policies do not promise a preset audience" do
    for boundary <- [nil, [], ["unknown-policy"], ["01M3MCD5V1APZJTN60XRSA0MN4"]] do
      assert SmartInputLive.group_audience_label(boundary, [], %{}) == "Custom audience"
    end

    assert SmartInputLive.group_audience_label(["members:private"], [], %{read: false}) ==
             "Custom audience"
  end
end
