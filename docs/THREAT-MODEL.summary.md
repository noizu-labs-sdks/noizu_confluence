# Threat Model — Summary

Digest of [THREAT-MODEL.md](THREAT-MODEL.md) for quick reference.

- **Posture**: client-side library — no listeners, no storage. Crown jewels:
  the Atlassian credential in the `Client` struct and the content it can
  reach. Host app trusted; Atlassian responses semi-trusted; network, local
  FS, and Hex deps hostile by default.
- **Headline answer**: pagination following (`_links.next` / `Link` header)
  **cannot redirect the Authorization header to another host** — continuation
  origins are discarded and every request is anchored to the pinned
  `client.base_url`.
- **Register**: 10 findings — 0 Critical/High, 2 Medium, 7 Low, plus
  design-mitigated items. **Rev. 1 (2026-10-17 hardening): T-001..T-004 and
  T-009 mitigated** (evidence = tests named in [THREAT-MODEL.md](THREAT-MODEL.md)).

| ID | Sev | Finding | Status |
|----|-----|---------|--------|
| T-001 | Medium | Client struct prints `api_token`/`access_token` via default `Inspect` (logs/crash dumps) | Mitigated — custom `Inspect` renders 4-char prefix only |
| T-002 | Medium | `Attachments.upload {:data, filename, _}`: unvalidated filename → temp-path traversal write when embedders forward user input | Mitigated — `Path.basename/1` + random temp name; empty/`.`/`..`/NUL rejected |
| T-003 | Low | Upload temp files 0644 in shared tmp dir | Mitigated — `:exclusive` create + chmod 0600 before content is written |
| T-004 | Low | Path/id params interpolated unencoded — same-host path/query injection | Mitigated — `Noizu.Confluence.Uri.path_segment/1` on every path id |
| T-005 | Low | CQL passed verbatim; CQL logic injection is an embedder risk, no escaping helper | Accepted (library scope) — `Search` moduledoc warns against untrusted interpolation |
| T-006 | Low | Attacker-influenced `site` config receives Basic credentials (trusted config assumed) | Accepted |
| T-007 | Low | Malicious continuation can steer same-host paths / prolong crawls | Accepted |
| T-008 | Low | Retry-After stalls bounded: strict parse, 30 s cap, ≤3 retries | Mitigated — negative/garbage fall back to bounded backoff (tested) |
| T-009 | Low | No CI / no `mix hex.audit`; small dep tree, lockfile dev-only | Mitigated — `.github/workflows/ci.yml` (1.14/OTP 25 + 1.18/OTP 27, format/compile/test/`mix hex.audit`) |
| T-010 | Low | `cloud_id` in pinned api.atlassian.com path — same-host confusion only | Mitigated by design (+ path-encoded like every id) |

- **Boundaries**: app ↔ library (trusted config), library ↔ Atlassian
  (responses are input), library ↔ local FS (upload temp files), library ↔
  logs (credential serialization). HTTPS pinned on both base URLs.
- **Remaining accepted risks**: T-005 (CQL is embedder responsibility),
  T-006 (trusted `site` config), T-007 (same-host pagination steering,
  bounded by stream termination).
