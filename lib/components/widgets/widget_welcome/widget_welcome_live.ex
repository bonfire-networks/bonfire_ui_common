defmodule Bonfire.UI.Common.WidgetWelcomeLive do
  @moduledoc "The instance's header and admin-written welcome text, followed by its facts (At a glance) unless the viewer turned them off."
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.Common.Config

  declare_widget(l("Welcome"),
    id: :welcome,
    skeleton: :text,
    # each member chooses in edit mode whether the facts show
    settings: Bonfire.UI.Common.WidgetWelcomeFactsLive
  )

  @doc "Whether the viewer shows the instance's facts under the welcome text; on by default."
  def show_facts?(context),
    do: Bonfire.Common.Settings.get([__MODULE__, :show_facts], true, context) != false

  @doc "The instance's name and member count for the header, cached for a minute."
  def community,
    do: Bonfire.Common.Cache.maybe_apply_cached(&load_community/0, [], expire: 60_000)

  @doc false
  def load_community do
    %{
      name: Bonfire.UI.Common.GuestBoardLive.instance_name(),
      # `nil` when the admin hides the member count, as nodeinfo and the Mastodon API do
      members: maybe_apply(Bonfire.Me.Users, :maybe_count, [:local], fallback_return: nil)
    }
  end

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
