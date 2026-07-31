# maister-plugins

Package monorepo for [MAIster](https://github.com/albertkanischev/maister):
each package is a self-contained distribution unit carrying everything its
flows or agents need to function — flow graphs, skills, agents, and MCP server
templates.

## Layout

```
packages/
  <name>/
    maister-package.yaml     # package manifest (flows, capability bundles, mcps)
    flows/<flow-id>/flow.yaml
    capability/…             # skills/ + agents/ bundles
    maister-agents/…         # optional platform-agent definitions
    README.md                # provenance + package-specific notes
```

| Package | Contents |
| ------- | -------- |
| [`aif`](packages/aif/) | AI Factory workflows: 5 flows (`aif-dev`, `aif-bugfix`, `aif-evolve`, `aif-roadmap`, `aif-init`) + vendored skills/agents bundle. |
| [`superpowers`](packages/superpowers/) | [obra/superpowers](https://github.com/obra/superpowers) methodology: 4 flows (`sp-dev`, `sp-debug`, `sp-plan`, `sp-execute`) + full vendored superpowers skills bundle. |
| [`openspec`](packages/openspec/) | [Fission-AI/OpenSpec](https://github.com/Fission-AI/OpenSpec) spec-driven workflow: 4 flows (`os-dev`, `os-propose`, `os-apply`, `os-init`) driving the `openspec` CLI (installed by `setup.sh` / `os-init`); hybrid `cli`+`ai_coding` nodes, `requirements` launch precondition. Reference-only bundle. |
| [`core`](packages/core/) | First-party platform agents for task triage, Project Brain improvement, and experiment evaluation, plus shared MAIster skills. |
| [`core-java`](packages/core-java/) | Java and JVM skills for builds, architecture, integration testing, performance analysis, and production diagnostics. |
| [`core-react`](packages/core-react/) | React and TypeScript frontend skills for components, state and data flow, accessibility, testing, and performance. |
| [`core-pg`](packages/core-pg/) | PostgreSQL skills for schema design, migrations, query tuning, indexing, transactions, reliability, and operations. |
| [`core-skill-authoring`](packages/core-skill-authoring/) | Skill-authoring skills for designing, structuring, validating, testing, and maintaining reusable MAIster agent skills. |
| [`env-e2e`](packages/env-e2e/) | Ephemeral docker-compose env + Playwright e2e as readiness evidence: 1 flow (`env-e2e`) whose `check` node owns up→seed→test→capture→down atomically (engine ≥ 3.3.0, `MAISTER_FLOW_DIR`); red suites drive a bounded fix loop, exhaustion escalates to a human — never auto-ship. |

## Documentation

Per-package reference docs and design specs live under [`docs/`](docs/):

- [`docs/aif/`](docs/aif/) — AIF package reference.
- [`docs/superpowers/`](docs/superpowers/) — Superpowers package reference +
  the design spec (`specs/`).
- [`docs/openspec/`](docs/openspec/) — OpenSpec package reference + the design
  spec (`specs/`).

## Versioning

Per-package git tags: **`<name>/vX.Y.Z`** (e.g. `aif/v2.5.0`). The tag is the
user-facing pin; MAIster resolves it to a commit SHA at install time and the
SHA is runtime truth (content-addressed cache, immutable revisions). A
package release tags only its own name — packages version independently.

## Consuming from MAIster

- **Target shape** (MAIster package management, P1+): one `packages[]` entry
  in the project's `maister.yaml` —
  `{ id: aif, source: <this repo URL>, version: aif/v2.5.0, path: packages/aif }` —
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

## Releasing a package

Create package tags through the release wrapper so the compatibility gate runs
against the exact clean checkout before a tag exists:

```sh
MAISTER_REPO=/path/to/mAIster ./scripts/release-package.sh aif v2.6.0
```

The gate validates the package manifest, graph-only `nodes[]` manifests,
compilation, engine range, package-root schema materialization, and a real
Postgres-backed package install. MAIster engine changes run the same gate over
every discoverable `<package>/vX.Y.Z` tag in this repository.
