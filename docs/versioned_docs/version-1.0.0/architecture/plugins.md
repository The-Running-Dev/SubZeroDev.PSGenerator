---
title: Internal plugin system
description: Plugin discovery, ordering, shared context, diagnostics, and trust.
sidebar_position: 2
---

# Internal plugin system

:::warning

Version 1 plugins are an internal trusted-code mechanism, not a stable public SDK.
They execute without a sandbox and can access the same files, processes, network,
and credentials as the generator process.

:::

## Directory layout

A plugin root may contain:

```text
Plugins/
├── Inspectors/
├── Validators/
├── ObjectModelProcessors/
├── RuntimeAdapters/
├── CodeGenerators/
├── TemplateRenderers/
└── PackagingProviders/
```

Files must match:

```text
<numeric-prefix>.<name>.ps1
```

Example:

```text
Inspectors/20.RepositoryPolicyInspector.ps1
```

## Discovery and ordering

Stages always execute in pipeline order. Within a stage, files are sorted by ordinal
filename and then resolved path. Numeric prefixes communicate intent, but the full
filename determines lexical order; use zero-padded prefixes consistently.

Inspect without executing:

```powershell
Get-ContainerModulePlugin `
    -Path ./PSModule/Plugins
```

Filter stages:

```powershell
Get-ContainerModulePlugin `
    -Path ./PSModule/Plugins `
    -Stage Inspectors, Validators
```

Duplicate roots, missing roots, and invalid filenames are rejected.

## Plugin contract

Every plugin is a PowerShell script declaring a `Context` parameter:

```powershell
param (
    [Parameter(Mandatory)]
    [psobject] $Context
)
```

An inspector example:

```powershell
param (
    [Parameter(Mandatory)]
    [psobject] $Context
)

$policyPath = Join-Path $Context.RepositoryPath 'repository-policy.json'
$Context.Inspection['RepositoryPolicy'] = if (
    Test-Path -LiteralPath $policyPath -PathType Leaf
) {
    Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
}
else {
    $null
}
```

Do not write ordinary pipeline output; the runner discards it. Communicate through
the shared context.

## Repository plugins

When `PluginPath` is omitted, build and inspection commands discover `Plugins`
beside the resolved specification:

```text
PSModule/
├── PSModule.psd1
└── Plugins/
    └── Inspectors/
        └── 20.RepositoryPolicyInspector.ps1
```

Select explicit additional roots:

```powershell
Build-ContainerModule `
    -Specification ./PSModule/PSModule.psd1 `
    -PluginPath ./Build/ContainerModulePlugins
```

Built-in plugins always run. Explicit roots do not replace them.

## Diagnostics

Every attempted plugin records:

- stage;
- execution order;
- plugin name and path;
- UTC start time;
- elapsed duration;
- success; and
- error text.

```powershell
$inspection = Get-ContainerModuleInspection
$inspection | Get-ContainerModuleDiagnostic
$inspection | Get-ContainerModuleDiagnostic -Detailed
```

The runner wraps ordinary failures with plugin and stage identity. Failures stop the
stage and the remaining pipeline.

## Authoring rules

- Treat the context shape as internal and version-coupled.
- Validate required context properties before changing them.
- Use repository-relative paths and normalize separators in persisted metadata.
- Sort discovered files and object properties ordinally.
- Do not embed development-machine absolute paths in generated artifacts.
- Produce focused errors that name the source artifact.
- Avoid network access unless the repository contract explicitly requires it.
- Never log tokens, credentials, secret contents, or unredacted environment state.
- Add fixture-backed tests for plugin behavior.
