---
title: Local repository testing
description: Generate, import, list, preview, and trace commands against another checkout.
sidebar_position: 4
---

# Local repository testing

`build/Test-LocalRepository.ps1` exercises this checkout of ContainerPSGenerator
against another local repository without embedding that repository as a submodule.

## Validate or initialize

```powershell
./build/Test-LocalRepository.ps1 `
    -Repository ../MyContainerRepository
```

If `PSModule/PSModule.psd1` is missing, empty, or an unmapped generator-owned
scaffold, the harness initializes or refreshes it and generates the inferred module.
Otherwise it returns the validated normalized model.

Prevent initialization:

```powershell
./build/Test-LocalRepository.ps1 `
    -Repository ../MyContainerRepository `
    -NoInitialize
```

## Generate

```powershell
./build/Test-LocalRepository.ps1 `
    -Repository ../MyContainerRepository `
    -Generate
```

Select non-default paths relative to the target repository:

```powershell
./build/Test-LocalRepository.ps1 `
    -Repository ../MyContainerRepository `
    -Specification ./config/ContainerModule.psd1 `
    -Output ./dist/PSModule `
    -Generate
```

Absolute specification and output paths are also accepted.

## Import and list commands

```powershell
./build/Test-LocalRepository.ps1 `
    -Repository ../MyContainerRepository `
    -ListCommands
```

The generated module is imported globally into the current session. Returned command
objects include parameter metadata and can be invoked immediately.

## Preview and trace

Preview a container-backed command:

```powershell
Invoke-MyCommand -WhatIf
```

Trace runtime discovery and execution:

```powershell
Invoke-MyCommand -Verbose
```

For inferred local commands, invoke the wrapper normally. It resolves the packaged
source beneath the generated module's `Scripts` directory.

## Maintained fixtures

The Pester suite includes isolated copies of:

- a script-only repository; and
- an authored build-agent repository.

Fixtures live under `tests/fixtures/repositories`. Tests copy them to temporary
directories before initialization or generation, so tracked fixture sources remain
unchanged.

## When no commands appear

Check:

1. scripts are under the target repository's `scripts` directory;
2. `.ps1` files parse without errors;
3. `.psm1` functions are explicitly exported with `Export-ModuleMember`;
4. command names do not collide without regard to case;
5. the source is not inside a nested Git repository; and
6. an authored specification is not intentionally preventing scaffold refresh.

See [Troubleshooting](../operations/troubleshooting.md) for failure-specific checks.
