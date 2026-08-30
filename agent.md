# Agent — lessons learned

Retrospective notes for whoever (human or agent) works this repo next. Standing
*instructions* live in [`AGENTS.md`](AGENTS.md); *decisions* live in
[`design/90-decisions.md`](design/90-decisions.md). This file is what was learned the hard
way.

Keep it short — it loads into context, so length is a recurring cost. **Add a lesson only
when it would have changed a decision.** A lesson with no cost attached is a preference,
and preferences belong in `AGENTS.md`.

---

## Earned here

These were this repository's own `Durable lessons`, moved out of `AGENTS.md` on 2026-08-04
when the agent kit was installed. Two of the six moved; four were dropped because the kit's
contract already states them and two copies of a rule is a promise they will diverge —
`AGENTS.md` § *Verification* now carries the verify-don't-assert lesson, § *Budget
discipline* the targeted-reads one, § *Working with me* the ask-before-policy one, and
§ *House conventions* the UTF-8 one.

- **When a type or public behaviour changes, audit everything downstream of it** — its
  specification, the prose, every example, the generated representation, command help, the
  tests, and the troubleshooting guidance. In a generator, one type change fans out further
  than anywhere else: the model, the emitted module, the emitted Markdown, and the help
  text are four separate renderings of the same fact.

- **Keep agent instructions concise and repository-specific.** Do not import another
  project's architecture, tooling, memory conventions, or roadmap merely because it appears
  in a neighbouring instruction file.

  > **Retained, and overridden once.** This lesson is the reason the agent kit was *not*
  > installed here for as long as it wasn't, and applying it to that decision was correct.
  > The owner overruled it on 2026-08-04, deliberately and with the conflict stated in
  > these terms, in favour of estate-wide consistency. The lesson stands for every other
  > case — it was overruled, not found wrong. See `design/90-decisions.md`.

## Inherited, not earned here

Harvested from other projects in the estate because these are the failures most likely to
repeat. **Delete any that turn out not to apply.** The kit's seed was pruned on install:
its container, knowledge-graph, spec-drift and naming lessons were dropped as not
applicable to a PowerShell generator with a settled contract.

- **Search the concept, not the phrasing you just edited.** Striking a requirement from
  seven places, a grep for the exact removed phrase returned clean — it could not match the
  same requirement worded differently, and six stale statements survived a check reported as
  thorough. **Removals are where this bites**: a bad edit contradicts something visibly, a
  missed removal is silent. *This one earned its place during the very install that added
  it: the reference rewrite was done by search and still missed three links, which only
  `build/Test-Documentation.ps1` caught.*
- **When a document states a number, count the list.** "All eight operations" against a
  nine-row table survived two full review passes. Re-count; never increment.
- **A stale cross-reference is invisible.** Section numbers cited across documents rot
  silently when a document is restructured. **Prefer appending.**
- **Check documentation against the tree, not against other documentation.** A page once
  described a file that had never existed in git history — it had been checked against
  neighbouring docs, which agreed with it.
- **Running the code beats recalling it.** A golden-test vector written from memory was
  wrong; executing the reference implementation caught it before it became the expected
  value everything else was checked against. Directly relevant here, where the expected
  output *is* generated code.
- **A broad `git add` has already nearly cost real work.** An ignore pattern would have made
  installer-generated scripts invisible to `git add -A` — present locally, green locally,
  missing in CI, with nothing saying why.
- **`prettier --check` reports false failures on a Windows working tree.** `core.autocrlf=true`
  gives CRLF locally while the committed blob is LF, which is what CI checks out. Check the
  blob before "fixing" formatting CI never complained about.
- **After a squash merge, `git branch -d` reports the branch unmerged** because the squash
  commit shares no history with it. Confirm with `git diff <branch> main` returning empty,
  then delete.
- **A required status check that never runs blocks the pull request permanently.** Think
  twice before adding a `paths:` filter to a required workflow.
- **A CI job can never be granted more permission than its workflow declares.**
- **Verify a regression test by reverting the fix.** A test that passes either way guards
  nothing.
- **A fix that only changed the odds is not a fix.** An intermittent failure went away when
  test parallelism was disabled — three consecutive clean runs — and came back on the
  fourth. The real cause was connection pooling handing out a stale schema snapshot. When a
  fix is "it stopped failing", suspect the odds moved rather than the cause, and say over
  how many runs.
- **A diff cannot show a rendering bug.** A metadata field or blockquote label needs a
  **blank line** after it, never trailing double-spaces (`git diff --check` rejects those).
  Render before merging a document change.
- **A shortcut taken in the reference implementation gets copied.** The next author reads
  the working example before reading the contract. In a generator this compounds: a
  shortcut in emitted code is copied into every module generated after it.
