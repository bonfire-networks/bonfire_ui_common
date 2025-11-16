defmodule Bonfire.UI.Common.RateLimit.Testing do
  @moduledoc """
  For testing rate limits via Hammer 7.

  Based on https://www.paraxial.io/blog/throttle-requests
  """
  alias Bonfire.Common.Utils

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
    # This is crucial - we fetch fresh CSRF for each POST
    # Process.sleep(1000)

    with {:ok, r} <- Req.get(url, retry: false),
         {:ok, html} <- Floki.parse_document(r.body),
         [{_, [_, _, {_v, csrf_token} | _], []}] <- Floki.find(html, "[name=_csrf_token]") do
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
    # Fetch fresh CSRF for each request (Phoenix rotates tokens)
    cc = get_csrf_and_cookie(url)
    body = get_post_body(cc.csrf_token, form_name, email, password)
    tep = get_tep(email, password)

    # Disable retry to prevent automatic backoff on 429 responses
    case Req.post(url, body: body, headers: @headers ++ [{"Cookie", cc.cookie}], retry: false) do
      {:ok, %{status: 429}} ->
        tep <> " POST to #{url} was throttled (received status 429)\n"

      {:ok, r} ->
        tep <> " POST to #{url} returned status #{r.status}\n"

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
  @doc """
  Run attack with adjustable RPM. For testing throttling, use slower RPM to avoid hitting GET rate limits.
  """
  def attack(url, login_pairs, rpm \\ 30) do
    # Use very slow default (30 RPM = 2 seconds per request) to avoid GET rate limits
    # Each request does GET (for CSRF) + POST, so we need to be conservative
    do_attack(url, login_pairs, convert_rpm(rpm))
    |> Enum.map(&Task.await(&1, 120_000))
  end

  def do_attack(_, [], _sleep), do: []

  def do_attack(url, [[email, pass] | t], sleep_n) do
    Process.sleep(sleep_n)

    [
      Utils.apply_task(:async, fn -> send_login(url, email, pass) end)
      | do_attack(url, t, sleep_n)
    ]
  end
end
