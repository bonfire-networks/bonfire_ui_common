if Bonfire.Common.Extend.module_enabled?(LiveViewNative) do
  defmodule Bonfire.UI.Common.Themes.Default.App.SwiftUI do
    use LiveViewNative.Stylesheet, :swiftui

    # Add your styles here
    # Refer to your client's documentation on what the proper syntax
    # is for defining rules within classes
    ~SHEET"""

    """

    def class("main_header") do
      ~RULES"""
        toolbar(content: :toolbar)
        navigationTitle(:title)
        toolbarTitleMenu(content: :content)
        navigationBarTitleDisplayMode(.inline)
        toolbarBackgroundVisibility(.visible, for: .navigationBar)
        toolbarBackground(.ultraThinMaterial, for: .navigationBar)
      """
    end

    def class("simple_header") do
      ~RULES"""
        toolbar(content: :toolbar)
        navigationTitle(:title)
        navigationBarTitleDisplayMode(.inline)
      """
    end

    def class("detents:" <> props) do
      [height, size] = String.split(props, ":")

      # {height, _} = Integer.parse(height)

      ~RULES"""
      presentationDetents([.{height}, .{size}])
      """
    end

    def class("dragindicator:" <> props) do
      ~RULES"""
      presentationDragIndicator(.{props})
      """
    end

    def class("ultrathinmaterial") do
      ~RULES"""
      presentationBackground(.ultraThinMaterial)
      """
    end

    # If you need to have greater control over how your style rules are created
    # you can use the function defintion style which is more verbose but allows
    # for more fine-grained controled
    #
    # This example shows what is not possible within the more concise ~SHEET
    # use `<Text class="frame:w100:h200" />` allows for a setting
    # of both the `width` and `height` values.

    # def class("frame:" <> dims) do
    #   [width] = Regex.run(~r/w(\d+)/, dims, capture: :all_but_first)
    #   [height] = Regex.run(~r/h(\d+)/, dims, capture: :all_but_first)

    #   ~RULES"""
    #   frame(width: {width}, height: {height})
    #   """
    # end
  end
end
