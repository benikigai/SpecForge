---
name: karpathy
description: >
  Karpathy autoresearch loop — autonomous iterative optimization with a mechanical
  ratchet. Edit code, evaluate against a scalar metric, keep only improvements,
  discard everything else. The branch can only move forward. Adapted faithfully
  from github.com/karpathy/autoresearch. Use for optimizing working code against
  a measurable target: performance, test coverage, bundle size, latency, accuracy.
invocation: user
---

# /karpathy — Autoresearch Loop

Adapted from [karpathy/autoresearch](https://github.com/karpathy/autoresearch).
You are an autonomous researcher. You modify code, evaluate the result against a
fixed metric, and keep only improvements. The ratchet is mechanical — enforced by
`.claude/scripts/karpathy-loop.sh`, not by your judgment.

## The Three Primitives

1. **Editable Asset** — The specific file(s) you are permitted to modify. Everything else is locked.
2. **Scalar Metric** — A single number (0-100) computed by `evaluate-task.sh`. Higher is better. No subjectivity. No committee. Machine-checkable.
3. **Time-Boxed Cycle** — Each experiment should complete within a bounded time. If it doesn't, it's a failure.

## Setup

When the user invokes `/karpathy`, work with them to define:

1. **The goal:** What are we optimizing? (e.g., "make tests pass", "reduce bundle size", "improve response latency")
2. **The editable files:** Which files can you modify? (e.g., `src/auth/oauth.ts, src/auth/config.ts`)
3. **The evaluation commands:** What determines the score?
   - `--test` command (40% of score): e.g., `npm run test`, `pytest`, `cargo test`
   - `--build` command (30% of score): e.g., `npm run build`, `cargo build`
   - `--lint` command (15% of score): e.g., `npm run lint`, `ruff check`
   - `--typecheck` command (15% of score): e.g., `npx tsc --noEmit`, `mypy src/`
4. **The tag:** A short name for this experiment run (e.g., `auth-pool`, `perf-jun4`)
5. **Max iterations:** How many experiments before stopping (default: 20)

Then initialize:

```bash
bash .claude/scripts/karpathy-loop.sh \
    --action setup \
    --tag "<tag>" \
    --test "<test command>" \
    --build "<build command>" \
    --lint "<lint command>" \
    --typecheck "<typecheck command>"
```

This creates the experiment branch, records the baseline score, and initializes `results.tsv`.

## The Experiment Loop

Read the editable files for full context. Then:

```
LOOP (up to max iterations):

  1. LOOK at the current code state. Read results.tsv for what has been tried.
     Think about what to try next based on:
     - What has worked (kept experiments)
     - What has failed (discarded experiments)
     - What hasn't been tried yet

  2. EDIT the editable file(s) with your experimental idea.
     - One idea per experiment. Don't bundle multiple changes.
     - Prefer small, targeted changes over sweeping rewrites.
     - Karpathy's simplicity criterion: A small improvement that adds ugly
       complexity is not worth it. Removing code for equal results IS worth it.

  3. COMMIT with a descriptive message:
     git commit -am "experiment: <what you changed and why>"

  4. EVALUATE using the ratchet script:
     bash .claude/scripts/karpathy-loop.sh \
         --action evaluate \
         --description "<what you changed>" \
         --test "<test command>" \
         --build "<build command>" \
         --lint "<lint command>" \
         --typecheck "<typecheck command>"

  5. READ the result:
     - "KEEP:<score>"    → Your change improved the metric. It stays. Move on.
     - "DISCARD:<score>" → Your change didn't improve. The commit was erased.
                           The code is back to where it was. Try something else.

  6. DECIDE next step:
     - If KEEP: Build on this success. What else can improve?
     - If DISCARD: Why did it fail? Try a different approach.
     - If stuck after 3+ consecutive discards: try a radically different direction.
     - If score reaches 100: STOP. You've hit the ceiling.

END LOOP
```

## After the Loop

When iterations are exhausted or you've reached a satisfactory score:

1. Run `bash .claude/scripts/karpathy-loop.sh --action status` to see final results
2. Present the results to the user:
   - Total experiments run
   - How many kept vs discarded vs crashed
   - Best score achieved (vs baseline)
   - Key discoveries (what changes actually helped)
3. The experiment branch contains a clean chain of validated improvements
4. Ask the user: merge into feature branch? continue experimenting? abort?

## Crash Handling

If an experiment crashes (code doesn't compile, test runner fails to start, OOM):

- If it's a simple fix (typo, missing import): fix it and re-run. Don't waste an iteration.
- If the idea itself is broken: discard, log as crash, move on.
- Run the evaluate with the broken code — it will score 0, get discarded, and the ratchet resets.

## results.tsv Format

Tab-separated, NOT comma-separated. Untracked by git (the ratchet manages it).

```
commit	score	status	timestamp	description
a1b2c3d	45	baseline	2026-04-04T10:00:00	initial baseline
b2c3d4e	70	keep	2026-04-04T10:05:00	added input validation
c3d4e5f	65	discard	2026-04-04T10:10:00	switched to regex validation
d4e5f6g	0	discard	2026-04-04T10:15:00	crash: OOM on large input
e5f6g7h	85	keep	2026-04-04T10:20:00	added edge case handling
```

## What This Is Good For

- **Making failing tests pass** — editable: the implementation files, metric: test pass rate
- **Performance optimization** — editable: the hot path, metric: benchmark score
- **Reducing bundle size** — editable: imports and components, metric: build size
- **Improving code quality** — editable: a module, metric: lint + typecheck score
- **Fixing a stubborn bug** — editable: the buggy file, metric: does the repro test pass

## What This Is NOT Good For

- **Greenfield development** — you need a working baseline first. Can't optimize from nothing.
- **Subjective quality** — if there's no scalar metric, the ratchet can't decide.
- **Architecture decisions** — this optimizes within a design, not between designs. Use `/spec` for architecture.
- **Research/exploration** — this is optimization, not discovery. Use `/research` for discovery.

## Key Differences from Karpathy's Original

| Karpathy's autoresearch | Our /karpathy |
|------------------------|---------------|
| Optimizes ML training (val_bpb) | Optimizes any code with a testable metric |
| Single file (train.py) | Any files the user designates as editable |
| 5-minute time budget (GPU training) | Time depends on test suite speed |
| prepare.py is the locked harness | evaluate-task.sh is the locked harness |
| results.tsv tracks experiments | Same — results.tsv tracks experiments |
| git branch per experiment run | Same — experiment/<tag> branches |
| Ratchet: keep only improvements | Same — mechanical ratchet via bash script |
| "NEVER STOP" | Bounded by max iterations (default 20) |

## IMPORTANT RULES

- **NEVER modify evaluate-task.sh or karpathy-loop.sh.** They are the fixed harness. Like Karpathy's prepare.py — sacrosanct.
- **NEVER modify files outside the designated editable set.** Ask the user to expand the set if needed.
- **NEVER manually override the ratchet.** If the script says DISCARD, the change is gone. Try something else.
- **ONE idea per experiment.** Don't bundle changes. If you change two things and the score improves, you won't know which one helped.
- **Log everything.** Every experiment gets a commit message and a results.tsv entry, even crashes.
- **Simplicity criterion.** All else equal, simpler is better. Removing code for equal results is a win.
