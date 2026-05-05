defmodule Bonfire.UI.Common.FontHelper do
  use Bonfire.Common.Settings
  alias Bonfire.Common.Text

  @default_font "Inter (Latin Languages)"
  # Captures display name and optional subset from labels like "Inter (Latin Languages)",
  # "Noto Sans (Latin)", or bare "Luciole" / "OpenDyslexic".
  @label_regex ~r/^(?<name>.*?)\s*(?:\((?<subset>.*?)(?:\s+Languages)?\))?\s*$/

  @doc """
  Look up the configured font for the given context (typically a Plug.Conn or assigns)
  and return `{font_name, href}` — the human-readable name (used for the `--font-sans`
  CSS variable) and the static path to the font's CSS file (with digest, when applicable).
  """
  def font_for(context) do
    Settings.get([:ui, :font_family], @default_font, context)
    |> resolve()
  end

  @doc """
  Splits a raw font label like `"Inter (Latin Languages)"` into `{font_name, href}`.

  Examples:
    `"Inter (Latin Languages)"` → `{"Inter", "/fonts/inter-latin.css"}`
    `"Luciole"`                 → `{"Luciole", "/fonts/luciole.css"}`
  """
  def resolve(font_family_raw) when is_binary(font_family_raw) do
    %{"name" => name, "subset" => subset} =
      Regex.named_captures(@label_regex, font_family_raw) ||
        %{"name" => font_family_raw, "subset" => ""}

    font_name = String.trim(name)
    slug_input = if subset in [nil, ""], do: font_name, else: "#{font_name} #{subset}"
    href = static_path("/fonts/#{Text.slug(slug_input)}.css")

    {font_name, href}
  end

  def resolve(_), do: resolve(@default_font)

  @doc """
  Pushes a `set_font` event so the `phx:set_font` listener in `root.html.heex` swaps the
  font CSS link's href and updates the `--font-sans` CSS variable. Keeps the head in sync
  without requiring a full page refresh.
  """
  def push_font(socket, font_family_raw) when is_binary(font_family_raw) do
    {font_name, href} = resolve(font_family_raw)
    Phoenix.LiveView.push_event(socket, "set_font", %{font_name: font_name, href: href})
  end

  def push_font(socket, _), do: socket

  defp static_path(path),
    do: Bonfire.Common.Config.endpoint_module().static_path(path)
end
