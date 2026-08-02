# Version 1 roadmap

This roadmap is ordered by dependency and release risk. `Specifications.md` defines
the Version 1 behavior contract and remaining boundary; `README.md` describes what
is implemented today. User, contributor, and release documentation is tracked
separately in [`docs/docs/developing/TODO.md`](docs/docs/developing/TODO.md).

Completed implementation history is summarized below instead of occupying the active
work queue.

## Version 1 policy decisions

- PowerShell 7.4 is the minimum supported version.
- Windows and Linux are supported and validated in CI. macOS is best-effort for
  Version 1 and is not a required CI platform.
- Malformed optional directory artifacts should emit actionable warnings and allow
  inspection to continue. Explicitly authoritative inputs, such as files named
  `*.schema.json`, should fail when malformed.
- Version 1 will document and test the supported subset of Compose, GitHub Actions,
  and OpenAPI YAML instead of adding a shared YAML dependency.
- Runtime mappings that depend on directory-specific invocation intent must be
  authored explicitly. Inference must not guess intent from names or paths.

## 1. MVP blockers

- [x] Make `Build-PSModule` orchestration-only and keep it as the single public
  build command.
- [x] Add deterministic package regression tests that prove repeated builds produce
  identical files without changing current behavior.
- [x] Build and test a packaged copy of the generator module from a clean location
  instead of testing only the development module under `src/`.
- [x] Add maintained integration fixtures for representative script-only and
  build-agent directories without embedding external source checkouts.
- [x] Expand `examples/Minimal` into a buildable, runnable container example covering
  generate, build, install, import, invoke, help, and cleanup.
- [x] Verify generated Markdown documentation in the packaged module end-to-end.
- [x] Reconcile `Specifications.md`, `README.md`, command help, examples, and generated
  documentation with the final Version 1 behavior.
- [x] Stop `Build-PSModule` from recursively clearing an unsafe `-Output` path. Reject
  filesystem roots, source roots, source ancestors, existing files, linked output
  leaves, and any path overlapping the packaged `scripts` tree outright, and require an
  explicit `-Force` before replacing a non-empty directory that is not recognizably
  generator-owned. The scripts overlap was the sharpest case: it deleted the
  source scripts and then copies the output into itself without bound. See
  [`planning/output-path-safety-design.md`](planning/output-path-safety-design.md) and
  its [implementation plan](planning/output-path-safety-implementation-plan.md).

## 2. Release quality gates

- [x] Add PowerShell static analysis and formatting checks.
- [x] Measure the packaged-generator coverage baseline, define a minimum acceptable
  threshold, and enforce it in CI.
- [x] Raise generator and generated-module manifests to PowerShell 7.4 and validate
  that baseline explicitly on Windows and Linux.
- [x] Complete the release-blocking documentation journey in
  [`docs/docs/developing/TODO.md`](docs/docs/developing/TODO.md).

## 3. Docker-BuildAgent compatibility

This work is based on the directory structure and generation flow in
Docker-BuildAgent. It must remain convention-based and reusable: do not hardcode
that directory's name, paths, build types, image, or commands.

Observed source contracts:

- executable NUKE projects are SDK-style `.csproj` files that reference
  `Nuke.Common`, share code through `ProjectReference`, and expose build types such
  as Docker, Forge, Node, and NodeInDocker;
- `.nuke/build.schema.json` contains executable targets and typed NUKE parameter
  metadata, while `.nuke/parameters.json` contains configured values and a
  `$schema` pointer rather than the complete parameter definition;
- C# build classes declare command-line inputs with `[Parameter]` and `[Secret]`,
  and hydrate typed `*Params` classes whose properties carry XML documentation,
  defaults, collection types, and multi-level inheritance;
- the existing `scripts/powershell-module/Update-ModuleParameters.ps1` is the
  proven parameter generator: it scans C# `*Params` classes, extracts property
  name/type/XML summary, strips the `Params` suffix into a build configuration
  name, resolves recursive inheritance with cycle detection, and writes
  `parameters.json`;
