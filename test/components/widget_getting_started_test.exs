defmodule Bonfire.UI.Common.WidgetGettingStartedTest do
  @moduledoc """
  Tests for the getting-started widget.

  The widget declares no steps of its own, so these seed a registry of their own instead of asserting on whatever the installed extensions declare. Each extension's real declaration, and its completion detector, is tested where it lives.
  """
  # not async: the registry and the chosen order are instance-wide config, and these tests replace them
  use Bonfire.UI.Common.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.UI.Common.WidgetGettingStartedLive
  alias Bonfire.Common.Settings

  # a module no instance has, to stand for a step whose extension is switched off here
  @disabled_module Bonfire.UI.Common.WidgetGettingStartedTest.NoSuchExtension

  describe "render_state/1" do
    test "stays hidden when the user has dismissed the widget" do
      assigns = %{dismissed?: true, total_count: 3, current: nil, celebrating?: false}
      assert WidgetGettingStartedLive.render_state(assigns) == :hidden
    end

    test "stays hidden when the instance has no actions configured" do
      assigns = %{dismissed?: false, total_count: 0, current: nil, celebrating?: false}
      assert WidgetGettingStartedLive.render_state(assigns) == :hidden
    end

    test "stays hidden when the user already had everything done before the widget existed" do
      assigns = %{dismissed?: false, total_count: 3, current: nil, celebrating?: false}
      assert WidgetGettingStartedLive.render_state(assigns) == :hidden
    end

    test "celebrates when the user just finished the last step in this session" do
      assigns = %{dismissed?: false, total_count: 3, current: nil, celebrating?: true}
      assert WidgetGettingStartedLive.render_state(assigns) == :celebrate
    end

    test "shows the focused step when work remains" do
      assigns = %{
        dismissed?: false,
        total_count: 3,
        current: %{key: :profile},
        celebrating?: false
      }

      assert WidgetGettingStartedLive.render_state(assigns) == :step
    end
  end

  describe "actions_registry/1 as the installed extensions declare it" do
    # no seeding here: this is what boot produced, and the point is that a keyword list under one config key collects declarations from several extensions instead of the last one winning
    test "collects the steps declared by different extensions" do
      registry = WidgetGettingStartedLive.actions_registry()

      # from bonfire_ui_me, bonfire_ui_posts and bonfire_ui_social_graph respectively
      for key <- [:profile, :first_post, :first_follow] do
        assert Map.has_key?(registry, key), "no #{key} step in #{inspect(Map.keys(registry))}"
      end
    end

    test "each declared step carries what its kind of action needs to render" do
      for {key, spec} <- WidgetGettingStartedLive.actions_registry() do
        assert is_binary(spec.title), "#{key} has no title"
        assert is_binary(e(spec, :rationale, nil)), "#{key} has no rationale"

        case e(spec, :cta_kind, :link) do
          :link ->
            assert is_binary(e(spec, :cta_path, nil)), "#{key} is a link to nowhere"
            assert is_binary(e(spec, :cta_label, nil)), "#{key} has no label on its link"

          :composer ->
            assert is_binary(e(spec, :cta_label, nil)), "#{key} has no label on its button"

          :button ->
            assert is_binary(e(spec, :cta_label, nil)), "#{key} has no label on its button"
            assert e(spec, :cta_event, nil), "#{key} has a button that fires nothing"

          kind when kind in [:stateful_component, :stateless_component] ->
            assert is_atom(e(spec, :cta_component, nil)) and e(spec, :cta_component, nil),
                   "#{key} names no component"

          other ->
            flunk("#{key} has an unknown cta_kind: #{inspect(other)}")
        end
      end
    end
  end

  describe "actions_registry/1" do
    test "drops a step whose extension is not enabled here" do
      put_config(
        actions_registry: [
          here: %{title: "here", cta_path: "/here"},
          elsewhere: %{title: "elsewhere", cta_path: "/elsewhere", needs: @disabled_module}
        ]
      )

      assert Map.keys(WidgetGettingStartedLive.actions_registry()) == [:here]
    end

    test "drops a link step the instance left with nowhere to go" do
      put_config(
        actions_registry: [
          configured: %{title: "configured", cta_path: {:config, :somewhere_path}},
          unconfigured: %{title: "unconfigured", cta_path: {:config, :nowhere_path}}
        ],
        somewhere_path: "/somewhere"
      )

      registry = WidgetGettingStartedLive.actions_registry()
      assert Map.keys(registry) == [:configured]
      assert registry[:configured].cta_path == "/somewhere"
    end

    test "keeps a component step, which needs no path" do
      put_config(
        actions_registry: [
          card: %{
            title: "card",
            cta_kind: :stateful_component,
            cta_component: WidgetGettingStartedLive,
            cta_path: nil
          }
        ]
      )

      assert Map.keys(WidgetGettingStartedLive.actions_registry()) == [:card]
    end

    test "falls back to the extension's own default where a flavour names no destination" do
      put_config(
        actions_registry: [
          conduct: %{title: "conduct", cta_path: {:config, :code_of_conduct_path, "/conduct"}}
        ]
      )

      assert WidgetGettingStartedLive.actions_registry()[:conduct].cta_path == "/conduct"
    end

    test "a flavour's own path wins over the extension's default" do
      put_config(
        actions_registry: [
          conduct: %{title: "conduct", cta_path: {:config, :code_of_conduct_path, "/conduct"}}
        ],
        code_of_conduct_path: "/rules-of-the-house"
      )

      assert WidgetGettingStartedLive.actions_registry()[:conduct].cta_path ==
               "/rules-of-the-house"
    end
  end

  describe "configured_actions/1" do
    test "offers every declared step when the instance names no order" do
      put_config(
        actions_registry: [
          first: %{title: "first", cta_path: "/first"},
          second: %{title: "second", cta_path: "/second"}
        ]
      )

      assert WidgetGettingStartedLive.configured_actions()
             |> Enum.map(& &1.key)
             |> Enum.sort() == [:first, :second]
    end

    test "honours the order the instance lists, and drops what it does not name" do
      put_config(
        actions_registry: [
          first: %{title: "first", cta_path: "/first"},
          second: %{title: "second", cta_path: "/second"}
        ],
        actions: [:second, :first]
      )

      assert Enum.map(WidgetGettingStartedLive.configured_actions(), & &1.key) ==
               [:second, :first]
    end

    test "passes over a step no enabled extension declared" do
      put_config(
        actions_registry: [
          here: %{title: "here", cta_path: "/here"},
          elsewhere: %{title: "elsewhere", cta_path: "/elsewhere", needs: @disabled_module}
        ],
        actions: [:here, :elsewhere, :never_declared]
      )

      assert Enum.map(WidgetGettingStartedLive.configured_actions(), & &1.key) == [:here]
    end

    test "drops anything that is not a step name" do
      put_config(
        actions_registry: [here: %{title: "here", cta_path: "/here"}],
        actions: [:here, %{key: :no_longer_supported}, "not an atom"]
      )

      assert Enum.map(WidgetGettingStartedLive.configured_actions(), & &1.key) == [:here]
    end
  end

  describe "viewing_step/1" do
    test "returns nil when there are no steps" do
      assert WidgetGettingStartedLive.viewing_step(%{steps: [], viewing_index: 0}) == nil
      assert WidgetGettingStartedLive.viewing_step(%{}) == nil
    end

    test "returns the step at viewing_index" do
      a = %{key: :a}
      b = %{key: :b}
      assert WidgetGettingStartedLive.viewing_step(%{steps: [a, b], viewing_index: 1}) == b
    end

    test "falls back to the first step when the index is out of bounds" do
      a = %{key: :a}
      b = %{key: :b}
      assert WidgetGettingStartedLive.viewing_step(%{steps: [a, b], viewing_index: 99}) == a
    end
  end

  describe "load_state/1" do
    test "treats anonymous users as already dismissed" do
      assert WidgetGettingStartedLive.load_state(nil) == {true, []}
    end

    test "returns defaults for a user with no settings yet" do
      account = fake_account!()
      me = fake_user!(account)

      assert {false, []} = WidgetGettingStartedLive.load_state(me)
    end

    test "round-trips dismissed and manual_done from user settings" do
      account = fake_account!()
      me = fake_user!(account)

      _ =
        Settings.put([:ui, :getting_started, :dismissed], true,
          current_user: me,
          scope: :user
        )

      # Reload between the two puts so the second one merges over the first
      # rather than overwriting it (Settings.put with a user that has stale
      # settings doesn't see the prior write).
      me = reload_with_settings(me)

      _ =
        Settings.put([:ui, :getting_started, :manual_done], ["profile", "first_post"],
          current_user: me,
          scope: :user
        )

      assert {true, manual} = WidgetGettingStartedLive.load_state(reload_with_settings(me))
      assert Enum.sort(manual) == ["first_post", "profile"]
    end
  end

  describe "handle_event navigation" do
    test "next wraps from last index to 0" do
      socket = build_socket(nil, %{viewing_index: 2, total_count: 3})

      assert {:noreply, socket} =
               WidgetGettingStartedLive.handle_event("next", %{}, socket)

      assert socket.assigns.viewing_index == 0
    end

    test "prev wraps from 0 to last index" do
      socket = build_socket(nil, %{viewing_index: 0, total_count: 3})

      assert {:noreply, socket} =
               WidgetGettingStartedLive.handle_event("prev", %{}, socket)

      assert socket.assigns.viewing_index == 2
    end

    test "next is a no-op when total_count is 0" do
      socket = build_socket(nil, %{viewing_index: 0, total_count: 0})

      assert {:noreply, socket} =
               WidgetGettingStartedLive.handle_event("next", %{}, socket)

      assert socket.assigns.viewing_index == 0
    end
  end

  describe "handle_event \"dismiss\"" do
    setup do
      account = fake_account!()
      me = fake_user!(account)
      {:ok, account: account, me: me}
    end

    test "flips dismissed? on and clears celebrating?", %{me: me} do
      socket = build_socket(me, %{celebrating?: true})

      assert {:noreply, socket} =
               WidgetGettingStartedLive.handle_event("dismiss", %{}, socket)

      assert socket.assigns.dismissed? == true
      assert socket.assigns.celebrating? == false
    end

    test "persists dismissed: true to the user's settings", %{me: me} do
      socket = build_socket(me)

      {:noreply, _} = WidgetGettingStartedLive.handle_event("dismiss", %{}, socket)

      assert {true, _} = WidgetGettingStartedLive.load_state(reload_with_settings(me))
    end
  end

  describe "handle_event \"mark_done\"" do
    setup do
      account = fake_account!()
      me = fake_user!(account)
      {:ok, account: account, me: me}
    end

    test "persists the manual entry to the user's settings", %{me: me} do
      socket = build_socket(me)

      {:noreply, _} =
        WidgetGettingStartedLive.handle_event("mark_done", %{"key" => "profile"}, socket)

      assert {_, manual} = WidgetGettingStartedLive.load_state(reload_with_settings(me))
      assert "profile" in manual
    end

    test "merges with existing manual_done without duplicates", %{me: me} do
      _ =
        Settings.put([:ui, :getting_started, :manual_done], ["profile"],
          current_user: me,
          scope: :user
        )

      socket = build_socket(me, %{manual_done: ["profile"]})

      {:noreply, _} =
        WidgetGettingStartedLive.handle_event("mark_done", %{"key" => "profile"}, socket)

      {:noreply, _} =
        WidgetGettingStartedLive.handle_event(
          "mark_done",
          %{"key" => "first_post"},
          build_socket(me, %{manual_done: ["profile"]})
        )

      assert {_, manual} = WidgetGettingStartedLive.load_state(reload_with_settings(me))
      assert Enum.sort(manual) == ["first_post", "profile"]
    end
  end

  describe "update/2" do
    setup do
      # a step nobody can complete by doing anything, so what the tests below see is only what they mark
      put_config(
        actions_registry: [
          profile: %{title: "profile", cta_path: "/profile", done?: fn _user -> false end}
        ],
        actions: [:profile]
      )
    end

    test "anonymous users see the widget hidden" do
      assert {:ok, socket} =
               WidgetGettingStartedLive.update(%{}, build_socket(nil))

      assert socket.assigns.dismissed? == true
      assert WidgetGettingStartedLive.render_state(socket.assigns) == :hidden
    end

    test "a fresh user sees the configured step as current and is not celebrating" do
      account = fake_account!()
      me = fake_user!(account)

      assert {:ok, socket} =
               WidgetGettingStartedLive.update(%{}, build_socket(me))

      assert %{key: :profile} = socket.assigns.current
      refute socket.assigns.celebrating?
      assert WidgetGettingStartedLive.render_state(socket.assigns) == :step
    end

    test "a manual mark counts as done even when the auto-detector says false" do
      account = fake_account!()
      me = fake_user!(account)

      _ =
        Settings.put([:ui, :getting_started, :manual_done], ["profile"],
          current_user: me,
          scope: :user
        )

      assert {:ok, socket} =
               WidgetGettingStartedLive.update(%{}, build_socket(reload_with_settings(me)))

      assert socket.assigns.current == nil
      assert socket.assigns.done_count == 1
    end

    test "a step the detector says is done needs no marking" do
      put_config(
        actions_registry: [
          profile: %{title: "profile", cta_path: "/profile", done?: fn _user -> true end}
        ],
        actions: [:profile]
      )

      account = fake_account!()
      me = fake_user!(account)

      assert {:ok, socket} =
               WidgetGettingStartedLive.update(%{}, build_socket(me))

      assert socket.assigns.current == nil
      assert socket.assigns.done_count == 1
    end
  end

  describe "fresh-completion celebration" do
    setup do
      put_config(
        actions_registry: [
          profile: %{title: "profile", cta_path: "/profile", done?: fn _user -> false end}
        ],
        actions: [:profile]
      )
    end

    test "fires when mark_done flips current from non-nil to nil" do
      account = fake_account!()
      me = fake_user!(account)

      assert {:ok, socket} =
               WidgetGettingStartedLive.update(%{}, build_socket(me))

      assert %{key: :profile} = socket.assigns.current
      refute socket.assigns.celebrating?

      assert {:noreply, socket} =
               WidgetGettingStartedLive.handle_event(
                 "mark_done",
                 %{"key" => "profile"},
                 socket
               )

      assert socket.assigns.current == nil
      assert socket.assigns.celebrating? == true
      assert WidgetGettingStartedLive.render_state(socket.assigns) == :celebrate
    end

    test "does not fire on first mount for a user who is already complete" do
      account = fake_account!()
      me = fake_user!(account)

      _ =
        Settings.put([:ui, :getting_started, :manual_done], ["profile"],
          current_user: me,
          scope: :user
        )

      assert {:ok, socket} =
               WidgetGettingStartedLive.update(%{}, build_socket(reload_with_settings(me)))

      assert socket.assigns.current == nil
      refute socket.assigns.celebrating?
      assert WidgetGettingStartedLive.render_state(socket.assigns) == :hidden
    end
  end

  # Replaces the whole config key for this module, since that is what holds both the registry and the chosen order, and puts back whatever the extensions declared at boot once the test ends
  defp put_config(opts) do
    previous = Application.get_env(:bonfire_ui_common, WidgetGettingStartedLive)
    Application.put_env(:bonfire_ui_common, WidgetGettingStartedLive, opts)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:bonfire_ui_common, WidgetGettingStartedLive, previous),
        else: Application.delete_env(:bonfire_ui_common, WidgetGettingStartedLive)
    end)

    :ok
  end

  # Settings.get only reads back DB-persisted values when the passed user has
  # `:settings` preloaded. fake_user!/1 doesn't preload it, so we refetch
  # before any assertion that goes through load_state/Settings.get.
  defp reload_with_settings(user),
    do: Bonfire.Common.Repo.maybe_preload(user, :settings, force: true)

  defp build_socket(user, extra_assigns \\ %{}) do
    base = %{
      __changed__: %{},
      current_user: user,
      dismissed?: false,
      celebrating?: false,
      steps: [],
      current: nil,
      viewing_index: 0,
      done_count: 0,
      total_count: 0,
      manual_done: []
    }

    %Phoenix.LiveView.Socket{assigns: Map.merge(base, extra_assigns)}
  end
end
