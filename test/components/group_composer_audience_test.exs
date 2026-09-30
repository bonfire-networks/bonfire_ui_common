defmodule Bonfire.UI.Common.GroupComposerAudienceTest do
  use ExUnit.Case, async: true
  @moduletag :ui

  alias Bonfire.UI.Common.SmartInputLive
  doctest SmartInputLive, import: true, only: [group_audience_label: 3, group_audience_icon: 3, custom_audience?: 2, reply_audience_label: 1]

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

  test "reply and quote overrides retain the reading audience label and icon" do
    for verb <- ["reply", "quote", :reply, :quote],
        value <- [:can, :cannot, nil],
        {boundary, label, icon} <- [
          {"public", "Public (federated)", "ph:globe-duotone"},
          {"members:private", "Members only", "ph:lock-duotone"}
        ] do
      permissions = %{verb => %{"circle-id" => value}}
      assert SmartInputLive.group_audience_label([{boundary, "Ignored"}], [], permissions) == label
      assert SmartInputLive.group_audience_icon([boundary], [], permissions) == icon
    end
  end

  test "reading overrides and unknown rules remain custom alongside interaction overrides" do
    for verb <- ["read", "see", :read, :see, "unknown-rule"],
        value <- [:can, :cannot] do
      permissions = %{"reply" => %{"circle-id" => :cannot}, verb => %{"circle-id" => value}}
      assert SmartInputLive.group_audience_label(["public"], [], permissions) == "Custom audience"
      assert SmartInputLive.group_audience_icon(["public"], [], permissions) == "ph:shield-check-duotone"
    end

    permissions = %{"reply" => %{"circle-id" => :cannot}}
    assert SmartInputLive.group_audience_label(["public"], ["excluded-circle"], permissions) == "Custom audience"
    assert SmartInputLive.group_audience_label(["public", "members:private"], [], permissions) == "Custom audience"
    assert SmartInputLive.group_audience_label(["unknown-policy"], [], permissions) == "Custom audience"
    assert SmartInputLive.group_audience_label(["public"], [], nil) == "Custom audience"
  end

end
