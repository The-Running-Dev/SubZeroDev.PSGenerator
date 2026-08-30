# Build Agent Inference Fixture

This fixture is deliberately different from the [BuildAgent](../BuildAgent) fixture.
That one proves an authored `PSModule.psd1` can be built, imported, and invoked. This
one proves the opposite: given the same shape of build evidence
(`.nuke/`, `src/`, `scripts/powershell-module/`) but an **empty** specification, does
inspection and generation infer anything?

Today it does not. This fixture and its tests record that gap explicitly so the
[build-agent evidence and inference design](../../../../design/planning/build-agent-evidence-design.md)
has a baseline to build against, slice by slice. Do not repurpose or weaken the
authored `BuildAgent` fixture to answer this question instead — it proves a
different, already-working path.

The fixture also carries two deliberate data points for later slices, not exercised
by the baseline tests:

- a **compatible overlap** — `Configuration` is declared by both the NUKE schema and
  `BuildParamsBase.Configuration`, with the same meaning and type;
- an **intentional conflict** — the NUKE schema and the generated
  `scripts/powershell-module/parameters.json` both default `OutputDirectory` to
  `artifacts/forge`, while `ForgeBuildParams.OutputDirectory` defaults to `out`.

`Update-ModuleParameters.ps1` is reference behavior only, tagged
`.FUNCTIONALITY Maintenance`. Discovery must never execute it.
