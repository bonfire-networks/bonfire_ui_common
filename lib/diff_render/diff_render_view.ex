defmodule Bonfire.UI.Common.DiffRenderView do
  use Bonfire.UI.Common.Web, {:view, [namespace: Bonfire.UI.Common]}


  def file_header(patch, status) do
    from = patch.from
    to = patch.to

    case status do
      "changed" -> from
      "renamed" -> "#{from} -> #{to}"
      "removed" -> from
      "added" -> to
    end
  end

  def patch_status(patch) do
    from = patch.from
    to = patch.to

    cond do
      !from -> "added"
      !to -> "removed"
      from == to -> "changed"
      true -> "renamed"
    end
  end

  def line_number(ln) when is_nil(ln), do: ""
  def line_number(ln), do: to_string(ln)

  def line_id(patch, line) do
    hash = :erlang.phash2({patch.from, patch.to})

    ln = "-#{line.from_line_number}-#{line.to_line_number}"

    [to_string(hash), ln]
  end

  def line_type(line), do: to_string(line.type)

  def line_text("+" <> text),
    do: [content_tag(:span, "+ ", class: "ghd-line-status"), text_content(text)]

  def line_text("-" <> text),
    do: [content_tag(:span, "- ", class: "ghd-line-status"), text_content(text)]

  def line_text(" " <> text),
    do: [content_tag(:span, "  ", class: "ghd-line-status"), text_content(text)]

  def line_text(text), do: [text_content(text)]

  # def text_content(text), do: content_tag(:span, text))
  def text_content(text), do: raw(Makeup.highlight(text))
end
