defmodule Bonfire.UI.Common.SmartInputInlineLive do
  use Bonfire.UI.Common.Web, :stateful_component
  alias Bonfire.UI.Common.SmartInputContainerLive
  alias Bonfire.UI.Common.SmartInput.LiveHandler

  @embed_reply_dom_id :inline_reply
  def embed_reply_dom_id, do: @embed_reply_dom_id

  prop reply_to_id, :any, default: nil
  prop context_id, :string, default: nil, required: false
  prop smart_input_component, :atom, default: nil
  prop to_boundaries, :any, default: nil
  prop boundary_preset, :any, default: nil
  prop to_circles, :list, default: []
  prop exclude_circles, :list, default: []
  prop verb_permissions, :map, default: %{}
  prop preview_boundary_for_id, :any, default: nil
  prop preview_boundary_for_username, :any, default: nil
  prop preview_boundary_verbs, :list, default: []
  prop smart_input_opts, :map, default: %{}
  prop showing_within, :atom, default: :smart_input
  # "remote" => guests get a single button to the remote-interaction page
  # (reply from any fediverse server); otherwise local Login/Register
  prop auth_mode, :string, default: nil

  # set in update/2: an embed guest on an invite-only, federating instance cannot sign up, so replying from their own fediverse account comes first
  data remote_first, :boolean, default: false
  prop activity, :any, default: nil
  prop hide_smart_input, :boolean, default: false
  prop object, :any, default: nil
  prop activity_inception, :any, default: nil
  # prop title_open, :boolean, default: nil
  prop title_prompt, :string, default: nil
  prop preloaded_recipients, :list, default: nil
  prop event_target, :any, default: nil
  prop selected_cover, :any, default: nil

  # prop thread_mode, :atom, default: nil
  prop page, :any, default: nil
  # prop without_sidebar, :string, default: nil

  def mount(socket),
    do:
      {:ok,
       socket
       |> SmartInputContainerLive.maybe_setup_uploads()}

  defp remote_first?(assigns) do
    assigns[:showing_within] == :thread_embed and
      is_nil(current_user(assigns[:__context__])) and
      maybe_apply(Bonfire.Me.Accounts, :instance_is_invite_only?, [], fallback_return: false) ==
        true and
      maybe_apply(Bonfire.Federate.ActivityPub, :federating?, [], fallback_return: false) == true
  end

  def update(assigns, socket) do
    dom_id =
      to_string(assigns[:id] || assigns[:reply_to_id] || assigns[:context_id] || "default")

    socket =
      socket
      |> assign(assigns)
      |> assign(:composer_dom_id, dom_id)

    remote_first? = remote_first?(socket.assigns)

    socket =
      if remote_first?,
        do: assign(socket, auth_mode: "remote", remote_first: true),
        else: assign(socket, :remote_first, false)

    # Precompute once (canonical_url may run a Peered query); nil → the
    # template falls back to local Login/Register instead of a dead link.
    remote_interaction_url =
      if socket.assigns[:auth_mode] == "remote" do
        Bonfire.UI.Common.remote_interaction_url(
          "reply",
          l("this discussion"),
          socket.assigns[:reply_to_id] || socket.assigns[:context_id],
          socket.assigns[:__context__]
        )
      end

    context = socket.assigns[:__context__]

    go_url =
      e(context, :go, nil) ||
        String.replace(
          e(context, :current_url, "/"),
          "/comments/embed/",
          "/comments/embed/interactive/"
        )

    can_reply =
      if current_user = current_user(context) do
        case socket.assigns[:reply_to_id] || socket.assigns[:context_id] do
          # standalone compose (e.g. /write): authoring a top-level post, nothing to check `:reply` against
          nil -> true
          reply_to_id -> Bonfire.Boundaries.can?(current_user, :reply, reply_to_id)
        end
      end

    {:ok,
     assign(socket,
       remote_interaction_url: remote_interaction_url,
       go_url: go_url,
       can_reply: can_reply
     )}
  end

  defdelegate handle_event(action, attrs, socket),
    to: SmartInputContainerLive
end
