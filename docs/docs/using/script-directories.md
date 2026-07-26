---
title: Script Directory Inference
description: Turn scripts and exported module functions into generated commands.
sidebar_position: 4
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
Write-Greeting
```

The script parameter block supplies parameter names, basic types, and whether the
parameter is mandatory. Untyped parameters default to `string`.

### How the Name Is Chosen

A file already named `Verb-Noun` keeps that name when the verb is one PowerShell
approves. The verb is emitted in the casing `Get-Verb` reports, so a lowercase
file name still produces a correctly cased command:

| File | Command |
| --- | --- |
| `Test-Documentation.ps1` | `Test-Documentation` |
| `write-greeting.ps1` | `Write-Greeting` |
| `convertto-json.ps1` | `ConvertTo-Json` |
| `container-tool.ps1` | `Invoke-ContainerTool` |
| `setup-my-tool.ps1` | `Invoke-SetupMyTool` |
| `build.ps1` | `Invoke-Build` |

Anything that is not `Verb-Noun` with an approved verb becomes `Invoke-` followed
by the file name in Pascal case, because a name the author did not write as a
command has no verb to preserve.

:::note

Naming a script after an existing command produces a generated command with that
same name, which will shadow the original once the module is imported. Rename the
script, or author the command explicitly, if that is not what you want.

:::

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

Point the generator at the directory:

```powershell
Initialize-PSModuleDirectory `
    -Directory ../MyDirectory `
    -ListCommands
```

The harness initializes or refreshes a generated scaffold, builds the module,
imports it globally, and lists its exported commands. The commands are immediately
available in the current PowerShell session.

Use strict behavior when a missing specification should fail:

```powershell
Initialize-PSModuleDirectory `
    -Directory ../MyDirectory `
    -NoInitialize
```

## Packaged Source Layout

The complete source directory `scripts` tree is copied into the generated module:

```text
artifacts/PSModule/
├── Public/
│   └── Write-Greeting.ps1
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
