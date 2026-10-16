# Project Layout — `noizu_confluence`

<!-- 〚📁:𓬡𔖡𓿓𓜞〛 docs/PROJ-LAYOUT.md :: Repository layout map: docs, lib modules, test tree, packaging files. -->

Navigable map of the repository. `noizu_confluence` is a single-purpose Elixir
Hex library: a Confluence Cloud REST API client (v2 primary, v1 for gaps). No
runtime application, no config files, no scripts — the entire surface is the
`lib/` tree, driven by explicit `Noizu.Confluence.Client` structs.

```
noizu_confluence/
├── docs/                                  # Project documentation
│   ├── API-CONTRACT.md                    # Coverage contract vs the Atlassian REST API (endpoint facts)
│   ├── PROJ-ARCH.md                       # Architecture: request pipeline, pagination, error model
│   ├── PROJ-LAYOUT.md                     # This file
│   ├── PROJ-LAYOUT.summary.md             # Companion quick-reference tree
│   └── THREAT-MODEL.md                    # Security review of the client surface
├── lib/noizu/
│   ├── confluence.ex                      # Top-level moduledoc: usage, auth modes, module map
│   └── confluence/                        # Library modules (one concern per file)
│       ├── client.ex                      # Client struct + request pipeline (auth header, 429 retry)
│       ├── pagination.ex                  # Cursor pagination (_links.next / Link header) + lazy streams
│       ├── query.ex                       # Query-param encoding (repeated bare keys; expand comma-joined)
│       ├── error.ex                       # %Noizu.Confluence.Error{} — decodes both provider error shapes
│       ├── spaces.ex                      # Spaces: list/get/create (v2)
│       ├── pages.ex                       # Pages: CRUD, children, versions, by-space (v2)
│       ├── blog_posts.ex                  # Blog posts: CRUD, by-space (v2)
│       ├── comments.ex                    # Footer + inline comments (v2)
│       ├── attachments.ex                 # Attachment metadata (v2); v1 multipart upload + download
│       ├── labels.ex                      # Label reads (v2); v1 add/remove
│       ├── properties.ex                  # Content properties CRUD for page/blogpost/space (v2)
│       ├── search.ex                      # CQL search (v1)
│       └── users.ex                       # Current/get user (v1)
├── test/
│   ├── noizu/confluence/                  # One ExUnit suite per module (12 files, 64 tests)
│   ├── support/support.ex                 # Req.Test client factories + canned response helpers
│   └── test_helper.exs                    # ExUnit bootstrap
├── .formatter.exs                         # `mix format` inputs
├── CHANGELOG.md                           # Keep-a-Changelog release log
├── LICENSE                                # MIT
├── README.md                              # Start here — install, quickstart, both auth modes
├── mix.exs                                # Project/deps/Hex package metadata
└── mix.lock                               # Locked dependency versions
```

## Docs

| File | Role |
|---|---|
| `docs/API-CONTRACT.md` | System of record for endpoint coverage — update this first when Atlassian's API evolves, then the code |
| `docs/PROJ-ARCH.md` | How the library works: pipeline, pagination normalization, version auto-increment |
| `docs/THREAT-MODEL.md` | Assets, trust boundaries, and findings for the client's security posture |
| `CHANGELOG.md` | Release history, Keep-a-Changelog format |

## Source conventions

- **One module per API resource**, each pairing plain `list/get/...` functions
  returning `{:ok, map()}` / `{:error, %Noizu.Confluence.Error{}}` with a
  `*_stream/2` variant built on `Noizu.Confluence.Pagination`.
- **No global state and no configuration file**: every credential lives in the
  client struct built by `Client.new/1` — nothing to set up in the repo.
- **Version auto-increment**: `Pages`, `BlogPosts`, and `Properties` updates
  share the same `ensure_version` helper (fetch current `version.number`, +1).

## Tests

The suite runs entirely against `Req.Test` plugs (see
`test/support/support.ex`) — no live network calls, no real tokens. The only
`mix` task needed locally is `mix test`.

## Not tracked (generated / local only)

| Path | What |
|---|---|
| `_build/`, `deps/` | Mix build + dependency checkouts (gitignored) |
| `doc/` | Generated `ex_doc` output (gitignored) |
| `noizu_confluence-*.tar` | `mix hex.build` artifact (gitignored) |

## Key files requiring setup

None. The library holds no environment files (`.envrc`, `.env.example`),
editor configs, or tool-version pins beyond `elixir: "~> 1.14"` in `mix.exs`;
credentials are supplied per call at runtime.
