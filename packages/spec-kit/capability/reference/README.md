# Spec Kit reference bundle (provenance — NOT materialized)

This bundle is **reference-only**. It is declared as the package's capability
(`spec-kit-reference`) so Spec Kit provenance travels with the package, but it
contains **no `skills/` or `agents/` subtree**, so MAIster's capability
materializer copies nothing into the session worktree. The flows drive Spec Kit
through its `specify` CLI + the `/speckit-*` skills that `specify init`
scaffolds **into the project** (installed by `setup.sh` / the `sk-init` flow).

Targets `github/spec-kit@v0.10.3` (MIT).

## The phases (and which `/speckit-*` skill each flow node invokes)

Spec Kit's SDLC is a sequence of Claude skills. Under Claude the integration is
**skills-based**: `specify init --integration claude` writes
`.claude/skills/speckit-<name>/SKILL.md`, invoked by the **hyphen** name
`/speckit-<name>` (NOT the dotted `/speckit.<name>` the README still shows).

| phase | skill (hyphen) | writes |
| ----- | -------------- | ------ |
| Constitution | `/speckit-constitution` | `.specify/memory/constitution.md` |
| Specify | `/speckit-specify` | `specs/NNN-<slug>/spec.md`, `…/checklists/requirements.md` |
| Clarify | `/speckit-clarify` | updates `spec.md` (`## Clarifications`) |
| Plan | `/speckit-plan` | `plan.md` + `research.md`, `data-model.md`, `contracts/`, `quickstart.md` |
| Tasks | `/speckit-tasks` | `tasks.md` |
| Analyze | `/speckit-analyze` | read-only Markdown report (no file written) |
| Implement | `/speckit-implement` | source code; marks `tasks.md` items `[X]` |

Optional phases not yet wired into a flow: `/speckit-checklist`,
`/speckit-taskstoissues`.

## The SKILL.md frontmatter `specify init` writes (for Claude)

Each scaffolded `.claude/skills/speckit-<name>/SKILL.md` carries frontmatter the
CLI rebuilds per-agent — for example `speckit-plan`:

```yaml
---
name: "speckit-plan"
description: "Execute the implementation planning workflow using the plan template to generate design artifacts."
argument-hint: "Optional guidance for the planning phase"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "github-spec-kit"
  source: "templates/commands/plan.md"
user-invocable: true
disable-model-invocation: false
---
```

We do **not** author these — `specify init` does. They are documented here so the
exact invocation surface the flows target is auditable.

## Why these are reference, not live MAIster capabilities

1. **`specify init` writes them into the consuming project.** The flows invoke
   the project's own `.claude/skills/speckit-*` (committed by `sk-init`), so
   MAIster ships nothing to materialize.
2. **They assume interactivity.** `/speckit-specify` and `/speckit-clarify` ask
   the user clarifying questions; `AskUserQuestion` is disabled in MAIster's ACP
   adapter (`claude-agent-acp` `disallowedTools`). The `sk-dev` flow reconciles
   this: agent nodes record open questions as `[NEEDS CLARIFICATION: …]` markers
   instead of asking, and an authored **clarify** human node collects the
   maintainer's answers and feeds them into `/speckit-clarify`.

The `.specify/` scripts, templates, and command bodies live inside the pinned
`spec-kit` wheel (bundled, no network) and are scaffolded at `sk-init` time;
they are not re-vendored here.
