# Inferred Command Collision Diagnostics Design

## Status

Accepted. Detection must not auto-load or execute installed modules. It combines
commands already available in the session with statically declared exports from
available module metadata. A prior generated module is excluded only when its
generator provenance and specification identity match. `-WhatIf` stays silent.

## Objective

Warn when an inferred command will shadow a command already resolvable from the
current PowerShell session, while preserving the inferred specification and all
deterministic generation contracts.

"Resolvable from" is wider than "loaded in": detection includes explicit exports
declared by installed modules the session has not imported. It deliberately does
not execute a module to discover dynamic exports.

## Current Behavior

`ConvertTo-PSModuleCommandName` intentionally preserves valid PowerShell names and
canonical verb casing. For example, `scripts/convertto-json.ps1` becomes
`ConvertTo-Json`. `Get-PSModuleSpecificationCandidate` de-duplicates inferred names
within the candidate module, but it does not compare them with commands outside
that module.

The user documentation warns about shadowing, but initialization produces no
runtime warning. Importing the generated module can therefore change which command
an unqualified invocation resolves.

## Design

### Detection boundary

After `Get-PSModuleSpecificationCandidate` returns and before the specification is
written, `Initialize-PSModuleSpecification` inspects every final candidate name
through two non-executing sources:

```powershell
# Source 1: commands already available without module auto-loading.
$PSModuleAutoLoadingPreference = 'None'
Get-Command -Name $name -All -ErrorAction SilentlyContinue

# Source 2: statically discoverable exports from available module metadata.
Get-Module -ListAvailable
```

The implementation must save and restore `PSModuleAutoLoadingPreference` in a
`finally` block. It inventories available modules once per initialization, not
once per candidate, and reads their `ExportedCommands` metadata without importing
them. Loaded functions, aliases, cmdlets, applications, and installed module
metadata differ by host. Warnings can therefore vary by environment, but the
generated specification must not.

PowerShell modules can compute exports dynamically. Those commands are not
discoverable without executing module code and are intentionally omitted. This
warning is advisory and best-effort; preserving the scaffolding command's
non-executing boundary is more important than complete prediction.

`-Name` takes a wildcard pattern, which is safe here only because the value is an
inferred name. `ConvertTo-PSModuleCommandName` emits either `Verb-Noun` built from
letters and digits, or `Invoke-` joined to the Pascal-cased `[A-Za-z0-9]+` runs of
the file name, so `foo[bar].ps1` arrives as `Invoke-FooBar` and no wildcard
character survives. Passing a raw file base name here would not be safe.

The detector must:

- evaluate the final inferred name, not the source filename;
- report the candidate `SourcePath`;
- sort and de-duplicate existing command identities for stable warning text;
- issue one warning per colliding inferred command;
- ignore only a proven earlier generated build of the same specification; and
- avoid importing or executing directory-provided and installed module code.

### Module discovery without auto-loading

`Get-Command` can auto-load a matching installed module even when
`-ListImported` is used. Import-time code would then execute merely to produce an
advisory warning. Detection prevents that by setting
`PSModuleAutoLoadingPreference` to `None` only around the session lookup and
restoring its previous value in `finally`.

Available-module metadata supplies the second source. For example,
`Microsoft.PowerShell.Utility` declares `ConvertTo-Json`, so the common collision
remains discoverable without importing that module. A module that uses wildcard
or computed exports may be absent or incomplete in this source; detection does
not fall back to importing it.

The directory being inspected is never placed on `PSModulePath`. Neither source
imports or executes it.

### Commands from the scaffolded module

`Initialize-PSModuleDirectory` refreshes a generated specification by calling
`Initialize-PSModuleSpecification -Force`. If an earlier generated build of the
same specification is installed or imported, every inferred command would
otherwise collide with its own previous build and warn on a routine refresh.

Module name alone does not prove identity: an unrelated installed module can have
the same name and is exactly the kind of collision this feature should report.
Generated manifests therefore gain private provenance containing:

- `GeneratedBy = 'SubZeroDev.PSGenerator'`; and
- the specification `Id`.

The detector excludes an existing command only when its module name, generator
marker, and specification ID all match the candidate. An unmarked module, a
different specification ID, or a legacy generated manifest without provenance
still warns. A legacy generated module can warn once during its first refresh;
the newly generated manifest then carries the marker required for quiet future
refreshes.

