# Peer Review: Next Engineering Set

Independent review of the three design documents and the delivery plan proposed
for the next engineering set.

## Scope

Reviewed at commit `4ee612b`, the head of `agent/plan-next-engineering-set`,
against base `891785e`.

- [Build-Agent evidence and inference design](planning/build-agent-evidence-design.md)
- [Inspector hardening design](planning/inspector-hardening-design.md)
- [Release-candidate validation design](planning/release-candidate-validation-design.md)
- [Next engineering set implementation plan](planning/next-engineering-set-implementation-plan.md)

## Method

Each load-bearing claim was checked against the current source rather than read
for internal consistency alone. The review environment has no PowerShell host, so
nothing was executed; findings rest on reading the implementation, the shipped
inspectors, the existing fixture, and the roadmap the plan claims to advance.

## Verified

- **The inspector matrix is complete.** The hardening design's nine inspector
  sections correspond one-to-one with the nine plugins under `src/Plugins/Inspectors`.
  Nothing shipped is unaddressed and nothing addressed is imaginary.
- **The roadmap counts are accurate.** `TODO.md` §3 has eleven unchecked items
  against two checked, and §4 has six unchecked, exactly as recorded.
- **The hardening design covers `TODO.md` §4 completely.** All six roadmap items
  map onto a section: malformed-input policy, traversal confinement, path
  fixtures, per-inspector behavior, YAML subsets, and Dockerfile parsing.
- **The release-candidate reuse targets all exist.** Every script the design
  proposes to orchestrate is present in `build/`, including `Test-RepositoryHygiene.ps1`
  added by the quality-safeguards work, which `Invoke-Quality.ps1` now calls.
  Neither `build/Invoke-ReleaseCandidate.ps1` nor the workflow it proposes exists
  yet, so the design describes new work rather than restating what is built.
- **The type names are right.** `SubZeroDev.PSGenerator.InspectionResult` and the
  `PluginExecutions` property are named as the source declares them, and the
  proposed `SubZeroDev.PSGenerator.InspectionIssueDiagnostic` follows the existing
  `SubZeroDev.PSGenerator.Diagnostic` convention.
- **The non-execution boundary is consistent** with the collision-diagnostics work
  already merged, which established that discovery may read manifests but may not
  import or run what it finds.

## Findings

### 1. The proposed inference fixture cannot start empty

The build-agent design specifies a fixture whose specification begins empty, and
a baseline test proving it produces "evidence but no false commands". The
proposed tree places three files under `scripts/`:

```text
scripts/powershell-module/
├── BuildAgent.psm1
├── parameters.json
└── Update-ModuleParameters.ps1
```

`Get-PSModuleSpecificationCandidate` already scans `scripts/` recursively and
infers a command from every `.ps1` and `.psm1` it finds. `Update-ModuleParameters.ps1`
therefore becomes the command `Update-ModuleParameters`, and `BuildAgent.psm1`
contributes its exported functions, the moment initialization runs. The
specification is not empty and the baseline assertion cannot hold as written.

The design anticipates the wrong hazard. It says `Update-ModuleParameters.ps1`
"is reference behavior and a test oracle. Discovery must not invoke it" — which
addresses execution, the thing that is already safe, while leaving inference, the
thing that actually fires.

This matters beyond the fixture. `TODO.md` §3 and `TODO-Next.md` §3 both record an
open item for "the maintenance-script classification that would keep repo tooling
out of a public command surface". `Update-ModuleParameters.ps1` is precisely that:
repository tooling that should not become a published command. The design
constructs a clean instance of a known unsolved problem without citing it, and
then writes acceptance criteria that assume it is solved.

Three ways out, in increasing cost:

- move the files outside `scripts/`, so the fixture exercises build evidence
  without tripping script inference;
- state the baseline as "no commands inferred from build evidence" and record the
  script-inferred commands as expected, distinguishing the two inference paths; or
- sequence the maintenance-script classification ahead of this fixture and make it
  a prerequisite, which is the only option that resolves the underlying roadmap item.

### 2. PR 2 asks for centralization that has already happened

The plan describes PR 2 as "centralize recursive enumeration and path admission",
with the exit criterion "every recursive inspector uses the same traversal helper".

That criterion is already met. `Test-PSModuleInspectionPath` exists and already
excludes the configured output directory, `.git`, `artifacts`, `bin`, `obj`, and
`node_modules`, and already walks parent directories to reject nested repositories.
Checking every inspector for recursion against its use of the helper gives an exact
correlation: the five that recurse — project manifest, PowerShell, NUKE,
configuration schema, and OpenAPI — all gate on it, and the four that do not use it
— Dockerfile, Compose, README, and GitHub Actions — do not recurse at all.

