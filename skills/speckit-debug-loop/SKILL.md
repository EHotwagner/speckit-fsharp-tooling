---
name: speckit-debug-loop
description: Iteratively diagnose, fix, and re-test until the build and tests are green, with hard safety rails. Use when the user says "make it pass", "fix the build", "get tests green", "debug until it works", "iterate on the failures", or any request for an autonomous fix-until-green loop. Writes an iteration log to readiness/debug-loop.log.md.
metadata:
  short-description: Iterative diagnose/test/fix loop
---

# speckit-debug-loop

Drive a bounded loop: run the project's verification, parse failures, fix
the smallest thing that could be wrong, re-run. Stop on green, on cap, or
on no-progress.

## When to use

- User says "make it pass", "fix the build", "debug this", "iterate on
  failures", "get everything green".
- Called explicitly after a feature's implementation phase when tests are
  failing and the user wants autonomous resolution.
- NOT used for design decisions, architectural changes, or when the
  failure points at a spec defect (in those cases surface to the user).

## Configuration

| Parameter | Default | Override by |
|---|---|---|
| Max iterations | 10 | User says "up to N iterations" |
| No-progress stop | 2 consecutive iterations with the same primary failure | — |
| Verify command | Auto-detect (see below) | User supplies explicit command |

### Verify command auto-detection

In order, use the first that applies:

1. `.specify/workflow-registry.json` declares a `verify` target → use it.
2. `build.fsx` exists → `fake run build.fsx --target Verify` (F# FAKE).
3. `*.sln` exists → `dotnet build && dotnet test`.
4. `package.json` with `test` script → `npm test`.
5. `Makefile` with `test` target → `make test`.
6. Otherwise stop and ask the user for the verify command.

## Loop

For iteration `n = 1..cap`:

1. **Run the verify command.** Capture stdout and stderr.
2. **If exit code is 0:** stop, green. Report iterations used.
3. **Parse failures.** For each failure, extract:
   - Classification: `build-error` / `test-failure` / `runtime-exception` / `flake-suspect`.
   - Primary signal: compiler diagnostic (file:line:code), test name, stack
     trace top frame, or exception type.
   - Affected files from the signal.
4. **No-progress check.** If this iteration's primary signal matches the
   previous iteration's, increment `same_failure_count`. If it reaches 2,
   stop with verdict `NO-PROGRESS` and surface the failure to the user.
5. **Diagnose.** Read the failing file(s) at the reported lines. Form the
   minimal hypothesis that could produce the failure.
6. **Fix.** Apply the smallest change that addresses the hypothesis.
7. **Re-run the narrow scope first** (single test, single project) for
   speed. On green, run the full verify before declaring success.
8. **Log the iteration** to `readiness/debug-loop.log.md` (see format
   below).

## Hard safety rails — violations require user confirmation

These are not suggestions:

- **Never** weaken an assertion to make a test pass. If a test asserts
  `x == 42` and the code produces `41`, fix the code, not the assertion.
- **Never** add `[<Skip>]`, `[<Ignore>]`, `[<Explicit>]`, `it.skip`,
  `xit(`, `@pytest.mark.skip`, or any framework's equivalent to silence a
  failing test. If a test must be skipped, stop and ask the user to
  confirm with a rationale that will be recorded.
- **Never** use `--no-verify` to bypass pre-commit hooks.
- **Never** delete a test. Deletion requires explicit user instruction.
- **Never** catch and swallow an exception to make the error disappear.
  If the error is real, fix the cause; if the error is wrong, fix the
  throw site.
- **Never** change compiler warning levels to silence warnings the test
  suite treats as errors.
- **Never** touch code outside the failure's blast radius without naming
  why the change is necessary in the log.

If the only way to make a test pass would violate one of these, stop. Log
the violation, surface to the user, and ask for direction.

## Stop conditions (in priority order)

1. **Green** — verify exits 0. Report success.
2. **No-progress** — 2 iterations with the same primary signal. Surface
   the failure with your best diagnosis.
3. **Cap reached** — `n == max_iterations`. Surface the remaining
   failures and your attempted fixes.
4. **Rail hit** — any safety rail was about to be violated. Surface to
   the user.
5. **Spec gap** — the failure points at a contradiction in the spec or
   plan, not the code. Surface to the user; do NOT "make it pass" by
   reinterpreting the spec.

## Iteration log format

Append to `specs/<FEATURE_ID>/readiness/debug-loop.log.md`:

```markdown
## Iteration <n> — <UTC timestamp>

**Verify command:** `<command>`
**Exit code:** <code>

**Primary failure:** <classification>
- Signal: `<file>:<line>: <code/message>`
- Hypothesis: <one sentence>

**Fix applied:**
- `<file>:<line>` — <what changed, why>

**Narrow re-run result:** <pass/fail>
**Full verify result:** <pass/fail/deferred>
```

On stop, append a final `## Result` block with the stop condition and
(if not green) a summary of the last remaining failures and the user's
recommended next action.

## After running

Report to the user:
- Stop condition (Green / No-progress / Cap reached / Rail hit / Spec gap).
- Iteration count.
- What changed (list of files with one-line rationale).
- If not green: the remaining failure, your best diagnosis, and what you'd
  try next if the user wanted you to continue.

Never describe the loop as "successful" unless the stop condition was
Green.