### Behavior

A collision is advisory:

- do not remove or rename the candidate;
- do not fail initialization;
- do not add host-specific collision data to the specification or inspection
  metadata;
- do not alter command ordering; and
- preserve `-Force`, `-PassThru`, and `ShouldProcess` behavior.

`-WhatIf` reports no collisions. `Initialize-PSModuleSpecification` returns at its
`ShouldProcess` call before candidate discovery runs, and detection stays after
that call, so a preview keeps scanning no files and parsing no scripts. Warning on
a preview would mean doing the full directory parse for a command that writes
nothing. This is a deliberate limit, not an oversight: a user who wants the
warning runs the command.

The warning should identify the inferred name, its source, the existing command
type and module/source where available, and the two remedies: rename the script or
author the specification explicitly.

Example:

```text
Inferred command 'ConvertTo-Json' from 'scripts/convertto-json.ps1' collides
with existing Cmdlet 'Microsoft.PowerShell.Utility\ConvertTo-Json' and may
shadow it after import. Rename the script or author the command explicitly.
```

### Implementation shape

Create one private helper responsible for collision discovery and identity
formatting. Keep `Initialize-PSModuleSpecification` responsible for emitting
warnings. This separates host discovery from specification inference and makes
the behavior directly testable.

The helper takes the candidate commands, candidate `ModuleName`, and candidate
specification `Id`, so it can apply the proven-self exclusion above without
reaching back into the specification.

The helper returns data; it does not call `Write-Warning`. Suggested fields:

- `Name`
- `SourcePath`
- `ExistingCommandType`
- `ExistingName`
- `ExistingModuleName`
- `ExistingSource`

## Tests

Build the colliding directory inside `TestDrive`, the way the existing inference
tests already create a `scripts` directory and write scripts into it. No committed
fixture is needed: the warning is behavior, not a maintained artifact.

Do not add `convertto-json.ps1` to the `ScriptOnly` fixture. Its integration test
asserts `Commands.Name | Should -Be 'Write-Greeting'` as a scalar and then indexes
`Commands[0]` three times. A second script would make that name an array, and
because candidates are ordered by full path, `convertto-json.ps1` would sort first
and take over index zero — four assertions break for reasons unrelated to what the
new test is checking.

Add cross-platform Pester coverage that:

1. uses `convertto-json.ps1` to collide with the built-in `ConvertTo-Json`;
2. captures the warning and verifies the inferred name and source path;
3. proves the command is still present in the written specification;
4. proves a unique inferred command emits no collision warning;
5. proves multiple results are ordered and do not duplicate warning identities;
6. proves `-WhatIf` does not write a specification or perform post-approval
   collision reporting;
7. proves repeated initialization produces byte-identical specification content;
8. proves a prior generated module with matching provenance produces no warning;
9. proves an unmarked or differently identified same-name module still warns; and
10. places a synthetic module with import-time sentinel code on `PSModulePath`,
    discovers its explicitly declared command, and proves the module was not
    imported and the sentinel did not run.

Cover the helper's identity-formatting and no-collision branches directly. The
Pester job enforces `MINIMUM_PACKAGED_COVERAGE_PERCENT` on both command and line
coverage of the packaged module, so a new private function reached only through
one happy-path test can push the gate below its threshold.

Update the script-inference guide and troubleshooting page with the warning,
best-effort semantics, non-executing discovery boundary, and explicit-authoring
escape hatch. Update generated-output documentation for the private manifest
provenance.

## Acceptance Criteria

- Common collisions are visible before module import.
- Initialization remains successful and deterministic.
- No directory-provided or installed module is imported to detect collisions.
- Refreshing a directory whose own generated module is loaded warns about nothing.
- An unrelated same-name module still warns.
- Warning behavior passes on Windows and Linux PowerShell 7.4.

## Non-goals

- Preventing all PowerShell command precedence changes.
- Renaming commands automatically.
- Executing modules to discover wildcard or dynamically computed exports.
- Warning during `-WhatIf`.
- Treating environment-specific warnings as persistent inspection diagnostics.
- Detecting collisions between authored commands already accepted by specification
  validation.
