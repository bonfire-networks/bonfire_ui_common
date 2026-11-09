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

  @doc """
  The links to show visitors, as `[{name, url}]`, with each name looked up in the visitor's language. A name the instance wrote itself has no translation and stays as written. The names the default config ships ("About Bonfire", "Forum", ...) are declared for extraction in `Bonfire.UI.Common.RuntimeConfig`, in the same domain as this lookup. Use `normalize_links/2` where the names are edited rather than shown, so the stored text is not replaced by a translation.
  """
  def localised_links(links) do
    links
    |> normalize_links()
    |> Enum.map(fn {name, url} -> {localise_dynamic(name, __MODULE__), url} end)
  end

  defp to_link(name, url, :map), do: %{name: to_string(name), url: to_string(url)}
  defp to_link(name, url, _), do: {to_string(name), to_string(url)}
end