- the local `.psm1` and `.psd1` are authored rather than synthesized by the current
  CI workflow. The generated `parameters.json` is an optional validation allow-list
  consumed by `Get-AllowedParametersForType`; the archived module requirements
  describe running the update script manually when C# parameters change;
- the PowerShell build wrapper provides additional dispatch evidence through its
  `ValidateSet`, including build types such as `node-template` that do not have a
  dedicated `.csproj`;
- the container command is an ordered static prefix, `build <type>`, followed by
  kebab-case parameter arguments. Collections repeat their option, Boolean values
  are not automatically equivalent to PowerShell switches, configured arguments
  are overridden by invocation arguments, and secrets must not be written to logs.

Implement the compatibility path in this order:

- [ ] Add a maintained Docker-BuildAgent-shaped fixture containing the smallest
  representative `.csproj` graph, NUKE schemas, C# build/parameter classes,
  `Update-ModuleParameters.ps1` behavior, PowerShell dispatch/module contract, and
  empty PSModule specification. Record the current regression explicitly:
  inspection finds NUKE projects but produces no command candidates and incorrectly
  reports `$schema` as a parameter.
- [ ] Define a single evidence-merging contract instead of treating any inspector as
  the complete source of truth. Collect command and parameter evidence from existing
  module manifests/exports, executable `.ps1` scripts, PowerShell parameter
  attributes, `.nuke/build.schema.json`, `.nuke/parameters.json`, generated module
  `parameters.json`, `.csproj` files, C# NUKE build classes, and inherited C#
  parameter classes. Preserve source path and evidence kind on every inferred value.
- [x] Expand .NET project inspection with effective project name, executable and
  test-project classification, NUKE/MSBuild properties, and normalized
  `ProjectReference` edges. Resolve references only within the inspected directory
  and keep test projects out of command inference.
- [x] Replace the NUKE `parameters.json` name scan with a parser for
  `.nuke/build.schema.json` definitions and `allOf` properties. Capture executable
  targets, parameter name, JSON type, description, enum values, array item type,
  default, and provenance; treat `parameters.json` only as optional configured
  values and ignore metadata keys such as `$schema`.
- [ ] Add a focused C# NUKE source inspector for the syntax used by SDK-style NUKE
  projects. Port the proven, directory-independent behavior of
  `Update-ModuleParameters.ps1` into an internal parser: parameter-class discovery,
  `Params` name normalization, public-property extraction, XML summaries,
  nullable/array/generic types, recursive inheritance, deterministic merging, and
  cycle detection. Extend that baseline with build entry classes, generic
  `Base<TParams, ...>` relationships, `[Parameter]`, `[Secret]`, and initial values.
  Discover source roots from inspected projects instead of hardcoding
  `Forge/Common/Parameters`, and never execute a directory-provided extraction
  script during inspection.
- [ ] When an existing generated PowerShell-module `parameters.json` is present,
  inspect its build configurations and parameter definitions as derived evidence.
  Reconcile it with C# and NUKE schema metadata deterministically, retain provenance,
  and emit diagnostics for stale or conflicting output instead of silently choosing
  one source.
- [ ] Enrich PowerShell AST inspection with parameter help, defaults, aliases,
  `ValidateSet`, and remaining-argument metadata so wrapper scripts can contribute
  build-type and dispatch evidence. Inspect explicit module exports as strong public
  command evidence, keep runnable scripts as command candidates, and identify
  maintenance/generator scripts separately so they are available for review without
  automatically becoming public runtime commands.
- [ ] Introduce a normalized build-command candidate inspection model containing
  build type, suggested PowerShell name, project/script provenance, ordered static
  container arguments, targets, parameters, secret flags, and confidence. Combine
  existing module commands, scripts, `.csproj`, NUKE configuration/schema, generated
  parameter metadata, C# source, and PowerShell wrapper evidence. Merge candidates by
  normalized build type and parameter name, retain all contributing evidence, and
  never infer a runtime command from a project name alone.
