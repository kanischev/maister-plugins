# Spec Kit Flow package

The **[GitHub Spec Kit](https://github.com/github/spec-kit) spec-driven
workflow for MAIster**. Wraps Spec Kit's SDLC
(**constitution → specify → clarify → plan → tasks → analyze → implement**) as
MAIster flows that drive the `specify` CLI and the `/speckit-*` Claude skills.

Versioned by per-package git tags: `spec-kit/vX.Y.Z`. The **Spec Kit version is
pinned to `github/spec-kit@v0.10.3`** in `setup.sh` and the `sk-init` flow's
installer.

## Provenance

- **Framework**: Spec Kit — https://github.com/github/spec-kit (MIT). The
  `specify` CLI is installed at runtime; `specify init` scaffolds Spec Kit's
  `.specify/` base + the `.claude/skills/speckit-*` skills into the project.
  `capability/reference/` documents the phases + the SKILL.md frontmatter as
  read-only provenance (see `capability/reference/README.md`).

## Flows

| flow id   | HITL | route_when |
| --------- | ---- | ---------- |
| `sk-dev`  | 2    | Build a feature end-to-end: specify → **clarify** → plan → tasks → analyze → implement → code_review → **review** → commit. |
| `sk-init` | 1    | One-time: install the `specify` CLI + scaffold Spec Kit + author the project constitution. Run + promote this first. |

`sk-dev` covers the full recommended Spec Kit SDLC in one flow.

## How Spec Kit is driven (hybrid: `cli` + `ai_coding`)

Spec Kit's phases exist **only** as Claude skills (there is no headless CLI for
specify/plan/tasks/…), so unlike a CLI-first tool the creative phases must run
through the agent. The flows split work by node type:

- **`cli` / `check` nodes** run deterministically (MAIster's runner, `bash -c`,
  host PATH — no agent, no permission HITL): `sk-init`'s `ensure` (install
  `specify`) + `scaffold` (`specify init`) + `commit`; `sk-dev`'s existence
  backstops (`spec-gate` / `plan-gate` / `tasks-gate`), the task-completion
  `verify`, the `clarify-extract` marker dump, and the final `commit`.
- **`ai_coding` nodes** invoke the `/speckit-*` skills (by their **hyphen**
  name: `/speckit-specify`, `/speckit-plan`, …) wherever an agent must reason or
  write: `specify`, `clarify-apply`, `plan`, `tasks`, `analyze`, `implement`,
  `code-review`. They carry `settings.permissionMode: allow`, so the agent runs
  unattended — HITL lives at the two human gates (clarify, review).

## The `specify` CLI must be present (and how it gets there)

- **`requirements` (ADR-091).** `sk-dev` declares launch preconditions —
  `command -v specify`, `test -d .specify`, `test -d .claude/skills/speckit-specify`
  — probed **before** any worktree/session; launch is refused (clean
  `PRECONDITION`) if Spec Kit is absent or unscaffolded. `sk-init` requires only
  `uv|pipx` + `git` (it installs `specify` and scaffolds).
- **Install + scaffold.** `sk-init` runs
  `command -v specify || uv tool install … spec-kit.git@v0.10.3` then
  `specify init --here --force --integration claude --ignore-agent-tools`
  (fully non-interactive, bundled assets, no network). `setup.sh` does the same
  install at package-install time (exec-trust gated).
- **Sequencing.** Run `sk-init` once per project **and promote it** so
  `.specify/` + `.claude/skills/speckit-*` are committed on the base branch;
  `sk-dev` worktrees fork from there and load `/speckit-*` at session start.

## MAIster ↔ Spec Kit reconciliation (in node prompts)

- **Non-interactive.** Spec Kit's `specify`/`clarify` ask the user clarifying
  questions; `AskUserQuestion` is disabled in the adapter. `sk-dev` agent nodes
  instead record open questions as `[NEEDS CLARIFICATION: …]` spec markers and
  proceed on best-judgment assumptions; the authored **clarify** human node
  surfaces them and feeds the maintainer's answers into `/speckit-clarify`.
- **Git/promotion owned by MAIster.** The flows never install Spec Kit's opt-in
  `git` extension (so `/speckit-specify` only `mkdir`s the `specs/` dir — never
  `git checkout`/`branch`), and the prompts forbid branch/merge/push/PR. Spec +
  code are committed by the terminal `cli` node; MAIster promotes the branch.
- **CRITICAL blocks implement.** `/speckit-analyze` is read-only (writes no
  file), so the `analyze` node resolves CRITICAL cross-artifact inconsistencies
  at source and a **blocking `ai_judgment`** gate enforces "zero CRITICAL
  remaining" before `implement`.

## Policies & gates

- Runner `claude-code` (`claude` / `claude-opus-4-8` / `anthropic`);
  `compat.engine_min: 1.4.0`; `defaults.session_policy: resume`; `retry_policy`
  on every `ai_coding` node; `verdict_calibration.confidence_min: 0.7` on `sk-dev`.
- Gates: existence backstops (`check` nodes) after specify/plan/tasks;
  `analyze` → blocking `ai_judgment` (no CRITICAL); `verify` → `check`
  task-completion (no unchecked `- [ ]`); `review` →
  `artifact_required(impl-diff)` blocking + `ai_judgment` advisory; terminal
  commits → `artifact_required must_touch` (mutation_report) + clean-tree
  `command_check`.

## Requirements

`uv` (or `pipx`) + Python 3.11+ and `git` on the supervisor/web host (`cli`
nodes run on the web tier, the `ai_coding` Bash on the supervisor — co-located
by default). `specify init` needs **no** network (assets are bundled in the
pinned wheel); the one-time CLI install does.

## Out of scope (today)

- The `codex` runner (Spec Kit's codex integration differs from the Claude
  skills surface this package targets).
- `/speckit-checklist` and `/speckit-taskstoissues` (GitHub issues), and
  spec-only / implement-only flow splits — future additions.
- Dynamic multiple-choice clarification surfaced from the agent (needs core
  MAIster HITL work); the clarify node collects free-text answers.

## Reference-only capability bundle

`capability/` has no `skills/`/`agents/` subtree, so MAIster materializes
nothing from it — it carries Spec Kit provenance only (see
`capability/reference/README.md`).
