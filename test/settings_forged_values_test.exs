defmodule Bonfire.UI.Common.SettingsForgedValuesTest do
  @moduledoc "A setting value sent by the browser is stored as plain data: it cannot be a struct or a module that exists on the server."
  use Bonfire.UI.Common.ConnCase, async: false
  @moduletag :ui

  import Phoenix.LiveViewTest, only: [live: 2, render_hook: 3]
  import Ecto.Query, only: [from: 2]
  use Bonfire.Common.Settings

  @module_name "Elixir.Bonfire.Data.Identity.User"

  setup do
    account = fake_account!()
    me = fake_user!(account)
    other = fake_user!(fake_account!())
    {:ok, view, _html} = live(conn(user: me, account: account), "/feed/my")

    %{me: me, other: other, view: view, account: account}
  end

  defp stored(me),
    do: Settings.get([:ui, :font_family], nil, current_user: Bonfire.Me.Users.get_current(me.id))

  # the forged value may crash the page when it is rendered after saving: only what was stored matters
  defp send_setting(view, event, value, extra \\ %{}) do
    render_hook(view, event, Map.merge(%{"ui" => %{"font_family" => value}}, extra))
  catch
    :exit, _ -> :ok
  end

  # the settings row read straight from the database through its Ecto type, bypassing every cache and the loaded user
  defp load(me) do
    json =
      Bonfire.Common.Config.repo().one(
        from(s in Bonfire.Data.Identity.Settings, where: s.id == ^me.id, select: s.json)
      )

    {:ok, get_in(json || %{}, [:bonfire, :ui, :font_family])}
  rescue
    e -> {:error, e}
  end

  defp load_id(id) do
    json =
      Bonfire.Common.Config.repo().one(
        from(s in Bonfire.Data.Identity.Settings, where: s.id == ^id, select: s.json)
      )

    {:ok, get_in(json || %{}, [:bonfire, :ui, :font_family])}
  end

  defp raw_json(me) do
    Bonfire.Common.Config.repo().one(
      from(s in Bonfire.Data.Identity.Settings,
        where: s.id == ^me.id,
        select: fragment("?::text", s.json)
      )
    )
  end

  # the stored value must come back as plain data: not a struct, not an atom (nil, true and false are atoms too)
  defp plain?(value),
    do: not is_struct(value) and not (is_atom(value) and value not in [nil, true, false])

  defp atom_exists?(name) do
    String.to_existing_atom(name)
    true
  rescue
    ArgumentError -> false
  end

  defp new_atom_name, do: "forged_atom_" <> Integer.to_string(System.unique_integer([:positive]))

  for event <- ["Bonfire.Common.Settings:set", "Bonfire.Common.Settings:save"] do
    describe "fresh load, #{event}" do
      test "control: a plain string survives a load straight from the database", %{
        me: me,
        view: view
      } do
        assert {:ok, nil} = load(me)
        send_setting(view, unquote(event), "Fira Sans")
        assert {:ok, "Fira Sans"} = load(me)
      end

      test "a forged struct does not come back as a struct", %{me: me, other: other, view: view} do
        assert {:ok, nil} = load(me)

        send_setting(view, unquote(event), %{"__struct__" => @module_name, "id" => other.id})

        assert {:ok, value} = load(me)
        assert plain?(value), "stored as #{inspect(raw_json(me))}"
      end

      test "a string naming a module does not come back as an atom", %{me: me, view: view} do
        assert {:ok, nil} = load(me)

        send_setting(view, unquote(event), @module_name)

        assert {:ok, value} = load(me)
        assert plain?(value), "stored as #{inspect(raw_json(me))}"
      end
    end

    describe "type markers in a pushed value, #{event}" do
      test "control: a map without markers is stored as that map", %{me: me, view: view} do
        send_setting(view, unquote(event), %{"name" => "Fira Sans"})

        assert {:ok, %{} = value} = load(me)
        assert plain?(value)
      end

      test "a struct marker names no module the server can load: it does not poison the row", %{
        me: me,
        view: view
      } do
        send_setting(view, unquote(event), %{"__data_type__" => new_atom_name(), "id" => "x"})

        assert {:ok, value} = load(me)
        assert plain?(value), "stored as #{inspect(raw_json(me))}"
      end

      test "a struct marker cannot create a new atom when loaded", %{me: me, view: view} do
        name = new_atom_name()
        refute atom_exists?(name)

        send_setting(view, unquote(event), %{"__data_type__" => name, "id" => "x"})
        _ = load(me)

        refute atom_exists?(name), "stored as #{inspect(raw_json(me))}"
      end

      test "an atom marker does not poison the row", %{me: me, view: view} do
        send_setting(view, unquote(event), %{"__data_type__" => "atom", "value" => "x"})

        assert {:ok, value} = load(me)
        assert plain?(value), "stored as #{inspect(raw_json(me))}"
      end

      test "an atom marker cannot create a new atom when loaded", %{me: me, view: view} do
        name = new_atom_name()
        refute atom_exists?(name)

        send_setting(view, unquote(event), %{"__data_type__" => "atom", "value" => name})
        _ = load(me)

        refute atom_exists?(name), "stored as #{inspect(raw_json(me))}"
      end

      test "a marker naming an existing module does not come back as a struct or poison the row",
           %{me: me, other: other, view: view} do
        send_setting(view, unquote(event), %{"__data_type__" => @module_name, "id" => other.id})

        assert {:ok, value} = load(me)
        assert plain?(value), "stored as #{inspect(raw_json(me))}"
      end
    end

    describe "scope sent by the browser, #{event}" do
      test "control: without a scope the setting goes to the sender only", %{
        me: me,
        other: other,
        view: view
      } do
        before = stored(other)
        refute before == "Fira Sans"

        send_setting(view, unquote(event), "Fira Sans")

        assert stored(me) == "Fira Sans"
        assert stored(other) == before
      end

      test "a forged user as the scope cannot write to another user's settings", %{
        other: other,
        view: view
      } do
        before = stored(other)
        refute before == "Fira Sans"

        send_setting(view, unquote(event), "Fira Sans", %{
          "scope" => %{"__struct__" => @module_name, "id" => other.id}
        })

        assert stored(other) == before
      end
    end

    describe "scope selector sent by the browser, #{event}" do
      test "`user` and `account` save to the sender's own user and account", %{
        me: me,
        account: account,
        view: view
      } do
        account_id = account.id

        send_setting(view, unquote(event), "Fira Sans", %{"scope" => "user"})
        assert {:ok, "Fira Sans"} = load(me)

        send_setting(view, unquote(event), "Lato", %{"scope" => "account"})
        assert {:ok, "Lato"} = load_id(account_id)
        assert {:ok, "Fira Sans"} = load(me)
      end

      test "`instance` saves to the instance settings for an admin", %{} do
        account = fake_account!()
        admin = fake_admin!(account)
        {:ok, view, _html} = live(conn(user: admin, account: account), "/feed/my")

        # instance settings also live in the app config, which outlives the test
        on_exit(fn -> Bonfire.Common.Config.put([:ui, :font_family], nil) end)

        send_setting(view, unquote(event), "Instance Sans", %{"scope" => "instance"})

        assert Settings.get([:ui, :font_family], nil, scope: :instance) == "Instance Sans"
        assert {:ok, nil} = load(admin)
      end

      test "a group id saves to the group's settings when the user can configure the group", %{
        me: me,
        view: view
      } do
        group = Bonfire.Classify.Simulate.fake_group!(me, %{name: "Settings group"})

        send_setting(view, unquote(event), "Fira Sans", %{"scope" => group.id})

        assert {:ok, "Fira Sans"} = load_id(group.id)
        assert {:ok, nil} = load(me)
      end

      test "a group id is refused when the user cannot configure the group", %{
        other: other,
        view: view
      } do
        group = Bonfire.Classify.Simulate.fake_group!(other, %{name: "Not my group"})

        send_setting(view, unquote(event), "Fira Sans", %{"scope" => group.id})

        assert {:ok, nil} = load_id(group.id)
      end
    end

    describe event do
      test "control: a plain string value is stored as that string", %{me: me, view: view} do
        refute stored(me) == "Fira Sans"
        send_setting(view, unquote(event), "Fira Sans")
        assert stored(me) == "Fira Sans"
      end

      test "a forged struct value is not stored as a struct", %{me: me, other: other, view: view} do
        refute is_struct(stored(me))

        send_setting(view, unquote(event), %{"__struct__" => @module_name, "id" => other.id})

        refute is_struct(stored(me))
      end

      test "a string naming a module is stored as a string", %{me: me, view: view} do
        refute stored(me) == @module_name

        send_setting(view, unquote(event), @module_name)

        assert stored(me) == @module_name
      end
    end
  end

  describe "a guest (no current user) sending a scope" do
    defp guest_socket,
      do: %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, __context__: %{}, flash: %{}}}

    # a refusal may raise: only what was stored matters
    defp guest_send(event, attrs) do
      Bonfire.Common.Settings.LiveHandler.handle_event(event, attrs, guest_socket())
    rescue
      _ -> :refused
    end

    for event <- ["set", "save"] do
      test "a group id as the scope does not change the group's settings, #{event}", %{
        other: other
      } do
        group = Bonfire.Classify.Simulate.fake_group!(other, %{name: "Guest target"})

        guest_send(unquote(event), %{
          "ui" => %{"font_family" => "Fira Sans"},
          "scope" => group.id
        })

        assert {:ok, nil} = load_id(group.id)
      end
    end

    test "a group as the scope in the server-side API needs skip_boundary_check", %{other: other} do
      group = Bonfire.Classify.Simulate.fake_group!(other, %{name: "Server target"})

      try do
        Settings.put([:ui, :font_family], "Fira Sans", scope: group)
      rescue
        _ -> :refused
      end

      assert {:ok, nil} = load_id(group.id)

      assert {:ok, _} =
               Settings.put([:ui, :font_family], "Fira Sans",
                 scope: group,
                 skip_boundary_check: true
               )

      assert {:ok, "Fira Sans"} = load_id(group.id)
    end
  end
end
