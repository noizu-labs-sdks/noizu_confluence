defmodule Noizu.Confluence.Labels do
  @moduledoc """
  Labels — v2 for reading (`GET /wiki/api/v2/.../labels`), v1 for writing
  (v2 label endpoints are read-only; `POST`/`DELETE` exist only under
  `/wiki/rest/api/content/{id}/label`). See `docs/API-CONTRACT.md` §3.6.

  v1 and v2 share content ids, so the v2 numeric page/blog-post id is used as
  the v1 `{id}` for `add/3` and `remove/3`.
  """

  alias Noizu.Confluence.{Client, Error, Pagination, Uri}

  @type id :: String.t() | integer()
  @type opts :: keyword()
  @type label :: String.t() | %{required(String.t()) => term()}

  @doc "List the labels of a page."
  @spec list_for_page(Client.t(), id(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def list_for_page(client, page_id, opts \\ []),
    do: Client.request(client, :get, "/api/v2/pages/#{Uri.path_segment(page_id)}/labels", opts)

  @doc "Lazily stream the labels of a page."
  @spec list_for_page_stream(Client.t(), id(), opts()) :: Enumerable.t()
  def list_for_page_stream(client, page_id, opts \\ []),
    do: Pagination.stream(client, :get, "/api/v2/pages/#{Uri.path_segment(page_id)}/labels", opts)

  @doc "List the labels of a blog post."
  @spec list_for_blogpost(Client.t(), id(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def list_for_blogpost(client, blogpost_id, opts \\ []),
    do:
      Client.request(
        client,
        :get,
        "/api/v2/blogposts/#{Uri.path_segment(blogpost_id)}/labels",
        opts
      )

  @doc "Lazily stream the labels of a blog post."
  @spec list_for_blogpost_stream(Client.t(), id(), opts()) :: Enumerable.t()
  def list_for_blogpost_stream(client, blogpost_id, opts \\ []),
    do:
      Pagination.stream(
        client,
        :get,
        "/api/v2/blogposts/#{Uri.path_segment(blogpost_id)}/labels",
        opts
      )

  @doc "List the labels of a space."
  @spec list_for_space(Client.t(), id(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def list_for_space(client, space_id, opts \\ []),
    do: Client.request(client, :get, "/api/v2/spaces/#{Uri.path_segment(space_id)}/labels", opts)

  @doc "Lazily stream the labels of a space."
  @spec list_for_space_stream(Client.t(), id(), opts()) :: Enumerable.t()
  def list_for_space_stream(client, space_id, opts \\ []),
    do:
      Pagination.stream(client, :get, "/api/v2/spaces/#{Uri.path_segment(space_id)}/labels", opts)

  @doc """
  Add labels to content (v1 `POST /rest/api/content/{id}/label`).

  `labels` may be a single or list of plain strings (wrapped with
  `"prefix" => "global"`) or label maps (`%{"prefix" => "global", "name" => "x"}`
  — both keys required by the spec).
  """
  @spec add(Client.t(), id(), label() | [label(), ...], opts()) ::
          {:ok, map()} | {:error, Error.t()}
  def add(client, content_id, labels, opts \\ []) do
    body =
      labels
      |> List.wrap()
      |> Enum.map(fn
        %{} = label -> label
        name when is_binary(name) -> %{"prefix" => "global", "name" => name}
      end)

    Client.request(
      client,
      :post,
      "/rest/api/content/#{Uri.path_segment(content_id)}/label",
      [json: body] ++ opts
    )
  end

  @doc """
  Remove a label from content by name
  (v1 `DELETE /rest/api/content/{id}/label?name=`).
  """
  @spec remove(Client.t(), id(), String.t(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def remove(client, content_id, name, opts \\ []) do
    opts = Keyword.put_new(opts, :params, %{"name" => name})

    Client.request(
      client,
      :delete,
      "/rest/api/content/#{Uri.path_segment(content_id)}/label",
      opts
    )
  end
end
