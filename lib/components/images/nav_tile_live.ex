defmodule Bonfire.UI.Common.NavTileLive do
  @moduledoc "A group's or topic's tile when it has no avatar: its initial on a colour picked from its id, so the same group looks the same in the sidebar, in a post's \"published in\" pill and in its own header. Styled by the `nav-tile` utility."
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "The group or topic, for the colour."
  prop object, :any, required: true

  @doc "Its name, for the initial."
  prop name, :string, default: nil

  @doc "Sizes beyond the 20px default, eg. for a header."
  prop class, :css_class, default: nil

  @doc """
  The first letter of a name, or `#` when there is none.

      iex> Bonfire.UI.Common.NavTileLive.initial("  fedi pub")
      "F"
      iex> Bonfire.UI.Common.NavTileLive.initial(nil)
      "#"
  """
  def initial(name) do
    case name |> to_string() |> String.trim() |> String.first() do
      nil -> "#"
      letter -> String.upcase(letter)
    end
  end

  @doc """
  A hue (0-359) from the object's id, the same for it everywhere.

      iex> Bonfire.UI.Common.NavTileLive.tile_hue(%{id: "01M5A1RS1M5A1RS1M5A1RS1M5"}) == Bonfire.UI.Common.NavTileLive.tile_hue("01M5A1RS1M5A1RS1M5A1RS1M5")
      true
  """
  def tile_hue(object), do: :erlang.phash2(id(object), 360)

  @doc "The URL of the image the group or topic has uploaded, else nil: then it shows its picked icon, else its initial (this component). The one place that choice is made, so every avatar of a group follows it."
  def uploaded_avatar_url(object) do
    case Bonfire.Common.Media.avatar_url(object) do
      "/images/avatar.png" -> nil
      url -> url
    end
  end

  @doc "The icon the group or topic has picked, if any (read from its loaded settings, as `Bonfire.Classify.Appearance.icon/1` does), else nil: then the tile shows the initial."
  def picked_icon(object) do
    case maybe_apply(Bonfire.Classify.Appearance, :icon, [object], fallback_return: nil) do
      icon when is_binary(icon) -> icon
      _ -> nil
    end
  end

  @doc "The CSS class of the swatch the group or topic has set for its colour (nil if none): the tile takes its ink and wash."
  def colour_class(object) do
    with colour when is_binary(colour) <-
           maybe_apply(Bonfire.Classify.Appearance, :own_colour, [object], fallback_return: nil) do
      Bonfire.Common.Swatches.class(colour)
    else
      _ -> nil
    end
  end
end
