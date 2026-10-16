defmodule Noizu.Confluence do
  @moduledoc """
  Elixir client for the [Confluence Cloud REST API](https://developer.atlassian.com/cloud/confluence/rest/v2/intro/).

  API v2 is the primary surface; v1 is used only where v2 has no equivalent
  (CQL search, label writes, attachment upload/download, single-user lookups).
  The full coverage contract — auth, endpoints, pagination, body formats, error
  model, rate limits, and explicit non-goals — lives in `docs/API-CONTRACT.md`.

  There is no global state: build a `Noizu.Confluence.Client` and pass it to
  every call. All operations return `{:ok, map()}` / `{:error, %Noizu.Confluence.Error{}}`;
  paginated operations also have `*_stream/2` variants returning lazy `Stream`s
  that follow cursors.

  ## Basic auth (email + API token)

      client = Noizu.Confluence.Client.new(
        auth_mode: :basic,
        site: "example.atlassian.net",
        email: "user@example.com",
        api_token: System.fetch_env!("CONFLUENCE_API_TOKEN")
      )

  ## OAuth 2.0 (3LO) bearer

      client = Noizu.Confluence.Client.new(
        auth_mode: :oauth,
        cloud_id: "a436116f-02ce-4620-840b-f5dd8d3f7861",
        access_token: System.fetch_env!("ATLASSIAN_ACCESS_TOKEN")
      )

  ## Examples

      {:ok, space} =
        Noizu.Confluence.Spaces.create(client, %{"name" => "Engineering", "key" => "ENG"})

      {:ok, page} =
        Noizu.Confluence.Pages.create(client, %{
          "spaceId" => space["id"],
          "status" => "current",
          "title" => "Hello",
          "body" => %{"representation" => "storage", "value" => "<p>Hello</p>"}
        })

      # version.number is fetched and incremented automatically
      {:ok, page} = Noizu.Confluence.Pages.update(client, page["id"], %{"title" => "Hello v2"})

      {:ok, results} = Noizu.Confluence.Search.cql(client, "type=page AND space=ENG")

      Noizu.Confluence.Pages.list_stream(client, params: %{limit: 5})
      |> Stream.map(& &1["id"])
      |> Enum.take(10)

  ## Modules

    * `Noizu.Confluence.Client` — connection config + request pipeline (retries on 429)
    * `Noizu.Confluence.Error` — `{:error, ...}` struct (also raisable)
    * `Noizu.Confluence.Pagination` — cursor/`Stream` machinery
    * `Noizu.Confluence.Spaces` · `Noizu.Confluence.Pages` · `Noizu.Confluence.BlogPosts`
    * `Noizu.Confluence.Comments` — footer + inline comments
    * `Noizu.Confluence.Attachments` · `Noizu.Confluence.Labels` · `Noizu.Confluence.Properties`
    * `Noizu.Confluence.Search` · `Noizu.Confluence.Users`
  """
end
