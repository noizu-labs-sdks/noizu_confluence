defmodule Noizu.Confluence.Spaces do
  @moduledoc """
  Spaces — Confluence REST API v2 (`/wiki/api/v2/spaces`).

  All functions take a `Noizu.Confluence.Client` first. List options accept
  `:params` (query map: `limit`, `cursor`, `type`, `status`, `sort`, `keys`, ...)
  plus any Req request option; both are forwarded.
  """

  alias Noizu.Confluence.{Client, Error, Pagination}

  @collection "/api/v2/spaces"

  @type opts :: keyword()

  @doc "List spaces visible to the caller."
  @spec list(Client.t(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def list(client, opts \\ []), do: Client.request(client, :get, @collection, opts)

  @doc "Lazily stream every space across cursor pages."
  @spec list_stream(Client.t(), opts()) :: Enumerable.t()
  def list_stream(client, opts \\ []), do: Pagination.stream(client, :get, @collection, opts)

  @doc "Get a space by id."
  @spec get(Client.t(), String.t() | integer(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def get(client, space_id, opts \\ []),
    do: Client.request(client, :get, "#{@collection}/#{space_id}", opts)

  @doc """
  Create a space. `attrs` per the v2 spec: required `"name"`; optional `"key"`,
  `"alias"`, `"description"`, `"createPrivateSpace"`, ... (string keys, passed
  through verbatim).
  """
  @spec create(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def create(client, attrs), do: Client.request(client, :post, @collection, json: attrs)
end
