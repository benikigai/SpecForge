---
name: deslop
description: >
  Mandatory AI-slop cleanup pass. Scans changed files for TODOs, stubs, placeholder
  text, console.logs, commented-out code, and other AI-generated junk. Runs after
  implementation, before final review. Adapted from OMX's ai-slop-cleaner pattern.
invocation: user
---

# /deslop — AI Slop Cleaner

You are in DESLOP MODE. Your job is to clean AI-generated junk from changed files.
This runs AFTER implementation and BEFORE review. It's a mandatory quality pass.

## What to Remove

Scan all changed files (via `git diff --name-only main...HEAD` or `git diff --name-only HEAD~N`) for:

### Definite Remove (always clean these)
- `TODO` / `FIXME` / `HACK` / `XXX` comments that weren't there before
- `console.log` / `console.debug` / `print()` debug statements (unless the feature IS logging)
- `// eslint-disable` / `# noqa` / `# type: ignore` without justification
- Placeholder text: "Lorem ipsum", "test123", "foo bar", "example.com" in non-test code
- Commented-out code blocks (>2 lines of commented code)
- Empty catch blocks / error swallowing (`catch (e) {}`)
- `any` type annotations in TypeScript (unless justified)
- Unused imports
- Duplicate imports

### Likely Remove (flag for review)
- Functions that are defined but never called
- Variables assigned but never read
- Overly verbose comments that just restate the code
- Unnecessary `else` after `return`
- Triple-nested ternaries or overly clever one-liners

### Never Remove
- Comments explaining WHY (not what)
- TODOs that reference a ticket number (e.g., `TODO(#123)`)
- Debug logging that's part of the feature's observability
- Test fixtures and test data (even if they look like placeholders)

## Process

1. **Scan**: Get list of changed files. For each file, search for slop patterns.
2. **Report**: List all findings with file:line references.
3. **Clean**: Remove definite-remove items. Flag likely-remove items for confirmation.
4. **Verify**: Run the project's test suite after cleanup to ensure nothing broke.
5. **Commit**: If tests pass, commit: `chore: deslop cleanup — removed N items`
6. **If tests fail**: Revert the cleanup that caused the failure, re-run.

## Output

```markdown
## Deslop Report

**Files scanned:** [N]
**Items found:** [N]
**Items cleaned:** [N]
**Items flagged:** [N] (need human decision)

### Cleaned
- `src/auth/oauth.ts:42` — removed `console.log("debug")`
- `src/auth/oauth.ts:78` — removed `// TODO: fix this later`
- `src/routes/login.ts:15` — removed unused import `express`

### Flagged (needs review)
- `src/auth/oauth.ts:95` — function `helperFn()` defined but never called
- `src/utils/format.ts:12` — overly verbose comment restating the code

### Verification
- Tests: [PASS/FAIL]
- Build: [PASS/FAIL]
```

## Integration Points

- **After `/yolo` task completion**: Run `/deslop` before the code-reviewer subagent
- **After `/forge` completion**: Run `/deslop` on all changed files before `/review`
- **Standalone**: Run anytime to clean up a branch

## IMPORTANT RULES

- **Never remove code that's part of the feature.** Only remove junk.
- **Always verify after cleanup.** A deslop that breaks tests is worse than no deslop.
- **Flag uncertain items.** When in doubt, flag for human — don't auto-remove.
- **One commit for all cleanup.** Don't commit per-file.
