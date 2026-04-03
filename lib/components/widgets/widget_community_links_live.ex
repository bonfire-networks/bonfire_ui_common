defmodule Bonfire.UI.Common.WidgetCommunityLinksLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop links, :list, default: nil

  @doc """
  Normalizes community links from various formats (keyword lists, maps, list of maps,
  JSON-deserialized keyword lists) into a consistent `[{name, url}]` tuple list.

  Accepts an optional `:as` option — `:map` returns `[%{name: ..., url: ...}]` instead.
  """
  def normalize_links(links, opts \\ [])

  def normalize_links(links, opts) when is_list(links) do
    as = Keyword.get(opts, :as, :tuple)

    Enum.flat_map(links, fn
      %{name: name, url: url} -> [to_link(name, url, as)]
      %{"name" => name, "url" => url} -> [to_link(name, url, as)]
      kw when is_list(kw) -> [to_link(kw[:name], kw[:url], as)]
      {name, url} when is_binary(url) -> [to_link(name, url, as)]
      _ -> []
    end)
  end

  def normalize_links(links, opts) when is_map(links) do
    as = Keyword.get(opts, :as, :tuple)
    Enum.map(links, fn {name, url} -> to_link(name, url, as) end)
  end

  def normalize_links(_, _opts), do: []

  defp to_link(name, url, :map), do: %{name: to_string(name), url: to_string(url)}
  defp to_link(name, url, _), do: {to_string(name), to_string(url)}
end
