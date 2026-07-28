# Repository Protection Design

## Status

Proposed.

## Objective

Make the existing quality gates enforceable on `main` and remove merged remote
branches automatically, without creating required checks that some pull requests
can never satisfy.

## Current State

The repository-level `Main` ruleset is active for the default branch. It currently:

- blocks branch deletion and non-fast-forward pushes;
- requires pull requests;
- requires review-thread resolution;
- permits squash and rebase merges; and
- has no bypass actors.

It does not require status checks. Repository setting `delete_branch_on_merge` is
reported as `false`.

Both of those are from the settings interface rather than an API export, and the
observed branch behavior does not entirely agree: after the recent cleanup, #62's
head branch went automatically while `feature/replace-docs-workflow` remained.
Treat this section as the working assumption. The archived export in the
administrative step is what confirms it, and it must be read before anything is
written.

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

A GitHub Container Registry package is private by default. If that package is
private, the documentation context cannot pass on a fork pull request, and making
it required would block every external contribution behind a red check with no
self-evident cause. Confirm the package is publicly readable as part of the
workflow change, before the context becomes required.

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

Set repository `delete_branch_on_merge` to `true`. This is independent of the
ruleset and affects future merged pull requests only. It must not delete local
branches or branches that are not merged.

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
the archived pre-change document. The only expected setting changes are the new
required-check rule and `delete_branch_on_merge = true`.

The fork path cannot be exercised this way. A temporary pull request from this
repository carries `secrets.REGISTRY_TOKEN`, so it proves nothing about a fork.
Check the package's visibility directly instead — an anonymous pull of
`ghcr.io/the-running-dev/docs-template`, or the package settings page.

## Rollback

Restore the archived ruleset JSON and set `delete_branch_on_merge` back to
`false`. Workflow trigger broadening can be reverted independently if check
enforcement is removed first.

## Non-goals

- Requiring the skipped `Deploy documentation` job.
- Changing approval counts or adding bypass actors.
- Changing package or container publishing cadence.
- Deleting existing branches as part of enabling automatic future cleanup.
