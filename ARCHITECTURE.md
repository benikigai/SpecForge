# Agent Harness Architecture v1.0

## Core Design

- **Primary Orchestrator:** Claude Code (Terminal) — Opus as sole writer
- **State Management:** Physical checkboxes on disk (`docs/specs/*-yolo.md`) for crash resilience
- **Verification Engine:** Ralph Loop — persistent code/fix retries until exit 0
- **Research Engine:** Karpathy Loop — dry-run hypotheses with explicit `git stash`/`git checkout` rollback
- **Review Gate:** Internal subagent (code-reviewer) + optional external API (Gemini via review.sh)
- **Autonomous Engine:** AgentForge Ralph Loop via `/forge` — Codex builds, Sonnet scores, harness commits

## Workflow

```
User -> /spec -> Interview -> Research (gated) -> Options -> Tasks -> Approved Spec
                                                                          |
                                                               ┌──────────┴──────────┐
                                                               │                     │
                                                            /yolo                  /forge
                                                         (supervised)          (autonomous)
                                                               │                     │
                                                     Claude Code task loop    AgentForge ralph-loop
                                                     + subagent review        + Sonnet evaluator
                                                     + optional Gemini        + quality backpressure
                                                               │                     │
                                                          docs/runs/            docs/runs/
```

## Complexity Tiers

| Tier     | Criteria                            | Research          | Review               |
|----------|-------------------------------------|-------------------|----------------------|
| Simple   | Known pattern, <50 LOC, <3 files    | Skip              | Hooks only           |
| Moderate | Some ambiguity, 50-200 LOC, 3-6 files | Light (1 pass) | Subagent review      |
| Complex  | Architecture change, >200 LOC, >6 files | Full Karpathy loop | Full review chain |

## Agent Roles

| Agent             | Model  | Access     | Purpose                           |
|-------------------|--------|------------|-----------------------------------|
| Opus (main)       | opus   | All tools  | Sole writer — implements code     |
| code-reviewer     | sonnet | Read-only  | Quality gate after every task     |
| researcher        | sonnet | Read + Web | Architecture/dependency analysis  |
| security-reviewer | sonnet | Read-only  | Security-focused review           |
| Gemini (external) | flash  | API only   | Independent second opinion        |
| Codex (via /forge) | gpt-5.3 | Codex CLI | Autonomous builder in Ralph Loop |
| Sonnet (evaluator) | sonnet | API only   | Scores /forge builds 0-10        |

## Key Principles

1. Spec owns ambiguity. Yolo owns zero.
2. One writer, parallel reviewers.
3. Hooks enforce. CLAUDE.md advises.
4. Story-sized tasks. One at a time.
5. Files are memory. Chat is ephemeral.
6. Commit after every passing task.
