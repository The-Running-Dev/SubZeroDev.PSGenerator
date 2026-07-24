# Repository-Generated PowerShell Container Modules

> **Status:** Version 1 behavior contract and release roadmap
>
> **Working Title:** Container Module Generator (CMG)
>
> **Target Platform:** PowerShell 7.4+, Docker

The generator and every generated module manifest declare PowerShell 7.4 as their
minimum supported runtime.

---

# Purpose

Container Module Generator (CMG) generates repository-specific PowerShell modules for containerized applications.

Instead of exposing Docker commands directly, repositories define a PowerShell-oriented specification describing their public interface. During the normal repository build, CMG generates a complete, self-contained PowerShell module which is embedded into the resulting container image.

End users install the module directly from the image and interact with the application through ordinary PowerShell commands rather than raw `docker run` invocations.

The repository remains the single source of truth.

---

# Version 1 Boundary

The core Version 1 workflow described here is implemented: specification validation,
model normalization, repository inspection, deterministic module and Markdown
generation, Docker command rendering, `/PSModule` packaging, installation, import,
help, preview, and invocation.

Items explicitly described as remaining Version 1 work are release-hardening tasks,
not implemented behavior. They are tracked in `TODO.md`. Anything under
**Deferred to Phase 2** is outside the Version 1 contract. Repository plugins are an
internal, trusted-code extension mechanism in Version 1; a stable public plugin SDK
is Phase 2 work.

---

# Design Principles

Version 1 is guided by the following principles:

- Use native PowerShell concepts wherever practical.
- Prefer convention over configuration.
- Generate complete PowerShell source code.
- Produce deterministic output.
- Keep the specification declarative by default.
- Allow extensibility through explicit plugin mechanisms.
- Favor clarity over minimizing duplication.
- Keep build-time intelligence separate from runtime execution.

---

# High-Level Architecture

```text
Repository
│
├── PSModule/
│   └── PSModule.psd1
│
├── Source
│
└── Build
      │
      ▼
Build-ContainerModule
      │
      ▼
Generated PowerShell Module
      │
      ▼
Embedded in Docker Image
      │
      ▼
Install-ContainerModule
      │
      ▼
Imported locally
      │
      ▼
Native PowerShell Experience
```

---

# Repository Layout

Default specification location:

```text
PSModule/
└── PSModule.psd1
```

Alternative specification:

```powershell
Build-ContainerModule -Specification ./config/MyModule.psd1
```

---

# Generated Output

Default output:

```text
artifacts/PSModule/
├── <ModuleName>.psd1
├── <ModuleName>.psm1
├── Documentation/
│   └── <CommandName>.md
├── Metadata/
│   └── model.json
├── Public/
│   └── <CommandName>.ps1
└── Scripts/                 # only when repository scripts are packaged
```

Only required directories are generated.

Output location may be overridden:

```powershell
Build-ContainerModule -Output ./dist
```

Each build overwrites previously generated output.

The generator validates the specification before clearing the selected output directory. It then writes a module manifest whose root module, version, and exported functions match the normalized model.

---

# Build Model

The generated module is produced during the normal repository build.

Repository authors generally do not execute the generator manually.

Typical pipeline:

```text
Build Application
        │
Build-ContainerModule
        │
Copy module into image
        │
Docker Build
        │
Publish
```

---

# Generated Code

CMG generates complete PowerShell source code.

Generated modules are self-contained.

They include:

- A module manifest and loader
- Public functions
- Parameter declarations
- Supported validation and static completion attributes
- Comment-based help and Markdown command references
- Docker invocation
- Local packaged-script invocation for inferred PowerShell commands
- `-WhatIf` preview and verbose timing
- Error handling

The generated module does not depend on a shared runtime library.

---

# Internal Generator Architecture

CMG constructs a complete internal object model before rendering PowerShell.

Pipeline:

```text
Repository
      │
Inspectors
      │
Validators
      │
Object Model Processors
      │
Runtime Adapters
      │
Code Generators
      │
Template Renderers
      │
Packaging Providers
```

PowerShell is rendered from templates using the object model.

---

