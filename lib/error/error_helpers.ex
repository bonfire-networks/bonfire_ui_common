defmodule Bonfire.UI.Common.ErrorHelpers do
  @moduledoc """
  Conveniences for translating and building error messages.
  """

  import Phoenix.HTML
  import Phoenix.HTML.Form
  use PhoenixHTMLHelpers

  @doc """
  Generates tag for inlined form input errors.
  # TODO: use `Surface.Components.Form.ErrorTag` instead?
  """
  def error_tag(form, field) do
    # debug(errors: form.errors)
    Keyword.get_values(form.errors, field)
    |> Enum.reduce({[], MapSet.new()}, fn error, {errors, seen} ->
      if MapSet.member?(seen, error) do
        {errors, seen}
      else
        tag =
          content_tag(:span, translate_error(error),
            class: "invalid-feedback",
            phx_feedback_for: input_id(form, field)
          )

        {[tag | errors], MapSet.put(seen, error)}
      end
    end)
    |> elem(0)
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate "is invalid" in the "errors" domain
    #     dgettext("errors", "is invalid")
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # Because the error messages we show in our forms and APIs
    # are defined inside Ecto, we need to translate them dynamically.
    # This requires us to call the Gettext module passing our gettext
    # backend as first argument.
    #
    # Note we use the "errors" domain, which means translations
    # should be written to the errors.po file. The :count option is
    # set by Ecto and indicates we should also apply plural rules.
    if count = opts[:count] do
      Gettext.dngettext(
        Bonfire.Common.Localise.Gettext,
        "errors",
        msg,
        msg,
        count,
        opts
      )
    else
      Gettext.dgettext(Bonfire.Common.Localise.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
