---
title: Command Reference
description: Public PSGenerator command syntax, parameters, and outputs.
sidebar_position: 8
---

# Command Reference

Import the generator before using these commands:

```powershell
Import-Module ./src/SubZeroDev.PSGenerator.psd1 -Force
```

## Build-PSModule

Runs all seven ordered stages and writes a complete module.

```powershell
Build-PSModule `
    [-Specification <string>] `
    [-Output <string>] `
    [-PluginPath <string[]>]
```

| Parameter | Default | Description |
| --- | --- | --- |
| `Specification` | `PSModule/PSModule.psd1` | Directory PSD1 |
| `Output` | `artifacts/PSModule` | Generated module directory |
| `PluginPath` | Conventional sibling `Plugins` | Additional trusted plugin roots |

Built-in plugins always execute. Explicit plugin paths are added to built-ins. When
`PluginPath` is omitted, a `Plugins` directory beside the specification is used when
present.

Returns the generated `Metadata/model.json` `FileInfo`.

## Test-PSModuleSpecification

Runs built-in Version 1 validators without generating output:

```powershell
Test-PSModuleSpecification `
    [-Specification <string>]
```

Returns `True` or throws a terminating error.

## Get-PSModuleModel

Validates and normalizes a specification:

```powershell
Get-PSModuleModel `
    [-Specification <string>]
```

Returns `SubZeroDev.PSGenerator.Model` with module identity, container
image, commands, parameters, validations, completions, mappings, and original
definition objects.

## Initialize-PSModuleSpecification

Inspects a directory and writes an initial scaffold:

```powershell
Initialize-PSModuleSpecification `
    [-Directory <string>] `
    [-Specification <string>] `
    [-Force] `
    [-PassThru] `
    [-WhatIf]
```

| Parameter | Default | Description |
| --- | --- | --- |
| `Directory` | `.` | Directory to inspect |
| `Specification` | `PSModule/PSModule.psd1` | Relative or absolute destination |
| `Force` | False | Replace an existing specification |
| `PassThru` | False | Return the created `FileInfo` |

Without `-PassThru`, successful creation has no pipeline output.

## Get-PSModuleInspection

Runs inspector plugins without generating a module:

```powershell
Get-PSModuleInspection `
    [-Specification <string>] `
    [-PluginPath <string[]>]
```

Returns `SubZeroDev.PSGenerator.InspectionResult`:

| Property | Meaning |
| --- | --- |
| `DirectoryPath` | Resolved directory |
| `SpecificationPath` | Resolved PSD1 |
| `Data` | Ordered inspection dictionary |
| `PluginExecutions` | Ordered execution records |

## Get-PSModuleDiagnostic

Formats execution records from an inspection or runs inspection directly:

```powershell
Get-PSModuleDiagnostic `
    [-Specification <string>] `
    [-PluginPath <string[]>] `
    [-Detailed]

$inspection | Get-PSModuleDiagnostic [-Detailed]
```

The concise output contains stage, execution order, plugin, duration, and success.
`-Detailed` adds path, start time, and error text.

## Get-PSModulePlugin

Discovers plugins without executing them:

```powershell
Get-PSModulePlugin `
    -Path <string[]> `
    [-Stage <string[]>]
```

Valid stages:

- `Inspectors`
- `Validators`
- `ObjectModelProcessors`
- `RuntimeAdapters`
- `CodeGenerators`
- `TemplateRenderers`
- `PackagingProviders`

Returns deterministic plugin metadata including stage, execution order, numeric
prefix, name, filename, and resolved path. Roots must be unique and filenames must
match `<numeric-prefix>.<name>.ps1`.

## Install-PSModule

Copies and validates `/PSModule` from an image:

```powershell
Install-PSModule `
    -Image <string> `
    [-Destination <string>] `
    [-Force] `
    [-WhatIf]
```

| Parameter | Default | Description |
| --- | --- | --- |
| `Image` | Required | Safe Docker image reference |
| `Destination` | `~/PSModule` | Local installation directory |
| `Force` | False | Replace after staged validation |

Returns the installed directory as `DirectoryInfo`.

## Generated Commands

Generated container-backed commands:

- expose specification parameters;
- support `-WhatIf`;
- emit verbose runtime details;
- call `docker run --rm`;
- throw when Docker is missing; and
- throw when Docker returns a non-zero exit code.

Inferred `Script` and `ModuleFunction` commands execute their packaged PowerShell
source rather than Docker.
