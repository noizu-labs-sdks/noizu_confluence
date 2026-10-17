defmodule Noizu.Confluence.Attachments do
  @moduledoc """
  Attachments — Confluence REST API v2 for metadata operations, v1 for upload
  and full-content download (v2 has no upload and only thumbnail download).
  See `docs/API-CONTRACT.md` §3.5.

  Upload sends the v1 CSRF bypass header `X-Atlassian-Token: no-check` with a
  `multipart/form-data` body (`file` + `minorEdit` required by the spec,
  `comment` optional).
  """

  alias Noizu.Confluence.{Client, Error, Pagination, Uri}

  @collection "/api/v2/attachments"
  @v1_content "/rest/api/content"

  @type id :: String.t() | integer()
  @type opts :: keyword()
  @type source :: {:path, String.t()} | {:data, filename :: String.t(), binary()}

  @doc "List attachments (query: `mediaType`, `filename`, `sort`, `status`, `cursor`, `limit`, ...)."
  @spec list(Client.t(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def list(client, opts \\ []), do: Client.request(client, :get, @collection, opts)

  @doc "Lazily stream every attachment across cursor pages."
  @spec list_stream(Client.t(), opts()) :: Enumerable.t()
  def list_stream(client, opts \\ []), do: Pagination.stream(client, :get, @collection, opts)

  @doc "Get an attachment by id."
  @spec get(Client.t(), id(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def get(client, attachment_id, opts \\ []),
    do: Client.request(client, :get, "#{@collection}/#{Uri.path_segment(attachment_id)}", opts)

  @doc "Delete an attachment by id."
  @spec delete(Client.t(), id()) :: {:ok, map()} | {:error, Error.t()}
  def delete(client, attachment_id),
    do: Client.request(client, :delete, "#{@collection}/#{Uri.path_segment(attachment_id)}")

  @doc "List the attachments of a page."
  @spec list_for_page(Client.t(), id(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def list_for_page(client, page_id, opts \\ []),
    do:
      Client.request(client, :get, "/api/v2/pages/#{Uri.path_segment(page_id)}/attachments", opts)

  @doc "Lazily stream the attachments of a page."
  @spec list_for_page_stream(Client.t(), id(), opts()) :: Enumerable.t()
  def list_for_page_stream(client, page_id, opts \\ []),
    do:
      Pagination.stream(
        client,
        :get,
        "/api/v2/pages/#{Uri.path_segment(page_id)}/attachments",
        opts
      )

  @doc "List the attachments of a blog post."
  @spec list_for_blogpost(Client.t(), id(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def list_for_blogpost(client, blogpost_id, opts \\ []),
    do:
      Client.request(
        client,
        :get,
        "/api/v2/blogposts/#{Uri.path_segment(blogpost_id)}/attachments",
        opts
      )

  @doc "Lazily stream the attachments of a blog post."
  @spec list_for_blogpost_stream(Client.t(), id(), opts()) :: Enumerable.t()
  def list_for_blogpost_stream(client, blogpost_id, opts \\ []),
    do:
      Pagination.stream(
        client,
        :get,
        "/api/v2/blogposts/#{Uri.path_segment(blogpost_id)}/attachments",
        opts
      )

  @doc """
  Upload an attachment to a container (page or blog post) via v1 multipart.

  `source`:

    * `{:path, filepath}` — upload a file from disk
    * `{:data, filename, binary}` — upload raw bytes under `filename`
      (materialized to a 0600 temp file for the multipart body; the temp name
      is derived from `Path.basename/1` plus a random component, so path
      separators in `filename` cannot escape the tmp dir)

  Names that are empty, resolve to `.`/`..`, or contain a NUL byte are
  rejected with `{:error, %Noizu.Confluence.Error{code: "invalid_filename"}}`.
  The original `filename` is still sent to Confluence as the multipart part
  filename.

  Options: `:comment` (attachment comment), `:minor_edit` (default `true`),
  plus any Req request option. The `X-Atlassian-Token: no-check` header is
  always sent.
  """
  @spec upload(Client.t(), id(), source(), opts()) :: {:ok, map()} | {:error, Error.t()}
  def upload(client, container_id, source, opts \\ [])

  def upload(client, container_id, {:path, path}, opts) when is_binary(path) do
    stream = chunk_stream(path, 65_536)
    do_upload(client, container_id, {stream, []}, opts)
  end

  def upload(client, container_id, {:data, filename, content}, opts)
      when is_binary(filename) and is_binary(content) do
    with {:ok, safe_name} <- safe_filename(filename) do
      tmp_dir = System.tmp_dir!()
      tmp_path = Path.join(tmp_dir, "noizu-confluence-upload-" <> unique() <> "-" <> safe_name)

      try do
        write_temp!(tmp_path, content)

        stream = chunk_stream(tmp_path, 65_536)
        do_upload(client, container_id, {stream, [filename: filename]}, opts)
      after
        File.rm(tmp_path)
      end
    end
  end

  # Only the basename survives: path separators in a caller-supplied filename
  # must never reach the temp path (T-002), and the original name is passed to
  # Confluence separately as the multipart filename.
  defp safe_filename(filename) do
    base = Path.basename(filename)

    cond do
      base in ["", ".", ".."] ->
        {:error,
         %Error{
           status: nil,
           code: "invalid_filename",
           message: "invalid upload filename #{inspect(filename)}: resolves to #{inspect(base)}",
           errors: []
         }}

      String.contains?(base, <<0>>) ->
        {:error,
         %Error{
           status: nil,
           code: "invalid_filename",
           message: "invalid upload filename #{inspect(filename)}: contains a NUL byte",
           errors: []
         }}

      true ->
        {:ok, base}
    end
  end

  # Owner-only permissions are set before any content is written (T-003);
  # `:exclusive` also refuses to follow a pre-planted name.
  defp write_temp!(path, content) do
    device = File.open!(path, [:write, :exclusive, :binary])

    try do
      case File.chmod(path, 0o600) do
        :ok ->
          :ok = IO.binwrite(device, content)

        {:error, reason} ->
          raise File.Error, reason: reason, action: "chmod", path: path
      end
    after
      File.close(device)
    end
  end

  defp do_upload(client, container_id, file_part, opts) do
    minor_edit = Keyword.get(opts, :minor_edit, true)

    form =
      [file: file_part, minorEdit: to_string(minor_edit)] ++
        case Keyword.fetch(opts, :comment) do
          {:ok, comment} -> [comment: comment]
          :error -> []
        end

    Client.request(
      client,
      :post,
      "#{@v1_content}/#{Uri.path_segment(container_id)}/child/attachment",
      form_multipart: form,
      headers: [{"x-atlassian-token", "no-check"}]
    )
  end

  @doc """
  Download the full binary content of an attachment via v1
  (`GET /rest/api/content/{containerId}/child/attachment/{attachmentId}/download`).
  Returns `{:ok, binary}`.
  """
  @spec download(Client.t(), id(), id(), opts()) :: {:ok, binary()} | {:error, Error.t()}
  def download(client, container_id, attachment_id, opts \\ []) do
    Client.request(
      client,
      :get,
      "#{@v1_content}/#{Uri.path_segment(container_id)}/child/attachment/#{Uri.path_segment(attachment_id)}/download",
      [decode_body: false] ++ opts
    )
  end

  defp unique(), do: Base.encode16(:crypto.strong_rand_bytes(6), case: :lower)

  # Lazy 64 KiB chunked file stream for multipart uploads. `File.stream!/3`'
  # argument order changed in Elixir 1.16 — `(path, modes, line_or_bytes)`
  # before, `(path, line_or_bytes, modes)` after — and the pre-1.16 order
  # warns as deprecated on newer compilers. Branch at compile time so each
  # supported version (mix.exs allows ~> 1.15) compiles only its own
  # warning-free signature.
  if Version.match?(System.version(), ">= 1.16.0") do
    defp chunk_stream(path, chunk_size), do: File.stream!(path, chunk_size, [:read, :binary])
  else
    defp chunk_stream(path, chunk_size), do: File.stream!(path, [:read, :binary], chunk_size)
  end
end
