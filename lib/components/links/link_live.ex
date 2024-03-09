defmodule Bonfire.UI.Common.LinkLive do
  @moduledoc """
  Defines a link that will **link** to a `Page` or external URL, or **redirect** to a new LiveView.
  If you want to navigate to the same LiveView without remounting it, use `<LinkPatchLive>` instead.
  """

  use Bonfire.UI.Common.Web, :stateless_component

  @doc "The required path or URL to link to"
  prop to, :string, required: true

  @doc "The flag to replace the current history or push a new state (if linking to a LiveView)"
  prop replace, :boolean, default: false

  @doc "The CSS class for the generated `<a>` element"
  prop class, :css_class, default: ""

  @doc """
  The label for the generated `<a>` element, used for aria-label, and as the link text if no other content is provided (as a default slot).
  """
  prop label, :string

  @doc "What JS hook to attach to the link, if any (possibly overriding the default action of the link)"
  prop phx_hook, :string, default: nil
  prop id, :string, default: nil

  @doc "What LiveHandler and/or event name to send the patch event to, if any (possibly overriding the default action of the link)"
  prop event_handler, :string, default: nil

  @doc "What element (and it's parent view or stateful component) to send the event to"
  prop event_target, :string, default: nil

  @doc "What browser window/frame to target, eg. `_blank`"
  prop target, :string, default: nil

  @doc """
  Additional attributes to add onto the generated element
  """
  prop opts, :keyword, default: []

  @doc """
  The content of the generated `<a>` element. If no content is provided,
  the value of property `label` is used instead.
  """
  slot default

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
        id={if @phx_hook, do: @id || Text.random_string()}
        phx-target={@event_target}
        class={@class}
        opts={@opts}
        aria-label={@label}
      >
        <#slot>{@label}</#slot>
      </span>
      """
    else
      # fallback to only using a link when LiveView is not available
      render(Map.drop(assigns, [:event_handler]))
    end
  end

  def render(%{to: "http" <> _} = assigns) do
    ~F"""
    <Link
      to={@to}
      class={@class}
      opts={@opts |> Keyword.merge("aria-label": @label, target: @target)}
    >
      <#slot>{@label}</#slot>
    </Link>
    """
  end

  def render(%{to: "#" <> _} = assigns) do
    ~F"""
    <Link
      to={@to}
      class={@class}
      opts={@opts |> Keyword.merge("aria-label": @label, target: @target)}
    >
      <#slot>{@label}</#slot>
    </Link>
    """
  end

  def render(%{__context__: %{current_app: :bonfire_pages}} = assigns) do
    # TODO: this should only apply to links to Page views, not internal pages
    ~F"""
    <Link
      to={@to}
      class={@class}
      opts={@opts |> Keyword.merge("aria-label": @label, target: @target)}
    >
      <#slot>{@label}</#slot>
    </Link>
    """
  end

  def render(%{to: to} = assigns) when is_binary(to) and to != "" do
    ~F"""
    <.link
      navigate={@to}
      class={@class}
      replace={@replace}
      {...@opts |> Keyword.merge("aria-label": @label)}
    >
      <#slot>{@label}</#slot>
    </.link>
    """
  end

  def render(assigns) do
    ~F"""
    <div data-name="no_link" class={@class} {...@opts |> Keyword.merge("aria-label": @label)}>
      <#slot>{@label}</#slot>
    </div>
    """
  end
end