The remaining work in that area is real but much narrower than the plan implies:
resolving real paths so a link cannot escape the repository root, a visited-path
set to stop symlink cycles and duplicate reads, platform casing rules, and emitting
repository-relative paths for diagnostics. None of that is centralization; it is
extension of a helper that already exists and is already universally adopted where
it applies.

An implementer following the plan would either rebuild what is there or spend the
slice discovering that the stated exit criterion was true before they started.

### 3. The dependency graph contradicts the pull-request numbering

The plan's graph asserts `G --> H`, where `G` is "Remaining inspector hardening"
and `H` is "Complete inference lifecycle". In the numbered sequence those are
PR 8 and PR 7 respectively, so the graph requires PR 8 to land before PR 7 while
the numbering says the reverse.

The graph also labels `F` as "Candidate merge and materialization", but the
sequence splits those: PR 6 is merge and conflict policy, and materialization moves
to PR 7. Two of ten nodes disagree with the list they summarize, in a document
whose stated purpose is ordering.

### 4. Command evidence becomes public output as a side effect

The hardening design is careful about public surface. It adds `Context.InspectionIssues`,
states that it is exposed as `Issues` on the result, keeps `Get-PSModuleDiagnostic`
output unchanged by default, and puts new records behind an opt-in switch
specifically to avoid changing shape for existing callers.

The build-agent design has no equivalent paragraph. It says inspectors add records
to `Context.Inspection.CommandEvidence` and stops there. But `Get-PSModuleInspection`
returns `Data = $context.Inspection`, so anything added to that object is published
verbatim on the result. `CommandEvidence` would become a public property of
`Data` — a new consumer-visible contract, carrying provenance, confidence, and
inspector identity — without the design ever acknowledging it as public.

Two designs in the same set treat the same concern with opposite levels of care.
Either evidence is internal and should live somewhere `Data` does not expose, or it
is public and deserves the same explicit contract, ordering guarantee, and
compatibility statement that `Issues` receives.

### 5. The combined diagnostic stream has no ordering contract

`-IncludeIssues` is specified to emit a distinct record type into the same output
stream as plugin-execution diagnostics. Issue ordering relative to other issues is
defined — inspector execution order, then path, then code — but ordering relative to
the execution records is not.

A caller piping the result cannot know whether issues arrive interleaved with, before,
or after the executions they relate to, and the two record types share no common
property to sort or filter on. Either state the interleaving, or emit issues after all
executions, or give both types a shared discriminator field.

### 6. The plan defers to a reorganization that already happened

The plan states: "This planning change intentionally does not edit `TODO-Next.md`;
that file is being reorganized independently."

That reorganization has since merged. `TODO-Next.md` §3 now carries a section titled
"Still Open on the v1 Roadmap" that names these exact three tracks and says they are
"Not re-planned here, just so it is not forgotten."

So two checked-in documents now describe the same open work — one saying it is
deliberately not planning it, the other being the plan — and neither points at the
other. The deferral should become a cross-reference now that the thing it was waiting
for has landed.

### 7. The fixture-mutation convention is unstated and newly load-bearing

Existing fixture tests copy the fixture into `$TestDrive` before generating, which is
why generation has never dirtied the worktree. The design does not state that
convention, and its fixture is the first designed specifically to be written into:
inference materializes commands into a specification that starts empty.

The quality-safeguards work raised the stakes. Initialization now mints a random
identity into any specification that does not already record a valid one, so running
inference in place against a checked-in empty specification would both modify a
tracked file and produce different content on every run. The plan's own test gate —
"no unexpected worktree changes after generation tests" — depends on a convention the
design never names.

Naming it costs one sentence and removes a failure that would otherwise be found by CI
rather than by review.

## Assessment

The three designs are individually coherent and the delivery plan is unusually
concrete about test gates and compatibility constraints. Nothing here is a design
that will not work.

Finding 1 is the one that should be settled before implementation starts. It is not a
wording problem: the fixture as drawn cannot produce the baseline the design asks it to
produce, and fixing it properly means confronting a roadmap item the plan currently
sequences nowhere. Findings 2 and 3 would cost an implementer time in the first two
slices, and both are cheap to correct now.

Findings 4 through 7 are contract and accuracy gaps of the kind that are much cheaper to
close in a design than in the release that inherits them.

## Note on placement

This document sits at the repository root while the equivalent review of the
quality-safeguards work sits at `planning/peer-review.md`. Two files with the same
name in different directories is an avoidable ambiguity; consolidating them under
`planning/`, or giving each a subject-specific name, would be worth doing before a
third review is written.
