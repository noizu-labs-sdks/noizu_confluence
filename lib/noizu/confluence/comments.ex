defmodule Noizu.Confluence.Comments do
  @moduledoc """
  Footer and inline comments — Confluence REST API v2
  (`/wiki/api/v2/footer-comments`, `/wiki/api/v2/inline-comments`).

  Footer comments hang at the bottom of pages/blog posts/attachments; inline
  comments are anchored in the body and carry `inlineCommentProperties`. Create
  bodies take exactly one of `pageId` / `blogPostId` / `attachmentId` /
  `customContentId` (footer) or `pageId` / `blogPostId` (inline), an optional
  `parentCommentId`, and `body` (`%{"representation" => ..., "value" => ...}`).
  """

  alias Noizu.Confluence.{Client, Error, Pagination, Uri}

  @footer "/api/v2/footer-comments"
  @inline "/api/v2/inline-comments"

  @type id :: String.t() | integer()
  @type opts :: keyword()

  # -- Footer comments ---------------------------------------------------------

  @doc "List footer comments."
  @spec list_footer(Client.t(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def list_footer(client, opts \\ []), do: Client.request(client, :get, @footer, opts)

  @doc "Lazily stream every footer comment across cursor pages."
  @spec list_footer_stream(Client.t(), opts()) :: Enumerable.t()
  def list_footer_stream(client, opts \\ []),
    do: Pagination.stream(client, :get, @footer, opts)

  @doc "Get a footer comment by id."
  @spec get_footer(Client.t(), id(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def get_footer(client, comment_id, opts \\ []),
    do: Client.request(client, :get, "#{@footer}/#{Uri.path_segment(comment_id)}", opts)

  @doc "Create a footer comment. `attrs`: one parent id key, `body`, optional `parentCommentId`."
  @spec create_footer(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def create_footer(client, attrs), do: Client.request(client, :post, @footer, json: attrs)

  @doc "Update a footer comment's body."
  @spec update_footer(Client.t(), id(), map()) :: {:ok, map()} | {:error, Error.t()}
  def update_footer(client, comment_id, attrs),
    do: Client.request(client, :put, "#{@footer}/#{Uri.path_segment(comment_id)}", json: attrs)

  @doc "Delete a footer comment by id."
  @spec delete_footer(Client.t(), id()) :: {:ok, map()} | {:error, Error.t()}
  def delete_footer(client, comment_id),
    do: Client.request(client, :delete, "#{@footer}/#{Uri.path_segment(comment_id)}")

  @doc "List the replies (children) of a footer comment."
  @spec footer_children(Client.t(), id(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def footer_children(client, comment_id, opts \\ []),
    do: Client.request(client, :get, "#{@footer}/#{Uri.path_segment(comment_id)}/children", opts)

  @doc "List footer comments of a page."
  @spec list_footer_for_page(Client.t(), id(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def list_footer_for_page(client, page_id, opts \\ []),
    do:
      Client.request(
        client,
        :get,
        "/api/v2/pages/#{Uri.path_segment(page_id)}/footer-comments",
        opts
      )

  @doc "Lazily stream the footer comments of a page."
  @spec list_footer_for_page_stream(Client.t(), id(), opts()) :: Enumerable.t()
  def list_footer_for_page_stream(client, page_id, opts \\ []),
    do:
      Pagination.stream(
        client,
        :get,
        "/api/v2/pages/#{Uri.path_segment(page_id)}/footer-comments",
        opts
      )

  @doc "List footer comments of a blog post."
  @spec list_footer_for_blogpost(Client.t(), id(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def list_footer_for_blogpost(client, blogpost_id, opts \\ []),
    do:
      Client.request(
        client,
        :get,
        "/api/v2/blogposts/#{Uri.path_segment(blogpost_id)}/footer-comments",
        opts
      )

  # -- Inline comments ---------------------------------------------------------

  @doc "List inline comments."
  @spec list_inline(Client.t(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def list_inline(client, opts \\ []), do: Client.request(client, :get, @inline, opts)

  @doc "Lazily stream every inline comment across cursor pages."
  @spec list_inline_stream(Client.t(), opts()) :: Enumerable.t()
  def list_inline_stream(client, opts \\ []),
    do: Pagination.stream(client, :get, @inline, opts)

  @doc "Get an inline comment by id."
  @spec get_inline(Client.t(), id(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def get_inline(client, comment_id, opts \\ []),
    do: Client.request(client, :get, "#{@inline}/#{Uri.path_segment(comment_id)}", opts)

  @doc """
  Create an inline comment. `attrs`: `pageId` or `blogPostId`, `body`,
  optional `parentCommentId`, and `inlineCommentProperties`
  (e.g. `%{"textProperties" => %{"..."}}` per Atlassian docs).
  """
  @spec create_inline(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def create_inline(client, attrs), do: Client.request(client, :post, @inline, json: attrs)

  @doc "Update an inline comment's body."
  @spec update_inline(Client.t(), id(), map()) :: {:ok, map()} | {:error, Error.t()}
  def update_inline(client, comment_id, attrs),
    do: Client.request(client, :put, "#{@inline}/#{Uri.path_segment(comment_id)}", json: attrs)

  @doc "Delete an inline comment by id."
  @spec delete_inline(Client.t(), id()) :: {:ok, map()} | {:error, Error.t()}
  def delete_inline(client, comment_id),
    do: Client.request(client, :delete, "#{@inline}/#{Uri.path_segment(comment_id)}")

  @doc "List the replies (children) of an inline comment."
  @spec inline_children(Client.t(), id(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def inline_children(client, comment_id, opts \\ []),
    do: Client.request(client, :get, "#{@inline}/#{Uri.path_segment(comment_id)}/children", opts)

  @doc "List inline comments of a page."
  @spec list_inline_for_page(Client.t(), id(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def list_inline_for_page(client, page_id, opts \\ []),
    do:
      Client.request(
        client,
        :get,
        "/api/v2/pages/#{Uri.path_segment(page_id)}/inline-comments",
        opts
      )

  @doc "Lazily stream the inline comments of a page."
  @spec list_inline_for_page_stream(Client.t(), id(), opts()) :: Enumerable.t()
  def list_inline_for_page_stream(client, page_id, opts \\ []),
    do:
      Pagination.stream(
        client,
        :get,
        "/api/v2/pages/#{Uri.path_segment(page_id)}/inline-comments",
        opts
      )

  @doc "List inline comments of a blog post."
  @spec list_inline_for_blogpost(Client.t(), id(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def list_inline_for_blogpost(client, blogpost_id, opts \\ []),
    do:
      Client.request(
        client,
        :get,
        "/api/v2/blogposts/#{Uri.path_segment(blogpost_id)}/inline-comments",
        opts
      )
end
