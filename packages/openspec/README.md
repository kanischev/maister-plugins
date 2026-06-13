# OpenSpec Flow package

The **[OpenSpec](https://github.com/Fission-AI/OpenSpec) spec-driven workflow
for MAIster**. Wraps Fission-AI's OpenSpec loop (**Propose → Apply → Archive**)
as MAIster flows that drive the `openspec` CLI.

Versioned by per-package git tags: `openspec/vX.Y.Z`. The **OpenSpec CLI version
is pinned to `@fission-ai/openspec@1.4.1`** in `setup.sh` and the `os-init`
flow's installer.

## Provenance

- **Framework**: OpenSpec — https://github.com/Fission-AI/OpenSpec (MIT). The
  CLI is invoked at runtime; `capability/reference/` vendors OpenSpec's schema +
  artifact templates and the claude skills/commands `openspec init` scaffolds,
  as **read-only provenance** (see `capability/reference/README.md`).

## Flows

| flow id      | HITL | route_when |
| ------------ | ---- | ---------- |
| `os-dev`     | 2    | Build a change end-to-end: propose → **proposal review** → apply → verify → code review → **review** → archive. |
| `os-propose` | 1    | Produce + review an OpenSpec change proposal only (no implementation). |
| `os-apply`   | 1    | Implement an already-approved change → verify → review → archive. |
| `os-init`    | 1    | One-time: ensure the CLI + scaffold OpenSpec into the project. Run this first. |

`os-dev` covers features and fixes — in OpenSpec everything is a *change*.

## How OpenSpec is driven (hybrid: `cli` + `ai_coding`)

OpenSpec is a CLI + an in-project `openspec/` base, not a vendored skills
library. The flows split work by node type so deterministic CLI calls never hit
the agent permission path:

- **`cli` / `check` nodes** run the OpenSpec CLI **directly** (MAIster's runner,
  `bash -c`, host PATH — no agent, no permission HITL): `verify`
  (`openspec validate`), `archive` (`openspec archive -y && validate && commit`),
  and `os-init`'s `ensure` (install) + `commit`.
- **`ai_coding` nodes** are used only where an agent must *write*: `propose`
  (author proposal/design/tasks + spec deltas), `apply`/`fix` (implement task
  code), `code_review`. These call the `openspec` CLI directly too, and carry
  `settings.permissionMode: allow` so the agent's edits + CLI calls run
  unattended — HITL then lives only at the review gates (MAIster's intended
  model).
- The flows use the **bare `openspec` binary** (not the `/opsx:*` slash commands
  or `openspec-*` skills, which assume interactivity and a global install). The
  real CLI sequence: `new change` → `status --json` → `instructions <artifact>
  --json` (write the returned template to its `resolvedOutputPath`) →
  `validate --strict` → `archive -y`.

## The `openspec` CLI must be present (and how it gets there)

- **`requirements` (ADR-091).** `os-dev` / `os-propose` / `os-apply` declare a
  launch precondition `requirements: [{ name: "openspec CLI present", probe:
  "command -v openspec", hint: … }]` — MAIster probes it **before** any
  worktree/session and refuses launch (clean `PRECONDITION`) if the CLI is
  absent. `os-init` requires only `npm` (it installs the CLI).
- **Install.** `os-init`'s first `cli` node runs
  `command -v openspec || npm i -g @fission-ai/openspec@1.4.1` (self-healing).
  `setup.sh` does the same and may run at package-install time (exec-trust
  gated). So: **run `os-init` once per project**, or install the CLI on the host;
  then the other flows' requirement probe passes.

## MAIster ↔ OpenSpec reconciliation (in node prompts)

- **Non-interactive.** OpenSpec's workflow assumes `AskUserQuestion`/`TodoWrite`
  and prompts for change selection; `AskUserQuestion` is disabled in the
  adapter. Prompts auto-select the single active change, derive change names, and
  make best-judgment calls; corrections arrive via the HITL review gates. All CLI
  calls use `--json` / `--no-interactive` / `-y` / `--force`.
- **Git/promotion owned by MAIster.** No worktree/branch creation, no
  merge/push/PR; commit locally only. Archive folds spec deltas into
  `openspec/specs/` and commits — MAIster promotes the branch.
- **spec-driven schema only.** If `status` reports
  `actionContext.mode: "workspace-planning"`, nodes STOP (out of scope).

## Policies & gates

- Runner `claude-code` (`claude` / `claude-opus-4-8` / `anthropic`);
  `compat.engine_min: 1.4.0`; `defaults.session_policy: resume`; `retry_policy`
  on every `ai_coding` node; `verdict_calibration.confidence_min: 0.7` on
  `os-dev`/`os-apply`.
- Gates: `propose` → `command_check` `openspec validate --strict` (blocking);
  `verify` → `check` node `openspec validate`; `review` →
  `artifact_required(impl-diff)` blocking + `ai_judgment` advisory; terminal
  (`archive` / `os-init` `commit` / `os-propose` `propose`) → `artifact_required`
  `must_touch [openspec/**]` (mutation_report) + clean-tree `command_check`.

## Requirements

Node.js + `npm` on the supervisor/web host (the `cli` nodes run on the web
tier, the `ai_coding` Bash on the supervisor — co-located by default). Network
egress for the one-time `npm i -g`.

## Reference-only capability bundle

`capability/` has no `skills/`/`agents/` subtree, so MAIster materializes
nothing from it — it carries OpenSpec provenance only (see
`capability/reference/README.md`).
