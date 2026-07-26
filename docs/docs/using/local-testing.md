---
title: Point PSGenerator at a Directory
description: Scaffold, generate, import, and inspect a module for a directory in one call.
sidebar_position: 3
---

# Point PSGenerator at a Directory

`Initialize-PSModuleDirectory` takes a directory as far as it can go in one call:
it scaffolds a specification when none exists, generates the module, imports it
globally so the commands are immediately callable, and reports what it produced.

This is the entry point when the directory is somewhere else — a mounted volume,
a sibling checkout — rather than the one you are sitting in.

## Inspect a Directory

```powershell
Initialize-PSModuleDirectory -Directory ../MyContainerDirectory
```

If `PSModule/PSModule.psd1` is missing, empty, or an unmapped generator-owned
scaffold, it is created or refreshed and the inferred module is generated.
Otherwise the validated normalized model is returned unchanged.

Fail instead of scaffolding:

```powershell
Initialize-PSModuleDirectory `
    -Directory ../MyContainerDirectory `
    -NoInitialize
```

## Generate

```powershell
Initialize-PSModuleDirectory `
    -Directory ../MyContainerDirectory `
    -Generate
```

Select non-default paths relative to the directory. Absolute paths are also
accepted:

```powershell
Initialize-PSModuleDirectory `
    -Directory ../MyContainerDirectory `
    -Specification ./config/ContainerModule.psd1 `
    -Output ./dist/PSModule `
    -Generate
```

## List the Commands

```powershell
Initialize-PSModuleDirectory `
    -Directory ../MyContainerDirectory `
    -ListCommands
```

The generated module is imported globally, so the returned commands can be
invoked straight away. A warning is raised when a discovered command carries
source metadata but no runtime mappings, because such a command invokes the
container image rather than the packaged source.

## From the Container Image

The image mounts your directory at `/workspace`, which makes this the natural
first command to run:

```powershell
docker run --rm -it `
    -v ${PWD}:/workspace `
    ghcr.io/the-running-dev/subzerodev.psgenerator:latest `
    -Command 'Initialize-PSModuleDirectory -Directory /workspace -ListCommands'
```

## Preview and Trace

Preview a container-backed command without starting Docker:

```powershell
Invoke-MyCommand -WhatIf
```

Trace runtime discovery and execution:

```powershell
Invoke-MyCommand -Verbose
```

For inferred local commands, invoke the wrapper normally. It resolves the
packaged source beneath the generated module's `Scripts` directory.

## When No Commands Appear

Check:

1. scripts are under the target directory's `scripts` directory;
2. `.ps1` files parse without errors;
3. `.psm1` functions are explicitly exported with `Export-ModuleMember`;
4. command names do not collide without regard to case;
5. the source is not inside a nested Git repository; and
6. an authored specification is not intentionally preventing scaffold refresh.

See [Troubleshooting](./troubleshooting.md) for failure-specific checks.
