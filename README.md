# maister-plugins

Package monorepo for [MAIster](https://github.com/albertkanischev/maister):
each package is a self-contained distribution unit carrying everything its
flows need to function — flow graphs, skills, agents, MCP server templates.

## Layout

```
packages/
  <name>/
    maister-package.yaml     # package manifest (flows, capability bundles, mcps)
    flows/<flow-id>/flow.yaml
    capability/…             # skills/ + agents/ bundles
    README.md                # provenance + package-specific notes
```

| Package | Contents |
| ------- | -------- |
| [`aif`](packages/aif/) | AI Factory workflows: 5 flows (`aif-dev`, `aif-bugfix`, `aif-evolve`, `aif-roadmap`, `aif-init`) + vendored skills/agents bundle. |
| [`superpowers`](packages/superpowers/) | [obra/superpowers](https://github.com/obra/superpowers) methodology: 4 flows (`sp-dev`, `sp-debug`, `sp-plan`, `sp-execute`) + full vendored superpowers skills bundle. |

(`core` — platform agents: task triager/router, GitHub intake — is planned
and not yet created.)

## Documentation

Per-package reference docs and design specs live under [`docs/`](docs/):

- [`docs/aif/`](docs/aif/) — AIF package reference.
- [`docs/superpowers/`](docs/superpowers/) — Superpowers package reference +
  the design spec (`specs/`).

## Versioning

Per-package git tags: **`<name>/vX.Y.Z`** (e.g. `aif/v2.0.0`). The tag is the
user-facing pin; MAIster resolves it to a commit SHA at install time and the
SHA is runtime truth (content-addressed cache, immutable revisions). A
package release tags only its own name — packages version independently.

## Consuming from MAIster

- **Target shape** (MAIster package management, P1+): one `packages[]` entry
  in the project's `maister.yaml` —
  `{ id: aif, source: <this repo URL>, version: aif/v2.0.0, path: packages/aif }` —
  or, with the platform catalog (P2), add this repo as a package source in
  `/settings` and install/attach from the UI.
- **Until then**: per-flow wiring — five `flows[]` entries pointing at
  `file:///…/maister-plugins/packages/aif/flows/<id>` plus one
  `capability_imports[]` entry for `packages/aif/capability`, all
  `version: local-dev`.

Design reference: `docs/pv/package-management.md` in the MAIster repo.

## Contributing changes

Two channels:

1. **Repo-as-project**: register this repo as a normal MAIster project and
   ship package changes through tasks → runs → promotion (`pull_request`).
2. **Studio propose-upstream** (planned): fork an installed package in
   MAIster Flow Studio, edit, and propose the change as a PR from the UI.

Local iteration without publishing: point a MAIster project at a local
checkout (`file://` source / local package version) and run flows against it.
