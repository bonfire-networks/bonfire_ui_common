defmodule Bonfire.UI.Common.SEOTest do
  use ExUnit.Case, async: true

  # bucket this into the ui CI leg: bare `ExUnit.Case` skips the tag the extension case templates apply, so without it this also runs in the federation job catch-all
  @moduletag :ui
  import Phoenix.LiveViewTest

  # NOTE: `SEO` (unaliased) refers to the phoenix_seo dep; our module is `CommonSEO`.
  alias Bonfire.UI.Common.SEO, as: CommonSEO
  alias Bonfire.UI.Common.SEOImage

  # A struct whose loaded `:creator` assoc has no `Phoenix.HTML.Safe` impl, mimicking a Bonfire
  # pointable (e.g. `Bonfire.Classify.Category`) as loaded with `:with_creator`.
  defmodule FakeCreator do
    defstruct [:id]
  end

  defmodule FakeObject do
    defstruct [:creator, :image, profile: %{}, character: %{}]
  end

  describe "generic extraction helpers" do
    test "seo_title prefers profile name, then named name, then username" do
      assert CommonSEO.seo_title(%{profile: %{name: "Cool Group"}}) == "Cool Group"
      assert CommonSEO.seo_title(%{named: %{name: "A Topic"}}) == "A Topic"
      assert CommonSEO.seo_title(%{character: %{username: "grp"}}) == "grp"
      assert CommonSEO.seo_title(%{}) == nil
    end

    test "seo_description strips HTML and returns plain text" do
      assert CommonSEO.seo_description(%{profile: %{summary: "<p>Hello <b>world</b></p>"}}) ==
               "Hello world"

      assert CommonSEO.seo_description(%{}) == nil
    end

    test "seo_image is nil when no image/icon is set" do
      assert CommonSEO.seo_image(%FakeObject{profile: %{}}) == nil
    end

    test "generic_seo_item never carries non-string assoc fields (e.g. :creator)" do
      item =
        CommonSEO.generic_seo_item(%FakeObject{
          creator: %FakeCreator{id: "x"},
          profile: %{name: "Grp", summary: "A bio"}
        })

      refute Map.has_key?(item, :creator)
      assert item.title == "Grp"

      for {_k, v} <- item do
        assert is_binary(v) or is_atom(v) or is_nil(v),
               "expected only safe values in the SEO item, got: #{inspect(v)}"
      end
    end
  end

  describe "Twitter meta rendering (regression: assoc/Pointer collision)" do
    # Documents the landmine `seo_item/1` guards against: phoenix_seo's `@fallback_to_any` impl
    # copies an object's `:creator` assoc straight into `SEO.Twitter.creator`, which then raises
    # `Phoenix.HTML.Safe not implemented` on render.
    test "raw un-implemented object with a :creator assoc crashes the Twitter meta" do
      assert SEO.Twitter.Build.impl_for(%FakeObject{}) == SEO.Twitter.Build.Any

      raw_item = SEO.Twitter.Build.build(%FakeObject{creator: %FakeCreator{id: "x"}}, nil)
      assert raw_item.creator == %FakeCreator{id: "x"}

      assert_raise Protocol.UndefinedError, fn ->
        render_component(&SEO.Twitter.meta/1, item: raw_item, config: nil)
      end
    end

    test "the guarded generic item renders safely" do
      item =
        SEO.Twitter.Build.build(
          CommonSEO.generic_seo_item(%FakeObject{
            creator: %FakeCreator{id: "x"},
            profile: %{name: "Grp"}
          }),
          nil
        )

      html = render_component(&SEO.Twitter.meta/1, item: item, config: nil)

      assert html =~ ~s(name="twitter:title")
      assert html =~ "Grp"
      refute html =~ "FakeCreator"
    end
  end

  describe "Open Graph instance icon fallback" do
    test "uses the configured raster instance icon rather than the instance banner" do
      Process.put(
        [:bonfire, :ui, :theme, :instance_icon],
        "https://example.com/instance-icon.png"
      )

      Process.put(
        [:bonfire, :ui, :theme, :instance_image],
        "https://example.com/instance-banner.png"
      )

      assert CommonSEO.open_graph_config().image == "https://example.com/instance-icon.png"
    end

    test "makes a relative raster instance icon absolute" do
      Process.put([:bonfire, :ui, :theme, :instance_icon], "/images/instance-icon.png")

      image = CommonSEO.open_graph_config().image

      assert String.starts_with?(image, "http")
      assert String.ends_with?(image, "/images/instance-icon.png")
    end

    test "does not emit an image when the instance icon is blank" do
      Process.put([:bonfire, :ui, :theme, :instance_icon], "")

      html =
        render_component(&SEO.OpenGraph.meta/1,
          item: SEO.OpenGraph.build(title: "Page"),
          config: CommonSEO.open_graph_config()
        )

      refute html =~ ~s(property="og:image")
    end

    test "a page-specific image overrides the instance icon" do
      Process.put(
        [:bonfire, :ui, :theme, :instance_icon],
        "https://example.com/instance-icon.png"
      )

      html =
        render_component(&SEO.OpenGraph.meta/1,
          item:
            SEO.OpenGraph.build(
              title: "Page",
              image: "https://example.com/page-image.png"
            ),
          config: CommonSEO.open_graph_config()
        )

      assert html =~ ~s(content="https://example.com/page-image.png")
      refute html =~ "instance-icon.png"
    end
  end

  describe "custom_instance_icon?/1" do
    test "recognises the bundled icons however they are spelled" do
      base = Bonfire.Common.URIs.base_url()

      for icon <- [
            "/images/bonfire-icon.png",
            "/favicon.ico",
            "favicon.ico",
            "#{base}/favicon.ico"
          ] do
        refute SEOImage.custom_instance_icon?(icon), "expected #{icon} to count as bundled"
      end
    end

    test "recognises a genuinely custom icon" do
      assert SEOImage.custom_instance_icon?("https://example.com/instance-icon.png")
      assert SEOImage.custom_instance_icon?("/images/jacobin.svg")
    end
  end
end
