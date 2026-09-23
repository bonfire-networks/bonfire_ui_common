defmodule Bonfire.UI.Common.CaretIconsBrowserTest do
  @moduledoc "Run after building CSS; compares the shipped styles against Phosphor icon data in a real browser."
  use ExUnit.Case, async: false

  alias Wallaby.Browser

  @moduletag :ui
  @moduletag :browser
  @assets Path.expand("../../assets", __DIR__)

  test "caret masks match canonical outlines under every icon theme" do
    {:ok, _} = Application.ensure_all_started(:wallaby)
    {:ok, session} = Wallaby.start_session()
    on_exit(fn -> Wallaby.end_session(session) end)

    icons =
      @assets
      |> Path.join("node_modules/@iconify/json/json/ph.json")
      |> File.read!()
      |> Jason.decode!()
      |> Map.fetch!("icons")

    styles =
      [Application.app_dir(:bonfire, "priv/static/assets/bonfire_basic.css")] ++
        Enum.map(["icons", "icons-fill", "icons-duotone", "icons-light"], fn name ->
          Path.join(@assets, "static/images/icons/#{name}.css")
        end)

    html =
      "<!doctype html><html><head>" <>
        Enum.map_join(styles, fn path -> "<style>#{File.read!(path)}</style>" end) <>
        "</head><body></body></html>"

    session
    |> Browser.visit("about:blank")
    |> Browser.execute_script(
      "document.open(); document.write(arguments[0]); document.close();",
      [html]
    )
    |> Browser.execute_script(
      ~S"""
      const results = [];
      const icon = document.createElement('span');
      icon.style.maskImage = 'var(--Iy)';
      document.body.append(icon);
      for (const theme of ['regular', 'fill', 'duotone', 'light']) {
        document.documentElement.dataset.iconWeight = theme;
        for (const direction of ['right', 'left', 'down', 'up']) {
          for (const weight of ['', 'fill', 'duotone', 'bold', 'light', 'thin']) {
            icon.setAttribute('iconify', `carbon:chevron-${direction}${weight ? '-' + weight : ''}`);
            const mask = getComputedStyle(icon).maskImage;
            const data = mask.match(/^url\(["']?data:image\/svg\+xml[^,]*,(.*?)["']?\)$/);
            results.push([theme, direction, weight, data ? decodeURIComponent(data[1]) : mask]);
          }
        }
      }
      return results;
      """,
      fn results ->
        assert length(results) == 96

        for [theme, direction, weight, svg] <- results do
          expected_weight =
            cond do
              theme == "light" -> "-light"
              weight in ["bold", "light", "thin"] -> "-#{weight}"
              true -> ""
            end

          expected = icons["caret-#{direction}#{expected_weight}"]["body"]

          assert Floki.find(Floki.parse_fragment!(svg), "path") ==
                   Floki.find(Floki.parse_fragment!(expected), "path"),
                 "Wrong caret outline: #{direction}, weight=#{weight}, theme=#{theme}"
        end
      end
    )
  end
end
