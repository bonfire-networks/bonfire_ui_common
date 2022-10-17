defmodule Bonfire.UI.Common.Icon do
  use Surface.Component
  import Phoenix.LiveView.HTMLEngine

  # any icon from iconify: https://icones.js.org
  prop iconify, :string, required: false
  # shorthand for heroicons
  prop solid, :string, required: false
  # shorthand for heroicons
  prop outline, :string, required: false

  prop class, :css_class, default: "w-4 h-4"

  def render(%{solid: icon} = assigns)
      when is_binary(icon) or (is_atom(icon) and not is_nil(icon)) do
    component(
      &Iconify.iconify/1,
      prepare_assigns(assigns, "heroicons-solid:" <> icon),
      {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
    )
  end

  def render(%{outline: icon} = assigns)
      when is_binary(icon) or (is_atom(icon) and not is_nil(icon)) do
    component(
      &Iconify.iconify/1,
      prepare_assigns(assigns, "heroicons-outline:" <> icon),
      {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
    )
  end

  def render(%{iconify: icon} = assigns) do
    component(
      &Iconify.iconify/1,
      prepare_assigns(assigns, icon),
      {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
    )
  end

  defp prepare_assigns(assigns, icon) do
    assign(
      assigns,
      icon: icon,
      class: class_to_string(Map.get(assigns, :class)),
      # never need context in icons
      __context__: nil
    )
  end

  def class_to_string(class) when is_binary(class) do
    class
  end

  def class_to_string(class) do
    Surface.css_class(class)
  end
end
