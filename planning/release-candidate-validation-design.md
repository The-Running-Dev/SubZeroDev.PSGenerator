# Release-Candidate Validation Design

## Status

Accepted. All findings from independent review are resolved; see
[the peer review](../peer-review.md) and
[the implementation plan](next-engineering-set-implementation-plan.md).

## Purpose

Prove the complete MVP lifecycle from a clean environment before creating a
GitHub release or publishing an immutable package. The validation must exercise
the same source commit that would be released and retain enough evidence to
diagnose a failure.

## Non-goals

- Automatically publish to GitHub Packages.
- Create a permanent release or tag.
- reuse a developer's installed PSGenerator module;
- rely on a warm package, Docker, or PowerShell module cache;
- replace the existing pull-request and release workflows.

An RC is an evidence bundle for a commit, not a prerelease package version.
This avoids versioning ambiguity in PowerShell module manifests and accidental
publication to immutable feeds.

## Entry points

Add:

- `build/Invoke-ReleaseCandidate.ps1` for the reusable orchestration;
- `.github/workflows/release-candidate.yml` for manual hosted validation.

The workflow accepts a Git ref, resolves it to a commit SHA, checks out that
exact commit, and runs the script. It has read-only repository permissions and
no package-write or release-write permission.

## Clean-environment contract

Hosted validation runs on a fresh GitHub-hosted runner. The script additionally
isolates mutable state:

- create a temporary workspace;
- create an isolated `PSModulePath`;
- install required test dependencies at pinned versions;
- use a dedicated NuGet source/configuration;
- use a dedicated Docker build context and uniquely tagged images;
- avoid user-scoped imports;
- clean temporary images, containers, volumes, and directories in `finally`.

Local runs may use installed tools, but the report records detected versions and
whether clean-run guarantees were available.

## Validation phases

### 1. Source and version

- require a clean checked-out commit in hosted runs;
- record repository, ref, SHA, and timestamp;
- validate module manifest and project/package versions;
- ensure a release tag, when supplied, matches `v<ModuleVersion>`;
- reject tracked generated output or forbidden transient files.

### 2. Static quality

- run formatting and analyzer checks;
- run documentation synchronization and link/configuration checks;
- confirm generated files are reproducible and leave no diff;
- validate manifests, workflows, examples, and plugin metadata.

### 3. Unit and integration tests

- run the supported Windows and Linux Pester matrices;
- enforce the packaged-code coverage threshold;
- run fixture-based inspection and generation tests;
- retain NUnit/JUnit and coverage reports.

### 4. Package lifecycle

- build the NuGet/PowerShell package once;
- install it into an isolated module directory;
- start a new PowerShell process with the isolated `PSModulePath`;
- import the installed package;
- verify exported commands and help;
- run a harmless inspection/generation smoke test;
- prove no source-tree module was imported.

### 5. Container MVP lifecycle

Using a representative example:

1. generate the container module;
2. build its image;
3. install the generated PowerShell module from the image;
4. import it in a fresh PowerShell process;
5. invoke a generated command;
6. run `Get-Help` for that command;
7. validate parameter mapping, secret handling, `WhatIf`, and cleanup.

This is the product success criterion and is mandatory for an RC.

### 6. Documentation build

- build the Docusaurus documentation using the repository's supported script;
- verify the configured production base URL;
- archive the static output for inspection;
- do not deploy it.

## Evidence bundle

Write results beneath `artifacts/release-candidate/<sha>/`:

```text
manifest.json
checksums.sha256
environment.json
packages/
test-results/
coverage/
container/
docs/
logs/
```

`manifest.json` records every phase, command abstraction, start/end time, result,
and output path. It must not contain tokens, environment secrets, or complete
machine environment dumps.

Generate SHA-256 checksums for distributable packages and documentation output.
Upload the whole directory as a GitHub Actions artifact with bounded retention.

## Failure behavior

Run independent evidence-producing checks where safe, but do not continue into a
phase whose prerequisites failed. For example, package installation cannot run
after package creation fails.

The script exits nonzero if any required phase fails. Cleanup failures are
reported separately and also fail the run when they leave a security- or
resource-sensitive artifact.

Console output provides a short phase summary. Detailed logs live in the
evidence bundle.

## Reuse and workflow boundaries

Reuse existing scripts and test commands instead of duplicating their logic.
The RC script orchestrates:

- existing CI/quality entry points;
- Pester test configuration;
- package creation and validation;
- existing container end-to-end tests;
- existing documentation build.

If an existing command cannot emit a report or accept isolated paths, extend
that command first rather than copying it into the RC script.

The existing publish workflow remains the only package-publishing path. It may
later require a successful RC check for the same SHA, but that policy change is
separate from this implementation.

### Prerequisite for a future required-check policy

Making an RC check required would mean adding it to the `Main` branch ruleset
(ID `19771450`), the same ruleset the quality-safeguards work configured with
the ten checks required today. That work left one task open:
`planning/quality-safeguards-implementation-plan.md` records that the
post-change ruleset was captured as a hand-written summary rather than the
complete API document, so it cannot be diffed against the pre-change archive,
and `bypass_actors`, `enforcement`, and `conditions` are unverified rather than
confirmed unchanged.

Any change to `required_status_checks` — including adding an RC context —
should close that gap first: archive the ruleset's complete API response
immediately before the write, the same way the pre-change archive was
captured, so the addition can be diffed rather than assumed safe. This is a
prerequisite for the policy change noted above, not part of this design's own
scope.

## Workflow security

- use SHA-pinned third-party actions;
- grant `contents: read`;
- do not grant `packages: write`, `pages: write`, or `id-token: write`;
- pass no registry token unless a test must read a private dependency;
- never run untrusted pull-request code with repository secrets;
- upload reports even after failure using a guarded final step.

## Tests

Add tests for the orchestrator without performing a full release:

- phase ordering and prerequisite skips;
- isolated path construction;
- manifest serialization and redaction;
- checksum generation;
- nonzero exit behavior;
- cleanup on success and failure;
- import-path proof that the installed package, not source, was loaded.

The workflow itself should be syntax-validated in regular CI. A scheduled or
manual real run supplies the final integration proof.

## Delivery slices

1. Add the phase runner, result model, redaction, and evidence manifest tests.
2. Add isolated package build/install/import validation.
3. Integrate the existing container MVP lifecycle and cleanup.
4. Add documentation build, checksums, and artifact assembly.
5. Add the manual read-only workflow and operator documentation.
6. Run an RC for a selected main-branch SHA and record follow-up defects.

## Acceptance criteria

- One command performs the complete validation locally where prerequisites
  exist.
- A manual workflow validates an exact commit on a fresh hosted runner.
- Package import occurs from an isolated installation in a new process.
- The generated module is installed from an image, imported, invoked, and
  documented successfully.
- Documentation builds but is not deployed.
- No package, image, tag, release, or Pages deployment is published.
- A redacted, checksummed evidence bundle is uploaded on success and failure.
- The run is reproducible enough to identify the exact source, tools, and
  outputs used.
