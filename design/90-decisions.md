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

The five arrived as bare statements with no rejected alternatives, which is the one thing
this log exists to carry. They were promoted into full entries on 2026-08-30 and now stand
on their own below, dated to when they were made; this entry records the move and does not
restate them.

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

---

The five entries below were written into the roadmap as bare statements on 2026-07-24
(`3cd8127`) and carried no rejected alternatives. Their `Rejected:` lines were
reconstructed on 2026-08-30 from the tree, the contract, and the roadmap's own earlier
wording — not recovered from a contemporaneous record. Two of the five were stated as
open questions in the roadmap that preceded them (`29e26f6`, 2026-07-23), so their
alternatives are quoted rather than inferred; the other three are reconstructed from what
the implementation and the contract can be shown to have chosen. Where an alternative is
inference, it is the strongest reading the evidence supports, and a correction from the
owner outranks it.

### 2026-07-24 — PowerShell 7.4 is the minimum supported version
Context: The module shipped at `PowerShellVersion = '7.0'` (`bf91add`, 2026-07-23). The
three-argument `Join-Path` building the built-in plugin root in what is now
`src/Public/Build-PSModule.ps1` already excluded Windows PowerShell 5.1 by construction —
`-AdditionalChildPath` is 6.0 and later, and the call was present at the time this was
decided — so the open question was never whether to require PowerShell 7, but which 7.x
to actually guarantee, and whether "minimum" would mean a floor that nothing exercises.
Chosen: 7.4, declared in the generator manifest and in every generated manifest, and
enforced by `build/Test-PowerShellBaseline.ps1`, which requires **exactly** 7.4.x and
refuses to run on a newer runtime. `Dockerfile` pins 7.4.6 by SHA-256 rather than a
floating tag so the published image guarantees the same baseline.
Rejected: **Stay on 7.0** — the value actually in the manifest until this decision.
Rejected because 7.4 is the supported LTS; a floor below it declares support for runtimes
that no longer receive fixes, and the generator would write that claim into every manifest
it produces. **Declare the floor and test on whatever the runner ships** — ordinary
practice, and cheaper. Rejected because a floor nothing exercises is not a floor: a
construct available only in a later 7.x lands green and breaks the one runtime the
manifest promised. The exact-version check is deliberately stricter than the manifest, and
`docs/docs/using/troubleshooting.md` says so rather than leaving it to look like a bug.
**Restore Windows PowerShell 5.1 compatibility** — the widest reach available to a
PowerShell module. Rejected as cost without return: the generator produces modules for
container directories, an environment where PowerShell 7 is the thing being installed.
Reversibility: cheap to lower, expensive to raise — raising the floor later is a breaking
change for everyone already on it.

### 2026-07-24 — Windows and Linux are validated in CI; macOS is best-effort
Context: The generator is pure PowerShell, but the end-to-end path builds and runs real
container images. Which platforms *block a merge* had to be settled before the CI matrix
was written.
Chosen: `ubuntu-latest` and `windows-latest` on both matrix jobs in
`.github/workflows/test.yml`, with `fail-fast: false` so one platform's failure still
reports the other. Container, docs, and publish jobs are Linux-only. macOS is expected to
work and is not gated.
Rejected: **Add `macos-latest` to the matrix** — makes macOS blocking. Rejected on yield
against cost: it adds a third of the matrix for a platform whose most likely failure mode,
path handling, is already covered by Windows and Linux sitting on opposite sides of the
separator and casing questions — and the container end-to-end path, where the real risk
lives, cannot run there, so the job would validate strictly less than the two already
present. **Linux only** — cheapest, and where the container runtime actually runs.
Rejected because the generator runs on the author's machine, not inside the container, and
Windows is where separator, casing, and line-ending defects surface; dropping it moves the
most likely class of bug out of CI. **Declare macOS unsupported outright** — cleaner to
state and honest about what is tested. Rejected because it claims more than the evidence:
nothing in the generator is platform-specific by design, so "not gated" is accurate where
"unsupported" would discourage use that most likely works.
Reversibility: cheap — a matrix entry.

