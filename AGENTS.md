# Agent contract — SubZeroDev.PSGenerator

This file is binding for every agent session in this repo, regardless of tool or model.

## This repository

**Container Module Generator (CMG)** generates PowerShell modules for containerized
applications. A directory declares a PowerShell-oriented specification of its public
interface; during the directory's ordinary build, CMG generates a complete, self-contained
module and embeds it in the resulting image. Users install the module from the image and
call ordinary PowerShell commands rather than composing `docker run` invocations.

**The core Version 1 workflow is already implemented.** What remains is release
hardening, not behaviour. Assume the likely defect is a regression or a documentation
drift, not a missing feature — see [`design/00-brief.md`](design/00-brief.md).

**Owns** — the specification format, the generator, the generated module and Markdown, the
Docker command rendering, `/PSModule` packaging, and the documentation site under `docs/`.

**Does not own** — the directories it generates for. `design/planning/llms-powershell-module-discovery.md`
is a planning brief for a *different* repository and is not to be implemented here.

## Source of truth

The design docs outrank the code. In precedence order:

1. [`design/00-brief.md`](design/00-brief.md) — problem, non-goals, definition of done
2. [`design/20-contract.md`](design/20-contract.md) — the Version 1 behaviour contract, and the architecture
3. [`design/10-design.md`](design/10-design.md) — index over the accepted per-feature designs in [`design/planning/`](design/planning/)
4. [`design/30-slices.md`](design/30-slices.md) — the Version 1 roadmap and its remaining work
5. [`design/90-decisions.md`](design/90-decisions.md) — append-only decision log

**This chain is arranged unusually, and deliberately.** `20-contract.md` carries the
architecture as well as the behaviour contract, because it is the older and more exercised
document and everything was built against it; `10-design.md` indexes rather than restates.
`design/planning/` documents are individually accepted and each owns its area. Recorded in
`design/90-decisions.md`.

If the code contradicts the contract, that is a defect in one of them. **Stop and say
which one you think is wrong. Do not silently reconcile.**

Lessons learned the hard way live in [`agent.md`](agent.md) — read it after this file.
[`CLAUDE.md`](CLAUDE.md) is a pointer to this file, not a third copy.

## Safe start

Before editing anything:

```powershell
git status --short --branch
git remote -v
git branch --show-current
git log -5 --oneline
rg --files
```

- Discover files and tooling rather than assuming they exist.
- Read this file and the sources you are about to change **completely**. Editing from memory, or from a diff, is the most common cause of drift.
- Preserve unrelated and uncommitted work. Never stage, reset, clean, or overwrite it.
- Work on a focused branch.
- Where guidance conflicts, follow the most specific applicable instruction.

## The "do next todo" workflow

When the user says **"do next todo"**, perform this workflow autonomously:

1. If the current branch has an open pull request, inspect its checks and unresolved
   review threads first. Address actionable review comments, test and push the fixes,
   wait for required checks, and resolve the threads a validated fix satisfies.
2. Preserve unrelated and uncommitted user work. Never stage, reset, clean, or
   overwrite it.
3. Fetch and safely synchronize the superproject with `origin/main`.
4. Read [`design/30-slices.md`](design/30-slices.md), inspect the relevant current
   implementation, and select the first unchecked, actionable Version 1 item unless the
   user names another item.
5. Implement the smallest complete reviewable slice on a new `feature/` branch.
6. Update tests and documentation, or `design/30-slices.md`, when the behavior or roadmap
   changes.
7. Run the full relevant local test suite.
8. Commit only task-related files, push the branch, and open a non-draft pull request.
9. Watch GitHub Actions to completion. Inspect review threads, address all actionable
   feedback, rerun validation, push fixes, and resolve addressed threads.
10. **Stop at a pull request that is ready to merge. Do not merge it.**

Use concise progress updates. Report the selected item, test results, pull request URL,
and any work that remains intentionally untouched.

