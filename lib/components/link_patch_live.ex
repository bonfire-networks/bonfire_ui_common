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

  @doc "What LiveHandler and/or event name to send the patch event to"
  prop event_handler, :string, required: false

  @doc "What element (and it's parent view or stateful component) to send the event to"
  prop event_target, :string, default: nil

  @doc "What state (eg. tab) to switch to"
  prop name, :string, required: false

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
    <Link to={@to} class={@class} opts={@opts}>
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

  def render(%{event_handler: event_handler, to: to, name: name} = assigns)
      when is_binary(event_handler) and is_binary(to) and is_binary(name) do
    # TODO: How can I have a phx-click on an anchor without the browser also triggering the default navigation?
    # <a href={@to}
    ~F"""
    <span
      href={@to}
      phx-click={event_handler}
      phx-value-name={name}
      phx-value-to={to}
      phx-target={@event_target}
      class={@class}
      opts={@opts}
    >
      <#slot>{@label}</#slot>
    </span>
    """
  end

  def render(%{event_handler: event_handler, name: name} = assigns)
      when is_binary(event_handler) and is_binary(name) do
    ~F"""
    <a
      href="#%{name}"
      phx-click={event_handler}
      phx-value-name={name}
      phx-target={@event_target}
      class={@class}
      opts={@opts}
    >
      <#slot>{@label}</#slot>
    </a>
    """
  end

  def render(assigns) do
    ~F"""
    <LivePatch to={@to} class={@class} replace={@replace} opts={@opts}>
      <#slot>{@label}</#slot>
    </LivePatch>
    """
  end
end
