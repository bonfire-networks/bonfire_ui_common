defmodule Bonfire.UI.Common.SmartInputLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Common.SmartInput.LiveHandler

  # prop user_image, :string, required: true
  # prop target_component, :string
  prop create_object_type, :any, default: nil
  prop reply_to_id, :any, default: nil
  prop context_id, :string, default: nil, required: false
  prop smart_input_component, :atom, default: nil
  prop to_boundaries, :any, default: nil
  prop to_circles, :list, default: []
  prop exclude_circles, :list, default: []
  prop mentions, :list, default: []
  prop open_boundaries, :boolean, default: false
  prop smart_input_opts, :map, default: %{}
  prop showing_within, :atom, default: :smart_input
  prop activity, :any, default: nil
  prop object, :any, default: nil
  prop activity_inception, :any, default: nil
  prop title_open, :boolean, default: nil
  prop title_prompt, :string, default: nil
  prop preloaded_recipients, :list, default: nil

  prop page, :any, default: nil
  prop boundaries_modal_id, :string, default: :sidebar_composer
  prop reset_smart_input, :boolean, default: false

  prop uploads, :any, default: nil
  prop uploaded_files, :any, default: nil
  prop trigger_submit, :boolean, default: nil
  # Classes to customize the smart input appearance
  prop replied_activity_class, :css_class,
    default:
      "items-center opacity-80 !flex-row order-first !p-3 before:border-neutral-content/80 mr-[40px]  m-3 mb-0 -mb-1"

  # defp handle_progress(_, entry, socket) do
  #   debug(entry, "progress")
  #   user = current_user(socket.assigns)

  #   if entry.done? and entry.valid? and user do
  #     with %{} = uploaded_media <-
  #       maybe_consume_uploaded_entry(socket, entry, fn %{path: path} = meta ->
  #         # debug(meta, "icon consume_uploaded_entry meta")
  #         Bonfire.Files.upload(nil, user, path)
  #         |> debug("uploaded")
  #       end) do
  #         # debug(uploaded_media)
  #         {:noreply,
  #           socket
  #           |> update(:uploaded_files, &(&1 ++ [uploaded_media]))
  #           |> assign_flash(:info, l "File uploaded!")
  #         }
  #     end
  #   else
  #     {:noreply, socket}
  #   end
  # end
end
