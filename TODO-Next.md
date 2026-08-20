# Next

Follow-up work after the v1 rename. Independent of that branch, which is already
large.

## 1. Publishing Stays Release-Driven

Decided: keep publishing on tag push and manual dispatch until 1.0 is
formalized. No change to `publish.yml`. The container image keeps publishing
from `main` on its own cadence, which is fine because date tags are always
unique.

Revisit at 1.0, and note two things that will matter then:

- **nuget.org and GitHub Packages both reject a version that already exists,
  permanently.** Any "publish on push" scheme has to publish only when
  `ModuleVersion` changes, or it fails on the second push.
- **The first nuget.org push claims `SubZeroDev.PSGenerator` forever.** It can be
  deprecated but never renamed, so confirm the public name before publishing.

Also worth deciding then: whether the image should carry `:1.0.0` alongside
`:latest` and the date tag, so an image can be matched to a package version.

## 2. Quality Safeguards in PR #66

The first three rename gaps are implemented together in PR
[#66](https://github.com/The-Running-Dev/SubZeroDev.PSGenerator/pull/66).
Detailed implementation and evidence live in
[`planning/quality-safeguards-implementation-plan.md`](planning/quality-safeguards-implementation-plan.md).

- **Required checks are active on `main`.** Ruleset `Main` (ID `19771450`) now
  requires the ten GitHub Actions contexts below with strict freshness. The
  existing PR, review-thread, deletion, non-fast-forward, merge-method, condition,
  and bypass behavior was preserved.

  Add these ten contexts, exactly as CI reports them. A misspelled or unavailable
  required context remains expected or pending and blocks merging indefinitely,
  so exact names matter:

  ```text
  Build and publish image
  Container end-to-end
  Documentation links and terminology
  Pester (ubuntu-latest)
  Pester (windows-latest)
  PowerShell 7.4 baseline (ubuntu-latest)
  PowerShell 7.4 baseline (windows-latest)
  PowerShell NuGet package
  PowerShell quality
  Verify documentation / Verify Documentation Build
  ```

  Only the reusable documentation workflow carries a `caller / job` prefix; the
  rest report their job name alone.

  Do not require `Deploy documentation`: it is skipped on pull requests by
  design, because its job is gated on `github.event_name == 'push'`.
- **Automatic branch deletion remains enabled.** The repository API confirms
  `delete_branch_on_merge = true`; observe the actual remote-head deletion after
  PR #66 is eventually reviewed and merged.
- **Inferred command collisions are diagnosed.** Inference warns without changing
  generated command names and statically inspects available manifests without
  importing or executing their modules.
- **Nested .NET output is ignored and validated.** Repository quality checks cover
  `bin/` and `obj/`, ensure tracked paths remain visible, and prevent a successful
  no-match probe from leaking a failing process code.

## 3. Still Open on the v1 Roadmap

Not re-planned here, just so it is not forgotten. `TODO.md` still has:

- **§3 Docker-BuildAgent compatibility** — 11 of 13 items unchecked, and this is
  the largest remaining piece of engineering. Includes the maintenance-script
  classification that would keep repo tooling out of a public command surface.
- **§4 Inspector hardening** — all 6 unchecked, starting with the warn-versus-fail
  malformed-input policy.
- **§5** — device and GPU mappings on runners that expose the hardware.
- **Three documentation-toolchain follow-ups** — the `docs-build.ps1` prune
  manifest, whether `docs/Dockerfile` and `.dockerignore` should stay, and
  whether the `docs.yml` caller is still worth having. All upstream-shaped and
  lower priority since the 404 fix removed the reason the prune manifest existed.

## Sequencing

Dropping Docusaurus versioning is done, so the snapshot no longer has to be
re-cut on every documentation change.

Of what remains, required status checks are the highest leverage: without them,
none of the gates block a merge. Automatic branch deletion is already enabled.
After that, the `index.md` drift check, since it closes a gap that currently
depends on someone remembering. Publishing waits for 1.0.
