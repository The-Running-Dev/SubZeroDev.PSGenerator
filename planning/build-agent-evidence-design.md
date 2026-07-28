# Build-Agent Evidence and Inference Design

## Status

Proposed.

## Purpose

Infer useful container PowerShell commands from repositories shaped like
Docker-BuildAgent without depending on that repository by name or running its
build. The implementation should combine static evidence already present in a
repository:

- .NET project relationships;
- NUKE schema and configuration;
- C# build entry points and parameter models;
- generated PowerShell-module parameter metadata;
- PowerShell dispatch and module exports.

The result must be reusable for other NUKE-based repositories and deterministic
on Windows and Linux.

## Current behavior and gap

The existing BuildAgent fixture proves that an authored module specification can
be built, imported, and invoked. It also proves basic `.csproj` and
`.nuke/build.schema.json` inspection.

It does not reproduce the inference problem because its specification already
contains `Invoke-BuildAgent`. It also lacks representative C# build sources,
generated module metadata, and dispatch code. A separate empty-specification
fixture is therefore required. The current authored fixture remains valuable and
must not be repurposed or weakened.

The historical `$schema` configuration leak has already been corrected. New
tests should preserve that fix with a negative assertion rather than model the
leak as expected behavior.

## Design principles

1. Inspect source; never execute a repository's build or scripts during
   discovery.
2. Record evidence before inferring commands.
3. Preserve provenance so every inferred value can be explained.
4. Prefer explicit public interfaces over implementation conventions.
5. Merge compatible evidence; report incompatible evidence.
6. Keep the supported C# subset intentionally small and documented.
7. Do not hardcode repository names, paths, build types, or command names.

## Dedicated inference fixture

Add `tests/fixtures/directories/BuildAgentInference` while retaining the existing
`BuildAgent` runtime fixture.

The new fixture should be minimal but realistic:

```text
BuildAgentInference/
├── .nuke/
│   ├── build.schema.json
│   └── parameters.json
├── PSModule/
│   └── PSModule.psd1
├── scripts/
│   └── powershell-module/
│       ├── BuildAgent.psm1
│       ├── parameters.json
│       └── Update-ModuleParameters.ps1
└── src/
    ├── Build/
    │   ├── Build.csproj
    │   ├── Build.cs
    │   └── *Params.cs
    ├── Build.Tests/
    │   └── Build.Tests.csproj
    └── Common/
        └── Common.csproj
```

The fixture must include:

- an empty inferred module specification;
- an executable build project plus test and shared project references;
- at least two build types;
- an inherited parameter class;
- XML documentation;
- scalar, array, generic, nullable, defaulted, and secret parameters;
- NUKE target and typed-parameter metadata;
- generated `parameters.json`;
- a PowerShell dispatcher with a literal `ValidateSet`;
- literal exported module functions;
- one intentional compatible overlap between evidence sources;
- one intentional conflict used only by focused conflict tests.

`Update-ModuleParameters.ps1` is reference behavior and a test oracle. Discovery
must not invoke it.

Tests must copy the fixture into `$TestDrive` before running inference against
it, the way the existing inspector tests already do. This fixture is the first
one designed to be written into rather than only read: inference materializes
commands into a specification that starts empty. Generating in place against the
checked-in copy would both modify a tracked file and, since specification
initialization now mints a random identity for any specification that does not
already record a valid one, produce different content on every run.

## Evidence model

Inspectors add records to `Context.Inspection.CommandEvidence`. Each record has
the following normalized fields:

| Field | Meaning |
| --- | --- |
| `Kind` | `Project`, `NukeSchema`, `NukeConfig`, `CSharp`, `GeneratedMetadata`, or `PowerShell` |
| `SourcePath` | Repository-relative source path |
| `Subject` | Stable build type, target, command, or parameter identity |
| `Property` | The fact being asserted |
| `Value` | Normalized scalar or collection value |
| `Confidence` | `Explicit`, `Strong`, or `Heuristic` |
| `Authoritative` | Whether disagreement must stop inference |
| `Inspector` | Plugin that produced the evidence |

Records are data only. An inspector must not directly create a final command
when multiple sources are involved.

Paths are repository-relative with `/` separators. Collections are sorted and
deduplicated with ordinal-ignore-case comparison. Original spelling is retained
from the highest-precedence source.

`CommandEvidence` is public. `Get-PSModuleInspection` returns
`Data = $context.Inspection` verbatim, so anything added to
`Context.Inspection` is part of the command's result whether or not this
document says so. Treat the field table above as the consumer-visible contract:
field names and meanings are additive-only once released, and a breaking change
to an existing field follows the same compatibility bar as any other public
property of the inspection result.

## Source precedence

For the same property, use this order:

1. authored module exports and explicit dispatch mappings;
2. generated PowerShell-module metadata;
3. NUKE schema metadata;
4. C# declarations and attributes;
5. NUKE configuration values;
6. project-graph and naming heuristics.

