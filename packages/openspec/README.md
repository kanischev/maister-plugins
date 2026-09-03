# OpenSpec package

MAIster packaging of [Fission-AI/OpenSpec](https://github.com/Fission-AI/OpenSpec),
using upstream `v1.12.0` at commit
`e062b9572be933564ba3899d059377dfa1393e32`.

The package ships all 12 upstream Agent Skills, the current spec-driven schema,
and four flows: `os-init`, `os-propose`, `os-apply`, and `os-dev`. The trusted
setup hook and `os-init` enforce `@fission-ai/openspec@1.12.0`; other flows
refuse launch against a different CLI version. Structured outputs carry the
approved `changeName` into apply/archive and feed independent review findings
into rework; proposal and implementation flows expose typed public results.

See [the package reference](../../docs/openspec/README.md). Vendored upstream
content remains under the MIT license in
`capability/reference/LICENSE.openspec`.
