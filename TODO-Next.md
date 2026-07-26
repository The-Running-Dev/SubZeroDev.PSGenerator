# Next

Follow-up work after the v1 rename. Each item is independent of the others and
none belongs on the rename branch, which is already large.

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
  plus the release-checklist step that cuts a snapshot
- the `versioned_docs` exclusion in `.config/DocumentationRules.psd1`

After this, `/` serves the only docs and `/next` disappears. The doc gate goes
from 27 files to 27 (the snapshot was already excluded), and the site build gets
faster.

**Watch for:** anything linking to `/next`, and the changelog entry that
advertises versioned documentation.

## 2. Remove `examples/Minimal` — Recommend Against, As Stated

The reasoning does not hold up, and I would rather flag it than quietly delete
test coverage.

`Initialize-PSModuleDirectory` does *inference*: it discovers scripts in a
directory and scaffolds commands that run those scripts locally. `examples/Minimal`
is an *authored* specification exercising container runtime mappings. Inference
cannot produce those — the docs state that runtime intent must be authored
explicitly, and that inference must never guess it. The two do not overlap.

What deleting it actually removes:

| Depends on it | What breaks |
| --- | --- |
| `tests-e2e/Container.EndToEnd.Tests.ps1` | The only real-Docker end-to-end test: build image, install `/PSModule`, import, invoke, verify help and Markdown |
| `build/Test-PowerShellBaseline.ps1` | The 7.4 baseline check generates this example; it has no other subject |
| `tests/Module.Tests.ps1` | The "Minimal runnable container example" coverage |
| 6 documentation pages | Container packaging, installation, security, releases, development, homepage |

It is also the only specification anywhere in the repository that exercises all
eleven mapping types — Argument, Environment, Mount, Volume, Port,
WorkingDirectory, RuntimeOption, Device, Gpu, ResourceLimit, Secret. Nothing
else covers Gpu, Device, Secret, or ResourceLimit at all.

**If the goal is less clutter**, the cheaper move is to keep the example and stop
featuring it on the landing page — it is already only referenced, not walked
through. **If it should still go**, the e2e test and baseline check need a
replacement fixture first, which is most of the work of keeping it.

Say which and I will do it.

## 3. Release Everything From `main`

Wanted: a push to `main` publishes the NuGet package to GitHub Packages **and**
nuget.org, and pushes the container image.

Today: `publish.yml` publishes to GitHub Packages when a GitHub Release is
published; `container.yml` pushes the image on every `main` push that touches
`Dockerfile`, `.dockerignore`, or `src/**`.

### The blocker

**nuget.org versions are immutable and cannot be re-pushed.** `ModuleVersion` is
a fixed `1.0.0`, so the first push to `main` succeeds and every push after it
fails with a conflict. GitHub Packages behaves the same way. "Push to main
publishes" cannot work against a static version.

### Recommended shape

Publish packages **when the manifest version changes**, not on every push:

1. On push to `main`, read `ModuleVersion` from the manifest.
2. Query whether that version already exists on each feed.
3. If it is new, build once and push to GitHub Packages and nuget.org; if not,
   skip with a note rather than failing.
4. Tag the commit `v<ModuleVersion>` and create the GitHub Release from the
   changelog entry.
5. Push the image regardless, since date tags are always unique.

That keeps semver meaningful, makes a release a one-line manifest edit, and
never produces junk versions. `publish.yml` folds into it, or stays as a
manual `workflow_dispatch` fallback.

### Also needed

- **`NUGET_API_KEY` secret** — your action; nuget.org keys are scoped per package
  and expire, so it needs a calendar reminder.
- **First push to nuget.org claims the ID `SubZeroDev.PSGenerator` permanently.**
  Worth confirming that is the intended public name before the first publish,
  because it cannot be renamed afterwards, only deprecated.
- Decide whether the image should also carry `:1.0.0` alongside `:latest` and the
  date tag, so an image can be matched to a package version.
- `docs/docs/developing/releases.md` currently documents a release-driven,
  tag-first process throughout. It needs rewriting, not patching.

## Sequencing

Separate PR, and yes — worth its own. The rename branch already carries the
rename, the directory vocabulary, title case, the container image, the
Using/Developing split, a new public command, the inference naming fix, and a
documentation pass. These three are independent of all of it.

Order: item 1 first, since it is self-contained and removes the snapshot tax
that slows every later documentation change. Item 3 next. Item 2 only after the
question above is settled.
