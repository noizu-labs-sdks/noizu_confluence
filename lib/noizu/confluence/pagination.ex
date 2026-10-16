defmodule Noizu.Confluence.Pagination do
  @moduledoc """
  Cursor pagination shared by v2 list endpoints and the v1 search endpoint.

  Confluence advertises the next page both as a `Link: <...>; rel="next"` response
  header and as `_links.next` in the response body (both absent on the last page).
  This module prefers the body `_links.next` and falls back to the `Link` header,
  normalizing the next URL against the client's base URL (absolute origins and the
  leading `/wiki` segment are stripped — the client base URL already carries it).

  See also `docs/API-CONTRACT.md` §4.
  """

  alias Noizu.Confluence.{Client, Error}

  @link_next_re ~r/<([^>]+)>;\s*rel="?next"?/i

  @doc """
  Returns the normalized request path for the next page, or `nil` when the
  response is the last page.
  """
  @spec next_path(map(), Req.Response.t() | nil) :: String.t() | nil
  def next_path(body, response \\ nil)

  def next_path(%{"_links" => %{"next" => next}}, _response) when is_binary(next),
    do: normalize_path(next)

  def next_path(_body, nil), do: nil

  def next_path(_body, %Req.Response{} = response) do
    case Req.Response.get_header(response, "link") do
      [] -> nil
      links -> extract_link(links)
    end
  end

  @doc """
  Normalizes a next-page URL from the provider to a request path relative to the
  client base URL: absolute URLs are reduced to path + query, and a leading
  `/wiki` segment is stripped (base URLs end in `/wiki`).
  """
  @spec normalize_path(String.t()) :: String.t()
  def normalize_path("http://" <> _ = url), do: from_absolute(url)
  def normalize_path("https://" <> _ = url), do: from_absolute(url)
  def normalize_path(path), do: strip_wiki(path)

  @doc """
  Lazy stream of result items across every page. `fun` is called with
  `{path, opts}` and must return `{:ok, body, response} | {:error, error}`.
  Raises `%Noizu.Confluence.Error{}` if a page fetch fails mid-stream.
  """
  @spec item_stream(
          ({String.t(), keyword()} ->
             {:ok, map() | binary(), Req.Response.t()} | {:error, Error.t()}),
          String.t(),
          keyword()
        ) :: Enumerable.t()
  def item_stream(fetch, first_path, first_opts) do
    {first_path, first_opts}
    |> Stream.unfold(fn
      :halt ->
        nil

      {path, opts} ->
        case fetch.({path, opts}) do
          {:ok, body, response} ->
            case next_path(body, response) do
              nil -> {items(body), :halt}
              next -> {items(body), {next, []}}
            end

          {:error, error} ->
            raise error
        end
    end)
    |> Stream.flat_map(& &1)
  end

  @doc "Stream helper for a resource collection."
  @spec stream(Client.t(), Client.method(), String.t(), keyword()) :: Enumerable.t()
  def stream(client, method, path, opts \\ []) do
    item_stream(&Client.request_full(client, method, elem(&1, 0), elem(&1, 1)), path, opts)
  end

  defp items(%{"results" => results}) when is_list(results), do: results
  defp items(%{} = body), do: [body]
  defp items(_), do: []

  defp from_absolute(url) do
    uri = URI.parse(url)
    path = uri.path || "/"
    if uri.query, do: strip_wiki(path <> "?" <> uri.query), else: strip_wiki(path)
  end

  defp strip_wiki("/wiki" <> rest), do: ensure_slash(rest)
  defp strip_wiki(path), do: ensure_slash(path)

  defp ensure_slash("/" <> _ = path), do: path
  defp ensure_slash("?" <> _ = path), do: path
  defp ensure_slash(""), do: "/"
  defp ensure_slash(path), do: "/" <> path

  defp extract_link(links) do
    joined = Enum.join(links, ", ")

    case Regex.run(@link_next_re, joined) do
      [_, url] -> normalize_path(url)
      _ -> nil
    end
  end
end
