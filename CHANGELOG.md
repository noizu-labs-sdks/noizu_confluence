# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

- Changed: repository moved to the `noizu-labs-sdks` GitHub org —
  `@source_url`/`homepage_url` and the hex package `links` (and doc prose)
  now point at `github.com/noizu-labs-sdks/noizu_confluence`.
- Changed: minimum supported Elixir raised from `~> 1.14` to `~> 1.15`. The
  locked dependency tree (mint 1.11 -> hpax 1.1) already requires Elixir
  1.15 and CI's lowest matrix entry (1.15/OTP 26) was already testing it;
  the declared `mix.exs` floor now matches what is actually tested.
- Security: `Noizu.Confluence.Client` has a custom `Inspect` impl — `api_token`
  and `access_token` render as a 4-character prefix + redaction marker, never
  in full (threat model T-001); exception messages interpolate only option
  labels.
- Security: `Attachments.upload/4` `{:data, filename, binary}` derives the
  temp-file name from `Path.basename/1` plus a random component, rejects
  empty/`.`/`..`/NUL names as `{:error, %Error{code: "invalid_filename"}}`, and
  keeps the original name as the multipart part filename (T-002).
- Security: upload temp files are created `:exclusive` and chmod'd `0600`
  before any content is written (T-003).
- Security: every resource id interpolated into a request path is URI-encoded
  through the new `Noizu.Confluence.Uri.path_segment/1`, so a crafted id stays
  a single opaque path segment (T-004); OAuth `cloud_id` is encoded the same
  way.
- Security/CI: added `.github/workflows/ci.yml` (push + PR on develop/stage/
  main) running format check, `mix compile --warnings-as-errors`, `mix test`,
  and `mix hex.audit` on Elixir 1.15/OTP 26 (lowest the locked dep tree
  compiles on, which the `mix.exs` floor now matches) and 1.18/OTP 27 (T-009).
- Security: confirmed (with injected-sleep tests) that 429 `Retry-After`
  values — negative, garbage, and huge — never sleep outside 0..30 s (T-008).
- Docs: `docs/THREAT-MODEL.md` rev. 1 — T-001..T-004, T-008, T-009 marked
  Mitigated with test evidence; `Search` moduledoc warns against
  interpolating untrusted input into CQL (T-005 stays accepted).
- Docs: added `docs/PROJ-LAYOUT.md`, `docs/PROJ-ARCH.md`, and
  `docs/THREAT-MODEL.md` (each with a `.summary.md` companion), plus
  doc-pointer declarations and the generated `.meta/pointers.yaml` store. The
  threat model covers credential handling, pagination host-pinning, upload
  temp files, the CQL surface, retry behavior, and supply chain.
- Removed stray `.formatter` (non-`.exs` duplicate of `.formatter.exs`) and
  dropped it from the `package/0` files list.

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
