defmodule Bonfire.UI.Common.SEO do
  use SEO,
    json_library: Jason

  alias Bonfire.Common.Config

  def config do
    name = Config.get([:ui, :theme, :instance_name]) || Bonfire.Application.name()
    description = Config.get([:ui, :theme, :instance_description])

    [
      {SEO.Site,
       SEO.Site.build(
         # default_title: "Default Title",
         description: description,
         title_suffix: " · #{name}"
       )},
      {SEO.OpenGraph,
       SEO.OpenGraph.build(
         description: description,
         site_name: name,
         type: :website,
         locale: Bonfire.Common.Localise.get_locale_id()
       )},
      {SEO.Twitter,
       SEO.Twitter.build(
         site: "@SwitchToBonfire",
         # site_id: "27704724",
         # creator: "@SwitchToBonfire",
         # creator_id: "27704724",
         card: :summary
       )}
      # {SEO.Unfurl, %{}},
      # {SEO.Breadcrumb, []}
    ]
  end

  use Phoenix.Component

  attr(:item, :any, required: true)
  attr(:page_title, :string, default: nil)
  attr(:json_library, :atom, default: Jason)

  @doc "Provide SEO juice"
  def juice(assigns) do
    ~H"""
    <SEO.Site.meta item={SEO.Build.site(@item, config(SEO.Site))} page_title={@page_title} />
    <SEO.OpenGraph.meta item={SEO.Build.open_graph(@item, config(SEO.OpenGraph))} />
    <SEO.Twitter.meta item={SEO.Build.twitter(@item, config(SEO.Twitter))} />
    <SEO.Breadcrumb.meta
      item={SEO.Build.breadcrumb_list(@item, config(SEO.Breadcrumb))}
      json_library={@json_library}
    />
    """
  end
end
