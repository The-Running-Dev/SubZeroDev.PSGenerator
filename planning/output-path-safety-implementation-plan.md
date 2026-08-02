# Generated Output Path Safety Implementation Plan

## Purpose

Implement the contract in
[output-path-safety-design.md](output-path-safety-design.md) as one focused,
reviewable feature.
The feature prevents accidental recursive deletion through `Build-PSModule -Output`
while preserving deterministic replacement of intentional generated output.

## Scope

This plan covers:

- source-aware and symlink-aware hard path denials;
- existing-directory ownership classification;
- a deterministic output marker;
- an explicit force path for unowned output;
- forwarding from directory initialization;
- package validation;
- unit, integration, documentation, and cross-platform validation.

It does not implement transactional output swaps, `Build-PSModule -WhatIf`, or the
Docker-BuildAgent roadmap work. Those remain independent follow-ups.

## Preconditions

Before implementation:

1. Confirm the worktree contains no unrelated changes that overlap the listed files.
2. Create a dedicated `feature/` branch using the repository's normal workflow.
3. Read `AGENTS.md` and preserve its authorship and validation requirements.
4. Confirm the current baseline manifest imports on PowerShell 7.4.
5. Run or record the current focused output-reset tests before editing.
6. Verify the exact behavior of `Resolve-PSModuleInspectionRealPath` for:
   - ordinary directories;
   - missing leaves;
   - symbolic links;
   - Windows junctions;
   - volume roots and doubled separators; and
   - the repository's Dropbox-backed path.
7. Do not use real user directories, roots, or paths outside Pester `TestDrive` for
   mutation experiments.
8. Land Phase 0 before anything else. The resolver defect it fixes is a prerequisite,
   not a cleanup, and every later comparison depends on it.

## File impact map

### New private source

| File | Responsibility |
| --- | --- |
| `src/Private/Test-PSModulePathAncestor.ps1` | Boundary-aware path ancestry comparison. |
| `src/Private/Test-PSModuleOutputOwnership.ps1` | Missing/empty/owned/legacy/unowned classification. |
| `src/Private/Assert-PSModuleOutputPath.ps1` | Hard denials and force-policy enforcement. |
| `src/Private/Write-PSModuleOutputMarker.ps1` | Canonical marker creation. |

The module bootstrap dot-sources every private `.ps1`, so no loader or manifest entry is
needed for these helpers.

### Modified runtime source

| File | Change |
| --- | --- |
| `src/Public/Build-PSModule.ps1` | Add and document `-Force`; store intent in context. |
| `src/Public/Initialize-PSModuleDirectory.ps1` | Add `-ForceOutput`; forward to build. |
| `src/Private/New-PSModuleBuildContext.ps1` | Add `ForceOutputReset = $false`. |
| `src/Private/Reset-PSModuleOutput.ps1` | Assert, classify, re-check, reset, and mark. |
| `src/Private/Complete-PSModulePackage.ps1` | Require and validate `Metadata/output.json`. |
| `src/Private/Resolve-PSModuleInspectionRealPath.ps1` | Fix the discarded `RemoveEmptyEntries` split (Phase 0). |
| `src/Private/Test-PSModuleInspectionPath.ps1` | Fix the same split pattern (Phase 0). |
| `src/Private/Write-PSModuleCommandSource.ps1` | Refuse to copy the scripts tree into a destination inside itself. |

### Tests

Primary changes belong in `tests/Module.Tests.ps1` near:

- module parameter/export tests;
- container module build-context tests;
- container module output-reset tests;
- `Initialize-PSModuleDirectory` tests; and
- package-completion boundary tests.

Add a separate test file only if the path matrix makes `Module.Tests.ps1` materially
harder to navigate. If split, use `tests/OutputPathSafety.Tests.ps1` and keep shared
fixture creation local to that file rather than introducing global test state.

### Documentation

| File | Change |
| --- | --- |
| `Specifications.md` | Refine overwrite contract and add marker to package tree. |
| `docs/docs/using/generated-output.md` | Explain ownership states, marker, and force. |
| `docs/docs/using/troubleshooting.md` | Add recovery for every rejection category. |
| `docs/docs/developing/overview.md` | Describe the guarded reset boundary. |
| `docs/docs/developing/security.md` | Explain hard denials and force limitations. |

Update `README.md` only if its first-build example needs a user-visible note. Avoid
expanding the homepage with internal details.