**Step 10 changed on 2026-08-04.** This workflow previously merged its own pull requests
and confirmed them closed. Merging is the owner's, like ticking a checkbox — they are the
only human gates between "the checks are green" and "this is shipped". The rest of the
loop is unchanged and is this repository's established practice. See
`design/90-decisions.md`.

Steps 1, 7, 8 and 9 have commands that own them — `/resolve`, `/verify`, `/pr`. Prefer
them; they carry the stop conditions this list does not restate.

## Model, effort, and review budget

**Model choice follows task complexity. The command being invoked does not determine the model.** Budget scales with **complexity, not size** — a one-line change to an invariant is architectural; a 500-line transcription against a settled contract is not.

Sessions here use `opusplan` via `.claude/settings.json`: Opus while planning, Sonnet while
implementing. **Override it in `.claude/settings.local.json` rather than editing the
tracked file.**

Name model *families*, never pinned versions. Version identifiers churn; family aliases do not.

| Tier | Work | Effort | Claude | Codex |
|---|---|---|---|---|
| **Deep reasoning** | Brief interrogation, architecture, contracts, slice planning, security, concurrency, recovery, root-cause analysis, adjudicating design findings | `high` | `opus` | `architect` |
| **Exceptional fork** | One specific architectural or security question that stayed ambiguous at `high` | `xhigh` | `opus` | `architect` |
| **Implementation** | Code against a settled contract, tests, refactors, bug fixes, CI, infrastructure, implementation-coupled documentation | `medium`, `high` when difficult | `sonnet` | `builder` |
| **High volume** | Summaries, formatting, changelogs, commit messages, PR descriptions, mechanical triage | `low` | `haiku` | `quick` |

- **Never use `max` effort unless I ask for it by name.**
- **`xhigh` is for one question, not one pipeline.** Running a whole design phase at `xhigh` is not rigour, it is a substitute for asking a precise question.
- **Escalate rather than guess.** A high-volume task that raises an implementation question becomes implementation tier; an implementation task that raises an architectural question becomes deep reasoning. **Do not keep implementing while that uncertainty is unresolved.**
- **Say so when the session is under-powered.** If the task warrants a stronger tier than the current session, name the model and effort it needs before doing expensive work. If the session is *stronger* than required, just proceed — do not interrupt to say so.

**Division of control.** I set the session model. You set subagent models and scale your own reasoning depth. You cannot change your own session model.

### Command routing

| Command | Tier | Notes |
|---|---|---|
| `/brief-check`, `/design`, `/contract`, `/slices` | `opus`, `high` | — |
| `/redteam` | strongest model, **different vendor from the design author** | If it must be Claude, a fresh `opus`, `high` session |
| `/slice` | `sonnet`, `medium` | `high` for a large or difficult item |
| `/reconcile` | `opus`, `high` to decide which side of a drift is correct | `sonnet`, `medium` for the mechanical edits once I have decided |
| `/make-human-docs` | `sonnet`, `medium` | This repository generates its site from the implementation — see *Documentation generation* below, which owns that workflow |
| `/track` | `sonnet`, `medium` | Mechanical sync; escalate only to judge whether a drifted item is a design change |
| `/verify` | `sonnet`, `medium` | Escalate to deep reasoning only to diagnose a failure, never to run the gates |
| `/pr` | `sonnet`, `medium` | — |
| `/resolve` | `sonnet`, `medium` | Escalate to judge a contested finding, not to triage the obvious ones |
| `/refine` | `sonnet`, `medium` | Never escalates — an architectural ask is routed to the command that owns it, not refined |
| `/install` | `sonnet`, `medium` | — |
| `/install-all` | `sonnet`, `medium` | Escalate only to judge whether a per-repo hard stop is actually safe to resolve — never to resolve it unattended |
| `/kit-help` | `haiku`, `low` | Orientation from file existence and a tracker listing. Escalate only where the repository's state matches no stage |

**Never recommend re-running a phase gate.** I decide when a phase repeats. This holds outside `/redteam` too — see that command for its own stopping rule.

