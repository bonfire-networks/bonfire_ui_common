defmodule Bonfire.UI.Common.SEOTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  # NOTE: `SEO` (unaliased) refers to the phoenix_seo dep; our module is `CommonSEO`.
  alias Bonfire.UI.Common.SEO, as: CommonSEO

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
end
