---
title: Specification reference
description: Complete Version 1 PSModule.psd1 property reference.
sidebar_position: 1
---

# Specification reference

The default repository specification is:

```text
PSModule/PSModule.psd1
```

It must be a PowerShell data file that imports as an `IDictionary`. Use arrays for
all collections, including single-item collections.

## Complete example

```powershell
@{
    Id             = 'repository.example'
    ModuleName     = 'ExampleContainer'
    ModuleVersion  = '0.1.0'
    ContainerImage = 'ghcr.io/example/example-container:latest'

    Commands = @(
        @{
            Id          = 'command.invoke-example'
            Name        = 'Invoke-Example'
            Synopsis    = 'Runs the example container.'
            Description = 'Runs the selected task inside the example image.'
            Notes       = 'Docker is required unless using -WhatIf.'

            Examples = @(
                @{
                    Code        = 'Invoke-Example -Task Test'
                    Description = 'Runs the test task.'
                }
            )

            Parameters = @(
                @{
                    Id          = 'parameter.task'
                    Name        = 'Task'
                    Type        = 'string'
                    Mandatory   = $true
                    Description = 'Task passed to the container.'

                    Validations = @(
                        @{
                            Type   = 'ValidateSet'
                            Values = @('Build', 'Test')
                        }
                    )

                    Completions = @(
                        @{
                            Type   = 'Static'
                            Values = @('Build', 'Test')
                        }
                    )

                    Mappings = @(
                        @{
                            Type = 'Argument'
                            Name = '--task'
                        }
                    )
                }
            )
        }
    )
}
```

## Root object

| Property | Type | Required | Default | Rules |
| --- | --- | --- | --- | --- |
| `Id` | String | No | Null | Globally unique specification ID |
| `ModuleName` | String | No | `PSModule` | Begins with a letter; letters, numbers, `.`, `_`, `-` |
| `ModuleVersion` | String | No | `0.1.0` | Must parse as `System.Version` |
| `ContainerImage` | String | No | Resolved module name | Safe image-reference characters; no whitespace |
| `Commands` | Array | No | Empty | Array of command objects |

The generated manifest uses `ModuleName` for its base name, exports every normalized
command, declares `ModuleVersion`, and requires PowerShell 7.4.

## Object IDs

`Id` is supported on:

- the root specification;
- commands; and
- parameters.

An ID:

- starts with a letter or number;
- contains only letters, numbers, dots, underscores, and hyphens; and
- is unique without regard to case across the entire specification.

IDs appear in model metadata and validation context. Use stable semantic IDs rather
than array positions.

## Command object

| Property | Type | Required | Rules |
| --- | --- | --- | --- |
| `Id` | String | No | Global ID rules |
| `Name` | String | Yes | `Verb-Noun`; letters and numbers only |
| `Synopsis` | String | No | Non-empty when present |
| `Description` | String | No | Non-empty when present |
| `Notes` | String | No | Non-empty when present |
| `Examples` | Array | No | Structured example objects |
| `Parameters` | Array | No | Parameter objects |

Command names are unique without regard to case. Version 1 accepts exactly one
hyphen and requires each side to begin with a letter:

```text
Invoke-BuildAgent
Get-Report2
```

Names such as `build`, `Invoke-My-Tool`, and `Invoke-Tool_Name` are rejected.

## Example object

| Property | Type | Required | Rules |
| --- | --- | --- | --- |
| `Code` | String | Yes | Non-empty PowerShell example |
| `Description` | String | Yes | Non-empty explanation |

Examples are rendered into comment-based help and generated Markdown.

## Parameter object

| Property | Type | Required | Default | Rules |
| --- | --- | --- | --- | --- |
| `Id` | String | No | Null | Global ID rules |
| `Name` | String | Yes | — | PowerShell identifier |
| `Type` | String | Yes | — | Simple or namespace-qualified type, optional `[]` |
| `Mandatory` | Boolean | No | `$false` | Must be Boolean when present |
| `Description` | String | No | Null | Non-empty when present |
| `Validations` | Array | No | Empty | Validation objects |
| `Completions` | Array | No | Empty | Completion objects |
| `Mappings` | Array | No | Empty | Runtime mapping objects |

Parameter names begin with a letter or underscore and then contain letters, numbers,
or underscores. Names are unique without regard to case within their command.

## Parameter types

The type name is emitted directly into generated PowerShell. Supported syntax is a
simple or namespace-qualified name with an optional array suffix:

```text
string
string[]
System.Uri
DirectoryInfo
System.IO.FileInfo
switch
```

Common useful types include:

- `string`, `bool`, `switch`;
- `byte`, `short`, `int`, `long`, `float`, `double`, `decimal`;
- `Guid`, `Version`, `Uri`, `DateTime`, `TimeSpan`;
- `FileInfo`, `DirectoryInfo`;
- `SecureString`, `PSCredential`; and
- enumeration types available when the generated module imports.

`SwitchParameter` and its namespace-qualified form normalize to `switch`.
Unresolvable types fail when the generated module is imported.

## Validation objects

| Type | Required properties | Rules |
| --- | --- | --- |
| `ValidateSet` | `Values` | Non-empty string array |
| `ValidateRange` | `Minimum`, `Maximum` | Numeric; ascending |
| `ValidatePattern` | `Pattern` | Non-empty valid .NET regex |

Unknown validation types are rejected.

## Completion objects

Version 1 supports one completion type:

```powershell
@{
    Type   = 'Static'
    Values = @('Build', 'Test')
}
```

Values are non-empty strings and unique without regard to case across all completion
providers on the parameter. Unknown completion types are rejected.

## Mapping objects

Every mapping requires `Type`. Supported values are:

- `Argument`
- `Environment`
- `Mount`
- `Volume`
- `Port`
- `WorkingDirectory`
- `RuntimeOption`
- `Device`
- `Gpu`
- `ResourceLimit`
- `Secret`

Unknown mapping types are rejected. See
[Runtime mappings](../guides/runtime-mappings.md) for properties, type constraints,
runtime validation, and examples.

## Inference-owned source properties

Generated scaffolds may add:

| Property | Location | Meaning |
| --- | --- | --- |
| `GeneratedBy` | Root | Marks generator ownership for safe refresh |
| `SourcePath` | Command | Path beneath the repository `scripts` directory |
| `SourceKind` | Command | `Script` or `ModuleFunction` |

These properties support script inference and packaged local execution. They are not
a general mechanism for executing arbitrary files outside `scripts`.

## Additional properties

Version 1 validators reject unsupported types inside known typed collections.
Unrecognized properties elsewhere are not a stable extension contract; they may
remain in the original `Definition` object but are not guaranteed to affect
generation. Repository-specific behavior belongs in a trusted plugin.

## Validate and inspect

```powershell
Test-ContainerModuleSpecification `
    -Specification ./PSModule/PSModule.psd1

Get-ContainerModuleModel `
    -Specification ./PSModule/PSModule.psd1
```
