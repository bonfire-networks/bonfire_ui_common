defmodule Bonfire.UI.Common.Cache.HTTPPurge.Cloudflare do
  @moduledoc """
  HTTP cache purge adapter for Cloudflare.

  Configured via `CLOUDFLARE_ZONE_ID` and `CLOUDFLARE_API_TOKEN` env vars,
  resolved at startup in `Bonfire.Common.RuntimeConfig`. The API token must
  have the "Cache Purge" permission.

  Note: Cloudflare does not cache HTML by default — you need a Cache Rule
  set to "Cache Everything" for the paths you want cached.
  """

  @behaviour Bonfire.Common.Cache.HTTPPurge
  use Untangle

  def bust_urls(urls) when is_list(urls), do: purge(%{files: urls}, "urls #{inspect(urls)}")
  def bust_tags(tags) when is_list(tags), do: purge(%{tags: tags}, "tags #{inspect(tags)}")

  defp purge(body, label) do
    case creds() do
      {zone, token} ->
        Req.post(
          "https://api.cloudflare.com/client/v4/zones/#{zone}/purge_cache",
          json: body,
          headers: [{"Authorization", "Bearer #{token}"}]
        )
        |> case do
          {:ok, %{status: 200}} -> :ok
          {:ok, resp} -> error(resp, "Cloudflare purge failed for #{label}")
          {:error, reason} -> error(reason, "Cloudflare purge error for #{label}")
        end

      nil ->
        error("Cloudflare zone ID or API token not configured — skipping purge")
    end
  end

  defp creds do
    zone = Bonfire.Common.Cache.HTTPPurge.config(:cloudflare_zone_id)
    token = Bonfire.Common.Cache.HTTPPurge.config(:cloudflare_api_token)
    if zone && token, do: {zone, token}
  end
end
