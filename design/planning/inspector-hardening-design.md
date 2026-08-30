# Inspector Hardening Design

## Status

Accepted. All findings from independent review are resolved; see
[the peer review](../../peer-review.md) and
[the implementation plan](next-engineering-set-implementation-plan.md).

## Purpose

Make repository inspection predictable when inputs are malformed, incomplete,
generated, duplicated, or outside the supported parser subset. Hardening must
protect discovery without hiding actionable problems.

## Policy

Every inspected input is classified before parsing:

| Classification | Example | Malformed behavior |
| --- | --- | --- |
| Authoritative | configured specification, explicit manifest reference | record error and fail |
| Conventional | recognized file in a documented location | record warning and skip file |
| Incidental | broad recursive discovery match | record warning only when the file was otherwise a credible candidate |
| Unsupported | valid syntax outside the documented subset | record warning and preserve any safely parsed evidence |

An inspector must not terminate the whole pipeline for a malformed optional
input. It also must not silently ignore a malformed authoritative input.

### Issues on the failure path

`Get-PSModuleInspection` returns `Issues` only on success. A plugin that throws
for an authoritative failure propagates through
`Invoke-PSModulePluginPipeline` and `Invoke-PSModuleInspection` as an
exception, so `Get-PSModuleInspection` never returns the result object that
would have carried `Issues` — a caller catching that exception has no
documented way to reach the stable code and path the classification table
above promises. This is true today: `Invoke-PSModulePluginPipeline` already
wraps every plugin exception in `System.InvalidOperationException` unless
`$_.Exception.Data['PSModule.PreserveType']` says otherwise, and it collects
`$Context.PluginExecutions` in a `finally` block regardless of which path is
taken.

The issue channel follows that existing pattern rather than inventing a
second return shape. Every issue recorded before the fatal one, plus the
fatal one itself, is attached to the thrown exception as
`$_.Exception.Data['PSModule.InspectionIssues']`, an array of the same typed
records `Issues` would have contained on success. A caller that wants
structured detail from an authoritative failure reads
`$_.Exception.Data['PSModule.InspectionIssues']` from the catch block; a
caller that only wants the message keeps working unchanged, since the
exception's own message is unaffected. `Get-PSModuleInspection` itself still
throws rather than returning a partial result — a caller must not mistake
inspection run against an authoritative failure for a complete one.

## Structured inspection issues

Plugin execution diagnostics and source-data issues are different concepts. Keep
the existing `PluginExecutions` behavior intact and add
`Context.InspectionIssues`, exposed as `Issues` on
`SubZeroDev.PSGenerator.InspectionResult`.

Each issue contains:

| Field | Meaning |
| --- | --- |
| `Severity` | `Warning` or `Error` |
| `Code` | Stable machine-readable identifier |
| `Inspector` | Producing plugin |
| `Path` | Repository-relative path when available |
| `Message` | Actionable user-facing summary |
| `ExceptionType` | Parser exception type when relevant |
| `Details` | Optional detailed context without secrets |

Add one private helper to validate and append issues. Issue order is inspector
execution order, then repository-relative path, then code.

`Get-PSModuleInspection` returns issues without changing existing properties.
`Get-PSModuleDiagnostic` retains its current default plugin-execution output and
gains an `-IncludeIssues` switch. This avoids silently changing the public output
shape for existing callers. When requested, issue records use a distinct
`SubZeroDev.PSGenerator.InspectionIssueDiagnostic` type, emitted after every
plugin-execution record in the same stream. A caller distinguishes the two by
type rather than by position, but the fixed order means issues can always be
read as commentary on a complete execution list rather than interleaved with
it.

Warnings should be visible during interactive inspection once, while structured
issues remain available for automation. Tests should avoid depending on rendered
warning text when a stable code is available.

## Shared path policy

All recursive inspectors must use one path-admission helper. It must:

- exclude the requested output directory;
- exclude `.git`, `artifacts`, `bin`, `obj`, `node_modules`, package caches, and
  common generated documentation/build directories;
- retain source metadata directories such as `.nuke`;
- reject nested repositories;
- reject files that resolve outside the repository root;
- avoid following directory symlink/reparse-point cycles;
- normalize comparisons for platform casing rules;
- handle spaces and mixed separators;
- produce repository-relative `/` paths for diagnostics.

Traversal should enumerate shallow candidates first and sort before parsing.
A visited-real-path set prevents cycles and duplicate inspection.

## Parser boundary

Each inspector documents:

