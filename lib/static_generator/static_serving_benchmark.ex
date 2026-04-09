defmodule Bonfire.UI.Common.StaticServingBenchmark do
  @moduledoc """
  Benchmark comparing cache backends for serving static HTML pages through `MaybeStaticGeneratorPlug`.

  Backends measured:
  - **Cachex** (default Bonfire cache)
  - **Nebulex Local** — `Nebulex.Adapters.Local` (ETS)
  - **Nebulex Coherent** — local + cluster invalidations
  - **DiskLFU** — disk-only with LFU eviction
  - **Disk only** — `Plug.Static` serving pre-generated files, no memory cache
  - **No cache** — plug bypassed via non-empty query string

  Scenarios per backend:
  - `cache put` — store `{content_type, html}` in the memory cache
  - `cache get hit` — serve from memory cache (fastest path)
  - `cache miss (disk)` — memory cache miss, falls through to `Plug.Static`
  - `no cache` — `query_string` non-empty, plug bypasses all caching

  Run from IEx:

      Bonfire.UI.Common.StaticServingBenchmark.run()

  Results written to `static_serving_benchmark_results.html`.
  """

  alias Bonfire.Common.Cache.BenchmarkHelpers
  alias Bonfire.Common.Cache.NebulexLocalCache
  alias Bonfire.Common.Cache.NebulexCoherentCache
  alias Bonfire.Common.Cache.DiskLFUCache
  alias Bonfire.Common.Cache.SimpleDiskCache
  alias Bonfire.UI.Common.MaybeStaticGeneratorPlug
  alias Bonfire.UI.Common.StaticGenerator

  @plug_module MaybeStaticGeneratorPlug
  # Backends benchmarked as sole cache_backend (ETS + disk-only via send_file)
  @cache_backends [Cachex, NebulexLocalCache, NebulexCoherentCache, SimpleDiskCache, DiskLFUCache]

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  def run do
    Logger.configure(level: :error)
    :persistent_term.put(:bench_results, %{})

    tmp = System.tmp_dir!()
    lfu_path = Path.join(tmp, "bonfire_static_bench_lfu_#{:os.getpid()}")
    File.mkdir_p!(lfu_path)

    tables_before = :ets.all() |> MapSet.new()

    {:ok, local_pid} = NebulexLocalCache.start_link([])
    {:ok, coherent_pid} = NebulexCoherentCache.start_link([])
    {:ok, lfu_pid} = DiskLFUCache.start_link(root_path: lfu_path, max_bytes: nil)

    BenchmarkHelpers.init_cache_tables(tables_before)

    inputs = build_inputs()

    Benchee.run(
      BenchmarkHelpers.wrap_scenarios(the_scenarios()),
      inputs: inputs,
      time: 5,
      warmup: 2,
      memory_time: 2,
      before_scenario: fn {url, _disk_path, _conn, _no_cache_conn} = input ->
        label = if url == "/", do: "homepage", else: String.trim_leading(url, "/")
        BenchmarkHelpers.flush_all()
        BenchmarkHelpers.snapshot_mem(label)
        input
      end,
      after_scenario: fn _input ->
        BenchmarkHelpers.after_scenario()
      end,
      before_each: fn input ->
        :erlang.garbage_collect()
        input
      end,
      print: [fast_warning: false],
      formatters: [
        Benchee.Formatters.Console,
        BenchmarkHelpers,
        {Benchee.Formatters.HTML,
         file: "static_serving_benchmark_results.html", auto_open: true}
      ]
    )

    # disk_paths = inputs |> Map.values() |> Enum.map(fn {_url, disk_path} -> Path.dirname(disk_path) end)

    BenchmarkHelpers.cleanup([local_pid, coherent_pid, lfu_pid], [lfu_path])
  end

  # ---------------------------------------------------------------------------
  # Scenarios
  # ---------------------------------------------------------------------------

  defp the_scenarios do
    cache_backend_scenarios =
      Enum.flat_map(@cache_backends, fn backend ->
        label =
          backend
          |> Module.split()
          |> List.last()
          |> Macro.underscore()
          |> String.replace("_cache", "")

        disk_only? = backend in [SimpleDiskCache, DiskLFUCache]

        if disk_only? do
          [
            # Disk-only backend as sole cache_backend — served via send_file using return: :path.
            {"#{label}: disk serve (send_file)",
             {fn {url, _, conn, _} ->
                StaticGenerator.call_plug(conn)
              end,
              before_scenario: fn {url, _, conn, _} = input ->
                configure_cache_backend(backend)
                warm_disk_backend(backend, url)
                input
              end,
              before_each: fn input ->
                :erlang.garbage_collect()
                input
              end}}
          ]
        else
          [
            # ETS memory cache hit — warmed in before_scenario, measures pure memory serve.
            {"#{label}: memory cache hit",
             {fn {url, _, _, _} ->
                StaticGenerator.get_cached!(url)
              end,
              before_scenario: fn {url, _, conn, _} = input ->
                configure_cache_backend(backend)
                warm_caches(conn, url)
                input
              end}},

            # Disk + promote — flush before each iteration, measure first request: Plug.Static serve + write to memory cache.
            {"#{label}: read from disk cache + promote to memory cache",
             {fn {url, _, conn, _} ->
                StaticGenerator.call_plug(conn)
              end,
              before_scenario: fn {url, _, conn, _} = input ->
                configure_cache_backend(backend)
                warm_caches(conn, url, warm_memory: false)
                input
              end,
              before_each: fn input ->
                BenchmarkHelpers.flush_all()
                input
              end}}
          ]
        end
      end)
      |> Map.new()

    disk_tier_scenarios = %{
      # DiskLFU as disk_cache_backend with Cachex as ETS memory tier.
      # Measures first-request path: ETS miss → DiskLFU symlink → send_file + promote to Cachex.
      "DiskLFU: disk tier + promote to ETS" =>
        {fn {url, _, conn, _} ->
           StaticGenerator.call_plug(conn)
         end,
         before_scenario: fn {url, _, conn, _} = input ->
           configure_disk_tier(DiskLFUCache, ets_backend: Cachex)
           warm_disk_backend(DiskLFUCache, url)
           input
         end,
         before_each: fn input ->
           BenchmarkHelpers.flush_all()
           input
         end},

      # DiskLFU as disk_cache_backend, ETS (Cachex) already warm after one disk request.
      "DiskLFU: ETS hit after disk tier promotion" =>
        {fn {url, _, _, _} ->
           StaticGenerator.get_cached!(url)
         end,
         before_scenario: fn {url, _, conn, _} = input ->
           configure_disk_tier(DiskLFUCache, ets_backend: Cachex)
           warm_disk_backend(DiskLFUCache, url)
           # one plug call to promote from DiskLFU → Cachex
           StaticGenerator.call_plug(conn)
           input
         end},

      # Plug.Static: baseline disk serve with no memory cache.
      "Plug.Static: disk serve" =>
        {fn {_, _, conn, _} ->
           StaticGenerator.call_plug(conn)
         end,
         before_scenario: fn {url, _, conn, _} = input ->
           configure_plug_static_only()
           warm_caches(conn, url, warm_memory: false)
           input
         end,
         before_each: fn input ->
           :erlang.garbage_collect()
           input
         end},

      # No cache — calls the Phoenix endpoint directly as a plug with cache=skip,
      # bypasses the static cache and measures actual Phoenix render time without ConnTest overhead.
      "no cache (bypass)" =>
        {fn {_, _, _, no_cache_conn} ->
           StaticGenerator.call_endpoint(no_cache_conn)
         end,
         before_scenario: fn input ->
           configure_plug_static_only()
           input
         end}
    }

    Map.merge(cache_backend_scenarios, disk_tier_scenarios)
  end

  # ---------------------------------------------------------------------------
  # Inputs — pre-write HTML files to disk so Plug.Static can serve them
  # ---------------------------------------------------------------------------

  defp build_inputs do
    urls = ["/", "/about"]
    StaticGenerator.generate(urls)

    Map.new(urls, fn url ->
      label = if url == "/", do: "homepage", else: String.trim_leading(url, "/")
      {label,
       {url, StaticGenerator.disk_path_for(url), StaticGenerator.build_bench_conn(url),
        StaticGenerator.build_bench_conn(url, %{"cache" => "skip"})}}
    end)
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Warm disk cache via ConnTest (renders and writes HTML to disk).
  # Then calls call_plug once to promote from disk to memory cache via the plug path.
  # Pass warm_memory: false to skip memory promotion (disk-only scenarios).
  defp warm_caches(conn, url, opts \\ []) do
    times = opts[:times] || 1
    for _ <- 1..times, do: StaticGenerator.get(conn, url, %{})
    unless opts[:warm_memory] == false, do: StaticGenerator.call_plug(conn)
  end

  # Configure backend as sole cache_backend (ETS or disk-only via send_file).
  defp configure_cache_backend(backend) do
    Application.put_env(:bonfire_ui_common, @plug_module,
      cache_backend: backend,
      memory_cache_threshold: 1,
      memory_cache_ttl: :timer.hours(1),
      memory_hits_ttl: :timer.hours(1)
    )
  end

  # Configure an ETS cache_backend + a dedicated disk_cache_backend tier.
  defp configure_disk_tier(disk_backend, opts \\ []) do
    ets_backend = opts[:ets_backend] || Cachex

    Application.put_env(:bonfire_ui_common, @plug_module,
      cache_backend: ets_backend,
      disk_cache_backend: disk_backend,
      memory_cache_threshold: 1,
      memory_cache_ttl: :timer.hours(1),
      memory_hits_ttl: :timer.hours(1)
    )
  end

  # No memory or disk cache — Plug.Static always serves.
  defp configure_plug_static_only do
    Application.put_env(:bonfire_ui_common, @plug_module, [])
  end

  # Warm a disk-only backend (SimpleDiskCache / DiskLFUCache) by writing the cached HTML via Cache.Backend.
  defp warm_disk_backend(backend, url) do
    root_path = StaticGenerator.dest_path()
    file_path = Path.join([root_path, String.trim_leading(url, "/"), "index.html"])

    case File.read(file_path) do
      {:ok, body} ->
        Bonfire.Common.Cache.Backend.put(
          backend,
          url,
          body,
          root_path: root_path,
          async: false
        )

      _ ->
        :ok
    end
  end

end
