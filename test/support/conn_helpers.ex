defmodule Bonfire.UI.Common.Test.ConnHelpers do
  require Phoenix.ConnTest
  alias Phoenix.ConnTest
  alias Phoenix.Controller

  alias Plug.Conn
  alias Plug.Session

  @endpoint Application.compile_env!(:bonfire, :endpoint_module)

  def conn(), do: ConnTest.build_conn()

  def with_method(conn, :get), do: %{conn | method: "GET"}

  def with_method(conn, :post), do: %{conn | method: "POST"}

  def with_params(conn, %{} = params), do: %{conn | params: params}

  def with_user(conn, %{} = user), do: Conn.assign(conn, :current_user, user)

  def with_accept_json(conn),
    do: Conn.put_req_header(conn, "accept", "application/json")

  def with_request_json(conn),
    do: Conn.put_resp_content_type(conn, "application/json")

  def with_accept_html(conn),
    do: Conn.put_req_header(conn, "accept", "text/html")

  def with_authorization(conn, %{id: id}),
    do: Conn.put_req_header(conn, "authorization", "Bearer #{id}")

  def json_conn(), do: conn() |> with_accept_json() |> with_request_json()

  def html_conn(), do: with_accept_html(conn())

  def user_conn(conn \\ json_conn(), user), do: with_user(conn, user)

  def token_conn(conn \\ json_conn(), token),
    do: with_authorization(conn, token)

  @default_opts [
    store: :cookie,
    key: "foobar",
    encryption_salt: "encrypted cookie salt",
    signing_salt: "signing salt",
    log: false
  ]
  @secret String.duplicate("abcdef0123456789", 8)
  @signing_opts Plug.Session.init(Keyword.put(@default_opts, :encrypt, false))

  def plugged(conn) do
    conn
    |> Conn.put_private(:phoenix_endpoint, @endpoint)
    |> Map.put(:secret_key_base, @secret)
    |> Session.call(@signing_opts)
    |> Controller.accepts(["html", "json"])
    |> Conn.fetch_query_params()
    |> Conn.fetch_session()
    |> Controller.fetch_flash()
  end

  @doc false
  def camel_map(%{} = vars) do
    Enum.reduce(vars, %{}, fn {k, v}, acc -> Map.put(acc, camel(k), v) end)
  end

  @doc false
  def camel(atom) when is_atom(atom), do: camel(Atom.to_string(atom))
  def camel(binary) when is_binary(binary), do: Recase.to_camel(binary)

  @doc false
  def uncamel_map(%{} = map) do
    Enum.reduce(map, %{}, fn {k, v}, acc -> Map.put(acc, uncamel(k), v) end)
  end

  @doc false
  def uncamel(atom) when is_atom(atom), do: atom
  def uncamel("__typeName"), do: :typename

  def uncamel(bin) when is_binary(bin),
    do: String.to_existing_atom(Recase.to_snake(bin))

  def extract_files(%{variables: vars} = query) do
    case extract_file_vars(vars) do
      {[], []} ->
        query

      {new_files, new_vars} ->
        query
        |> Map.update!(:variables, &Map.merge(&1, new_vars))
        |> Map.merge(new_files)
    end
  end

  defp extract_file_vars(vars, path \\ []) do
    {new_files, new_vars} =
      Enum.flat_map_reduce(vars, %{}, fn {key, val}, acc ->
        path = path ++ [key]

        case val do
          %Plug.Upload{} = file ->
            file_key = Enum.join(path, "_")

            {
              %{String.to_atom(file_key) => file},
              put_in_map(acc, path, file_key)
            }

          inner when not is_struct(inner) and is_map(inner) ->
            {files, vars} = extract_file_vars(inner, path)
            {files, Map.merge(acc, vars)}

          _other ->
            {%{}, acc}
        end
      end)

    {Enum.into(new_files, %{}), new_vars}
  end

  defp put_in_map(%{} = map, [key], val) do
    Map.put(map, key, val)
  end

  defp put_in_map(%{} = map, [key | path], val) when is_list(path) do
    {_, ret} =
      Map.get_and_update(map, key, fn existing ->
        {val, put_in_map(existing || %{}, path, val)}
      end)

    ret
  end
end
