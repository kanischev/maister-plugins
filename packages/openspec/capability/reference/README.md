# OpenSpec reference bundle (provenance — NOT materialized)

This bundle is **reference-only**. It is declared as the package's capability
(`openspec-reference`) so OpenSpec provenance travels with the package, but it
contains **no `skills/` or `agents/` subtree**, so MAIster's capability
materializer copies nothing into the session worktree. The flows drive OpenSpec
through its CLI (`openspec …`, installed by `setup.sh` / the `os-init` flow).

Contents (vendored from `@fission-ai/openspec@1.4.1`, MIT):

| Path | What it is |
| ---- | ---------- |
| `schema-spec-driven/schema.yaml` | The default OpenSpec workflow schema (artifact pipeline + dependencies). |
| `schema-spec-driven/templates/{proposal,design,tasks,spec}.md` | The artifact templates `openspec instructions <artifact>` returns. |
| `claude-skills/openspec-*/SKILL.md` | The Claude skills `openspec init --tools claude` scaffolds into a project. |
| `claude-commands-opsx/*.md` | The `/opsx:*` slash-command bodies `openspec init` scaffolds. |
| `openspec-config.yaml` | The `openspec/config.yaml` written by `openspec init`. |
| `LICENSE.openspec` | Upstream MIT license. |

## Why these are reference, not live capabilities

`openspec init --tools claude` writes real `.claude/skills/openspec-*` and
`.claude/commands/opsx/*` **into the consuming project**. The flows do **not**
invoke them, for two reasons:

1. **They assume interactivity.** Their bodies use the `AskUserQuestion` tool
   (to pick a change name / select among changes), which is disabled in
   MAIster's ACP adapter. The flows instead auto-select the single active change
   and derive names non-interactively.
2. **The flows drive the CLI directly, by node type.** Deterministic OpenSpec
   calls live in `cli`/`check` nodes (run by MAIster's runner, no agent, no
   permission HITL); only the creative steps are `ai_coding`. Routing everything
   through the slash commands/skills would force all of it through the agent.

These files are kept here so the exact OpenSpec workflow text (what the CLI would
instruct) is auditable alongside the flows, and to record precisely which
upstream version the flows target. They remain perfectly usable in native Claude
Code, where a human can answer the questions.
