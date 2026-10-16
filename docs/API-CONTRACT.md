# Confluence Cloud REST API — Client Contract (`noizu_confluence`)

Version: 0.1.0 · Date: 2026-10-17
Scope: Elixir client library for the **Confluence Cloud** REST API, published as
`noizu_confluence` (github.com/noizu-labs/noizu_confluence).

This document is the coverage contract between the library and
[Atlassian's Confluence Cloud REST API](https://developer.atlassian.com/cloud/confluence/rest/v2/intro/).
Endpoint facts below were verified against the official v2/v1 OpenAPI specs
(`developer.atlassian.com/cloud/confluence/openapi-v2.v3.json`,
`openapi-v1.v3.json` → `swagger.v3.json`) and the Atlassian auth/rate-limit guides —
not from memory. When Atlassian evolves the API, update this file first, then the code.

---

## 1. Authentication

Two modes, selected per client instance via `Noizu.Confluence.Client.new/1`. No global
state; the client struct is passed explicitly to every call.

### 1.1 Basic auth (email + API token)

- Base URL: `https://<site>.atlassian.net/wiki` (e.g. site `"example"` →
  `https://example.atlassian.net/wiki`). Atlassian: username is the **Atlassian account
  email**, password is an **API token** created at `https://id.atlassian.com/manage/api-tokens`;
  header is `Authorization: Basic base64(email:token)`. Confluence never issues an auth
  challenge, so the header is always sent up front.
- All v1 and v2 endpoints are reachable under this base (`/wiki/api/v2/...`, `/wiki/rest/api/...`).

### 1.2 OAuth 2.0 (3LO) bearer

- Base URL: `https://api.atlassian.com/ex/confluence/<cloudId>/wiki`. OAuth calls go to
  `api.atlassian.com`, never to the site domain; `cloudId` comes from
  `GET https://api.atlassian.com/oauth/token/accessible-resources` (out of scope for this
  library — the caller supplies the id and a live access token).
- Header: `Authorization: Bearer <access token>`.
- Scope note (informational): v2 endpoints use granular scopes
  (`read:page:confluence`, `write:page:confluence`, `read:space:confluence`,
  `read:comment:confluence`, `read:attachment:confluence`, ...); v1 endpoints use classic
  scopes (`read:confluence-content`, `search:confluence`, ...). Token acquisition/refresh
  is NOT covered (§8).

---

## 2. API versions — v2 primary, v1 only for gaps

**v2 (`/wiki/api/v2/...`) is the primary surface.** v1 (`/wiki/rest/api/...`) is used
**only** where v2 has no equivalent. Atlassian has begun removing deprecated v1
endpoints (e.g. `GET /rest/api/space` now returns `410`), so every v1 dependency here is
deliberate and listed:

| Capability | Endpoint | Version | Why v1 |
|---|---|---|---|
| CQL search | `GET /rest/api/search` | v1 | Task contract; v2 search coverage is newer/partial and the v1 endpoint remains the CQL workhorse (`cql`, `cursor`, `limit`, `start`, `next`, `prev`, `includeArchivedSpaces`, `excludeCurrentSpaces`, `cqlcontext`, `excerpt`). User-specific CQL fields are unsupported by Atlassian — use `GET /rest/api/search/user`. |
| Label add/remove | `POST /rest/api/content/{id}/label`, `DELETE /rest/api/content/{id}/label?name=` | v1 | v2 label endpoints are **GET-only** (verified in the v2 spec); v2 cannot write labels. Body: `{prefix, name}` or array of them. |
| Attachment upload | `POST /rest/api/content/{id}/child/attachment` | v1 | v2 has no upload. `multipart/form-data` with `file` + `minorEdit` (both required per spec, `comment` optional) and header `X-Atlassian-Token: no-check`. |
| Attachment download | `GET /rest/api/content/{id}/child/attachment/{attachmentId}/download` | v1 | v2 only offers thumbnail download (`GET /api/v2/attachments/{id}/thumbnail/download`). |
| Users (current/get) | `GET /rest/api/user/current`, `GET /rest/api/user?accountId=` | v1 | v2 spec exposes only `/users-bulk` (admin); no single-user get/current. |

Everything else in §3 is v2.

---

## 3. Resources and endpoints covered

Path prefix `<base>` = the auth-mode base URL from §1 (ends in `/wiki`).

### 3.1 Spaces (`Noizu.Confluence.Spaces`) — v2

| Function | Endpoint | Notes |
|---|---|---|
| `list/2` + `list_stream/2` | `GET /api/v2/spaces` | Query: `ids`, `keys`, `type`, `status`, `labels`, `sort`, `cursor`, `limit` |
| `get/2` | `GET /api/v2/spaces/{id}` | |
| `create/2` | `POST /api/v2/spaces` | Body (spec): required `name`; optional `key`, `alias`, `description`, `createPrivateSpace`, ... |

### 3.2 Pages (`Noizu.Confluence.Pages`) — v2

| Function | Endpoint | Notes |
|---|---|---|
| `list/2` + `list_stream/2` | `GET /api/v2/pages` | |
| `get/2` | `GET /api/v2/pages/{id}` | Response carries `version.number` |
| `create/2` | `POST /api/v2/pages` | Body: required `spaceId` (+ `title`, `body`, `status`; `parentId` for nesting) |
| `update/3` (+`/4`) | `PUT /api/v2/pages/{id}` | Body: required `id`, `status`, `title`, `body`, `version.number` = **current + 1**. The client auto-fetches the current version and increments when `version` is not supplied (§6) |
| `delete/2` | `DELETE /api/v2/pages/{id}` | |
| `children/2` + `children_stream/2` | `GET /api/v2/pages/{id}/children` | Query: `cursor`, `limit`, `sort` |
| `versions/2` + `versions_stream/2` | `GET /api/v2/pages/{id}/versions` | |
| `list_for_space/2` + `list_for_space_stream/2` | `GET /api/v2/spaces/{id}/pages` | |

### 3.3 Blog posts (`Noizu.Confluence.BlogPosts`) — v2

| Function | Endpoint | Notes |
|---|---|---|
| `list/2` + `list_stream/2` | `GET /api/v2/blogposts` | |
| `get/2` | `GET /api/v2/blogposts/{id}` | |
| `create/2` | `POST /api/v2/blogposts` | Body: required `spaceId` (+ `title`, `body`, `status`, `createdAt`) |
| `update/3` (+`/4`) | `PUT /api/v2/blogposts/{id}` | Body: required `id`, `status`, `title`, `body`, `version.number` = current + 1 (same auto-increment helper as pages) |
| `delete/2` | `DELETE /api/v2/blogposts/{id}` | |
| `list_for_space/2` + stream | `GET /api/v2/spaces/{id}/blogposts` | |

### 3.4 Comments (`Noizu.Confluence.Comments`) — v2

Footer comments (page-bottom):

| Function | Endpoint |
|---|---|
| `list_footer/2` + stream | `GET /api/v2/footer-comments` |
| `get_footer/2` | `GET /api/v2/footer-comments/{comment-id}` |
| `create_footer/2` | `POST /api/v2/footer-comments` — body: exactly one of `pageId` / `blogPostId` / `attachmentId` / `customContentId`, optional `parentCommentId`, `body` |
| `update_footer/3` | `PUT /api/v2/footer-comments/{comment-id}` |
| `delete_footer/2` | `DELETE /api/v2/footer-comments/{comment-id}` |
| `footer_children/2` | `GET /api/v2/footer-comments/{id}/children` |
| `list_footer_for_page/2` | `GET /api/v2/pages/{id}/footer-comments` |
| `list_footer_for_blogpost/2` | `GET /api/v2/blogposts/{id}/footer-comments` |

Inline comments — the same nine operations under `/api/v2/inline-comments` and
`/api/v2/pages/{id}/inline-comments`, `/api/v2/blogposts/{id}/inline-comments`
(`list_inline`, `get_inline`, `create_inline` — create body adds `inlineCommentProperties` —,
`update_inline`, `delete_inline`, `inline_children`, `list_inline_for_page`,
`list_inline_for_blogpost`).

### 3.5 Attachments (`Noizu.Confluence.Attachments`) — v2 + v1

| Function | Endpoint | Version |
|---|---|---|
| `list/2` + `list_stream/2` | `GET /api/v2/attachments` | v2 |
| `get/2` | `GET /api/v2/attachments/{id}` | v2 |
| `delete/2` | `DELETE /api/v2/attachments/{id}` | v2 |
| `list_for_page/2`, `list_for_blogpost/2` + streams | `GET /api/v2/pages/{id}/attachments`, `GET /api/v2/blogposts/{id}/attachments` | v2 |
| `upload/4` | `POST /rest/api/content/{containerId}/child/attachment` | v1, multipart + `X-Atlassian-Token: no-check` |
| `download/3` | `GET /rest/api/content/{containerId}/child/attachment/{attachmentId}/download` | v1, returns binary |

### 3.6 Labels (`Noizu.Confluence.Labels`) — v2 read, v1 write

| Function | Endpoint | Version |
|---|---|---|
| `list_for_page/2`, `list_for_blogpost/2`, `list_for_space/2` + streams | `GET /api/v2/pages/{id}/labels`, `GET /api/v2/blogposts/{id}/labels`, `GET /api/v2/spaces/{id}/labels` | v2 |
| `add/3` | `POST /rest/api/content/{id}/label` | v1 — body `{prefix, name}` or array; bare label strings are wrapped with `prefix: "global"` |
| `remove/3` | `DELETE /rest/api/content/{id}/label?name=` | v1 |

`add`/`remove` accept the v2 numeric id of the page/blog post as `{id}` (v1 and v2 share
content ids).

### 3.7 Content properties (`Noizu.Confluence.Properties`) — v2

Uniform five operations for `:page`, `:blogpost`, `:space` parents:

| Function | Endpoint pattern |
|---|---|
| `list/4` + `list_stream/4` | `GET /api/v2/{pages\|blogposts\|spaces}/{id}/properties` |
| `create/4` | `POST ...` — body: `key`, `value` |
| `get/4` | `GET /api/v2/{...}/{id}/properties/{property-id}` |
| `update/5` | `PUT /api/v2/{...}/{id}/properties/{property-id}` — body: `key`, `value`, `version.number` (auto-bumped when omitted, same helper as pages) |
| `delete/4` | `DELETE /api/v2/{...}/{id}/properties/{property-id}` |

### 3.8 Search (`Noizu.Confluence.Search`) — v1

| Function | Endpoint | Notes |
|---|---|---|
| `cql/3` | `GET /rest/api/search` | `cql` required; opts forwarded as query params (`cursor`, `limit`, `start`, `next`, `prev`, ...) |
| `cql_stream/3` | same | Follows `_links.next` / `Link` header cursors |

### 3.9 Users (`Noizu.Confluence.Users`) — v1

| Function | Endpoint |
|---|---|
| `current/2` | `GET /rest/api/user/current` |
| `get/3` | `GET /rest/api/user?accountId={accountId}` |

---

## 4. Pagination

Confluence paginates with **cursor** pagination: request params `limit` + `cursor`; the
next page is advertised both in the `Link` response header (`</path?cursor=...>; rel="next"`)
and in the body as `_links.next`; **both are absent on the last page**. `_links.next` is a
relative path (typically starting `/wiki/...`); the client normalizes it against the
auth-mode base URL (strips any absolute origin and the leading `/wiki` segment, which the
base URL already carries).

Client contract:

- List operations return `{:ok, body_map}` where `body_map` is the raw response map
  (contains `"results"` and `"_links"`). Responses are plain maps — no struct casting.
- Every paginated operation has a `*_stream/2` variant returning a lazy `Stream` that
  **follows `_links.next`** (falling back to the `Link` header when the body lacks it) and
  yields result items one by one. An error mid-stream raises `%Noizu.Confluence.Error{}`.
- v1 search uses the same cursor convention (`cursor` param + `_links.next`), so the same
  stream machinery serves both versions.

### 4.1 Query-parameter encoding

The client encodes the `:params` map itself (Req would render list values Plug-style,
`key[]=v`, which Atlassian does not define):

- List values become **repeated bare keys** — `ids=1&ids=2`, `space-id=10&space-id=20`,
  `keys=ENG&keys=OPS` — matching the v2 OpenAPI spec's `style=form, explode=true` on every
  array parameter (`ids`, `keys`, `space-id`, `labels`, `status`, `id`, `page-id`,
  `blogpost-id`, `label-id`, `prefix`, ...).
- `expand` is the one `explode=false` exception (v1): **comma-joined** —
  `expand=version,space`.
- `nil` values are dropped; booleans render `true`/`false`; output is percent-encoded and
  deterministic (pairs sorted by key, same-key pairs keep list order).

## 5. Body formats

Page/blog/comment/property bodies are written as
`%{"body" => %{"representation" => rep, "value" => value}}` with `rep` one of the spec
enum `"storage"` | `"atlas_doc_format"` | `"wiki"`:

- **`storage`** — XHTML storage format (legacy default; what `GET` returns under
  `body.storage`).
- **`atlas_doc_format`** — Atlassian Document Format (ADF), the JSON document format used
  by the editor (what this library recommends for new content).

The library passes `body` values through verbatim — it does not generate or convert
XHTML/ADF (see §8). Page updates additionally carry
`%{"version" => %{"number" => current + 1, "message" => optional}}`.

## 6. Optimistic locking (version.number)

`PUT /api/v2/pages/{id}` and `PUT /api/v2/blogposts/{id}` require
`version.number = current + 1`. Per the spec: "Set this to the current version number
plus one... If you don't know the current version number, use Get page by id."

The client implements the spec's recommendation: `update/3` accepts an attrs map without
`version`, fetches the entity (`GET .../{id}`), and sends `version.number = fetched + 1`
(one extra request). Callers who track versions locally can pass
`attrs["version"] = %{"number" => n}` to skip the fetch. The same helper backs
`Properties.update/5` (property `version.number` = current + 1).

## 7. Errors, retries, rate limits

### 7.1 Error model

All failures return `{:error, %Noizu.Confluence.Error{}}`; raising is never used for
request failures (mid-stream errors aside, §4).

```elixir
%Noizu.Confluence.Error{
  status: 404,              # HTTP status (integer, or nil for transport errors)
  code: "NOT_FOUND",        # v2 error `code` / v1 semantic code, when present
  message: "Not Found",     # v2 error `title`/`detail`, or v1 `message`
  errors: [...]             # raw error list/map from the provider (v2 `errors` array,
                            # v1 `data`/`developerResponse`, or the undecoded body)
}
```

Both provider shapes are decoded: v2 `{"errors": [{"status", "code", "title", "detail"}]}`
(first entry feeds `code`/`message`, the full list is kept in `errors`) and v1
`{"statusCode", "message", "data"}`. Non-JSON bodies (HTML error pages) keep a truncated
body in `message`. `Noizu.Confluence.Error` is an exception, so `raise err` works.

### 7.2 Rate limits and retries

Atlassian returns **429 Too Many Requests** when a limit is hit, with **`Retry-After` in
seconds** (only on 429; some 5xx may also include it), plus `X-RateLimit-Limit`,
`X-RateLimit-Remaining`, `X-RateLimit-Reset` (ISO 8601), `X-RateLimit-NearLimit`, and
`RateLimit-Reason`. Limits are per app/token, with a shared hourly quota and separate
burst windows.

Client behavior (bounded, per Atlassian's recommendation of "at most 4 retries,
30-second max delay"):

- Only **429** triggers automatic retry (5xx/transport errors surface as `{:error, ...}`
  — the caller decides, keeping the failure surface honest).
- Delay = `Retry-After` seconds when present; otherwise exponential backoff
  1s, 2s, 4s... capped at 30s.
- At most `max_retries` retries (default 3) after the initial attempt (≤ 4 requests).
  The sleep function is injectable (`:retry_sleep` on the client) for tests; exhaustion
  returns the last 429 as `{:error, %Error{}}`.

### 7.3 Timeouts and transport

HTTP is `Req` (Finch pool); request options (`receive_timeout`, `finch`, `plug`, ...) can
be injected per client via `:req_opts` — this is also the test seam (`Req.Test` plug
stubs; the test suite performs **no live network calls and holds no real tokens**).

## 8. Intentionally NOT covered

- **Token/credential lifecycle** — OAuth token issuance, refresh, and
  `accessible-resources` discovery; API-token creation. Callers bring a live token.
- **Content format tooling** — generating/converting XHTML storage or ADF documents.
- **v1 endpoints Atlassian deprecates or has removed** (e.g. `GET /rest/api/space` →
  410) — spaces work via v2 only.
- Space update/delete (v2 exposes none), page title-only update
  (`PUT /api/v2/pages/{id}/title`), classification levels, likes, permissions, operations,
  restrictions, workflows, themes, long-running tasks, audit, analytics, group/user
  administration, bulk user endpoints, whiteboards/databases/custom-content/embeds,
  space properties beyond the uniform property CRUD (v2 `space-properties` extras),
  `GET /rest/api/search/user` (exposed via `Search.cql` options only if Atlassian's
  generic `cql` call covers it — no dedicated wrapper).
- Attachment thumbnail download (v2) — full download via v1 only (§3.5).
- Webhooks, Confluence mobile, content trees/move/copy (v1).