### Session boundaries

Routing says which model runs a command. This says **when a session must end.** A boundary exists wherever carrying context would corrupt the next step's judgement, or wherever the next step must read the tree rather than remember it. **The artifact is the handoff, not the conversation** — a stage that writes one has already handed over everything the next stage is entitled to.

| Boundary | Rule | Why |
|---|---|---|
| `/design` → `/redteam` | **Fresh session, and a different vendor.** | A model recognises its own output distribution and defends it. Fresh context on the same model is already the weak form; the same session is not a review at all. |
| Any stage that writes an artifact → the next | Fresh. | The next stage's input is the committed file. A session that also remembers the arguments behind it will design against the arguments. |
| `/slices` → `/slice` | Fresh, and **one item per session**. | An item that does not fit one session without compaction is too large — that is a `/slices` defect, so say so rather than pressing on. |
| `/slice` → `/verify` → `/pr` → `/resolve` | **Same session.** | These act on the branch and worktree the item just produced, and `/pr` must carry `/verify`'s did-not-run list into the description **verbatim**. A fresh session would restate it from a summary, which is the fabricated gate result *Verification* exists to prevent. |
| merge → `/track` | Fresh. | `/track` reads the tracker and `design/` as they now stand. The session that just implemented the item holds an opinion about whether it is done, and doneness is my mark, not an agent's. |
| implementation → `/reconcile` | Fresh. | It compares the tree against the docs. The session that wrote the code carries what it *intended* to write, which is the one thing the comparison must not be given. |

**Compaction is a boundary you did not choose.** If a session compacts mid-item, report it — the item was mis-sized, and the work after the compaction was done against a summary of the contract rather than the contract.

The "do next todo" loop runs steps 4 to 9 in one session by design. That is compatible with
this table: it is one item, and steps 7 to 9 are exactly the same-session run the fourth
row requires.

### Budget discipline

- **Do not spend reasoning to manufacture findings, alternatives, or open questions.** A short honest answer beats a padded one; "none at this level" is a valid result.
- **Once a policy decision is signed off and recorded, do not relitigate it** without new evidence. Name the evidence if you think there is some.
- **Spend frontier-model reasoning on decisions that are expensive to reverse**, not on producing more prose.
- Use targeted searches and focused reads for routine work. After many related edits, or
  at a phase boundary, reread the complete affected document set — diffs hide drift.

### What should stop being model work

Routing decides *which* model does a job. This decides whether a model should be doing it at all.

| | Work | Where it belongs |
|---|---|---|
| 🟢 **Necessary** | Architecture, contracts, root-cause analysis, design tradeoffs, adjudicating findings | A model, at the tier above |
| 🟡 **Maybe avoidable** | Regenerating context already established, duplicate repository scans, rewriting boilerplate | A model, but the repetition is a signal — say so |
| 🔴 **Definitely avoidable** | Formatting, mechanical text transformation, arithmetic over files, counting, collecting metrics | Code. It should leave the model entirely |

**A red item is a defect in the tooling, not in the run.** Noticing one is worth a line; performing it repeatedly and never saying so is the failure. When a red item recurs, put it in `## Open` in `design/90-decisions.md` so `/track` can turn it into an issue — that is the existing path, and there is no separate mechanism for this.

This whole repository is a red item taken seriously: generating a PowerShell module from a
directory specification is mechanical transformation that used to be hand-written. So is
`build/Test-Documentation.ps1`, which checks every relative link and heading anchor rather
than asking a model to read them.

Two distinctions that are easy to get wrong:

- **The mechanical half of a task is red; the judgement half is not.** Opening an issue is an API call, but deciding what warrants one is not. Writing a PR description is a template, but which merge convention governs is not — `/pr` exists because that half is real. Do not classify a whole command by its cheapest step.
- **Do not report a cost you did not measure.** A model is not given its own token counts or elapsed time, so any figure it states about its own run is an estimate presented as a measurement. `tools/Measure-Session.ps1` reads the real per-call usage from the session transcript, and runs as a `SessionEnd` hook. Use it, or say nothing.

