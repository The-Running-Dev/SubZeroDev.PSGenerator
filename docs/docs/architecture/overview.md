---
title: Architecture overview
description: How repository inputs become a self-contained PowerShell module.
sidebar_position: 1
---

# Architecture overview

ContainerPSGenerator separates build-time analysis from generated-module runtime
execution.

```text
Repository inputs
      │
      ▼
Build-ContainerModule
      │
      ├── Inspectors
      ├── Validators
      ├── Object model processors
      ├── Runtime adapters
      ├── Code generators
      ├── Template renderers
      └── Packaging providers
      │
      ▼
Self-contained PowerShell module
      │
      ├── import locally
      └── embed at /PSModule
```

## Repository is the source of truth

The authored PSD1 defines the public command surface. Inspectors add repository
facts, but Version 1 does not guess container mappings from file names or paths.

Generated output is reproducible build output, not the authoritative definition.

## Build context

Every stage receives one mutable context:

| Property | Purpose |
| --- | --- |
| `SpecificationPath` | Resolved source PSD1 |
| `OutputPath` | Resolved generation directory |
| `RepositoryPath` | Repository root inferred from specification location |
| `Specification` | Imported data-file dictionary |
| `Inspection` | Ordered repository metadata |
| `Model` | Validated normalized model |
| `Artifacts` | Published generated files and package |
| `RenderRequests` | Source payloads awaiting rendering |
| `PluginExecutions` | Ordered timing and failure records |

When the specification is directly beneath `PSModule`, the repository root is its
parent. For an alternate specification location, that file's directory is the
inspection root.

## Stage responsibilities

### Inspectors

Read repository artifacts and add typed, ordered metadata to `Inspection`. They do
not create build output.

### Validators

Reject invalid identity, command, parameter, help, object ID, validation, completion,
mapping, and runtime definitions.

### Object model processors

Create the normalized `Model`. The orchestrator fails immediately if this stage does
not produce one.

### Runtime adapters

Select and attach runtime behavior. Version 1 uses Docker for container-backed
commands and preserves packaged local execution for inferred PowerShell sources.

### Code generators

Reset the validated output destination and generate in-memory source and metadata
requests. Output reset happens only after validation and model creation.

### Template renderers

Write metadata, command source, Markdown references, loader, and manifest. The
orchestrator requires the metadata artifact before packaging begins.

### Packaging providers

Verify required files, command pages, command source, artifact paths, and manifest
validity, then publish the completed package artifact.

## Deterministic boundaries

Determinism comes from:

- ordered arrays and dictionaries in the normalized model;
- ordinal plugin and input sorting;
- one generated file per responsibility;
- UTF-8 output conventions; and
- a full output reset at the generation boundary.

Plugin behavior and changing external repository inputs can affect output, so
trusted plugins must impose their own deterministic ordering.

## Runtime behavior

Generated modules contain no dependency on ContainerPSGenerator.

Container-backed commands:

1. validate native parameters;
2. convert bound parameters into ordered Docker arguments;
3. support `-WhatIf`;
4. discover Docker only when executing;
5. invoke `docker run --rm`; and
6. report non-zero exits.

Inferred PowerShell commands resolve and execute packaged local source beneath the
module's `Scripts` directory.

## Installation architecture

`Install-ContainerModule` uses `docker create`, not `docker run`, so application
entry points are not started. It copies `/PSModule` into a staging directory,
validates the manifest, replaces the destination only when safe, and always attempts
to remove the temporary container.
