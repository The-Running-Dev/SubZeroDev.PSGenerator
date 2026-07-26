---
title: Directory Inspection
description: Inspector inputs, supported subsets, exclusions, and output shapes.
sidebar_position: 3
---

# Directory Inspection

Run inspection without generating output:

```powershell
$inspection = Get-PSModuleInspection `
    -Specification ./PSModule/PSModule.psd1

$inspection.Data
$inspection | Get-PSModuleDiagnostic -Detailed
```

Inspector output is an ordered dictionary. Missing artifact types normally produce
an empty collection or an unconfigured object.

## Common Exclusions

Recursive inspectors skip paths containing these segments:

- `.git`
- `node_modules`
- `artifacts`
- `bin`
- `obj`

They also skip nested directories containing their own `.git` marker and the current
generation output directory. Root-only inspectors do not recurse.

## Dockerfiles

**Inputs:** root `Dockerfile`, `Dockerfile.*`, and `*.Dockerfile`.

**Supported subset:** single-line `FROM` with optional `--platform`, image, and
optional `AS` alias.

```text
Dockerfiles[]:
  Path
  Stages[]:
    Image
    Alias
    Platform
```

Continuations and build-argument expansion in `FROM` are not interpreted in the
current Version 1 parser.

## Docker Compose

**Inputs:** root `compose.yaml`, `compose.yml`, `docker-compose.yaml`, and
`docker-compose.yml`.

**Supported subset:**

- top-level `services`;
- service names;
- scalar `image`;
- scalar `build`;
- nested `build.context`;
- nested `build.dockerfile`; and
- list-form `ports`.

```text
ComposeFiles[]:
  Path
  Services[]:
    Name
    Image
    Build:
      Context
      Dockerfile
    Ports[]
```

This is a line-oriented subset, not a complete YAML or Compose implementation.
Anchors, aliases, flow mappings, interpolation semantics, merged configuration, and
extended forms are not resolved.

## .NET Projects

**Inputs:** recursive `*.csproj`.

```text
DotNetProjects[]:
  Path
  Name
  Sdk
  TargetFrameworks[]
  OutputType
  IsExecutable
  IsTestProject
  AssemblyName
  PackageId
  NukeRootDirectory
  NukeScriptDirectory
  PackageReferences[]:
    Name
    Version
  ProjectReferences[]:
    Path
    Aliases[]
```

The first matching property group supplies scalar properties. Package references
support a `Version` attribute or nested `Version` element. `Name` uses
`AssemblyName` when authored and otherwise uses the project filename.
`IsExecutable` recognizes `Exe` and `WinExe`; `IsTestProject` recognizes the
corresponding MSBuild property or a `Microsoft.NET.Test.Sdk` package reference.
Project-reference paths are resolved relative to the declaring project and then
normalized relative to the directory.

Malformed project XML currently terminates inspection.

## Node Projects

**Inputs:** recursive `package.json`.

```text
NodeProjects[]:
  Path
  Name
  Version
  Private
  PackageManager
  Scripts[]
  Dependencies[]
  DevDependencies[]
```

Only property names are retained for scripts and dependencies. Lists are sorted
ordinally. Malformed JSON currently terminates inspection.

## README

**Inputs:** root README with no extension or `.md`, `.markdown`, or `.txt`, matched
without regard to case.

```text
Readmes[]:
  Path
  Title
  Headings[]:
    Level
    Text
  CodeLanguages[]
```

Markdown headings inside fenced code are ignored. Fence languages are recorded in
declaration order. For text READMEs, the first non-empty line is the title.

## PowerShell

**Inputs:** recursive `.ps1`, `.psm1`, and `.psd1` under `scripts` only.

```text
PowerShellFiles[]:
  Path
  Type
  IsCommandCandidate
  SuggestedCommandName
  Parameters[]:
    Name
    Type
    Mandatory
  Functions[]
  Classes[]
  ParseErrors[]
```

Only `.ps1` files are direct command candidates. This inspection data is also used by
initial specification inference.

## GitHub Actions

**Inputs:** root `.github/workflows/*.yml` and `*.yaml`.

**Supported subset:**

- top-level workflow `name`;
- inline `on: [push, pull_request]`;
- mapping keys immediately beneath `on`; and
- job IDs immediately beneath `jobs`.

```text
GitHubActions[]:
  Path
  Name
  Triggers[]
  Jobs[]
```

The parser is line-oriented and does not evaluate reusable workflows, expressions,
anchors, or complete YAML semantics.

## NUKE

**Inputs:**

- `.nuke` directory;
- `.nuke/build.schema.json`;
- `.nuke/parameters.json`;
- .NET projects referencing `Nuke.Common`; and
- recursive `build.ps1`.

```text
Nuke:
  IsConfigured
  SchemaPath
  ParameterNames[]
  ConfiguredParameterNames[]
  Parameters[]:
    Name
    Type
    Description
    Enum[]
    ItemType
    ItemEnum[]
    Default
  Targets[]
  ProjectPaths[]
  BuildScripts[]
```

When `build.schema.json` exists, `ParameterNames` and `Parameters` describe its
resolved `allOf` properties, including local `#/definitions/...` references.
Executable targets come from the `ExecutableTarget` definition.
`parameters.json` is treated as configured values: metadata properties beginning
with `$`, including `$schema`, are excluded from `ConfiguredParameterNames`. When
no build schema exists, those configured names remain the backward-compatible
`ParameterNames` fallback.

This parser resolves only local definition references and does not evaluate external
JSON Schema references or arbitrary composition keywords. Malformed NUKE JSON
currently terminates inspection.

## Configuration Schemas

**Inputs:** recursive `*.schema.json` and JSON documents containing `$schema`.

```text
ConfigurationSchemas[]:
  Path
  Schema
  Id
  Title
  Type
  Required[]
  Properties[]
```

Malformed files explicitly named `*.schema.json` terminate inspection because their
names declare them authoritative. Other malformed JSON files are skipped. Only
top-level schema identity, type, required names, and property names are retained.

## OpenAPI

**Inputs:** recursive JSON or YAML files whose names begin with `openapi` or
`swagger`, without regard to case.

```text
OpenApiDocuments[]:
  Path
  SpecificationVersion
  Title
  ApiVersion
  Paths[]
```

JSON documents read `openapi` or `swagger`, `info.title`, `info.version`, and
top-level path names.

The YAML subset reads scalar `openapi` or `swagger`, `info.title`, `info.version`,
and direct keys under `paths`. It does not implement full YAML semantics.

Malformed OpenAPI JSON currently terminates inspection.

## Diagnostics

Each plugin execution record contains:

```text
Stage
ExecutionOrder
Plugin
Path
StartedAt
Duration
Succeeded
Error
```

Use the concise view in CI logs and `-Detailed` during troubleshooting.
