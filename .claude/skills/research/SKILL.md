---
name: research
description: >
  Karpathy-style autonomous research loop for complex tasks. Iteratively explores
  approaches, tests hypotheses against measurable criteria, and keeps only improvements.
  Use for complex-tier tasks with architecture ambiguity, new dependencies, or
  performance-critical behavior. Gated — do not use for simple or obvious tasks.
invocation: user
---

# /research — Autonomous Research Loop

Adapted from Karpathy's AutoResearch pattern. This skill runs an iterative research cycle:
hypothesize -> implement minimal proof -> evaluate against metrics -> keep or discard -> repeat.

## When to Use (Gate Check)

Run this ONLY when at least one is true:

- New dependency or external API with unclear integration patterns
- Security-sensitive implementation with multiple valid approaches
- Architecture decision with significant long-term implications
- Performance-critical code path where wrong approach costs >2x
- Cross-cutting refactor touching >5 modules

**Do NOT use when:**

- The task is local, obvious, and touches <3 files
- Existing tests already define correct behavior
- There is only one reasonable implementation approach
- The spec already specifies the exact approach

## The Three Primitives

1. **Editable Asset:** The specific implementation approach or code pattern being evaluated
2. **Scalar Metric:** Composite score of: tests passing (0/1), lint clean (0/1), type check (0/1), and any task-specific metric from the spec
3. **Iteration Budget:** Maximum 5 iterations. Each iteration should take <5 minutes.

## Research Loop

```
FOR iteration = 1 to 5:

  1. RESEARCH
     - Read relevant codebase patterns (use Explore subagent)
     - If external API/dependency: search web for best practices and gotchas
     - If prior attempts exist: read git history and prior research notes
     - Document findings in working notes

  2. HYPOTHESIZE
     - Based on findings, propose a specific implementation approach
     - State clearly: "I believe [approach] because [evidence]"
     - Predict: what metric score do you expect?

  3. IMPLEMENT (minimal proof)
     - Write the smallest possible implementation that tests the hypothesis
     - This is NOT production code — it is a proof of concept
     - Focus on the core mechanism, skip polish

  4. EVALUATE
     - Run the scalar metric:
       * Do targeted tests pass? (Y/N)
       * Is lint clean? (Y/N)
       * Does type check pass? (Y/N)
       * Task-specific metric if defined (value)
     - Compare to previous best score

  5. KEEP or DISCARD
     - If metric improved: KEEP. Record approach and score. git stash push -m "research-iter-N-keep"
     - If metric same or worse: DISCARD. Rollback: git checkout -- . to undo changes
     - If hypothesis fails fundamentally (wrong approach entirely): git stash drop any work
       and try a completely different direction
     - If all metrics green AND confidence is high: EXIT EARLY

  6. SYNTHESIZE
     - What did this iteration teach?
     - What should the next iteration try differently?
     - Update working notes

END FOR
```

## Exit Conditions

Stop the loop when ANY of these are true:

- All metrics green and approach is validated (success)
- Maximum 5 iterations reached (report best findings)
- Two consecutive iterations show no improvement (likely local optimum)
- Research reveals the spec needs to change (escalate to user)

## Output

Write research results to `docs/specs/<feature>-research.md`:

```markdown
# Research: [Topic]
**Date:** [YYYY-MM-DD]
**Iterations:** [N]
**Best approach:** [name/description]
**Confidence:** High | Medium | Low

## Summary
[2-3 sentences: what was explored, what was found, what is recommended]

## Iteration Log
### Iteration 1
- **Hypothesis:** [what was tried]
- **Result:** [metric scores]
- **Kept/Discarded:** [which and why]
- **Learning:** [what this taught]

[repeat for each iteration]

## Recommended Approach
[Detailed description of the winning approach, with code patterns if applicable]

## Rejected Approaches
[Brief list of what was tried and didn't work, with reasons]

## Risks & Unknowns
[What this research did NOT resolve — things the implementation should watch for]
```

## IMPORTANT REMINDERS

- This is a RESEARCH tool, not an implementation tool. The output is knowledge, not production code.
- Minimal proofs should be discarded after evaluation. Clean up before exiting.
- If the research reveals the spec's assumptions are wrong, STOP and escalate immediately.
- Document everything. The research log is as valuable as the conclusion.
- Prefer approaches that are boring and proven over clever and novel.
