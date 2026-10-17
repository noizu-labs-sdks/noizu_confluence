# Threat Model — `noizu_confluence`

<!-- 〚📁:𓉙𔍤𔅉𓶗〛 docs/THREAT-MODEL.md :: STRIDE threat model: credential handling, pagination host-pinning analysis, upload temp files, CQL surface, supply chain; vulnerability register T-001..T-010. -->

Version: 0.2.0 · Date: 2026-10-17 (rev. 1 — security hardening)
Method: STRIDE over the trust boundaries implied by [PROJ-ARCH.md](PROJ-ARCH.md);
every claim verified against the code on `develop` at `e97981a`; mitigation
status re-verified against the `fix/security-hardening` branch (tests named in
the register).

## Overview

`noizu_confluence` is a **client-side library** with no listening services, no
daemon, and no storage: its security posture is entirely about (1) holding the
caller's Atlassian credentials in memory, (2) deciding which hosts those
credentials are sent to, and (3) how much of a server response is trusted as
input (pagination continuations, error bodies).

**Crown jewels:** the API token / OAuth bearer carried in the `Client` struct,
and the Confluence content the credential can read or write. The library is
embedded into a host application that is **trusted** (it supplies config and
often credentials); Atlassian's API is **semi-trusted** — its responses drive
pagination; the local machine, the network path, and Hex dependencies are
**hostile by default**.

## Trust Boundaries

```mermaid
graph LR
    APP[Embedding application] -->|"Client struct (holds credentials)"| LIB[noizu_confluence]
    LIB -->|"HTTPS + Authorization<br/>(basic or bearer)"| ATL[Atlassian API<br/>site.atlassian.net / api.atlassian.com]
    ATL -->|"200 body: _links.next<br/>Link header, error bodies"| LIB
    LIB -->|"multipart upload<br/>(temp file in System.tmp_dir!)"| FS[(Local filesystem)]
    HEX[Hex deps: req, jason] --> LIB
    LOG[Host app logs / crash dumps] -.may capture.- LIB
```

Four boundaries: **app ↔ library** (trusted config, but see T-002/T-004 for
untrusted values flowing through), **library ↔ Atlassian** (responses are
attacker-influenceable input when the workspace or a proxy is compromised),
**library ↔ local filesystem** (temp files during upload), and
**library ↔ logs/REPL** (credential serialization). Network interception is
out of scope for the library itself: both base URLs are hard-pinned `https://`
and transport is Req/Finch with system CA trust.

## Attack Surface

- `Client.new/1` — credential intake (basic: `site`/`email`/`api_token`;
  OAuth: `cloud_id`/`access_token`); base-URL construction.
- `Client.request/4` / `request_full/4` — the only egress path; auth header
  attached to **every** request, anchored to the pinned `base_url`.
- `Pagination.next_path/2` — trusts `_links.next` (body) and the `Link`
  response header as *input* for the next request URL.
- `Search.cql/3` — caller CQL string passed verbatim.
- All resource modules — ids and attrs interpolated into request paths/bodies.
- `Attachments.upload/4` — multipart body materialized via local temp files.
- `Error.from_response/2` — provider error bodies decoded into a raisable
  exception (surfaces in host logs).

## Vulnerability Register

