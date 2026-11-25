defmodule Bonfire.UI.Common.WidgetWelcomeLive do
  @moduledoc "The instance's welcome text, as admins write it in instance settings (`[:ui, :theme, :instance_welcome, :title | :description]`, the same text the guest home's intro shows), rendered as markdown. Renders nothing while there's no description."
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.Common.Config

  declare_widget(l("Welcome"), id: :welcome, skeleton: :text)

  @doc "The welcome title and text, or `nil` when the instance has written no text."
  def welcome do
    case Config.get([:ui, :theme, :instance_welcome, :description], nil) do
      text when is_binary(text) and text != "" ->
        %{title: Config.get([:ui, :theme, :instance_welcome, :title], nil), text: text}

      _ ->
        nil
    end
  end
end
