defmodule Bonfire.UI.Common.CrawlerBoundaries.RobotsController do
  use Bonfire.UI.Common.Web, :controller
  alias Bonfire.UI.Common.CrawlerBoundaries

  def txt(conn, _params) do
    # Use instance-wide settings for robots.txt
    robots_content =
      CrawlerBoundaries.get_settings()
      |> CrawlerBoundaries.cached_robots_txt()

    conn
    |> put_resp_content_type("text/plain")
    |> text(robots_content)
  end
end