# Plugin Architecture

Every processing stage is plugin-based.

Pipeline stages include:

- Inspectors
- Validators
- Object Model Processors
- Runtime Adapters
- Code Generators
- Template Renderers
- Packaging Providers

Plugins receive a shared mutable build context containing the specification,
inspection data, normalized model, render requests, artifacts, and execution
diagnostics.

The core engine is responsible for:

- Plugin discovery
- Ordering
- Diagnostics
- Pipeline orchestration

---

# Plugin Discovery

Plugins are automatically discovered.

Each plugin is a trusted PowerShell script with a mandatory `Context` parameter.
Version 1 does not expose a stable plugin interface or sandbox plugin execution.

Execution order is determined by filename prefix.

Example:

```text
00.DockerfileInspector.ps1
05.ComposeInspector.ps1
10.ReadmeInspector.ps1
20.NukeInspector.ps1
90.Validation.ps1
```

Plugins execute in ascending lexical order.

---

# Repository Inspection

Repository inspection occurs through independent inspector plugins.

Inspectors may analyze:

- Dockerfiles
- Docker Compose
- PowerShell
- README
- GitHub Actions
- NUKE
- .NET projects
- Node projects
- Configuration schemas
- OpenAPI
- Additional technologies

Trusted repository inspectors can be added beneath the conventional
`PSModule/Plugins/Inspectors` directory or an explicitly selected plugin root. They
run with the invoking PowerShell process's filesystem, process, network, and
credential access.

The current Compose, GitHub Actions, and OpenAPI YAML inspectors intentionally parse
a limited line-oriented subset without a shared YAML dependency. Documenting that
subset and applying the final malformed-input policy across every inspector remain
Version 1 hardening work. The target policy is to warn and continue for malformed
optional artifacts while failing for explicitly authoritative inputs such as
`*.schema.json`.

---

# Build Command

The build process exposes a single command:

```powershell
Build-ContainerModule
```

Pipeline stages are internal implementation details.

Debugging and diagnostics are provided through dedicated developer commands rather than build switches.

---

# Cross-Platform Support

Generated modules execute correctly on all supported platforms.

Windows and Linux are supported Version 1 platforms and are validated in CI. macOS is
best-effort for Version 1 and is not a required CI platform. PowerShell 7.4 is the
Version 1 support baseline. Every shipped and generated manifest enforces that
baseline, and CI validates it on Windows and Linux.

The generator handles:

- Path normalization
- Home directory resolution
- Environment variables
- Filesystem differences
- Process invocation
- Runtime detection

Repository authors should not write platform-specific specifications whenever practical.

---

# Container Module Location

Generated modules are embedded inside every compliant image at:

```text
/PSModule
```

Install-ContainerModule retrieves the module from this location.

Installation creates a temporary container without starting it, stages `/PSModule` beside the destination, validates its single module manifest, and removes the temporary container even when copying or validation fails. Existing destinations require `-Force` and are only replaced after validation succeeds. The command supports `-WhatIf`.

Local installation defaults to:

```text
~/PSModule
```

Override:

```powershell
Install-ContainerModule -Destination ~/Modules
```

---

# Repository Specification

The repository specification uses PowerShell PSD1.

Collections are represented as arrays of typed objects.

The specification favors explicit objects over nested hashtables.

Optional module identity properties are:

```powershell
ModuleName = "BuildAgent"
ModuleVersion = "0.1.0"
ContainerImage = "ghcr.io/example/build-agent:latest"
```

`ModuleName` must be safe for use as a file name and begin with a letter. `ModuleVersion` must be a valid PowerShell version string. `ContainerImage` must be a container image reference without whitespace. When omitted, the values default to `PSModule`, `0.1.0`, and the resolved module name respectively.

---

# Commands

Commands are defined as arrays of objects.

The `Commands` property is optional. When present, it must be an array. Each command must define a non-empty string `Name`, and command names must be unique without regard to case.

Command names use PowerShell `Verb-Noun` syntax. Version 1 command names contain letters and numbers with a single separator hyphen.

