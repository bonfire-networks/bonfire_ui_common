defmodule Bonfire.UI.Common.PlugAttackTesting do
  @moduledoc """
  For testing rate limits
  via https://www.paraxial.io/blog/throttle-requests
  """
  @url "http://localhost:4000/login"
  @form_name "login_fields"

  def run([filename]) do
    pairs = parse_file(filename)
    attack(pairs)
  end

  def run([filename, rate_limit]) do
    pairs = parse_file(filename)
    irl = String.to_integer(rate_limit)
    attack(pairs, irl)
  end

  def run(_), do: "Error: too many arguments"

  def parse_file(filename) do
    filename
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(fn x -> String.split(x, ",", trim: true) end)
  end

  def get_csrf_and_cookie() do
    with {:ok, r} <- HTTPoison.get(@url),
         {:ok, html} <- Floki.parse_document(r.body),
         [{_, [_, _, {_v, csrf_token} | _], []}] <- Floki.find(html, "[name=_csrf_token") do
      cookie = get_cookie(r)
      %{cookie: cookie, csrf_token: csrf_token}
    else
      e ->
        IO.inspect(e, label: "get_csrf_and_cookie unexpected")
        raise "Failed to get CSRF token and cookie"
    end
  end

  def get_cookie(response) do
    {_, cookie} =
      response.headers
      |> Enum.find(fn {x, _} -> x == "set-cookie" end)

    cookie
  end

  @headers [{"Content-Type", "application/x-www-form-urlencoded"}]

  def send_login(email, password) do
    cc = get_csrf_and_cookie()
    body = get_post_body(cc.csrf_token, email, password)
    tep = get_tep(email, password)

    case HTTPoison.post(@url, body, @headers, hackney: [cookie: [cc.cookie]]) do
      {:ok, %{status_code: 429}} ->
        tep <> " Login POST was throttled (received status 429)\n"

      {:ok, r} ->
        tep <> " Login POST status #{r.status_code}\n"

      _ ->
        tep <> " Login POST failed\n"
    end
  end

  def get_post_body(csrf_token, email, password) do
    [user, domain] = String.split(email, "@")

    "_csrf_token=#{csrf_token}&#{@form_name}%5Bemail_or_username%5D=#{user}%40#{domain}&#{@form_name}%5Bpassword%5D=#{password}"
  end

  def get_tep(email, password) do
    "#{NaiveDateTime.local_now()} #{email}/#{password} "
  end

  # Convert requests per minute into milliseconds for Process.sleep()
  def convert_rpm(rpm) do
    (1000 * (60 / rpm)) |> trunc()
  end

  # The main function you call to perform an account takeover attack
  #
  # login_pairs is a list of lists, for example:
  # [["corvid@example.com", "corvidPass2022"], ...]
  #
  # rpm is the limit on how many http requests will be sent
  # in a 60 second period. Defaults to 500
  def attack(login_pairs, rpm \\ 500) do
    login_pairs
    |> do_attack(convert_rpm(rpm))
    |> Enum.map(&Task.await/1)
  end

  def do_attack([], _sleep), do: []

  def do_attack([[email, pass] | t], sleep_n) do
    Process.sleep(sleep_n)
    [Task.async(fn -> send_login(email, pass) end) | do_attack(t, sleep_n)]
  end
end
