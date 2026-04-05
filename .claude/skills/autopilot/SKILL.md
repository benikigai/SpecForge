---
name: autopilot
description: >
  Full autonomous lifecycle — chains research, spec, execution, deslop, review,
  and PR into one command. Say what you want built, walk away, come back to a PR.
  Adapted from OMX's autopilot 6-phase pattern. Use for well-understood features
  where you trust the pipeline. Not for exploratory or security-sensitive work.
invocation: user
---

# /autopilot — Full Lifecycle Automation

You are in AUTOPILOT MODE. You chain the entire Forge pipeline into one autonomous run.
The user describes what they want. You plan it, build it, clean it, review it, and open a PR.

## When to Use

- Well-understood feature with clear acceptance criteria
- User wants to walk away and come back to a PR
- Not security-sensitive (use `/yolo` for auth/payments/data)
- Not exploratory (use `/research` + `/spec` for new territory)

## When NOT to Use

- First time building in a new area of the codebase
- Security-sensitive changes (auth, payments, secrets)
- Architecture decisions that need human judgment
- Ambiguous requirements that need discussion

## The 6 Phases

```
Phase 1: Research (if needed)
    ↓
Phase 2: Spec (plan + critic review)
    ↓
Phase 3: Execute (/yolo with UltraQA cycling)
    ↓
Phase 4: Deslop (mandatory cleanup)
    ↓
Phase 5: Review (multi-model blind review)
    ↓
Phase 6: PR (create + notify)
```

### Phase 1: Research (Gated)

**Gate check — run research ONLY if:**
- New dependency or external API
- Topic the codebase hasn't touched before
- User explicitly said "research first"

**If gated IN:** Run `/research` on the topic. Save to `docs/specs/<feature>-research.md`
and refresh `docs/specs/<feature>-context.md`.
**If gated OUT:** Skip. State: "Research skipped — [reason]."

### Phase 2: Spec

Run the `/spec` pipeline:
1. Context loading (scan codebase, load research if it exists)
2. Intent interview — ask 3-5 questions. **HALT and wait for answers.**
3. Options analysis — present 2-3 options scored on Three Es
4. **Critic review** — spawn the `critic` subagent to attack the recommended option
5. Incorporate valid critiques, dismiss unfounded ones
6. Task decomposition
7. Write spec + yolo file + forge JSON
8. **HALT and wait for user approval.**

Autopilot does NOT skip the interview or approval. These are the two human checkpoints.

### Phase 3: Execute

Choose execution mode based on complexity:
- **All tasks Simple/Moderate:** Use `/yolo` (supervised but fast)
- **Mix of complexities OR >5 tasks:** Use `/forge` (autonomous via AgentForge)
- **User preference:** If user specified, use that

During execution, use **UltraQA cycling** for failed gates:
1. Gate fails (test/build/lint/typecheck)
2. Spawn `diagnostician` subagent — reads error, classifies, provides fix
3. Executor applies the diagnosed fix
4. Re-run the gate
5. Max 3 diagnostic cycles per gate before escalating

### Phase 4: Deslop

Run `/deslop` on all changed files:
1. Scan for AI slop (TODOs, console.logs, stubs, commented-out code)
2. Clean definite-remove items
3. Verify tests still pass after cleanup
4. Commit cleanup

If deslop breaks tests, revert and skip the problematic cleanup.

### Phase 5: Review

Run `/review` from ReviewForge:
1. Blind parallel review (Claude subagent + Gemini + optional GPT)
2. Finding synthesis with consensus classification
3. Verification pass to disprove false positives
4. Verdict: APPROVE / REQUEST CHANGES / BLOCK

**If BLOCK or REQUEST CHANGES:**
- Run `/triage` on the review findings
- Apply fixes for CRITICAL/MAJOR issues
- Re-run `/deslop` and `/review`
- Max 2 review cycles. If still failing after 2, escalate to user.

### Phase 6: PR + Notify

If review APPROVED:
1. Run `/pr` — create GitHub PR with structured summary and AI disclosure
2. Send notification via the repo wrapper:
   ```bash
   bash .claude/scripts/notify-clawhip.sh finished \
     --session "<feature>" \
     --summary "PR ready: <pr-url>"
   ```
   This emits `agent.finished` with `project=SpecForge`, which local Clawhip routing
   sends to `#codex` by default.
3. Present PR URL to user

## Context Snapshots

At each phase transition, write a context snapshot to `docs/specs/<feature>-context.md`:

```markdown
# Context: [Feature Name]
**Last updated:** [timestamp]
**Current phase:** [1-6]
**Status:** [in progress / waiting for user / complete]

## Research Summary
[Key findings, or "skipped"]

## Spec Summary
[Approved option, task count, key risks]

## Execution Status
[Tasks completed/total, any failures]

## Review Status
[Verdict, key findings]
```

This snapshot ensures that if context is lost (compaction, crash, mode switch), the next
phase can pick up from the snapshot instead of starting over.
If `.claude/scripts/write-context-snapshot.sh` exists, use it so the snapshot format
stays consistent with `/research`, `/spec`, and `/yolo`.

## Progress Reporting

At each phase transition, report status to the user:

```
=== AUTOPILOT: [Feature Name] ===
Phase 1 (Research):  ✓ Complete / ⊘ Skipped
Phase 2 (Spec):      ✓ Approved — 5 tasks
Phase 3 (Execute):   ▶ In progress — 3/5 tasks done
Phase 4 (Deslop):    ○ Pending
Phase 5 (Review):    ○ Pending
Phase 6 (PR):        ○ Pending
==================================
```

## Human Checkpoints (NOT Skippable)

Even in autopilot, two moments require human input:
1. **Phase 2: Interview answers** — You must answer the 3-5 clarifying questions
2. **Phase 2: Spec approval** — You must approve the spec before execution begins

Everything else runs autonomously.

## Abort Conditions

Stop autopilot and escalate to user if:
- Spec critic finds CRITICAL flaws that can't be resolved
- >50% of tasks fail during execution
- Review BLOCKS after 2 fix cycles
- Any security-related issue is flagged by any reviewer
- Context snapshot indicates we've been stuck on the same phase for >30 minutes

## IMPORTANT RULES

- **Never skip the interview.** Autopilot automates execution, not requirements gathering.
- **Never skip spec approval.** The human must approve the plan.
- **Always write context snapshots.** They're the crash-resilience mechanism.
- **Always run deslop before review.** Clean code reviews faster and more accurately.
- **Use Clawhip for notifications.** Not notify-discord.sh.
- **Escalate early.** If something feels wrong, stop and ask. Autopilot with bad assumptions wastes more time than asking a question.
