defmodule Bonfire.UI.Common.SEOImage do
  use Untangle

  def generate_path(id, author_id, title, body, author, image \\ nil) do
    filename = og_image_paths(id, author_id)

    if not File.exists?(filename) do
      with {:ok, filename} <- generate_og_image(filename, title, body, author, image) do
        filename
      else e ->
        error(e)
        nil
      end
    else
      filename
    end
  end

  defp generate_og_image(filename, nil, body, author, image),
    do: generate_og_image(filename, body, nil, author, image)

  defp generate_og_image(filename, title, body, author, image) do
    {title_1, title_2} = og_split_lines(title || "", 31)
    {body_1, body_2} = og_split_lines(body || "", 40)
    # TODO: configurable
    font_family = "'Inter', 'Noto Sans', 'Roboto', 'system-ui', 'sans-serif'"

    svg =
      """
      <svg viewbox="0 0 1200 600" width="1200" height="600" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
          <defs>
          <linearGradient y2="1" x2="1" y1="0.14844" x1="0.53125" id="gradient">
          <stop offset="0" stop-opacity="0.99609" stop-color="#800909"/>
          <stop offset="0.99219" stop-opacity="0.97656" stop-color="#ff8300"/>
          </linearGradient>
          </defs>
          <g>
          <rect stroke="#000" height="800" width="1800" y="0" x="0" stroke-width="0" fill="url(#gradient)"/>
          <text font-style="normal" font-weight="normal" xml:space="preserve" text-anchor="start" font-family="#{font_family}" font-size="70" y="150" x="100" stroke-width="0" stroke="#000" fill="#f8fafc">#{title_1}</text>
          <text font-style="normal" font-weight="normal" xml:space="preserve" text-anchor="start" font-family="#{font_family}" font-size="70" y="250" x="100" stroke-width="0" stroke="#000" fill="#f8fafc">#{title_2}</text>
          <text font-style="normal" font-weight="normal" xml:space="preserve" text-anchor="start" font-family="#{font_family}" font-size="50" y="350" x="100" stroke-width="0" stroke="#000" fill="#f8fafc">#{body_1}</text>
          <text font-style="normal" font-weight="normal" xml:space="preserve" text-anchor="start" font-family="#{font_family}" font-size="50" y="450" x="100" stroke-width="0" stroke="#000" fill="#f8fafc">#{body_2}</text>
          <text font-style="normal" font-weight="normal" xml:space="preserve" text-anchor="start" font-family="#{font_family}" font-size="30" y="550" x="50" stroke-width="0" stroke="#000" fill="#f8fafc" opacity="0.5">#{author}</text>
          
          </g>
      </svg>
      """

    # |> IO.inspect

    # not supported by Vips?
    # <image xml:space="preserve"
    #         y="500" x="1100"
    #         width="100" height="100" 
    #         xlink:href="#{image}" 
    #     />

    write_og_image(filename, svg, image)
    |> info("write_og_image")
  end

  defp og_image_paths(id, author_id) do
    # TODO: configurable
    root_dir = "data/uploads/"
    path = Path.join([root_dir, author_id || "unknown", "og_previews"])

    File.mkdir_p!(path)

    Path.join([path, "#{id}.png"])
  end

  defp og_split_lines(title, max_length \\ 31) do
    title
    |> String.split(" ")
    |> Enum.reduce_while({"", ""}, fn word, {title_1, title_2} ->
      cond do
        String.length(title_1 <> " " <> word) <= max_length ->
          {:cont, {title_1 <> " " <> word, title_2}}

        String.length(title_2 <> " " <> word) <= max_length - 3 ->
          {:cont, {title_1, title_2 <> " " <> word}}

        true ->
          {:halt, {title_1, title_2 <> "..."}}
      end
    end)
  end

  defp write_og_image(filename, svg, image \\ nil)

  defp write_og_image(filename, svg, nil) do
    with {:ok, {svg_image, _}} <- Vix.Vips.Operation.svgload_buffer(svg),
         {:ok, _} <- Image.write(svg_image, filename) do
      # ^ save to PNG because for some reason OpenGraph does not support SVG
      {:ok, filename}
    end
  end

  defp write_og_image(filename, svg, overlay_path) do
    with {:ok, {svg_image, _}} <- Vix.Vips.Operation.svgload_buffer(svg),
        {:ok, overlay_image} <- Image.open(overlay_path),
         IO.inspect(overlay_path, label: "ok imagesss"),
         {:ok, overlay_image} <- Image.thumbnail(overlay_image, "200x200"),
         {:ok, composed_img} <- Image.compose(svg_image, overlay_image, x: 980, y: 380),
         {:ok, _} <- Image.write(composed_img, filename) do
      {:ok, filename}
    else
      e ->
        error(e)
        write_og_image(filename, svg, nil)
    end
  end
end
