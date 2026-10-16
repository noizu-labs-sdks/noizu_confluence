defmodule Noizu.Confluence.Client do
  @moduledoc """
  Connection configuration and the request pipeline.

  Build one client struct per credential set and pass it explicitly to every
  operation — there is no global state.

      basic = Noizu.Confluence.Client.new(
        auth_mode: :basic,
        site: "example.atlassian.net",
        email: "user@example.com",
        api_token: token
      )

      oauth = Noizu.Confluence.Client.new(
        auth_mode: :oauth,
        cloud_id: "a436116f-02ce-4620-840b-f5dd8d3f7861",
        access_token: token
      )

  ## Options for `new/1`

    * `:auth_mode` — `:basic` (default) or `:oauth`
    * `:site` — basic auth: `"example"` or `"example.atlassian.net"`
      (a bare name gets `.atlassian.net` appended)
    * `:email`, `:api_token` — basic auth credentials (Atlassian account email +
      API token from id.atlassian.com)
    * `:cloud_id` — oauth: the Confluence cloudId (from
      `GET https://api.atlassian.com/oauth/token/accessible-resources`)
    * `:access_token` — oauth: live OAuth 2.0 (3LO) bearer token
    * `:max_retries` — retries after the initial attempt on 429 (default `3`,
      so at most 4 requests total)
    * `:retry_sleep` — `fn milliseconds -> ... end` used to wait between 429
      retries (default `&Process.sleep/1`); inject for tests
    * `:req_opts` — extra Req request options merged into every request
      (`:plug` for `Req.Test`, `:finch`, `:receive_timeout`, ...)

  Missing required fields for the chosen auth mode raise `ArgumentError`.
  """

  alias Noizu.Confluence.Error
  alias Noizu.Confluence.Query

  @oauth_api_base "https://api.atlassian.com"
  @max_retry_delay_ms 30_000

  defstruct [
    :auth_mode,
    :base_url,
    :site,
    :cloud_id,
    :email,
    :api_token,
    :access_token,
    :max_retries,
    :retry_sleep,
    :req_opts
  ]

  @type auth_mode :: :basic | :oauth
  @type method :: :get | :post | :put | :delete
  @type retry_sleep :: (non_neg_integer() -> term())

  @type t :: %__MODULE__{
          auth_mode: auth_mode(),
          base_url: String.t(),
          site: String.t() | nil,
          cloud_id: String.t() | nil,
          email: String.t() | nil,
          api_token: String.t() | nil,
          access_token: String.t() | nil,
          max_retries: non_neg_integer(),
          retry_sleep: retry_sleep(),
          req_opts: keyword()
        }

  @spec new(keyword()) :: t()
  def new(opts) when is_list(opts) do
    auth_mode = Keyword.get(opts, :auth_mode, :basic)
    site = normalize_site(Keyword.get(opts, :site))
    email = Keyword.get(opts, :email)
    api_token = Keyword.get(opts, :api_token)
    cloud_id = Keyword.get(opts, :cloud_id)
    access_token = Keyword.get(opts, :access_token)

    validate!(auth_mode, site, email, api_token, cloud_id, access_token)

    %__MODULE__{
      auth_mode: auth_mode,
      site: site,
      email: email,
      api_token: api_token,
      cloud_id: cloud_id,
      access_token: access_token,
      base_url: base_url(auth_mode, site, cloud_id),
      max_retries: Keyword.get(opts, :max_retries, 3),
      retry_sleep: Keyword.get(opts, :retry_sleep, &Process.sleep/1),
      req_opts: Keyword.get(opts, :req_opts, [])
    }
  end

  @doc """
  Performs a request and returns `{:ok, body}` on 2xx (decoded JSON map, or raw
  binary when `:decode_body: false` is passed in `opts`), or
  `{:error, %Noizu.Confluence.Error{}}` otherwise. Retries 429 responses
  honoring `Retry-After` up to the client's `:max_retries`.

  `opts` are Req request options: `:params` (query map — list values encode as
  repeated bare keys per the Atlassian specs, `expand` comma-joined), `:json`,
  `:form` (multipart), `:headers`, `:decode_body`, ...
  """
  @spec request(t(), method(), String.t(), keyword()) ::
          {:ok, map() | binary()} | {:error, Error.t()}
  def request(client, method, path, opts \\ []) do
    case request_full(client, method, path, opts) do
      {:ok, body, _response} -> {:ok, body}
      {:error, error} -> {:error, error}
    end
  end

  @doc false
  @spec request_full(t(), method(), String.t(), keyword()) ::
          {:ok, map() | binary(), Req.Response.t()} | {:error, Error.t()}
  def request_full(client, method, path, opts \\ [])
      when method in [:get, :post, :put, :delete] and is_binary(path) do
    req = build_request(client, method, path, opts)
    do_request(client, req, client.max_retries + 1)
  end

  defp build_request(client, method, path, opts) do
    {params, opts} = Keyword.pop(opts, :params)

    base =
      [
        base_url: client.base_url,
        retry: false,
        auth: auth(client)
      ] ++ client.req_opts

    Req.new(base) |> Req.merge([method: method, url: with_query(path, params)] ++ opts)
  end

  # Encodes `:params` into the URL ourselves instead of handing the map to
  # Req: Req renders list values Plug-style (`key[]=v`), while the Atlassian
  # specs define repeated bare keys (`ids=1&ids=2`) — see
  # `Noizu.Confluence.Query`.
  defp with_query(path, params) when is_map(params) and map_size(params) > 0 do
    query = Query.encode(params)

    if String.contains?(path, "?"), do: path <> "&" <> query, else: path <> "?" <> query
  end

  defp with_query(path, _params), do: path

  defp auth(%__MODULE__{auth_mode: :basic} = client),
    do: {:basic, client.email <> ":" <> client.api_token}

  defp auth(%__MODULE__{auth_mode: :oauth} = client), do: {:bearer, client.access_token}

  defp do_request(_client, _req, 0),
    do: {:error, Error.from_response(nil, "retry loop exhausted")}

  defp do_request(client, req, attempts_left) do
    case Req.request(req) do
      {:ok, %Req.Response{status: 429} = response} when attempts_left > 1 ->
        client.retry_sleep.(retry_delay_ms(response, client.max_retries - attempts_left + 1))
        do_request(client, req, attempts_left - 1)

      {:ok, %Req.Response{status: status, body: body} = response} when status in 200..299 ->
        {:ok, body, response}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, Error.from_response(status, body)}

      {:error, exception} ->
        {:error, Error.from_exception(exception)}
    end
  end

  defp retry_delay_ms(response, attempt) do
    case Req.Response.get_header(response, "retry-after") do
      [seconds | _] ->
        case Integer.parse(seconds) do
          {n, _} when n >= 0 -> min(n * 1000, @max_retry_delay_ms)
          _ -> backoff_ms(attempt)
        end

      [] ->
        backoff_ms(attempt)
    end
  end

  defp backoff_ms(attempt), do: min(1000 * 2 ** attempt, @max_retry_delay_ms)

  defp base_url(:basic, site, _cloud_id), do: "https://" <> site <> "/wiki"

  defp base_url(:oauth, _site, cloud_id),
    do: @oauth_api_base <> "/ex/confluence/" <> cloud_id <> "/wiki"

  defp normalize_site(nil), do: nil

  defp normalize_site(site) when is_binary(site) do
    site =
      site
      |> String.replace_prefix("https://", "")
      |> String.replace_prefix("http://", "")
      |> String.trim_trailing("/")

    if String.contains?(site, "."), do: site, else: site <> ".atlassian.net"
  end

  defp validate!(:basic, site, email, api_token, _cloud_id, _access_token) do
    missing =
      for {label, value} <- [site: site, email: email, api_token: api_token],
          value in [nil, ""],
          do: label

    unless missing == [] do
      raise ArgumentError,
            "auth_mode: :basic requires :site, :email and :api_token; missing #{inspect(missing)}"
    end
  end

  defp validate!(:oauth, _site, _email, _api_token, cloud_id, access_token) do
    missing =
      for {label, value} <- [cloud_id: cloud_id, access_token: access_token],
          value in [nil, ""],
          do: label

    unless missing == [] do
      raise ArgumentError,
            "auth_mode: :oauth requires :cloud_id and :access_token; missing #{inspect(missing)}"
    end
  end

  defp validate!(other, _, _, _, _, _) do
    raise ArgumentError, "auth_mode must be :basic or :oauth, got: #{inspect(other)}"
  end
end
