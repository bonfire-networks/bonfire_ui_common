if Code.ensure_loaded?(Image) do
  defmodule Bonfire.UI.Common.SEOImageRasterTest do
    use ExUnit.Case, async: true

    # bucket this into the ui CI leg: bare `ExUnit.Case` skips the tag the extension case templates apply, so without it this also runs in the federation job catch-all
    @moduletag :ui

    alias Bonfire.UI.Common.SEOImage

    describe "Open Graph instance icon fallback (rasterising)" do
      test "renders an SVG instance icon to one cached square PNG" do
        cache_dir = tmp_cache_dir()

        svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 100">
          <rect width="300" height="100" fill="#e63027"/>
        </svg>
        """

        # `cache: false` so this exercises the on-disk cache rather than the in-memory memoisation
        opts = [
          cache: false,
          cache_dir: cache_dir,
          public_path: "/data/uploads/instance/seo",
          fetch_source: fn _url -> {:ok, svg} end
        ]

        url = SEOImage.social_icon_url("https://example.com/jacobin.svg", opts)

        assert String.starts_with?(url, "http")
        assert String.ends_with?(url, ".png")

        [png_path] = Path.wildcard(Path.join(cache_dir, "*.png"))
        assert {:ok, image} = Image.open(png_path)
        assert {512, 512, _bands} = Image.shape(image)
        assert {:ok, [_red, _green, _blue, 0]} = Image.get_pixel(image, 0, 0)

        # a source hosted elsewhere is re-read once the memoised result expires (that is the only
        # way a changed remote icon is ever noticed), but rasterising it again is not needed: the
        # filename tracks the source's contents, so an existing PNG is known to still be current
        File.write!(png_path, "left alone if the cached render is reused")

        assert url == SEOImage.social_icon_url("https://example.com/jacobin.svg", opts)
        assert [png_path] == Path.wildcard(Path.join(cache_dir, "*.png"))
        assert File.read!(png_path) == "left alone if the cached render is reused"
      end

      test "renders an SVG at the requested size rather than upscaling its intrinsic size" do
        cache_dir = tmp_cache_dir()

        # no width/height, and a tiny viewBox: rasterising at the intrinsic size would give a
        # 32px image blown up to 512px, i.e. a blurry og:image
        svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
          <rect x="0" y="0" width="16" height="32" fill="#e63027"/>
          <rect x="16" y="0" width="16" height="32" fill="#0a0a0a"/>
        </svg>
        """

        url =
          SEOImage.social_icon_url("https://example.com/tiny-viewbox.svg",
            cache: false,
            cache_dir: cache_dir,
            fetch_source: fn _url -> {:ok, svg} end
          )

        assert String.ends_with?(url, ".png")

        [png_path] = Path.wildcard(Path.join(cache_dir, "*.png"))
        assert {:ok, image} = Image.open(png_path)
        assert {512, 512, _bands} = Image.shape(image)

        # the colour boundary at x=256 is a hard vector edge. Rasterising at the intrinsic 32px
        # and upscaling 16x would smear it across ~16px, leaving both of these pixels mid-grey.
        assert {:ok, [left_r, left_g, left_b | _]} = Image.get_pixel(image, 250, 256)
        assert {:ok, [right_r, right_g, right_b | _]} = Image.get_pixel(image, 262, 256)

        assert left_r > 200 and left_g < 80 and left_b < 80
        assert right_r < 40 and right_g < 40 and right_b < 40
      end

      test "re-renders a raster instance icon that is too small to be used as an og:image" do
        # `Bonfire.Files.IconUploader` thumbnails uploads to 142px, below the 200px that
        # Facebook/Signal/Slack require before they will use an og:image at all
        {icon_url, _path} = local_instance_icon(142)

        url = SEOImage.social_icon_url(icon_url, cache: false, cache_dir: tmp_cache_dir())

        refute url == icon_url
        assert String.ends_with?(url, ".png")
      end

      test "leaves a large enough raster instance icon alone" do
        {icon_url, _path} = local_instance_icon(512)

        assert SEOImage.social_icon_url(icon_url, cache: false, cache_dir: tmp_cache_dir()) ==
                 icon_url
      end

      test "renders even a large raster with always_render, for the PWA manifest" do
        {icon_url, _path} = local_instance_icon(600)
        cache_dir = tmp_cache_dir()

        url =
          SEOImage.social_icon_url(icon_url,
            cache: false,
            cache_dir: cache_dir,
            always_render: true
          )

        assert url =~ "/instance-icon-"
        [png_path] = Path.wildcard(Path.join(cache_dir, "*.png"))
        assert {:ok, image} = Image.open(png_path)
        assert {512, 512, _bands} = Image.shape(image)
      end

      test "reads an upload linked through the local storage redirect from disk" do
        # how an uploaded instance icon is linked (`Bonfire.Files.redirect_entrepot_url/2`)
        {_icon_url, path} = local_instance_icon(142)
        redir_url = SEOImage.absolute_url("/files/redir/local/#{path}")

        url = SEOImage.social_icon_url(redir_url, cache: false, cache_dir: tmp_cache_dir())

        assert url =~ "/instance-icon-"
      end

      test "re-renders when the file behind an unchanged icon URL changes" do
        cache_dir = tmp_cache_dir()
        {icon_url, path} = local_instance_icon(142)

        first = SEOImage.social_icon_url(icon_url, cache: false, cache_dir: cache_dir)

        # same URL, different contents: a cache keyed on the URL alone would serve the old PNG
        {:ok, replacement} = Image.new(120, 120, color: [10, 10, 10])
        {:ok, _} = Image.write(replacement, path)

        second = SEOImage.social_icon_url(icon_url, cache: false, cache_dir: cache_dir)

        refute second == first
        assert String.ends_with?(second, ".png")
      end
    end

    describe "maskable instance icon" do
      test "draws the rendered icon inside the safe zone, on an opaque background" do
        cache_dir = tmp_cache_dir()

        svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <rect width="100" height="100" fill="#e63027"/>
        </svg>
        """

        opts = [cache: false, cache_dir: cache_dir, fetch_source: fn _url -> {:ok, svg} end]
        icon_url = SEOImage.social_icon_url("https://example.com/square.svg", opts)

        maskable_url =
          SEOImage.maskable_icon_url(icon_url, cache_dir: cache_dir, background: "#191e25")

        assert String.ends_with?(maskable_url, "-maskable.png")

        [png_path] = Path.wildcard(Path.join(cache_dir, "*-maskable.png"))
        assert {:ok, image} = Image.open(png_path)
        assert {512, 512, _bands} = Image.shape(image)
        # the corners, which masks cut away, are the background, and opaque
        assert {:ok, [0x19, 0x1E, 0x25 | _]} = Image.get_pixel(image, 2, 2)
        # the icon sits in the middle 80%: its edge is ~51px in, not at the border
        assert {:ok, [r, g, b | _]} = Image.get_pixel(image, 256, 256)
        assert r > 200 and g < 80 and b < 80
        assert {:ok, [0x19, 0x1E, 0x25 | _]} = Image.get_pixel(image, 256, 40)

        # rendered once: a second call reuses the file
        File.write!(png_path, "reused")
        assert maskable_url == SEOImage.maskable_icon_url(icon_url, cache_dir: cache_dir)
        assert File.read!(png_path) == "reused"
      end

      test "is nil for an icon it didn't render" do
        assert SEOImage.maskable_icon_url("https://example.com/instance-icon.png") == nil
      end
    end

    defp tmp_cache_dir do
      dir =
        Path.join(
          System.tmp_dir!(),
          "bonfire-instance-icon-#{System.unique_integer([:positive])}"
        )

      on_exit(fn -> File.rm_rf!(dir) end)
      dir
    end

    # writes a square PNG where `local_path/1` will find it, i.e. under the `/data/uploads/` mount
    defp local_instance_icon(size) do
      dir = "data/uploads/test-instance-icons/#{System.unique_integer([:positive])}"
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)

      path = Path.join(dir, "icon.png")
      {:ok, image} = Image.new(size, size, color: [230, 48, 39])
      {:ok, _} = Image.write(image, path)

      {SEOImage.absolute_url("/#{path}"), path}
    end
  end
end
