defmodule Bonfire.UI.Common.MultiselectLiveSelectTest do
  @moduledoc """
  Locks in the layout fix for the LiveSelect-backed multiselect in `:tags` mode.

  In tags mode LiveSelect renders the selected tags in a sibling block above the
  text input. With the daisyui defaults the input keeps its own `input-bordered`
  border (turning `input-primary`/orange once a tag is selected), so a tag + the
  field rendered as two stacked pills with a misplaced search icon. The fix makes
  the container the bordered box and the field borderless/transparent inside it.
  """
  use Bonfire.UI.Common.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Bonfire.UI.Common.LiveSelectIntegrationLive

  defp render_ls(mode, value, variant \\ :default) do
    assigns = %{
      form: Phoenix.Component.to_form(%{}, as: :multi_select),
      field: :selected_users,
      mode: mode,
      variant: variant,
      event_target: "#x",
      options: [],
      value: value,
      placeholder: "Search",
      update_min_len: 2,
      debounce: 300,
      disabled: false,
      type: nil
    }

    render_component(&LiveSelectIntegrationLive.live_select/1, assigns)
  end

  describe ":tags mode (with a selected tag)" do
    setup do
      %{html: render_ls(:tags, [%{id: "01ABCDEF", name: "some_strangetestuser7"}])}
    end

    test "renders the tag", %{html: html} do
      assert html =~ "some_strangetestuser7"
    end

    test "the container is the bordered box", %{html: html} do
      assert html =~ "rounded-2xl"
      assert html =~ "border-secondary"
      assert html =~ "focus-within:border-primary"
    end

    test "the text field is borderless/transparent (no input-bordered, no orange input-primary)",
         %{html: html} do
      # the field must not carry the daisyui input border, nor the selected-state
      # orange border, otherwise it reads as a second pill below the tag
      refute html =~ "input-bordered"
      refute html =~ "input-primary"
      assert html =~ "bg-transparent"
    end
  end

  describe ":single mode" do
    setup do
      %{html: render_ls(:single, nil)}
    end

    test "uses the themed bordered input", %{html: html} do
      assert html =~ "input input-sm"
      assert html =~ "border-hair"
      assert html =~ "border-secondary"
    end

    test "does not use the tags bordered-box container", %{html: html} do
      refute html =~ "focus-within:border-primary"
    end
  end

  describe ":filter variant in tags mode" do
    setup do
      %{
        html:
          render_ls(
            :tags,
            [%{id: "01ABCDEF", name: "Mira Cohen"}],
            :filter
          )
      }
    end

    test "renders selected people and the input in one wrapping field", %{html: html} do
      assert html =~ "min-h-[46px]"
      assert html =~ "flex-wrap"
      assert html =~ "rounded-[14px]"
      assert html =~ "[&amp;&gt;div]:flex-1"
      assert html =~ ~s(class="contents")
    end

    test "uses the guided chip and 16px ghost input styling", %{html: html} do
      assert html =~ "min-h-[34px]"
      assert html =~ "bg-primary/[0.14]"
      assert html =~ "text-[13px]"
      assert html =~ "text-base h-auto"
    end

    test "gives the remove control a visible icon, accessible name, and expanded hit area", %{
      html: html
    } do
      assert html =~ "Remove selection"
      assert html =~ "touch-target-hit-area"
      assert html =~ "×"
      refute html =~ "<#Icon"
    end
  end
end
