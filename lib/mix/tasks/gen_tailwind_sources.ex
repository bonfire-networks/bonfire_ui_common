defmodule Mix.Tasks.Bonfire.GenTailwindSources do
  @moduledoc "Regenerates `assets/css/_tailwind_sources.css`. See `Bonfire.UI.Common.TailwindSources`."
  use Mix.Task

  @shortdoc "Regenerates the Tailwind v4 @source list for all bonfire deps"

  @impl Mix.Task
  def run(_args), do: Bonfire.UI.Common.TailwindSources.generate()
end
