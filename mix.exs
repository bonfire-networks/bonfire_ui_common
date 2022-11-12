Code.eval_file("mess.exs")

defmodule Bonfire.UI.Common.MixProject do
  use Mix.Project

  def project do
    [
      app: :bonfire_ui_common,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      compilers: Mix.compilers(),
      deps:
        Mess.deps([
          {:phoenix_live_reload, "~> 1.2", only: :dev},
          {:floki, "~> 0.32.1", only: :test},
          {:dbg, "~> 1.0", only: :dev},
          {:zest, "~> 0.1", optional: true}
          # {:bonfire_search, "https://github.com/bonfire-networks/bonfire_search#main", optional: true}
          # {:bonfire_boundaries, git: "https://github.com/bonfire-networks/bonfire_boundaries#main", optional: true}
        ])
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application, do: [extra_applications: [:logger]]
end
