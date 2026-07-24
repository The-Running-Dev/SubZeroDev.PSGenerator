---
title: Runtime mappings
description: Map native PowerShell parameters to Docker runtime arguments.
sidebar_position: 1
---

# Runtime mappings

A mapping connects one generated PowerShell parameter to one or more Docker runtime
arguments. Mappings are emitted only when the caller binds the parameter.

```powershell
Mappings = @(
    @{
        Type = 'Argument'
        Name = '--message'
    }
)
```

Mappings before the image configure Docker. `Argument` mappings are appended after
the image as container-command arguments.

## Summary

| Type | Parameter type | Required properties | Docker output |
| --- | --- | --- | --- |
| `Argument` | Any supported type | `Name` | `IMAGE NAME VALUE` |
| `Environment` | Any supported type | `Name` | `-e NAME=VALUE` |
| `Mount` | Path-like | `Target`, `Access` | `--mount type=bind,...` |
| `Volume` | `string` | `Target`, `Access` | `--mount type=volume,...` |
| `Port` | Integer | `ContainerPort` | `--publish HOST:CONTAINER/PROTOCOL` |
| `WorkingDirectory` | `string` | None | `--workdir VALUE` |
| `RuntimeOption` | Any supported type | `Name` | `--option VALUE` |
| `Device` | `string` or `FileInfo` | None | `--device HOST[:TARGET][:PERMISSIONS]` |
| `Gpu` | `string` | None | `--gpus VALUE` |
| `ResourceLimit` | Depends on resource | `Resource` | `--memory` or `--cpus` |
| `Secret` | `string` or `FileInfo` | `Name` | read-only bind mount |

## Argument

`Name` must be a non-empty string. The name and value appear after the image:

```powershell
@{
    Name = 'Task'
    Type = 'string'
    Mappings = @(
        @{ Type = 'Argument'; Name = '--task' }
    )
}
```

```text
docker run --rm example/build-agent --task Test
```

Array values repeat as ordinary command arguments according to generated runtime
rendering.

## Environment

`Name` must be a non-empty string:

```powershell
@{
    Name = 'Configuration'
    Type = 'string'
    Mappings = @(
        @{ Type = 'Environment'; Name = 'CONFIGURATION' }
    )
}
```

```text
docker run --rm -e CONFIGURATION=Release example/build-agent
```

A parameter can map to both environment and command arguments when the container
interface requires both.

## Bind mount

`Mount` resolves the caller-provided host path to an absolute path. `Target` is the
container path. `Access` is `ReadOnly` or `ReadWrite`:

```powershell
@{
    Name = 'Repository'
    Type = 'DirectoryInfo'
    Mandatory = $true
    Mappings = @(
        @{
            Type   = 'Mount'
            Target = '/repository'
            Access = 'ReadOnly'
        }
    )
}
```

```text
--mount type=bind,source=<absolute-host-path>,target=/repository,readonly
```

Use `FileInfo`, `DirectoryInfo`, or `string` when the bound value can be resolved as
a host path.

## Named volume

The parameter value is the Docker volume name. `Target` must be an absolute
container path without commas:

```powershell
@{
    Name = 'CacheVolume'
    Type = 'string'
    Mappings = @(
        @{
            Type   = 'Volume'
            Target = '/cache'
            Access = 'ReadWrite'
        }
    )
}
```

Unsafe volume names are rejected before Docker is called.

## Port

The parameter supplies the host port and must use `int`, `long`, `System.Int32`, or
`System.Int64`. `ContainerPort` is an integer from 1 through 65535. `Protocol` is
optional and defaults to `tcp`:

```powershell
@{
    Name = 'HostPort'
    Type = 'int'
    Mappings = @(
        @{
            Type          = 'Port'
            ContainerPort = 8080
            Protocol      = 'tcp'
        }
    )
}
```

Host ports outside 1 through 65535 are rejected at invocation time.

## Working directory

A command may contain at most one `WorkingDirectory` mapping:

```powershell
@{
    Name = 'WorkingDirectory'
    Type = 'string'
    Mappings = @(
        @{ Type = 'WorkingDirectory' }
    )
}
```

Empty bound values are rejected.

## Generic runtime option

`Name` must be a lowercase long Docker option such as `--network`:

```powershell
@{
    Name = 'Network'
    Type = 'string'
    Mappings = @(
        @{ Type = 'RuntimeOption'; Name = '--network' }
    )
}
```

A switch parameter emits only the option. Scalar values emit an option/value pair.
Array values repeat the pair:

```text
--label first --label second
```

Use a dedicated mapping instead of `RuntimeOption` when one exists; dedicated
mappings provide stronger validation.

## Device

The parameter must use `string`, `FileInfo`, or `System.IO.FileInfo`. `Target` is
optional and must be an absolute container path without colons or commas.
`Permissions` is an optional ordered combination of `r`, `w`, and `m`:

```powershell
@{
    Name = 'Device'
    Type = 'FileInfo'
    Mappings = @(
        @{
            Type        = 'Device'
            Target      = '/dev/example'
            Permissions = 'rw'
        }
    )
}
```

Device access depends on host capabilities and Docker permissions.

## GPU

The parameter must use `string`:

```powershell
@{
    Name = 'Gpu'
    Type = 'string'
    Mappings = @(
        @{ Type = 'Gpu' }
    )
}
```

Runtime values accept:

- `all`;
- a positive count such as `1`; or
- a selector such as `device=0,1`.

GPU execution requires a compatible host and container runtime configuration.

## Resource limits

Memory uses a string:

```powershell
@{
    Name = 'Memory'
    Type = 'string'
    Mappings = @(
        @{ Type = 'ResourceLimit'; Resource = 'Memory' }
    )
}
```

Values use Docker memory syntax such as `512m`.

CPUs use `int`, `long`, `double`, or `decimal`:

```powershell
@{
    Name = 'Cpus'
    Type = 'double'
    Mappings = @(
        @{ Type = 'ResourceLimit'; Resource = 'Cpus' }
    )
}
```

Numeric CPU values are rendered culture-invariantly.

## Secret

The parameter supplies an existing host file and must use `string`, `FileInfo`, or
`System.IO.FileInfo`. `Name` is a safe file name. The default target is
`/run/secrets/<Name>`:

```powershell
@{
    Name = 'SecretFile'
    Type = 'FileInfo'
    Mappings = @(
        @{
            Type = 'Secret'
            Name = 'api-token'
        }
    )
}
```

An optional `Target` overrides the absolute container path:

```powershell
@{
    Type   = 'Secret'
    Name   = 'api-token'
    Target = '/app/secrets/token'
}
```

Version 1 implements secrets as read-only bind mounts because standalone
`docker run` does not use the Swarm secret flag.

## Multiple mappings

A parameter can define multiple mappings. They run in declaration order within the
runtime model:

```powershell
Mappings = @(
    @{ Type = 'Environment'; Name = 'EXAMPLE_MESSAGE' }
    @{ Type = 'Argument'; Name = '--message' }
)
```

Use `-WhatIf` to verify the final ordering without starting Docker.
