defmodule Bonfire.UI.Common.CrawlerBoundaries.Plug do
  import Plug.Conn
  import Bonfire.Common.Utils
  import Untangle
  alias Bonfire.UI.Common.CrawlerBoundaries

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    settings = CrawlerBoundaries.get_settings(current_user(conn))

    if settings.enable && settings.enable_server_blocking do
      check_and_block_crawler(conn, settings)
    else
      conn
    end
  end

  defp check_and_block_crawler(conn, settings) do
    user_agent = get_req_header(conn, "user-agent") |> List.first() || ""
    ip = get_peer_ip(conn)

    cond do
      blocked_crawler?(user_agent, settings.blocked_crawlers) ->
        block_request(
          conn,
          settings,
          "AI crawler blocked: #{extract_bot_name(user_agent)}",
          ip,
          user_agent
        )

      # settings.rate_limit_enabled && rate_limited?(ip, settings) ->
      #   block_request(conn, settings, "Rate limit exceeded", ip, user_agent)

      true ->
        conn
    end
  end

  defp blocked_crawler?(user_agent, blocked_crawlers) do
    user_agent_lower = String.downcase(user_agent)

    Enum.any?(blocked_crawlers, fn bot ->
      String.contains?(user_agent_lower, String.downcase(bot))
    end)
  end

  # defp rate_limited?(ip, settings) do
  #   case Hammer.check_rate(
  #     "crawler_block:#{ip}", 
  #     settings.rate_limit_window_ms, 
  #     settings.rate_limit_requests
  #   ) do
  #     {:allow, _count} -> false
  #     {:deny, _limit} -> true
  #     _ -> false  # If Hammer is not available, don't rate limit
  #   end
  # rescue
  #   _ -> false  # If Hammer is not configured, don't rate limit
  # end

  defp block_request(conn, settings, reason, ip, user_agent) do
    if settings.log_blocked_requests do
      info(user_agent, "Blocked crawler request: #{reason}, IP: #{ip}, User-Agent")
    end

    status = settings.block_response_status
    message = settings.block_response_message

    conn
    |> put_status(status)
    |> put_resp_content_type("text/plain")
    |> send_resp(status, message)
    |> halt()
  end

  defp extract_bot_name(user_agent) do
    cond do
      String.contains?(user_agent, "GPTBot") -> "GPTBot"
      String.contains?(user_agent, "Google-Extended") -> "Google-Extended"
      String.contains?(user_agent, "CCBot") -> "CCBot"
      String.contains?(user_agent, "Claude-Web") -> "Claude-Web"
      String.contains?(user_agent, "ByteSpider") -> "ByteSpider"
      true -> String.slice(user_agent, 0, 50)
    end
  end

  defp get_peer_ip(conn) do
    case get_peer_data(conn) do
      %{address: address} -> :inet.ntoa(address) |> to_string()
      _ -> "unknown"
    end
  end
end
