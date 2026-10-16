defmodule Noizu.Confluence.Properties do
  @moduledoc """
  Content properties — Confluence REST API v2, uniform CRUD under
  `/wiki/api/v2/{pages|blogposts|spaces}/{id}/properties[/{property-id}]`.

  Create bodies take `"key"` + `"value"`; updates additionally require
  `"version.number"` = current + 1, which `update/5` auto-fetches and
  increments when `"version"` is omitted.
  """

  alias Noizu.Confluence.{Client, Error, Pagination}

  @bases %{
    page: "/api/v2/pages",
    blogpost: "/api/v2/blogposts",
    space: "/api/v2/spaces"
  }

  @type parent_type :: :page | :blogpost | :space
  @type id :: String.t() | integer()
  @type opts :: keyword()

  @doc "List the properties of a page, blog post, or space."
  @spec list(Client.t(), parent_type(), id(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def list(client, type, id, opts \\ []),
    do: Client.request(client, :get, "#{base!(type)}/#{id}/properties", opts)

  @doc "Lazily stream the properties of a page, blog post, or space."
  @spec list_stream(Client.t(), parent_type(), id(), opts()) :: Enumerable.t()
  def list_stream(client, type, id, opts \\ []),
    do: Pagination.stream(client, :get, "#{base!(type)}/#{id}/properties", opts)

  @doc "Create a content property. `attrs`: `%{\"key\" => ..., \"value\" => ...}`."
  @spec create(Client.t(), parent_type(), id(), map()) :: {:ok, map()} | {:error, Error.t()}
  def create(client, type, id, attrs),
    do: Client.request(client, :post, "#{base!(type)}/#{id}/properties", json: attrs)

  @doc "Get a content property by its property id."
  @spec get(Client.t(), parent_type(), id(), id(), opts()) ::
          {:ok, map()} | {:error, Error.t()}
  def get(client, type, id, property_id, opts \\ []),
    do: Client.request(client, :get, "#{base!(type)}/#{id}/properties/#{property_id}", opts)

  @doc """
  Update a content property. `attrs`: `"key"`, `"value"`, optional `"version"`.
  When `"version"` is absent the current property is fetched and
  `version.number` set to `current + 1`.
  """
  @spec update(Client.t(), parent_type(), id(), id(), map()) ::
          {:ok, map()} | {:error, Error.t()}
  def update(client, type, id, property_id, attrs) do
    path = "#{base!(type)}/#{id}/properties/#{property_id}"

    with {:ok, attrs} <- ensure_version(client, type, id, property_id, attrs) do
      Client.request(client, :put, path, json: attrs)
    end
  end

  @doc "Delete a content property by its property id."
  @spec delete(Client.t(), parent_type(), id(), id()) :: {:ok, map()} | {:error, Error.t()}
  def delete(client, type, id, property_id),
    do: Client.request(client, :delete, "#{base!(type)}/#{id}/properties/#{property_id}")

  defp base!(type) when type in [:page, :blogpost, :space], do: Map.fetch!(@bases, type)

  defp base!(other) do
    raise ArgumentError,
          "parent type must be :page, :blogpost or :space, got: #{inspect(other)}"
  end

  defp ensure_version(client, type, id, property_id, attrs) do
    if Map.has_key?(attrs, "version") do
      {:ok, attrs}
    else
      case get(client, type, id, property_id) do
        {:ok, %{"version" => %{"number" => current}}} ->
          {:ok, Map.put(attrs, "version", %{"number" => current + 1})}

        {:ok, body} ->
          {:error,
           %Error{
             status: nil,
             code: "version_lookup_failed",
             message: "could not read version.number from property #{property_id}",
             errors: [body]
           }}

        {:error, error} ->
          {:error, error}
      end
    end
  end
end
