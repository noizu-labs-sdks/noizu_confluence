# AGENT-README

> Orientation for AI coding agents working in this repo. Human docs: README.md (plus docs/API-CONTRACT.md — the exact coverage contract).

## Type

elixir-lib (Hex package, API client)

## Purpose

Elixir client for the Confluence Cloud REST API — v2 as the primary surface, v1 only where v2 has no equivalent (CQL search, label writes, attachment upload/download, single-user lookups).

## Stack

Elixir ~> 1.15. Deps: `req` (~> 0.7), `jason`; `plug` test-only. Explicit `Noizu.Confluence.Client` config (Basic auth or OAuth 2.0 3LO, no global state), cursor pagination with lazy `*_stream/2` variants, automatic `version.number` increment on page/blog-post/property updates.

## Dev mode

```bash
mix deps.get
mix test
```

## Ports / URLs

- none (library/CLI)

## Tests

```bash
mix test    # entirely against Req.Test plugs; no live network
```

## Gotchas

- Env vars per README quickstart: `CONFLUENCE_API_TOKEN` (Basic auth, with site + email) or `ATLASSIAN_ACCESS_TOKEN` (OAuth 2.0 3LO, with `cloud_id` — calls go to `api.atlassian.com/ex/confluence/<cloudId>/wiki`).
- 429s auto-retry honoring `Retry-After` (bounded attempts); everything else returns `{:error, %Noizu.Confluence.Error{}}`.
