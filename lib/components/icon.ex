defmodule Icon do
  use Surface.Component

  prop iconify, :string, required: true # any icon from iconify: https://icones.js.org
  prop solid, :string, required: true # shorthand for heroicons
  prop outline, :string, required: true # shorthand for heroicons

  prop class, :css_class, default: "w-auto h-auto"

  def render(%{iconify: icon} = assigns) when is_binary(icon) do
    component(&Iconify.iconify/1, prepare_assigns(assigns, icon))
  end

  def render(%{solid: icon} = assigns) when is_binary(icon) do
    component(&Iconify.iconify/1, prepare_assigns(assigns, "heroicons-solid:"<>icon))
  end

  def render(%{outline: icon} = assigns) when is_binary(icon) do
    component(&Iconify.iconify/1, prepare_assigns(assigns, "heroicons-outline:"<>icon))
  end

  defp prepare_assigns(assigns, icon) do
    assigns
    |> assign(
      icon: icon,
      class: Surface.css_class(Map.get(assigns, :class))
    )
  end

end
