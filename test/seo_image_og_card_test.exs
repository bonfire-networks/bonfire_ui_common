if Code.ensure_loaded?(Image) do
  defmodule Bonfire.UI.Common.SEOImageOgCardTest do
    use ExUnit.Case, async: false

    @moduletag :ui

    alias Bonfire.UI.Common.SEOImage

    # the generated Open Graph card of a post (the path `PostContentSEO.build/2` takes): our own SVG template, rasterised by libvips, written as a PNG
    test "generates a 1200x600 PNG card with libvips' untrusted loaders blocked as at boot" do
      block_untrusted_loaders_as_at_boot()
      assert System.get_env("VIPS_BLOCK_UNTRUSTED") in ["TRUE", "true", "1"]

      id = "og_card_test_#{System.unique_integer([:positive])}"
      author_id = "og_card_test_author"
      on_exit(fn -> File.rm_rf!(Path.join(["data/uploads", author_id])) end)

      path =
        SEOImage.generate_path(id, author_id, "A title for the card", "Some body text", "Author")

      assert is_binary(path), "no card was generated"
      assert File.regular?(path)
      assert {:ok, img} = Image.open(path)
      assert {1200, 600} == {Image.width(img), Image.height(img)}
      assert <<137, 80, 78, 71, _::binary>> = File.read!(path)
    end

    defp block_untrusted_loaders_as_at_boot do
      if Code.ensure_loaded?(Bonfire.Files.MediaEdit),
        do: apply(Bonfire.Files.MediaEdit, :block_untrusted_loaders, []),
        else:
          if(System.get_env("VIPS_BLOCK_UNTRUSTED") == nil,
            do: System.put_env("VIPS_BLOCK_UNTRUSTED", "TRUE")
          )
    end
  end
end