```powershell
Commands = @(
    @{
        Name = "Invoke-BuildAgent"
        Description = "Build repository"

        Parameters = @(...)
    }
)
```

---

# Parameters

Parameters are arrays of typed objects.

The `Parameters` property is optional on a command. When present, it must be an array. Each parameter must define a non-empty string `Name` and `Type`. Parameter names must be unique within their command without regard to case. When specified, `Mandatory` must be Boolean.

Parameter names must be valid PowerShell identifiers. Version 1 type names support simple or namespace-qualified names and optional array suffixes, such as `string`, `System.Uri`, and `string[]`.

```powershell
Parameters = @(
    @{
        Name = "Repository"
        Type = "DirectoryInfo"
        Mandatory = $true
    }
)
```

---

# PowerShell Types

The specification uses native PowerShell types.

The generator emits the declared type name directly into generated PowerShell.
Built-in aliases normalize `switch`, `FileInfo`, and `DirectoryInfo`; other simple or
namespace-qualified types must resolve when the generated module is imported.
Examples include:

- string
- string[]
- bool
- switch
- int
- long
- double
- decimal
- Guid
- Version
- Uri
- DateTime
- TimeSpan
- FileInfo
- DirectoryInfo
- SecureString
- PSCredential
- Existing enumeration types

No custom type system is introduced.

---

# Validation

Version 1 supports declarative `ValidateSet`, `ValidateRange`, and
`ValidatePattern` objects:

```powershell
Validations = @(
    @{ Type = "ValidateSet"; Values = @("Build", "Test") }
    @{ Type = "ValidateRange"; Minimum = 1; Maximum = 10 }
    @{ Type = "ValidatePattern"; Pattern = "^[a-z]+$" }
)
```

The generator validates these definitions and renders them as native PowerShell parameter attributes.

---

# Extensibility

The specification is declarative by default.

Where declarative metadata cannot express required behavior, explicit PowerShell extension points may be referenced.

Extension points include:

- Validation
- Completion
- Discovery
- Repository-specific behaviors

External PowerShell files are preferred over embedded script blocks.

Version 1 supports declarative static argument completion through typed providers:

```powershell
Completions = @(
    @{ Type = "Static"; Values = @("Build", "Test") }
)
```

Static providers require unique, non-empty string values and render PowerShell's native `ArgumentCompletions` attribute. Multiple static providers on a parameter are combined in declaration order.

---

# Help

The specification contains:

- Synopsis
- Description
- Parameter descriptions
- Notes
- Basic examples

Command and parameter `Description` values are rendered as comment-based help. Generated commands support PowerShell's common `-WhatIf` parameter and display the planned Docker invocation without executing it.

Commands may define `Synopsis`, `Description`, and `Notes` as non-empty strings. For compatibility, `Description` is used as the synopsis when `Synopsis` is omitted.

The generator writes deterministic Markdown documentation for every command under `Documentation/`. Each page contains syntax, descriptions, parameter details, examples, and notes from the normalized model. Authored description and note content may use Markdown.

---

# Examples

Examples are structured objects.

Each example requires non-empty `Code` and `Description` strings:

```powershell
Examples = @(
    @{
        Code = "Invoke-BuildAgent -Repository . -Task Build"
        Description = "Builds the current repository."
    }
)
```

The generator renders them into:

- Get-Help
- Deterministic Markdown command references

Version 1 generates command reference pages. Cross-command tutorials remain part of advanced documentation generation deferred to Phase 2.

---

# Parameter Mappings

Mappings are first-class typed objects.

The `Mappings` property is optional on a parameter. When present, it must be an array. Each mapping must be an object with a supported, non-empty string `Type`. Unknown mapping types are rejected so that a specification cannot silently omit runtime behavior. Rules for the properties required by each mapping type are applied separately.

Repository-specific runtime intent is not inferred from script names, source paths,
or other naming conventions. Authors explicitly declare mappings whenever a command
requires container runtime behavior.

```powershell
Mappings = @(
    @{
        Type = "Mount"
        Target = "/repository"
        Access = "ReadOnly"
    }

    @{
        Type = "Environment"
        Name = "BUILD_REPOSITORY"
    }

    @{
        Type = "Argument"
        Name = "--repository"
    }
)
```

