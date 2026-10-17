# Project Architecture — Summary

Digest of [PROJ-ARCH.md](PROJ-ARCH.md) for quick reference.

- **Shape**: stateless Elixir HTTP client library for Confluence Cloud REST
  API v2 (v1 only for CQL search, label writes, attachment upload/download,
  single-user lookups). No processes, no app env, no global config.
- **Client**: immutable `Noizu.Confluence.Client` struct built by `new/1`,
  passed explicitly to every call. Basic auth → `https://<site>/wiki`;
  OAuth 3LO → `https://api.atlassian.com/ex/confluence/<cloudId>/wiki`.
  Missing credentials raise `ArgumentError`.
- **Pipeline**: `Client.request/4` → Req (retry disabled in Req; auth header
  from auth mode; caller `req_opts` merged). Only 429 is retried
  automatically: `Retry-After` honored, exponential fallback, 30 s cap,
  ≤ `max_retries` (default 3) retries, injectable sleep. 2xx →
  `{:ok, body}`; anything else → `{:error, %Noizu.Confluence.Error{}}`.
- **Query encoding**: custom (not Req's) — list values become repeated bare
  keys (`ids=1&ids=2`), `expand` comma-joined, `nil` dropped, deterministic
  sorted percent-encoded output.
- **Pagination**: cursor-based; next page from body `_links.next`
  (Link-header fallback), normalized to a path under the client base
  (absolute origin + `/wiki` stripped). `*_stream/2` variants lazily
  flat-map items; mid-stream failures raise.
- **Errors**: exception struct decoding both v2 (`errors[]`) and v1
  (`statusCode/message/data`) shapes; non-JSON bodies truncated into
  `message`.
- **Optimistic locking**: `Pages`/`BlogPosts`/`Properties` updates
  auto-fetch the current `version.number` and +1 when `"version"` is
  omitted.
- **Responses**: plain maps (provider payloads verbatim); content bodies
  (XHTML/ADF/wiki) pass through unmodified.
- **Stack**: Elixir ~> 1.15, Req ~> 0.7 (Finch/Mint, `:form_multipart`),
  Jason; test-only Plug. Tests are fully offline (`Req.Test` plugs).
- **Docs of record**: `docs/API-CONTRACT.md` (endpoint coverage, updated
  before code), `docs/THREAT-MODEL.md` (security posture).
