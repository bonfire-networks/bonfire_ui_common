defmodule Bonfire.UI.Common.InputLabelGuardTest do
  @moduledoc """
  `.input` should render its own `<label>` wrapper only when a `label` is
  passed. Without it, an empty label wrapper shadows an external `<.label>`
  (the structure the Surface→LiveView Field conversion produces: a separate
  `<.label for={@id}>` sibling + the control). With the guard, the external
  label is the sole label and associates via `for`.
  """
  use Bonfire.UI.Common.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Bonfire.UI.Common.CoreComponents

  test "select with NO label renders no <label> element" do
    html =
      render_component(&CoreComponents.input/1, %{
        type: "select",
        id: "i",
        name: "n",
        options: [],
        value: nil
      })

    refute html =~ "<label"
  end

  test "select WITH a label renders one <label> containing it" do
    html =
      render_component(&CoreComponents.input/1, %{
        type: "select",
        id: "i",
        name: "n",
        options: [],
        value: nil,
        label: "Pick one"
      })

    assert html =~ "<label"
    assert html =~ "Pick one"
  end

  test "text input with NO label renders no <label> element" do
    html =
      render_component(&CoreComponents.input/1, %{type: "text", id: "i", name: "n", value: nil})

    refute html =~ "<label"
  end
end