### 2026-07-24 — Malformed optional artifacts warn and continue; authoritative inputs fail
Context: This was an open question on the roadmap, not a settled position — `29e26f6`
listed "Decide whether malformed optional repository artifacts should produce warnings or
fail the build, then apply the rule consistently." Inspection reaches files by broad
recursive discovery across a directory the generator does not own, so the answer decides
whether an unrelated malformed file anywhere in a tree can stop module generation.
Chosen: Warn and continue for malformed optional artifacts; fail for explicitly
authoritative inputs such as `*.schema.json`.
`design/planning/inspector-hardening-design.md` § *Policy* later refined the two-way split
into four classifications, which is the form the decision is implemented against.
Rejected: **Fail for any malformed input** — the other branch named in the original
question, and the safer-sounding one. Rejected because it makes every unrelated malformed
file in a directory a build stopper, converting "nothing could be learned from this file"
into "no module can be generated." **Warn for everything, including `*.schema.json`** —
uniform, and never blocks. Rejected because a file the author explicitly pointed the
generator at is not the same thing as one discovery happened to reach: degrading it
silently yields a module missing the parameters that schema declared, and the failure then
surfaces at invocation time, far from its cause.
Reversibility: cheap as a policy statement. Applying it per inspector is Version 1
hardening work still open in [`30-slices.md`](30-slices.md) § *4. Inspector hardening*.

### 2026-07-24 — Document and test a YAML subset instead of adding a shared YAML dependency
Context: Also an explicit fork on the roadmap that preceded this one — "Replace the
limited Compose, GitHub Actions, and OpenAPI YAML readers with a shared YAML parser or
explicitly document their supported subset" (`29e26f6`). Three inspectors parse a
line-oriented subset by hand.
Chosen: Keep the hand-written readers, and make the subset a documented, tested boundary
rather than an accident. [`20-contract.md`](20-contract.md) states that the readers
"intentionally parse a limited line-oriented subset without a shared YAML dependency."
Rejected: **Take a YAML dependency**, `powershell-yaml` being the de facto choice —
correct parsing for free, and the option the roadmap named first. Rejected because the
generator declares no `RequiredModules` at all and installs as one self-contained module;
a parser dependency makes every install two steps and every offline or image build a
vendoring problem, in exchange for reading three file formats from which this project
extracts a handful of fields. This is the standing example behind `AGENTS.md`'s
no-new-dependencies rule. **Vendor a parser into `src/`** — no external dependency on
paper. Rejected as the worst of both: the repository takes on maintenance of a general
parser it did not write and cannot upstream fixes to, for generality it has no use for.
**Leave the readers limited and say nothing** — the state at the time, and the actual
defect being fixed: an undocumented subset is indistinguishable from a bug, so every input
outside it becomes a support question.
Reversibility: cheap. Adopting a real parser later is additive, because everything the
hand-written subset accepts a conforming YAML parser also accepts.

### 2026-07-24 — Runtime mappings are authored explicitly; inference must not guess intent
Context: The generator infers heavily elsewhere — it discovers commands from PowerShell
scripts and from .NET and NUKE build definitions, and `Initialize-PSModuleDirectory`
materializes a specification from what it found. The question was whether that inference
could extend from "which commands exist" to "which container runtime behavior each
parameter needs."
Chosen: It stops at mappings. [`20-contract.md`](20-contract.md) states that
directory-specific runtime intent is not inferred from script names, source paths, or
other naming conventions. The same section rejects unknown mapping types outright, so that
a specification cannot silently omit runtime behavior.
Rejected: **Infer mappings from naming conventions** — a `-Path` or `-Directory`
parameter becomes a Mount, a `-Port` becomes a published port. Tempting, because that is
where most of the remaining authoring effort sits. Rejected because the failure is not
symmetric with command inference: a wrongly inferred command is inert and visible, while a
wrongly inferred mount silently grants a container access to a host path the author never
named. Guessing here is a security decision wearing a convenience's clothes. **Infer, then
have the author confirm** — keeps the assistance and adds a gate. Rejected because the
confirmation must be recorded somewhere for builds to stay deterministic, and once it is
recorded it *is* an explicitly authored mapping: the middle path collapses into the chosen
one plus a wizard, and the wizard is `Initialize-PSModuleDirectory`'s job rather than the
contract's. **Infer only a documented safe subset**, such as environment variables, which
grant no filesystem access. Rejected because the boundary is not stable — the safe subset
is defined by today's mapping types, and every new type reopens the question with the
incentive pointing at "add it to the safe list."
Reversibility: expensive, and asymmetric. Inference that has ever shipped is load-bearing:
specifications authored while it existed omit the mappings it supplied, so withdrawing it
later breaks them. Adding it later breaks nothing.
