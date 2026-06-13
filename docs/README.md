# maister-plugins docs

Reference documentation for the MAIster flow packages in this repo. Each
package is a self-contained distribution unit (flow graphs + capability bundle
+ manifest) consumed by [MAIster](https://github.com/albertkanischev/maister)
through `maister.yaml packages[]`, pinned by a per-package git tag
(`<name>/vX.Y.Z`).

## Packages

| Package | Reference | Flows | Capability bundle |
| ------- | --------- | ----- | ----------------- |
| `aif` | [aif/](aif/README.md) | `aif-dev`, `aif-bugfix`, `aif-evolve`, `aif-roadmap`, `aif-init` | AI Factory skills + subagents (`github.com/lee-to/ai-factory@2.x`) |
| `superpowers` | [superpowers/](superpowers/README.md) | `sp-dev`, `sp-debug`, `sp-plan`, `sp-execute` | superpowers skills, all 14 (`github.com/obra/superpowers@5.1.0`) |

## What every package documents

- **Flows** — the typed-node graphs (`flow.yaml`): nodes, transitions, gates,
  HITL placement, rework loops.
- **Capability bundle** — the vendored skills/agents materialised into each
  session worktree's `.claude/` at launch.
- **Reconciliation** — how the upstream framework's interactivity and git
  ownership are mapped onto MAIster-native HITL + worktree/promotion ownership
  (the framework must not create branches, merge, push, or ask the user
  directly).
- **Policies** — runner profile, `compat.engine_min`, `session_policy`,
  `retry_policy`, `verdict_calibration`, rework `workspacePolicies`.

## How MAIster materialises a capability bundle (claude adapter)

Verified against MAIster `web/lib/capabilities/*` + the
`@agentclientprotocol/claude-agent-acp@0.37.0` adapter:

- **Skills + agents files are copied wholesale** at launch:
  `capability/skills/*` → `<worktree>/.claude/skills/*` and
  `capability/agents/*` → `<worktree>/.claude/agents/*` (per-project, for every
  Installed bundle — **not** gated on a node's `settings.skills`).
- The adapter sets `settingSources: ["user","project","local"]`, so the SDK
  loads those project `.claude/` skills + agents; the `claude_code` system
  preset exposes the Skill + Task (subagent) tools. `AskUserQuestion` is the
  only force-disabled tool.
- **`rule`-kind capabilities are NOT delivered** to a claude session today (no
  `CLAUDE.md`/`AGENTS.md`/context write) — packages that need always-on
  guidance must inline it into node prompts, not ship it as a rule.
- Per-node `settings` deliver `tools`→`permissions.allow`,
  `permissionMode`→`permissions.defaultMode`, and `mcps`→ACP `mcpServers` via
  `<worktree>/.claude/settings.local.json`. Capability *enforcement* (skills /
  restrictions / workspaceAccess) stays advisory (`instructed`) this milestone.

See each package's reference page for how it uses these facts.
