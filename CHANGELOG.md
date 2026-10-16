# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0 - 2026-10-17

Initial release.

- `Noizu.Confluence.Client` — explicit config struct, Basic auth
  (`https://<site>.atlassian.net/wiki`) and OAuth 2.0 3LO bearer
  (`https://api.atlassian.com/ex/confluence/<cloudId>/wiki`), 429 retry
  honoring `Retry-After` with bounded attempts and injectable sleep.
- Resources: spaces, pages (CRUD, children, versions, by-space), blog posts
  (CRUD, by-space), footer + inline comments, attachments (v2 metadata; v1
  multipart upload with `X-Atlassian-Token: no-check` + v1 download), labels
  (v2 read, v1 add/remove), content properties (pages/blog posts/spaces),
  CQL search (v1), users current/get (v1).
- Cursor pagination (`_links.next` with `Link` header fallback) plus lazy
  `*_stream/2` helpers.
- Automatic `version.number` increment for page/blog-post/property updates.
- Require `{:req, "~> 0.7"}` — attachment upload uses `:form_multipart`, added in Req 0.7.
- Query params are encoded by the client: list values become repeated bare keys
  (`ids=1&ids=2`, `space-id=10&space-id=20`) per the specs' `explode: true`,
  `expand` comma-joined (`explode: false`); Req's `key[]=` form is never sent.
- Contract-first coverage doc: `docs/API-CONTRACT.md`.