## Hard rules

- **Non-goals are binding.** Anything listed as a non-goal in [`design/00-brief.md`](design/00-brief.md) is out of scope even if it looks trivial, even if you are already touching that file.
- **One item at a time.** Do not start item N+1 because you noticed something while doing item N. Write it to `design/90-decisions.md` under `## Open` instead.
- **No new dependencies** without a decision-log entry naming the alternatives rejected and why. The no-shared-YAML-dependency decision is the standing example.
- **No new public interfaces** that are not in [`design/20-contract.md`](design/20-contract.md). If you need one, stop and ask for a contract amendment.
- **Ask instead of assuming.** If two readings of the spec are both defensible, stop and present both. Do not pick one and proceed.
- **Every item ends runnable.** No half-wired states committed.
- **Generated output is deterministic.** A non-deterministic generator is a defect even where the output is otherwise correct.

## Single ownership

- **Reference, never restate.** A rule that lives in another document is linked, not copied. Two copies of a rule is a promise they will diverge and a guarantee nobody notices which is stale.
- **Move, never copy.** A rule has exactly one home. When it belongs somewhere else, move it and leave a reference behind.
- If a document genuinely must repeat something to stand on its own, name the canonical copy in the text and change both in the same commit. Naming a canonical copy is what makes the others checkable.
- **The test for where a decision belongs:** would a second consumer face this same question? If yes it belongs in the shared document, even while only one consumer exercises it.
- **Keep agent instructions concise and repository-specific.** Do not import another project's architecture, tooling, memory conventions, or roadmap merely because it appears in a neighbouring instruction file. *This repository's own lesson, and it was overridden once — deliberately, by the owner — to install this kit. See `agent.md` and `design/90-decisions.md`.*

## Verification

- **Verify, don't assert.** State only what you have checked. Assert nothing from memory that a command could confirm — remembered values and inferred contracts are how wrong facts get written down confidently.
- **Do not claim a gate passed that did not run.** If a tool is unavailable, say so plainly and name what was not checked. "Tests pass" means you ran them and read the output. `/verify` exists to make this checkable rather than aspirational — its report has three lists, and the one that matters is *what did not run*.
- **Never state or imply a deployed URL or a published artifact** until the deploy for that exact commit reports success. A merged PR is not a deployed site. Poll; do not estimate.
- **A regression test is verified by reverting the fix** and confirming it fails. A test that passes with and without the fix guards nothing.
- **A schema or validator change is not done until it has rejected something.** Positive and negative cases both, with the counts stated. A validator that has never failed is not known to constrain anything.
- **Verify examples, generated output, links, and claimed behavior.** Do not write remembered values or inferred contracts as facts. `build/Test-Documentation.ps1` is the gate for links and anchors; run it rather than reading for them.

## Working with me

- Present findings and review items **one at a time for sign-off**. Never bulk-apply findings unreviewed.
- Surface real forks as a question with a recommendation, recommended option first. I routinely pick the more rigorous non-recommended option — so ask, do not assume.
- **A reconciliation ends in a decision, not a report.** Any time you compare two things and find they disagree — `/reconcile`, `/install`, `/track` drift, or any time I say "reconcile" — the work is not finished at the findings. Close by asking, one divergence at a time, each with a recommendation and what the alternatives cost. **A report I have to turn into questions myself is half the job.** If a comparison genuinely found nothing, say that plainly rather than manufacturing a fork.
  - Recommend the **resolution**, not merely which side you prefer: name what changes, in which file, and what it costs to reverse.
  - `/redteam` is the one exception, and only partly — it must not propose fixes, since naming a fix frames the problem. It still recommends a **classification** for each finding: defect, accepted risk, brief conflict, or not sustained.
