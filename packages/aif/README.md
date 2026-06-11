# AIF Flow package

The **AI Factory (AIF) flow package for MAIster**. A self-contained plugin
that wraps the [AI Factory](https://github.com/lee-to/ai-factory/tree/2.x)
agent workflows (plan, implement, review, fix, evolve, roadmap, init) as
MAIster flows backed by a shared skills + subagents bundle.

This package is self-contained; nothing here imports from MAIster core.
Versioned by per-package git tags: `aif/vX.Y.Z` (see the repo root README).

## Provenance

- **Extracted from the MAIster repo** (`plugins/aif` @ `maister@c104f66b`,
  2026-06-12); history prior to extraction lives there.
- **Framework**: AI Factory `2.x` —
  https://github.com/lee-to/ai-factory/tree/2.x
  (Apache-2.0). Its skills and subagents are vendored under `capability/`.
- **Dev workflow**:
  https://github.com/lee-to/ai-factory/blob/2.x/docs/workflow.md
- **Config reference**:
  https://github.com/lee-to/ai-factory/blob/2.x/docs/configuration.md

## Flows

Five flows ship with this package, each routed by what the incoming task is.

| flow id       | route_when                                                                                    |
| ------------- | --------------------------------------------------------------------------------------------- |
| `aif-dev`     | A feature / enhancement / refactor with a clear spec (plan → review → implement → review → fix). |
| `aif-bugfix`  | A reported bug / error / regression to fix (`/aif-fix` loop; emits a self-improvement patch).  |
| `aif-evolve`  | Periodic maintenance: distill accumulated fix-patches into better skills (not feature work).   |
| `aif-roadmap` | A large / multi-milestone initiative needing a roadmap before planning.                         |
| `aif-init`    | One-time: project not yet AIF-initialized (`/aif` + `/aif-architecture`).                       |

Flow sources live under `flows/<id>/flow.yaml`.

## Package layout

| Path                          | Purpose                                                                 |
| ----------------------------- | ----------------------------------------------------------------------- |
| `capability/`                 | Shared bundle — vendored AIF skills (`skills/`) + subagents (`agents/`). |
| `flows/<id>/flow.yaml`        | The 5 flow sources listed above.                                        |
| `config/ai-factory.config.yaml` | Default `.ai-factory/config.yaml` template for a consuming project.    |
| `setup.sh`                    | Inert no-op (see below).                                                |

## What changed in `aif/v2.0.0`

Engine-feature bump applied at extraction (vs the `local-dev` package that
shipped inside the MAIster repo):

- `compat.engine_min: 1.4.0` on all five flows.
- Explicit `defaults: { session_policy: resume }` (M30/ADR-081).
- `retry_policy` on every `ai_coding` node — auto-retry of infra failures
  (`SPAWN`, `EXECUTOR_UNAVAILABLE`, `CHECKPOINT`, `ACP_PROTOCOL`), workspace
  rewound to the pre-attempt checkpoint (M30/ADR-080).
- Review→fix rework loops (`aif-dev`, `aif-bugfix`) offer the reviewer
  `workspacePolicies: [keep, rewind-to-node-checkpoint]` (M30/ADR-079).
- File-edit gates (M29/ADR-074) on the `commit` node of the meta-flows:
  `aif-evolve` / `aif-init` must touch `.ai-factory/**` or `.claude/**`,
  `aif-roadmap` must touch `.ai-factory/**` — blocking `artifact_required`
  gates with `must_touch` + a recorded `mutation_report` artifact. The gate
  sits on the commit node because AIF defers all committing to `/aif-commit`
  (mutation ranges are committed-only).
- `maister-package.yaml` added — the package manifest for MAIster package
  management (single-import). `must_not_touch` protection zones are
  deliberately deferred to `aif/v2.1.0`: they need restriction capability
  records, which packages can ship only once MAIster typed ingestion lands.

## How MAIster consumes it

A consuming project's `maister.yaml` registers this package twice over:

- **One shared `capability_imports` bundle** pointing at `capability/`.
  All five flows reuse the same vendored skills + subagents instead of each
  carrying their own copy. MAIster materializes these into the workspace
  (per ADR-043) — there is no `ai-factory init` and no npm install.
- **Five `flows[]` sources**, one per `flows/<id>/flow.yaml` above. Each flow
  resolves its steps against the shared capability bundle.

If a project has no `.ai-factory/config.yaml`, it receives
`config/ai-factory.config.yaml` as the default. The MAIster-compat overrides
in that template matter most for `git`: `git.create_branches: false` —
**MAIster owns the worktree and branch**, so AIF must not create its own.

Interactivity (questions, approvals, review gates) is delivered by
**MAIster-native HITL** (form / permission steps), not the AIF
`AskUserQuestion` tool.

> **Run the `aif-init` flow first** if the project has no
> `.ai-factory/DESCRIPTION.md`. The other flows assume an initialized AIF
> project (description + architecture present).

## setup.sh

`setup.sh` is an **inert no-op**: it prints a one-line notice to stderr and
exits `0`. MAIster delivers AIF skills through capability materialization, so
there is nothing to install at flow-setup time.
