defmodule Bonfire.UI.Common.SettingsSelectLiveTest do
  @moduledoc """
  `Bonfire.UI.Common.SettingsSelectLive` shows what is in effect: this scope's own choice, else what a parent scope chose, else its default. A select has no placeholder to hint at an inherited value, so with no option marked the browser would show its first one as if it were chosen.
  """
  use Bonfire.UI.Common.ConnCase, async: true

  use Bonfire.Common.Settings

  @keys [:test_settings_select, :choice]
  @options [first: "First", second: "Second", third: "Third"]

  setup do
    account = fake_account!()
    {:ok, account: account, user: fake_user!(account)}
  end

  defp selected(user, account, opts \\ []) do
    render_component(
      &Bonfire.UI.Common.SettingsSelectLive.render/1,
      Map.merge(
        %{
          id: "test-settings-select",
          keys: @keys,
          options: @options,
          __context__: %{
            current_user: Bonfire.Me.Users.get_current(user.id),
            current_account: account
          }
        },
        Map.new(opts)
      )
    )
    |> Floki.parse_document!()
    |> Floki.attribute("#test-settings-select option[selected]", "value")
  end

  test "with nothing chosen anywhere, it shows its default", %{user: user, account: account} do
    assert selected(user, account, default_value: :third) == ["third"]
  end

  test "with nothing of its own, it shows what the account chose", %{
    user: user,
    account: account
  } do
    {:ok, _} = Settings.put(@keys, :second, current_account: account, scope: :account)

    assert selected(user, account, default_value: :third) == ["second"]
  end

  test "its own choice wins over the account's", %{user: user, account: account} do
    {:ok, _} = Settings.put(@keys, :second, current_account: account, scope: :account)
    Settings.put(@keys, :third, current_user: user)

    assert selected(user, account) == ["third"]
  end
end
