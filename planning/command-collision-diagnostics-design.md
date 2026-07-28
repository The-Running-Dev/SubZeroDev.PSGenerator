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
- issue one warning per colliding inferred command; and
- avoid importing or executing directory-provided code.

### Behavior

A collision is advisory:

- do not remove or rename the candidate;
- do not fail initialization;
- do not add host-specific collision data to the specification or inspection
  metadata;
- do not alter command ordering; and
- preserve `-Force`, `-PassThru`, and `ShouldProcess` behavior.

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
   collision reporting; and
7. proves repeated initialization produces byte-identical specification content.

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