## Implementation sequence

### Phase 0: Fix the shared path-splitting defect

Both `Resolve-PSModuleInspectionRealPath` and `Test-PSModuleInspectionPath` call:

```powershell
.Split(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar,
    [StringSplitOptions]::RemoveEmptyEntries
)
```

`String` exposes no `Split(char, char, StringSplitOptions)` overload. PowerShell binds
`Split(char[])`, coercing `RemoveEmptyEntries` to `(char) 1` and treating it as a third
separator, so the option is silently discarded.

Replace both with an explicit array so the options argument selects
`Split(char[], StringSplitOptions)`:

```powershell
.Split(
    [char[]] @([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar),
    [StringSplitOptions]::RemoveEmptyEntries
)
```

Add resolver tests, using IDs from the `RP` table below, before touching output safety.
Expect at least one behavior change to fall out: with empty segments removed, a volume
root no longer regains its trailing separator through `Join-Path`, so the resolver's
root handling must be made explicitly canonical rather than accidentally correct.

Re-run the existing inspection suites. `Test-PSModuleInspectionPath` builds prefixes by
trimming and re-appending a separator, so it should be unaffected, but that must be
demonstrated rather than assumed.

Exit criteria:

- both call sites pass an explicit `[char[]]`;
- doubled separators and roots produce no empty segments;
- the resolver returns one canonical form per input; and
- all pre-existing inspection tests still pass unchanged.

### Phase 1: Lock the current contract with focused tests

Add failing tests before changing reset behavior.

#### 1.1 Public parameter tests

Assert:

- `Build-PSModule` declares a switch parameter named `Force`;
- `Initialize-PSModuleDirectory` declares a switch parameter named `ForceOutput`;
- public exports remain unchanged; and
- comment-based help contains a parameter record for each switch.

#### 1.2 Build-context default

Extend the build-context test to assert:

```powershell
$context.ForceOutputReset | Should -BeFalse
```

Add a focused construction test proving no output directory or marker is created while
the context is constructed. Context creation remains non-mutating.

#### 1.3 Hard-denial test harness

Create a helper local to the test scope that:

- creates a valid minimal specification beneath a synthetic repository root;
- places a sentinel file in the source tree;
- invokes `Build-PSModule` with the selected output;
- asserts the expected terminating exception; and
- verifies the sentinel and specification bytes remain unchanged.

Use this harness for source root, source parent, specification parent, and force-bypass
attempts. Filesystem-root tests must only assert early failure; never place or remove a
sentinel at a real root.

#### 1.4 Ownership-state test harness

Create small fixture helpers for:

- exact marker-owned output;
- valid legacy output;
- malformed marker;
- unowned non-empty output; and
- empty output including hidden-content distinctions.

Keep fixtures deterministic and entirely beneath `TestDrive`.

Exit criteria:

- tests accurately express the design decisions;
- failures occur for missing implementation, not malformed fixtures; and
- no test risks deleting a path outside `TestDrive`.

### Phase 2: Implement path relationship primitives

#### 2.1 `Test-PSModulePathAncestor`

Implementation rules:

1. Require non-empty absolute path inputs.
2. Normalize with `GetFullPath` once, before any trimming.
3. Trim both directory separator variants, for comparison only.
4. Add one platform directory separator to the candidate ancestor.
5. Compare with the supplied or platform-selected `StringComparison`.
6. Return false for equality; callers test equality separately.
7. Do not touch the filesystem.

