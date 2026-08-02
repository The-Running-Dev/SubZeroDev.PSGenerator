# Generated Output Path Safety Design

## Status

Proposed. This document is implementation-ready but does not itself change runtime
behavior.

Revised after validation against the implementation. The review confirmed the problem
statement and the overall shape of the policy, and corrected six items: a prerequisite
defect in the shared real-path resolver, a missing path normalization contract, the
`GetFullPath` hazard on bare drive designators, the strict-mode behavior of the optional
context-property fallback, a contradiction with the implementation plan over
`-ForceOutput` forwarding, and an overstated claim about what the hard denials cover.

A later run against a real repository added a seventh: an output overlapping the
packaged `scripts` tree causes an unbounded recursive copy that the ownership layer
cannot close, because `-Force` admits it and the resulting marker makes it permanent.
That is now a hard denial with a matching guard in the packager.

The riskiest remaining assumption — that existing generated packages are recognized and
do not force every current user through a one-time `-Force` — was then checked by
prototyping the legacy rules and running them against real pre-marker output. Both a
full package and an empty-module package classified as `Legacy`. The implementation plan
records which claims in this design are verified and which remain reasoned.

## Decision summary

`Build-PSModule` will continue to replace generated output, but it will no longer
recursively delete every existing path supplied through `-Output`.

The generator will apply two layers of protection immediately before the first
destructive operation:

1. **Hard path denials** reject filesystem roots, source ancestors, source roots,
   existing non-directory paths, and linked output directories. `-Force` cannot
   override these denials.
2. **Ownership protection** permits replacement of an existing non-empty directory
   only when it is recognizably owned by PSGenerator or the caller explicitly uses
   `Build-PSModule -Force`.

Every newly prepared output receives a deterministic ownership marker at
`Metadata/output.json`. Existing generated packages from before the marker was
introduced are recognized through a narrow, non-executing legacy-package check.

`Initialize-PSModuleDirectory` will expose `-ForceOutput` and forward it to
`Build-PSModule -Force`. The more explicit name avoids confusing output replacement
with specification initialization or refresh behavior.

## Problem statement

The current generation sequence is intentionally ordered so specification and model
validation finish before output is cleared. At the `CodeGenerators` boundary,
`Invoke-PSModuleBuildStage` calls `Reset-PSModuleOutput`. That helper currently does:

```powershell
if (Test-Path -LiteralPath $Context.OutputPath) {
    Remove-Item -LiteralPath $Context.OutputPath -Recurse -Force
}
```

`New-PSModuleBuildContext` normalizes the requested path, but it does not classify the
path or verify that it is safe to remove. Consequently, a valid specification paired
with an unsafe `-Output` value can recursively remove:

- a filesystem root, subject to process permissions and partial failures;
- the inspected repository root;
- a parent of the repository;
- the specification directory;
- an unrelated existing directory selected by a typo;
- a linked directory whose real target is not apparent from its lexical path; or
- an existing regular file, even though `Output` is documented as a directory.

The existing validation-before-reset ordering protects prior output from an invalid
specification. It does not protect source or unrelated user data from a valid build
with a bad output path.

The repository's build scripts already reject filesystem roots, repository ancestors,
and source-tree collisions before clearing their own package output. The public
generator should meet at least the same safety standard while preserving its documented
ability to rebuild an intentional output directory.

## Goals

1. Make accidental deletion of a filesystem root, the inspected source root, or any
   directory containing the source fail before mutation, with or without force.
2. Preserve deterministic full-output replacement for recognized generator output.
3. Keep the default `artifacts/PSModule` workflow unchanged after the first safe build.
4. Give callers an explicit way to adopt or clear an existing non-empty output
   directory after reviewing it.
