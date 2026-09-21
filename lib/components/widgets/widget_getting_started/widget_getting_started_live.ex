defmodule Bonfire.UI.Common.WidgetGettingStartedLive do
  @moduledoc """
  Sidebar widget that walks somebody new through a few starter actions.

  It declares no steps of its own. Each step is declared by the extension whose feature it is about, in that extension's own config, under one key:

      config :bonfire_ui_common, Bonfire.UI.Common.WidgetGettingStartedLive,
        actions_registry: [
          profile: %{title: l("Add a profile picture and bio"), done?: &…/1, needs: Bonfire.Me.Users}
        ]

  A **keyword list** because config of that shape merges: every extension adds its own entries and none replaces another's, which is what lets a step live with the code it is about. Copy stays inside those config files' own extension, where `l/1` is compiled and `mix gettext.extract` can see it, and a completion detector stays a function capture pointing at that extension.

  Each step names what it `needs`, and a step whose extension is disabled here is dropped, so an instance without a feature never asks anyone to go and use it. Which steps to show, and in what order, is separate (`:actions`), since that is a flavour's choice rather than an extension's.

  Completion is auto-detected by each step's optional `:done?`, and can also be marked by hand. Both the manual marks and the dismissal live in per-user settings under `[:ui, :getting_started, …]`, so they follow somebody across browsers and devices.
  """
  use Bonfire.UI.Common.Web, :stateful_component

  alias Bonfire.Common.Config
  alias Bonfire.Common.Settings

  @settings_path [:ui, :getting_started]

  data dismissed?, :boolean, default: false
  data celebrating?, :boolean, default: false
  data steps, :list, default: []
  data current, :any, default: nil
  data viewing_index, :integer, default: 0
  data done_count, :integer, default: 0
  data total_count, :integer, default: 0
  data manual_done, :list, default: []

  @doc """
  Every step any enabled extension has declared, keyed by its name.

  Merged from config rather than listed here, so a step lives with the feature it is about. A step whose extension is disabled is not offered: with no such feature on this instance, asking somebody to go and use it would be a dead end.
  """
  def actions_registry(context \\ nil) do
    declared_actions()
    |> Enum.filter(fn {_key, spec} -> available?(spec, context) end)
    |> Map.new()
  end

  # every step declared, on offer or not, which is what `configured_actions/1` needs in order to tell a step that is switched off from one nobody declared: only the first has a fallback worth using
  defp declared_actions do
    Config.get([__MODULE__, :actions_registry], [],
      name: l("Getting-started steps"),
      description: l("Every step this instance could offer someone who joins.")
    )
    |> Enum.map(fn {key, spec} -> {key, resolve_path(spec)} end)
    |> Map.new()
  end

  # `cta_path: {:config, key}` for a step whose destination only an instance knows, such as a form to collect what people want, and `{:config, key, default}` where an extension has a page of its own but a flavour may keep its answer elsewhere. Named rather than read where the step is declared, because a declaration IS config and cannot read config that has not finished loading; this resolves while rendering, by which time a flavour's value is in place
  defp resolve_path(%{cta_path: {:config, key}} = spec) do
    %{spec | cta_path: Config.get([__MODULE__, key], nil)}
  end

  defp resolve_path(%{cta_path: {:config, key, default}} = spec) do
    %{spec | cta_path: Config.get([__MODULE__, key], default)}
  end

  defp resolve_path(spec), do: spec

  # two ways a step can turn out not to be on offer: what it needs is not here, or it is a link with nowhere to go, which is what an instance leaving its destination unset means
  defp available?(spec, context) do
    feature_enabled?(e(spec, :needs, nil), context) and has_destination?(spec)
  end

  defp feature_enabled?(nil, _context), do: true

  # `needs` is usually a module, and is a function where having the feature is not the same as having anything to show with it: an instance can run the community rules extension and have written no rules
  defp feature_enabled?(check, _context) when is_function(check, 0), do: !!check.()
  defp feature_enabled?(check, context) when is_function(check, 1), do: !!check.(context)

  defp feature_enabled?(module, context), do: module_enabled?(module, context)

  defp has_destination?(spec) do
    e(spec, :cta_kind, :link) != :link or not is_nil(e(spec, :cta_path, nil))
  end

  @doc """
  The steps this instance shows, in the order it lists them.

  Every step it names is looked up among the declared ones, and one nobody declared is passed over. A step that is declared but has nothing to offer here can name a `fallback:` step to stand in, which is used only when the instance is not already showing that one: rules an instance never wrote fall back to its code of conduct, and a flavour that lists both gets them as themselves.
  """
  def configured_actions(context \\ nil) do
    declared = declared_actions()

    listed =
      Config.get([__MODULE__, :actions], Map.keys(declared), :bonfire_ui_common)
      |> List.wrap()
      |> Enum.filter(&is_atom/1)

    Enum.flat_map(listed, &resolve_action(&1, declared, listed, context))
  end

  defp resolve_action(key, declared, listed, context, seen \\ []) do
    case Map.fetch(declared, key) do
      {:ok, spec} ->
        cond do
          available?(spec, context) ->
            [Map.put(spec, :key, key)]

          (fallback = e(spec, :fallback, nil)) && fallback not in listed && fallback not in seen ->
            resolve_action(fallback, declared, listed, context, [key | seen])

          true ->
            []
        end

      :error ->
        []
    end
  end

  def update(assigns, socket) do
    socket = assign(socket, assigns)
    {dismissed?, manual} = load_state(current_user(socket))

    # the per-step detectors read from the database, so they are skipped where the widget would render hidden anyway
    if dismissed? do
      {:ok, assign(socket, dismissed?: true, manual_done: manual)}
    else
      {:ok, recompute(socket, dismissed?, manual)}
    end
  end

  def handle_event("mark_done", %{"key" => key}, socket) do
    user = current_user(socket)

    manual =
      (List.wrap(socket.assigns.manual_done) ++ [to_string(key)])
      |> Enum.uniq()

    _ = Settings.put(@settings_path ++ [:manual_done], manual, current_user: user)

    {:noreply, recompute(socket, socket.assigns.dismissed?, manual)}
  end

  def handle_event("dismiss", _params, socket) do
    _ = Settings.put(@settings_path ++ [:dismissed], true, current_user: current_user(socket))
    {:noreply, assign(socket, dismissed?: true, celebrating?: false)}
  end

  def handle_event("prev", _params, socket) do
    total = socket.assigns.total_count
    next_index = rem(socket.assigns.viewing_index - 1 + total, max(total, 1))
    {:noreply, assign(socket, viewing_index: next_index)}
  end

  def handle_event("next", _params, socket) do
    total = socket.assigns.total_count
    next_index = rem(socket.assigns.viewing_index + 1, max(total, 1))
    {:noreply, assign(socket, viewing_index: next_index)}
  end

  @doc false
  def load_state(nil), do: {true, []}

  def load_state(user) do
    dismissed? = !!Settings.get(@settings_path ++ [:dismissed], false, current_user: user)

    manual =
      Settings.get(@settings_path ++ [:manual_done], [], current_user: user)
      |> List.wrap()
      |> Enum.map(&to_string/1)

    {dismissed?, manual}
  end

  defp recompute(socket, dismissed?, manual_done) do
    user = current_user(socket)

    steps =
      Enum.map(configured_actions(socket), fn spec ->
        manual? = to_string(spec.key) in manual_done
        Map.put(spec, :done?, manual? || run_done(spec, user))
      end)

    # newly auto-detected completions are stored, so later renders short-circuit on the manual check above and skip the per-step read. One write per transition, none once somebody is finished
    manual_done = persist_newly_done(steps, manual_done, user)

    total = length(steps)
    done_count = Enum.count(steps, & &1.done?)
    current = Enum.find(steps, &(!&1.done?))
    all_done? = total > 0 and is_nil(current)

    # celebrate only where this process saw the change from "work left" to "all done", so somebody who was already finished stays hidden
    fresh_completion? = all_done? and not is_nil(socket.assigns[:current])

    viewing_index = Enum.find_index(steps, &(!&1.done?)) || 0

    socket
    |> assign(
      manual_done: manual_done,
      dismissed?: dismissed?,
      steps: steps,
      current: current,
      viewing_index: viewing_index,
      done_count: done_count,
      total_count: total,
      celebrating?: socket.assigns[:celebrating?] || fresh_completion?
    )
  end

  # a detector reads the database and belongs to another extension, so a raise in one must not take the widget with it: the step simply reads as not done
  defp run_done(%{done?: fun}, user) when is_function(fun, 1) do
    try do
      !!fun.(user)
    rescue
      error ->
        error(error, "A getting-started step's completion detector failed")
        false
    end
  end

  defp run_done(_, _), do: false

  defp persist_newly_done(_steps, manual_done, nil), do: manual_done

  defp persist_newly_done(steps, manual_done, user) do
    newly_done =
      for step <- steps,
          step.done?,
          key = to_string(step.key),
          key not in manual_done,
          do: key

    case newly_done do
      [] ->
        manual_done

      _ ->
        updated = manual_done ++ newly_done
        _ = Settings.put(@settings_path ++ [:manual_done], updated, current_user: user)
        updated
    end
  end

  @doc """
  Drives the template's top-level case.

  - `:hidden` renders nothing: dismissed, no steps to show, or everything was already done before this process started.
  - `:celebrate` is the last beat, for somebody who finishes while looking at it.
  - `:step` is the normal one-at-a-time view.
  """
  def render_state(%{dismissed?: true}), do: :hidden
  def render_state(%{total_count: 0}), do: :hidden
  def render_state(%{celebrating?: true}), do: :celebrate
  def render_state(%{current: nil}), do: :hidden
  def render_state(_), do: :step

  @doc "The step currently in view, which starts at the first one not done."
  def viewing_step(%{steps: steps, viewing_index: idx}) when is_list(steps) and steps != [] do
    Enum.at(steps, idx) || List.first(steps)
  end

  def viewing_step(_), do: nil
end
