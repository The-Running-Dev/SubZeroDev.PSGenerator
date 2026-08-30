# Decision log

Append-only. Newest at the top. **The rejected alternatives are the point** — without
them the next session relitigates the same choice.

## Open

Things noticed and deliberately not acted on. Move them out or delete them; do not let
this section rot. `/track` turns these into issues.

---

### 2026-08-30 — /kit-sync: merged four kit `AGENTS.md` changes since the last sync, one over a local customization
Context: `~/.agent-kit` was 4 commits ahead of this repository's recorded `syncedCommit` (2f9c664e → 5095a55c). Of those commits, only `AGENTS.md` touched an installed artifact — the rest were the kit's own `design/` content, never installed here. Three of the four changed spots were clean additions (a `/next` Command-routing row, a force-delete-on-tip-comparison sentence on the `/clean` bullet, and a "derived design-state record may commit straight to the default branch" exception on the "no work lands directly on the default branch" bullet); the target's wording at each still matched the pre-change kit text verbatim. The fourth overlapped a standing local customization: this repository's *Vendor model aliases* tier-resolution paragraph already read `codex/PROFILES.md` as a code span with a "not installed, no Codex use to date" caveat (2026-08-30, PR #83's `Test-Documentation.ps1` fix), and the kit's new commit added a preceding paragraph about an `AGENTKIT_TIER` environment stamp (set by `tools/Invoke-CodexCommand.ps1`, already installed here though unused) plus a "Failing that," reword of the sentence that follows.
Chosen: Apply all three clean additions verbatim. For the fourth, prepend the kit's new `AGENTKIT_TIER` paragraph unchanged, apply the "Failing that," reword, and keep this repository's customized wording — including the code-span link and the "not installed" caveat — in the paragraph that follows it.
Rejected: **Take the kit's paragraph outright, dropping the local caveat** — would silently re-link to `codex/PROFILES.md`, a file this repository still does not have, reintroducing exactly the dead link PR #83 fixed. **Skip the `AGENTKIT_TIER` paragraph as inapplicable, since Codex is unused here** — declined; `tools/Invoke-CodexCommand.ps1` is installed and updated by this same sync, so the stamp mechanism it documents already exists in this repository's tooling even though nothing invokes it yet.
Reversibility: cheap — prose only; no tooling or settings changed.

### 2026-08-30 — Re-install: adopt the kit's post-2026-08-20 delegation and model-tier-gate policy
Context: The kit retired its High-volume/haiku tier and now delegates branch-commit-push-PR-opening, review-thread resolution, milestone/project creation, and Done-when checkbox ticking without asking (kit commit a12aac7 and related, landed after this repository's 2026-08-20 install). This repository's `AGENTS.md` still stated the pre-a12aac7 policy: approval required before pushing/opening/merging PRs, review-thread resolution scoped to the "do next todo" loop only, milestones/projects needing approval, checkbox-ticking reserved to the owner, and no model-tier-mismatch gate in the over-powered direction. Per `AGENTS.md`'s own reconciliation rule the target's stated policy wins by default — but this cluster read as staleness relative to a deliberate kit-wide policy shift, not a considered local override, and was put to the owner as such.
Chosen: Adopt the kit's current policy in full: retire the High-volume/haiku tier (folding its work into Implementation); delegate branch/commit/push/PR-opening for all work with no separate ask; delegate `/resolve`'s Defect-class thread resolution as a blanket rule, not only inside the "do next todo" loop; carve out issue closing/commenting/editing and milestone/project creation (in a repository the owner owns); delegate Done-when checkbox ticking to `/slice`; and add the work-start/session-boundary banner protocol, gating a model-tier mismatch in both the under- and over-powered directions. This supersedes the checkbox/merge framing in the 2026-08-04 "autonomous 'do next todo' loop" decision below — merging is still reserved to the owner, but checkbox-ticking no longer is.
Rejected: **Keep the repository's stricter, pre-shift policy** — defensible as a considered local override, but the owner confirmed it was staleness rather than a deliberate choice. **Split the cluster and decide each authorization boundary separately** — offered and declined in favor of one bundled decision, since all eight sub-points trace to the same upstream policy shift.
Reversibility: cheap — reverting `AGENTS.md`'s wording reverts the policy; nothing external (branch permissions, GitHub settings) was changed.

### 2026-08-30 — Re-install: backported five kit sections this repository lacked entirely
Context: The 2026-08-20 install predated five additions to the kit's `AGENTS.md`: the Vendor model aliases table, the Third-party text (prompt-injection) caution, the design-freeze mechanism (`design/FROZEN.md` plus its Hard Rules and Source-of-truth carve-outs), the general Marked regions framework, and two Hard Rules ("could I have answered this myself", "never hand back a diff to type in"). None conflicted with anything this repository's `AGENTS.md` already stated.
Chosen: Add all five verbatim (vocabulary adapted from "slice" to this repository's "item," per its existing convention). `codex/PROFILES.md`, which Vendor model aliases points to, was not installed — this repository has shown no Codex use — and the section says so rather than citing a file that does not exist here.
Rejected: **Add everything except the design freeze** — considered, since this repository has never needed to freeze `design/`; not chosen, since the freeze commands (`/freeze`, `/unfreeze`) were being installed as core command files in the same pass regardless, and documenting the mechanism they implement costs nothing extra. **Skip all five and revisit later** — declined; nothing in them requires the repository to change behavior today, only to know the option exists.
Reversibility: cheap

### 2026-08-30 — Re-install: routing table, stale `done.md`, and three untracked test files
Context: `tools/Sync-Kit.ps1 -DryRun` surfaced three mechanical gaps from the 2026-08-20 install: the Command routing table was missing rows for seven commands whose core files this pass adds or updates (`/code-review`, `/fix`, `/freeze`, `/unfreeze`, `/clean`, `/install-code-review-agent`, `/kit-sync`) and had `/kit-help` pinned to the retired haiku tier; `.claude/commands/done.md` remained on disk after the kit renamed `/done` to `/clean` (commit d2ff850); and three Pester test files (`Read-DesignState.Tests.ps1`, `Test-DesignState.Tests.ps1`, `Update-DesignProjection.Tests.ps1`) existed in the kit at the 2026-08-20 recorded commit but were never copied into this repository — confirmed by the absence of any add-then-delete in this repository's own git history, so a gap in that install rather than a deliberate removal.
Chosen: Sync the routing table to the kit's current rows and tiers; delete `done.md`; add the three test files.
Rejected: **Leave the three test files out** — would leave `Read-DesignState.ps1`, `Test-DesignState.ps1` and `Update-DesignProjection.ps1` (all present and updated in this pass) without their kit-authored coverage, for no reason this repository chose. **Leave `done.md` in place** — risks someone invoking a command the kit no longer maintains.
Reversibility: cheap

### 2026-08-30 — Re-install: added `Measure-Session.ps1`'s `SessionEnd`/`UserPromptSubmit` hooks
Context: `.claude/settings.json` had no `hooks` key. `tools/Measure-Session.ps1`, already present, provides a per-session cost report and a prompt-time size warning, but only functions as a `SessionEnd`/`UserPromptSubmit` hook pair.
Chosen: Install both hooks, touching only the `hooks` key; `model: opusplan` is untouched.
Rejected: **Skip the hooks** — offered; declined since pwsh 7 is on `PATH` and nothing else claims either event.
Reversibility: cheap

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
