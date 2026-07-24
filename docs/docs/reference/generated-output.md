---
title: Generated output
description: Deterministic module artifacts and their runtime roles.
sidebar_position: 4
---

# Generated output

The default generated directory is `artifacts/PSModule`.

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
└── Scripts/
    └── ... packaged repository scripts ...
```

Directories are created only when needed. A specification with no commands imports
without a `Public` directory.

## Module manifest

`<ModuleName>.psd1` declares:

- the generated loader as `RootModule`;
- the normalized module version;
- PowerShell 7.4;
- generated function exports; and
- empty cmdlet, variable, and alias exports.

The manifest is validated before packaging completes.

## Module loader

`<ModuleName>.psm1` dot-sources every generated public command in deterministic name
order and exports the resulting functions.

## Public commands

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

## Markdown command references

`Documentation/<CommandName>.md` contains:

- syntax;
- synopsis and description;
- parameter details;
- examples; and
- notes.

The page derives from the same normalized model as comment-based help. CI verifies
that the content survives image packaging and installation byte-for-byte.

## Model metadata

`Metadata/model.json` is deterministic UTF-8 JSON representing module identity,
container image, commands, parameters, validations, completions, and mappings.

`Build-ContainerModule` returns this file as its pipeline output.

## Packaged scripts

When inferred source commands exist, the complete repository `scripts` tree is
copied to `Scripts` once. Relative paths and supporting non-PowerShell files are
preserved.

Generated wrappers resolve their source relative to the installed module:

- `SourceKind = 'Script'` invokes the packaged `.ps1`;
- `SourceKind = 'ModuleFunction'` imports the packaged `.psm1` and invokes its
  explicitly exported function module-qualified.

## Determinism

Repeated builds from the same specification and repository inputs produce identical
generated files. Output is reset only after specification and model validation pass.
If validation fails, existing output remains unchanged.

The outer NuGet archive may contain packaging metadata such as ZIP timestamps; the
deterministic contract applies to the generated module files.

## Source control and build artifacts

Recommended ownership:

| Content | Recommendation |
| --- | --- |
| `PSModule/PSModule.psd1` | Commit |
| Repository `scripts` | Commit |
| Trusted repository plugins | Commit and review |
| `artifacts/PSModule` | Generate in build/CI |
| `.nupkg` | Publish or retain as CI artifact |
| Installed module directory | Local user state |
