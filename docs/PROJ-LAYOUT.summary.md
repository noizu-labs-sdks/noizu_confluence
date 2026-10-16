# Project Layout — Summary

Quick-reference tree for `noizu_confluence`. Descriptions abbreviated; full
notes in [PROJ-LAYOUT.md](PROJ-LAYOUT.md).

```
noizu_confluence/
├── docs/                     # API-CONTRACT, PROJ-ARCH, PROJ-LAYOUT, THREAT-MODEL
├── lib/noizu/
│   ├── confluence.ex         # Top-level moduledoc + module map
│   └── confluence/           # client, pagination, query, error +
│                             #   spaces, pages, blog_posts, comments,
│                             #   attachments, labels, properties,
│                             #   search (v1 CQL), users (v1)
├── test/
│   ├── noizu/confluence/     # 12 ExUnit suites (64 tests), Req.Test plugs only
│   └── support/support.ex    # Client factories + response helpers
├── .formatter.exs            # mix format inputs
├── CHANGELOG.md              # Keep-a-Changelog
├── LICENSE                   # MIT
├── README.md                 # Install + quickstart
├── mix.exs                   # Hex package metadata (req ~> 0.7, jason ~> 1.4)
└── mix.lock                  # Locked deps
```

Gitignored/generated (not tracked): `_build/`, `deps/`, `doc/` (ex_doc output),
`noizu_confluence-*.tar`. No environment or config files — credentials are
per-call client structs.
