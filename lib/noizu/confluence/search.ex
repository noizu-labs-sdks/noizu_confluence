defmodule Noizu.Confluence.Search do
  @moduledoc """
  CQL search — Confluence REST API **v1** (`GET /wiki/rest/api/search`); v2 has
  no full CQL-search equivalent (see `docs/API-CONTRACT.md` §2).

  Note: Atlassian no longer supports user-specific CQL fields (`user`,
  `user.fullname`, ...) on this endpoint — use `GET /rest/api/search/user`
  for user lookups (not wrapped by this library).
  """

  alias Noizu.Confluence.{Client, Error, Pagination}

  @search "/rest/api/search"

  @type opts :: keyword()

  @doc """
  Run a CQL query. `cql` is required (e.g. `"type=page AND space=ENG"`).
  `opts[:params]` may carry `limit`, `start`, `cursor`, `next`, `prev`,
  `includeArchivedSpaces`, `excludeCurrentSpaces`, `cqlcontext`, `excerpt`, ...
  plus any Req request option.
  """
  @spec cql(Client.t(), String.t(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def cql(client, cql, opts \\ []) do
    params =
      opts
      |> Keyword.get(:params, %{})
      |> Map.merge(%{"cql" => cql})

    Client.request(client, :get, @search, Keyword.put(opts, :params, params))
  end

  @doc "Lazily stream every search result across cursor pages."
  @spec cql_stream(Client.t(), String.t(), opts()) :: Enumerable.t()
  def cql_stream(client, cql, opts \\ []) do
    params =
      opts
      |> Keyword.get(:params, %{})
      |> Map.merge(%{"cql" => cql})

    Pagination.stream(client, :get, @search, Keyword.put(opts, :params, params))
  end
end
