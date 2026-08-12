defmodule Bonfire.UI.Common.CoreComponentsTest do
  use ExUnit.Case, async: true

  # bucket this into the ui CI leg: bare `ExUnit.Case` skips the tag the extension case templates apply, so without it this also runs in the federation job catch-all
  @moduletag :ui

  alias Bonfire.UI.Common.CoreComponents
  alias Phoenix.LiveView.JS

  doctest Bonfire.UI.Common.CoreComponents, only: [css_class: 1]

  describe "motion commands" do
    test "show uses an explicit composite-only transition" do
      assert [
               [
                 "show",
                 %{
                   time: 250,
                   to: "#target",
                   transition: [
                     [
                       "transition-[opacity,transform]",
                       "ease-[cubic-bezier(0.19,1,0.22,1)]",
                       "duration-250"
                     ],
                     ["opacity-0", "translate-y-4", "sm:translate-y-0", "sm:scale-95"],
                     ["opacity-100", "translate-y-0", "sm:scale-100"]
                   ]
                 }
               ]
             ] = CoreComponents.show("#target") |> JS.to_encodable()
    end

    test "hide is quicker than entry and does not use ease-in" do
      encoded = CoreComponents.hide("#target") |> JS.to_encodable()

      assert [["hide", %{time: 150}]] = encoded
      refute inspect(encoded) =~ "transition-all"
      refute inspect(encoded) =~ "ease-in"
    end
  end
end