- [ ] Define deterministic evidence precedence and conflict behavior. Prefer explicit
  public exports and authored script metadata for command intent, NUKE schema for
  generated targets and CLI types, generated module `parameters.json` for its named
  build configurations, C# attributes/source for secrets, descriptions, defaults,
  and inheritance, and `.csproj` data for project scope and relationships. Emit
  actionable diagnostics when stronger sources disagree instead of dropping the
  weaker evidence silently.
- [ ] Add an explicit specification/model contract for ordered static container
  arguments before mapped parameter arguments. Render and validate commands such as
  `build docker --image-tag value` without embedding directory-specific strings in
  templates or generators.
- [ ] Extend specification initialization to materialize high-confidence normalized
  build-command candidates and report lower-confidence candidates for review. Infer
  as much as the combined evidence proves: command names, static command prefixes,
  parameters, descriptions, defaults, validation/completion data, secret handling,
  kebab-case `Argument` mappings, and repeated collection arguments. Preserve
  ambiguous defaults, Boolean semantics, and runtime mappings specific to the inspected directory
  as explicit review items rather than inventing behavior.
- [ ] Exercise the complete fixture flow: initialize, inspect, generate, import,
  list commands, render help, preview with `-WhatIf`, and assert deterministic
  Docker arguments for Docker, Forge, Node, NodeInDocker, and wrapper-only build
  types, plus the existing exported PowerShell commands and eligible standalone
  scripts. Verify inherited parameters, merged evidence, targets, secrets,
  maintenance-script classification, test-project exclusion, and generated
  documentation. Run the original extractor against fixture input only as a test
  oracle and compare its normalized parameter output with the internal parser;
  production inspection must not invoke it.
- [ ] Document the supported SDK-style `.csproj`, NUKE schema, C# source, and wrapper
  syntax; explain evidence precedence, diagnostics, inference confidence, and the
  boundary where explicit specification authoring remains required.

## 4. Inspector hardening

Complete these in order so every inspector follows the same policy:

- [ ] Implement the Version 1 malformed-input policy: warn and continue for optional
  artifacts, but fail for explicitly authoritative malformed inputs.
- [ ] Confirm recursive inspectors never traverse generated output, dependency,
  cache, or source-control directories.
- [x] Fix the discarded `RemoveEmptyEntries` argument in the path splits used by
  `Resolve-PSModuleInspectionRealPath` and `Test-PSModuleInspectionPath`. PowerShell
  binds `Split(char[])` and treats the option as a third separator, so empty segments
  survive and reach `Join-Path`.
- [ ] Add fixtures for multi-project directories, alternate casing, spaces in paths,
  and symbolic links.
- [ ] Apply focused malformed-input behavior to Dockerfiles, Compose files, project
  manifests, README files, workflows, NUKE configuration, schemas, and OpenAPI
  documents.
- [ ] Test the supported Version 1 subset of Compose, GitHub Actions, and OpenAPI
  YAML; its documentation is tracked separately.
- [ ] Handle Dockerfile continuations, build arguments used by `FROM`, and additional
  instruction metadata.

## 5. End-to-end behavior

- [x] Exercise argument, environment, mount, port, working-directory, volume,
  resource-limit, secret, and runtime-option mappings in the real container test.
- [ ] Exercise device and GPU mappings only on runners that expose the required host
  capabilities; do not make unavailable hardware an MVP blocker.

## 6. Release preparation

- [x] Complete contributor, policy, and release documentation in
  [`docs/docs/developing/TODO.md`](docs/docs/developing/TODO.md).
- [x] Finalize module identity, versioning, tags, release notes, and distribution
  approach. The module is `SubZeroDev.PSGenerator` at `1.0.0`, tagged
  `v<ModuleVersion>`, distributed through GitHub Packages, with the release-note
  process recorded in the changelog.
- [ ] Produce a release candidate and run the complete success-criteria workflow from
  a clean machine or runner.

## Version 1 definition of done

- [x] A module author can define `PSModule/PSModule.psd1` and generate a complete
  module package.
- [x] The generated module is embedded at `/PSModule` in a real image.
- [x] A user can install it with `Install-PSModule`, import it, invoke generated
  commands, and use `Get-Help` without manually constructing `docker run` arguments.
