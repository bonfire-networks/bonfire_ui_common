defmodule Bonfire.UI.Common.PlugAttackTesting do
  @moduledoc """
  For testing rate limits
  via https://www.paraxial.io/blog/throttle-requests
  """

  @form_name "login_fields"

  def run(url, filename) do
    pairs = parse_file(filename)
    attack(url, pairs)
  end

  def run(url, filename, rate_limit) do
    pairs = parse_file(filename)
    irl = String.to_integer(rate_limit)
    attack(url, pairs, irl)
  end

  def parse_file(filename) do
    filename
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(fn x -> String.split(x, ",", trim: true) end)
  end

  def get_csrf_and_cookie(url) do
    with {:ok, r} <- HTTPoison.get(url),
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

  def send_login(url, email, password, form_name \\ @form_name)

  def send_login({url, form_name}, email, password, _) do
    send_login(url, email, password, form_name)
  end

  def send_login(url, email, password, form_name) do
    cc = get_csrf_and_cookie(url)
    body = get_post_body(cc.csrf_token, form_name, email, password)
    tep = get_tep(email, password)

    case HTTPoison.post(url, body, @headers, hackney: [cookie: [cc.cookie]]) do
      {:ok, %{status_code: 429}} ->
        tep <> " POST to #{url} was throttled (received status 429)\n"

      {:ok, r} ->
        tep <> " POST to #{url} returned status #{r.status_code}\n"

      _ ->
        tep <> " POST to #{url} failed\n"
    end
  end

  def get_post_body(csrf_token, form_name, email, password) do
    [user, domain] = String.split(email, "@")

    "_csrf_token=#{csrf_token}&#{form_name}%5Bemail%5D=#{user}%40#{domain}&#{form_name}%5Bpassword%5D=#{password}"
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
  def attack(url, login_pairs, rpm \\ 500) do
    do_attack(url, login_pairs, convert_rpm(rpm))
    |> Enum.map(&Task.await/1)
  end

  def do_attack(_, [], _sleep), do: []

  def do_attack(url, [[email, pass] | t], sleep_n) do
    Process.sleep(sleep_n)
    [Task.async(fn -> send_login(url, email, pass) end) | do_attack(url, t, sleep_n)]
  end
end
