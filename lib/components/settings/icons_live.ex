defmodule Bonfire.UI.Common.SettingsViewsLive.IconsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  def list do
    :application.get_key(
      Application.get_env(:iconify_ex, :generated_icon_app, :bonfire),
      :modules
    )
    ~> Enum.filter(&String.starts_with?("#{&1}", "Elixir.Iconify"))
    |> Enum.group_by(fn mod ->
      String.split("#{mod}", ".", parts: 4)
      |> Enum.at(2)
    end)
  end
end
