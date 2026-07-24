---
title: Build your first module
description: Define, validate, generate, import, and preview a container module.
sidebar_position: 2
---

# Build your first module

This tutorial creates a repository specification manually. Run the commands from the
root of a repository where ContainerPSGenerator is already imported.

## 1. Create the specification

Create `PSModule/PSModule.psd1`:

```powershell
@{
    Id             = 'repository.hello'
    ModuleName     = 'HelloContainer'
    ModuleVersion  = '0.1.0'
    ContainerImage = 'ghcr.io/example/hello-container:latest'

    Commands = @(
        @{
            Id          = 'command.invoke-hello'
            Name        = 'Invoke-Hello'
            Synopsis    = 'Runs the hello container.'
            Description = 'Runs the hello container with a caller-provided message.'

            Examples = @(
                @{
                    Code        = "Invoke-Hello -Message 'hello'"
                    Description = 'Sends a greeting to the container.'
                }
            )

            Parameters = @(
                @{
                    Id          = 'parameter.message'
                    Name        = 'Message'
                    Type        = 'string'
                    Mandatory   = $true
                    Description = 'Message passed to the container.'

                    Validations = @(
                        @{
                            Type    = 'ValidatePattern'
                            Pattern = '^.{1,100}$'
                        }
                    )

                    Mappings = @(
                        @{
                            Type = 'Argument'
                            Name = '--message'
                        }
                    )
                }
            )
        }
    )
}
```

Arrays are required for `Commands`, `Parameters`, `Examples`, `Validations`,
`Completions`, and `Mappings`, even when a collection contains one object.

## 2. Validate

```powershell
Test-ContainerModuleSpecification `
    -Specification ./PSModule/PSModule.psd1
```

The command returns `True` or throws a terminating validation error. Validate before
adding generation to CI so identity, type, help, and mapping errors remain easy to
locate.

Inspect the normalized model:

```powershell
$model = Get-ContainerModuleModel `
    -Specification ./PSModule/PSModule.psd1

$model.Commands.Parameters.Mappings
```

## 3. Generate

```powershell
$metadata = Build-ContainerModule `
    -Specification ./PSModule/PSModule.psd1 `
    -Output ./artifacts/PSModule
```

`Build-ContainerModule` returns the generated `Metadata/model.json` file. The full
module is under `artifacts/PSModule`:

```text
artifacts/PSModule/
├── HelloContainer.psd1
├── HelloContainer.psm1
├── Documentation/
│   └── Invoke-Hello.md
├── Metadata/
│   └── model.json
└── Public/
    └── Invoke-Hello.ps1
```

Generation replaces the selected output directory only after specification and
normalized-model validation succeed.

## 4. Import and inspect

```powershell
Import-Module ./artifacts/PSModule/HelloContainer.psd1 -Force

Get-Command -Module HelloContainer
Get-Help Invoke-Hello -Full
Get-Content ./artifacts/PSModule/Documentation/Invoke-Hello.md
```

## 5. Preview before execution

```powershell
Invoke-Hello -Message hello -WhatIf
```

The preview shows the planned `docker run --rm` command without discovering or
starting Docker:

```text
docker run --rm ghcr.io/example/hello-container:latest --message hello
```

Use verbose output for runtime discovery, the exact argument list, attachment
behavior, elapsed time, and exit code:

```powershell
Invoke-Hello -Message hello -Verbose
```

## 6. Embed the module

Copy the generated directory to `/PSModule` in the final image. See
[Container packaging and installation](../guides/container-packaging.md) for a
Dockerfile and installation workflow.
