Code.eval_file("mess.exs", (if File.exists?("../../lib/mix/mess.exs"), do: "../../lib/mix/"))

defmodule Bonfire.UI.Common.MixProject do
  use Mix.Project

  def project do
    if System.get_env("AS_UMBRELLA") == "1" do
      [
        build_path: "../../_build",
        config_path: "../../config/config.exs",
        deps_path: "../../deps",
        lockfile: "../../mix.lock"
      ]
    else
      []
    end
    ++
    [
      app: :bonfire_ui_common,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      compilers: Mix.compilers() ++ [:surface],
      deps:
        Mess.deps([
          {:phoenix_live_reload, "~> 1.2", only: :dev},
          {:floki, "~> 0.36", only: :test},
          {:zest, "~> 0.1", optional: true},
          {:phoenix_test, "~> 0.2.2", only: :test, runtime: false},
          # {:pages, "~> 0.12", only: :test} # extends Floki for testing 
          # {:bonfire_search, "https://github.com/bonfire-networks/bonfire_search#main", optional: true, runtime: false}
          # {:bonfire_boundaries, git: "https://github.com/bonfire-networks/bonfire_boundaries#main", optional: true, runtime: false}
        ] ++ if(System.get_env("NATIVE_ENABLED") in ["1", "true"], do: [
          {:live_view_native, "~> 0.2.0"},
          {:live_view_native_swiftui, "~> 0.2.0"}
          ], else: [])
        )
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application, do: [extra_applications: [:logger]]
end
