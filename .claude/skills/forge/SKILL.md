---
name: forge
description: >
  Bridge to AgentForge's autonomous Ralph Loop. Reads an approved spec's forge JSON,
  generates build prompts, and launches ralph-loop.sh for fully autonomous execution.
  Use when you want to execute a spec unattended — overnight builds, batch features,
  or any time you don't need to supervise each task. Requires AgentForge to be installed.
invocation: user
---

# /forge — Autonomous Execution via AgentForge

You are in FORGE MODE. Your job is to bridge an approved spec artifact to AgentForge's
autonomous Ralph Loop. You generate the right inputs, launch the loop, and report results.

## Pre-Flight Checklist

Before launching, verify ALL of these. If any fail, STOP and report:

- [ ] **Approved spec exists:** Check `docs/specs/` for the relevant `<feature>.md`
- [ ] **Forge JSON exists:** Check `docs/specs/<feature>-forge.json` — if missing, generate it from the spec
- [ ] **Git is clean:** No uncommitted changes (`git status`)
- [ ] **Feature branch exists:** Create one if not: `git checkout -b feat/<feature>`
- [ ] **Base tests pass:** Run the project's test suite to establish a green baseline
- [ ] **AgentForge installed:** Check `$AGENTFORGE_HOME` or `~/code/AgentForge/ralph-loop.sh` exists
- [ ] **Builder available:** Verify `codex` CLI is installed (`which codex`)
- [ ] **API keys set:** `OPENAI_API_KEY` and `ANTHROPIC_API_KEY` must be exported

## Step 1: Generate Build Prompt

Read the project's `CLAUDE.md` (or `AGENTS.md`) and the approved spec. Generate a
build prompt file at `docs/specs/<feature>-PROMPT_build.md`:

```markdown
# Build Mode — [Feature Name]

You are building exactly ONE task from the feature list, then EXIT.

## Project Context
[Relevant sections from CLAUDE.md — tech stack, code style, key files]

## Step 1: Check for Revision Feedback
Read `.ralph-logs/feedback.md`. If it contains feedback:
- Fix ONLY the issues described
- Do NOT start the task over
- Skip to Step 3

## Step 2: Pick Your Task
Read the feature list JSON. Find the first item where `passes: false` AND NOT `skipped: true`.
Check what already exists: scan relevant directories and `git log --oneline -5`.

## Step 3: Build It
Rules:
- ONE task only
- Write COMPLETE code (no TODOs, stubs, placeholders)
- Handle edge cases and error states
- Ensure all imports exist
- Stay within the files listed in the task description

## Step 4: Verify
Run the verification command from the feature's `verify` field.
Also run: [project build command, e.g., npm run build / cargo build / pytest]
If verification fails, FIX IT before exiting.

## Step 5: Exit
Do NOT: update the feature list, git commit/push, or implement additional tasks.
ONE task. Build it. Verify it. Exit.
```

## Step 2: Launch AgentForge

Run the Ralph Loop with spec-driven paths:

```bash
AGENTFORGE_HOME="${AGENTFORGE_HOME:-$HOME/code/AgentForge}"

"$AGENTFORGE_HOME/ralph-loop.sh" \
    --features "docs/specs/<feature>-forge.json" \
    --prompt "docs/specs/<feature>-PROMPT_build.md" \
    --project-dir "$(pwd)"
```

**Before launching, inform the user:**
- How many tasks are in the forge JSON
- Estimated time (rough: 5-10 min per simple task, 10-20 per moderate, 15-30 per complex)
- That the loop will run autonomously — they can walk away
- How to monitor: `tail -f .ralph-logs/iteration-*.log`
- How to stop: `Ctrl+C` (the loop commits after each passing task, so no work is lost)

Ask the user to confirm before launching.

## Step 3: Collect Results

After the Ralph Loop completes (or is stopped), read the results and generate a run report:

1. Read the forge JSON to see which tasks passed/skipped
2. Read `.ralph-logs/` for attempt details, scores, and feedback
3. Read `git log` for commits made during the run
4. Write the run report to `docs/runs/<feature>-run.md` using the run template

Update the yolo execution file too — mark any forge-completed tasks as `[x]` so `/yolo`
knows where to resume if needed.

## Step 4: Present Results

Show the user:
- Tasks completed vs skipped
- Scores per task (from evaluator)
- Any tasks that need manual intervention (`/yolo` for failed tasks)
- Total tokens consumed and cost estimate
- The run report location

If tasks were skipped, suggest: "Run `/yolo` to step through the failed tasks manually."

## Forge JSON Not Found?

If the spec exists but the forge JSON doesn't (e.g., older spec created before forge support),
generate it on the fly:

1. Read the spec's task list
2. For each task, create a forge entry:
   - `id` — task number
   - `category` — complexity tier (lowercase)
   - `description` — task objective + files to change
   - `verify` — test plan commands joined with ` && `
   - `passes` — `false`
   - `skipped` — `false`
3. Write to `docs/specs/<feature>-forge.json`
4. Commit: `forge: generate forge JSON for <feature>`

## CRITICAL RULES

- **NEVER modify the spec.** The spec is frozen. If something needs to change, tell the user to re-spec.
- **NEVER run ralph-loop.sh without user confirmation.** It's autonomous and will run for a while.
- **ALWAYS generate the build prompt before launching.** The loop needs project-specific context.
- **ALWAYS check for AgentForge installation.** Don't fail cryptically if it's missing.
- **Forge is for unattended execution.** If the user wants to watch each step, tell them to use `/yolo` instead.
