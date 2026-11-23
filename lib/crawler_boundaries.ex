defmodule Bonfire.UI.Common.CrawlerBoundaries do
  @moduledoc """
  Defines the structure and defaults for robots.txt and crawler blocking settings.
  """

  use Bonfire.Common.Config
  use Bonfire.Common.Settings
  alias Bonfire.Common.Cache
  alias Bonfire.Common.URIs

  @predefined_crawlers [
    # AI Training Crawlers
    %{
      name: "OpenAI GPTBot",
      user_agent: "GPTBot",
      description: "OpenAI's web crawler for ChatGPT",
      category: "AI Training",
      enabled_by_default: true
    },
    %{
      name: "Google Bard/Gemini",
      user_agent: "Google-Extended",
      description: "Google's AI training crawler",
      category: "AI Training",
      enabled_by_default: true
    },
    %{
      name: "Anthropic Claude",
      user_agent: "Claude-Web",
      description: "Anthropic's web crawler",
      category: "AI Training",
      enabled_by_default: true
    },
    %{
      name: "Common Crawl",
      user_agent: "CCBot",
      description: "Common Crawl foundation crawler used for AI training",
      category: "AI Training",
      enabled_by_default: true
    },
    %{
      name: "ByteDance AI",
      user_agent: "ByteSpider",
      description: "ByteDance/TikTok AI crawler",
      category: "AI Training",
      enabled_by_default: true
    },
    %{
      name: "AI2 Bot",
      user_agent: "AI2Bot",
      description: "Allen Institute for AI crawler",
      category: "AI Training",
      enabled_by_default: true
    },
    %{
      name: "Meta AI",
      user_agent: "FacebookBot",
      description: "Meta's AI crawler",
      category: "AI Training",
      enabled_by_default: true
    },
    %{
      name: "Perplexity AI",
      user_agent: "PerplexityBot",
      description: "Perplexity AI search crawler",
      category: "AI Training",
      enabled_by_default: true
    },
    %{
      name: "ChatGPT User",
      user_agent: "ChatGPT-User",
      description: "ChatGPT user browsing requests",
      category: "AI Training",
      enabled_by_default: true
    },
    %{
      name: "Cohere AI",
      user_agent: "CohereCrawler",
      description: "Cohere AI crawler",
      category: "AI Training",
      enabled_by_default: true
    },
    %{
      name: "Diffbot",
      user_agent: "Diffbot",
      description: "Diffbot AI-powered web scraper",
      category: "AI Training",
      enabled_by_default: true
    },
    %{
      name: "ImagesiftBot",
      user_agent: "ImagesiftBot",
      description: "AI image analysis crawler",
      category: "AI Training",
      enabled_by_default: false
    },
    %{
      name: "Omgilibot",
      user_agent: "omgilibot",
      description: "Omgili news crawler for AI",
      category: "AI Training",
      enabled_by_default: false
    },

    # Search Engine Indexers (usually you want these, but some might not)
    %{
      name: "Bing Bot",
      user_agent: "bingbot",
      description: "Microsoft Bing search crawler",
      category: "Search Engines",
      enabled_by_default: false
    },
    %{
      name: "Googlebot",
      user_agent: "Googlebot",
      description: "Google search crawler",
      category: "Search Engines",
      enabled_by_default: false
    },
    %{
      name: "DuckDuckGo",
      user_agent: "DuckDuckBot",
      description: "DuckDuckGo search crawler",
      category: "Search Engines",
      enabled_by_default: false
    },
    %{
      name: "Yandex Bot",
      user_agent: "YandexBot",
      description: "Yandex search engine crawler",
      category: "Search Engines",
      enabled_by_default: false
    },
    %{
      name: "Baidu Spider",
      user_agent: "Baiduspider",
      description: "Baidu search engine crawler",
      category: "Search Engines",
      enabled_by_default: true
    },
    %{
      name: "Yahoo Slurp",
      user_agent: "Slurp",
      description: "Yahoo search crawler",
      category: "Search Engines",
      enabled_by_default: false
    },
    %{
      name: "Sogou Spider",
      user_agent: "Sogou",
      description: "Sogou search engine crawler",
      category: "Search Engines",
      enabled_by_default: true
    },

    # Social Media Crawlers
    %{
      name: "Facebook Crawler",
      user_agent: "facebookexternalhit",
      description: "Facebook link preview crawler",
      category: "Social Media",
      enabled_by_default: false
    },
    %{
      name: "Twitter Bot",
      user_agent: "Twitterbot",
      description: "Twitter link preview crawler",
      category: "Social Media",
      enabled_by_default: false
    },
    %{
      name: "LinkedIn Bot",
      user_agent: "LinkedInBot",
      description: "LinkedIn link preview crawler",
      category: "Social Media",
      enabled_by_default: false
    },
    %{
      name: "WhatsApp Crawler",
      user_agent: "WhatsApp",
      description: "WhatsApp link preview crawler",
      category: "Social Media",
      enabled_by_default: false
    },
    %{
      name: "Telegram Bot",
      user_agent: "TelegramBot",
      description: "Telegram link preview crawler",
      category: "Social Media",
      enabled_by_default: false
    },
    %{
      name: "Discord Bot",
      user_agent: "Discordbot",
      description: "Discord link preview crawler",
      category: "Social Media",
      enabled_by_default: false
    },

    # SEO & Analytics Tools
    %{
      name: "Ahrefs Bot",
      user_agent: "AhrefsBot",
      description: "Ahrefs SEO analysis crawler",
      category: "SEO Tools",
      enabled_by_default: true
    },
    %{
      name: "SemRush Bot",
      user_agent: "SemrushBot",
      description: "SemRush SEO crawler",
      category: "SEO Tools",
      enabled_by_default: true
    },
    %{
      name: "Moz Bot",
      user_agent: "rogerbot",
      description: "Moz SEO crawler",
      category: "SEO Tools",
      enabled_by_default: true
    },
    %{
      name: "Majestic Crawler",
      user_agent: "MJ12bot",
      description: "Majestic SEO backlink crawler",
      category: "SEO Tools",
      enabled_by_default: true
    },
    %{
      name: "SEOkicks Bot",
      user_agent: "seokicks",
      description: "SEOkicks analysis crawler",
      category: "SEO Tools",
      enabled_by_default: true
    },
    %{
      name: "DotBot",
      user_agent: "DotBot",
      description: "OpenSiteExplorer/Moz crawler",
      category: "SEO Tools",
      enabled_by_default: true
    },

    # Archive & Backup Services
    %{
      name: "Internet Archive",
      user_agent: "ia_archiver",
      description: "Wayback Machine archival crawler",
      category: "Archives",
      enabled_by_default: false
    },
    %{
      name: "Archive.today",
      user_agent: "archive.org_bot",
      description: "Archive.today snapshot service",
      category: "Archives",
      enabled_by_default: false
    },

    # Security & Monitoring
    %{
      name: "Qualys SSL Labs",
      user_agent: "ssllabs",
      description: "SSL Labs security scanner",
      category: "Security",
      enabled_by_default: false
    },
    %{
      name: "Security Trails",
      user_agent: "SecurityTrails",
      description: "Security monitoring crawler",
      category: "Security",
      enabled_by_default: true
    },
    %{
      name: "Shodan",
      user_agent: "Shodan",
      description: "Shodan security scanner",
      category: "Security",
      enabled_by_default: true
    },

    # Content Scrapers & Aggregators
    %{
      name: "Scrapy",
      user_agent: "Scrapy",
      description: "Generic Scrapy framework crawler",
      category: "Scrapers",
      enabled_by_default: true
    },
    %{
      name: "Python Requests",
      user_agent: "python-requests",
      description: "Python requests library (often scrapers)",
      category: "Scrapers",
      enabled_by_default: true
    },
    %{
      name: "cURL",
      user_agent: "curl",
      description: "cURL command line tool",
      category: "Scrapers",
      enabled_by_default: false
    },
    %{
      name: "Wget",
      user_agent: "Wget",
      description: "Wget download tool",
      category: "Scrapers",
      enabled_by_default: false
    },
    %{
      name: "Apache HTTP Client",
      user_agent: "Apache-HttpClient",
      description: "Apache HTTP client (often automated)",
      category: "Scrapers",
      enabled_by_default: true
    },

    # Academic & Research
    %{
      name: "CiteSeerX",
      user_agent: "CiteSeerXBot",
      description: "Academic paper indexing crawler",
      category: "Academic",
      enabled_by_default: false
    },
    %{
      name: "ResearchGate",
      user_agent: "ResearchGate",
      description: "ResearchGate academic crawler",
      category: "Academic",
      enabled_by_default: false
    },

    # E-commerce & Price Monitoring
    %{
      name: "PriceGrabber",
      user_agent: "PriceGrabber",
      description: "Price comparison crawler",
      category: "E-commerce",
      enabled_by_default: true
    },
    %{
      name: "Shopping Bot",
      user_agent: "Shopbot",
      description: "Generic shopping comparison bot",
      category: "E-commerce",
      enabled_by_default: true
    },
    %{
      name: "Nextag",
      user_agent: "NextGenSearchBot",
      description: "Nextag price comparison",
      category: "E-commerce",
      enabled_by_default: true
    },

    # News & Content Aggregators
    %{
      name: "Feedly",
      user_agent: "FeedlyBot",
      description: "Feedly RSS aggregator",
      category: "Content",
      enabled_by_default: false
    },
    %{
      name: "Flipboard",
      user_agent: "FlipboardProxy",
      description: "Flipboard content aggregator",
      category: "Content",
      enabled_by_default: false
    },
    %{
      name: "Apple News",
      user_agent: "AppleNewsBot",
      description: "Apple News content crawler",
      category: "Content",
      enabled_by_default: false
    },

    # Suspicious/Generic
    %{
      name: "Generic Bot",
      user_agent: "bot",
      description: "Generic user agents containing 'bot'",
      category: "Generic",
      enabled_by_default: false
    },
    %{
      name: "Spider",
      user_agent: "spider",
      description: "Generic user agents containing 'spider'",
      category: "Generic",
      enabled_by_default: false
    },
    %{
      name: "Crawler",
      user_agent: "crawler",
      description: "Generic user agents containing 'crawler'",
      category: "Generic",
      enabled_by_default: false
    }
  ]

  @default_settings %{
    # Robots.txt settings - default to blocking AI training and aggressive SEO/scraping bots
    blocked_crawlers:
      @predefined_crawlers
      |> Enum.filter(& &1.enabled_by_default)
      |> Enum.map(& &1.user_agent),
    custom_rules: "",
    enable: false,

    # Server-side blocking settings
    enable_server_blocking: true,
    block_response_status: 403,
    block_response_message: "Access denied",
    log_blocked_requests: true,

    # Rate limiting settings
    rate_limit_enabled: false,
    rate_limit_requests: 100,
    rate_limit_window_ms: 60_000
  }

  def predefined_crawlers, do: @predefined_crawlers
  def default_settings, do: @default_settings

  def crawlers_by_category do
    @predefined_crawlers
    |> Enum.group_by(& &1.category)
    |> Enum.sort_by(fn {category, _} ->
      case category do
        "AI Training" -> 1
        "Search Engines" -> 2
        "SEO Tools" -> 3
        "Scrapers" -> 4
        "Social Media" -> 5
        "Security" -> 6
        "E-commerce" -> 7
        "Content" -> 8
        "Archives" -> 9
        "Academic" -> 10
        "Generic" -> 11
        _ -> 99
      end
    end)
  end

  def get_settings(user \\ nil) do
    base_settings =
      if user do
        Settings.get(:robots_boundaries, %{}, user)
      else
        # Instance-wide settings
        Config.get(:robots_boundaries, %{})
      end
      # Ensure all required keys exist
      |> Enum.into(default_settings())
  end

  def put_settings(settings, scope, user) do
    validated_settings = validate_and_clean_settings(settings)

    Settings.put(:robots_boundaries, validated_settings, scope: scope, current_user: user)
    # TODO: clear robots.txt cache for :instance scope
  end

  def cached_robots_txt(settings) do
    Cache.maybe_apply_cached(fn -> generate_robots_txt(settings) end)
  end

  def generate_robots_txt(settings) do
    base_rules =
      if !settings.enable do
        "User-agent: *\nAllow: /\n\n"
      else
        blocked_rules =
          Enum.map(settings.blocked_crawlers, fn crawler ->
            "User-agent: #{crawler}\nDisallow: /\n"
          end)
          |> Enum.join("\n")

        default_allow = "User-agent: *\nAllow: /\n"

        "#{blocked_rules}\n#{default_allow}\n"
      end

    custom_rules =
      if settings.custom_rules && String.trim(settings.custom_rules) != "" do
        "\n# Custom Rules\n#{settings.custom_rules}\n"
      else
        ""
      end

    sitemap_url = URIs.based_url("/sitemap.xml")

    """
    # Robots.txt - Generated automatically
    # Last updated: #{DateTime.utc_now()}

    #{base_rules}#{custom_rules}
    Sitemap: #{sitemap_url}
    """
  end

  defp validate_and_clean_settings(settings) do
    settings
    |> Map.take(Map.keys(default_settings()))
    |> validate_blocked_crawlers()
    |> validate_response_status()
    |> validate_rate_limits()
  end

  defp validate_blocked_crawlers(settings) do
    valid_crawlers = Enum.map(@predefined_crawlers, & &1.user_agent)

    blocked_crawlers =
      case settings[:blocked_crawlers] do
        list when is_list(list) ->
          Enum.filter(list, &(&1 in valid_crawlers))

        _ ->
          default_settings().blocked_crawlers
      end

    Map.put(settings, :blocked_crawlers, blocked_crawlers)
  end

  defp validate_response_status(settings) do
    status =
      case settings[:block_response_status] do
        code when code in [403, 404, 429, 503] -> code
        _ -> default_settings().block_response_status
      end

    Map.put(settings, :block_response_status, status)
  end

  defp validate_rate_limits(settings) do
    default_settings = default_settings()

    settings
    |> Map.update(:rate_limit_requests, default_settings.rate_limit_requests, fn
      val when is_integer(val) and val > 0 -> val
      _ -> default_settings.rate_limit_requests
    end)
    |> Map.update(:rate_limit_window_ms, default_settings.rate_limit_window_ms, fn
      val when is_integer(val) and val >= 1000 -> val
      _ -> default_settings.rate_limit_window_ms
    end)
  end

  def get_crawler_by_user_agent(user_agent) do
    Enum.find(@predefined_crawlers, &(&1.user_agent == user_agent))
  end

  def get_category_info(category) do
    case category do
      "AI Training" ->
        %{
          description: "Crawlers that collect data for AI model training",
          recommendation: "Usually best to block these to protect your content",
          icon: "🤖"
        }

      "Search Engines" ->
        %{
          description: "Major search engine crawlers for indexing",
          recommendation: "Usually want to allow these for SEO",
          icon: "🔍"
        }

      "SEO Tools" ->
        %{
          description: "SEO analysis and backlink monitoring tools",
          recommendation: "Often aggressive, consider blocking",
          icon: "📊"
        }

      "Scrapers" ->
        %{
          description: "Generic scraping tools and frameworks",
          recommendation: "Usually best to block these",
          icon: "🕷️"
        }

      "Social Media" ->
        %{
          description: "Social media platforms for link previews",
          recommendation: "Usually want to allow for social sharing",
          icon: "📱"
        }

      "Security" ->
        %{
          description: "Security scanners and monitoring tools",
          recommendation: "May want to block depending on privacy needs",
          icon: "🔒"
        }

      "E-commerce" ->
        %{
          description: "Price monitoring and shopping comparison bots",
          recommendation: "Often unwanted competitive intelligence",
          icon: "🛒"
        }

      "Content" ->
        %{
          description: "Content aggregators and RSS readers",
          recommendation: "Usually fine to allow",
          icon: "📰"
        }

      "Archives" ->
        %{
          description: "Web archival services",
          recommendation: "Consider allowing for historical preservation",
          icon: "📚"
        }

      "Academic" ->
        %{
          description: "Academic and research crawlers",
          recommendation: "Usually fine to allow",
          icon: "🎓"
        }

      "Generic" ->
        %{
          description: "Generic bot patterns (broad matches)",
          recommendation: "Use carefully - may block legitimate tools",
          icon: "⚠️"
        }

      _ ->
        %{
          description: "Other crawlers",
          recommendation: "Review individually",
          icon: "❓"
        }
    end
  end
end