Never feed a trimmed value back through `GetFullPath`. On Windows a bare drive
designator is process-relative, not a root: with the process on `D:\Dropbox\Projects`,
`[IO.Path]::GetFullPath('D:')` returns `D:\Dropbox\Projects`, not `D:\`. Trimming
`D:\` to `D:` and re-normalizing therefore silently retargets the comparison at the
current directory. Normalize first, trim last, and keep the trimmed form inside the
comparison only.

Tests:

- direct parent and multiple-level ancestor;
- sibling-prefix collision such as `repo` versus `repository`;
- equal paths;
- root behavior, including a bare drive designator that must not be re-normalized;
- trailing separators;
- alternate separators where supported;
- Windows/macOS case folding and Linux ordinal behavior.

#### 2.2 Reuse real-path resolution

Do not create a second link resolver. Call `Resolve-PSModuleInspectionRealPath`, now
carrying the Phase 0 fix, and add focused tests only where output safety exposes a
missing behavior.

Root detection must not assume the resolver preserves a trailing separator. Compare the
normalized target against its own normalized `GetPathRoot` through the same
trim-for-comparison helper used everywhere else, so `C:\`, `\\server\share`, and `/`
each classify as a root regardless of which side carries the separator.

If the resolver cannot distinguish an actual link from a cloud-provider reparse point,
use `Directory.ResolveLinkTarget` on the existing output leaf. A null target is not by
itself a linked-leaf denial.

Exit criteria:

- ancestry comparisons cannot be fooled by common string-prefix collisions;
- platform casing behavior matches inspection policy; and
- ordinary Dropbox-backed paths remain admissible.

### Phase 3: Implement ownership classification

#### 3.1 Marker parser

Within `Test-PSModuleOutputOwnership`:

1. Compute `Metadata/output.json` with `Join-Path`.
2. If present, require a regular file rather than a directory or linked leaf.
3. Read raw UTF-8 content.
4. Parse JSON with a bounded depth.
5. Validate exact required property names, types, and values.
6. Return `Owned` only when all checks pass.
7. Return `InvalidMarker` with a safe reason for malformed or mismatched content.

Do not echo raw marker content in the result or exception.

#### 3.2 Empty classification

For a directory without a marker:

```powershell
@(Get-ChildItem -LiteralPath $OutputPath -Force -ErrorAction Stop).Count -eq 0
```

An access failure must propagate or become a safe `Unowned` reason; it must never
produce `Empty`.

#### 3.3 Legacy classification

When the directory is non-empty and has no marker:

1. Require `Metadata/model.json` as a regular file.
2. Parse it without invoking PowerShell content.
3. Validate schema version and module-name syntax using the same safe identity rules as
   the specification validator, preferably through a small reusable non-throwing check
   rather than duplicating a looser regex.
4. Require paired root `.psd1` and `.psm1` regular files using that exact module name.
5. Reject linked `Public`, `Documentation`, or `Scripts` leaves when those entries
   exist.
6. Return `Legacy` only after every condition passes.

Do not call `Test-ModuleManifest`; it may process generated module metadata beyond what
ownership detection needs.

#### 3.4 Typed result

Return a `SubZeroDev.PSGenerator.OutputOwnership` object with only:

- `State`;
- `MarkerPath`; and
- `Reason`.

Do not expose enumerated directory contents.

Exit criteria:

- every ownership state in the design has a direct test;
- malformed data fails closed;
- legacy recognition executes no generated code; and
- hidden entries prevent empty classification.

### Phase 4: Implement hard-denial assertion

#### 4.1 Normalize inputs

`Assert-PSModuleOutputPath` must derive all paths from the context and not trust callers
to pre-normalize them:

- lexical output from `Context.OutputPath`;
- lexical specification from `Context.SpecificationPath`;
- lexical directory from `Context.DirectoryPath`; and
- corresponding real paths through the existing resolver.

Select the comparison mode once and use it consistently.

`Set-StrictMode -Version 3.0` is active module-wide, so reading a property that a
partially constructed context does not carry throws `PropertyNotFoundException` instead
of returning `$null`. Existing tests build contexts as bare `[pscustomobject]` literals
holding only `DirectoryPath` and `OutputPath`, so this is a reachable path, not a
hypothetical one.

Presence-check before reading, and fail closed on a missing source boundary:

```powershell
foreach ($name in @('OutputPath', 'SpecificationPath', 'DirectoryPath')) {
    if (-not $Context.PSObject.Properties[$name] -or -not $Context.$name) {
        throw [ArgumentException]::new(
            "The build context does not define $name, so output cannot be reset safely."
        )
    }
}
```

Do not silently skip the specification or directory denials when those properties are
absent. A context that cannot describe its own source boundary must not reach
`Remove-Item`.

#### 4.2 Apply denials before ownership

Evaluate, in order:

1. lexical filesystem root;
2. real filesystem root;
3. equality with real or lexical source directory;
4. ancestry of real or lexical source directory;
5. equality with real or lexical specification;
6. ancestry of real or lexical specification;
7. equality with or containment inside `<DirectoryPath>/scripts`;
8. existing non-directory output;
9. actual linked output leaf; and
10. unresolved/cyclic real path.

Apply rule 7 to both the lexical and the real path, using the same boundary-aware
ancestry helper as the source rules, so a link into the scripts tree cannot slip past
it.

Checking denials before ownership ensures a forged marker and `-Force` cannot admit a
source-destructive path. Rule 7 depends on that ordering more than any other: an
ownership-only check rejects the overlap the first time, but `-Force` admits it, the
recursion runs, and the marker it leaves behind makes the directory `Owned` so every
later build recurses without force.

#### 4.3 Enforce ownership

- Admit `Missing`, `Empty`, `Owned`, and `Legacy`.
- Admit `Unowned` and `InvalidMarker` only when force is true.
- Return an assertion result containing the paths, ownership state, and initial leaf
  identity for the reset re-check.

#### 4.4 Exception assertions

Tests should check exception type and a stable message fragment, not the entire
machine-specific path string. Separately assert the resolved path appears in the
message where required.

Exit criteria:

- force cannot bypass any hard denial;
- no rejected case mutates source or output; and
- each rejection gives one actionable recovery path.

### Phase 5: Guard and mark the destructive reset

#### 5.1 Context forwarding

In `New-PSModuleBuildContext`, add `ForceOutputReset = $false`.

In `Build-PSModule`:

```powershell
$context.ForceOutputReset = [bool] $Force
```

Keep plugin-root and stage ordering unchanged.

In `Initialize-PSModuleDirectory`, construct build parameters and add `Force = $true`
only when `ForceOutput` is bound:

```powershell
$buildParameters = @{ Specification = $Specification; Output = $Output }
if ($ForceOutput) { $buildParameters['Force'] = $true }
$artifact = Build-PSModule @buildParameters
```

Do not pass an incidental `-Force:$false`. This is the binding the design specifies and
the behavior FO-07 asserts; always binding the parameter would make "did not force"
indistinguishable from "forced false" in `PSBoundParameters`.

#### 5.2 Pre-delete assertion

At the beginning of `Reset-PSModuleOutput`:

- derive force from `Context.ForceOutputReset`, defaulting to false when the property is
  absent;
- call `Assert-PSModuleOutputPath`;
- retain the returned identity for re-check.

Under `Set-StrictMode -Version 3.0` the default cannot be a plain property read. Use:

```powershell
$force = [bool] ($Context.PSObject.Properties['ForceOutputReset'] -and
                 $Context.ForceOutputReset)