- admitted filenames and locations;
- authoritative versus optional inputs;
- supported syntax subset;
- recoverable versus fatal parse failures;
- evidence emitted from partial parses.

Parser exceptions must be caught at the file boundary, not around the entire
inspector. One bad optional file must not discard valid evidence from other
files.

## Inspector matrix

### Dockerfile

Support:

- line continuations;
- multiple stages;
- `ARG` declared before `FROM`;
- variable substitution in `FROM` when statically resolvable;
- stage aliases;
- basic label, workdir, entrypoint, and command metadata.

Unresolved dynamic `FROM` values warn and preserve the raw value. Invalid
instructions in an incidental Dockerfile do not fail unrelated inspection.

### Compose

Document and test the supported YAML subset. Recognize services, image/build
context, Dockerfile, environment names, ports, volumes, command, and entrypoint
when expressed in supported scalar/list/map forms.

YAML anchors, merges, tags, and expressions outside the subset warn rather than
being guessed. An explicitly configured Compose file is authoritative.

### Project manifests

Catch XML and JSON errors per file. Project files that are explicit roots are
authoritative; recursively found auxiliary projects are conventional.

Normalize project references, reject containment escapes, and report unresolved
references without invoking restore or evaluation.

### README

Treat README parsing as optional. Invalid encoding or unsupported structures
warn and do not stop other inspectors. Never execute embedded examples.

### PowerShell

Use the PowerShell parser and retain parse errors as issues. A manifest or module
explicitly selected as the public interface is authoritative. Incidental scripts
with parse errors are skipped.

AST inspection never imports or dot-sources source modules.

### GitHub Actions

Document the supported YAML subset and expression handling. Extract only
statically provable workflow, job, step, input, and command facts. Unsupported
expressions remain raw evidence with a warning.

### NUKE

An explicitly located `.nuke/build.schema.json` is authoritative for NUKE
evidence. Configuration files are conventional unless referenced. Exclude
metadata properties such as `$schema` and preserve typed values.

### Configuration schemas

Files explicitly named or referenced as schemas are authoritative. Incidental
JSON files must not be treated as schemas solely because they parse.

### OpenAPI

An explicitly referenced contract is authoritative. Conventionally named
contracts warn and skip on malformed content. Document supported JSON and YAML
subsets, references, operations, parameters, and schema constructs.

## Security and privacy

- Never include secret values in issue details.
- Cap source excerpts and nested exception depth.
- Do not resolve network references.
- Do not execute parsers supplied by the inspected repository.
- Apply file-size and collection-count limits with explicit issue codes.
- Treat symlinks and junctions as untrusted traversal boundaries.

## Stable issue codes

Initial codes should follow these categories:

- `PATH_*` for exclusion, escape, cycle, and duplicate paths;
- `PARSE_*` for malformed input;
- `SUBSET_*` for unsupported valid syntax;
- `REFERENCE_*` for missing or escaping references;
- `CONFLICT_*` for incompatible evidence;
- `LIMIT_*` for safety limits.

Codes are public automation contracts once released. Messages may improve
without changing their meaning.

## Tests

Create focused fixtures covering:

- malformed authoritative and optional files for every inspector;
- multiple project roots;
- path casing and spaces;
- nested repositories;
- symlink/junction escape and cycle behavior where the platform permits;
- mixed valid and invalid files;
- deterministic issue ordering;
- redaction and safety limits;
- supported and unsupported YAML forms;
- Dockerfile continuations and `ARG`-based `FROM`;
- Windows and Linux path equivalence.

Tests should assert codes, severity, path, and continuation/failure behavior.
They should not assert incidental exception wording from framework parsers.

## Delivery slices

1. Add the issue model, helper, result property, and opt-in diagnostic output.
2. Centralize traversal, containment, exclusion, and cycle protection.
3. Harden JSON, XML, PowerShell, and text inspectors at per-file boundaries.
4. Define and harden the Compose, workflow, and OpenAPI YAML subsets.
5. Extend Dockerfile parsing and metadata.
6. Add the cross-platform malformed-input and filesystem fixture matrix.

## Acceptance criteria

- A malformed optional file cannot erase valid inspection data from other files.
- A malformed authoritative file fails with a stable issue code and useful path.
- Existing plugin-execution diagnostics remain backward compatible.
- Every recursive inspector uses the shared path policy.
- No inspector follows a path outside the repository root.
- Supported subsets and unsupported behavior are documented and tested.
- Issue output is deterministic and contains no secret values.
