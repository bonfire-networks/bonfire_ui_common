defmodule Bonfire.UI.Common.SEO do
  use SEO,
    json_library: Jason,
    # a function reference will be called with a conn during render
    site: &__MODULE__.site_config/1,
    open_graph: &__MODULE__.open_graph_config/1,
    # facebook: &__MODULE__.facebook_config/1,
    twitter: &__MODULE__.twitter_config/1

  alias Bonfire.Common.Config
  alias Bonfire.Web.Router.Helpers, as: Routes

  def site_config(_conn \\ nil) do
    name = Config.get([:ui, :theme, :instance_name]) || Bonfire.Application.name()
    description = Config.get([:ui, :theme, :instance_description])

    SEO.Site.build(
      default_title: name,
      description: description,
      title_suffix: " · #{name}",
      # TODO: based on selected theme?
      theme_color: "#1B74E4",
      mask_icon_url: "/images/bonfire-icon.svg"
      # manifest_url: "/site.webmanifest"
    )
  end

  def open_graph_config(_conn \\ nil) do
    name = Config.get([:ui, :theme, :instance_name]) || Bonfire.Application.name()
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
