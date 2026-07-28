# Build Output Hygiene Design

## Status

Accepted. Both ignore patterns were exercised against the working tree before
implementation; see Acceptance Criteria.

## Objective

Keep `.NET` build products created by maintained fixtures out of `git status`
without hiding repository-owned source or generated PSModule artifacts.

## Current State

The BuildAgent fixture contains SDK-style projects under
`tests/fixtures/directories/BuildAgent/src`. Running .NET restore, build, or test
can create nested `bin/` and `obj/` directories. No tracked path currently contains
a `bin` or `obj` segment, and `.gitignore` does not cover either directory name.

The repository already ignores its intentional top-level generated outputs:

- `/artifacts/`
- `/examples/Minimal/artifacts/`
- `/docs-template/`

## Design

Add these directory patterns to the root `.gitignore`:

```gitignore
bin/
obj/
```

A pattern without a leading slash applies to matching directories at any depth,
which covers current and future fixture projects. The trailing slash limits each
rule to directories.

Do not add broad extension rules such as `*.dll`, `*.pdb`, or `*.json`. Those can
hide intentional fixtures, schemas, or expected-output files. Do not ignore all
of `tests/fixtures`; source inputs remain reviewable.

## Task Breakdown

1. Add a labeled `.NET build output` section to `.gitignore`.
2. Assert that representative nested fixture paths are ignored:
   - `tests/fixtures/directories/BuildAgent/src/Build/bin/Debug/example.dll`
   - `tests/fixtures/directories/BuildAgent/src/Build/obj/project.assets.json`
3. Assert that fixture `.csproj`, `.nuke/*.json`, and PSModule specification files
   remain visible to Git.
4. Run the relevant .NET or fixture-producing command, when available, and confirm
   the worktree stays clean.
5. Document the rule in the contributor development page only if contributors need
   to distinguish ignored compiler output from generator artifacts.

## Native exit codes

`git check-ignore` reports "nothing ignored" as exit code 1, and that is the
passing outcome for the tracked-path check. The validation script sets
`$ErrorActionPreference` to `Stop`, so it also sets
`$PSNativeCommandUseErrorActionPreference` to `$false` for itself. Without that,
a caller that had turned the preference on — or a future release that changes its
default — would turn the passing exit code into a terminating error before the
script could examine it, failing the gate on the result that means success.

A test invokes the script from a session with the preference enabled, so the
opt-out is demonstrated rather than assumed.

## Acceptance Criteria

- `git check-ignore` identifies nested `bin/` and `obj/` paths through the new
  root patterns.
- No currently tracked path becomes ignored.
- The maintained BuildAgent fixture remains complete and inspectable.
- Generator outputs retain their existing explicit ignore rules.

Both of the first two were checked ahead of implementation by applying the two
patterns through a temporary excludes file: the representative fixture paths above
match, and feeding every tracked path to `git check-ignore` returns nothing.

## Non-goals

- Removing already tracked build products; none currently exist.
- Ignoring PowerShell module packages or documentation artifacts more broadly.
- Changing inspector traversal policy. That is a separate roadmap item even
  though it should independently exclude dependency and generated directories.
