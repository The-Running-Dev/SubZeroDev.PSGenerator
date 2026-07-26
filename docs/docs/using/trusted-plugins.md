---
title: Trusted Local Plugins
description: Add inspection and packaging behavior for one directory with internal Version 1 plugins.
sidebar_position: 11
---

# Trusted Local Plugins

Version 1 local plugins are useful when a directory needs build-time behavior
that does not belong in the declarative specification.

:::warning

Plugins are trusted, unsandboxed PowerShell and use an internal contract that may
change before a public SDK exists. Keep them in the directory, review them like
build code, and test them against the generator version used by CI.

:::

This example reads a directory policy during inspection and writes it into the
generated module during packaging.

## Layout

```text
PSModule/
├── PSModule.psd1
└── Plugins/
    ├── Inspectors/
    │   └── 90.DirectoryPolicyInspector.ps1
    └── PackagingProviders/
        └── 90.DirectoryPolicyPackagingProvider.ps1
directory-policy.json
```

The built-in packaging provider validates the core package before the directory's
`90` provider adds supplemental metadata.

## Directory Input

Create `directory-policy.json`:

```json
{
  "owner": "platform-team",
  "supportTier": "production"
}
```

## Inspector

Create `PSModule/Plugins/Inspectors/90.DirectoryPolicyInspector.ps1`:

```powershell
param (
    [Parameter(Mandatory)]
    [psobject] $Context
)

$policyPath = Join-Path $Context.DirectoryPath 'directory-policy.json'
$Context.Inspection['DirectoryPolicy'] = if (
    Test-Path -LiteralPath $policyPath -PathType Leaf
) {
    Get-Content -LiteralPath $policyPath -Raw |
        ConvertFrom-Json -ErrorAction Stop
}
else {
    $null
}
```

The inspector always publishes the `DirectoryPolicy` key, using `$null` when the
optional file is absent.

## Packaging Provider

Create
`PSModule/Plugins/PackagingProviders/90.DirectoryPolicyPackagingProvider.ps1`:

```powershell
param (
    [Parameter(Mandatory)]
    [psobject] $Context
)

if ($null -eq $Context.Inspection['DirectoryPolicy']) {
    return
}

$metadataDirectory = Join-Path $Context.OutputPath 'Metadata'
$policyOutput = Join-Path $metadataDirectory 'directory-policy.json'
$null = New-Item -Path $metadataDirectory -ItemType Directory -Force

$Context.Inspection['DirectoryPolicy'] |
    ConvertTo-Json -Depth 10 |
    Set-Content -LiteralPath $policyOutput -Encoding utf8NoBOM -NoNewline

$Context.Artifacts['DirectoryPolicy'] = Get-Item -LiteralPath $policyOutput
```

The provider writes only under the validated output directory and publishes the
result through `Artifacts`.

## Inspect Before Building

```powershell
$inspection = Get-PSModuleInspection `
    -Specification ./PSModule/PSModule.psd1

$inspection.Data.DirectoryPolicy
$inspection | Get-PSModuleDiagnostic -Detailed
```

## Generate and Verify

```powershell
Build-PSModule `
    -Specification ./PSModule/PSModule.psd1 `
    -Output ./artifacts/PSModule

Get-Content ./artifacts/PSModule/Metadata/directory-policy.json
```

Because the plugins are beside the specification, no explicit `-PluginPath` is
needed.

## Testing Guidance

Test:

- the file-present case;
- the file-absent case;
- malformed JSON behavior;
- deterministic JSON property and array ordering required by the directory;
- plugin discovery order;
- the generated relative path; and
- detailed diagnostics on failure.

Avoid persisting secrets or machine-specific absolute paths.
