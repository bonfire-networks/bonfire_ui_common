defmodule Bonfire.UI.Common.WidgetFeedbackLive do
  @moduledoc """
  Asks people what they want of the place: a link to a form the instance names, or, with no form, the composer opened into a group or topic the instance picks, with some text to start from.

  Its words, link, group and starting text are instance settings (`[WidgetFeedbackLive, :title | :text | :cta_label | :url | :context_id | :template]`). The getting-started checklist's wishes step reads the same ones through `getting_started_step/1`, so an instance sets them once.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.Common.Config

  declare_widget("Feedback", id: :wishes)

  def title, do: text_setting(:title) || l("Feedback")

  def text,
    do:
      text_setting(:text) || l("Help shape what comes next: what you say drives what gets built.")

  def cta_label, do: text_setting(:cta_label) || l("Share your wishes")

  @doc """
  Where the button goes: `{:link, url}` to the instance's form, else `{:composer, opts}` to post into its group or topic, else `nil` when the instance is asking nothing.

  The form is this widget's `:url` setting, else the `wishes_url` a flavour gives the getting-started checklist, which is where it was set before this widget had settings of its own.
  """
  def cta do
    cond do
      url =
          text_setting(:url) ||
            text_only(Config.get([Bonfire.UI.Common.WidgetGettingStartedLive, :wishes_url], nil)) ->
        {:link, url}

      # an id, so nothing else a settings form may have saved there (eg. its empty choice, which `Settings.set/2` can turn into a module) reads as a group
      context_id = text_setting(:context_id) ->
        {:composer, %{context_id: context_id, text: text_setting(:template) || ""}}

      true ->
        nil
    end
  end

  @doc "The getting-started checklist's wishes step, with its words wherever the instance has set some (otherwise it keeps the copy it was declared with), and this widget's own button (`Bonfire.UI.Common.FeedbackCtaLive`), so both go to the same place the same way."
  def getting_started_step(spec) do
    spec =
      spec
      |> put_if_set(:title, text_setting(:title))
      |> put_if_set(:rationale, text_setting(:text))
      |> put_if_set(:cta_label, text_setting(:cta_label))

    case cta() do
      # a link with nowhere to go, which the checklist drops
      nil ->
        Map.put(spec, :cta_path, nil)

      _ ->
        Map.merge(spec, %{
          cta_kind: :stateless_component,
          cta_component: Bonfire.UI.Common.FeedbackCtaLive
        })
    end
  end

  @doc "What to render for a viewer: nothing when the instance asks nothing, or when the composer is the way to answer and a guest has none."
  def cta_for(context) do
    case cta() do
      {:composer, _} = cta -> if current_user_id(context), do: cta
      cta -> cta
    end
  end

  @doc "Puts the instance's starting text in the composer, which the button has just opened in the instance's group or topic. Its own event because the composer drops any text pushed with the opts that open it."
  def handle_event("fill_composer", _params, socket) do
    case cta() do
      {:composer, %{text: text}} when text != "" ->
        Bonfire.UI.Common.SmartInput.LiveHandler.set_smart_input_text(socket, text)

      _ ->
        nil
    end

    {:noreply, socket}
  end

  @doc "The groups and topics an admin can pick for people to post their feedback in, as `{id, name}` options for a settings select, with a first option for none. One query each for groups and topics, on the settings page only."
  def context_options(context) do
    choices =
      for type <- [:group, :topic],
          category <-
            Utils.maybe_apply(
              Bonfire.Classify.Categories,
              :list,
              [[:default, type: type], [current_user: current_user(context), limit: 100]],
              fallback_return: []
            )
            |> then(&(e(&1, :edges, nil) || &1))
            |> List.wrap() do
        {id(category),
         e(category, :profile, :name, nil) || e(category, :character, :username, nil) ||
           id(category)}
      end

    [{"", l("None")} | choices]
  end

  # every setting here is text: a blank one, or anything else a settings form may have saved, reads as unset
  defp text_setting(key), do: text_only(Config.get([__MODULE__, key], nil))

  defp text_only(value) when is_binary(value) and value != "", do: value
  defp text_only(_), do: nil

  defp put_if_set(map, _key, nil), do: map
  defp put_if_set(map, key, value), do: Map.put(map, key, value)
end