5. Preserve pre-marker generated packages without requiring a one-time force flag.
6. Apply path comparisons correctly on Windows, Linux, and best-effort macOS.
7. Resolve symlink and junction targets before evaluating containment.
8. Keep safety checks at the destructive boundary so every build path is covered.
9. Produce errors that identify the rejected path, classification, and safe recovery.
10. Add no machine-specific paths, timestamps, secrets, or nondeterministic values to
    generated packages.

### What each layer actually covers

The two layers protect different things, and the distinction matters when reviewing the
denial table below.

Hard denials cover only targets that contain the source or the volume. They do **not**
protect a sibling directory inside the inspected tree: `-Output ./src` passes every hard
denial, because `src` neither contains the specification nor is an ancestor of the
inspected root.

Everything else is the ownership layer's job. A non-empty unowned `src` is rejected for
lacking a marker, not for being source, and `-Force` will therefore delete it. That is
deliberate, and it is why the force help text must direct callers to inspect the
resolved path first.

## Non-goals

- Providing a security sandbox against a malicious caller with permission to edit and
  run generator code.
- Making trusted PSD1 specifications or plugins untrusted inputs.
- Implementing transactional or atomic directory replacement in this change.
- Adding `SupportsShouldProcess` or `-WhatIf` to `Build-PSModule`.
- Preventing a caller from explicitly clearing an unrelated non-empty directory with
  `-Force`, provided it passes the hard path denials.
- Restricting output to the inspected repository or to an `artifacts` directory.
- Changing generated-command runtime behavior.
- Refactoring the separate safety checks in the repository's build/package scripts.
- Treating marker presence as an adversarial authenticity guarantee. It is an
  accidental-deletion ownership signal, not a signature.

## Existing behavior and constraints

### Build sequence

The public build command creates a context and runs:

1. Inspectors
2. Validators
3. Object model processors
4. Runtime adapters
5. Code generators
6. Template renderers
7. Packaging providers

Output is reset at the beginning of stage 5. This placement is valuable and remains:

- invalid specifications do not clear prior output;
- invalid normalized-model boundaries do not clear prior output; and
- all renderers see a clean output tree.

The new safety assertion belongs inside `Reset-PSModuleOutput`, directly adjacent to
`Remove-Item`, rather than only in the public command. That keeps the destructive
primitive safe when invoked from tests, future orchestration, or an internal plugin.

### Output contract

The specification currently promises that each build overwrites previously generated
output. The refined contract is:

> Each build replaces an empty, recognized PSGenerator-owned, or explicitly forced
> output directory after validating the specification and output path. Source roots,
> source ancestors, filesystem roots, files, and linked output directories are never
> valid output-reset targets.

### Internal plugin contract

The shared context is internal and version-coupled. Adding a Boolean
`ForceOutputReset` property is therefore acceptable, but it must default to false so
direct internal construction remains safe.

### Prerequisite defect in the shared real-path resolver

This design layers exact path comparisons on top of
`Resolve-PSModuleInspectionRealPath`. That resolver currently splits path segments with:

```powershell
$full.Substring($root.Length).Split(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar,
    [StringSplitOptions]::RemoveEmptyEntries
)
```

`String` has no `Split(char, char, StringSplitOptions)` overload. PowerShell binds
`Split(char[])` and coerces the enum to `(char) 1`, so `RemoveEmptyEntries` is silently
discarded. Observed consequences:

- `''.Split(...)` yields one empty entry rather than none;
- `'D:\a\\b'.Split(...)` yields `D:`, `a`, `''`, `b`; and
- an empty segment reaching `Join-Path` appends a separator, so `Join-Path 'D:\a' ''`
  returns `D:\a\`.

A resolved path carrying a trailing separator defeats every equality comparison in this
design. The resolver happens to return `C:\` for a drive root today only because the
spurious empty segment restores the separator that `TrimEnd` removed.

The same pattern appears in `Test-PSModuleInspectionPath`.

Fixing both call sites to pass an explicit `[char[]]` array with the options argument is
a prerequisite for this feature, not an optional cleanup. The fix ships with focused
resolver tests for roots, doubled separators, and a link whose target is a root.

### Path normalization contract

Because the denial rules compare paths for exact equality, one canonical form is
required. Every path entering a comparison is normalized as follows:

1. Resolve to an absolute path with `GetFullPath` **before** any trimming.
2. Never pass an already-trimmed value back through `GetFullPath`. On Windows a bare
   drive designator is process-relative: `[IO.Path]::GetFullPath('D:')` returns the
   process's current directory on `D:`, not `D:\`.
3. For comparison, trim trailing directory separators from both operands.
4. Re-append a single separator only when the result is a bare volume root, so a root
   remains distinguishable from a relative drive reference.

Root detection compares the normalized target against its own normalized
`GetPathRoot`, so it does not depend on whether the resolver preserved a trailing
separator.

### Cross-platform behavior

Path equality and containment use:

- `StringComparison.Ordinal` on Linux;
- `StringComparison.OrdinalIgnoreCase` on Windows; and
- `StringComparison.OrdinalIgnoreCase` on macOS, matching the repository's existing
  inspection-path policy and the default filesystem behavior.

All persisted relative paths continue to use `/`. The ownership marker contains no
path, so it requires no platform normalization.

## Terminology

**Lexical path**
: The normalized absolute path expressed by the caller after provider resolution and
  `GetFullPath`, before following filesystem links.

**Real path**
: The location obtained after resolving symlink or junction segments with the existing
  bounded real-path resolver.

**Source boundary**
: The specification file and the inspected directory tree represented by
  `Context.DirectoryPath`.

**Hard denial**
: A target that the generator never clears, even with `-Force`.

**Owned output**
: An existing directory carrying a valid PSGenerator output marker.

**Legacy output**
: A narrowly recognizable generated module package created before output markers were
  introduced.

**Unowned output**
: An existing non-empty directory that is neither marked nor recognized as legacy.

## Public interface changes

### `Build-PSModule`

Add:

```powershell
[Parameter()]
[switch] $Force
```

Semantics:

- permits replacement of an existing non-empty unowned output directory;
- does not bypass any hard denial;
- has no effect for a missing, empty, owned, or legacy output directory; and
- does not change validation ordering.

The help text must say that callers should inspect the resolved error path before
using `-Force`.

### `Initialize-PSModuleDirectory`

Add:

```powershell
[Parameter()]
[switch] $ForceOutput
```

When generation occurs, forward it by adding `Force = $true` to the build parameters
only when `ForceOutput` is bound:

```powershell
$buildParameters = @{ Specification = $Specification; Output = $Output }
if ($ForceOutput) { $buildParameters['Force'] = $true }
$artifact = Build-PSModule @buildParameters
```

Do not forward an incidental `-Force:$false`. Always binding the parameter changes
`PSBoundParameters` for every ordinary initialization, which makes "did not force"
indistinguishable from "forced false" in mocks and plugin-visible state.

`-ForceOutput` does not:

- replace an authored specification;
- alter `-NoInitialize`;
- suppress output-path hard denials; or
- imply any Docker installation force behavior.

### No manifest export change

No new public command is added. The manifest continues to export the same nine
functions.

## Safety policy

### Evaluation order

`Reset-PSModuleOutput` evaluates the target in this order:

1. Normalize the lexical output path.
2. Select the platform comparison mode.
3. Resolve real output, source-directory, and specification paths.
4. Apply hard denials.
5. Classify the existing output state.
6. Apply ownership protection.
7. Re-check the destructive leaf immediately before deletion.
8. Remove the prior directory, if present.
9. Create the new output and metadata directories.
10. Write the deterministic ownership marker.

No step before step 8 mutates the target.

### Hard denials

The following targets are rejected with `ArgumentException`, regardless of `-Force`:

| Condition | Reason |
| --- | --- |
| Lexical output equals its filesystem root | Never recursively target a volume root. |
| Real output equals its filesystem root | A linked path must not disguise a root. |
| Output equals `Context.DirectoryPath` | Do not clear the inspected source root. |
| Output is an ancestor of `Context.DirectoryPath` | Do not clear a parent containing the source. |
| Output equals `Context.SpecificationPath` | `Output` must be a directory, never the source file. |
| Output is an ancestor of `Context.SpecificationPath` | Do not clear a directory containing the specification. |
| Existing output is a non-directory item | Avoid deleting a file selected through a typo. |
| Existing output leaf resolves as a symlink or junction | Avoid platform-dependent recursive link deletion. |
| Real-path resolution exceeds its cycle/depth bound | Fail closed on an ambiguous target. |
| Output equals or is inside `<DirectoryPath>/scripts` | Script packaging copies that tree into the output; an overlap recurses without bound. |

Both lexical and real relationships are checked. Lexical checks make error behavior
clear for ordinary paths. Real checks prevent a linked ancestor from hiding a source
or root relationship.

Root comparisons follow the path normalization contract above; they must not assume the
real-path resolver returns a trailing separator for a volume root.

The two `Context.DirectoryPath` rows are retained for message quality, not for
additional coverage. `DirectoryPath` is always the specification's parent or
grandparent, so any target equal to or containing it is already caught by the
specification-ancestor rule. Evaluating the directory rows first means a caller who
passes the inspected root is told that, rather than being told about the specification
file they did not name. Do not remove them as redundant.

#### Why the script-packaging overlap must be a hard denial

This row is not symmetric with the others: it protects against a runaway, not against a
deletion. `Write-PSModuleCommandSource` packages discovered scripts with:

```powershell
$directoryScriptsPath = Join-Path $Context.DirectoryPath 'scripts'
if (Test-Path -LiteralPath $directoryScriptsPath -PathType Container) {
    Copy-Item -LiteralPath $directoryScriptsPath `
        -Destination (Join-Path $Context.OutputPath 'Scripts') -Recurse -Force
}
```

When the output is at or inside that tree, the destination lies inside the source and
`Copy-Item -Recurse` walks into its own output. Reset removes the directory, the
renderers recreate it as the output, `Test-Path` then succeeds, and the copy expands
without bound. This was reproduced against a real repository: the source scripts were
destroyed and the tree grew past 1400 nested files before the process was killed.

The ownership layer alone is not sufficient here, which is why the rule belongs among
the hard denials:

- by default the directory is non-empty and unowned, so ownership does reject it;
- but `-Force` admits it, and the recursion still occurs; and
- that forced run leaves a valid marker in the scripts tree, so the directory becomes
  `Owned` and every later build recurses again **without** force.

An ownership-only rule therefore converts a one-time forced mistake into a permanent
one. The hard denial is evaluated before ownership and cannot be forced, which is the
only placement that closes all three paths.

`Write-PSModuleCommandSource` additionally guards its own copy by refusing to run when
the resolved destination is inside the resolved source. That guard is independent of
output policy, so the runaway stays closed even if this denial is ever relaxed or a
future caller reaches the packager by another route.

The source-ancestor rules still allow normal destinations inside the inspected tree,
including `artifacts/PSModule` and `dist`, because those descendants do not contain the
source root or specification file.

### Existing directory classification

After hard denials, classify the output:

| State | Default action | With `-Force` |
| --- | --- | --- |
| Missing | Create | Create |
| Existing and empty | Replace | Replace |
| Valid ownership marker | Replace | Replace |
| Recognized legacy package | Replace and add marker | Replace and add marker |
| Invalid/corrupt marker | Reject | Replace |
| Non-empty and unowned | Reject | Replace |

An invalid marker is not silently accepted as ownership. This ensures partial manual
edits to the ownership contract do not accidentally broaden deletion.

### Ownership marker

Location:

```text
Metadata/output.json
```

Canonical content:

```json
{
  "SchemaVersion": 1,
  "Generator": "SubZeroDev.PSGenerator",
  "ArtifactType": "GeneratedPowerShellModule"
}
```

Requirements:

- UTF-8 without BOM;
- LF line endings and one final newline;
- ordinal property order as shown;
- no timestamp, source path, output path, username, host, process ID, or version that
  changes independently of the marker schema;
- exact expected types and values when read;
- required by final package validation; and
- created immediately after output preparation, before renderers write other files.

Writing the marker immediately means a failed render leaves a directory that a retry
can safely recognize and replace. Requiring it during final package validation means a
successful package can never omit the marker.

### Legacy output recognition

Legacy recognition exists only to migrate output created by the current generator.
It must not execute or import any generated PowerShell.

An existing directory is legacy output only when all conditions hold:

1. `Metadata/model.json` exists as a regular file.
2. The JSON parses successfully with a bounded depth.
3. It contains `SchemaVersion = 1`.
4. It contains a safe, non-empty `ModuleName`.
5. `<ModuleName>.psd1` and `<ModuleName>.psm1` exist as regular root files.
6. `Public`, `Documentation`, and `Scripts`, when present, are directories rather than
   linked leaves.

The check deliberately does not call `Test-ModuleManifest`, import the module, inspect
plugins, or execute generated source. It is an ownership heuristic for accidental
deletion, not package validation.

A malformed `model.json`, missing paired root files, or unsafe module name makes the
directory unowned. The error can recommend `-Force` after manual inspection.

### Empty directory definition

An existing directory is empty only when `Get-ChildItem -Force` returns no entries.
Hidden files count as content. Access errors fail closed and do not classify the
directory as empty.

### Linked paths

The implementation reuses `Resolve-PSModuleInspectionRealPath` for bounded resolution
of link segments. Cloud-provider reparse metadata that does not resolve as a symlink or
junction is not automatically rejected; this is necessary for repositories stored in
providers such as Dropbox. A leaf with an actual link target is rejected.

For a missing output beneath a linked ancestor, the real parent relationship is used
for hard-denial checks. The implementation must test Windows junctions where available
and symbolic links on platforms where test permissions allow them.

### Time-of-check/time-of-use boundary

Filesystem state can change between inspection and deletion. Immediately before
`Remove-Item`, the reset helper must re-read the output leaf and verify that it:

- still exists as a directory;
- still has the same normalized real path; and
- has not become a symlink or junction.

If any property changed, throw an `IOException` and perform no deletion. This does not
claim to eliminate all filesystem races, but it narrows the mutation boundary and
fails closed for ordinary replacement races.

## Internal design

### Context extension

`New-PSModuleBuildContext` adds:

```text
ForceOutputReset = false
```

`Build-PSModule` sets it from `-Force` after context creation. Tests and internal
callers that omit the property remain safe because `Reset-PSModuleOutput` treats a
missing property as false for compatibility with manually constructed test contexts.

That fallback cannot be written as a plain property read. The module sets
`Set-StrictMode -Version 3.0`, under which `$Context.ForceOutputReset` on an object
lacking the property throws `PropertyNotFoundException` rather than returning `$null`.
Existing tests construct partial contexts as bare `[pscustomobject]` literals, so this
path is reachable. Every optional context read in this feature must be presence-checked:

```powershell
$force = [bool] ($Context.PSObject.Properties['ForceOutputReset'] -and
                 $Context.ForceOutputReset)
```

The same rule applies to `Assert-PSModuleOutputPath`, which reads
`Context.SpecificationPath` and `Context.DirectoryPath`. When either is absent or null,
fail closed with `ArgumentException` rather than skipping the corresponding denials. A
context that cannot describe its own source boundary is not a context this function can
clear output for.

### Private helpers

Add focused helpers rather than expanding the reset function into a large policy
implementation:

#### `Test-PSModulePathAncestor`

Inputs: candidate ancestor, path, comparison mode.

Behavior: normalize separators, append exactly one directory separator, and perform a
boundary-aware prefix comparison. Equality is handled by the caller so messages can
distinguish equality from ancestry.

#### `Test-PSModuleOutputOwnership`

Input: normalized output path.

Returns a typed classification object:

```text
PSTypeName = SubZeroDev.PSGenerator.OutputOwnership
State      = Missing | Empty | Owned | Legacy | Unowned | InvalidMarker
MarkerPath
Reason
```

It never mutates the filesystem and never executes package content.

#### `Assert-PSModuleOutputPath`

Inputs: context and force switch.

Responsibilities:

- normalize and resolve paths;
- apply lexical and real hard denials;
- reject existing files and linked leaves;
- obtain ownership classification;
- enforce the force requirement; and
- return a typed validation result containing the lexical path, real path, state, and
  pre-delete identity needed for the immediate re-check.

#### `Write-PSModuleOutputMarker`

Input: output path.

Creates `Metadata`, writes canonical content with `File.WriteAllText` and UTF-8 without
BOM, and returns the marker file.

### Reset orchestration

`Reset-PSModuleOutput` becomes the only destructive coordinator:

```text
Assert target
    |
    +-- unsafe ----------------------------> throw; no mutation
    |
    +-- unowned without explicit force ----> throw; no mutation
    |
    `-- admitted
            |
            +-- re-check existing leaf
            +-- remove existing directory
            +-- create clean output
            `-- write ownership marker
```

The function should return the marker item for tests but callers may discard it.

Reset now creates the output and `Metadata` directories, which previously happened
lazily in `Write-PSModuleMetadata`. That renderer still runs
`New-Item -Path <Metadata> -ItemType Directory -Force` over a directory that now already
contains `output.json`. On an existing directory this returns the item without touching
its contents, so the marker survives. Record that dependency: `New-Item -Force` against
a *file* truncates it, so if that call is ever retargeted at a file path it would
silently destroy the marker.

### Package completion

`Complete-PSModulePackage` adds `Metadata/output.json` to its required paths and
validates the marker through the same ownership parser. A missing or invalid marker
causes packaging to fail as incomplete. The marker need not be separately published in
`Context.Artifacts`; it is package metadata rather than a renderer artifact.

## Error contract

Errors must be terminating and use stable exception categories:

| Failure | Exception type | Message requirements |
| --- | --- | --- |
| Root/source/ancestor hard denial | `ArgumentException` | Resolved path and rejected relationship. |
| Existing non-directory | `ArgumentException` | State that output must be a directory. |
| Linked output leaf | `ArgumentException` | State that linked output directories cannot be reset. |
| Unowned/invalid-marker directory | `InvalidOperationException` | Resolved path and deliberate `-Force` recovery. |
| Real-path cycle/depth error | Preserve or wrap `IOException` | Path and resolution failure. |
| Leaf changed before deletion | `IOException` | State that the output changed during validation. |
| Marker write failure | Preserve filesystem exception | Marker path; no secret or source content. |

Example unowned-output message:

```text
Output directory '<full path>' is not recognized as PSGenerator-owned and is not
empty. Review the directory, choose another output, or rerun Build-PSModule with
-Force to replace it.
```

Example hard-denial message:

```text
PSGenerator output path is unsafe because it contains the inspected source directory:
'<full path>'. Choose a dedicated generated-output directory.
```

Messages should avoid dumping marker contents, environment variables, or directory
contents.

## Compatibility and migration

### Unchanged workflows

- First build to missing `artifacts/PSModule`.
- Repeated build to marker-owned `artifacts/PSModule`.
- Repeated build to a valid legacy package.
- Build to an empty existing directory.
- Build to an output outside the repository when it is missing, empty, owned, legacy,
  or explicitly forced.
- Validation failure preserving existing output.

### Behavior changes

- A non-empty unowned directory now requires `-Force`.
- A regular file can no longer be silently replaced by a directory.
- A symlink or junction used as the output leaf is rejected.
- Source roots and ancestors are rejected even with `-Force`.
- Successful packages include `Metadata/output.json`.
- Removing `Metadata/output.json` from a completed package makes that directory unowned,
  so the next rebuild into it requires one deliberate `-Force` to re-establish the
  marker. Troubleshooting must state this directly.

The project has not published its first package, so this is the appropriate time to
tighten the Version 1 contract. Legacy recognition still minimizes disruption for
existing source-checkout users.

## Documentation changes

Update:

- `Build-PSModule` comment-based help with `-Force` and the reset policy;
- `Initialize-PSModuleDirectory` help with `-ForceOutput`;
- `Specifications.md` generated-output contract and package tree;
- `docs/docs/using/generated-output.md` with ownership states and marker details;
- `docs/docs/using/troubleshooting.md` with unowned, invalid-marker, deleted-marker,
  linked-path, and hard-denial recovery;
- `docs/docs/developing/overview.md` to name the validation/reset/marker boundary;
- `docs/docs/developing/security.md` to explain that `-Force` is deliberate deletion,
  not a hard-denial bypass; and
- generated `docs/docs/index.md` only through the repository's documented homepage
  generation path if README changes become necessary.

Do not claim atomic replacement or protection against malicious local code.

## Test design

### Unit path matrix

Use Pester `TestDrive` for all ordinary mutation tests. Root and source-ancestor tests
must assert rejection before any removal command can run.

Hard-denial cases:

- filesystem root;
- inspected directory itself;
- parent and grandparent of inspected directory;
- specification path;
- directory containing the specification;
- existing regular file;
- linked output leaf;
- real path that resolves to the inspected directory;
- force applied to every hard-denial category.

Admitted cases:

- missing output;
- empty directory;
- valid marker-owned output;
- recognized legacy output;
- unowned non-empty output with `-Force`;
- output inside the inspected directory but not containing source, such as
  `artifacts/PSModule`;
- missing output below a safe linked parent, when the platform permits it;
- path containing spaces;
- mixed-case path behavior appropriate to the platform.

Ownership cases:

- exact valid marker;
- missing marker;
- malformed JSON marker;
- wrong schema version;
- wrong generator value;
- wrong artifact type;
- hidden file preventing empty classification;
- access failure failing closed where practical;
- valid legacy metadata and paired module files;
- malformed legacy metadata;
- legacy metadata with unsafe module name;
- legacy metadata missing manifest or loader.

Reset and lifecycle cases:

- admitted reset removes stale content and writes the marker;
- marker bytes are deterministic, UTF-8 without BOM, and LF-terminated;
- repeat builds remain byte-for-byte deterministic;
- validation failure preserves existing output and marker;
- a renderer failure after reset leaves a marker-owned partial directory that a retry
  can replace without force;
- the completed package requires the marker;
- deleting the marker before package completion fails packaging;
- `Initialize-PSModuleDirectory -ForceOutput` forwards force only when generation runs;
- default initialization does not force an unowned output;
- module manifest still exports exactly the existing public commands.

Real-path resolver cases (prerequisite fix):

- a drive root and a POSIX root round-trip to a canonical form;
- a doubled separator produces no empty segment and no trailing separator;
- a link whose target is a volume root resolves to that root, not to root-plus-separator;
- a path deeper than the previous implicit segment limit resolves completely; and
- existing inspection-path behavior is unchanged.

Context-shape cases:

- a context missing `ForceOutputReset` is treated as not forced rather than throwing;
- a context missing or with a null `SpecificationPath` fails closed; and
- a context missing or with a null `DirectoryPath` fails closed.

### Link tests

Link creation may require privileges on Windows. Tests should:

- attempt creation in setup;
- skip with an explicit reason only when the platform refuses link creation;
- use a junction fallback for Windows directory-link coverage when possible;
- never point a destructive test at a path outside `TestDrive`; and
- verify both lexical and real-path denial.

### Regression gates

- all PowerShell source parses on PowerShell 7.4;
- PSScriptAnalyzer and formatting pass;
- Windows and Linux Pester pass;
- packaged-generator coverage remains at or above 85%;
- container E2E passes because the marker becomes part of `/PSModule`;
- NuGet package validation passes;
- documentation links, terminology, and production build pass;
- repository hygiene remains clean after tests.

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Existing custom output becomes unowned | Recognize legacy output and provide explicit `-Force`. |
| Marker is mistaken for a security signature | Document it as an ownership hint for accidental-deletion safety. |
| Symlink logic breaks Dropbox/cloud paths | Reject only actual resolvable link leaves; reuse tested real-path resolution. |
| Platform case behavior diverges | Use the same comparison policy as inspection and run Windows/Linux CI. |
| Force becomes a blanket bypass | Apply hard denials before ownership/force evaluation and test every denial with force. |
| Partial generation becomes hard to recover | Write the marker immediately after reset, before rendering. |
| Legacy detection executes generated code | Parse JSON and inspect file types only; never import or test the manifest. |
| New metadata breaks consumers expecting exact files | Document the additive file and exercise container/NuGet packaging. |
| Safety logic drifts across callers | Keep deletion and its assertion together in `Reset-PSModuleOutput`. |
| TOCTOU replacement after validation | Re-check the leaf immediately before removal and fail on identity change. |
| Trailing separators defeat path equality | Fix the resolver's discarded `RemoveEmptyEntries` first and normalize both operands through one contract. |
| Strict mode turns the optional-property fallback into a terminating error | Presence-check every optional context read; cover partial `[pscustomobject]` contexts in tests. |
| Marker deleted from a good package makes it unowned | Document the one-time `-Force` recovery in troubleshooting. |
| Output overlapping the packaged scripts tree recurses without bound | Deny the overlap before ownership, and guard the copy in `Write-PSModuleCommandSource`. |
| A forced overlap becomes self-perpetuating once marked | Hard denial precedes ownership, so a marker inside the scripts tree can never admit it. |

## Acceptance criteria

The design is implemented when all of the following are true:

1. No filesystem root, inspected source root, source ancestor, specification ancestor,
   or path overlapping the packaged scripts tree can reach `Remove-Item`, with or
   without force.
2. Existing files and linked output directories are rejected before mutation.
3. Missing and empty safe outputs build without force.
4. Marker-owned and valid legacy outputs rebuild without force.
5. Non-empty unowned output fails without force and succeeds with deliberate force.
6. Every newly prepared output contains the canonical marker before rendering.
7. Package completion rejects a missing or invalid marker.
8. Failed validation preserves the prior output exactly.
9. Failed rendering leaves a safely replaceable partial output.
10. Repeated successful builds remain deterministic.
11. `Initialize-PSModuleDirectory -ForceOutput` forwards the intended policy without
    changing specification ownership behavior.
12. User and developer documentation accurately describes the policy and recovery.
13. The real-path resolver honors `RemoveEmptyEntries`, returns a canonical form for
    roots and doubled separators, and is covered by tests at both call sites.
14. A context missing `ForceOutputReset` is treated as not forced, and a context missing
    its source boundary fails closed, both under `Set-StrictMode -Version 3.0`.
15. Script packaging cannot copy a tree into itself, whether blocked by the output
    denial or by its own destination-inside-source guard.
16. The complete Windows/Linux quality, unit, packaging, documentation, and container
    gates pass.

## Follow-up opportunities

These are intentionally separate changes:

- transactional directory swap with rollback if final packaging fails;
- a shared path-safety library for build scripts and generator internals;
- `SupportsShouldProcess` for build output replacement;
- a command that reports output ownership without building;
- stronger marker provenance or signed build metadata; and
- cleanup tooling for abandoned partial output.