- [x] Built-in stages execute through the ordered internal plugin pipeline and expose
  actionable execution diagnostics.
- [x] Direct Pester, hosted Windows and Linux CI, local `act`, and the real container
  end-to-end workflow pass.
- [x] The generator's distributed package is tested from a clean location.
- [x] Documentation accurately distinguishes implemented Version 1 behavior from
  Phase 2 plans.
- [ ] Release quality gates and the clean-run release-candidate workflow pass.

## Completed milestones

- [x] Directory inspection and typed developer diagnostics.
- [x] Validation errors with specification IDs and source context.
- [x] Ordered validator, object-model processor, code-generator,
  template-renderer, Docker runtime-adapter, and packaging-provider plugins.
- [x] Deterministic manifest, loader, command, metadata, and Markdown generation.
- [x] Declarative mappings, validation attributes, static completion, help, and
  `-WhatIf`.
- [x] `/PSModule` container packaging, installation, import, invocation, and cleanup.
- [x] Hosted unit, end-to-end, and code-coverage reporting.
- [x] Missing-specification initialization and PowerShell command inference limited
  to the directory's `scripts` directory.
- [x] Packaging of the complete `scripts` tree and local-directory command testing.
- [x] Empty-module support and malformed JSON Schema handling.
- [x] Installable PowerShell NuGet package validation and release-driven publishing
  to GitHub Packages.

## Documentation toolchain follow-ups

Follow-up work from adopting the container-based documentation workflows
(`.github/workflows/docs.yml`, `docs-ci.yml`, `docs-deploy.yml`). The reusable
workflows and the `ghcr.io/the-running-dev/docs-template` base image are owned by
[Docusaurus-Template](https://github.com/The-Running-Dev/Docusaurus-Template).
The items below are the seams where this directory currently works around it.

- [x] Fix the template's 404 links, then delete the local theme override.
  Resolved upstream by
  [Docusaurus-Template#33](https://github.com/The-Running-Dev/Docusaurus-Template/pull/33),
  which made `Custom404`'s destinations a `links` prop defaulting to none instead
  of hardcoding `to="/docs"` and `to="/demos"`. Those routes do not exist for a
  consumer that serves docs from the site root via `routeBasePath: '/'` and
  disables the pages plugin, and with `onBrokenLinks: 'throw'` they failed the
  build. `docs/src/theme/NotFound/Content/index.tsx` existed only to work around
  that and has been deleted.
- [ ] Give `docs-build.ps1` a way to prune template files before the overlay.
  It copies the caller's `docs/` over `/template` and never deletes, whereas the
  removed `docs/Dockerfile` did `rm -rf ./docs ./src/pages ./src/theme/NotFound`.
  The base image itself removes only `/template/docs`. A prune manifest honored
  ahead of the overlay would let both `pages: false` in
  `docs/docusaurus.config.ts` and the `NotFound` override go away.
- [ ] Decide whether `docs/Dockerfile` and `docs/.dockerignore` should stay. The
  root `docs.ps1` still needs the Dockerfile for local preview, but
  `docs-build.ps1` also copies both into `/template` during CI, where nothing
  reads them.
- [ ] Reconsider the `.github/workflows/docs.yml` caller. It exists only to carry
  the `pull_request` and `push` triggers that `docs-ci.yml` and `docs-deploy.yml`
  deliberately omit, and it keeps those two files byte-identical to the template
  so `setup-docs.ps1` can be re-run safely. Folding the triggers into the
  installed workflows would remove a file but diverge from the template, and
  `setup-docs-workflow.ps1 -Overwrite` would then silently revert them.

## Deferred to Phase 2

- [ ] Public and stable plugin SDK.
- [ ] Third-party plugin packaging and distribution.
- [ ] Plugin contract versioning and compatibility policy.
- [ ] Extension-model refinement.
- [ ] Object inheritance, templates, composition, and reuse mechanisms.
- [ ] Additional container runtimes such as Podman.
- [ ] Advanced documentation generation, including cross-command tutorials.
