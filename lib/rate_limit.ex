defmodule Bonfire.UI.Common.RateLimit do
  @moduledoc """
  Rate limiter for Bonfire using Hammer 7.x with ETS backend.

  Provides rate limiting for form submissions and other user actions to protect against abuse.
  """

  use Hammer, backend: :ets
end
