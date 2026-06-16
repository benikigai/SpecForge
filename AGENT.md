# Agent Rules — SpecForge

## Philosophy: Three Es

Every decision is evaluated against:

- **Elegant:** Minimal complexity, coherent architecture, no unnecessary abstractions
- **Efficient:** Smallest safe diff, lowest cognitive/runtime/token cost
- **Effective:** Solves the real problem with low regression risk and long-term durability

When presenting options, score each against the Three Es. Recommend one with rationale.
Never present a bare choice without analysis.

## Workflow Rules

### Spec-First Development

Use `/spec` for all new features and non-trivial changes.
`/yolo` only executes an approved spec artifact from `docs/specs/`. It never invents scope.
`/forge` launches autonomous execution via AgentForge's Ralph Loop.
`/karpathy` optimizes against a measurable metric with a mechanical ratchet.

### Task Sizing

Each `/yolo` task must be story-sized: completable in one context window.
Refuse to batch oversized tasks. Decompose first.

### Subagent Usage

Run `code-reviewer` after every implementation task.
Run `researcher` before implementing complex-tier tasks.
Agent definitions live in `.claude/agents/`.

## Quality Gates

### Before Coding

```bash
# Explore codebase before planning
# Plan before coding
# Run /spec for non-trivial work
```

### During Implementation

```bash
# Write tests before or alongside implementation
# Run targeted tests after every edit
# Handle errors at every level — never silently swallow
# Validate all inputs at system boundaries
```

### Before Commit

```bash
# Run full test suite before marking a feature complete
# Format code on save — lint must pass before commit
# Run code-reviewer subagent
```

### Git Discipline

```bash
# Create a feature branch before any /yolo run
git checkout -b feat/<scope>

# Commit after each passing task
git commit -m "feat(<scope>): task N — <description>"

# Never force push. Never commit secrets.
```

Spec artifacts, run logs, and reviews are committed to `docs/`.

## Protected Paths

These require explicit user approval before modification:

- Database migrations
- Authentication/authorization logic
- Environment variables and secrets
- Lock files (package-lock.json, yarn.lock, etc.)
- CI/CD configuration
- CLAUDE.md and .claude/ configuration

## Context Management

- Use `/compact` at logical breakpoints, not just when auto-triggered
- When compacting, preserve: current task objective, modified file list, test status, spec reference
- Keep CLAUDE.md under 80 lines — domain-specific workflows belong in skills

## Code Style

- Prefer composition over inheritance
- Many small files over few large ones
- Only document the non-obvious
- Use positive rules ("do X" over "don't do Y")

## Key Principles

1. Spec owns ambiguity. Yolo owns zero.
2. One writer, parallel reviewers.
3. Hooks enforce. CLAUDE.md advises.
4. Story-sized tasks. One at a time.
5. Files are memory. Chat is ephemeral.
6. Commit after every passing task.

## Knowledge Base

| Topic | Location |
|-------|----------|
| Spec template | `docs/templates/spec-template.md` |
| Run report template | `docs/templates/run-template.md` |
| Review template | `docs/templates/review-template.md` |
| Architecture | `ARCHITECTURE.md` |
| Skill definitions | `.claude/skills/` |
| Agent definitions | `.claude/agents/` |
