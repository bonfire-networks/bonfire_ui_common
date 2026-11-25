defmodule Bonfire.UI.Common.WidgetRegistryTest do
  @moduledoc "What `declare_widget` records for each widget, which is what places and their settings are built from."
  use ExUnit.Case, async: true

  # bucket this into the ui CI leg: bare `ExUnit.Case` skips the tag the extension case templates apply
  @moduletag :ui

  alias Bonfire.UI.Common.WidgetModule

  @dashboard_main_ids [
    :welcome,
    :instance_pinned,
    :trending_discussions,
    :polls_closing_soon,
    :suggested_profiles
  ]

  defp declared, do: Enum.reject(WidgetModule.widgets(), &is_nil/1)
  defp by_id(id), do: Enum.find(declared(), &(&1.id == id))

  test "every declared widget says what places and settings need, with defaults" do
    assert [_ | _] = declared()

    for widget <- declared() do
      assert is_atom(widget.id) and not is_nil(widget.id), "#{inspect(widget.module)} has no id"
      assert is_binary(widget.name)
      assert widget.width in [:narrow, :wide, :any]
      assert is_boolean(widget.current_user_required)
      assert is_boolean(widget.embeddable)
      assert is_list(widget.props)
    end
  end

  test "ids are unique, as settings and places key on them" do
    ids = Enum.map(declared(), & &1.id)
    assert ids == Enum.uniq(ids)
  end

  test "the dashboard's main-area widgets are all declared" do
    ids = Enum.map(declared(), & &1.id)

    for id <- @dashboard_main_ids do
      assert id in ids, "#{inspect(id)} is not declared"
    end
  end

  test "a widget only for signed-in people says so, and isn't embeddable by default" do
    assert %{
             module: Bonfire.UI.Social.WidgetTrendingDiscussionsLive,
             current_user_required: true,
             embeddable: false,
             width: :any
           } = by_id(:trending_discussions)
  end

  test "a widget that doesn't declare a width fits the main area or a sidebar" do
    assert %{width: :any} = by_id(:welcome)
    assert %{width: :any} = by_id(:community_rules)
  end

  test "the widgets made for the dashboard's sidebar are declared narrow, and are there for the right people" do
    assert %{module: Bonfire.Tag.Web.WidgetTagsLive, width: :narrow} = by_id(:popular_topics)

    assert %{module: Bonfire.UI.Social.WidgetTrendingLinksLive, width: :narrow} =
             by_id(:trending_links)

    assert %{module: Bonfire.UI.Me.WidgetHighlightUsersLive, width: :narrow} =
             by_id(:recent_users)

    assert %{
             module: Bonfire.UI.Common.WidgetGettingStartedLive,
             width: :narrow,
             current_user_required: true
           } = by_id(:getting_started)

    assert %{
             module: Bonfire.UI.Articles.WidgetRecentArticlesLive,
             width: :narrow,
             current_user_required: true,
             props: props
           } = by_id(:recent_articles)

    assert props[:limit] == 5
    assert props[:image_position] == :bottom
    assert is_binary(props[:widget_title])
  end

  test "a widget guests can see is embeddable by default, and keeps its declared props" do
    assert %{
             module: Bonfire.UI.Reactions.PinnedCarouselLive,
             current_user_required: false,
             embeddable: true,
             width: :wide,
             props: props
           } = by_id(:instance_pinned)

    assert props[:hide_empty] == true
  end

  test "Who to follow is only for signed-in people, so guests' places don't offer it" do
    assert %{current_user_required: true} = by_id(:suggested_profiles)
  end

  test "the moderators widget is one widget, for everyone" do
    assert %{module: Bonfire.UI.Me.WidgetModsLive, current_user_required: false} = by_id(:mods)
  end

  test "the guest home's groups, rules and community links are declared, for everyone" do
    assert %{module: Bonfire.UI.Groups.WidgetGroupsCarouselLive, width: :wide} = by_id(:groups)

    assert %{module: Bonfire.CommunityRules.Web.WidgetRulesLive, current_user_required: false} =
             by_id(:community_rules)

    assert %{module: Bonfire.UI.Common.WidgetCommunityLinksLive, current_user_required: false} =
             by_id(:community_links)
  end

  test "the guest home's introduction and instance facts are declared" do
    assert %{module: Bonfire.UI.Me.WidgetIntroLive, width: :wide} = by_id(:intro)

    assert %{module: Bonfire.UI.Me.WidgetInstanceFactsLive, current_user_required: false} =
             by_id(:instance_facts)
  end

  test "the feed is one widget, full width, for everyone" do
    assert %{
             module: Bonfire.UI.Social.WidgetFeedLive,
             name: "Feed",
             width: :wide,
             current_user_required: false
           } = by_id(:feed)
  end

  test "the welcome widget is for everyone" do
    assert %{current_user_required: false} = by_id(:welcome)
  end

  describe "custom widgets" do
    alias Bonfire.UI.Common.Widgets

    # Config.get reads these per test process
    defp put_custom(custom),
      do: Process.put([:bonfire_ui_common, Bonfire.UI.Common.Widgets, :custom], custom)

    defp custom_ids, do: for(%{id: id} <- Widgets.registry(), id in [:custom_text], do: id)

    test "an admin's custom widget is in the registry next to the declared ones, rendered as markdown text" do
      put_custom(%{text: %{title: "Start here", text: "Read **the guide**"}})

      assert %{
               id: :custom_text,
               name: "Start here",
               module: Bonfire.UI.Common.WidgetTextLive,
               width: :any,
               current_user_required: false,
               embeddable: true,
               props: props
             } = Enum.find(Widgets.registry(), &(&1.id == :custom_text))

      assert props[:widget_title] == "Start here"
      assert props[:text] == "Read **the guide**"

      assert Enum.find(Widgets.registry(), &(&1.id == :trending_discussions)),
             "the declared widgets are still there"
    end

    test "a custom widget can be wide" do
      put_custom(%{text: %{title: "Start here", text: "Hello", width: :wide}})

      assert %{width: :wide} = Enum.find(Widgets.registry(), &(&1.id == :custom_text))
    end

    test "a custom widget can be for a sidebar only" do
      put_custom(%{text: %{title: "Start here", text: "Hello", width: "narrow"}})

      assert %{width: :narrow} = Enum.find(Widgets.registry(), &(&1.id == :custom_text))
    end

    test "a custom widget with no text isn't offered anywhere" do
      put_custom(%{text: %{title: "Start here", text: ""}})
      assert custom_ids() == []

      put_custom(nil)
      assert custom_ids() == []
    end
  end
end
