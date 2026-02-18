defmodule Bonfire.UI.Common.Cache.HTTPPurge.Varnish do
  @moduledoc """
  HTTP cache purge adapter for Varnish.

  Configured via `VARNISH_URL` env var (default: `http://localhost:80`),
  which is resolved at startup in `Bonfire.Common.RuntimeConfig`.

  Tag-based purging (`bust_tags/1`) requires the `xkey` vmod and is not
  implemented here — extend if your Varnish setup supports it.
  """

  @behaviour Bonfire.Common.Cache.HTTPPurge
  use Untangle

  def bust_urls(urls) when is_list(urls) do
    Enum.each(urls, &purge_one/1)
    :ok
  end

  def bust_tags(_tags), do: :ok

  defp purge_one(path) do
    base = Bonfire.Common.Cache.HTTPPurge.config(:varnish_url) || "http://localhost:80"
    url = "#{base}#{path}"

    case Req.request(method: :purge, url: url) do
      {:ok, _} -> :ok
      {:error, reason} -> error(reason, "Varnish purge failed for #{path}")
    end
  end
end
