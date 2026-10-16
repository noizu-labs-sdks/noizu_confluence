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
  design-mitigated items.

| ID | Sev | Finding | Status |
|----|-----|---------|--------|
| T-001 | Medium | Client struct prints `api_token`/`access_token` via default `Inspect` (logs/crash dumps) | Open |
| T-002 | Medium | `Attachments.upload {:data, filename, _}`: unvalidated filename → temp-path traversal write when embedders forward user input | Open |
| T-003 | Low | Upload temp files 0644 in shared tmp dir | Open |
| T-004 | Low | Path/id params interpolated unencoded — same-host path/query injection | Open |
| T-005 | Low | CQL passed verbatim; CQL logic injection is an embedder risk, no escaping helper | Accepted (library scope) |
| T-006 | Low | Attacker-influenced `site` config receives Basic credentials (trusted config assumed) | Accepted |
| T-007 | Low | Malicious continuation can steer same-host paths / prolong crawls | Accepted |
| T-008 | Low | Retry-After stalls bounded: strict parse, 30 s cap, ≤3 retries | Mitigated |
| T-009 | Low | No CI / no `mix hex.audit`; small dep tree, lockfile dev-only | Open |
| T-010 | Low | `cloud_id` in pinned api.atlassian.com path — same-host confusion only | Mitigated by design |

- **Boundaries**: app ↔ library (trusted config), library ↔ Atlassian
  (responses are input), library ↔ local FS (upload temp files), library ↔
  logs (credential serialization). HTTPS pinned on both base URLs.
- **Top fixes owed**: redact secrets from `Inspect` (T-001); sanitize upload
  `filename` (T-002); URI-encode path segments (T-004); add CI with
  `mix hex.audit` (T-009).
