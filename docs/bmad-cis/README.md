# BMAD Creative Intelligence Suite package reference

The package tracks BMAD CIS `v0.3.2`: four upstream workflow skills and six
platform agents. Current resolver scripts are installed into each run by the
internal runtime-support skill, and every upstream call receives an explicit
project root.

`cis-discovery` uses MAIster engine 3.7's governed recursive-agent harness:

1. An orchestrator submits four read-only agent children: Quinn, Maya, Carson,
   and Victor.
2. Each child publishes a `creative-contribution` result with the deterministic
   `summary`/`outcome` spine and an open JSON payload.
3. The orchestrator collects all terminal results and records the exact child
   run ids it consumed.
4. A single Victor writer checks the synthesis against the repository, writes
   `docs/planning-artifacts/discovery-brief.md`, and publishes the flow result.
5. A product-owner gate can approve, rework the whole fan-out, or defer with a
   typed `needs_input` result.

Read-only child workspaces plus one writer avoid concurrent branch mutation.
The reviewed discovery brief remains directly consumable by `bmm-plan`.
