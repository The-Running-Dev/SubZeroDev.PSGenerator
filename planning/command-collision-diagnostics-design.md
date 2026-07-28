# Inferred Command Collision Diagnostics Design

## Status

Proposed.

## Objective

Warn when an inferred command will shadow a command already discoverable in the
current PowerShell session, while preserving the inferred specification and all
deterministic generation contracts.

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
written, `Initialize-PSModuleSpecification` will inspect every candidate command
name with:

```powershell
Get-Command -Name $name -All -ErrorAction SilentlyContinue
```

Detection is intentionally session-aware. Installed modules, imported functions,
aliases, cmdlets, and applications differ by host. That means warnings can vary by
environment, but the generated specification must not.

The detector must:

- evaluate the final inferred name, not the source filename;
- report the candidate `SourcePath`;
- sort and de-duplicate existing command identities for stable warning text;
- issue one warning per colliding inferred command;
- ignore existing commands whose module is the module being scaffolded; and
- avoid importing or executing directory-provided code.

### Module auto-loading

`Get-Command` resolves a name against `PSModulePath`, so it can import an
installed module that the session had not loaded. Detection keeps that behavior
rather than suppressing it.

Setting `$PSModuleAutoLoadingPreference = 'None'` around the lookup would make the
helper inert, but it also reduces detection to whatever is already loaded. In a
`pwsh -NoProfile -Command` session that starts with no modules loaded, the lookup
then returns nothing at all for `ConvertTo-Json`, which is the collision this
feature exists to report. Suppression trades a real diagnostic for a smaller
side effect.

Complete detection is the right trade because the risk being reported is a
resolution change in the *consumer's* session, where the competing module will
auto-load on the same terms. The cost is explicit: initialization may import
installed modules, and on a cold session with a large `PSModulePath` the lookup
adds noticeable latency. The helper is not side-effect-free, and nothing in the
plan should describe it that way.

The directory being inspected is never placed on `PSModulePath`, so this does not
import or execute directory-provided code.

### Commands from the scaffolded module

`Initialize-PSModuleDirectory` refreshes a generated specification by calling
`Initialize-PSModuleSpecification -Force`. If an earlier build of the same module
is installed or imported, every inferred command would otherwise collide with its
own previous build and warn on a routine refresh.

The detector therefore discards existing commands whose `ModuleName` equals the
candidate module name, which `Get-PSModuleSpecificationCandidate` already returns
as `ModuleName`. The helper needs that name as an input alongside the candidate
list.

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

The helper returns data; it does not call `Write-Warning`. Suggested fields:

- `Name`
- `SourcePath`
- `ExistingCommandType`
- `ExistingName`
- `ExistingModuleName`
- `ExistingSource`

## Tests

Add cross-platform Pester coverage that:

1. uses `convertto-json.ps1` to collide with the built-in `ConvertTo-Json`;
2. captures the warning and verifies the inferred name and source path;
3. proves the command is still present in the written specification;
4. proves a unique inferred command emits no collision warning;
5. proves multiple results are ordered and do not duplicate warning identities;
6. proves `-WhatIf` does not write a specification or perform post-approval
   collision reporting;
7. proves repeated initialization produces byte-identical specification content;
   and
8. proves an existing command belonging to the scaffolded module produces no
   warning, so refreshing a directory whose generated module is already loaded
   stays quiet.

Cover the helper's identity-formatting and no-collision branches directly. The
Pester job enforces `MINIMUM_PACKAGED_COVERAGE_PERCENT` on both command and line
coverage of the packaged module, so a new private function reached only through
one happy-path test can push the gate below its threshold.

Update the script-inference guide and troubleshooting page with the warning,
advisory semantics, and explicit-authoring escape hatch.

## Acceptance Criteria

- Common collisions are visible before module import.
- Initialization remains successful and deterministic.
- No directory-provided script or module is imported to detect collisions.
- Warning behavior passes on Windows and Linux PowerShell 7.4.

## Non-goals

- Preventing all PowerShell command precedence changes.
- Renaming commands automatically.
- Treating environment-specific warnings as persistent inspection diagnostics.
- Detecting collisions between authored commands already accepted by specification
  validation.
