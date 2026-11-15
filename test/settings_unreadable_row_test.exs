defmodule Bonfire.UI.Common.SettingsUnreadableRowTest do
  @moduledoc "A settings row that cannot be read back must not cost the person the rest of what they stored: saving one setting keeps the other keys of the row."
  use Bonfire.UI.Common.ConnCase, async: false
  @moduletag :ui

  import Ecto.Query, only: [from: 2]
  use Bonfire.Common.Settings

  alias Bonfire.Data.Identity.SettingsJSONSerdeData

  # the JSON decodes, but cannot be deserialized: a tuple marker whose values are not a list
  @unreadable ~s({"bad": {"__data_type__": "tuple", "values": "not a list"}})

  setup do
    me = fake_user!(fake_account!())
    {:ok, _} = Settings.put([:ui, :font_family], "serif", current_user: me)
    me = Bonfire.Me.Users.get_current(me.id)
    {:ok, _} = Settings.put([:ui, :language], "en", current_user: me)
    %{me: Bonfire.Me.Users.get_current(me.id)}
  end

  defp corrupt(me), do: merge_into_row(me, @unreadable)

  defp merge_into_row(me, json) do
    {1, _} =
      Bonfire.Common.Config.repo().update_all(
        from(s in Bonfire.Data.Identity.Settings,
          where: s.id == ^me.id,
          # the column holds the serialized JSON as a JSON string: merge into the object inside it, and store it as a string again
          update: [
            set: [
              json:
                fragment(
                  "to_jsonb(((? #>> '{}')::jsonb || (?::text)::jsonb)::text)",
                  s.json,
                  ^json
                )
            ]
          ]
        ),
        []
      )

    Bonfire.Me.Users.get_current(me.id)
  end

  defp raw_json(me) do
    Bonfire.Common.Config.repo().one(
      from(s in Bonfire.Data.Identity.Settings,
        where: s.id == ^me.id,
        select: fragment("?::text", s.json)
      )
    )
  end

  test "control: saving one setting on a readable row keeps the other keys", %{me: me} do
    assert raw_json(me) =~ "serif", "control: the row holds the first key"

    {:ok, _} = Settings.put([:ui, :language], "fr", current_user: me)

    raw = raw_json(me)
    assert raw =~ "fr", "control: the new value was stored: #{raw}"
    assert raw =~ "serif", "the other stored key is still there: #{raw}"
  end

  test "control: the corrupted part of the row is dropped, the rest loads", %{me: me} do
    me = corrupt(me)
    raw = raw_json(me)
    assert raw =~ "serif" and raw =~ "not a list", "control: corrupted but keys kept: #{raw}"

    assert {:ok, loaded} = raw |> Jason.decode!() |> SettingsJSONSerdeData.load()
    assert match?(%{bonfire: _}, loaded), "the good key loads, got #{inspect(loaded)}"

    refute Map.has_key?(loaded, "bad") or Map.has_key?(loaded, :bad),
           "the unreadable part is dropped, got #{inspect(loaded)}"

    assert loaded.bonfire.ui.font_family == "serif"
  end

  test "saving one setting keeps the other keys of an unreadable row", %{me: me} do
    me = corrupt(me)

    {:ok, _} = Settings.put([:ui, :language], "fr", current_user: me)

    raw = raw_json(me)
    assert raw =~ "fr", "control: the new value was stored: #{raw}"
    assert raw =~ "serif", "the other stored key is still there: #{raw}"
    refute raw =~ "not a list", "the part that cannot be decoded is dropped by the save: #{raw}"
  end

  test "put_raw does not store the form keys of a Phoenix form", %{me: me} do
    {:ok, _} =
      Settings.put_raw([:ui], %{"language" => "de", "_csrf_token" => "forgedtoken"},
        current_user: me
      )

    raw = raw_json(Bonfire.Me.Users.get_current(me.id))
    assert raw =~ "de", "control: the value was stored: #{raw}"
    refute raw =~ "forgedtoken", "the form key is not stored: #{raw}"
  end

  test "a top-level key of an extension that is not loaded survives a save, and known settings still read",
       %{me: me} do
    me = merge_into_row(me, ~s({"Bonfire.NotLoaded": {"some_setting": "kept"}}))

    assert Settings.get([:ui, :font_family], nil, current_user: me) == "serif"

    {:ok, _} = Settings.put([:ui, :language], "fr", current_user: me)
    me = Bonfire.Me.Users.get_current(me.id)

    raw = raw_json(me)
    assert raw =~ "Bonfire.NotLoaded" and raw =~ "kept", "the unknown key is still there: #{raw}"
    assert raw =~ "serif" and raw =~ "fr"
    assert Settings.get([:ui, :font_family], nil, current_user: me) == "serif"
  end
end
