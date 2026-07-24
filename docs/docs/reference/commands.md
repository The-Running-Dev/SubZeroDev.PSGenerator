---
title: Command reference
description: Public ContainerPSGenerator command syntax, parameters, and outputs.
sidebar_position: 2
---

# Command reference

Import the generator before using these commands:

```powershell
Import-Module ./src/SubZeroDev.ContainerPSGenerator.psd1 -Force
```

## Build-ContainerModule

Runs all seven ordered stages and writes a complete module.

```powershell
Build-ContainerModule `
    [-Specification <string>] `
    [-Output <string>] `
    [-PluginPath <string[]>]
```

| Parameter | Default | Description |
| --- | --- | --- |
| `Specification` | `PSModule/PSModule.psd1` | Repository PSD1 |
| `Output` | `artifacts/PSModule` | Generated module directory |
| `PluginPath` | Conventional sibling `Plugins` | Additional trusted plugin roots |

Built-in plugins always execute. Explicit plugin paths are added to built-ins. When
`PluginPath` is omitted, a `Plugins` directory beside the specification is used when
present.

Returns the generated `Metadata/model.json` `FileInfo`.

## Test-ContainerModuleSpecification

Runs built-in Version 1 validators without generating output:

```powershell
Test-ContainerModuleSpecification `
    [-Specification <string>]
```

Returns `True` or throws a terminating error.

## Get-ContainerModuleModel

Validates and normalizes a specification:

```powershell
Get-ContainerModuleModel `
    [-Specification <string>]
```

Returns `SubZeroDev.ContainerPSGenerator.Model` with module identity, container
image, commands, parameters, validations, completions, mappings, and original
definition objects.

## Initialize-ContainerModuleSpecification

Inspects a repository and writes an initial scaffold:

```powershell
Initialize-ContainerModuleSpecification `
    [-Repository <string>] `
    [-Specification <string>] `
    [-Force] `
    [-PassThru] `
    [-WhatIf]
```

| Parameter | Default | Description |
| --- | --- | --- |
| `Repository` | `.` | Repository to inspect |
| `Specification` | `PSModule/PSModule.psd1` | Relative or absolute destination |
| `Force` | False | Replace an existing specification |
| `PassThru` | False | Return the created `FileInfo` |

Without `-PassThru`, successful creation has no pipeline output.

## Get-ContainerModuleInspection

Runs inspector plugins without generating a module:

```powershell
Get-ContainerModuleInspection `
    [-Specification <string>] `
    [-PluginPath <string[]>]
```

Returns `SubZeroDev.ContainerPSGenerator.InspectionResult`:

| Property | Meaning |
| --- | --- |
| `RepositoryPath` | Resolved repository root |
| `SpecificationPath` | Resolved PSD1 |
| `Data` | Ordered inspection dictionary |
| `PluginExecutions` | Ordered execution records |

## Get-ContainerModuleDiagnostic

Formats execution records from an inspection or runs inspection directly:

```powershell
Get-ContainerModuleDiagnostic `
    [-Specification <string>] `
    [-PluginPath <string[]>] `
    [-Detailed]

$inspection | Get-ContainerModuleDiagnostic [-Detailed]
```

The concise output contains stage, execution order, plugin, duration, and success.
`-Detailed` adds path, start time, and error text.

## Get-ContainerModulePlugin

Discovers plugins without executing them:

```powershell
Get-ContainerModulePlugin `
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

## Install-ContainerModule

Copies and validates `/PSModule` from an image:

```powershell
Install-ContainerModule `
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

## Generated commands

Generated container-backed commands:

- expose specification parameters;
- support `-WhatIf`;
- emit verbose runtime details;
- call `docker run --rm`;
- throw when Docker is missing; and
- throw when Docker returns a non-zero exit code.

Inferred `Script` and `ModuleFunction` commands execute their packaged PowerShell
source rather than Docker.
