---
title: Generated Output
description: Deterministic module artifacts and their runtime roles.
sidebar_position: 10
---

# Generated Output

The default generated directory is `artifacts/PSModule`.

```text
artifacts/PSModule/
├── <ModuleName>.psd1
├── <ModuleName>.psm1
├── Documentation/
│   └── <CommandName>.md
├── Metadata/
│   ├── model.json
│   └── output.json
├── Public/
│   └── <CommandName>.ps1
└── Scripts/
    └── ... packaged directory scripts ...
```

Directories are created only when needed. A specification with no commands imports
without a `Public` directory.

## Module Manifest

`<ModuleName>.psd1` declares:

- the generated loader as `RootModule`;
- the normalized module version;
- PowerShell 7.4;
- generated function exports;
- empty cmdlet, variable, and alias exports; and
- private PSGenerator provenance containing the generator name and specification
  ID.

The manifest is validated before packaging completes.

The private provenance lets specification initialization distinguish an earlier
generated build from an unrelated installed module with the same name. It does
not contain a source-directory path or machine-specific value.

An inferred specification identity is the module name followed by a random
suffix minted once, when the specification is first written. Initialization
reuses the identity already recorded in a specification, so refreshing a
directory keeps producing byte-identical output while two directories that infer
the same module name stay distinguishable. Authoring `Id` explicitly overrides
the inferred value and is preserved the same way.

## Module Loader

`<ModuleName>.psm1` dot-sources every generated public command in deterministic name
order and exports the resulting functions.

## Public Commands

Each command has one parseable `.ps1` file containing:

- comment-based help;
- native parameter declarations;
- validation attributes;
- static completion attributes;
- `SupportsShouldProcess` behavior for `-WhatIf`;
- local-source or Docker runtime execution;
- verbose tracing; and
- focused error handling.

Generated files do not depend on the generator at runtime.

## Markdown Command References

`Documentation/<CommandName>.md` contains:

- syntax;
- synopsis and description;
- parameter details;
- examples; and
- notes.

The page derives from the same normalized model as comment-based help. CI verifies
that the content survives image packaging and installation byte-for-byte.

## Model Metadata

`Metadata/model.json` is deterministic UTF-8 JSON representing module identity,
container image, commands, parameters, validations, completions, and mappings.

`Build-PSModule` returns this file as its pipeline output.

## Output Ownership Marker

`Metadata/output.json` identifies a directory prepared by PSGenerator. It contains
only a fixed schema version, generator name, and artifact type. It has no source or
output path, user, host, process, timestamp, credential, or changing generator
version. The file is deterministic UTF-8 JSON without a byte-order mark.

The marker prevents accidental replacement of an unrelated non-empty directory. It
is an ownership hint, not authentication or a security boundary: anyone who can
write the directory can copy or alter it. Specifications and plugins remain trusted
code.

The marker is written immediately after an admitted output directory is reset and
before renderers run. A later renderer failure therefore leaves marked partial output
that a retry can replace without force. Package completion requires a valid marker,
so partial output is not accepted as a completed package.

## Guarded Replacement

Before reset, output is classified as follows:

| State | Default behavior |
| --- | --- |
| Missing | Create and mark it. |
| Empty | Replace and mark it. Hidden entries count as content. |
| Owned | Replace it; `Metadata/output.json` is valid. |
| Legacy | Replace and migrate a valid pre-marker generated package. |
| Unowned | Preserve it and fail unless `-Force` is explicit. |

A legacy package must have valid Version 1 `Metadata/model.json` identity plus its
paired root manifest and loader. Recognition reads data only; it never imports or
executes the old package.

The following targets are always rejected, with or without `-Force`:

- a filesystem root;
- the inspected source directory or any directory containing it;
- the specification directory or any directory containing it;
- an existing file;
- a linked output directory; and
- a path equal to, inside, or containing the source `scripts` tree.

Checks use both the selected path and a bounded resolved path so an intermediate
symbolic link or Windows junction cannot disguise a source relationship. Link state
can change concurrently, so the output leaf and resolved identity are checked again
immediately before deletion. This narrows the race window but is not a transactional
filesystem guarantee.

First and repeat builds need no force:

```powershell
Build-PSModule -Output ./artifacts/PSModule
Build-PSModule -Output ./artifacts/PSModule
```

To adopt an unrelated directory, inspect it first and then opt in deliberately:

```powershell
Get-ChildItem ./selected-output -Force
Build-PSModule -Output ./selected-output -Force
```

Prefer a dedicated generated-output directory or move valuable files before using
`-Force`. Force bypasses only ownership classification; it cannot bypass any unsafe
path denial.

## Packaged Scripts

When inferred source commands exist, the complete directory `scripts` tree is
copied to `Scripts` once. Relative paths and supporting non-PowerShell files are
preserved.

Generated wrappers resolve their source relative to the installed module:

- `SourceKind = 'Script'` invokes the packaged `.ps1`;
- `SourceKind = 'ModuleFunction'` imports the packaged `.psm1` and invokes its
  explicitly exported function module-qualified.

## Determinism

Repeated builds from the same specification and directory inputs produce identical
generated files. Output is asserted and reset only after specification and model
validation pass. If validation or a pre-reset runtime adapter fails, existing output
remains unchanged. A failure after reset leaves marked partial output for a safe
retry.

The outer NuGet archive may contain packaging metadata such as ZIP timestamps; the
deterministic contract applies to the generated module files.

## Source Control and Build Artifacts

Recommended ownership:

| Content | Recommendation |
| --- | --- |
| `PSModule/PSModule.psd1` | Commit |
| Directory `scripts` | Commit |
| Trusted local plugins | Commit and review |
| `artifacts/PSModule` | Generate in build/CI |
| `.nupkg` | Publish or retain as CI artifact |
| Installed module directory | Local user state |