Precedence is property-specific, not record-specific. For example, PowerShell
may authoritatively name a command while C# provides its parameter description.

Equal-precedence incompatible values produce a conflict diagnostic and suppress
that candidate. A lower-precedence incompatible value produces a warning and is
retained as provenance, but the higher-precedence value wins. Secrets are never
downgraded: if any credible source marks a parameter secret, the merged
parameter is secret.

## C# source inspector

### Supported subset

The first version statically recognizes:

- namespace and class declarations;
- build entry classes;
- `Base<TParams>` inheritance;
- `*Params` classes and their inheritance chains;
- public properties;
- XML summary documentation;
- `[Parameter]` and `[Secret]` attributes;
- literal defaults;
- arrays, common generics, and nullable types.

It resolves source-local inheritance, detects cycles, and emits a diagnostic for
unresolved bases. It does not compile or load repository assemblies.

### Parsing approach

Use a focused lexical and structural parser:

1. tokenize while preserving source offsets and masking strings/comments;
2. balance braces and brackets;
3. identify supported declarations;
4. associate attributes and XML documentation by source position;
5. normalize recognized type syntax.

Do not use regular expressions over raw C# as the primary parser. Do not add a
runtime Roslyn download or execute `dotnet` during inspection. Unsupported syntax
is skipped with a structured warning when it affects a candidate.

## Generated metadata inspector

Read generated module `parameters.json` only from known PowerShell-module
locations discovered from project evidence or under `scripts/`. Accept a
documented schema version and reject ambiguous shapes.

The inspector extracts:

- build type;
- parameter name;
- PowerShell type;
- mandatory/default state;
- validation values;
- secret state;
- description;
- static arguments.

Malformed explicitly referenced metadata is authoritative and fails inspection.
Incidental metadata discovered by convention warns and is skipped.

## PowerShell dispatch inspector

Extend AST-based inspection only for files admitted by the existing path policy.
Recognize:

- literal `Export-ModuleMember -Function` values;
- manifest `FunctionsToExport`;
- literal `ValidateSet` build-type values;
- literal dispatch hashtables and switch branches;
- static command prefixes and arguments.

Dynamic expressions are not evaluated. When a value cannot be proven statically,
record a warning and leave it unresolved.

## Candidate normalization

After inspectors finish, a merger groups evidence by normalized build type and
produces candidates with:

- suggested PowerShell command name;
- build type;
- executable/project scope;
- static command prefix and arguments;
- targets;
- parameters;
- source provenance;
- confidence;
- conflicts and warnings.

Command naming follows existing PSGenerator naming rules. A name found in an
explicit export wins over a generated name. Candidates are sorted by build type
and command name.

Only conflict-free candidates meeting the minimum evidence threshold are
materialized into an inferred specification. The initial threshold is:

- a build type from an explicit dispatch/export, generated metadata, NUKE
  schema, or C# build entry; and
- a runnable mapping from explicit dispatch metadata or a statically proven
  project/build prefix.

Parameter evidence alone never creates a command.

## Static prefix model

Represent invocation as structured tokens rather than one shell string:

```powershell
@{
    Executable = 'dotnet'
    Arguments  = @('run', '--project', 'src/Build/Build.csproj', '--')
}
```

Repository-relative paths remain relative in the model and are resolved by the
generated wrapper at runtime. No developer-machine absolute paths may enter the
specification or artifact.

## Tests

Add focused tests for:

- the empty fixture initially producing evidence but no false commands;
- the historical `$schema` value remaining excluded;
- project containment and executable selection;
- C# inheritance, cycles, XML docs, types, defaults, and secrets;
- generated metadata parsing and reconciliation;
- literal PowerShell exports, dispatch, and `ValidateSet`;
- precedence and compatible merging;
- conflict diagnostics and candidate suppression;
- deterministic ordering and path normalization;
- complete inference, generation, import, help, and invocation using a mocked or
  harmless build executable.

Tests must prove discovery does not invoke repository scripts, `dotnet`, Docker,
or package managers.

## Delivery slices

1. Add the dedicated fixture and baseline regression tests.
2. Add the evidence schema and deterministic merge primitives.
3. Add the focused C# source inspector.
4. Add generated metadata and PowerShell dispatch evidence.
5. Add candidate merging, precedence, and conflict diagnostics.
6. Materialize accepted candidates and add end-to-end tests and documentation.

Each slice should be independently reviewable and should preserve existing
authored-specification behavior.

## Acceptance criteria

- The authored BuildAgent fixture continues to pass unchanged.
- The inference fixture begins with an empty specification.
- Discovery produces explainable, repository-relative evidence.
- At least two build commands are inferred without running repository code.
- Parameters preserve type, help, validation, defaults, and secret handling.
- Conflicts are visible and never silently choose equal-precedence values.
- Generated wrappers invoke structured static prefixes without absolute paths.
- Repeated Windows and Linux runs produce equivalent ordered output.
