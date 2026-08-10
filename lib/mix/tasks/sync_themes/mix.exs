defmodule Bonfire.SyncThemes do
  use Mix.Project

  # Buildable as a standalone escript (see `just sync-themes`) so the flavour installer can sync themes without a compiled app 
  def project do
    [
      app: :sync_themes,
      version: "0.1.0-alpha.1",
      elixir: "~> 1.11",
      escript: [main_module: Mix.Tasks.Bonfire.SyncThemes]
    ]
  end
end
