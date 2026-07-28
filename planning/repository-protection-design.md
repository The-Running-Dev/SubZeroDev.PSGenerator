# Repository Protection Design

## Status

Accepted. Strict required-check freshness is kept, and the documentation base
image was confirmed publicly readable, so the fork concern below is closed
rather than open.

## Objective

Make the existing quality gates enforceable on `main` and preserve automatic
merged-branch cleanup, without creating required checks that some pull requests
can never satisfy.

## Current State

The repository-level `Main` ruleset is active for the default branch. It currently:

- blocks branch deletion and non-fast-forward pushes;
- requires pull requests;
- requires review-thread resolution;
- permits squash and rebase merges; and
- has no bypass actors.

It does not require status checks.

`delete_branch_on_merge` has since been enabled by the repository owner, ahead of
the administrative step and independently of the ruleset. A live API readback
confirms it is `true`. Repository merge settings also confirm merge commits are
disabled while squash and rebase are enabled.

The live ruleset is repository ruleset `Main`, ID `19771450`. It targets the
default branch, has active enforcement and no bypass actors, and contains
deletion, non-fast-forward, and pull-request rules. It still has no required
status-check rule. Export the complete document again immediately before any
write so a concurrent settings change is not overwritten.

Six jobs in `.github/workflows/test.yml` run for every pull request. Two of them
are matrixed over Windows and Linux, so they report eight check contexts:

1. `PowerShell 7.4 baseline (ubuntu-latest)`
2. `PowerShell 7.4 baseline (windows-latest)`
3. `PowerShell quality`
4. `Documentation links and terminology`
5. `Pester (ubuntu-latest)`
6. `Pester (windows-latest)`
7. `PowerShell NuGet package`
8. `Container end-to-end`

Two additional gates are path-filtered:

9. `Build and publish image` in `container.yml`
10. `Verify documentation / Verify Documentation Build` through `docs.yml`

GitHub does not create a check context when a workflow is excluded by an event
path filter. Requiring either path-filtered context now would leave unrelated pull
requests permanently waiting for a check that will never exist.

This is observed, not inferred. Pull request #66 changes only `TODO-Next.md` and
`planning/`, and reports exactly the eight `test.yml` contexts; neither
path-filtered context appears. Pull request #62 touches `src/`, `docs/`, and
`README.md`, and reports all ten, with the names above matching character for
character, including the `caller / job` prefix on the documentation context.

Pull request #62 also shows `Deploy documentation` present as a check context with
conclusion `skipped`, which is why it stays out of the required set: a rule should
not depend on how a skipped conclusion is counted.

Context ten is the fragile one. Its name is composed from two job names in two
files — `verify` in `docs.yml` and `verify` in `docs-ci.yml` — so renaming either
changes the reported context. The old required name would then remain expected and
block merging indefinitely. Renaming either job means updating the ruleset in the
same change.

## Design

### Stable check availability

Before changing the ruleset, make all ten required contexts appear on every pull
request:

- remove only the `pull_request.paths` filter from `container.yml`;
- remove only the `pull_request.paths` filter from `docs.yml`;
- retain the existing `push.branches` and `push.paths` filters so publishing and
  deployment behavior on `main` does not broaden; and
- retain the documentation deploy job's push-only condition.

This deliberately pays the cost of a container and documentation verification on
every pull request. The alternative—conditional jobs or path-filtered workflows—
creates ambiguous skipped or absent contexts and weakens the branch rule.

### Fork pull requests

This repository is public and allows forks. A pull request from a fork receives
no repository secrets, so `secrets.REGISTRY_TOKEN` is empty and the documentation
workflows fall back to the fork's read-only `github.token` to pull their base
image, `ghcr.io/the-running-dev/docs-template`.

A GitHub Container Registry package is private by default. If that package were
private, the documentation context could not pass on a fork pull request, and
making it required would block every external contribution behind a red check with
no self-evident cause.

That package is public. An anonymous registry token fetches its `latest` manifest
successfully, while the same request for an inaccessible package is refused, so
the result is a real read rather than a permissive default. The fork path is
therefore safe today.

What remains is a constraint, not a task: `ghcr.io/the-running-dev/docs-template`
must stay publicly readable for as long as the documentation context is required.
Making it private would not fail visibly here — it would fail only on fork pull
requests, which this repository does not currently receive.

Nothing equivalent applies to the container context. `container.yml` builds and
smoke-tests locally, and its registry login and push steps are already skipped for
`pull_request` events.

### Required status checks

After a pull request proves all ten contexts are present, add a
`required_status_checks` rule to ruleset `Main`:

- require the ten contexts listed above;
- bind each context to the GitHub Actions integration (`app.id = 15368`);
- enable strict branch freshness so the pull request head must be tested against
  the current target branch; and
- preserve every existing ruleset condition, rule, parameter, and bypass setting.

Strict freshness multiplies the per-pull-request cost accepted above: every merge
to `main` invalidates every other open pull request and re-runs all ten contexts,
including the container build. That is affordable at the current volume, where one
or two pull requests are open at a time, and it is the setting to reconsider first
if concurrent work grows.

Ruleset updates replace the submitted rule collection. The implementation must
read and archive the complete current JSON before writing it, then send the
existing rules plus the new status-check rule. A partial update could silently
remove protections.

### Automatic branch deletion

Preserve repository `delete_branch_on_merge = true`. This is independent of the
ruleset, was enabled separately by the owner, and must not be changed by either
the required-check implementation or its rollback. It affects future merged pull
requests only and does not delete local or unmerged branches.

## Validation

Use a temporary pull request whose files do not match the former container or
documentation path filters. Confirm:

- all ten contexts are created;
- the branch is blocked while a required context is pending or failing;
- the branch becomes mergeable when all ten pass;
- review-thread resolution remains required;
- squash and rebase remain the only ruleset-allowed merge methods; and
- the remote head branch disappears after merge.

Read the repository and ruleset back through the GitHub API and compare them with
the archived pre-change document. The only expected setting change is the new
required-check rule. `delete_branch_on_merge` must remain `true`.

The fork path cannot be exercised this way. A temporary pull request from this
repository carries `secrets.REGISTRY_TOKEN`, so it proves nothing about a fork.
Package visibility is checked directly instead, and already has been: an anonymous
registry token reads the `docs-template` manifest. Re-run that check if the
package's visibility is ever changed.

## Rollback

Restore the archived ruleset JSON while preserving
`delete_branch_on_merge = true`. Workflow trigger broadening can be reverted
independently if check enforcement is removed first.

## Non-goals

- Requiring the skipped `Deploy documentation` job.
- Changing approval counts or adding bypass actors.
- Changing package or container publishing cadence.
- Changing the existing automatic branch-deletion setting.
- Deleting existing branches as part of enabling automatic future cleanup.
