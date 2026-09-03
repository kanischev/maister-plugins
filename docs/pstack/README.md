# pstack on MAIster

This document records how pstack's development model maps to MAIster's runtime
primitives. The package consumer reference is
[`../../packages/pstack/README.md`](../../packages/pstack/README.md).

## Mapping

| pstack concept                 | MAIster primitive                                                    | Package decision                                                                      |
| ------------------------------ | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| Poteto-mode playbook selection | Explicit Flow selection and `metadata.route_when`                    | Each production workflow is a separately installable, inspectable graph.              |
| Multi-model deliberation       | `consensus` participants plus synthesizer                            | Independent Claude/Codex runner slots debate read-only investigation and design work. |
| Specialist critique            | Fresh-session `judge` node                                           | Verification and review do not inherit the implementing agent's narrative.            |
| Task subagents                 | Flow nodes and typed artifacts                                       | Workflow-scale delegation is visible in the ledger; no hidden child-task dependency.  |
| AskQuestion                    | `human` node, decision set, comments variable                        | Human input is durable, routable, and available to rework nodes.                      |
| Iterative correction           | `decide` plus bounded `rework`                                       | Loops have explicit targets, budgets, exhaustion paths, and workspace policies.       |
| Proof before claims            | `test_report`, `preview`, `ai_judgment`, and blocking artifact gates | Evidence is durable and reviewable outside agent context.                             |
| Worktree and PR playbooks      | MAIster workspace and promotion lifecycle                            | Agents may commit locally only in finalization; they never merge, push, or open PRs.  |
| Configured model roster        | Project-bound runner profiles                                        | The package declares capability classes, not provider-specific model IDs.             |
| Quality taste and principles   | Vendored capability skills plus `pstack-rigor`                       | Guidance is available during execution and measurable afterward.                      |

The decisive boundary is that pstack supplies engineering judgment and
phase-specific techniques, while MAIster supplies control-plane semantics.
Encoding Cursor's Task, `/loop`, branch, or PR behavior inside an agent prompt
would hide execution state from MAIster and weaken recovery, auditability, and
human governance.

## Why the extended flows are in v1

Refactoring, performance work, prototyping, and visual parity need no new
platform primitive beyond what the core four flows already require. They are
distinct evidence protocols over the same stable substrate:

- Refactoring freezes behavior before structural change.
- Performance freezes a workload and measurement method before optimization.
- Prototyping writes disposable output to the attempt artifact directory,
  keeping source clean until a later production task is chosen.
- Visual parity makes references, rendered candidates, and comparison reports
  first-class artifacts.

Keeping them for a later package release would reduce initial validation risk,
but would not simplify MAIster integration materially. Shipping all eight in v1
tests the reusable architecture across the important process shapes without
adding another runtime mechanism.

## Deliberately outside v1

The following upstream playbooks remain vendored skills but are not exposed as
production Flow graphs yet:

- `shipping` and `babysit`, because MAIster already owns review, CI state,
  promotion, and merge authority; a direct port would duplicate that ownership.
- `autonomous-run` and `orchestrate`, because durable recursive public Run
  results and explicit delegation bounds should be used instead of a long-lived
  prompt coordinator. A future Flow should be designed directly on the
  orchestrator/RAH contract.
- `hillclimb`, runtime forensics, trace forensics, skill authoring, and eval,
  because each needs a narrower artifact or operational contract before it can
  be a reusable production graph.
- Benny automation, because scheduled execution and notifications belong to a
  separate MAIster automation integration, not the capability package.

This is an execution-surface boundary, not a loss of source material: the full
upstream skills remain installed for explicit use.
