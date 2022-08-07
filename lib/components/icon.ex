defmodule Icon do
  use Surface.Component

  prop iconify, :string, required: false # any icon from iconify: https://icones.js.org
  prop solid, :string, required: false # shorthand for heroicons
  prop outline, :string, required: false # shorthand for heroicons

  prop class, :css_class, default: "w-4 h-4"

  def render(%{iconify: icon} = assigns) when is_binary(icon) or is_atom(icon) and not is_nil(icon) do
    component(&Iconify.iconify/1, prepare_assigns(assigns, icon))
  end

  def render(%{solid: icon} = assigns) when is_binary(icon) or is_atom(icon) and not is_nil(icon) do
    component(&Iconify.iconify/1, prepare_assigns(assigns, "heroicons-solid:"<>icon))
  end

  def render(%{outline: icon} = assigns) when is_binary(icon) or is_atom(icon) and not is_nil(icon) do
    component(&Iconify.iconify/1, prepare_assigns(assigns, "heroicons-outline:"<>icon))
  end

  defp prepare_assigns(assigns, icon) do
    assigns
    |> assign(
      icon: icon,
      class: class_to_string(Map.get(assigns, :class))
    )
  end

  def class_to_string(class) when is_binary(class) do
    class
  end
  def class_to_string(class) do
    Surface.css_class(class)
  end

end
