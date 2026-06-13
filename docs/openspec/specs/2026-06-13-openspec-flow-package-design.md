# OpenSpec flow package — design spec

**Date:** 2026-06-13 · **Status:** implemented (v1.0.0) · **Author:** brainstormed with the human partner

## Problem

After `aif` and `superpowers`, add a third MAIster flow package wrapping
[OpenSpec](https://github.com/Fission-AI/OpenSpec) (`@fission-ai/openspec`,
"AI-native system for spec-driven development"), analogous in shape but adapted
to OpenSpec's different integration model.

OpenSpec is **not** a skills library. It is a CLI (`openspec …`) + an in-project
`openspec/` spec base + slash-commands/skills that `openspec init` scaffolds
into the consuming project. Its workflow is **Propose → Apply → Archive**. Two
mismatches with MAIster must be solved:

1. **No vendorable skills bundle** — the logic lives in the CLI and in what
   `init` scaffolds. What does the package vendor, and how do nodes invoke
   OpenSpec?
2. **OpenSpec is interactive and assumes a global binary** — its scaffolded
   commands/skills use `AskUserQuestion` and call bare `openspec`; MAIster is
   non-interactive and owns the worktree + promotion.

## Verified facts (from the installed `@fission-ai/openspec@1.4.1`)

- Non-interactive CLI surface: `init --tools claude --force`, `update --force`,
  `new change <name>`, `status --change <n> --json`, `instructions <artifact>
  --change <n> --json`, `validate --changes/--specs --strict --no-interactive`,
  `archive -y`, `list --json`.
- `openspec init --tools claude` scaffolds `.claude/commands/opsx/*` **and**
  `.claude/skills/openspec-*/SKILL.md` + `openspec/config.yaml` into the
  project. **But** those internally call the **bare `openspec`** binary and use
  `AskUserQuestion` — so they don't work under a no-global, non-interactive run.
- `openspec instructions <artifact> --json` returns `template` / `rules` /
  `context` / `resolvedOutputPath` — the CLI-native way to drive artifact
  creation without the slash commands.

## Approaches considered

- **A. Host-global `openspec` + use the scaffolded skills/commands.** Simplest
  invocation, but undocumented host dependency, unpinned version, and the
  scaffolded skills still assume interactivity.
- **B. npx-pinned CLI, prompt-driven (CHOSEN).** Nodes call
  `npx -y @fission-ai/openspec@1.4.1 …` directly (version pinned, no global),
  driving `new change`/`status`/`instructions`/`validate`/`archive`. The
  scaffolded slash commands/skills are **not** used (they'd call bare
  `openspec`); they are vendored as **reference** only.

The human partner chose **B (npx-pin)** + **reference docs in `capability/`** +
**4 flows**.

## Design

Package `packages/openspec/`:

```
maister-package.yaml   name: openspec; flows[4]; capabilities[openspec-reference → capability]; mcps:[]
setup.sh               inert no-op
README.md              quick-start
flows/{dev,propose,apply,init}/flow.yaml
capability/reference/  schema-spec-driven/ (schema + templates) · claude-skills/ · claude-commands-opsx/ · openspec-config.yaml · LICENSE.openspec · README.md
```

**Reference-only bundle:** `capability/` has no `skills/`/`agents/` subtree, so
MAIster materializes nothing — it is pure provenance (the OpenSpec schema +
templates + the skills/commands `init` would scaffold + the version target).

**Flows** (see [`docs/openspec/README.md`](../README.md) for node graphs):
`os-dev` (2 HITL: proposal approval before code + final review before archive),
`os-propose` (1 HITL, proposal-only, terminal gates on `propose`), `os-apply`
(1 HITL, build an existing change → archive), `os-init` (1 HITL, one-time
`openspec init`). `os-dev` covers features and fixes — everything is a *change*,
so no separate bug flow.

**Drive model:** every node calls `npx -y @fission-ai/openspec@1.4.1 …`. Propose
runs `new change` → loop(`status` → `instructions <artifact>` → write to
`resolvedOutputPath`) → `validate`. Apply runs `instructions apply` → read
`contextFiles` → implement `tasks.md`. Archive runs `archive -y` → fold deltas
→ `validate --specs`.

**Reconciliation (inlined contract per node):** invoke OpenSpec only via the
npx pin (never bare `openspec`, never `/opsx:*`/`openspec-*`); never use
`AskUserQuestion` (auto-select the single active change, derive names,
best-judgment, corrections via HITL rework comments); MAIster owns
git/worktree/promotion (no branch/merge/push/PR; commit locally); spec-driven
schema only (STOP on workspace-planning mode).

### Decisions log

