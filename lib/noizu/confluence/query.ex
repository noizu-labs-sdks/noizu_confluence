defmodule Noizu.Confluence.Query do
  @moduledoc false

  # Params whose OpenAPI definition is `style=form, explode=false` are encoded
  # comma-joined; every other array param in the Atlassian specs is
  # `style=form, explode=true` and becomes repeated bare keys
  # (`ids=1&ids=2`, `space-id=10&space-id=20`). Verified against
  # openapi-v2.v3.json / swagger.v3.json (docs/API-CONTRACT.md §4).
  @comma_joined MapSet.new(["expand"])

  @doc """
  Encodes a query-params map into a raw query string.

  * scalars → `key=value` (booleans render `true`/`false`, `nil` values skipped)
  * list values → repeated bare keys by default (`ids=1&ids=2`)
  * `expand` → comma-joined (`expand=version,space`), per the spec's `explode: false`
  * output is deterministic: pairs are sorted by key (same-key pairs keep list order)
  """
  @spec encode(map()) :: String.t()
  def encode(params) when is_map(params) do
    params
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
    |> Enum.sort_by(fn {key, _} -> key end)
    |> Enum.flat_map(&pair/1)
    |> URI.encode_query()
  end

  defp pair({_key, nil}), do: []

  defp pair({key, values}) when is_list(values) do
    if MapSet.member?(@comma_joined, key) do
      [{key, Enum.map_join(values, ",", &to_string/1)}]
    else
      Enum.map(values, &{key, to_string(&1)})
    end
  end

  defp pair({key, value}), do: [{key, to_string(value)}]
end
