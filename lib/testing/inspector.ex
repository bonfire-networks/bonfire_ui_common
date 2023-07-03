defmodule Bonfire.UI.Common.Testing.Inspector do
  defmacro pry(opts \\ []) do
    # We're in dev mode; we might get to add some attributes
    quote do
      # Let's see if we want to actually activate Source Inspector or not
      if Application.get_env(:source_inspector, :enabled, false) do
        # The config option is set, so we return a number of attributes
        if Keyword.get(unquote(opts), :random_id, true) == true do
          %{id: Bonfire.Common.Text.random_string()}
        else
          %{}
        end
        |> Map.merge(%{
          "data-source-inspector": "true",
          "data-source-inspector-file": unquote(__CALLER__.file),
          "data-source-inspector-line": unquote(__CALLER__.line),
          title: SourceInspector.debuggable_element_title(),
          "phx-hook": "SourceInspect"
        })
      else
        # The config option is not set, so we return an empty map
        %{}
      end
    end
  end
end
