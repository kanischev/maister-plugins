# Superpowers package reference

The package tracks upstream Superpowers `v6.3.0` and vendors all 14 skills
verbatim. MAIster owns orchestration, worktrees, promotion, and human approval;
the skills own engineering discipline inside agent nodes.

| Flow | Purpose | Human gates |
| --- | --- | --- |
| `sp-dev` | Design, plan, implement with TDD, verify, review, finalize. | Design, plan, final implementation review. |
| `sp-debug` | Root-cause investigation, regression test, fix, verify, review. | Final implementation review. |
| `sp-plan` | Produce a design and implementation plan without coding. | Design and typed plan review, each with approve/rework/defer. |
| `sp-execute` | Execute an already approved plan. | Final implementation review. |

The v6.3 subagent-driven workflow uses task briefs, one review per task,
re-review after fixes, and a broad final review. The MAIster prompts no longer
reference the removed `spec-reviewer-prompt.md` and
`code-quality-reviewer-prompt.md`; they delegate the protocol to the current
skill. Selecting subagent-driven mode fails explicitly when governed dispatch is
unavailable rather than silently switching execution strategy.

All four flows require MAIster engine 3.7 and export the common result spine:
`summary`, `outcome`, and an open `payload`. The same shape is used internally
where it adds a real handoff: chosen design → planning, exact plan → execution,
verification evidence → review, and structured review findings → rework. The
code-writing flows deliberately remain native single-worktree graphs instead of
spawning concurrent RAH writers.
