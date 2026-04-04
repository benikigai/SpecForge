# Project Rules

## Philosophy: Three Es

Every decision — architecture, code, tooling — is evaluated against:

- **Elegant:** Minimal complexity, coherent architecture, no unnecessary abstractions
- **Efficient:** Smallest safe diff, lowest cognitive/runtime/token cost
- **Effective:** Solves the real problem with low regression risk and long-term durability

## Development Workflow

- ALWAYS explore the codebase before planning. Plan before coding.
- Use `/spec` for all new features and non-trivial changes. Never skip the spec phase.
- Use `/yolo` only to execute an approved spec artifact from `docs/specs/`. Never invent scope.
- Use `/forge` to execute a spec autonomously via AgentForge's Ralph Loop (unattended).
- Each `/yolo` task must be story-sized (completable in one context window). Refuse to batch oversized tasks.
- Use the `code-reviewer` subagent after every implementation task.
- Use the `researcher` subagent before implementing complex-tier tasks.

## Code Quality

- Write tests before or alongside implementation, never after.
- Run targeted tests after every edit. Run full suite before marking a feature complete.
- Format code on save. Lint must pass before commit.
- Handle errors at every level. Never silently swallow errors.
- Validate all inputs at system boundaries.
- Prefer composition over inheritance. Many small files over few large ones.

## Git Discipline

- Create a feature branch before any `/yolo` run.
- Commit after each passing task with: `feat(<scope>): task N — <description>`
- Never force push. Never commit secrets, credentials, or API keys.
- Spec artifacts, run logs, and reviews are committed to `docs/`.

## Protected Paths (Require Explicit Approval)

- Database migrations
- Authentication/authorization logic
- Environment variables and secrets
- Lock files (package-lock.json, yarn.lock, etc.)
- CI/CD configuration
- CLAUDE.md and .claude/ configuration

## Context Management

- Keep this file under 100 lines. Domain-specific workflows belong in skills.
- Use `/compact` at logical breakpoints, not just when auto-triggered.
- When compacting, preserve: current task objective, modified file list, test status, spec reference.

## File Structure Reference

- `docs/specs/<feature>.md` — Approved spec artifacts
- `docs/runs/<feature>-run.md` — Execution logs
- `docs/reviews/<feature>-review.md` — Review output
- `.claude/skills/` — On-demand workflow skills
- `.claude/agents/` — Subagent definitions
