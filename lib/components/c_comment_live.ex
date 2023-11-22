defmodule Bonfire.UI.Common.C do
  @moduledoc """
  Defines a `<C>comment</C>` component that will conditionally output comments depending on the app's loglevel.
  """

  use Bonfire.UI.Common.Web, :stateless_component

  @doc "Data to output in the comment"
  prop d, :any, default: nil

  @doc "Log level at which to output the comment"
  prop l, :atom, default: :debug

  @doc "Content to output in the comment"
  slot default

  def render(assigns) do
    debug(assigns, "HTML comment")

    ~F"""
    {#if Untangle.log_level?(@l)}
      {raw("<!--")}
      {case @d do
        nil -> nil
        _ when is_binary(@d) -> @d
        _ -> inspect(@d)
      end}
      <#slot />
      {raw("-->")}
    {/if}
    """
  end
end
