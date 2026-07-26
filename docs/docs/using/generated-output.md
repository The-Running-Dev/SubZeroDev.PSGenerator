---
title: Generated Output
description: Deterministic module artifacts and their runtime roles.
sidebar_position: 9
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
│   └── model.json
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
- generated function exports; and
- empty cmdlet, variable, and alias exports.

The manifest is validated before packaging completes.

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
generated files. Output is reset only after specification and model validation pass.
If validation fails, existing output remains unchanged.

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
