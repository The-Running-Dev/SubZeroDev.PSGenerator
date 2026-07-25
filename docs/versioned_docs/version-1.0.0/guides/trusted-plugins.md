---
title: Trusted repository plugins
description: Add repository-specific inspection and packaging behavior with internal Version 1 plugins.
sidebar_position: 5
---

# Trusted repository plugins

Version 1 repository plugins are useful when a repository needs build-time behavior
that does not belong in the declarative specification.

:::warning

Plugins are trusted, unsandboxed PowerShell and use an internal contract that may
change before a public SDK exists. Keep them in the repository, review them like
build code, and test them against the generator version used by CI.

:::

This example reads a repository policy during inspection and writes it into the
generated module during packaging.

## Layout

```text
PSModule/
├── PSModule.psd1
└── Plugins/
    ├── Inspectors/
    │   └── 90.RepositoryPolicyInspector.ps1
    └── PackagingProviders/
        └── 90.RepositoryPolicyPackagingProvider.ps1
repository-policy.json
```

The built-in packaging provider validates the core package before the repository's
`90` provider adds supplemental metadata.

## Repository input

Create `repository-policy.json`:

```json
{
  "owner": "platform-team",
  "supportTier": "production"
}
```

## Inspector

Create `PSModule/Plugins/Inspectors/90.RepositoryPolicyInspector.ps1`:

```powershell
param (
    [Parameter(Mandatory)]
    [psobject] $Context
)

$policyPath = Join-Path $Context.RepositoryPath 'repository-policy.json'
$Context.Inspection['RepositoryPolicy'] = if (
    Test-Path -LiteralPath $policyPath -PathType Leaf
) {
    Get-Content -LiteralPath $policyPath -Raw |
        ConvertFrom-Json -ErrorAction Stop
}
else {
    $null
}
```

The inspector always publishes the `RepositoryPolicy` key, using `$null` when the
optional file is absent.

## Packaging provider

Create
`PSModule/Plugins/PackagingProviders/90.RepositoryPolicyPackagingProvider.ps1`:

```powershell
param (
    [Parameter(Mandatory)]
    [psobject] $Context
)

if ($null -eq $Context.Inspection['RepositoryPolicy']) {
    return
}

$metadataDirectory = Join-Path $Context.OutputPath 'Metadata'
$policyOutput = Join-Path $metadataDirectory 'repository-policy.json'
$null = New-Item -Path $metadataDirectory -ItemType Directory -Force

$Context.Inspection['RepositoryPolicy'] |
    ConvertTo-Json -Depth 10 |
    Set-Content -LiteralPath $policyOutput -Encoding utf8NoBOM -NoNewline

$Context.Artifacts['RepositoryPolicy'] = Get-Item -LiteralPath $policyOutput
```

The provider writes only under the validated output directory and publishes the
result through `Artifacts`.

## Inspect before building

```powershell
$inspection = Get-ContainerModuleInspection `
    -Specification ./PSModule/PSModule.psd1

$inspection.Data.RepositoryPolicy
$inspection | Get-ContainerModuleDiagnostic -Detailed
```

## Generate and verify

```powershell
Build-ContainerModule `
    -Specification ./PSModule/PSModule.psd1 `
    -Output ./artifacts/PSModule

Get-Content ./artifacts/PSModule/Metadata/repository-policy.json
```

Because the plugins are beside the specification, no explicit `-PluginPath` is
needed.

## Testing guidance

Test:

- the file-present case;
- the file-absent case;
- malformed JSON behavior;
- deterministic JSON property and array ordering required by the repository;
- plugin discovery order;
- the generated relative path; and
- detailed diagnostics on failure.

Avoid persisting secrets or machine-specific absolute paths.
