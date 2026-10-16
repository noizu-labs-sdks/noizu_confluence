defmodule Noizu.Confluence.BlogPosts do
  @moduledoc """
  Blog posts — Confluence REST API v2 (`/wiki/api/v2/blogposts`).

  `update/3` auto-increments `version.number` the same way as
  `Noizu.Confluence.Pages.update/3`.
  """

  alias Noizu.Confluence.{Client, Error, Pagination}

  @collection "/api/v2/blogposts"

  @type id :: String.t() | integer()
  @type opts :: keyword()

  @doc "List blog posts."
  @spec list(Client.t(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def list(client, opts \\ []), do: Client.request(client, :get, @collection, opts)

  @doc "Lazily stream every blog post across cursor pages."
  @spec list_stream(Client.t(), opts()) :: Enumerable.t()
  def list_stream(client, opts \\ []), do: Pagination.stream(client, :get, @collection, opts)

  @doc "Get a blog post by id."
  @spec get(Client.t(), id(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def get(client, blogpost_id, opts \\ []),
    do: Client.request(client, :get, "#{@collection}/#{blogpost_id}", opts)

  @doc """
  Create a blog post. `attrs` per the v2 spec: required `"spaceId"`, plus
  `"title"`, `"body"` (`%{"representation" => ..., "value" => ...}`),
  `"status"`, optional `"createdAt"`.
  """
  @spec create(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def create(client, attrs), do: Client.request(client, :post, @collection, json: attrs)

  @doc """
  Update a blog post. `attrs` string keys: `"title"`, `"body"`, optional
  `"status"` (default `"current"`), optional `"version"`. When `"version"` is
  absent the current version is fetched and incremented.
  """
  @spec update(Client.t(), id(), map(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def update(client, blogpost_id, attrs, opts \\ []) do
    with {:ok, attrs} <- ensure_version(client, blogpost_id, attrs) do
      payload =
        attrs
        |> Map.put_new("id", to_string(blogpost_id))
        |> Map.put_new("status", "current")

      Client.request(client, :put, "#{@collection}/#{blogpost_id}", [json: payload] ++ opts)
    end
  end

  @doc "Delete a blog post by id."
  @spec delete(Client.t(), id()) :: {:ok, map()} | {:error, Error.t()}
  def delete(client, blogpost_id),
    do: Client.request(client, :delete, "#{@collection}/#{blogpost_id}")

  @doc "List the blog posts of a space."
  @spec list_for_space(Client.t(), id(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def list_for_space(client, space_id, opts \\ []),
    do: Client.request(client, :get, "/api/v2/spaces/#{space_id}/blogposts", opts)

  @doc "Lazily stream the blog posts of a space."
  @spec list_for_space_stream(Client.t(), id(), opts()) :: Enumerable.t()
  def list_for_space_stream(client, space_id, opts \\ []),
    do: Pagination.stream(client, :get, "/api/v2/spaces/#{space_id}/blogposts", opts)

  defp ensure_version(client, blogpost_id, attrs) do
    if Map.has_key?(attrs, "version") do
      {:ok, attrs}
    else
      case get(client, blogpost_id) do
        {:ok, %{"version" => %{"number" => current}}} ->
          {:ok, Map.put(attrs, "version", %{"number" => current + 1})}

        {:ok, body} ->
          {:error,
           %Error{
             status: nil,
             code: "version_lookup_failed",
             message: "could not read version.number from current blog post #{blogpost_id}",
             errors: [body]
           }}

        {:error, error} ->
          {:error, error}
      end
    end
  end
end
