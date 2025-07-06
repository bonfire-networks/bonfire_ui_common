defmodule Bonfire.UI.Common.CrawlerBoundaries.SettingsLive do
  use Bonfire.UI.Common.Web, :stateful_component
  alias Bonfire.UI.Common.CrawlerBoundaries

  alias Bonfire.UI.Common.CrawlerBoundaries.{
    ConfigForm,
    PreviewPanel,
    CrawlerCategory,
    AdvancedSettings
  }

  prop scope, :any, default: nil

  data settings, :map, default: %{}
  data robots_txt_preview, :string, default: ""
  data show_advanced, :boolean, default: false
  data saving, :boolean, default: false

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)

    current_user = current_user(socket)
    scope = e(assigns(socket), :scope, nil) || :user

    settings =
      CrawlerBoundaries.get_settings(current_user)
      |> flood("settings")

    {:ok,
     socket
     |> assign(:settings, settings)
     |> assign(:robots_txt_preview, CrawlerBoundaries.generate_robots_txt(settings))
     |> assign(:show_advanced, false)
     |> assign(:scope, scope)}
  end

  def handle_event("update_setting", %{"key" => key, "value" => value}, socket) do
    current_settings = socket.assigns.settings

    updated_settings =
      case key do
        "blocked_crawlers" ->
          # Handle checkbox array
          blocked = Map.get(socket.assigns.temp_blocked || %{}, value, false)
          current_blocked = current_settings.blocked_crawlers || []

          new_blocked =
            if blocked do
              [value | current_blocked] |> Enum.uniq()
            else
              List.delete(current_blocked, value)
            end

          Map.put(current_settings, :blocked_crawlers, new_blocked)

        "enable" ->
          Map.put(current_settings, :enable, value in ["true", "on"])

        "enable_server_blocking" ->
          Map.put(current_settings, :enable_server_blocking, value in ["true", "on"])

        "log_blocked_requests" ->
          Map.put(current_settings, :log_blocked_requests, value in ["true", "on"])

        "rate_limit_enabled" ->
          Map.put(current_settings, :rate_limit_enabled, value in ["true", "on"])

        "block_response_status" ->
          Map.put(current_settings, :block_response_status, String.to_integer(value))

        "rate_limit_requests" ->
          Map.put(current_settings, :rate_limit_requests, String.to_integer(value))

        "rate_limit_window_ms" ->
          Map.put(current_settings, :rate_limit_window_ms, String.to_integer(value))

        _ ->
          Map.put(current_settings, String.to_atom(key), value)
      end

    # Auto-save the settings
    current_user = current_user(socket)
    scope = e(assigns(socket), :scope, nil) || :user
    save_result = CrawlerBoundaries.put_settings(updated_settings, scope, current_user)

    preview = CrawlerBoundaries.generate_robots_txt(updated_settings)

    socket =
      socket
      |> assign(:settings, updated_settings)
      |> assign(:robots_txt_preview, preview)
      # Clear saving state immediately after save
      |> assign(:saving, false)
      |> maybe_show_save_feedback(save_result, key)

    {:noreply, socket}
  end

  def handle_event("update_setting", %{"key" => key}, socket) do
    handle_event("update_setting", %{"key" => key, "value" => nil}, socket)
  end

  def handle_event("toggle_category", %{"category" => category}, socket) do
    category_crawlers =
      CrawlerBoundaries.crawlers_by_category()
      |> Enum.find(fn {cat, _} -> cat == category end)
      |> elem(1)
      |> Enum.map(& &1.user_agent)

    current_blocked = socket.assigns.settings.blocked_crawlers || []

    # If any crawler in this category is not blocked, block all
    # Otherwise, unblock all
    should_block = not Enum.all?(category_crawlers, &(&1 in current_blocked))

    new_blocked =
      if should_block do
        (current_blocked ++ category_crawlers) |> Enum.uniq()
      else
        current_blocked -- category_crawlers
      end

    updated_settings = Map.put(socket.assigns.settings, :blocked_crawlers, new_blocked)

    # Auto-save the settings
    current_user = current_user(socket)
    scope = e(assigns(socket), :scope, nil) || :user
    save_result = CrawlerBoundaries.put_settings(updated_settings, scope, current_user)

    preview = CrawlerBoundaries.generate_robots_txt(updated_settings)

    action_text = if should_block, do: "blocked", else: "unblocked"

    socket =
      socket
      |> assign(:settings, updated_settings)
      |> assign(:robots_txt_preview, preview)
      |> maybe_show_save_feedback(save_result, "toggle_category")
      |> put_flash(:info, "All #{category} crawlers #{action_text}")

    {:noreply, socket}
  end

  def handle_event("toggle_crawler", %{"crawler" => crawler}, socket) do
    current_blocked = socket.assigns.settings.blocked_crawlers || []

    new_blocked =
      if crawler in current_blocked do
        debug(crawler, "Unblocking crawler")
        List.delete(current_blocked, crawler)
      else
        debug(crawler, "Blocking crawler")
        [crawler | current_blocked] |> Enum.uniq()
      end

    updated_settings =
      Map.put(socket.assigns.settings, :blocked_crawlers, new_blocked)
      |> debug("Updated settings after toggling crawler")

    # Auto-save the settings
    current_user = current_user(socket)
    scope = e(assigns(socket), :scope, nil) || :user
    save_result = CrawlerBoundaries.put_settings(updated_settings, scope, current_user)

    preview = CrawlerBoundaries.generate_robots_txt(updated_settings)

    socket =
      socket
      |> assign(:settings, updated_settings)
      |> assign(:robots_txt_preview, preview)
      |> maybe_show_save_feedback(save_result, "toggle_crawler")

    {:noreply, socket}
  end

  def handle_event("toggle_advanced", _params, socket) do
    {:noreply, assign(socket, :show_advanced, !socket.assigns.show_advanced)}
  end

  def handle_event("reset_to_defaults", _params, socket) do
    default_settings = CrawlerBoundaries.default_settings()

    # Auto-save the default settings
    current_user = current_user(socket)
    scope = e(assigns(socket), :scope, nil) || :user
    save_result = CrawlerBoundaries.put_settings(default_settings, scope, current_user)

    preview = CrawlerBoundaries.generate_robots_txt(default_settings)

    socket =
      socket
      |> assign(:settings, default_settings)
      |> assign(:robots_txt_preview, preview)
      |> maybe_show_save_feedback(save_result, "reset")
      |> put_flash(:info, "Reset to default settings and saved")

    {:noreply, socket}
  end

  # Helper function to provide user feedback on save operations
  defp maybe_show_save_feedback(socket, save_result, action) do
    case save_result do
      {:ok, _} ->
        # Show brief success feedback for major actions
        socket =
          if action in ["reset", "toggle_category"] do
            put_flash(socket, :info, "✅ Settings saved")
          else
            socket
          end

        # Clear any saving state
        assign(socket, :saving, false)

      {:error, reason} ->
        socket
        |> put_flash(:error, "Failed to save configuration: #{reason}")
        |> assign(:saving, false)
    end
  end

  # def handle_event("test_config", _params, socket) do
  #   settings = socket.assigns.settings

  #   test_results = %{
  #     gptbot: would_block?("Mozilla/5.0 (compatible; GPTBot/1.0; +https://openai.com/gptbot)", settings),
  #     google_extended: would_block?("Mozilla/5.0 (compatible; Google-Extended)", settings),
  #     regular_browser: would_block?("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36", settings)
  #   }

  #   message = """
  #   Test results:
  #   • GPTBot: #{if test_results.gptbot, do: "🚫 BLOCKED", else: "✅ ALLOWED"}
  #   • Google-Extended: #{if test_results.google_extended, do: "🚫 BLOCKED", else: "✅ ALLOWED"}
  #   • Regular Browser: #{if test_results.regular_browser, do: "🚫 BLOCKED", else: "✅ ALLOWED"}
  #   """

  #   {:noreply, assign_flash(socket, :info, message)}
  # end

  # defp would_block?(user_agent, settings) do
  #   if !settings.enable do
  #     false
  #   else
  #     user_agent_lower = String.downcase(user_agent)
  #     Enum.any?(settings.blocked_crawlers, fn bot ->
  #       String.contains?(user_agent_lower, String.downcase(bot))
  #     end)
  #   end
  # end
end
