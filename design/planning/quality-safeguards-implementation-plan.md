# Quality Safeguards Implementation Plan

## Scope

This plan implements the three highest-value follow-ups identified after Version 1:

1. enforce repository quality gates and automatically delete merged head branches;
2. ignore nested `.NET` `bin/` and `obj/` build output; and
3. warn when inferred commands shadow existing PowerShell commands.

Detailed decisions live in:

- [Repository protection design](repository-protection-design.md)
- [Build output hygiene design](build-output-hygiene-design.md)
- [Command collision diagnostics design](command-collision-diagnostics-design.md)

## Delivery Strategy

Implement all three workstreams in PR
[#66](https://github.com/The-Running-Dev/SubZeroDev.PSGenerator/pull/66) as one
review unit. Apply repository settings only after the workflow commit proves
that every required context is available and green.

### Workstream 1: Make required checks universally available

Tasks:

- [x] Remove `pull_request.paths` from `container.yml`.
- [x] Remove `pull_request.paths` from `docs.yml`.
- [x] Preserve path-filtered `main` push behavior.
- [x] Confirm all ten intended checks appear on PR #66 after trigger broadening.
- [x] Confirm documentation deployment remains skipped on pull requests.
- [x] Record observed context names and GitHub Actions integration ID in the PR.

Exit criteria:

- Every pull request creates all ten future required contexts.
- All existing workflows pass on Windows and Linux where applicable.

### Administrative change: Enforce checks and verify branch cleanup

Depends on Workstream 1 producing all ten green contexts.

Tasks:

- [x] Archive the complete current `Main` ruleset JSON immediately before writing.
- [x] Read the current repository merge settings through the API.
- [x] Verify `delete_branch_on_merge = true`. It was enabled by the repository
  owner independently and must be preserved.
- [x] Add the ten GitHub Actions contexts to `required_status_checks`.
- [x] Enable strict required-check freshness.
- [x] Preserve deletion, non-fast-forward, pull-request, review-thread, merge-method,
  condition, and bypass settings.
- [x] Read back the resulting repository and ruleset configuration and record the
  required contexts, integration ID, strict freshness, preserved rule types, and
  pull-request parameters as a summary.
- [ ] Archive the complete post-change ruleset document beside that summary. The
  summary is not comparable with the pre-change archive, which is the full API
  response, so the two cannot be diffed. `bypass_actors`, `enforcement`, and
  `conditions` are absent from the summary and are exactly the settings this
  change promises to preserve.
- [x] Validate pending-check blocking and successful-check release on PR #66.
- [ ] Confirm automatic remote branch deletion after PR #66 is eventually merged.

Exit criteria:

- A failing or pending required check blocks merge.
- Ten successful checks permit merge when review threads are resolved.
- The merged remote head branch is deleted automatically.

### Workstream 2: Ignore .NET fixture output

Tasks:

- [x] Add `bin/` and `obj/` directory rules to `.gitignore`.
- [x] Add focused `git check-ignore` validation to the repository quality tests or
  a small build validation script.
- [x] Verify no tracked source path is hidden.
- [x] Build the fixture's `Common.csproj` and confirm no untracked compiler output.

Exit criteria:

- Nested fixture build output stays out of `git status`.
- Fixture inputs remain tracked and discoverable.

### Workstream 3: Add inferred-command collision warnings

Tasks:

- [x] Add a private collision discovery helper that returns data and writes no
  warnings or imports. Inspect current-session commands with module auto-loading
  disabled and `PSModulePath` temporarily removed, then merge literal exports read
  directly from conventional module manifests.
- [x] Add generated-manifest provenance containing the generator marker and
  specification ID.
- [x] Exclude only an earlier generated module whose name, generator marker, and
  specification ID match, so unrelated same-name modules still warn.
- [x] Invoke it from `Initialize-PSModuleSpecification` after candidate inference,
  leaving `-WhatIf` with no collision reporting.
- [x] Emit one stable advisory warning per colliding candidate.
- [x] Preserve candidate names and deterministic specification output.
- [x] Add Windows/Linux Pester coverage for collision, no-collision, ordering,
  proven self-collision, unrelated same-name modules, non-importing static
  discovery, `-WhatIf`, and determinism cases.
- [x] Cover the helper's identity-formatting and no-collision branches so the
  packaged coverage gate does not regress.
- [x] Update script-inference and troubleshooting documentation.
- [x] Give the inferred specification a durable random identity, preserved across
  refreshes, so two directories inferring the same module name stay
  distinguishable.
- [x] Cache the parsed manifest index against manifest path, length, and write
  time rather than the `PSModulePath` string, so an installed, removed, or edited
  module is not missed for the life of the session.

Exit criteria:

- `convertto-json.ps1` warns about the built-in `ConvertTo-Json`.
- Refreshing a directory whose generated module is already loaded warns about
  nothing.
- Collision discovery imports or executes no available module.
- An unrelated same-name module is not mistaken for the generated module.
- The inferred command remains in the specification.
- Full local and hosted quality gates pass, including packaged coverage.

## Dependency Order

```text
Workflow availability
  └─ administrative ruleset/settings change

Build-output hygiene
Collision warnings
```

Build-output hygiene and collision warnings are independent workstreams bundled
into PR #66. The administrative repository change waited for the workflow
availability run to expose and pass all ten contexts.

## Validation Matrix

| Workstream | Local validation | Hosted validation |
| --- | --- | --- |
| Workflow availability | Workflow syntax and path review | All ten checks appear and pass; base image pullable anonymously |
| Repository settings | API readback and recorded summary | Required-check block/pass exercise |
| Build-output hygiene | `git check-ignore`, fixture build, clean status | Existing quality and Pester jobs |
| Collision warnings | Focused and full Pester suites | Windows and Linux Pester jobs |

## Verified Before Implementation

Checked against the repository before implementation, so it did not need
rediscovering. Recorded in the past tense because the repository has since
changed; see Completion Evidence for the state that followed.

- The path-filter premise, from real check runs. A planning-only pull request
  reported eight contexts; a pull request touching `src/`, `docs/`, and
  `README.md` reported all ten, matching the recorded names exactly.
- The two `.gitignore` patterns, through a temporary excludes file. No tracked
  path became ignored.
- The collision mechanics. `convertto-json.ps1` infers `ConvertTo-Json`, and
  the manifest for `Microsoft.PowerShell.Utility` declares
  `ConvertTo-Json`, which supplied every field the warning text needs without
  analyzing or importing the module.
- The warning site. `Initialize-PSModuleDirectory` delegates to
  `Initialize-PSModuleSpecification`, so one call site covers both entry points.
- The documentation base image is publicly readable. An anonymous registry token
  read its manifest, while the same request for an inaccessible package was
  refused. Fork pull requests are not blocked by it.

The live API readback confirmed ruleset `Main` (ID `19771450`) contained deletion,
non-fast-forward, and pull-request rules with no bypass actors and no required
checks. It also confirmed `delete_branch_on_merge = true`, merge commits disabled,
and squash and rebase enabled. The ruleset was to be archived again immediately
before writing, so concurrent changes could not be lost.

## Completion Evidence

Implementation and validation are recorded in PR
[#66](https://github.com/The-Running-Dev/SubZeroDev.PSGenerator/pull/66).
Ruleset `Main` remains ID `19771450`; its before/after API evidence is archived
under [`design/planning/evidence`](evidence/). The hosted implementation run exposed
and passed all ten required contexts on Windows and Linux. Automatic branch
deletion can only be observed after the pull request is merged.

The two archived artifacts are not of the same kind.
`main-ruleset-before-required-checks.json` is the complete API response;
`main-ruleset-after-required-checks.json` is a summary, and its
`EnforcementValidation` block — pending checks producing `BLOCKED`, ten successful
checks producing `CLEAN` — is the strongest evidence in the set. Until the raw
post-change document is archived beside it, preservation of `bypass_actors`,
`enforcement`, and `conditions` rests on the write having sent the existing rules
back unchanged, not on a readback that shows it.
