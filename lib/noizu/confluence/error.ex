defmodule Noizu.Confluence.Error do
  @moduledoc """
  Error struct returned as `{:error, %Noizu.Confluence.Error{}}` by every client
  operation (and raised by `*_stream` helpers mid-stream).

  Both provider error shapes are decoded:

  * v2: `{"errors": [{"status": 404, "code": "NOT_FOUND", "title": "...", "detail": "..."}]}`
    — the first entry feeds `code`/`message`; the full list is kept in `errors`.
  * v1: `{"statusCode": 400, "message": "...", "data": {...}}` — `data` is kept in `errors`.
  * Non-JSON bodies (HTML error pages) keep a truncated body in `message`.
  """

  defexception [:status, :code, :message, :errors]

  @type t :: %__MODULE__{
          status: non_neg_integer() | nil,
          code: String.t() | nil,
          message: String.t() | nil,
          errors: term()
        }

  @doc """
  Builds an error from an HTTP response. `status` is the HTTP status code,
  `body` the (possibly decoded) response body.
  """
  @spec from_response(non_neg_integer() | nil, term()) :: t()
  def from_response(status, body) when is_map(body) do
    cond do
      v2_errors?(body) ->
        first = hd(body["errors"])

        %__MODULE__{
          status: body["status"] || first["status"] || status,
          code: first["code"],
          message: first["title"] || first["detail"],
          errors: body["errors"]
        }

      body["statusCode"] != nil ->
        %__MODULE__{
          status: body["statusCode"],
          code: nil,
          message: body["message"],
          errors: Map.get(body, "data")
        }

      is_binary(body["message"]) ->
        %__MODULE__{status: status, code: body["code"], message: body["message"], errors: [body]}

      true ->
        %__MODULE__{status: status, code: nil, message: nil, errors: [body]}
    end
  end

  def from_response(status, body) when is_binary(body) do
    %__MODULE__{status: status, code: nil, message: truncate(body), errors: []}
  end

  def from_response(status, _body) do
    %__MODULE__{status: status, code: nil, message: nil, errors: []}
  end

  @doc "Builds an error from a transport-level exception (connection refused, timeout, ...)."
  @spec from_exception(Exception.t()) :: t()
  def from_exception(exception) do
    %__MODULE__{
      status: nil,
      code: "request_failed",
      message: Exception.message(exception),
      errors: []
    }
  end

  @impl Exception
  def message(%__MODULE__{status: nil, code: nil, message: nil}), do: "confluence request failed"
  def message(%__MODULE__{} = error), do: format(error)

  defp format(%__MODULE__{} = error) do
    status = if error.status, do: "status=#{error.status}", else: nil
    code = if error.code, do: "code=#{error.code}", else: nil

    [status, code, error.message]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> then(&("confluence_error: " <> &1))
  end

  defp v2_errors?(body), do: is_list(body["errors"]) and body["errors"] != []

  defp truncate(body) when byte_size(body) > 300, do: binary_part(body, 0, 300) <> "..."
  defp truncate(body), do: body
end