| ID | Severity | STRIDE | Component | Finding | Status |
|----|----------|--------|-----------|---------|--------|
| T-001 | **Medium** | Info disclosure | `Client` struct | No custom `Inspect`: `inspect(client)` / crash dumps render `api_token` / `access_token` in cleartext — leaks into host logs, REPL history, error reports | **Mitigated** — custom `Inspect` impl on `Client` renders each token as a 4-char prefix + redaction marker (email kept); `ArgumentError` messages interpolate only option labels. Tests: `ClientTest` "inspect/1 never renders the api_token in basic auth mode" / "inspect/1 never renders the access_token in oauth mode" / "ArgumentError messages never interpolate credential values" |
| T-002 | **Medium** | Info disclosure / Tampering | `Attachments.upload/4` | `{:data, filename, _}` — `filename` is interpolated into the temp path unvalidated (`Path.join(tmp, "noizu-confluence-upload-" <> rand <> "-" <> filename)`); a name containing `/` or `..` writes caller content **outside the tmp dir**. Benign when the embedder controls the name; dangerous when an embedder forwards user-supplied filenames (a common web-app pattern) | **Mitigated** — temp name = `Path.basename/1` + random component; empty/`.`/`..`/NUL names rejected as `{:error, %Error{code: "invalid_filename"}}`; the original name still travels as the multipart filename. Test: `AttachmentsTest` "upload/4 with a traversal filename writes only inside tmp_dir and keeps the original multipart filename (T-002)" + "rejects empty, dot, dot-dot and NUL-containing filenames" |
| T-003 | Low | Info disclosure | `Attachments.upload/4` | Temp files are written with default permissions (0644) into a shared `System.tmp_dir!`; upload content is readable by other local users until removed (`try/after` does delete on normal paths) | **Mitigated** — temp file created `:exclusive` and chmod'd 0600 **before** any content is written; cleanup stays in `try/after` (now also covering the write itself). Test: `AttachmentsTest` "upload/4 materializes the temp file with owner-only 0600 permissions (T-003)" |
| T-004 | Low | Tampering | Resource modules | Path/id parameters (page ids, attachment ids, label names via `?name=`) are `to_string`-interpolated **without URI encoding**; a crafted id can inject extra path segments or a query string. Requests stay on the pinned host with the same privileges, so impact is endpoint confusion / unintended operations within the token's authority | **Mitigated** — every path id goes through `Noizu.Confluence.Uri.path_segment/1` (percent-escapes `/ ? # % .` and all reserved chars → exactly one opaque segment; `?name=` values already URI-encoded by `Query.encode/1`). Tests: `UriTest` "path_segment/1 encodes a crafted id into a single segment (T-004)" (plus dot-dot / %-smuggling cases), `PagesTest` "get/3 encodes a crafted page id into a single path segment (T-004)" |
| T-005 | Low | Tampering | `Search.cql/3` | CQL is a query language and is passed verbatim (the correct library behavior); embedders who build CQL by string concatenation from user input face **CQL logic injection** (tainted searches within the token's permissions). The library ships no CQL escaping helper | **Accepted (library scope)** — embedder responsibility; the `Search` moduledoc carries an explicit warning against interpolating untrusted input (added 2026-10-17) |
| T-006 | Low | Info disclosure | `Client.new/1` | Basic-auth credentials follow caller-configured `site` verbatim: an attacker able to influence the `site` option receives `email:api_token` in the Authorization header to their own HTTPS host. Config is trusted, so this requires config-injection in the host app | **Accepted** (trusted config); an `*.atlassian.net` allowlist option would close it |
| T-007 | Low | Tampering | `Pagination` | A compromised/median response controls continuation: it can keep `_links.next` alive indefinitely (**unbounded crawl** — rate-limit burn, content exfil at crawl speed) or steer arbitrary paths/queries **on the legitimate host** | **Accepted** — bounded only by stream termination; see Mitigations |
| T-008 | Low | DoS | `Client` retry loop | Attacker-supplied `Retry-After` can stall a request, but is parsed strictly (non-negative integer) and capped at 30 s, with ≤ `max_retries` (3) retries — worst case ~90 s + 4 requests per operation | **Mitigated** — negative and garbage values fall back to the bounded exponential backoff; only huge positives clamp at 30 s. Tests: `ClientTest` "a negative Retry-After falls back to the bounded backoff, never a negative or huge sleep" / "a garbage Retry-After falls back to the bounded backoff" / "a huge Retry-After is clamped to 30 seconds" (injected-sleep assertions) |
| T-009 | Low | Tampering (supply chain) | Dependencies / CI | No CI exists (no `.github/`), so no automated `mix hex.audit` / dependency-advisory step; runtime surface is small (`req ~> 0.7` → finch/mint/hpax/nimble_*, `jason ~> 1.4`; plug test-only; ex_doc dev-only) and locked in `mix.lock` for development, but consumers resolve their own versions | **Mitigated** — `.github/workflows/ci.yml` added (push + PR × develop/stage/main): matrix lowest-supported-by-the-lock (Elixir 1.15 / OTP 26; the locked mint→hpax 1.1 tree needs ~> 1.15, matching the declared `~> 1.15` mix.exs floor) + current (1.18 / OTP 27), `mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix test`, `mix hex.audit`, deps/_build cached |
| T-010 | Low | Tampering | OAuth base URL | `cloud_id` is interpolated into the path of the **pinned** `https://api.atlassian.com` base; a malformed `cloud_id` can at worst confuse the path on the same Atlassian host (bearer remains Atlassian-scoped) | **Mitigated by design** |

## Explicit finding: pagination cannot redirect the auth header cross-host

**T-question: can a malicious response send the client and its Authorization
header to another host? No.** The mechanics, verified in
`lib/noizu/confluence/pagination.ex` and `client.ex`:

1. `Pagination.next_path/2` takes `_links.next` from the body (preferred) or
   the `Link: <...>; rel="next"` header (fallback).
2. `normalize_path/1` → `from_absolute/1` parses absolute URLs and keeps
   **only `path` + `query`** — scheme and host are **discarded**; relative
   paths skip this step.
3. Every request, including every continuation, is built with
   `base_url: client.base_url` (`build_request/4`), and `Req` resolves the URL
   against that base — the auth header (`{:basic, email:token}` or
   `{:bearer, token}`) is attached to that same request object. There is no
   code path that adopts a response-supplied origin.

So a hostile `_links.next` such as `https://evil.example/collect?a=b` degrades
to the path `/collect?a=b` served by the **configured** Atlassian host
(T-007's same-host steering) — the credential never leaves the pinned origin.

## Mitigation Coverage

- **By design (host pinning):** T-007 (cross-host leg), T-008 (bounded retry),
  T-010 (OAuth path) — all requests anchored to `base_url` from client config;
  only 429 retried; `Retry-After` strictly parsed and capped.
- **By hygiene:** the library never logs (`Logger` absent from `lib/`), and
  its own `inspect/1` uses in `ArgumentError` messages render only option
  **labels**, never credential values; error structs carry status/code/message
  and provider bodies, never request headers.
- **Closed by the 2026-10-17 hardening (evidence = named tests in the
  register):** T-001 (custom redacting `Inspect` on `Client`), T-002 (basename
  + random temp name; empty/`.`/`..`/NUL rejected), T-003 (0600 `:exclusive`
  temp files), T-004 (`Noizu.Confluence.Uri.path_segment/1` on every path id),
  T-009 (CI with `mix hex.audit`).
- **Remaining accepted:** T-005 (documented embedder responsibility),
  T-006 (trusted `site` config), T-007 (same-host pagination steering).
  Owner: noizu-labs-sdks/noizu_confluence maintainers.

## Residual Risk

- **Trusted-config assumption (T-005, T-006):** the library treats `site`,
  `cloud_id`, and CQL as trusted caller input. A host app that forwards these
  from untrusted sources without validation owns the consequences.
- **Semi-trusted API responses (T-007):** a compromised Atlassian workspace
  or TLS-terminating proxy can prolong crawls and pick same-host paths; it
  cannot escalate privileges (the token already bounds them) or move the
  credential off-origin.
- **Local artifacts (T-003):** 0600-only temp files exist briefly during
  `{:data, ...}` uploads (owner-readable only, content written only after the
  mode is set); residue only on unclean VM shutdown.
- **Supply chain (T-009):** trust in Hex-published `req`/`jason` versions
  resolved by consumers; no pinning enforcement beyond `mix.lock` (dev-only).

→ *Grounding: components in [PROJ-ARCH.md](PROJ-ARCH.md), file map in
[PROJ-LAYOUT.md](PROJ-LAYOUT.md), endpoint facts in
[API-CONTRACT.md](API-CONTRACT.md).*
