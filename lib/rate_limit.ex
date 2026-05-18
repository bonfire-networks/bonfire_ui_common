defmodule Bonfire.UI.Common.RateLimit do
  @moduledoc """
  Rate limiter for Bonfire using Hammer 7.x with ETS backend.

  Provides rate limiting for form submissions and other user actions to protect against abuse.
  """

  use Bonfire.Common.Utils
  use Hammer, backend: :ets

  @doc """
  Check whether `ip` has exceeded the rate limit for `key_prefix`.

  Reads scale_ms and limit from `:bonfire, :rate_limit, key_prefix` config,
  falling back to `default_scale_ms` and `default_limit`.

  Returns `:ok` if allowed, `{:error, retry_after_seconds}` if denied.
  """
  def check(key_prefix, ip, default_scale_ms \\ 60_000, default_limit \\ 5) do
    rate_config = Bonfire.Common.Config.get([:bonfire, :rate_limit, key_prefix], [])
    disabled = Bonfire.Common.Config.get([:bonfire, :rate_limit, :disabled], false)

    if disabled or Keyword.get(rate_config, :disabled, false) do
      :ok
    else
      scale_ms = Keyword.get(rate_config, :scale_ms) || default_scale_ms
      limit = Keyword.get(rate_config, :limit) || default_limit
      key = "#{key_prefix}:#{ip}"

      case hit(key, scale_ms, limit) do
        {:allow, _} -> :ok
        {:deny, retry_after} -> {:error, div(retry_after, 1_000)}
      end
    end
  end
end
