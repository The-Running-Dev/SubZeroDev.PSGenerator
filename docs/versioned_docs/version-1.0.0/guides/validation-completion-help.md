---
title: Validation, completion, and help
description: Add native PowerShell ergonomics to generated commands.
sidebar_position: 2
---

# Validation, Completion, and Help

The specification generates native PowerShell attributes and help. Validation runs
before Docker, and help works without the container runtime.

## ValidateSet

```powershell
Validations = @(
    @{
        Type   = 'ValidateSet'
        Values = @('Build', 'Test')
    }
)
```

`Values` must be a non-empty string array.

## ValidateRange

```powershell
Validations = @(
    @{
        Type    = 'ValidateRange'
        Minimum = 1
        Maximum = 10
    }
)
```

Both values must be numeric and `Minimum` cannot exceed `Maximum`.

## ValidatePattern

```powershell
Validations = @(
    @{
        Type    = 'ValidatePattern'
        Pattern = '^[a-z]+$'
    }
)
```

`Pattern` must be a non-empty, valid .NET regular expression.

Multiple validations are rendered in declaration order:

```powershell
@{
    Name = 'Task'
    Type = 'string'
    Validations = @(
        @{ Type = 'ValidateSet'; Values = @('Build', 'Test') }
        @{ Type = 'ValidatePattern'; Pattern = '^[A-Z][a-z]+$' }
    )
}
```

## Static Completion

Completion suggests values without restricting the caller:

```powershell
Completions = @(
    @{
        Type   = 'Static'
        Values = @('bridge', 'host', 'none')
    }
)
```

Values must be non-empty strings and unique without regard to case across every
static provider on the parameter. Multiple providers are combined in declaration
order and rendered with PowerShell's native `ArgumentCompletions` attribute.

Use `ValidateSet` when other values must be rejected. Use static completion when the
list is helpful but not exhaustive.

## Command Help

Commands may define:

| Property | Purpose |
| --- | --- |
| `Synopsis` | One-line summary shown by help |
| `Description` | Detailed command behavior |
| `Notes` | Operational constraints or caveats |
| `Examples` | Structured code and explanation |

```powershell
@{
    Name        = 'Invoke-BuildAgent'
    Synopsis    = 'Runs a directory build.'
    Description = 'Runs the selected target inside the build-agent image.'
    Notes       = 'Docker must be available unless using -WhatIf.'

    Examples = @(
        @{
            Code = 'Invoke-BuildAgent -Directory . -Task Test'
            Description = 'Runs tests for the current directory.'
        }
    )
}
```

`Synopsis`, `Description`, and `Notes`, when present, must be non-empty strings.
When `Synopsis` is omitted, `Description` supplies compatibility synopsis text.

Each example requires non-empty `Code` and `Description` strings.

## Parameter Help

```powershell
@{
    Name        = 'Directory'
    Type        = 'DirectoryInfo'
    Mandatory   = $true
    Description = 'Directory directory mounted at /directory.'
}
```

Generated help includes the type, mandatory state, description, validation, and
accepted pipeline behavior from the generated declaration.

## Generated Outputs

The same normalized help model produces:

- comment-based help returned by `Get-Help`; and
- deterministic Markdown under `Documentation/<CommandName>.md`.

Check both during directory review:

```powershell
Get-Help Invoke-BuildAgent -Full
Get-Content ./artifacts/PSModule/Documentation/Invoke-BuildAgent.md
```
