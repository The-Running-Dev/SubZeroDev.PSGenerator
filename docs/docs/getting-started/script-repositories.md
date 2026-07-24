---
title: Script repository inference
description: Turn scripts and exported module functions into generated commands.
sidebar_position: 3
---

# Script repository inference

ContainerPSGenerator can create an initial specification for repositories that
already expose PowerShell entry points beneath `scripts`.

## Discovery boundary

Inference examines only:

```text
scripts/**/*.ps1
scripts/**/*.psm1
```

It does not infer commands from PowerShell files at the repository root, under
`setup`, in dependencies, or elsewhere. This boundary keeps build helpers and
unrelated modules out of the public command surface.

Nested Git repositories beneath `scripts` are skipped.

## Standalone scripts

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

## Module functions

For `.psm1` files, inference includes only functions:

1. defined in the module; and
2. named explicitly by `Export-ModuleMember`.

The function name must use Version 1 `Verb-Noun` syntax. The generated wrapper
imports the packaged module and invokes the exported function module-qualified.

## Initialize a specification

```powershell
Initialize-ContainerModuleSpecification `
    -Repository . `
    -PassThru
```

This creates `PSModule/PSModule.psd1`. Use `-WhatIf` to preview creation and `-Force`
to replace an existing file:

```powershell
Initialize-ContainerModuleSpecification -Repository . -WhatIf
Initialize-ContainerModuleSpecification -Repository . -Force
```

The scaffold infers:

- a file-safe module name from the repository directory;
- version `0.1.0`;
- a GHCR image reference found in the root README, when present;
- script commands;
- explicitly exported module functions; and
- source-relative command metadata.

## Generate and list commands

From the ContainerPSGenerator checkout:

```powershell
./build/Test-LocalRepository.ps1 `
    -Repository ../MyRepository `
    -ListCommands
```

The harness initializes or refreshes a generated scaffold, builds the module,
imports it globally, and lists its exported commands. The commands are immediately
available in the current PowerShell session.

Use strict behavior when a missing specification should fail:

```powershell
./build/Test-LocalRepository.ps1 `
    -Repository ../MyRepository `
    -NoInitialize
```

## Packaged source layout

The complete source repository `scripts` tree is copied into the generated module:

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

## Scaffold ownership and refresh

Generated scaffolds carry:

```powershell
GeneratedBy = 'SubZeroDev.ContainerPSGenerator'
```

The repository test harness refreshes missing, empty, or generator-owned scaffolds
that do not contain authored runtime mappings. Once mappings are added, it treats the
specification as authored and preserves it.

:::warning

Inference discovers callable PowerShell sources; it does not infer
repository-specific container intent. Add explicit mappings only to authored
container-backed commands. Do not add Docker mappings to commands that should
execute their packaged local script or module function.

:::
