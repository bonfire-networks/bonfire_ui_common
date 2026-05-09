defmodule Bonfire.UI.Common.TailwindSources do
  @moduledoc """
  Generates `assets/css/_tailwind_sources.css` so Tailwind v4 sees all bonfire extensions.

  Tailwind v4 respects `.gitignore` when expanding wildcards in `@source`, so gitignored extensions and forks match nothing with a wildcard. Explicit per-extension `@source` lines do work, so this module generates one pair per bonfire dep whose `lib/` contains Phoenix/Surface templates or LiveView/View modules.

  Registered as a Phoenix watcher in `config/dev.exs` so the file is regenerated whenever the server starts. Can also be run manually via `mix bonfire.gen_tailwind_sources` if necessary (e.g. before a prod build or in CI scripts).
  """

  # CSS file lives 4 dirs deep from the app root — relative paths climb 4 levels.
  @ups "../../../../"

  @ui_globs [
    "/lib/**/*.{leex,heex,sface}",
    "/lib/**/*{_live,_view}.ex"
  ]

  def generate do
    packages =
      Bonfire.Mixer.deps_for(:bonfire)
      |> Enum.filter(&has_ui_files?/1)

    File.write!(output_path(), file_content(packages))
    IO.puts("[TailwindSources] Wrote #{length(packages)} source(s) to #{output_path()}")
  end

  defp has_ui_files?(dep) do
    Enum.any?(@ui_globs, &(Bonfire.Mixer.dep_paths(dep, &1) != []))
  end

  defp source_lines(dep) do
    rel = @ups <> Bonfire.Mixer.dep_path(dep)

    [
      ~s|@source "#{rel}/lib/**/*.{leex,heex,sface}";|,
      ~s|@source "#{rel}/lib/**/*{_live,_view}.ex";|
    ]
  end

  defp file_content(packages) do
    sources = Enum.flat_map(packages, &source_lines/1)

    """
    /*
     * AUTO-GENERATED — do not edit.
     * Regenerated at server start (config/dev.exs watcher) or via `mix bonfire.gen_tailwind_sources`.
     *
     * One pair of @source lines per bonfire dep whose lib/ contains Phoenix/Surface templates
     * or LiveView/View modules. Tailwind v4 respects .gitignore when expanding wildcards in
     * @source, so gitignored extensions/forks must be listed explicitly.
     */
    #{Enum.join(sources, "\n")}
    """
  end

  defp output_path do
    cond do
      File.dir?("extensions/bonfire_ui_common") ->
        "extensions/bonfire_ui_common/assets/css/_tailwind_sources.css"

      File.dir?("deps/bonfire_ui_common") ->
        "deps/bonfire_ui_common/assets/css/_tailwind_sources.css"

      true ->
        raise "Could not locate bonfire_ui_common under extensions/ or deps/"
    end
  end
end
