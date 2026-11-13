defmodule Bonfire.UI.Common.WidgetFeedbackTest do
  @moduledoc "The wishes widget asks people what they want of the place: a link to a form the instance names, or, with no form, the composer opened into a group or topic the instance picks. Its words, link and group are instance settings, which the getting-started checklist's wishes step reads too."
  # instance settings are read with `Config.get`, primed per test process with `Process.put`
  use Bonfire.UI.Common.ConnCase, async: true
  @moduletag :ui

  alias Bonfire.UI.Common.WidgetFeedbackLive
  alias Bonfire.UI.Common.WidgetGettingStartedLive

  @app :bonfire_ui_common

  defp put_setting(key, value), do: Process.put([@app, WidgetFeedbackLive, key], value)

  defp render_widget(user) do
    assigns =
      WidgetFeedbackLive
      |> Surface.default_props()
      |> Map.new()
      |> Map.put(:__context__, %{current_user: user})

    Phoenix.LiveViewTest.render_component(&WidgetFeedbackLive.render/1, assigns)
    |> Floki.parse_document!()
  end

  setup do
    # no flavour's form leaks in: every test names its own destination, or none
    Process.put([@app, WidgetGettingStartedLive, :wishes_url], nil)
    {:ok, me: fake_user!(fake_account!())}
  end

  describe "with a link to a form" do
    setup do
      put_setting(:url, "https://wishes.example.local/form")
      :ok
    end

    test "shows the instance's words and links to its form, for guests too", %{me: me} do
      put_setting(:title, "What should we build?")
      put_setting(:text, "Tell the admins what you miss.")

      for viewer <- [me, nil] do
        doc = render_widget(viewer)

        assert Floki.text(Floki.find(doc, "[data-id=widget_feedback]")) =~ "What should we build?"

        assert Floki.text(Floki.find(doc, "[data-id=widget_feedback]")) =~
                 "Tell the admins what you miss."

        assert Floki.attribute(doc, "[data-id=widget_feedback_cta]", "href") ==
                 ["https://wishes.example.local/form"]
      end
    end

    test "uses the default words when the instance set none", %{me: me} do
      doc = render_widget(me)

      assert Floki.text(Floki.find(doc, "[data-id=widget_feedback] [data-role=widget-heading]")) =~
               "Feedback"

      assert Floki.text(Floki.find(doc, "[data-id=widget_feedback]")) =~
               "Help shape what comes next"
    end

    test "the getting-started step keeps its own declared words until the instance sets some" do
      assert %{title: "Tell us about your wishes", cta_label: "Share your wishes"} =
               WidgetGettingStartedLive.actions_registry()[:wishes]
    end

    test "the getting-started step shows the same words, and the widget's own button" do
      put_setting(:title, "What should we build?")

      assert %{
               title: "What should we build?",
               cta_kind: :stateless_component,
               cta_component: Bonfire.UI.Common.FeedbackCtaLive
             } = WidgetGettingStartedLive.actions_registry()[:wishes]
    end
  end

  test "a flavour's own wishes_url still works as the default link", %{me: me} do
    Process.put(
      [@app, WidgetGettingStartedLive, :wishes_url],
      "https://flavour.example.local/wishes"
    )

    assert Floki.attribute(render_widget(me), "[data-id=widget_feedback_cta]", "href") ==
             ["https://flavour.example.local/wishes"]

    assert %{cta_component: Bonfire.UI.Common.FeedbackCtaLive} =
             WidgetGettingStartedLive.actions_registry()[:wishes]
  end

  describe "with no form but a group to post in" do
    setup do
      put_setting(:context_id, "01GR0VPF0RWISHES00000000000")
      put_setting(:template, "My wish: ")
      :ok
    end

    test "opens the composer in that group, with the template", %{me: me} do
      doc = render_widget(me)

      assert [click] = Floki.attribute(doc, "button[data-id=widget_feedback_cta]", "phx-click")
      assert click =~ "01GR0VPF0RWISHES00000000000"

      # the composer drops text pushed with its opts, so the template is set by an event of the widget's own
      assert click =~ "Bonfire.UI.Common.WidgetFeedbackLive:fill_composer"
      assert Floki.attribute(doc, "a[data-id=widget_feedback_cta]", "href") == []
    end

    test "fills the composer with the template", %{me: me} do
      test_pid = self()

      Repatch.patch(
        Bonfire.UI.Common.SmartInput.LiveHandler,
        :set_smart_input_text,
        fn _socket, text ->
          send(test_pid, {:composer_text, text})
          :ok
        end
      )

      socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, current_user: me}}

      assert {:noreply, _} = WidgetFeedbackLive.handle_event("fill_composer", %{}, socket)
      assert_receive {:composer_text, "My wish: "}
    end

    test "shows nothing to a guest, who has no composer" do
      assert Floki.find(render_widget(nil), "[data-id=widget_feedback]") == []
    end

    test "the getting-started step uses the widget's own button" do
      assert %{cta_kind: :stateless_component, cta_component: Bonfire.UI.Common.FeedbackCtaLive} =
               WidgetGettingStartedLive.actions_registry()[:wishes]
    end
  end

  test "a group setting that isn't an id, eg. the select's empty choice saved as a module, counts as none",
       %{me: me} do
    put_setting(:context_id, None)

    assert WidgetFeedbackLive.cta() == nil
    assert Floki.find(render_widget(me), "[data-id=widget_feedback]") == []
  end

  test "with neither a form nor a group, the widget and the step stay hidden", %{me: me} do
    assert Floki.find(render_widget(me), "[data-id=widget_feedback]") == []
    refute Map.has_key?(WidgetGettingStartedLive.actions_registry(), :wishes)
  end

  test "offers the instance's groups to post feedback in, after a none option", %{me: me} do
    group = Bonfire.Classify.Simulate.fake_group!(me, %{name: "Wishes and ideas"})

    options = WidgetFeedbackLive.context_options(%{current_user: me})

    assert {"", _none} = List.first(options)
    assert {id(group), "Wishes and ideas"} in options
  end

  test "is declared as the :wishes widget" do
    assert %{id: :wishes, name: "Feedback"} = WidgetFeedbackLive.declared_widget()
  end
end
