defmodule Bonfire.UI.Common.LinkPatchLive do
  @moduledoc """
  Defines an element that will trigger an internal navigation event (eg. switching tabs) and/or render a **link**
  (TODO add route validation from Phoenix 1.7)
  """

  use Bonfire.UI.Common.Web, :stateless_component

  @doc "The required path or URL to link to"
  prop to, :string, required: false

  @doc "The flag to replace the current history or push a new state (if linking to a LiveView)"
  prop replace, :boolean, default: false

  @doc "The CSS class for the generated `<a>` element"
  prop class, :css_class, default: ""

  @doc """
  The label for the generated `<a>` element, if no content (default slot) is provided.
  """
  prop label, :string

  @doc "What JS hook to attach to the link, if any (possibly overriding the default action of the link)"
  prop phx_hook, :string, default: nil
  prop id, :string, default: nil

  @doc "What LiveHandler and/or event name to send the patch event to, if any (possibly overriding the default action of the link)"
  prop event_handler, :string, default: nil

  @doc "What element (and it's parent view or stateful component) to send the event to"
  prop event_target, :string, default: nil

  @doc "What state (eg. tab) to switch to"
  prop name, :string, default: nil

  @doc """
  Additional attributes to add onto the generated element
  """
  prop opts, :keyword, default: []

  @doc """
  The content of the generated `<a>` element. If no content is provided,
  the value of property `label` is used instead.
  """
  slot default

  def render(%{to: "http" <> _} = assigns) do
    ~F"""
    <Link to={@to} class={@class} opts={@opts |> Enum.into(%{"aria-label": @label})}>
      <#slot>{@label}</#slot>
    </Link>
    """
  end

  # def render(%{__context__: %{current_app: :bonfire_pages}} = assigns) do
  #   # TODO: this should only apply to links to Page views, not internal pages
  #   ~F"""
  #   <Link to={@to} class={@class} opts={@opts}>
  #     <#slot>{@label}</#slot>
  #   </Link>
  #   """
  # end

  def render(%{event_handler: event_handler, phx_hook: phx_hook} = assigns)
      when is_binary(event_handler) or is_binary(phx_hook) do
    # TODO: How can I have a phx-click on an anchor without the browser also triggering the default navigation?
    # <a href={@to}
    if socket_connected?(assigns) do
      ~F"""
      <span
        data-to={@to}
        phx-value-to={@to}
        phx-click={@event_handler}
        phx-hook={@phx_hook}
        id={if @phx_hook, do: @id || random_dom_id()}
        phx-target={@event_target}
        phx-value-name={@name}
        class={@class}
        opts={@opts}
        aria-label={@label}
      >
        {!-- FIXME: do not generate random ID to avoid re-rendering --}
        <#slot>{@label}</#slot>
      </span>
      """
    else
      # fallback to only using a link when LiveView is not available
      render(Map.drop(assigns, [:event_handler]))
    end
  end

  def render(assigns) do
    ~F"""
    <Phoenix.Component.link
      patch={@to}
      class={@class}
      replace={@replace}
      phx-hook="Bonfire.UI.Common.PreviewContentLive#CloseAll"
      id={@id || random_dom_id()}
      {...@opts |> Keyword.merge("aria-label": @label)}
    >
      <#slot>{@label}</#slot>
    </Phoenix.Component.link>
    """
  end
end
