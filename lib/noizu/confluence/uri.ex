defmodule Noizu.Confluence.Uri do
  @moduledoc """
  URL-building helpers used by every resource module.

  Resource ids are interpolated into request paths; `path_segment/1` is the
  single choke point that turns an id into exactly one percent-encoded path
  segment, so a crafted id (`"1/../x?y=1"`) cannot inject extra path segments
  or a query string into a request (threat model T-004). Requests stay on the
  client's pinned host with the token's usual authority.
  """

  @doc """
  Encodes a resource id as exactly one URI path segment: `/`, `?`, `#`, `%`,
  `.` and every other reserved or unsafe character is percent-escaped, so a
  crafted id cannot inject extra path segments or a query string. Requests
  stay on the client's pinned host with the token's usual authority.
  """
  @spec path_segment(term()) :: String.t()
  def path_segment(id) do
    id
    |> to_string()
    |> URI.encode(&unescaped?/1)
  end

  defp unescaped?(char), do: URI.char_unreserved?(char) and char != ?.
end
