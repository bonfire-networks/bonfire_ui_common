defmodule Bonfire.UI.Common.ViewCodeLiveTest do
  use Bonfire.UI.Common.ConnCase, async: true

  @moduletag :ui

  setup do
    account = fake_account!()
    me = fake_user!(account)

    {:ok, conn: conn(user: me, account: account)}
  end

  test "source lines are numbered as #L links, and the selected function's line is highlighted",
       %{
         conn: conn
       } do
    conn
    |> visit("/settings/extensions/code/Bonfire.Common.Text/code_syntax")
    |> wait_async()
    |> assert_has("span#L1.l-line a.l-line-number[href='#L1']", text: "1")
    # matched on one token, since PhoenixTest drops the whitespace-only text node between `def` and the function name
    |> assert_has(".l-line.l-highlighted .l-function", text: "code_syntax")
    |> refute_has("#left_gutter")
  end
end
