defmodule Bonfire.UI.Common.NextGenImageLive do
  @moduledoc """
  Renders an image, transparently upgraded to a `<picture>` with AVIF/WebP
  `<source>`s when pre-generated next-gen variants exist alongside a local
  static image.

  Modern browsers download the smallest format they support; everyone else
  (and any image without variants, e.g. user uploads or remote URLs) falls back
  to the original `src`. Failure is always a safe no-op: if variants can't be
  found, a plain `<img>` is rendered.

  Known variants are listed in `@variants` below — keep this in sync with the
  next-gen assets generated into `priv/static/images/` (see
  `perf/generate_assets.exs`). Anything not listed renders a plain `<img>`, so
  adding an entry is purely additive and failure is always a safe no-op.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop(src, :string, required: true)
  prop(alt, :string, default: "")
  prop(title, :string, default: nil)
  prop(class, :any, default: nil)
  prop(loading, :string, default: "lazy")
  prop(fetchpriority, :string, default: nil)

  # Auto-discovered at COMPILE TIME by scanning `priv/static/images` for any
  # raster image (`.png`/`.jpg`/`.jpeg`) that has a generated `.avif` sibling
  # (and `.webp`). Generate variants with `perf/generate_assets.exs` (or a build
  # task) and recompile — no hand-maintained list. Baked into the beam, so it
  # works in releases too (the files ship in priv/static).
  @image_dir "priv/static/images"
  @originals_exts ~w(.png .jpg .jpeg)

  @variants (if File.dir?(@image_dir) do
               @image_dir
               |> File.ls!()
               |> Enum.filter(&(Path.extname(&1) == ".avif"))
               |> Enum.flat_map(fn avif_file ->
                 stem = Path.basename(avif_file, ".avif")
                 webp_file = "#{stem}.webp"

                 original =
                   Enum.find(@originals_exts, fn ext ->
                     File.exists?(Path.join(@image_dir, "#{stem}#{ext}"))
                   end)

                 if original && File.exists?(Path.join(@image_dir, webp_file)) do
                   [
                     {"/images/#{stem}#{original}",
                      %{avif: "/images/#{avif_file}", webp: "/images/#{webp_file}"}}
                   ]
                 else
                   []
                 end
               end)
               |> Map.new()
             else
               %{}
             end)

  @doc """
  Returns `%{avif: url, webp: url}` when `src` is a static image with generated
  next-gen variants, otherwise `nil`.
  """
  def variants(src) when is_binary(src), do: Map.get(@variants, src)
  def variants(_), do: nil

  @doc """
  Returns an inline-style `background-image` fragment that serves AVIF/WebP via
  `image-set()` (with the original as final fallback) when `src` has next-gen
  variants, otherwise a plain `url()`. For CSS-background banners where a
  `<picture>` element can't be used. No trailing semicolon, so callers can append
  further declarations (e.g. `height`).
  """
  def background_image_set(src) when is_binary(src) do
    case variants(src) do
      %{avif: avif, webp: webp} ->
        "background-image: url('#{src}'); " <>
          "background-image: image-set(" <>
          "url('#{avif}') type('image/avif'), " <>
          "url('#{webp}') type('image/webp'), " <>
          "url('#{src}') type('#{mime(src)}'))"

      _ ->
        "background-image: url('#{URI.encode(src)}')"
    end
  end

  def background_image_set(_), do: ""

  defp mime(src) do
    case Path.extname(src) do
      ".png" -> "image/png"
      ext when ext in [".jpg", ".jpeg"] -> "image/jpeg"
      ".webp" -> "image/webp"
      ".gif" -> "image/gif"
      _ -> "image/png"
    end
  end
end
