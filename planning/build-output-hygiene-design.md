# Build Output Hygiene Design

## Status

Proposed.

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

## Acceptance Criteria

- `git check-ignore` identifies nested `bin/` and `obj/` paths through the new
  root patterns.
- No currently tracked path becomes ignored.
- The maintained BuildAgent fixture remains complete and inspectable.
- Generator outputs retain their existing explicit ignore rules.

## Non-goals

- Removing already tracked build products; none currently exist.
- Ignoring PowerShell module packages or documentation artifacts more broadly.
- Changing inspector traversal policy. That is a separate roadmap item even
  though it should independently exclude dependency and generated directories.