Supported mappings include:

- Arguments
- Environment variables
- Bind mounts
- Named volumes
- Ports
- Working directory
- Resource limits
- Devices
- GPU
- Secrets
- Runtime options

`Argument` and `Environment` mappings require a non-empty string `Name`.

Generated commands place environment mappings before the image reference and argument mappings after it. Parameters omitted by the caller do not produce runtime arguments.

`Mount` mappings require a non-empty string container `Target`. `Access` must be `ReadOnly` or `ReadWrite`. Generated commands resolve the supplied host path to an absolute path and emit a Docker bind mount before the image reference.

`Port` mappings use an integer parameter for the host port and require a `ContainerPort` from 1 through 65535. Optional `Protocol` values are `tcp` (the default) or `udp`. Generated commands reject out-of-range host ports and emit `--publish host:container/protocol`.

`WorkingDirectory` mappings use a string parameter and emit `--workdir`. A command may define at most one working-directory mapping, and bound values cannot be empty.

`Volume` mappings use a string parameter for the Docker volume name and require an absolute container `Target` plus `ReadOnly` or `ReadWrite` access. They emit Docker `--mount type=volume` options.

`RuntimeOption` mappings require a lowercase long-option `Name`, such as `--network`. Switch parameters emit the option alone; other parameters emit option/value pairs before the image reference, repeating pairs for array values.

`Device` mappings use a `string` or `FileInfo` parameter for a host device path. An optional absolute container `Target` and ordered `Permissions` combination of `r`, `w`, and `m` produce Docker `--device` arguments; permissions default to Docker's behavior when omitted.

`Gpu` mappings use a string parameter and emit Docker `--gpus`. Runtime values accept `all`, a positive GPU count, or a device selector such as `device=0,1`.

`ResourceLimit` mappings define a `Resource` of `Memory` or `Cpus`. Memory uses a string value such as `512m`; CPUs use a positive numeric value. Generated commands emit `--memory` or `--cpus` using culture-invariant values.

`Secret` mappings use a `string` or `FileInfo` parameter for a host secret file and require a safe `Name`. Because standalone `docker run` does not provide the Swarm secret flag, generated commands mount the file read-only at `/run/secrets/<Name>` or an optional absolute container `Target`.

A parameter may define multiple mappings.

---

# Typed Objects

Objects supporting multiple variants include a `Type` property.

Examples include:

- Parameter mappings
- Parameter validations
- Completion providers

Objects whose type is implied by their containing collection may omit `Type`.

---

# Object Identity

Major specification objects may define an optional `Id`.

Version 1 supports `Id` on the specification root, commands, and parameters. Ids begin with a letter or number, may contain letters, numbers, dots, underscores, and hyphens, and must be unique without regard to case across the specification.

Ids provide stable identifiers for:

- Validation
- Diagnostics
- Cross references
- Plugin communication
- Future schema evolution

---

# Runtime Model

The specification describes runtime requirements rather than Docker syntax.

Docker is the initial runtime.

Future runtime adapters (for example, Podman) should consume the same mapping model.

---

# Simplicity

Version 1 intentionally avoids:

- Object inheritance
- Templates
- Object composition
- Reuse mechanisms

Objects remain explicit and self-contained.

---

# Deferred to Phase 2

Topics intentionally deferred include:

- Plugin SDK
- Third-party plugin packaging
- Stable plugin interfaces
- Plugin versioning
- Extension model refinement
- Object reuse mechanisms
- Additional runtime adapters
- Advanced documentation generation

---

# Success Criteria

The project succeeds when a repository author can define a PowerShell specification, build the repository, embed the generated module into the image, and allow end users to install it directly from that image.

Users should be able to execute:

```powershell
Install-ContainerModule ghcr.io/the-running-dev/build-agent:latest

Invoke-BuildAgent -Repository . -Task Build

Get-Help Invoke-BuildAgent
```

without manually constructing `docker run` commands.

The repository remains the authoritative definition of the public interface while the generated module provides a native PowerShell experience.
