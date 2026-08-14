defmodule Bonfire.UI.Common.SEOImage do
  use Untangle
  import Bonfire.Common.Utils, only: [maybe_apply: 4]
  alias Bonfire.Common.Cache
  alias Bonfire.Common.Config
  alias Bonfire.Common.Extend
  require Config

  @instance_icon_size 512
  # Facebook, Signal and Slack ignore an `og:image` below 200×200 and fall back to whatever
  # else they can scrape, and `Bonfire.Files.IconUploader` thumbnails uploads to 142px by
  # default, so a smaller icon is re-rendered rather than advertised as-is.
  @min_social_icon_size 200
  @instance_icon_cache_dir "data/uploads/instance/seo"
  @instance_icon_public_path "/data/uploads/instance/seo"
  @max_source_bytes 5_000_000
  # Only ever paid for an icon hosted elsewhere: icons served by this instance are read from disk.
  @fetch_timeout 5_000
  # Resolving an icon can stat/read a file, fetch a URL and rasterise, while the result is
  # needed on every dead render (`SEO.juice` for guests, `include_assets/2` for everyone) and
  # on every `/favicon.ico` hit. `Cache.maybe_apply_cached/3` also caches errors (with a short
  # TTL of its own), which is what stops a broken icon from making every render pay again.
  @resolve_cache_ttl 1_000 * 60 * 60 * 6
  @bundled_instance_icons [
    "/images/bonfire-icon.png",
    "/images/bonfire-icon.svg",
    "/favicon.ico"
  ]

  @doc """
  Ensure an image path/URL is absolute, as required by social crawlers/unfurlers.

  Note `generate_path/6` returns a bare relative path (no leading `/`), and can
  return `nil`/`false`, so `Bonfire.Common.URIs.based_url/2` is not a substitute.
  """
  def absolute_url(nil), do: nil
  def absolute_url(false), do: nil
  def absolute_url("http" <> _ = url), do: url
  def absolute_url("//" <> _ = url), do: "https:" <> url
  def absolute_url("/" <> _ = path), do: Bonfire.Common.URIs.base_url() <> path

  def absolute_url(path) when is_binary(path) and path != "",
    do: Bonfire.Common.URIs.base_url() <> "/" <> path

  def absolute_url(_), do: nil

  @doc "Returns whether an instance icon is customized rather than one of Bonfire's bundled defaults."
  def custom_instance_icon?(icon)

  def custom_instance_icon?(icon) when is_binary(icon) and icon != "" do
    # compared as absolute URLs, because `favicon.ico` and `https://<this instance>/favicon.ico`
    # are the bundled icon just as much as `/favicon.ico` is: treating those as custom would
    # make `InstanceFaviconPlug` redirect `/favicon.ico` to itself, forever.
    case absolute_url(icon) do
      url when is_binary(url) -> url not in bundled_instance_icon_urls()
      _ -> false
    end
  end

  def custom_instance_icon?(_), do: false

  defp bundled_instance_icon_urls do
    base = Bonfire.Common.URIs.base_url()
    Enum.flat_map(@bundled_instance_icons, &[&1, "#{base}#{&1}"])
  end

  @doc "Returns the configured instance icon as a crawler-compatible absolute URL. SVG icons are rendered once to a square PNG."
  def instance_icon_url(opts \\ []) do
    Config.get([:ui, :theme, :instance_icon])
    |> social_icon_url(opts)
  end

  @doc """
  Returns an absolute social-preview icon URL for the given icon path/URL.

  An SVG source, or a raster too small to be accepted as an `og:image`, is rendered once to a
  square transparent PNG under `#{@instance_icon_public_path}` and served from there; anything
  else is returned as a plain absolute URL. Any failure falls back to the original URL rather
  than emitting nothing.

  Results are memoised, so this stays cheap on the render path — see `@resolve_cache_ttl`.

  ## Options
    * `:cache_dir` / `:public_path` - where rendered PNGs are written and served from
    * `:fetch_source` - a 1-arity fetcher to use instead of `Bonfire.Common.HTTP`
    * plus anything `Bonfire.Common.Cache.maybe_apply_cached/3` understands (e.g. `cache: false`)
  """
  def social_icon_url(icon, opts \\ [])

  def social_icon_url(icon, _opts) when icon in [nil, false, ""], do: nil

  def social_icon_url(icon, opts) when is_binary(icon) do
    with icon_url when is_binary(icon_url) <- absolute_url(icon) do
      case resolve_social_icon(icon_url, opts) do
        {:ok, url} ->
          url

        error ->
          warn(error, "Could not prepare the instance icon for social previews, using it as-is")

          icon_url
      end
    end
  end

  def social_icon_url(_, _opts), do: nil

  defp resolve_social_icon(icon_url, opts) do
    Cache.maybe_apply_cached(
      &prepare_social_icon/2,
      [icon_url, opts],
      opts
      # the cache dir is part of the key so that callers pointing at their own dir (i.e. tests)
      # cannot be served a URL under somebody else's
      |> Keyword.put(:cache_key, "social_icon_url:#{cache_dir(opts)}:#{icon_url}")
      |> Keyword.put_new(:expire, @resolve_cache_ttl)
    )
  end

  defp prepare_social_icon(icon_url, opts) do
    case icon_source(icon_url, opts) do
      {:ok, :as_is} -> {:ok, icon_url}
      {:ok, {bytes, fingerprint}} -> render_cached_icon(bytes, fingerprint, opts)
      error -> error
    end
  end

  # Decides whether an icon has to be re-rendered at all, and where its bytes would come from.
  defp icon_source(icon_url, opts) do
    own_host? = own_host?(icon_url)
    local_path = if own_host?, do: local_path(icon_url)

    cond do
      is_binary(local_path) ->
        with {:ok, bytes} <- File.read(local_path), do: classify_source(icon_url, bytes)

      # a URL on our own host that maps to no file on disk: fetching it would be this instance
      # calling itself mid-render, so leave it alone rather than pay for that (and its timeouts)
      own_host? ->
        {:ok, :as_is}

      svg_url?(icon_url) ->
        with {:ok, bytes} <- fetch_source(icon_url, opts), do: classify_source(icon_url, bytes)

      # A raster hosted elsewhere is taken at face value: fetching it just to measure it would
      # put a third-party HTTP round trip on the render path, for a URL an admin set by hand.
      true ->
        {:ok, :as_is}
    end
  end

  # an SVG always has to be rasterised; a raster only when it is too small to be used as an
  # og:image. The rendered PNG is named after the source's contents, so it is stable across
  # nodes and deploys, and never stale — which a name derived from the URL alone would not be,
  # for a flavour that ships `/images/logo.svg` and updates it in place.
  defp classify_source(icon_url, bytes) do
    if svg_url?(icon_url) or too_small_for_social?(bytes),
      do: {:ok, {bytes, Bonfire.Common.Text.hash(bytes, algorithm: :sha256)}},
      else: {:ok, :as_is}
  end

  defp render_cached_icon(bytes, fingerprint, opts) do
    public_path = Keyword.get(opts, :public_path, @instance_icon_public_path)
    filename = "instance-icon-#{fingerprint}.png"
    cached_path = Path.join(cache_dir(opts), filename)

    if File.regular?(cached_path) do
      {:ok, public_icon_url(public_path, filename)}
    else
      with :ok <- ensure_renderer_available(),
           :ok <- validate_source_size(bytes),
           {:ok, _path} <- render_square_png(bytes, cached_path, @instance_icon_size) do
        {:ok, public_icon_url(public_path, filename)}
      end
    end
  end

  defp public_icon_url(public_path, filename) do
    public_path
    |> Path.join(filename)
    |> absolute_url()
  end

  defp cache_dir(opts), do: Keyword.get(opts, :cache_dir, @instance_icon_cache_dir)

  # Renders image bytes onto a square transparent PNG canvas and writes it atomically.
  defp render_square_png(bytes, output_path, size) do
    temporary_path =
      "#{output_path}.#{System.unique_integer([:positive, :monotonic])}.png"

    result =
      with :ok <- File.mkdir_p(Path.dirname(output_path)),
           # `thumbnail_buffer` asks the loader to rasterise at the requested size, so a vector
           # source is rendered crisply at 512px. Loading it first (`svgload_buffer`) and resizing
           # the result would instead blow up whatever its intrinsic size happens to be — an icon
           # authored as `viewBox="0 0 32 32"` renders at 32px and upscales to a blurry mess.
           {:ok, resized_image} <-
             Vix.Vips.Operation.thumbnail_buffer(bytes, size,
               height: size,
               size: :VIPS_SIZE_BOTH
             ),
           {:ok, resized_image} <- ensure_alpha(resized_image),
           {:ok, square_image} <-
             Image.embed(resized_image, size, size,
               x: :center,
               y: :center,
               background: {:black, alpha: :transparent}
             ),
           {:ok, _image} <- Image.write(square_image, temporary_path),
           :ok <- replace_file(temporary_path, output_path) do
        {:ok, output_path}
      end

    File.rm(temporary_path)
    result
  end

  defp svg_url?(url) when is_binary(url) do
    case URI.parse(url).path do
      path when is_binary(path) -> String.downcase(Path.extname(path)) == ".svg"
      _ -> false
    end
  end

  defp svg_url?(_), do: false

  defp own_host?(icon_url) do
    case Bonfire.Common.URIs.base_url() do
      base when is_binary(base) and base != "" -> String.starts_with?(icon_url, base)
      _ -> false
    end
  end

  # Maps a URL served by this instance back to the file on disk, mirroring the `Plug.Static`
  # mounts in `EndpointTemplate`. Reading the file keeps a page render from depending on an HTTP
  # round trip to ourselves, and gives us a fingerprint that changes when the file does.
  defp local_path(icon_url) do
    with %URI{path: "/" <> _ = path} <- URI.parse(icon_url),
         path = URI.decode(path),
         false <- String.contains?(path, "..") do
      Enum.find_value(static_mounts(), fn {at, from} ->
        if String.starts_with?(path, at) do
          candidate = Path.join(from, String.replace_prefix(path, at, ""))
          if File.regular?(candidate), do: candidate
        end
      end)
    else
      _ -> nil
    end
  end

  defp static_mounts do
    [{"/data/uploads/", "data/uploads"}] ++ Enum.map(static_app_dirs(), &{"/", &1})
  end

  defp static_app_dirs do
    [Config.top_level_otp_app(), :bonfire_ui_common, :bonfire]
    |> Enum.uniq()
    |> Enum.map(&app_static_dir/1)
    |> Enum.filter(&is_binary/1)
  end

  defp app_static_dir(app) do
    dir = Application.app_dir(app, "priv/static")
    if File.dir?(dir), do: dir
  rescue
    # not a loaded application
    ArgumentError -> nil
  end

  defp too_small_for_social?(bytes) do
    # when unmeasurable (or bonfire_files disabled), assume it needs no re-rendering
    case maybe_apply(Bonfire.Files.MediaEdit, :dimensions, [bytes], fallback_return: nil) do
      {width, height} -> max(width, height) < @min_social_icon_size
      _ -> false
    end
  end

  defp fetch_source(icon_url, opts) do
    case Keyword.get(opts, :fetch_source) do
      fun when is_function(fun, 1) -> fun.(icon_url)
      _ -> fetch_source(icon_url)
    end
  end

  defp fetch_source(icon_url) do
    with {:ok, %{status: status, body: body}} when status in 200..299 and is_binary(body) <-
           Bonfire.Common.HTTP.get(icon_url, [],
             # an unbounded fetch here would stall page renders, not just this one: the names
             # differ per adapter (Finch vs Hackney), and each ignores the ones it does not know
             adapter: [
               receive_timeout: @fetch_timeout,
               request_timeout: @fetch_timeout,
               recv_timeout: @fetch_timeout,
               connect_timeout: @fetch_timeout
             ]
           ) do
      {:ok, body}
    else
      error -> {:error, error}
    end
  end

  defp ensure_renderer_available do
    if Extend.module_enabled?(Image) and Extend.module_enabled?(Vix.Vips.Operation),
      do: :ok,
      else: {:error, :image_renderer_unavailable}
  end

  defp validate_source_size(bytes) when byte_size(bytes) <= @max_source_bytes, do: :ok
  defp validate_source_size(_bytes), do: {:error, :source_too_large}

  defp ensure_alpha(image) do
    if Image.has_alpha?(image), do: {:ok, image}, else: Image.add_alpha(image, :opaque)
  end

  defp replace_file(temporary_path, output_path) do
    case File.rename(temporary_path, output_path) do
      :ok ->
        :ok

      error ->
        # `rename/2` overwrites an existing regular file, so a failure means either a real
        # problem or another process having just won the same race. Only the latter is `:ok`,
        # and only because the destination filename is fingerprinted: same name, same contents.
        if File.regular?(output_path), do: :ok, else: error
    end
  end

  def generate_path(id, author_id, title, body, author, image \\ nil) do
    filename = og_image_paths(id, author_id)

    if not File.exists?(filename) do
      with :ok <- ensure_renderer_available(),
           {:ok, filename} <- generate_og_image(filename, title, body, author, image) do
        filename
      else
        {:error, :image_renderer_unavailable} ->
          #  necessary libs not available
          nil

        e ->
          error(e)
          nil
      end
    else
      filename
    end
  end

  defp generate_og_image(filename, nil, body, author, image),
    do: generate_og_image(filename, body, nil, author, image)

  defp generate_og_image(filename, title, body, author, image) do
    {title_1, title_2} = og_split_lines(title || "", 31)
    {body_1, body_2} = og_split_lines(body || "", 40)
    # TODO: configurable
    font_family = "'Inter', 'Noto Sans', 'Roboto', 'system-ui', 'sans-serif'"

    svg =
      """
      <svg viewbox="0 0 1200 600" width="1200" height="600" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
          <defs>
          <linearGradient y2="1" x2="1" y1="0.14844" x1="0.53125" id="gradient">
          <stop offset="0" stop-opacity="0.99609" stop-color="#800909"/>
          <stop offset="0.99219" stop-opacity="0.97656" stop-color="#ff8300"/>
          </linearGradient>
          </defs>
          <g>
          <rect stroke="#000" height="800" width="1800" y="0" x="0" stroke-width="0" fill="url(#gradient)"/>
          <text font-style="normal" font-weight="normal" xml:space="preserve" text-anchor="start" font-family="#{font_family}" font-size="70" y="150" x="100" stroke-width="0" stroke="#000" fill="#f8fafc">#{title_1}</text>
          <text font-style="normal" font-weight="normal" xml:space="preserve" text-anchor="start" font-family="#{font_family}" font-size="70" y="250" x="100" stroke-width="0" stroke="#000" fill="#f8fafc">#{title_2}</text>
          <text font-style="normal" font-weight="normal" xml:space="preserve" text-anchor="start" font-family="#{font_family}" font-size="50" y="350" x="100" stroke-width="0" stroke="#000" fill="#f8fafc">#{body_1}</text>
          <text font-style="normal" font-weight="normal" xml:space="preserve" text-anchor="start" font-family="#{font_family}" font-size="50" y="450" x="100" stroke-width="0" stroke="#000" fill="#f8fafc">#{body_2}</text>
          <text font-style="normal" font-weight="normal" xml:space="preserve" text-anchor="start" font-family="#{font_family}" font-size="30" y="550" x="50" stroke-width="0" stroke="#000" fill="#f8fafc" opacity="0.5">#{author}</text>
          
          </g>
      </svg>
      """

    # |> IO.inspect

    # not supported by Vips?
    # <image xml:space="preserve"
    #         y="500" x="1100"
    #         width="100" height="100" 
    #         xlink:href="#{image}" 
    #     />

    write_og_image(filename, svg, image)
    |> info("write_og_image")
  end

  defp og_image_paths(id, author_id) do
    # TODO: configurable
    root_dir = "data/uploads/"
    path = Path.join([root_dir, author_id || "unknown", "og_previews"])

    File.mkdir_p!(path)

    Path.join([path, "#{id}.png"])
  end

  defp og_split_lines(title, max_length \\ 31) do
    title
    |> String.split(" ")
    |> Enum.reduce_while({"", ""}, fn word, {title_1, title_2} ->
      cond do
        String.length(title_1 <> " " <> word) <= max_length ->
          {:cont, {title_1 <> " " <> word, title_2}}

        String.length(title_2 <> " " <> word) <= max_length - 3 ->
          {:cont, {title_1, title_2 <> " " <> word}}

        true ->
          {:halt, {title_1, title_2 <> "..."}}
      end
    end)
  end

  defp write_og_image(filename, svg, image \\ nil)

  defp write_og_image(filename, svg, nil) do
    with {:ok, {svg_image, _}} <- Vix.Vips.Operation.svgload_buffer(svg),
         {:ok, _} <- Image.write(svg_image, filename) do
      # ^ save to PNG because for some reason OpenGraph does not support SVG
      {:ok, filename}
    end
  end

  defp write_og_image(filename, svg, overlay_path) do
    with {:ok, {svg_image, _}} <- Vix.Vips.Operation.svgload_buffer(svg),
         {:ok, overlay_image} <- Image.open(overlay_path),
         #  debug(overlay_path, "ok imagesss"),
         {:ok, overlay_image} <- Image.thumbnail(overlay_image, "200x200"),
         {:ok, composed_img} <- Image.compose(svg_image, overlay_image, x: 980, y: 380),
         {:ok, _} <- Image.write(composed_img, filename) do
      {:ok, filename}
    else
      e ->
        warn(e, "Error generating OG image with overlay, falling back to no overlay")
        write_og_image(filename, svg, nil)
    end
  end
end
