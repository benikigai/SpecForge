# SpecForge

Turn Claude Code into a disciplined engineer. `/spec` to think. `/yolo` to ship. `/forge` to run overnight. Zero freestyle.

---

## The Problem

AI coding agents are powerful but undisciplined. They skip planning, hallucinate scope, ignore edge cases, and ship untested code. The longer the task, the worse it gets.

## The Fix

Drop these files into your repo. Now Claude Code operates in three modes:

**`/spec`** — Forces Claude to think before coding. It scans your codebase, asks you 3-5 hard clarifying questions, presents scored implementation options, decomposes into story-sized tasks with acceptance criteria and rollback plans, and writes the approved plan to disk. No code written.

**`/yolo`** — Supervised execution. Reads the approved plan. Executes one task at a time. Runs format/lint/typecheck/tests after every edit. Spawns an independent code reviewer. Optionally calls Gemini for a cross-model second opinion. Commits only when everything passes. If Claude crashes mid-run, it reads the checkpoint file and resumes from where it left off.

**`/forge`** — Autonomous execution via [AgentForge](https://github.com/benikigai/AgentForge). Translates the spec into AgentForge's format and launches the Ralph Loop. Codex builds each task, Sonnet scores it 0-10, and the harness retries up to 3 times with structured feedback. Walk away, come back to committed code.

The agent never invents scope. If the spec doesn't say to do it, it doesn't do it.

## What's Inside

```
your-project/
├── CLAUDE.md                           # Always-on rules (~60 lines)
├── ARCHITECTURE.md                     # System design reference
├── .claude/
│   ├── settings.json                   # Hooks + permissions
│   ├── skills/
│   │   ├── spec/SKILL.md              # /spec — planning engine
│   │   ├── yolo/SKILL.md             # /yolo — supervised executor
│   │   ├── forge/SKILL.md            # /forge — AgentForge bridge
│   │   └── research/SKILL.md         # /research — Karpathy loop
│   ├── agents/
│   │   ├── code-reviewer.md           # Quality gate (read-only)
│   │   ├── researcher.md              # Architecture investigator (read-only + web)
│   │   └── security-reviewer.md       # Security hunter (read-only)
│   ├── scripts/
│   │   └── review.sh                  # External Gemini review via curl
│   └── provider-handoff.md            # Cross-model review contract
└── docs/
    ├── specs/                          # Approved spec artifacts
    ├── runs/                           # Execution logs
    ├── reviews/                        # Review output
    └── templates/                      # Blank templates (spec, run, review)
```

## Quick Start

```bash
# 1. Clone into your project
git clone https://github.com/benikigai/SpecForge.git /tmp/sdh
cp -r /tmp/sdh/.claude /tmp/sdh/CLAUDE.md /tmp/sdh/ARCHITECTURE.md /tmp/sdh/docs your-project/
rm -rf /tmp/sdh

# 2. Optional: enable external Gemini review
export GEMINI_API_KEY="your-key-here"

# 3. Start Claude Code in your project
cd your-project
claude

# 4. Plan a feature
> /spec I want to add user authentication with OAuth2

# 5a. Execute supervised (you watch)
> /yolo

# 5b. Execute autonomous (walk away)
> /forge
```

## How It Works

### /spec Flow

```
You describe a feature
    → Claude scans codebase
    → Asks 3-5 clarifying questions
    → Presents 2-3 options scored on Elegant / Efficient / Effective
    → Decomposes chosen option into tasks
    → Writes approved spec to docs/specs/
```

### /yolo Flow

```
For each task in the spec:
    → Restate objective (no ambiguity)
    → Implement (stay in spec's file list)
    → Run format / lint / typecheck / tests
    → Spawn code-reviewer subagent
    → Optional: call Gemini via review.sh
    → Fix any issues raised
    → Commit with structured message
    → Mark checkbox [x] in execution file
    → Next task
```

### /forge Flow (Autonomous via AgentForge)

```
/forge reads the approved spec
    → Generates forge JSON (AgentForge feature list format)
    → Generates build prompt from spec + project context
    → Launches ralph-loop.sh
        → Codex builds each task
        → Sonnet evaluator scores 0-10
        → If score < threshold: structured feedback → retry (up to 3x)
        → If pass: commit + mark complete
        → If stagnation: accept if close, skip if not
    �� Writes run report to docs/runs/
    → Marks yolo checkboxes for any completed tasks
```

**Requirements:** [AgentForge](https://github.com/benikigai/AgentForge) installed at `~/code/AgentForge`, `codex` CLI, `OPENAI_API_KEY` + `ANTHROPIC_API_KEY` set.

### /research Flow (Complex Tasks Only)

```
Up to 5 iterations:
    → Hypothesize an approach
    → Build minimal proof
    → Measure against metrics
    → Keep improvement or git stash discard
    → Repeat until validated
```

## When to Use Which

| Situation | Use |
|-----------|-----|
| First time building in a new area of the codebase | `/yolo` — watch and learn |
| Security-sensitive changes (auth, payments, data) | `/yolo` — human review per task |
| Well-defined feature, clear tests, low risk | `/forge` — let it run |
| Overnight batch of features | `/forge` — built for this |
| Debugging a failed `/forge` task | `/yolo` — step through manually |
| Complex architecture decision | `/yolo` + `/research` — need human judgment |

## The Review Chain

Every task gets reviewed before commit. Up to three independent perspectives:

| Reviewer | Model | How |
|----------|-------|-----|
| **code-reviewer** | Claude Sonnet (subagent) | Spawned automatically — checks correctness, edge cases, tests, security |
| **Gemini** | Flash/Pro (API) | `review.sh` sends `git diff` to Gemini, prints verdict to terminal |
| **You** | Human | Final review after all tasks complete |

## Complexity Tiers

Tasks are graded. The system scales its effort accordingly:

| Tier | When | Research | Review |
|------|------|----------|--------|
| **Simple** | Known pattern, <50 LOC, <3 files | Skip | Hooks only |
| **Moderate** | Some ambiguity, 50-200 LOC, 3-6 files | Light | Subagent review |
| **Complex** | Architecture change, >200 LOC, >6 files | Full /research loop | Full review chain |

## Safety

- **Hooks enforce rules deterministically** — not suggestions, not prose
- **PreToolUse hook** blocks `rm -rf`, `--force`, `--no-verify`, `.env` access
- **Stop hook** verifies acceptance criteria met before Claude finishes any turn
- **Protected paths** require explicit approval (migrations, auth, secrets, CI/CD, lock files)
- **Crash resilience** — physical `[ ]`/`[x]` checkboxes on disk track progress; resume from any interruption
- **Every passing task is committed** — your safety net

## Core Principles

1. **Spec owns ambiguity. Yolo owns zero.**
2. **One writer, parallel reviewers.** Only Opus edits code.
3. **Hooks enforce. CLAUDE.md advises.**
4. **Story-sized tasks. One at a time.**
5. **Files are memory. Chat is ephemeral.**

## Customization

- Edit `CLAUDE.md` for your project's rules and conventions
- Edit `.claude/settings.json` to adjust hooks for your formatter/linter
- Edit agent files to tune review criteria
- Set `REVIEWER_MODEL` env var to change the Gemini model (default: `gemini-2.5-flash`)

## What This Draws From

Built on patterns from [Ralph](https://github.com/frankbria/ralph-claude-code) (file-based state, one story per loop), [Oh My Codex](https://github.com/Yeachan-Heo/oh-my-codex) (deep interviews, staged pipelines), [Karpathy's AutoResearch](https://github.com/karpathy/autoresearch) (hypothesis-driven iteration), and Anthropic's official Claude Code best practices (hooks, subagents, skills, concise CLAUDE.md).

## License

MIT