1. OpenSpec CLI runtime: **npx-pinned** `@fission-ai/openspec@1.4.1` (pin lives
   in the flow prompts; recorded in `metadata.sources`).
2. Package shape: flows + **reference-only** `capability/reference/` bundle.
3. Flow set: **4** (`os-dev`, `os-propose`, `os-apply`, `os-init`).
4. HITL: `os-dev` = 2 (proposal approval, final review); others = 1.
5. Drive via `openspec instructions`/`validate`/`archive` (CLI-guaranteed); the
   scaffolded slash commands/skills are reference only.
6. Package tag `openspec/v1.0.0`; OpenSpec CLI `1.4.1`.

## Risks & follow-ups

- **npx network/cache dependency.** First CLI call per host fetches OpenSpec;
  needs Node + network (cached afterward under `~/.npm/_npx`). Offline hosts
  must pre-warm or use a global install. Documented in the package README.
- **OpenSpec version drift.** The pin `1.4.1` is hard-coded across ~12 prompt
  call sites; bump in lockstep when upgrading. A first-class "vendored component
  version" field across packages remains a future idea.
- **`planning home` assumption.** `must_touch: [openspec/**]` assumes OpenSpec's
  default planning home; a project that relocates it would need the glob
  adjusted.
- **Live behaviour unproven.** The CLI surface is verified, but a full
  `os-dev` run (propose→apply→archive) has not been executed end-to-end in a
  MAIster session — recommended spike before external use.

## Verification done

- All four `flow.yaml` `name`s equal their `maister-package.yaml flows[].id`
  (`os-dev`/`os-propose`/`os-apply`/`os-init`), validated by the real MAIster
  loaders (`loadFlowManifest` + `loadMaisterPackageManifest`, engine 1.4.0).
- Every templated var exists at its node (`task.prompt` everywhere; `commentsVar`s
  only on rework targets — strict-mode safe).
- Artifact/gate/rework wiring mirrors the proven `aif`/`superpowers` packages.

## Revision — hybrid `cli`/`ai_coding` + platform `requirements` (2026-06-13, same day)

The v1 design above (npx-pin, all-`ai_coding`, reference-only) shipped first.
On review with the human partner it was superseded the same day. Two insights:

1. **`cli`/`check` nodes run commands directly** (MAIster runner, `bash -c`, host
   PATH) with **no agent and no permission HITL** — verified in
   `web/lib/flows/runner-cli.ts`. The permission concern only ever applied to
   `ai_coding` nodes (the agent's own gated tool calls / file writes). So the
   deterministic OpenSpec CLI calls belong in `cli`/`check` nodes, not the agent.
2. **MAIster gained a `requirements` launch precondition** (ADR-091, built in the
   MAIster repo alongside this package): per-flow shell probes run before any
   worktree/session, refusing launch with a clean `PRECONDITION` if a dependency
   (here, the `openspec` CLI) is absent.

Superseding decisions (replace v1 items 1, 2, 5):
- **CLI invocation:** bare `openspec` (not npx-pin). Installed by `setup.sh` and
  the `os-init` `ensure` cli node (`command -v openspec || npm i -g
  @fission-ai/openspec@1.4.1`). The version pin lives in those two install sites,
  not ~12 prompt sites.
- **Node split (hybrid):** `cli`/`check` for deterministic OpenSpec CLI
  (`verify` = `openspec validate`; `archive` = `archive -y && validate &&
  commit`; `os-init` `ensure` + `commit`). `ai_coding` only for content/impl
  (`propose`, `apply`, `fix`, `code_review`), each with
  `settings.permissionMode: allow` so the agent's writes + CLI calls run
  unattended (HITL stays at the review gates).
- **`requirements`:** `os-dev`/`os-propose`/`os-apply` require `openspec`
  present; `os-init` requires only `npm` (it installs the CLI) — hence per-flow,
  not package-wide (a package-wide rule would block the installer flow).

This resolves the v1 "npx network/cache" risk (now a one-time `npm i -g`) and the
"version drift across ~12 sites" risk (now 2 install sites). The
`planning-home` and "full `os-dev` live run unproven" follow-ups still stand;
the platform-permission question (does an `ai_coding` node's writes stall
without `permissionMode: allow`?) is the one residual live unknown — verified to
be bypassed by `permissionMode: allow` per `agent-map.ts`, but the SDK's honoring
of `bypassPermissions` is unverified live (ADR-044) → spike before relying on
unattended runs.

Platform feature built alongside (MAIster repo): **ADR-091** — `flow.yaml`
`requirements: [{ name, probe, hint? }]` + a launch precondition probe
(`web/lib/flows/requirements-check.ts`) wired into `launchRun` before
`addWorktree`. Additive, no engine floor, check-only (never auto-installs).