```

A direct `$Context.ForceOutputReset` throws for every hand-built test context and would
break the compatibility the design promises.

#### 5.3 Immediate identity re-check

If the output existed during assertion:

- fetch it again immediately before removal;
- require a directory;
- reject a newly introduced link target;
- resolve its real path again; and
- compare it with the assertion result.

Throw `IOException` if it changed.

#### 5.4 Reset and marker write

After admission:

1. remove the existing directory if it exists;
2. create the clean output directory;
3. call `Write-PSModuleOutputMarker`;
4. return the marker item.

Use `-LiteralPath` for every existing-path operation. Use explicit paths rather than
globs. Do not swallow filesystem exceptions.

Creating the output directory here is new; it previously happened lazily inside
`Write-PSModuleMetadata`. That renderer still runs
`New-Item -Path <Metadata> -ItemType Directory -Force` after reset has already created
`Metadata` and written `output.json`. Against an existing *directory* this returns the
item and leaves contents intact, so the marker survives — verify it with a test rather
than relying on the reading. Note in the code that `New-Item -Force` against a *file*
truncates, so retargeting that call at a file path would destroy the marker silently.

`tests/Module.Tests.ps1` already asserts that context construction creates no output
directory. That test targets `New-PSModuleBuildContext`, not reset, and stays valid.

#### 5.5 Guard the script-packaging copy

`Write-PSModuleCommandSource` currently runs an unguarded recursive copy:

```powershell
$directoryScriptsPath = Join-Path $Context.DirectoryPath 'scripts'
if (Test-Path -LiteralPath $directoryScriptsPath -PathType Container) {
    Copy-Item -LiteralPath $directoryScriptsPath `
        -Destination (Join-Path $Context.OutputPath 'Scripts') -Recurse -Force
}
```

Resolve both sides and refuse when the destination is the source or lies inside it:

- resolve the scripts source and the `Scripts` destination to real paths;
- reject with `InvalidOperationException` on equality or containment; and
- name both resolved paths in the message.

This is deliberately redundant with the Phase 4 denial. The denial is the user-facing
policy; this guard is the last line and stays correct even if a future caller reaches
the packager through a path the denial does not cover. Do not implement one and skip
the other.

Note the ordering that makes the bug reachable: reset removes the scripts directory,
the renderers recreate it as the output, and only then does `Test-Path` succeed. A test
that checks `Test-Path` before reset will not reproduce it.

#### 5.6 Marker writer

Build the marker as an ordered dictionary, serialize at a fixed depth, normalize line
endings, and write through:

```powershell
[IO.File]::WriteAllText(
    $markerPath,
    $normalizedJson,
    [Text.UTF8Encoding]::new($false)
)
```

Byte-level tests must verify no BOM and one final LF.

Exit criteria:

- the assertion is inseparable from the destructive helper;
- admitted output is marked before later build stages can fail; and
- rejected output never reaches `Remove-Item`.

### Phase 6: Require ownership in completed packages

Modify `Complete-PSModulePackage`:

1. Add the marker to `requiredPaths`.
2. Require it to be a regular file.
3. Parse and validate it through the ownership helper or a shared marker validator.
4. Throw `InvalidDataException` when missing or invalid.
5. Preserve existing manifest, metadata, command source, documentation, and artifact
   path validation.

Avoid creating a circular meaning where classifying an output as owned requires a
complete package but completing a package requires ownership. Marker validity is
sufficient for current ownership; legacy recognition remains the separate migration
path.

Tests:

- ordinary successful package includes the marker;
- missing marker fails completion;
- malformed marker fails completion;
- marker remains present in the built container's `/PSModule` tree; and
- a partial marked directory is replaceable but is not mistaken for a completed
  package by `Complete-PSModulePackage`.

Exit criteria:

- every successful package carries valid ownership metadata; and
- partial output remains distinguishable from complete output.

### Phase 7: Update public help and user documentation

#### 7.1 Command help

`Build-PSModule`:

- explain the guarded replacement behavior in `.DESCRIPTION`;
- document `-Force` as unowned-output adoption;
- state explicitly that force cannot target roots or source ancestors.

`Initialize-PSModuleDirectory`:

- document `-ForceOutput`;
- clarify that it affects generation output only; and
- add one example that handles a deliberately selected existing directory.

#### 7.2 Specification and using guide

Update the package tree:

```text
Metadata/
├── model.json
└── output.json
```

Replace the unconditional overwrite sentence with the refined safety contract.

The generated-output guide should include:

- classification table;
- first-build and repeat-build examples;
- explicit force example;
- marker purpose and non-security boundary;
- migration from pre-marker output;
- linked-path limitation; and
- failure timing relative to validation.

#### 7.3 Troubleshooting

Add symptom/cause/recovery entries for:

- unsafe filesystem root;
- source root or ancestor;
- existing file;
- linked output leaf;
- unowned non-empty directory;
- invalid marker;
- marker deleted from a previously complete package;
- marker write failure; and
- output changed during reset validation.

Every recovery should prefer choosing a dedicated output or moving data before
suggesting force. The deleted-marker entry is the one exception: a package that was
generated here and then had `Metadata/output.json` removed is genuinely unowned, and the
correct advice is one deliberate `-Force` rebuild to re-establish the marker. Say that
plainly rather than sending the user to pick a different directory.

#### 7.4 Architecture and security

Document that:

- path assertion occurs immediately before reset;
- marker creation occurs immediately after reset;
- failed validation remains non-mutating;
- force bypasses ownership only; and
- plugins/specifications remain trusted code and can act outside this safeguard.

Exit criteria:

- documentation describes actual behavior rather than intended behavior;
- no absolute developer paths appear;
- relative links and terminology validation pass.

### Phase 8: Full validation

Run validation in increasing cost order.

#### 8.1 Static validation

1. Parse every `.ps1`, `.psm1`, and `.psd1` file with the PowerShell parser.
2. Run `Test-ModuleManifest` on the source manifest.
3. Import a packaged copy from a clean location.
4. Run `build/Invoke-Quality.ps1` with the pinned analyzer available.
5. Run `build/Test-Documentation.ps1`.

#### 8.2 Focused Pester

Run the new output-safety contexts first with detailed output. Confirm:

- no skipped ordinary-path tests;
- link tests skip only for explicit platform privilege limitations;
- sentinel assertions prove no rejected mutation; and
- the working tree remains clean afterward.

#### 8.3 Complete unit matrix

Run all tests from `tests/` on PowerShell 7.4. Verify packaged-source coverage remains
at or above 85%.

#### 8.4 Package and container validation

Run:

- generator module packaging;
- generator NuGet package validation;
- minimal generated-module lifecycle;
- container end-to-end tests; and
- container image smoke test.

Inspect `/PSModule/Metadata/output.json` in the built image without exposing unrelated
container environment state.

This subsection requires a working Docker daemon. When one is unavailable locally, run
the rest of the phase, record the container steps as deferred, and treat the hosted
container end-to-end and image smoke jobs in §8.6 as their authoritative result. Do not
report container verification as passing on the strength of a local run that did not
happen.

#### 8.5 Documentation build

Run documentation link/terminology validation and the production Docusaurus build.

#### 8.6 Cross-platform CI

Required hosted results:

- PowerShell 7.4 baseline on Windows and Linux;
- Pester on Windows and Linux;
- minimum coverage on Linux;
- PowerShell quality;
- documentation validation and site build;
- NuGet package validation;
- container end-to-end; and
- container image build/smoke test.

Exit criteria:

- every required check passes on the same commit;
- no unexpected generated or temporary files remain;
- no actionable review findings remain.

## Detailed test case inventory

Use the following IDs in test names or review notes to make coverage auditable.

### Hard denials

| ID | Scenario | Expected result |
| --- | --- | --- |
| HD-01 | Lexical filesystem root | `ArgumentException`; no removal. |
| HD-02 | Real path resolves to filesystem root | Reject before ownership. |
| HD-03 | Output equals inspected directory | Reject; source sentinel preserved. |
| HD-04 | Output is parent of inspected directory | Reject; source sentinel preserved. |
| HD-05 | Output is grandparent of inspected directory | Reject; source sentinel preserved. |
| HD-06 | Output equals specification file | Reject as non-directory/source. |
| HD-07 | Output contains specification | Reject; specification bytes preserved. |
| HD-08 | Existing ordinary file | Reject; file bytes preserved. |
| HD-09 | Existing symbolic-link directory | Reject; target sentinel preserved. |
| HD-10 | Existing Windows junction | Reject; target sentinel preserved. |
| HD-11 | Link ancestor disguises source relationship | Reject by real path. |
| HD-12 | Real-path cycle/depth overflow | `IOException`; no removal. |
| HD-13 | Every prior case with force | Same rejection; force is not a bypass. |
| HD-14 | Output equals `<DirectoryPath>/scripts` | Reject; scripts tree intact, no recursion. |
| HD-15 | Output inside `<DirectoryPath>/scripts` | Reject; scripts tree intact. |
| HD-16 | HD-14/HD-15 with force | Same rejection; force is not a bypass. |
| HD-17 | Link inside the output resolving into the scripts tree | Reject by real path. |
| HD-18 | Marker planted in the scripts tree, then build | Reject; ownership never reached. |

HD-12 must build its link chain against the resolver's own bound rather than inventing
one. That bound is the `$hops -gt 32` guard in `Resolve-PSModuleInspectionRealPath`;
reference it so the test tracks the implementation if the constant ever moves.

### Real-path resolver (Phase 0)

| ID | Scenario | Expected result |
| --- | --- | --- |
| RP-01 | Volume root (`C:\`, `/`) | One canonical form; no trailing-separator drift. |
| RP-02 | UNC root (`\\server\share`) | Canonical form; classified as a root. |
| RP-03 | Doubled separator in the input | No empty segment; no trailing separator. |
| RP-04 | Link whose target is a volume root | Resolves to the root, not root-plus-separator. |
| RP-05 | Path deeper than the previous implicit segment limit | Fully resolved. |
| RP-06 | Existing inspection-path behavior | Unchanged by the split fix. |

### Context shape

| ID | Scenario | Expected result |
| --- | --- | --- |
| CX-01 | Context without `ForceOutputReset` | Treated as not forced; no exception. |
| CX-02 | Context without `SpecificationPath` | `ArgumentException`; no removal. |
| CX-03 | Context without `DirectoryPath` | `ArgumentException`; no removal. |
| CX-04 | Context with a null source-boundary value | `ArgumentException`; no removal. |

### Ownership classification

| ID | Scenario | Expected state |
| --- | --- | --- |
| OW-01 | Missing output | `Missing`. |
| OW-02 | Empty directory | `Empty`. |
| OW-03 | Hidden entry only | `Unowned`. |
| OW-04 | Exact marker | `Owned`. |
| OW-05 | Malformed marker JSON | `InvalidMarker`. |
| OW-06 | Marker wrong schema | `InvalidMarker`. |
| OW-07 | Marker wrong generator | `InvalidMarker`. |
| OW-08 | Marker wrong artifact type | `InvalidMarker`. |
| OW-09 | Marker is directory or linked file | `InvalidMarker`. |
| OW-10 | Valid pre-marker package | `Legacy`. |
| OW-11 | Legacy metadata malformed | `Unowned`. |
| OW-12 | Legacy module name unsafe | `Unowned`. |
| OW-13 | Legacy manifest missing | `Unowned`. |
| OW-14 | Legacy loader missing | `Unowned`. |
| OW-15 | Access denied during enumeration | Fail closed. |

### Force behavior

| ID | Scenario | Expected result |
| --- | --- | --- |
| FO-01 | Unowned without force | Reject; sentinel preserved. |
| FO-02 | Unowned with force | Replace and mark. |
| FO-03 | Invalid marker without force | Reject; content preserved. |
| FO-04 | Invalid marker with force | Replace and mark. |
| FO-05 | Owned without force | Replace normally. |
| FO-06 | Legacy without force | Replace and migrate to marker. |
| FO-07 | Initialize without `ForceOutput` | Does not silently force. |
| FO-08 | Initialize with `ForceOutput` | Forwards force during generation. |

### Build lifecycle

| ID | Scenario | Expected result |
| --- | --- | --- |
| BL-01 | Valid first build | Complete marked package. |
| BL-02 | Repeat build | Deterministic identical package. |
| BL-03 | Invalid specification | Existing output unchanged. |
| BL-04 | Runtime-adapter failure before reset | Existing output unchanged. |
| BL-05 | Renderer failure after reset | Marked partial output remains. |
| BL-06 | Retry after partial failure | Replaces partial output without force. |
| BL-07 | Marker deleted before completion | Packaging fails as incomplete. |
| BL-08 | Marker malformed before completion | Packaging fails as invalid. |
| BL-09 | Empty module | Complete marked package. |
| BL-10 | Script-packaging module | Marker and scripts both packaged. |
| BL-11 | Packager invoked with destination inside the scripts source | `InvalidOperationException`; no copy, no nesting. |
| BL-12 | Script-packaging build to a normal output | Scripts copied exactly once; no `Scripts/Scripts` nesting. |

BL-11 and BL-12 must assert bounded output, not merely a successful build. Check that no
`Scripts/Scripts` path exists and that the packaged file count matches the source count,
so an unbounded copy fails the test instead of hanging it. Give these cases an explicit
Pester timeout: the pre-fix behavior does not throw, it expands until the disk fills.

### Marker bytes

| ID | Scenario | Expected result |
| --- | --- | --- |
| MK-01 | Encoding | UTF-8 without BOM. |
| MK-02 | Line endings | LF only, one final newline. |
| MK-03 | Property order | Exact canonical order. |
| MK-04 | Repeat writes | Byte-identical. |
| MK-05 | Sensitive/machine data | No path, user, host, time, PID, or secret fields. |

## Review checklist

### Safety

- [ ] The safety assertion is called from the destructive helper itself.
- [ ] Every mutation uses a literal, normalized path.
- [ ] Force is evaluated only after all hard denials.
- [ ] Filesystem roots are checked lexically and after link resolution.
- [ ] Source equality and ancestry are boundary-aware, not raw prefix checks.
- [ ] Existing files and actual linked leaves are never removed.
- [ ] The output leaf is re-checked immediately before deletion.
- [ ] Rejected tests verify sentinels and specification bytes remain unchanged.
- [ ] No destructive test targets a real user directory or filesystem root.
- [ ] Both `Split` call sites pass an explicit `[char[]]` so `RemoveEmptyEntries` applies.
- [ ] No comparison operand is re-normalized through `GetFullPath` after trimming.
- [ ] Optional context properties are presence-checked, not read directly under strict mode.
- [ ] A context missing its source boundary fails closed rather than skipping denials.
- [ ] Output overlapping `<DirectoryPath>/scripts` is denied before ownership, not by it.
- [ ] `Write-PSModuleCommandSource` refuses a destination inside its own source.
- [ ] Recursion tests assert bounded output and carry a timeout.

### Compatibility

- [ ] Default missing output still works.
- [ ] Empty output still works.
- [ ] Existing generated output still works through marker or legacy recognition.
- [ ] Public exports remain unchanged.
- [ ] Plugin order and build-stage order remain unchanged.
- [ ] Validation still completes before reset.
- [ ] Windows and Linux path semantics are tested.
- [ ] Dropbox/cloud-provider reparse metadata is not mistaken for an actual link.

### Determinism and artifacts

- [ ] Marker bytes are canonical and repeatable.
- [ ] Marker contains no machine-specific or sensitive data.
- [ ] Completed packages require the marker.
- [ ] Container and NuGet packages retain the marker.
- [ ] Repeated package snapshots remain identical.

### Documentation

- [ ] Public help documents both switches.
- [ ] Specification tree includes `Metadata/output.json`.
- [ ] Generated-output guide explains all states and recovery.
- [ ] Troubleshooting prefers safe alternative paths before force.
- [ ] Security documentation says force is not a hard-denial bypass.
- [ ] No atomicity or hostile-code protection is claimed.

## Suggested commit sequence

Keep commits independently understandable and avoid mixing generated documentation with
unrelated source work.

1. `Honor empty-entry removal when splitting inspection paths`
   - Fix both `Split` call sites and add the `RP` resolver tests. This commit stands
     alone and is independently revertable.
2. `Test unsafe generated output path contracts`
   - Add the path, ownership, force, marker, forwarding, and `CX` context-shape tests.
3. `Classify generated output ownership`
   - Add ancestry, ownership, marker parsing, and assertion helpers.
4. `Guard generated output replacement`
   - Add context/public switches and integrate guarded reset plus marker writing.
5. `Require ownership metadata in generated packages`
   - Extend package completion and lifecycle assertions.
6. `Document generated output safety`
   - Update command help, specifications, using, troubleshooting, architecture, and
     security documentation.

If tests and implementation must land together to keep every commit green, combine
commits 2 through 4 while retaining the same logical review order in the diff. Keep
commit 1 separate regardless; it fixes a pre-existing defect in shared inspection code
and should be reviewable and revertable without the output-safety feature.

## Pull request structure

The pull request description should include:

### Problem

State that a caller-selected valid build output was recursively cleared without a
root, source-boundary, ownership, or link check.

### Solution

Summarize:

- the prerequisite `RemoveEmptyEntries` fix in shared path splitting, and why the new
  comparisons could not be trusted without it;
- the script-packaging overlap denial and copier guard, noting that the pre-fix
  behavior was an unbounded copy rather than a single bad deletion;
- hard denials;
- ownership classification;
- explicit force behavior;
- deterministic marker;
- legacy migration; and
- pre-delete identity re-check.

### Compatibility

List unchanged workflows and the deliberate behavior changes for unowned directories,
files, and links.

### Verification

Report exact Windows/Linux tests, coverage, quality, documentation, package, and
container results. Mention skipped link tests and their platform reason, if any.

### Security boundary

State that the feature reduces accidental deletion but does not sandbox trusted
specifications or plugins.

Do not include assistant attribution or generated-with footers.

## Rollback strategy

If the ownership policy causes unexpected compatibility failures after merge:

1. Keep hard denials, existing-file rejection, and linked-leaf rejection in place.
2. Temporarily treat non-empty unowned directories as the legacy behavior while
   emitting a warning that a future build will require force.
3. Keep writing the marker so affected directories migrate automatically.
4. Do not remove marker validation from completed packages unless packaging itself is
   failing.
5. File a focused follow-up with the exact rejected directory shape; do not weaken
   root or source-ancestor protections to fix ownership migration.

This fallback preserves the highest-value safety boundary while allowing a staged
adoption of the ownership requirement.

## Definition of done

The feature is done only when:

- implementation matches every accepted decision in
  `output-path-safety-design.md`;
- all RP, CX, HD, OW, FO, BL, and MK test cases are implemented or have a documented,
  reviewed reason for exclusion;
- no build configuration can copy the packaged scripts tree into itself;
- no rejected target is mutated in tests;
- all supported first-build, repeat-build, initialization, package, and container
  workflows pass;
- source manifest and packaged module remain valid on PowerShell 7.4;
- hosted Windows and Linux required checks pass on the same commit;
- documentation validates and builds;
- the worktree is clean after validation;
- no actionable review thread remains; and
- the pull request is reviewable as output-path safety work without unrelated roadmap
  implementation.
