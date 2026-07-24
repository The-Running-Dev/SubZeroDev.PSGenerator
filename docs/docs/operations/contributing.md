---
title: Contributing
description: Prepare focused changes and validate them before review.
sidebar_position: 2
---

# Contributing

## Before starting

1. Read the [Architecture overview](../architecture/overview.md).
2. Check the engineering roadmap in `TODO.md`.
3. Check documentation work in `docs/TODO.md`.
4. Confirm an open pull request does not already address the same change.

## Change scope

Keep pull requests reviewable:

- one coherent behavior or documentation milestone;
- tests beside behavior changes;
- documentation beside public contract changes;
- no unrelated formatting churn; and
- no generated artifacts unless the repository explicitly tracks them.

Use a `feature/` branch for planned work.

## PowerShell style

- Target PowerShell 7.4.
- Use approved verbs and `Verb-Noun` public names.
- Enable strict mode in standalone build scripts.
- Prefer literal paths for filesystem operations.
- Preserve deterministic ordinal ordering.
- Emit UTF-8 without BOM for generated text.
- Never embed local absolute paths in generated source.
- Keep `Build-ContainerModule` orchestration-only.

Run:

```powershell
./build/Invoke-Quality.ps1 -InstallDependencies
```

## Tests

Behavior changes require focused Pester coverage:

```powershell
Invoke-Pester -Path ./tests -Output Detailed
```

Changes to packaging, manifests, minimum runtime behavior, runtime mappings, or
container installation should also run the relevant scripts:

```powershell
./build/Test-PowerShellBaseline.ps1
./build/Test-GeneratorNuGetPackage.ps1
```

Run the Docker end-to-end suite when container behavior changes.

## Inspector changes

For an inspector:

- define the exact repository input boundary;
- sort inputs and outputs deterministically;
- respect common path exclusions;
- preserve relative `/`-separated paths;
- add empty-input and representative-input fixtures;
- add malformed-input coverage; and
- document the supported subset and output shape.

Do not imply full YAML, JSON Schema, OpenAPI, Dockerfile, or project-system support
when the parser intentionally implements a subset.

## Plugin changes

The plugin context is internal in Version 1. Built-in and repository plugin changes
must preserve stage boundaries and provide actionable execution diagnostics. Do not
present a new context field as stable public API.

## Documentation changes

Documentation pages use:

- YAML front matter with `title`, `description`, and `sidebar_position`;
- one level-one heading matching the page title;
- relative links;
- fenced code blocks with a language;
- Docusaurus admonitions only when they remain understandable in source Markdown;
- commands runnable from a stated working directory; and
- implemented behavior only.

Each category contains `_category_.json`.

## Pull request checklist

- [ ] Scope is focused.
- [ ] New behavior has tests.
- [ ] Public behavior has documentation.
- [ ] Quality checks pass.
- [ ] Relevant Pester tests pass.
- [ ] Docker or package checks pass when applicable.
- [ ] No secrets, machine paths, or unrelated files are included.
- [ ] The PR description states impact and validation.
