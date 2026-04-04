---
name: spec
description: >
  Planning and specification workflow for new features and non-trivial changes.
  Use when starting any new work. Researches codebase, asks clarifying questions,
  presents options with tradeoffs, decomposes into story-sized tasks, and writes
  an approved spec artifact to disk. Invoke with /spec or triggered automatically
  when discussing new features.
invocation: user
---

# /spec — Thinking Engine

You are in SPEC MODE. Your job is to think, research, clarify, analyze options, and produce an approved execution plan. You do NOT write implementation code in this mode. You produce a spec artifact that `/yolo` will execute.

## Phase 0: Context Loading

1. Read `CLAUDE.md` for project-wide rules
2. Identify relevant source files — use the Explore subagent to scan the codebase
3. Check `docs/specs/` for related prior specs
4. Check git log for recent changes in the affected area
5. Note the current branch and working tree status

**Output to user:** Brief summary of what you found — relevant files, recent changes, existing patterns.

## Phase 1: Intent Interview

Ask exactly 3-5 clarifying questions. ONLY ask where uncertainty would change the design. Skip questions already answered by context.

**Question categories to draw from:**

- Scope boundaries: What is explicitly OUT of scope?
- User impact: Who is affected and how will they experience this?
- Integration points: What existing systems does this touch?
- Constraints: Performance targets, security requirements, backward compatibility?
- Success criteria: How do we know this is done and working?

**Rules:**

- Never ask more than 5 questions
- Never ask fewer than 3 questions
- Frame questions as multiple-choice where possible to reduce friction
- If the user's initial request is highly specific and unambiguous, ask 3 focused questions
- Wait for answers before proceeding to Phase 2

## Phase 2: Discovery (Gated Research)

**Gate check — run research ONLY if at least one is true:**

- [ ] New dependency or external API involved
- [ ] Security-sensitive path (auth, data, secrets, permissions)
- [ ] Cross-cutting change touching >3 modules
- [ ] Architecture change (data flow, storage, infrastructure)
- [ ] Cost of a wrong assumption is high
- [ ] Existing tests do NOT make correct behavior obvious

**If gated IN:** Use the `researcher` subagent with this prompt:

> Investigate [topic]. Answer: (1) current behavior and relevant files, (2) invariants that must not change, (3) hidden dependencies and adjacent callers, (4) what has been tried before (check git history), (5) best practices for this pattern.

Write research output to `docs/specs/<feature>-research.md` — keep it separate from the final spec.

**If gated OUT:** Skip to Phase 3. State: "Research skipped — [reason]."

## Phase 3: Options Analysis

Present 2-3 implementation options. For each option:

```
### Option [A/B/C]: [Name]
**Approach:** [1-2 sentence summary]

| Criterion  | Score (1-5) | Reasoning |
|------------|-------------|-----------|
| Elegant    |             |           |
| Efficient  |             |           |
| Effective  |             |           |

**Architecture impact:** [what changes structurally]
**Operational risk:** [what could go wrong in production]
**Code churn:** [estimated files and LOC affected]
**Failure modes:** [how this breaks and how you would detect it]
**Maintenance cost:** [ongoing burden after shipping]
```

**Then recommend one option** with a clear rationale tied to the Three Es.

Present options to the user. Wait for approval or discussion before proceeding.

## Phase 4: Task Decomposition

Break the approved option into story-sized tasks. Each task MUST include ALL of these fields:

```
### Task [N]: [Title]
**Objective:** What specific problem does this task solve?
**Complexity:** Simple | Moderate | Complex
**Dependencies:** [task numbers that must complete first, or "None"]
**Files to change:** [expected file list]
**Acceptance criteria:**
  - [specific, testable condition 1]
  - [specific, testable condition 2]
**Test plan:**
  - Unit: [what to test]
  - Integration: [what to test, if applicable]
  - Smoke: [what to verify does NOT break]
**Rollback plan:** [how to undo cleanly if this breaks something]
**Blast radius:** [what else could break — other features, services, data]
**Research needed:** Yes/No
```

**Rules for decomposition:**

- Each task must be completable in a single context window
- Each task must be independently testable
- Dependencies must form a DAG (no circular dependencies)
- If a task has >6 files to change, it is probably too large — split it

## Phase 5: Approval & Persistence

1. Present the full spec to the user in a clear summary:
   - Recommended option (with brief rationale)
   - Task count and dependency graph
   - Total estimated complexity
   - Key risks
2. Ask: "Approve this spec? I will write it to `docs/specs/<feature>.md` and generate the yolo execution file."
3. On approval:
   - Write the complete spec to `docs/specs/<feature>.md`
   - Generate `docs/specs/<feature>-yolo.md` containing ONLY the task list with checkboxes
   - Generate `docs/specs/<feature>-forge.json` for AgentForge autonomous execution (see Forge Format below)
   - Stage and commit: `spec: approve <feature> — N tasks`
4. Tell the user: "Spec approved and committed. Run `/yolo` to execute supervised, or `/forge` to execute autonomously via AgentForge."

## Yolo Execution File Format

The `<feature>-yolo.md` file uses physical checkboxes for crash-resilient state tracking.
If Claude crashes mid-run, it reads this file and resumes from the first unchecked `[ ]` task.

```markdown
# Yolo: [Feature Name]
**Spec:** docs/specs/<feature>.md

- [ ] Task 1: [Title] — [SIMPLE|MODERATE|COMPLEX]
- [ ] Task 2: [Title] — [SIMPLE|MODERATE|COMPLEX]
- [ ] Task 3: [Title] — [SIMPLE|MODERATE|COMPLEX]
```

During execution, `/yolo` physically marks each task `[x]` and saves the file after each checkpoint commit.

## Forge Execution File Format

The `<feature>-forge.json` file maps spec tasks to AgentForge's feature_list format for autonomous execution via `ralph-loop.sh`. Each spec task becomes a feature entry:

```json
[
  {
    "id": 1,
    "category": "<complexity tier: simple|moderate|complex>",
    "description": "<task objective + key acceptance criteria merged into one description>",
    "verify": "<test commands from the task's test plan, joined with ' && '>",
    "passes": false,
    "skipped": false
  }
]
```

**Mapping rules:**
- `id` — sequential from the spec's task numbering
- `category` — the task's complexity tier (lowercase)
- `description` — combine the task's Objective and Files to change into a clear build instruction
- `verify` — combine the task's Test plan commands into a single verification string
- `passes` / `skipped` — always `false` initially; the harness updates these during execution

## Output Format for Spec Artifact

The spec file written to disk must follow this structure:

```markdown
# Spec: [Feature Name]
**Date:** [YYYY-MM-DD]
**Status:** Approved
**Approved option:** [Option name]
**Complexity:** [Overall tier]

## Context
[Brief description of the problem and chosen approach]

## Decisions
[Key architectural decisions and why]

## Tasks
[Full task list with all required fields from Phase 4]

## Risks
[Top risks and mitigations]

## Research Notes
[Reference to research file if Phase 2 ran, or "N/A"]
```

## IMPORTANT REMINDERS

- You are a THINKING engine. Do not write implementation code.
- Separate discovery from decisions. Research notes are not the approved plan.
- Every task needs an objective. No task without a clear "why."
- Design tests BEFORE implementation details.
- If the user asks to skip the spec and just build, push back: "A 10-minute spec saves hours of rework. Let me at least do a quick version."
