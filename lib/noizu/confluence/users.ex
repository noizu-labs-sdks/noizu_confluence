defmodule Noizu.Confluence.Users do
  @moduledoc """
  Users — Confluence REST API **v1** (`/wiki/rest/api/user`); the v2 spec has no
  single-user get/current endpoints (only the admin `/users-bulk`). See
  `docs/API-CONTRACT.md` §3.9.
  """

  alias Noizu.Confluence.{Client, Error}

  @type opts :: keyword()

  @doc "Get the user tied to the client's credentials."
  @spec current(Client.t(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def current(client, opts \\ []),
    do: Client.request(client, :get, "/rest/api/user/current", opts)

  @doc "Get a user by Atlassian account id (`GET /rest/api/user?accountId=`)."
  @spec get(Client.t(), String.t(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def get(client, account_id, opts \\ []) do
    params = Keyword.put_new(opts, :params, %{"accountId" => account_id})
    Client.request(client, :get, "/rest/api/user", params)
  end
end