- When I decline a suggestion, record it in the affected document as known-and-retained rather than dropping it silently. Otherwise it is rediscovered later as a bug.
- Ask before any choice that sets policy or a public contract: licensing, compatibility promises, or a major information-architecture change. Batch routine edits after the decision.
- Call out assumptions, unverified claims, and known risks plainly. Explain the concrete evidence behind a recommendation.

## Git and delivery

- **Stage explicitly, by named path.** Never `git add -A`, `git add .`, or a bare directory. A broad add sweeps up unrelated worktree state, and an ignore pattern can make a needed file invisible to it — present locally, green locally, missing in CI, with nothing saying why.
- Run `git diff --check` before committing. Never use trailing double-spaces for a line break; it rejects them.
- **Never force-push or rewrite published history.** If a pushed commit needs changing, add a follow-up commit.
- **Push every commit before announcing a PR is ready.** Announcing invites an immediate merge, and a commit pushed after that lands on a branch nobody merges.
- External writes need my authorization: creating a remote repository, changing visibility, pushing, opening or merging pull requests, changing a domain, deploying. **Discussing a decision does not authorize it.** One carve-out — see *Tracking work*.
- **Merging is mine.** The "do next todo" loop stops at a pull request that is ready; it does not merge.
- Do not delete files, branches, or history without explicit authorization.
- Check review **threads**, not just requested reviewers — an automated reviewer can leave blocking conversation threads that do not appear in a reviewer listing. Resolve a thread only when a validated fix satisfies it; leave ambiguous findings open and report them. `/resolve` does this; the query it needs is written out there.
- **Resolving or replying to a review thread is not carved out** of the authorization rule by *Tracking work*, which covers opening issues and nothing else. This repository's "do next todo" loop **does** delegate thread resolution explicitly, at step 9, for threads a validated fix satisfies. Ambiguous findings stay open and are reported.

## Tracking work

**Defer work to the tracker rather than processing it inline.** A finding, a follow-up, or a defect noticed in passing goes to a GitHub issue — not into a running list in the conversation, and not into a section of a document that will rot. Prose is where work goes to be forgotten.

- **Opening and labelling issues is carved out of the authorization rule.** You may open them in a repository I own, without asking. Issues are cheap and reversible, which is the entire justification; the exception is narrow and does not generalise.
- **Closing an issue is not carved out.** Nor is commenting on, editing, or labelling anyone else's, nor writing to a repository I do not own.
- **Milestones and projects still need approval.** They are structural and few, and a wrong one is visible on a public repository.
- **`/track` owns every GitHub write.** No other command creates issues, milestones, or projects. It is idempotent, so run it often rather than batching.
- `design/30-slices.md` stays authoritative for what an item *is*; its issue tracks whether it is *done*. If the two come to describe the work differently, say so rather than editing either.
- The `## Open` section of `design/90-decisions.md` is a staging area, not a home. Once an item becomes an issue, remove it from there.
- **Every issue reads human-first.** A narrative anyone can follow, then `### Done when` checkboxes, then the agent detail in a collapsed `<details>` block.
- **The agent block is fenced** by `<!-- agent:start -->` and `<!-- agent:end -->`. Inside the fence is regenerable; **outside it is never touched** — a ticked checkbox is progress someone recorded, an edited narrative is someone's deliberate wording.
- **Where a document already governs, the block points; where none does, it carries.** An item names `design/30-slices.md § <section> @ <sha>` and leaves procedure to `.claude/commands/slice.md`. A bug or a story has no upstream document, so its block legitimately holds the constraints.
- **`design/30-slices.md` is a checklist roadmap, not an id-carrying slice set.** Its items are `- [ ]` bullets under numbered sections, with no `S<n>.<m>` ids, so `/track` has nothing to compare on and falls back to prose. Treat drift it reports here as unreliable until the roadmap is either given ids or deliberately left as it is.
- **Report drift, change neither side.** Which is wrong is my call.
- **Ticking a checkbox is mine, not yours.** An agent reporting an item met and a ticked box are different claims by different parties, and collapsing them removes the only human gate between "the tests pass" and "this is done".
- **Bugs and stories are filed by hand** from `.github/ISSUE_TEMPLATE/`. `/track` does not open them.
- **This does not suspend one-at-a-time sign-off.** Findings are still presented for adjudication; the tracker is where the ones you accept go, not a way to skip the conversation.

