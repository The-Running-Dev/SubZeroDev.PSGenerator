---
title: Script Directory Inference
description: Turn scripts and exported module functions into generated commands.
sidebar_position: 3
---

# Script Directory Inference

PSGenerator can create an initial specification for directories that
already expose PowerShell entry points beneath `scripts`.

## Discovery Boundary

Inference examines only:

```text
scripts/**/*.ps1
scripts/**/*.psm1
```

It does not infer commands from PowerShell files at the directory, under
`setup`, in dependencies, or elsewhere. This boundary keeps build helpers and
unrelated modules out of the public command surface.

Nested Git repositories beneath `scripts` are skipped.

## Standalone Scripts

Every parseable `.ps1` file becomes a command candidate:

```text
scripts/write-greeting.ps1
```

becomes:

```text
Invoke-WriteGreeting
```

The script parameter block supplies parameter names, basic types, and whether the
parameter is mandatory. Untyped parameters default to `string`.

## Module Functions

For `.psm1` files, inference includes only functions:

1. defined in the module; and
2. named explicitly by `Export-ModuleMember`.

The function name must use Version 1 `Verb-Noun` syntax. The generated wrapper
imports the packaged module and invokes the exported function module-qualified.

## Initialize a Specification

```powershell
Initialize-PSModuleSpecification `
    -Directory . `
    -PassThru
```

This creates `PSModule/PSModule.psd1`. Use `-WhatIf` to preview creation and `-Force`
to replace an existing file:

```powershell
Initialize-PSModuleSpecification -Directory . -WhatIf
Initialize-PSModuleSpecification -Directory . -Force
```

The scaffold infers:

- a file-safe module name from the directory directory;
- version `0.1.0`;
- a GHCR image reference found in the root README, when present;
- script commands;
- explicitly exported module functions; and
- source-relative command metadata.

## Generate and List Commands

From the PSGenerator checkout:

```powershell
./build/Test-LocalDirectory.ps1 `
    -Directory ../MyDirectory `
    -ListCommands
```

The harness initializes or refreshes a generated scaffold, builds the module,
imports it globally, and lists its exported commands. The commands are immediately
available in the current PowerShell session.

Use strict behavior when a missing specification should fail:

```powershell
./build/Test-LocalDirectory.ps1 `
    -Directory ../MyDirectory `
    -NoInitialize
```

## Packaged Source Layout

The complete source directory `scripts` tree is copied into the generated module:

```text
artifacts/PSModule/
├── Public/
│   └── Invoke-WriteGreeting.ps1
└── Scripts/
    ├── write-greeting.ps1
    ├── modules/
    │   └── Common.psm1
    └── support/
        └── settings.json
```

Relative paths are preserved. Scripts can therefore resolve sibling modules and
supporting files relative to their packaged location instead of a development
machine path.

## Scaffold Ownership and Refresh

Generated scaffolds carry:

```powershell
GeneratedBy = 'SubZeroDev.PSGenerator'
```

The directory test harness refreshes missing, empty, or generator-owned scaffolds
that do not contain authored runtime mappings. Once mappings are added, it treats the
specification as authored and preserves it.

:::warning

Inference discovers callable PowerShell sources; it does not infer
container intent specific to the inspected directory. Add explicit mappings only to authored
container-backed commands. Do not add Docker mappings to commands that should
execute their packaged local script or module function.

:::
