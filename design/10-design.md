# Design

> Assembled 2026-08-04 during the agent-kit install. This repository's design was written
> as **one accepted document per feature** rather than as a single architecture document,
> and those documents are real, reviewed and cited from
> [`../peer-review.md`](../peer-review.md). This file does not replace them and does not
> summarise them — a summary of nine accepted designs is a tenth document that can
> disagree with all of them. It says where each decision lives and what owns it.

## The architecture is in the contract

The system-level architecture — the component diagram, the directory layout, the build
model, the generated-code shape, the internal generator architecture and the plugin
architecture — is stated in [`20-contract.md`](20-contract.md) §§ *High-Level
Architecture*, *Directory Layout*, *Generated Output*, *Build Model*, *Generated Code*,
*Internal Generator Architecture*, *Plugin Architecture* and *Plugin Discovery*.

That is unusual — the kit's default is for `10-design.md` to hold it and for the contract
to hold only signatures. **Here the contract is the older and more exercised document**,
it is what the tests and the generator were built against, and moving those sections out
of it would break every cross-reference into a file that has been stable for the life of
the project. It stays where it is; this file points at it. See
[`90-decisions.md`](90-decisions.md).

## Feature designs — [`planning/`](planning/)

Each is independently accepted and owns its area. Where one disagrees with this index,
the feature document is right.

| Document | Owns |
|---|---|
| [`build-agent-evidence-design.md`](planning/build-agent-evidence-design.md) | Docker-BuildAgent-shaped evidence merging and command inference |
| [`build-output-hygiene-design.md`](planning/build-output-hygiene-design.md) | Build output placement and the ignore patterns that keep it out of the tree |
| [`command-collision-diagnostics-design.md`](planning/command-collision-diagnostics-design.md) | Detecting inferred-command collisions **without** auto-loading or executing installed modules |
| [`inspector-hardening-design.md`](planning/inspector-hardening-design.md) | Directory inspection under malformed and hostile input |
| [`release-candidate-validation-design.md`](planning/release-candidate-validation-design.md) | What must hold before a release candidate is accepted |
| [`repository-protection-design.md`](planning/repository-protection-design.md) | Required checks, branch protection, merged-branch deletion |
| [`next-engineering-set-implementation-plan.md`](planning/next-engineering-set-implementation-plan.md) | Sequencing plan across three engineering tracks |
| [`quality-safeguards-implementation-plan.md`](planning/quality-safeguards-implementation-plan.md) | Sequencing plan for the three post-Version-1 safeguards |

[`planning/evidence/`](planning/evidence/) holds captured ruleset states referenced by
the repository-protection design. They are evidence, not design: never edit one to match
a document.

**One document in `planning/` is not this repository's design.**
[`llms-powershell-module-discovery.md`](planning/llms-powershell-module-discovery.md) is
a planning brief for a *different* repository, `The-Running-Dev/LLMs`, and says so in its
own header. It is filed here because it originated here. Do not implement it against this
codebase.

## Failure modes

Stated where they are enforced rather than collected here:

- Malformed **optional** directory artifacts emit actionable warnings and allow
  inspection to continue; explicitly authoritative inputs such as `*.schema.json` fail.
  Recorded in [`90-decisions.md`](90-decisions.md), enforced by the inspector.
- Collision detection must not auto-load or execute installed modules — a design
  constraint, not an optimisation. See the collision-diagnostics design.
- Generated output is deterministic. A non-deterministic generator is a defect even when
  the output is otherwise correct.
