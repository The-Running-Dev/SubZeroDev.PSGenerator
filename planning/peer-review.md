# Peer Review: Quality Safeguards

Independent review of the three quality-safeguard workstreams delivered in pull
request #66, covering the code, the implementation as built, and the design
documents that specify it.

## Scope

Reviewed at commit `ad793ee`, the head of `agent/plan-quality-safeguards`, against
base `8bb4061`.

- [Repository protection design](repository-protection-design.md)
- [Build output hygiene design](build-output-hygiene-design.md)
- [Command collision diagnostics design](command-collision-diagnostics-design.md)
- [Quality safeguards implementation plan](quality-safeguards-implementation-plan.md)
- `src/Private/Get-PSModuleCommandCollision.ps1`,
  `src/Private/ConvertTo-PSModuleManifestSource.ps1`,
  `src/Public/Initialize-PSModuleSpecification.ps1`
- `build/Test-RepositoryHygiene.ps1`, `build/Invoke-Quality.ps1`, `.gitignore`
- `.github/workflows/container.yml`, `.github/workflows/docs.yml`
- `tests/Module.Tests.ps1` and the archived ruleset evidence

## Method

Static review against the live repository, plus the hosted check-run record read
back through the API. The review environment had no PowerShell host and no Docker
daemon, so the suite was not re-executed locally; the hosted run on `ad793ee` is
the execution evidence and every required context passed on it.

## Verified

These claims were checked rather than accepted.

- **The ten required contexts match reality exactly.** Every name recorded in
  [`evidence/main-ruleset-after-required-checks.json`](evidence/main-ruleset-after-required-checks.json)
  matches the corresponding live check-run name character for character,
  including the `caller / job` prefix on the documentation context. Misspelling
  one was the stated failure mode; none is misspelled.
- **Enforcement is proven behaviorally, not assumed.** The archived validation
  records `BLOCKED` while checks were pending and `CLEAN` at ten successes.
- **`Deploy documentation` is correctly excluded.** It reports `skipped` on pull
  requests because its job is gated on a push event, and it is not in the
  required set.
- **Trigger broadening did not broaden publishing.** Both `container.yml` and
  `docs.yml` lost only their `pull_request.paths` filter; each retains its
  `push.branches` and `push.paths` filters, so image publish and documentation
  deploy cadence on `main` is unchanged.
- **Collision detection sits after `ShouldProcess`.** A preview returns before
  candidate discovery, so `-WhatIf` genuinely parses nothing, as designed.
- **The design's ten-item test list is implemented**, including the difficult
  case: a synthetic module carrying import-time sentinel code is placed on
  `PSModulePath`, its declared command is discovered, and the test proves the
  sentinel never ran and the module was never imported.

## Findings

### 1. The specification ID adds no discrimination beyond the module name

`Get-PSModuleSpecificationCandidate.ps1` builds the directory specification with
`Id = "directory.$($moduleName.ToLowerInvariant())"`. The identifier is a pure
function of `ModuleName`.

The self-suppression filter in `Get-PSModuleCommandCollision.ps1` requires the
module name, the `GeneratedBy` marker, and the specification ID to match. Because
the third is derived from the first, that test collapses to two independent facts:
the name matches, and the module carries the generator marker.

The command collision design rests on the opposite claim: "Module name alone does
not prove identity: an unrelated installed module can have the same name and is
exactly the kind of collision this feature should report."

The property actually delivered is narrower. An unrelated **non-generated**
same-name module still warns, which is the common case and works. But two
repositories whose directory names are equal both generate a module named `X`
with `Id = directory.x`. Refreshing one while the other's build is loaded
suppresses every colliding command silently. For a tool whose purpose is
generating modules across many repositories, same-named directories are not an
exotic case.

The gap is visible in coverage as well. Design test item 9 requires proving that
"an unmarked **or differently identified** same-name module still warns."
`tests/Module.Tests.ps1` covers only the unmarked branch, using a bare `.psm1`
with no manifest and therefore no provenance. The differently-identified branch is
untested because it is unreachable through the normal path.

Resolve by choosing one:

- derive `Id` from something that distinguishes directories, so the design's
  stated property becomes true and test item 9 becomes reachable; or
- drop the ID clause from both the detector and the design, and state plainly
  that the marker separates generated modules from non-generated ones only.

The second is smaller and honest. The first is a change to a value written into
every generated manifest, so it is a contract decision rather than a fix.

**Resolved.** The automated review reached the same conclusion independently, and
the first option was taken. The inferred identity is now the module name followed
by a random suffix minted once when the specification is first written, and
initialization reuses whatever valid `Id` an existing specification already
records. Refreshing therefore keeps its identity and stays byte-identical, while
two directories inferring the same module name receive different identities and
warn about each other. A random suffix keeps the documented promise that the
provenance carries no source-directory path or machine-specific value, so a
repository cloned elsewhere still generates the same manifest. Test items 11 and
12 cover both halves.

### 2. The auto-loading preference save and restore is dead ceremony

`Get-PSModuleCommandCollision.ps1` reads `PSModuleAutoLoadingPreference` through
`Get-Variable -Scope Local` before the lookup and restores it in `finally`.

