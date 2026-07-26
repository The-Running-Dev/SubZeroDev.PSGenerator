# Next

Follow-up work after the v1 rename. Independent of that branch, which is already
large.

## 1. Drop Docusaurus Versioning

There is one version of these docs and there always will be, so the snapshot
machinery is pure overhead. It has also been a recurring tax: every content
change needs the snapshot re-cut, and re-cutting needs `lastVersion` temporarily
removed first, because Docusaurus refuses to load a config naming a version that
`versions.json` does not list.

Remove:

- `docs/versioned_docs/`, `docs/versioned_sidebars/`, `docs/versions.json`
- `lastVersion` and the `versions` block in `docs/docusaurus.config.ts`
- the `docsVersionDropdown` navbar item
- `-CreateVersion` from `docs.ps1`, and its ordering caution
- the "Documentation Versions" section in `docs/docs/developing/releases.md`,
  and the release-checklist step that cuts a snapshot
- the `versioned_docs` exclusion in `.config/DocumentationRules.psd1`
- the changelog entry advertising versioned documentation

After this, `/` serves the only docs and `/next` disappears. Check nothing links
to `/next` before removing it.

## 2. Publishing Stays Release-Driven

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

## 3. Gaps Found During the Rename

Small, concrete, and each one is a thing that can silently rot.

- **`docs/docs/index.md` drift is unverified.** It is generated from `README.md`
  by `docs.ps1`, but nothing checks that the committed copy still matches. Every
  README edit needs it regenerated, and today the only thing catching that is
  someone remembering. Add the comparison to `build/Test-Documentation.ps1`:
  rebuild the expected content from `README.md` and fail when it differs from
  the committed file.
- **`main` has no branch protection.** No required status checks at all, so a red
  PowerShell quality, documentation, Pester, or docs run does not block a merge.
  The whole point of the deploy-path coverage added in #61 was to block before
  merge; without required checks it only reports. Your action, in repository
  settings.
- **A generated command can shadow an existing one.** Since the inference naming
  fix, `convertto-json.ps1` produces `ConvertTo-Json`, which shadows the built-in
  once the module is imported. Documented as a note in the script inference
  guide, but inference could detect the collision and warn, the same way it warns
  about source commands without runtime mappings.
- **`.gitignore` does not cover `bin/` and `obj/`.** The BuildAgent fixture's
  `.csproj` files produce build output that shows up as untracked noise whenever
  anything builds them. Those directories are currently empty, so it is quiet
  right now, and it will come back.

## 4. Still Open on the v1 Roadmap

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

Separate PR from the rename. Item 1 first: self-contained, and it removes the
snapshot tax that slows every later documentation change. Item 3 alongside or
after — the `index.md` check is the one with real leverage, since it closes a
gap that currently depends on someone noticing.
