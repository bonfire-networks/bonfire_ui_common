defmodule Bonfire.UI.Common.Plugs.MaybeActivityRedirectPlug do
  import Plug.Conn
  # import Untangle

  def init(_opts), do: nil

  def call(%{req_headers: req_headers} = conn, opts) do
    if Bonfire.Common.Utils.maybe_apply(Bonfire.Federate.ActivityPub, :federating?, [],
         fallback_return: false
       ) != false do
      with_headers(conn, Map.new(req_headers), opts)
    else
      conn
    end
  end

  def call(conn, _opts) do
    conn
  end

  def with_headers(
        %{params: _params} = conn,
        %{"accept" => "application/ld+json" <> _},
        _opts
      ) do
    maybe_redirect(conn)
  end

  def with_headers(
        %{params: _params} = conn,
        %{"accept" => "application/activity+json" <> _},
        _opts
      ) do
    maybe_redirect(conn)
  end

  def with_headers(
        %{params: _params} = conn,
        %{"accept" => "application/json" <> _},
        _opts
      ) do
    maybe_redirect(conn)
  end

  def with_headers(conn, _, _opts) do
    conn
  end

  # the instance root names no actor or object, and a server fetching it as ActivityPub (as Lemmy does after fetching one of our actors, to read the site's actor) is after the instance's own actor: the service actor, the one nodeinfo names
  def maybe_redirect(%{path_info: []} = conn) do
    case Bonfire.Common.Utils.maybe_apply(
           Bonfire.Federate.ActivityPub.NodeinfoAdapter,
           :application_actor_uri,
           [],
           fallback_return: nil
         ) do
      url when is_binary(url) ->
        conn
        |> Phoenix.Controller.redirect(external: url)
        |> halt()

      _ ->
        as_html_if_live_view(conn)
    end
  end

  def maybe_redirect(%{params: params} = conn) when not is_nil(params) do
    request_url = request_url(conn)

    case Bonfire.Common.URIs.canonical_url(page_object(params) || params) do
      url when is_binary(url) and url != request_url ->
        conn
        |> Phoenix.Controller.redirect(external: url)
        |> halt()

      _ ->
        as_html_if_live_view(conn)
    end
  end

  def maybe_redirect(conn) do
    as_html_if_live_view(conn)
  end

  # a LiveView page renders only as HTML, so when there is no actor or object to send the request to, it gets the page as HTML, as Mastodon does, rather than a 500 for a body that can't be sent in the format asked for
  defp as_html_if_live_view(%{private: %{phoenix_live_view: _}} = conn),
    do: Phoenix.Controller.put_format(conn, "html")

  defp as_html_if_live_view(conn), do: conn

  # the object the page is about, loaded, since its ActivityPub id can't always be told from the URL: a group's, or any actor's made under the ULID scheme, is `/pub/<type>/<ULID>`, and a mirrored one's is its id on its own server. `nil` when the route names nothing we have, and the URL's params are used as before. No boundary check: this only says where its actor or object lives, which that endpoint guards
  defp page_object(params) do
    case params["id"] || params["username"] do
      id_or_username when is_binary(id_or_username) ->
        if Bonfire.Common.Types.is_uid?(id_or_username),
          do: loaded(id_or_username),
          else: by_username(id_or_username)

      _ ->
        nil
    end
  end

  defp by_username(username) do
    case Bonfire.Common.Utils.maybe_apply(Bonfire.Me.Characters, :by_username, [username],
           fallback_return: nil
         ) do
      {:ok, %{id: id}} -> loaded(id)
      _ -> nil
    end
  end

  # with what its canonical URL is read from: where it came from (an actor's on its character, anything else's on itself), and for a user whether it is a shared account, which makes it an organisation rather than a person (`prune:`, as each object has only some of these)
  defp loaded(id) do
    case Bonfire.Common.Needles.get(id, skip_boundary_check: true) do
      {:ok, object} ->
        Bonfire.Common.Repo.maybe_preload(object, [:peered, :shared_user, character: [:peered]],
          prune: true
        )

      _ ->
        nil
    end
  end
end
