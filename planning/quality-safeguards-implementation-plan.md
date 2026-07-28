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
- [ ] Confirm all ten intended checks appear on a pull request containing only a
  planning or Markdown change.
- [ ] Confirm documentation deployment remains skipped on pull requests.
- [ ] Record observed context names and GitHub Actions integration ID in the PR.

Exit criteria:

- Every pull request creates all ten future required contexts.
- All existing workflows pass on Windows and Linux where applicable.

### Administrative change: Enforce checks and verify branch cleanup

Depends on PR 1 being merged.

Tasks:

- [ ] Archive the complete current `Main` ruleset JSON immediately before writing.
- [x] Read the current repository merge settings through the API.
- [x] Verify `delete_branch_on_merge = true`. It was enabled by the repository
  owner independently and must be preserved.
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
  warnings or imports. Inspect current-session commands with module auto-loading
  disabled and `PSModulePath` temporarily removed, then merge literal exports read
  directly from conventional module manifests.
- [ ] Add generated-manifest provenance containing the generator marker and
  specification ID.
- [ ] Exclude only an earlier generated module whose name, generator marker, and
  specification ID match, so unrelated same-name modules still warn.
- [ ] Invoke it from `Initialize-PSModuleSpecification` after candidate inference,
  leaving `-WhatIf` with no collision reporting.
- [ ] Emit one stable advisory warning per colliding candidate.
- [ ] Preserve candidate names and deterministic specification output.
- [ ] Add Windows/Linux Pester coverage for collision, no-collision, ordering,
  proven self-collision, unrelated same-name modules, non-importing static
  discovery, `-WhatIf`, and determinism cases.
- [ ] Cover the helper's identity-formatting and no-collision branches so the
  packaged coverage gate does not regress.
- [ ] Update script-inference and troubleshooting documentation.

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
  the manifest for `Microsoft.PowerShell.Utility` declares
  `ConvertTo-Json`, which supplies every field the warning text needs without
  analyzing or importing the module.
- The warning site. `Initialize-PSModuleDirectory` delegates to
  `Initialize-PSModuleSpecification`, so one call site covers both entry points.
- The documentation base image is publicly readable. An anonymous registry token
  reads its manifest, while the same request for an inaccessible package is
  refused. Fork pull requests are not blocked by it.

The live API readback confirms ruleset `Main` (ID `19771450`) contains deletion,
non-fast-forward, and pull-request rules with no bypass actors and no required
checks. It also confirms `delete_branch_on_merge = true`, merge commits disabled,
and squash and rebase enabled. Archive the ruleset again immediately before
writing so concurrent changes cannot be lost.

## Completion Evidence

Update `TODO-Next.md` as each workstream finishes. Link merged pull requests and
record the final ruleset ID, required contexts, and repository setting readback.
Do not mark repository protection complete from a documentation-only change.
