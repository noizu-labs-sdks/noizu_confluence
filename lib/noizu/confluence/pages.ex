defmodule Noizu.Confluence.Pages do
  @moduledoc """
  Pages — Confluence REST API v2 (`/wiki/api/v2/pages`).

  `update/3` implements the v2 optimistic-locking rule (`version.number` =
  current + 1): when the attrs omit `"version"`, the current page is fetched and
  its version incremented automatically. See `docs/API-CONTRACT.md` §6.
  """

  alias Noizu.Confluence.{Client, Error, Pagination}

  @collection "/api/v2/pages"

  @type id :: String.t() | integer()
  @type opts :: keyword()

  @doc "List pages."
  @spec list(Client.t(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def list(client, opts \\ []), do: Client.request(client, :get, @collection, opts)

  @doc "Lazily stream every page across cursor pages."
  @spec list_stream(Client.t(), opts()) :: Enumerable.t()
  def list_stream(client, opts \\ []), do: Pagination.stream(client, :get, @collection, opts)

  @doc "Get a page by id (response includes `version.number`)."
  @spec get(Client.t(), id(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def get(client, page_id, opts \\ []),
    do: Client.request(client, :get, "#{@collection}/#{page_id}", opts)

  @doc """
  Create a page. `attrs` per the v2 spec: required `"spaceId"`, plus `"title"`,
  `"body"` (`%{"representation" => "storage" | "atlas_doc_format" | "wiki",
  "value" => ...}`), `"status"`, optional `"parentId"`. Extra keys pass through.
  """
  @spec create(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def create(client, attrs), do: Client.request(client, :post, @collection, json: attrs)

  @doc """
  Update a page (`PUT /api/v2/pages/{id}`). `attrs` string keys: `"title"`,
  `"body"`, optional `"status"` (default `"current"`), optional `"version"`
  (`%{"number" => n, "message" => m}`) and any extra passthrough keys.

  When `"version"` is absent the current page is fetched and `version.number`
  is set to `current + 1` (one extra GET). Pass `"version"` explicitly to skip
  the fetch.
  """
  @spec update(Client.t(), id(), map(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def update(client, page_id, attrs, opts \\ []) do
    with {:ok, attrs} <- ensure_version(client, page_id, attrs) do
      payload =
        attrs
        |> Map.put_new("id", to_string(page_id))
        |> Map.put_new("status", "current")

      Client.request(client, :put, "#{@collection}/#{page_id}", [json: payload] ++ opts)
    end
  end

  @doc "Delete a page by id."
  @spec delete(Client.t(), id()) :: {:ok, map()} | {:error, Error.t()}
  def delete(client, page_id), do: Client.request(client, :delete, "#{@collection}/#{page_id}")

  @doc "List the direct children of a page."
  @spec children(Client.t(), id(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def children(client, page_id, opts \\ []),
    do: Client.request(client, :get, "#{@collection}/#{page_id}/children", opts)

  @doc "Lazily stream the direct children of a page."
  @spec children_stream(Client.t(), id(), opts()) :: Enumerable.t()

  def children_stream(client, page_id, opts \\ []),
    do: Pagination.stream(client, :get, "#{@collection}/#{page_id}/children", opts)

  @doc "List the version history of a page."
  @spec versions(Client.t(), id(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def versions(client, page_id, opts \\ []),
    do: Client.request(client, :get, "#{@collection}/#{page_id}/versions", opts)

  @doc "Lazily stream the version history of a page."
  @spec versions_stream(Client.t(), id(), opts()) :: Enumerable.t()
  def versions_stream(client, page_id, opts \\ []),
    do: Pagination.stream(client, :get, "#{@collection}/#{page_id}/versions", opts)

  @doc "List the pages of a space."
  @spec list_for_space(Client.t(), id(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def list_for_space(client, space_id, opts \\ []),
    do: Client.request(client, :get, "/api/v2/spaces/#{space_id}/pages", opts)

  @doc "Lazily stream the pages of a space."
  @spec list_for_space_stream(Client.t(), id(), opts()) :: Enumerable.t()
  def list_for_space_stream(client, space_id, opts \\ []),
    do: Pagination.stream(client, :get, "/api/v2/spaces/#{space_id}/pages", opts)

  defp ensure_version(client, page_id, attrs) do
    if Map.has_key?(attrs, "version") do
      {:ok, attrs}
    else
      case get(client, page_id) do
        {:ok, %{"version" => %{"number" => current}}} ->
          {:ok, Map.put(attrs, "version", %{"number" => current + 1})}

        {:ok, body} ->
          {:error,
           %Error{
             status: nil,
             code: "version_lookup_failed",
             message: "could not read version.number from current page #{page_id}",
             errors: [body]
           }}

        {:error, error} ->
          {:error, error}
      end
    end
  end
end
