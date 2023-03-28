defmodule Bonfire.UI.Common.LinkLive do
  @moduledoc """
  Defines a link that will **link** to a `Page` or external URL, or **redirect** to a new LiveView.
  If you want to navigate to the same LiveView without remounting it, use `<LivePatch>` instead.
  """

  use Bonfire.UI.Common.Web, :stateless_component

  @doc "The required path or URL to link to"
  prop to, :string, required: true

  @doc "The flag to replace the current history or push a new state (if linking to a LiveView)"
  prop replace, :boolean, default: false

  @doc "The CSS class for the generated `<a>` element"
  prop class, :css_class, default: ""

  @doc """
  The label for the generated `<a>` element, if no content (default slot) is provided.
  """
  prop label, :string

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

  def render(%{to: "#" <> _} = assigns) do
    ~F"""
    <Link to={@to} class={@class} opts={@opts}>
      <#slot>{@label}</#slot>
    </Link>
    """
  end

  def render(%{__context__: %{current_app: :bonfire_pages}} = assigns) do
    # TODO: this should only apply to links to Page views, not internal pages
    ~F"""
    <Link to={@to} class={@class} opts={@opts}>
      <#slot>{@label}</#slot>
    </Link>
    """
  end

  def render(%{to: to} = assigns) when is_binary(to) and to != "" do
    ~F"""
    <LiveRedirect to={@to} class={@class} replace={@replace} opts={@opts}>
      <#slot>{@label}</#slot>
    </LiveRedirect>
    """
  end

  def render(assigns) do
    ~F"""
    <Field name="none_link" class={@class} opts={@opts}>
      <#slot>{@label}</#slot>
    </Field>
    """
  end
end
