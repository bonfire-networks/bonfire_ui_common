defmodule Bonfire.UI.Common.SEO do
  use SEO,
    json_library: Jason,
    # a function reference will be called with a conn during render
    site: &__MODULE__.site_config/1,
    open_graph: &__MODULE__.open_graph_config/1,
    # facebook: &__MODULE__.facebook_config/1,
    twitter: &__MODULE__.twitter_config/1

  use Bonfire.UI.Common

  @description_length 200

  # Assign the SEO item only on the guest (non-logged-in) disconnected (dead) render — that is what crawlers/unfurlers (X, Mastodon, Slack, Facebook) actually fetch, and it avoids paying for it on every mount.
  def maybe_assign_seo(socket, data) do
    if !socket_connected?(socket) and !current_user_id(socket),
      do: SEO.assign(socket, seo_item(data)),
      else: socket
  end

  # Objects with a tailored `SEO.*.Build` impl (User, PostContent, Page, Category, …) are passed
  # through untouched so that impl runs. Anything else would otherwise fall through to phoenix_seo's
  # `@fallback_to_any` impl, which blindly merges every struct field (incl. loaded assocs/Pointers
  # such as `:creator`, `:image`, `:title`) into the meta structs and crashes on render
  # (`Phoenix.HTML.Safe not implemented for Needle.Pointer`). So for those we build a safe,
  # string-only generic item derived from common Bonfire fields instead.
  defp seo_item(nil), do: nil

  defp seo_item(data) do
    if has_specific_seo_impl?(data), do: data, else: generic_seo_item(data)
  end

  defp has_specific_seo_impl?(data) do
    SEO.OpenGraph.Build.impl_for(data) not in [nil, SEO.OpenGraph.Build.Any]
  end

  @doc "Build a safe, string-only SEO item (title/description/image) from any Bonfire object."
  def generic_seo_item(object) do
    image = seo_image(object)

    %{
      title: seo_title(object),
      description: seo_description(object),
      image: image,
      card: if(image, do: :summary_large_image, else: :summary)
    }
  end

  @doc "Best-effort human title for any Bonfire object (profile/topic name, post title, or `@username`)."
  def seo_title(object) do
    e(object, :profile, :name, nil) ||
      e(object, :named, :name, nil) ||
      e(object, :post_content, :name, nil) ||
      case e(object, :character, :username, nil) do
        title when is_binary(title) -> title
        _ -> nil
      end
  end

  @doc "Best-effort plain-text, truncated description for any Bonfire object."
  def seo_description(object) do
    case e(object, :profile, :summary, nil) || e(object, :post_content, :summary, nil) ||
           e(object, :post_content, :html_body, nil) do
      summary when is_binary(summary) and summary != "" ->
        summary
        |> Text.text_only()
        |> Text.sentence_truncate(@description_length)

      _ ->
        nil
    end
  end

  @doc "Absolute URL of the object's banner (or avatar) image, only when one is actually set."
  def seo_image(object) do
    cond do
      e(object, :profile, :image, nil) -> Media.banner_url(object)
      e(object, :profile, :icon, nil) -> Media.avatar_url(object)
      true -> nil
    end
    |> Bonfire.UI.Common.SEOImage.absolute_url()
  end

  def site_config(_conn \\ nil) do
    name = Config.get([:ui, :theme, :instance_name]) || Bonfire.Application.name_and_flavour()
    description = Config.get([:ui, :theme, :instance_description])

    SEO.Site.build(
      default_title: name,
      description: description,
      title_suffix: " · #{name}",
      # theme_color intentionally not set here: the canonical <meta name="theme-color">
      # is emitted for every page (not just guest renders) in EndpointTemplate.include_assets/2
      # and must stay in sync with the PWA manifest's theme_color
      mask_icon_url: "/images/bonfire-icon.svg"
      # manifest_url: "/site.webmanifest"
    )
  end

  def open_graph_config(_conn \\ nil) do
    name = Config.get([:ui, :theme, :instance_name]) || Bonfire.Application.name_and_flavour()
    description = Config.get([:ui, :theme, :instance_description])

    SEO.OpenGraph.build(
      description: description,
      site_name: name,
      type: :website,
      locale: Bonfire.Common.Localise.get_locale_id() |> to_string()
    )
  end

  def twitter_config(_conn \\ nil) do
    SEO.Twitter.build(
      site: "@SwitchToBonfire",
      # site_id: "0",
      # creator: "@SwitchToBonfire",
      # creator_id: "0",
      card: :summary
    )
  end
end
