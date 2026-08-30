# Decision log

Append-only. Newest at the top. **The rejected alternatives are the point** — without
them the next session relitigates the same choice.

## Open

Things noticed and deliberately not acted on. Move them out or delete them; do not let
this section rot. `/track` turns these into issues.

---

### 2026-08-04 — Version 1 policy decisions, moved from the roadmap
Context: These five were stated as a `## Version 1 policy decisions` list at the top of
`TODO.md`, which is a roadmap. A decision register inside a work queue is a decision
register nobody reads once the queue moves on, and this repository had no decision log at
all — established by search, not assumption.
Chosen: Move them here verbatim, and leave the roadmap pointing at this file. The wording
is unchanged; only the home is.

- PowerShell 7.4 is the minimum supported version.
- Windows and Linux are supported and validated in CI. macOS is best-effort for Version 1
  and is not a required CI platform.
- Malformed optional directory artifacts should emit actionable warnings and allow
  inspection to continue. Explicitly authoritative inputs, such as files named
  `*.schema.json`, should fail when malformed.
- Version 1 will document and test the supported subset of Compose, GitHub Actions, and
  OpenAPI YAML instead of adding a shared YAML dependency.
- Runtime mappings that depend on directory-specific invocation intent must be authored
  explicitly. Inference must not guess intent from names or paths.

Rejected: **Copy them here and leave them in the roadmap too** — two copies of a decision
is a promise they will diverge. **Leave them where they were** — they are decisions, and
the roadmap is the one document guaranteed to be rewritten as work completes.
Reversibility: cheap

---

### 2026-08-04 — The kit is installed here, overriding this repository's own lesson against it
Context: This repository's `AGENTS.md` carried a durable lesson — "Keep agent instructions
concise and repository-specific. Do not import another project's architecture, tooling,
memory conventions, or roadmap merely because it appears in a neighboring instruction
file." Installing the SubZeroDev agent kit is precisely what that forbids, and the
installer's own rule is that a target's stated rules outrank the kit's defaults.
Chosen: Install anyway, **on the repository owner's explicit instruction**, given after
the conflict was put to them in those terms. The lesson is retained rather than deleted —
it is a good rule and it was correctly applied to this case; it was overruled, not found
wrong. It now reads as retained-and-overridden in `agent.md`.
Rejected: **Skip the install and report** — what the lesson requires, and what was
recommended. **Install only the commands and leave the contract alone** — avoids the
conflict on paper, but the commands cite contract sections that would then not exist here,
which is worse than either whole answer.
Reversibility: cheap to revert as files; the estate consistency it buys is the reason not
to.

### 2026-08-04 — The design chain absorbs the existing documents rather than sitting beside them
Context: Four of the kit's five design documents already had homes: `Specifications.md`
was the behaviour contract, `planning/` held nine accepted per-feature designs, `TODO.md`
was the roadmap, `peer-review.md` was adversarial review. Only a decision log was missing.
Creating `design/00-brief.md` … `90-decisions.md` alongside them would have given the
repository two answers to every question.
Chosen: Migrate. `Specifications.md` → `design/20-contract.md`, `TODO.md` →
`design/30-slices.md`, `planning/` → `design/planning/`, each as a tracked rename with a
pointer left at the old path. `10-design.md` is a new index over `planning/` rather than a
tenth design document. `00-brief.md` is reconstructed from what the contract already
states and says so in its own header. **34 references across 13 files were rewritten**,
found by search rather than from a list; the documentation gate caught three more that the
search had missed.
Rejected: **Map without moving** — install only `90-decisions.md` and repoint the commands
at the existing filenames. Smaller and entirely defensible; not chosen, because the
mapping would then be invisible from the file tree and every future agent would rediscover
it. **Create the full chain alongside** — rejected as the duplication the kit exists to
prevent.
Reversibility: **expensive.** Every cross-reference moves again if the directory does.

### 2026-08-04 — `design/` at the root, and added to `.dockerignore`
Context: `docs/` is a Docusaurus project with its own `Dockerfile`, so `docs/design/`
would place internal design documents inside the published image's build context.
`Specifications.md`, `TODO.md` and `planning` were already listed in `.dockerignore` for
exactly that reason.
Chosen: Root `design/`, and those three `.dockerignore` entries collapse to one `design`
entry that covers the whole migrated set.
Rejected: **`docs/design/`** — bakes internal documents into a published image.
**Leaving `.dockerignore` alone** — the three named entries no longer match anything after
the move, so the exclusion would have silently stopped working.
Reversibility: cheap

### 2026-08-04 — The autonomous "do next todo" loop keeps running, but no longer merges
Context: This repository's workflow ran unattended end to end: implement, push, open a
pull request, wait for checks, resolve review threads, **and merge**. The kit's contract
requires the owner's authorization for every external write and reserves merging to them.
Both cannot hold.
Chosen: The loop stays — it is this repository's established and working practice, and it
is the reason the work moves. Its final step does not. `/verify`, `/pr` and `/resolve` now
own the steps they duplicate, and the loop stops at a pull request that is ready to merge
rather than merging it. Ticking a checkbox and merging are the two acts reserved to the
owner.
Rejected: **Keep self-merge and drop the kit's authorization rule for this repository** —
consistent with what was here, and it removes the only human gate between "checks are
green" and "this is shipped". **Delete the loop and use the kit pipeline alone** — throws
away a workflow that demonstrably works, to gain uniformity nobody asked for.
Reversibility: cheap
