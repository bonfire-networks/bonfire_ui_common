defmodule Bonfire.UI.Common.NextGenImageLiveTest do
  use ExUnit.Case, async: true

  alias Bonfire.UI.Common.NextGenImageLive, as: NextGen

  # NOTE: `variants/1` is built at compile time by scanning `priv/static/images`
  # for `.avif`/`.webp` siblings, so these positive cases assume the branding
  # assets (committed under `assets/static/images/`) have been assembled into
  # `priv/static`. The negative/fallback cases hold regardless.

  describe "variants/1" do
    test "returns avif+webp for a static image with generated variants" do
      assert %{avif: "/images/bonfires.avif", webp: "/images/bonfires.webp"} =
               NextGen.variants("/images/bonfires.png")
    end

    test "returns nil for an image without variants" do
      assert NextGen.variants("/images/no-such-upload.png") == nil
    end

    test "returns nil for non-binary input" do
      assert NextGen.variants(nil) == nil
      assert NextGen.variants(123) == nil
    end
  end

  describe "background_image_set/1" do
    test "emits image-set with avif + webp (and a plain url fallback) for a known static image" do
      css = NextGen.background_image_set("/images/bonfires.png")

      # plain declaration first, for browsers without image-set() support
      assert css =~ "background-image: url('/images/bonfires.png')"
      # then the image-set override modern browsers use to pick the smallest format
      assert css =~ "image-set("
      assert css =~ "url('/images/bonfires.avif') type('image/avif')"
      assert css =~ "url('/images/bonfires.webp') type('image/webp')"
    end

    test "falls back to a plain url() for images without variants (e.g. uploads)" do
      css = NextGen.background_image_set("/uploads/banner123.jpg")

      refute css =~ "image-set"
      assert css == "background-image: url('/uploads/banner123.jpg')"
    end

    test "returns an empty string for nil" do
      assert NextGen.background_image_set(nil) == ""
    end
  end
end
