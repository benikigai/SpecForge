# Debug State — SpecForge

Last updated: 2026-04-07

## Current Objective

Documentation rollout: 4-file standard (CLAUDE.md, AGENT.md, DEBUG.md, CHANGELOG.md).

## Deployed Status

- **Repo:** benikigai/SpecForge (private)
- **Branch:** main
- **Last sync:** 2026-04-05 (auto-sync)

## Available Skills

| Skill | Status | Notes |
|-------|--------|-------|
| /spec | Active | Planning and specification |
| /yolo | Active | Supervised execution |
| /forge | Active | Autonomous via AgentForge |
| /karpathy | Active | Autoresearch optimization loop |
| /research | Active | Deep web research |
| /autopilot | Active | Full lifecycle chain |
| /deslop | Active | AI slop cleanup |
| /review | Active | Multi-model code review |
| /triage | Active | Failure classification |

## Available Subagents

| Agent | Purpose |
|-------|---------|
| code-reviewer | Quality gate after implementation |
| researcher | Architecture/dependency analysis |
| critic | Options analysis review |
| diagnostician | Debug and failure analysis |
| security-reviewer | Security-focused review |

## Feature Flags

None currently active.

## Active Anomalies

None currently tracked.

## Infrastructure

- Primary orchestrator: Claude Code (Opus)
- State management: Physical checkboxes on disk (docs/specs/)
- Review: Internal subagents + optional Gemini API
- Autonomous: AgentForge Ralph Loop via /forge
