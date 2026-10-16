# Noizu.Confluence

Elixir client for the [Confluence Cloud REST API](https://developer.atlassian.com/cloud/confluence/rest/v2/intro/) — API v2 as the primary surface, v1 only where v2 has no equivalent (CQL search, label writes, attachment upload/download, single-user lookups).

- Explicit `Noizu.Confluence.Client` config (Basic auth or OAuth 2.0 3LO) — no global state
- `{:ok, map()}` / `{:error, %Noizu.Confluence.Error{}}` returns, typespecs throughout
- Cursor pagination with lazy `*_stream/2` variants
- Automatic `version.number` increment on page/blog-post/property updates
- 429 retry honoring `Retry-After`, bounded attempts
- Test suite runs entirely against `Req.Test` plugs — no live network

The coverage contract (auth, endpoints, pagination, body formats, error model, rate limits, non-goals) is documented in [docs/API-CONTRACT.md](docs/API-CONTRACT.md).

## Installation

```elixir
def deps do
  [
    {:noizu_confluence, "~> 0.1"}
  ]
end
```

## Quickstart

```elixir
client =
  Noizu.Confluence.Client.new(
    auth_mode: :basic,
    site: "example.atlassian.net",
    email: "user@example.com",
    api_token: System.fetch_env!("CONFLUENCE_API_TOKEN")
  )

{:ok, space} =
  Noizu.Confluence.Spaces.create(client, %{"name" => "Engineering", "key" => "ENG"})

{:ok, page} =
  Noizu.Confluence.Pages.create(client, %{
    "spaceId" => space["id"],
    "status" => "current",
    "title" => "Hello",
    "body" => %{"representation" => "storage", "value" => "<p>Hello</p>"}
  })

# version.number fetched and incremented automatically
{:ok, page} = Noizu.Confluence.Pages.update(client, page["id"], %{"title" => "Hello v2"})

{:ok, results} = Noizu.Confluence.Search.cql(client, "type=page AND space=ENG")

Noizu.Confluence.Pages.list_stream(client, params: %{limit: 5})
|> Stream.map(& &1["id"])
|> Enum.take(10)
```

OAuth 2.0 (3LO) calls go to `api.atlassian.com/ex/confluence/<cloudId>/wiki`:

```elixir
client =
  Noizu.Confluence.Client.new(
    auth_mode: :oauth,
    cloud_id: "a436116f-02ce-4620-840b-f5dd8d3f7861",
    access_token: System.fetch_env!("ATLASSIAN_ACCESS_TOKEN")
  )
```

## Modules

| Module | Purpose |
|---|---|
| `Noizu.Confluence.Client` | auth modes, base URLs, request pipeline, 429 retry |
| `Noizu.Confluence.Error` | decoded error struct (v2 + v1 shapes) |
| `Noizu.Confluence.Pagination` | cursor/`_links.next`/`Link` header machinery |
| `Noizu.Confluence.Spaces` | spaces (v2) |
| `Noizu.Confluence.Pages` | pages CRUD, children, versions, by-space (v2) |
| `Noizu.Confluence.BlogPosts` | blog posts CRUD, by-space (v2) |
| `Noizu.Confluence.Comments` | footer + inline comments (v2) |
| `Noizu.Confluence.Attachments` | list/get/delete (v2), upload/download (v1 multipart) |
| `Noizu.Confluence.Labels` | list (v2), add/remove (v1) |
| `Noizu.Confluence.Properties` | content properties for pages/blog posts/spaces (v2) |
| `Noizu.Confluence.Search` | CQL search (v1) |
| `Noizu.Confluence.Users` | current user / get by account id (v1) |

## License

MIT — see [LICENSE](LICENSE).