Neither half does anything. The assignment that sets the preference to `None`
carries no scope modifier, so it lands in the function's own scope and cannot
outlive the call; there is nothing to restore. And `-Scope Local` searches only
the function's own scope, where the variable does not yet exist, so the captured
value is always null and the restore branch is unreachable.

That is roughly fifteen lines implying a hazard that does not exist, and the
design mandates it: "The implementation must save and restore
`PSModuleAutoLoadingPreference` in a `finally` block."

The `PSModulePath` save and restore in the same `finally` is a different matter.
That one manipulates a process-wide environment variable and is both necessary and
correctly written. Only the preference handling should be removed, from the code
and from the design sentence that requires it.

### 3. The hygiene gate's success path is one preference flip from failing

`Test-RepositoryHygiene.ps1` pipes every tracked path through `git check-ignore
--stdin`. That command exits **1** when nothing is ignored, which is the passing
outcome, and the script correctly accepts both 0 and 1.

The script also sets `$ErrorActionPreference = 'Stop'`. If
`$PSNativeCommandUseErrorActionPreference` is ever true — set by a caller, or
changed as a future default — a non-zero native exit becomes a terminating error
raised at the pipeline, before the exit-code test can accept it. The gate would
then fail on exactly the result that means success.

The trailing comment shows the author already understood that exit code 1 is the
happy path; this hardens the same insight against a preference the script does not
control. Set `$PSNativeCommandUseErrorActionPreference = $false` beside the
existing preferences.

### 4. The quality gate announces success before the check it added runs

`Invoke-Quality.ps1` prints "PowerShell quality checks passed…" and then invokes
`Test-RepositoryHygiene.ps1`. A hygiene failure therefore emits a green success
banner immediately followed by a throw.

Either move the invocation above the success message, or fold the hygiene result
into a single summary written once both gates have passed.

### 5. The protection design names job identifiers where it means display names

The repository protection design calls the documentation context the fragile one
and explains that its name "is composed from two job names in two files — `verify`
in `docs.yml` and `verify` in `docs-ci.yml`."

Those are job *keys*. The reported context is composed from the `name:` fields:
`Verify documentation` in `docs.yml` and `Verify Documentation Build` in
`docs-ci.yml`. Renaming the keys leaves the context unchanged; renaming the `name:`
values breaks the required check and blocks merging indefinitely.

In a document whose stated purpose is exact naming, this misdirects the precise
rename it exists to warn about. Correct the sentence to name the display fields.

### 6. Two planning documents describe a state that no longer exists

The repository protection design states in the present tense that the ruleset
"does not require status checks" and "still has no required status-check rule."
The implementation plan's "Already Verified" section likewise reports the live
readback as confirming "no required checks," and instructs the reader to "archive
the ruleset again immediately before writing."

All were true before implementation and are false now; the same pull request's own
evidence file records the ten contexts and strict freshness. Neither passage is
marked as a pre-change snapshot, and both read as current fact.

This cuts against the repository's own durable lesson about not writing remembered
values as facts. Mark these sections explicitly as the pre-change state, or restate
them in the past tense with a pointer to the completion evidence.

### 7. The after-evidence is not comparable to the before-evidence

The implementation plan's administrative task reads "Read back and **diff** the
resulting repository and ruleset configuration," and is checked off.

The two archived artifacts are not of the same kind.
`main-ruleset-before-required-checks.json` is the complete ruleset document as the
API returned it. `main-ruleset-after-required-checks.json` is a hand-shaped
summary. It omits `bypass_actors`, `enforcement`, and `conditions` — precisely the
settings the design promises to preserve when it requires that the implementation
"preserve every existing ruleset condition, rule, parameter, and bypass setting."

The summary is useful and its `EnforcementValidation` block is the strongest
evidence in the set. But the diff the task claims cannot be reproduced from the
archive. Store the raw post-change ruleset document alongside the summary.

## Missed by this review

Recorded so the gap in this pass is visible rather than quietly absorbed.

The automated review found a staleness bug this review did not report. The parsed
available-command index was cached against the `PSModulePath` string alone and
held in module scope, so a module installed, removed, or edited beneath a root
that did not itself change left the diagnostics reporting the previous state for
the life of the session — newly available collisions missed, withdrawn exports
still warned about.

It is now cached against the full path, length, and write time of the manifests it
was built from. Locating those files is cheap and parsing them is not, so the
inventory runs every call while only the expensive step is cached. Test item 13
covers it.

Two further observations from the automated review were considered and not acted
on. Clearing the process-wide `PSModulePath` for the duration of the candidate
loop is real, and is the reason the restore sits in a `finally`; removing the
mutation entirely would mean giving up the second barrier that keeps `Get-Command`
from analyzing an installed module, which is a larger change than the exposure
warrants. The objection to absolute pull-request links is not a rule this
repository holds: a pull request has no relative form, and `TODO.md` already links
to one absolutely.

## Assessment

None of these is a live defect. The hosted run is green on all ten required
contexts, and the safeguards do what the pull request says they do.

Finding 1 was the only one with behavioral consequence: a safety property the
design states explicitly and the implementation could not deliver, with the
corresponding test case reduced to the half that passes. It is resolved above,
along with the index staleness the automated review caught.

Findings 3 and 4 are cheap hardening of the new build tooling. Findings 5 through 7
are accuracy corrections to documents whose entire value is being exact about
names, state, and evidence. All five remain open.
