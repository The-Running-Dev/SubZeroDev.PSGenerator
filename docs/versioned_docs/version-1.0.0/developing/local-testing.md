---
title: Local Directory Testing
description: Generate, import, list, preview, and trace commands against another checkout.
sidebar_position: 4
---

# Local Directory Testing

`build/Test-LocalDirectory.ps1` exercises this checkout of PSGenerator
against another local directory without embedding that directory as a submodule.
Whenever it generates a module, it imports that module globally so its commands can
be invoked immediately from the caller's current project directory.

## Validate or Initialize

```powershell
./build/Test-LocalDirectory.ps1 `
    -Directory ../MyContainerDirectory
```

If `PSModule/PSModule.psd1` is missing, empty, or an unmapped generator-owned
scaffold, the harness initializes or refreshes it and generates the inferred module.
Otherwise it returns the validated normalized model.

Prevent initialization:

```powershell
./build/Test-LocalDirectory.ps1 `
    -Directory ../MyContainerDirectory `
    -NoInitialize
```

## Generate

```powershell
./build/Test-LocalDirectory.ps1 `
    -Directory ../MyContainerDirectory `
    -Generate
```

Select non-default paths relative to the target directory:

```powershell
./build/Test-LocalDirectory.ps1 `
    -Directory ../MyContainerDirectory `
    -Specification ./config/PSModule.psd1 `
    -Output ./dist/PSModule `
    -Generate
```

Absolute specification and output paths are also accepted.

## Import and List Commands

```powershell
./build/Test-LocalDirectory.ps1 `
    -Directory ../MyContainerDirectory `
    -ListCommands
```

The generated module is imported globally into the current session. Returned command
objects include parameter metadata and can be invoked immediately.

## Preview and Trace

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

## Maintained Fixtures

The Pester suite includes isolated copies of:

- a script-only directory; and
- an authored build-agent directory.

Fixtures live under `tests/fixtures/directories`. Tests copy them to temporary
directories before initialization or generation, so tracked fixture sources remain
unchanged.

## When No Commands Appear

Check:

1. scripts are under the target directory's `scripts` directory;
2. `.ps1` files parse without errors;
3. `.psm1` functions are explicitly exported with `Export-ModuleMember`;
4. command names do not collide without regard to case;
5. the source is not inside a nested Git repository; and
6. an authored specification is not intentionally preventing scaffold refresh.

See [Troubleshooting](../using/troubleshooting.md) for failure-specific checks.
