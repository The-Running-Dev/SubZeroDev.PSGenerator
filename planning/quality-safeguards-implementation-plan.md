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

Deliver the work as small, ordered pull requests. Repository settings are applied
only after the workflow change that makes every required context available.

### PR 1: Make required checks universally available

Tasks:

- [ ] Remove `pull_request.paths` from `container.yml`.
- [ ] Remove `pull_request.paths` from `docs.yml`.
- [ ] Preserve path-filtered `main` push behavior.
- [ ] Confirm the `ghcr.io/the-running-dev/docs-template` package is publicly
  readable, so the documentation context can pass without repository secrets.
- [ ] Confirm all ten intended checks appear on a pull request containing only a
  planning or Markdown change.
- [ ] Confirm documentation deployment remains skipped on pull requests.
- [ ] Record observed context names and GitHub Actions integration ID in the PR.

Exit criteria:

- Every pull request creates all ten future required contexts.
- A fork pull request can pull the documentation base image.
- All existing workflows pass on Windows and Linux where applicable.

### Administrative change: Enforce checks and branch cleanup

Depends on PR 1 being merged.

Tasks:

- [ ] Export the complete current `Main` ruleset JSON.
- [ ] Export the current repository merge settings.
- [ ] Enable `delete_branch_on_merge`.
- [ ] Add the ten GitHub Actions contexts to `required_status_checks`.
- [ ] Enable strict required-check freshness.
- [ ] Preserve deletion, non-fast-forward, pull-request, review-thread, merge-method,
  condition, and bypass settings.
- [ ] Read back and diff the resulting repository and ruleset configuration.
- [ ] Validate blocking, success, and automatic branch deletion with a temporary PR.

Exit criteria:

- A failing or pending required check blocks merge.
- Ten successful checks permit merge when review threads are resolved.
- The merged remote head branch is deleted automatically.

### PR 2: Ignore .NET fixture output

Tasks:

- [ ] Add `bin/` and `obj/` directory rules to `.gitignore`.
- [ ] Add focused `git check-ignore` validation to the repository quality tests or
  a small build validation script.
- [ ] Verify no tracked source path is hidden.
- [ ] Run the relevant fixture build and confirm no untracked compiler output.

Exit criteria:

- Nested fixture build output stays out of `git status`.
- Fixture inputs remain tracked and discoverable.

### PR 3: Add inferred-command collision warnings

Tasks:

- [ ] Add a private collision discovery helper that returns data and writes no
  warnings. It is not side-effect-free: `Get-Command` may import installed
  modules, which the design accepts in exchange for complete detection.
- [ ] Exclude existing commands belonging to the scaffolded module, so refreshing
  a directory whose generated module is installed stays quiet.
- [ ] Invoke it from `Initialize-PSModuleSpecification` after candidate inference,
  leaving `-WhatIf` with no collision reporting.
- [ ] Emit one stable advisory warning per colliding candidate.
- [ ] Preserve candidate names and deterministic specification output.
- [ ] Add Windows/Linux Pester coverage for collision, no-collision, ordering,
  self-collision, `-WhatIf`, and determinism cases.
- [ ] Cover the helper's identity-formatting and no-collision branches so the
  packaged coverage gate does not regress.
- [ ] Update script-inference and troubleshooting documentation.

Exit criteria:

- `convertto-json.ps1` warns about the built-in `ConvertTo-Json`.
- Refreshing a directory whose generated module is already loaded warns about
  nothing.
- The inferred command remains in the specification.
- Full local and hosted quality gates pass, including packaged coverage.

## Dependency Order

```text
PR 1: workflow availability
  └─ administrative ruleset/settings change

PR 2: build-output hygiene
PR 3: collision warnings
```

PR 2 and PR 3 can proceed independently. The administrative repository change
must wait for PR 1.

## Validation Matrix

| Workstream | Local validation | Hosted validation |
| --- | --- | --- |
| Workflow availability | Workflow syntax and path review | All ten checks appear and pass; base image pullable anonymously |
| Repository settings | API readback and JSON diff | Required-check block/pass exercise |
| Build-output hygiene | `git check-ignore`, fixture build, clean status | Existing quality and Pester jobs |
| Collision warnings | Focused and full Pester suites | Windows and Linux Pester jobs |

## Already Verified

Checked against the repository before implementation, so it does not need
rediscovering:

- The path-filter premise, from real check runs. A planning-only pull request
  reports eight contexts; a pull request touching `src/`, `docs/`, and `README.md`
  reports all ten, matching the recorded names exactly.
- The two `.gitignore` patterns, through a temporary excludes file. No tracked
  path becomes ignored.
- The collision mechanics. `convertto-json.ps1` infers `ConvertTo-Json`, and
  `Get-Command` returns one cmdlet from `Microsoft.PowerShell.Utility`, which
  supplies every field the warning text needs.
- The warning site. `Initialize-PSModuleDirectory` delegates to
  `Initialize-PSModuleSpecification`, so one call site covers both entry points.

Still unverified: the current `Main` ruleset contents and
`delete_branch_on_merge`. Both need the administrative export above, which is why
that step exports before it writes.

## Completion Evidence

Update `TODO-Next.md` as each workstream finishes. Link merged pull requests and
record the final ruleset ID, required contexts, and repository setting readback.
Do not mark repository protection complete from a documentation-only change.
