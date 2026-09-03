# BMAD Test Architect package reference

The package tracks BMAD TEA `v1.24.0` and vendors all nine current skills. Murat
is indexed as `bmad-tea:murat-test-architect`. Runtime support installs the
customization resolver and creates `_bmad/tea/config.yaml` without overwriting
project-provided configuration.

| Flow | Output | Human decisions |
| --- | --- | --- |
| `tea-test-design` | Risk-based test design and coverage plan. | approve / rework / waive |
| `tea-automate` | Test implementation diff and verification evidence. | approve / rework / takeover |
| `tea-nfr` | NFR evidence assessment. | approve / rework / accept_risk |
| `tea-trace` | Requirements traceability and quality gate. | approve / rework / waive |
| `tea-test-review` | Test quality score and findings. | approve / rework / accept_risk |

All five flows require MAIster engine 3.7 and export a small deterministic result
spine with an open JSON payload. This makes their reports collectable by parent
orchestrators without freezing TEA's evolving domain data into a rigid schema.

TEA 1.24 retains tri-modal create/resume, validate, and edit paths and expands
Pact short-lived branch coordination. The package enables Pact.js utilities but
leaves broker MCP integration explicitly disabled (`tea_pact_mcp: none`) because
no project-specific broker connection ships with the package.