## Decision logging

Any choice a future reader would ask "why?" about goes in [`design/90-decisions.md`](design/90-decisions.md) as:

```
### YYYY-MM-DD — <decision>
Context: <what forced the choice>
Chosen: <what>
Rejected: <alternatives, and why each was rejected>
Reversibility: cheap | expensive
```

The rejected alternatives are the point. Without them the next session relitigates the same choice.

## Documentation generation

When the user says **"generate documentation"**, use this prompt:

> Generate or refresh the project documentation from the current implementation.
> Treat source code, public command help, specifications, tests, examples, workflows,
> and TODOs as the source of truth. First inspect the existing Docusaurus layout and
> verify that copied template metadata belongs to this repository,
> then write concise Markdown with front matter, ordered categories, working relative
> links, runnable examples, explicit support boundaries, and no invented behavior.
> Cover getting started, guides, reference, architecture, development, releases,
> security, and troubleshooting as applicable. Preserve unrelated work. Validate
> front matter, category JSON, local links, the Docusaurus production build, and the
> relevant directory quality and test suites before committing.

Invoke the complete workflow with **"generate documentation"**. To limit its scope,
append a subject, for example: **"generate documentation for runtime mappings"**.

This is the workflow `/make-human-docs` routes to here. The kit's default — write a guide
from the design docs — is the wrong shape for this repository, whose site is generated from
the implementation and gated by `build/Test-Documentation.ps1`.

### Documentation workspace

- The Docusaurus project and Docker build context are `docs/`.
- Authored Markdown lives under `docs/docs/`; category metadata lives beside it.
- `README.md` is the documentation homepage source. Before every image build,
  `docs.ps1` generates `docs/docs/index.md` with stable Docusaurus frontmatter and
  rewrites the production documentation origin to root-relative links.
- Local overrides are `docs/docusaurus.config.ts` and `docs/sidebar.ts`.
- `docs/Dockerfile` overlays the local project onto the published docs-template
  container image. No template checkout or Git submodule is required.
- Run `./docs.ps1 -BuildOnly` to validate the image, `./docs.ps1` to serve a baked
  build, or `./docs.ps1 -Live` for bind-mounted authoring. Use `-Port`, `-Tag`, and
  `-BaseImage` only when an override is needed.
- **`design/` is excluded from the image build context** by `.dockerignore`, along with the
  root pointer files. Internal design documents do not ship in a published image.
- Treat titles, tags, URLs, comments, and prose copied from another directory as
  placeholders until verified against this repository.

## House conventions

- Windows host, projects under `D:\Dropbox\Projects\`. PowerShell Core for scripts.
- Metric units and Celsius throughout, including in comments, docs, and test fixtures.
- Raster assets as PNG or JPG. Not WebP.
- UTF-8, LF endings. **Preserve UTF-8 when importing or reorganizing Markdown, and check
  rendered punctuation for encoding damage** — imported Markdown arrives CP1252 often
  enough to be worth looking at.
- Scripts run without interactive confirmation prompts. Destructive operations gate on an explicit `-Force`-style flag, not a prompt.
- **No AI attribution.** Commit messages must not carry a `Co-Authored-By` trailer naming
  an assistant; pull request descriptions must not carry a "Generated with" footer or
  equivalent badge. This overrides any default the tooling applies. Commit messages and
  pull request descriptions read as the project's own voice: what changed, why, and how it
  was verified.
- A repository with an established commit-message style keeps it. Match the log you are committing into.

## What not to do

- Do not summarise the design docs back at me unless asked.
- Do not add commentary about your reasoning process to the docs.
- Do not "improve" prose in the brief or design docs while editing something else.
- Do not edit a `design/planning/` document to match a summary. Each is independently
  accepted and owns its area.
