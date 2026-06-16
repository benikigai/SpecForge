# Spec: Nightshift v2 — Always-On Persistent Agent Loop

**Status:** Approved
**Approved option:** Option C — Strangler-fig supervisor (persistent launchd daemon + executor-adapter interface, incremental migration; no big-bang rewrite)
**Overall complexity:** Complex
**Date:** 2026-06-14
**Amended:** 2026-06-15 — added authentication & cost model (subscription-first, API-fallback); inserted Task 4 (auth layer); renumbered downstream tasks.
**Supersedes:** the working title "Forge v2"

---

## Naming decision (LOCKED)

The stack is renamed away from "Forge". The always-on supervisor is **Nightshift**; the three
stages are themed to the night-shift metaphor.

| Old | New | Role |
|---|---|---|
| *(new umbrella)* | **Nightshift** | always-on supervisor / daemon (`nightshiftd`, `nightshift run`) |
| SpecForge | **Brief** | the shift brief — plan → scored options → tasks |
| AgentForge (`agentforge`) | **Graveyard** | the overnight build loop (Ralph technique; Codex/Claude/Antigravity adapters) |
| ReviewForge | **Handoff** | the morning handoff — blind multi-model review → triage → PR |

**Vocabulary:**
- A queued unit of work = a **shift** → `queue/pending/<feature>.shift.json` (was `forge.json`).
- Config = `nightshift.config.json` (was `forge.config.json`).
- Supervisor state = `nightshift/state/` (checkpoint, budget ledger, hypothesis history, breaker).
- Build-loop entrypoint = `graveyard.sh` (was `ralph-loop.sh`).

**Target directory layout** (after T1 rename):
```
/Users/elias/code/nightshift/            # renamed from /Users/elias/code/forge/
├── nightshift/                          # NEW supervisor (umbrella)
│   ├── nightshiftd / forge-supervisor → nightshift-supervisor.sh
│   ├── dispatch.sh
│   ├── auth.sh                          # subscription-first auth resolver (T4)
│   ├── adapters/{codex.sh,claude.sh,antigravity.sh}
│   ├── queue/{pending,active,done,failed}/
│   └── state/{checkpoint.json,budget.json,hypothesis-history.jsonl,breaker.json}
├── brief/                               # was SpecForge
├── graveyard/                           # was agentforge   (graveyard.sh was ralph-loop.sh)
├── handoff/                             # was ReviewForge
└── nightshift.config.json
```

---

## Locked configuration decisions

| Decision | Value | Rationale |
|---|---|---|
| Auth model | **subscription-first, API-fallback** | Route every model call through its official subscription CLI; drop to metered API only when the subscription rate-limits. See "Authentication & cost model" below. |
| Default builder adapter | **codex** (via ChatGPT Pro login) | Zero migration; `codex` "Sign in with ChatGPT" runs under subscription quota; automations are officially supported (cleanest ToS posture of the three). |
| Daily spend ceiling | **$20/day** (metered fallback only) | Subscription usage is "free" up to its ceiling; the $20 caps the metered-fallback spend once subscriptions exhaust. |
| Per-run (per-shift) ceiling | **$5** (metered fallback only) | One runaway shift cannot consume the whole day's fallback budget. |
| Evaluator | **`claude -p`** (Max credit pool), model `claude-sonnet-4-6` | Replace `evaluate.py`'s metered Anthropic SDK with a subscription-backed `claude -p` call — the single biggest metered→subscription win. |
| Antigravity 2.0 | **Deferred — NOT installed** (probe 2026-06-14) | `agy` OAuth rides Google AI Ultra quota but is rate-capped ~200 req/24h; light-touch reviewer/secondary builder only. Documented `claude.sh` fallback; off the critical path. |
| Circuit breaker | 3 no-progress / 5 repeated errors / 1 permission-denial / **subscription-exhausted** | Ported from `ralph-claude-code`; breaker also halts (not silently overflows to metered) when a subscription pool is exhausted. |
| Process model | **launchd** (`KeepAlive`) + `caffeinate -s` | macOS — not systemd. |
| Notifications | Telegram id `5611660528` | Guaranteed on BLOCK / budget-hit / subscription-exhausted / shift-complete. |

---

## Authentication & cost model (researched 2026-06-15)

**Goal:** run Nightshift on Ben's existing top-tier subscriptions (Claude Max, ChatGPT Pro, Google AI
Ultra) and pay **zero metered API cost**.

**Headline reality:** "subscription ≠ free" for automation in 2026. Every provider has deliberately
split headless/automated usage off from the interactive subscription. You trade an *uncapped metered
bill* for a *capped monthly ceiling that stalls the loop (or overflows to metered) once hit.* A 24/7
loop **will** hit these ceilings — which is exactly why the budget cap + circuit breaker are load-bearing.

| Provider (tier) | Subscription path (no per-token API) | Headless automation | Ceiling it hits | ToS posture |
|---|---|---|---|---|
| **OpenAI — ChatGPT Pro** | ✅ cleanest: `codex` Sign-in-with-ChatGPT under subscription quota | ✅ officially supported (scheduled/triggered Codex automations) | shared 5h + weekly windows; automations burn the same pool as interactive use | ✅ sanctioned |
| **Anthropic — Claude Max** | ⚠️ Agent SDK / `claude -p` draws a **separate, non-rollover monthly credit pool** ($100 Max 5x / $200 Max 20x), not the chat pool | ⚠️ gray (sources conflict on whether `claude -p` headless draws the pool or bills metered) | credit pool depletes in ~3–4 days sustained, then silently stops/overflows | ⚠️ OAuth restricted to official Claude Code; 3rd-party harnesses forbidden (Consumer ToS 3.7) |
| **Google — AI Ultra** | ✅ subscription grants Antigravity quota; AI credits are overage-only | ⚠️ painful: OAuth headless **rate-capped ~200 req/24h** | 200/day OAuth cap; can unexpectedly bill the Gemini API key at the boundary | ⚠️ bans issued for unauthorized/3rd-party access; official `agy` only |

**Hard rules for the auth layer:**
1. Shell out to **official CLIs only** (`codex`, `claude`, `agy`) — never reimplement provider auth or use 3rd-party auth plugins (e.g. `opencode-antigravity-auth`) → ban risk.
2. **Unset `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` when subscription auth is active** — if set, they take precedence and bill metered.
3. Keep API keys configured as **explicit fallback only**, triggered on subscription rate-limit; the breaker halts on exhaustion unless metered-fallback is opted in (bounded by the $20/day cap).
4. **Expectation:** on Max 20x + ChatGPT Pro + Ultra, expect *bursts* of heavy autonomous runtime (a few days/week), not infinite. The queue + budget pacing exist for this.

---

## Architecture summary

Nightshift is a persistent macOS launchd daemon that pulls **shifts** (forge-JSON-schema task
bundles) from a queue and drives each through **Graveyard** (build loop) → **Handoff** (review →
triage → PR), under hard budget/rate guardrails, with crash-resilient checkpointing and cross-attempt
hypothesis memory. The builder is abstracted behind a single **executor-adapter contract** so Codex
(default), Claude Code, and Antigravity 2.0 are interchangeable, each resolving auth subscription-first
via a shared `auth.sh`. The existing **Brief** planner emits the `.shift.json` bundles. The existing
Graveyard dashboard (Next.js) is repointed at supervisor state for live observability.

**What is reused verbatim (salvageable):** the Graveyard two-loop harness + best-attempt revert +
stagnation/diminishing-returns logic; the Sonnet evaluator + triple-fallback JSON parser; the
`metrics.json` + Next.js dashboard; the `.shift.json` immutable-spec contract; Brief's `/spec`→bundle
emission; Handoff's blind multi-model review + `/triage` failure taxonomy. **What is net-new:** the
persistent supervisor, the queue, the adapter interface, the subscription-first auth layer, guardrails,
hypothesis memory, worktree isolation, the Antigravity adapter, and the rename.

**Strangler migration:** the supervisor wraps today's scripts immediately; loop internals move behind
the adapter contract incrementally. No phase blocks on Antigravity (absent).

---

## Tasks

### Task 1: Rename Forge stack → Nightshift
**Objective:** Retire "Forge" everywhere. Rename repos + parent dir per the target layout, rename
`/spec`→`/brief` style skills, `forge.config.json`→`nightshift.config.json`, the `forge.json`
contract → `.shift.json`, `ralph-loop.sh`→`graveyard.sh`. Fix the broken default path
(`AGENTFORGE_HOME=$HOME/code/AgentForge` → `…/code/nightshift/graveyard`).
**Complexity:** Complex
**Dependencies:** None
**Files to change:** repo dir names; `brief/.claude/skills/*`; `graveyard/{graveyard.sh,*.py}`; `handoff/.claude/skills/*`; all `AGENTFORGE_HOME`/path references; each repo `CHANGELOG.md`.
**Acceptance criteria:**
- [ ] `/Users/elias/code/nightshift/{nightshift,brief,graveyard,handoff}` exist; no path resolves to a `*Forge` name.
- [ ] `graveyard/graveyard.sh --help` runs; `nightshift build` wraps it.
- [ ] No literal `AGENTFORGE_HOME` default points at a non-existent path.
- [ ] Each repo CHANGELOG records the rename.
**Test plan:** smoke-run one toy `.shift.json` through `graveyard.sh` post-rename; grep for residual `forge`/`Forge` in execution paths returns only historical/CHANGELOG hits.
**Rollback:** `git mv` is reversible; each repo git-checkpointed before rename. Revert dir names + path edits.
**Blast radius:** High mechanically (touches all 3 repos + paths/skills/CI) but Low semantically (no logic change). Git-checkpoint each repo first.
**Research needed:** No

### Task 2: `nightshift.config.json` + config helper
**Objective:** Single config: paths, model ids, budgets ($20 daily / $5 run, metered-fallback only), default_adapter=codex, `auth.mode=subscription_first`, `auth.fallback_api=true`, circuit-breaker thresholds, Telegram id. `nightshift-config-get` reads dotted keys.
**Complexity:** Simple
**Dependencies:** Task 1
**Acceptance criteria:**
- [ ] `nightshift-config-get .paths.graveyard` → `/Users/elias/code/nightshift/graveyard`
- [ ] `nightshift-config-get .budgets.daily_usd` → `20`
- [ ] `nightshift-config-get .auth.mode` → `subscription_first`
**Test plan:** read several dotted keys; assert values.
**Rollback:** delete config; scripts fall back to literals.
**Blast radius:** Low — config only.
**Research needed:** No

### Task 3: Externalize model ids
**Objective:** `graveyard.sh` reads builder model from config; evaluator reads `models.evaluator` (replace literal `claude-sonnet-4-20250514` → `claude-sonnet-4-6`). No behavior change when config absent.
**Complexity:** Moderate
**Dependencies:** Task 2
**Acceptance criteria:**
- [ ] No literal `gpt-5.3-codex` / `claude-sonnet-4-20250514` in execution paths.
- [ ] Loop runs end-to-end reading model from config.
**Test plan:** run with config-supplied model; confirm used.
**Rollback:** restore literals.
**Blast radius:** Low.
**Research needed:** No

### Task 4: Authentication layer (subscription-first, API-fallback)
**Objective:** Shared `nightshift/auth.sh` that, per adapter, resolves auth **subscription-first** and exposes a clean env to the adapter. Convert the evaluator off the metered Anthropic SDK. Stop hard-requiring API keys.
- Evaluator: replace `evaluate.py`'s `from anthropic import Anthropic` call path with a shell-out to `claude -p --output-format json` (Max credit pool); `ANTHROPIC_API_KEY` **unset** in that context.
- Codex builder: ensure `codex` is authed via Sign-in-with-ChatGPT (not `OPENAI_API_KEY`).
- `init.sh`: stop exiting on missing `OPENAI_API_KEY`/`ANTHROPIC_API_KEY`; instead verify subscription CLIs are logged in (`claude`, `codex`); treat API keys as optional fallback.
- Fallback: when a subscription path returns a rate-limit signal, `auth.sh` may re-enable the metered key for that call (bounded by the $20/day ledger) **only if** `auth.fallback_api=true`.
**Complexity:** Complex
**Dependencies:** Task 2, Task 3
**Acceptance criteria:**
- [ ] Evaluator produces scores via `claude -p` with **no `ANTHROPIC_API_KEY` set** and no metered API call (verify via absence of api.anthropic.com billing / network).
- [ ] `init.sh` passes preflight with subscription CLIs logged in and **no** API keys exported.
- [ ] A simulated subscription rate-limit triggers fallback only when `auth.fallback_api=true`, and the fallback spend is recorded in `state/budget.json`.
- [ ] No 3rd-party auth plugin is used anywhere; only official `claude`/`codex`/`agy` CLIs.
**Test plan:** run an eval with keys unset (assert subscription path); set `fallback_api=false` + force limit (assert halt, no metered call); set true (assert bounded fallback + ledger entry).
**Rollback:** restore API-key requirement in `init.sh`; evaluator falls back to the Anthropic SDK path.
**Blast radius:** Med — touches auth/secrets (a Protected Path); requires explicit approval. Git-checkpoint first; do not commit any key material.
**Research needed:** Yes — confirm current `claude -p` headless billing behavior on Max (sources conflicted) and `codex` ChatGPT-login persistence on a headless box before trusting "zero metered."

### Task 5: Executor-adapter interface + codex adapter
**Objective:** Define `adapters/<name>.sh build --prompt <f> --features <shift.json> --workdir <d>` → mutates workdir, writes `telemetry.json {tokens,cost_usd,auth_path,status}`, returns exit code. `codex.sh` wraps `graveyard.sh` (default) and resolves auth via `auth.sh` (ChatGPT login).
**Complexity:** Complex
**Dependencies:** Task 4
**Acceptance criteria:**
- [ ] `adapters/codex.sh build …` is behavior-identical to direct `graveyard.sh`; emits valid `telemetry.json` including `auth_path` (subscription|fallback).
**Test plan:** diff a real run via shim vs direct — identical commits/metrics; assert `auth_path=subscription`.
**Rollback:** call `graveyard.sh` directly.
**Blast radius:** Low — additive wrapper.
**Research needed:** No

### Task 6: Work queue + dispatcher
**Objective:** `queue/{pending,active,done,failed}/`; `dispatch.sh` flock-guarded pull of oldest pending shift → active → build adapter → done/failed on outcome; per-shift structured log.
**Complexity:** Complex
**Dependencies:** Task 5
**Acceptance criteria:**
- [ ] Two enqueued toy shifts process serially, no double-pull; each lands in done/ or failed/.
**Test plan:** enqueue 2 shifts; assert serial processing + no race.
**Rollback:** stop dispatcher; shifts inert.
**Blast radius:** Low–Med (touches git/PR).
**Research needed:** No

### Task 7: launchd supervisor + caffeinate + crash recovery
**Objective:** `nightshift-supervisor.sh` infinite guarded loop over `dispatch.sh`; SIGTERM trap; `state/checkpoint.json {shift,iteration,attempt,scores}`; resume interrupted active shift on start; wrap in `caffeinate -s`.
**Complexity:** Complex
**Dependencies:** Task 6
**Acceptance criteria:**
- [ ] `kill -9` mid-build → relaunch resumes the active shift from checkpoint, no duplicate commits.
**Test plan:** induce crash mid-build; verify resume.
**Rollback:** run dispatcher one-shot; skip supervisor.
**Blast radius:** Med (always-on) — enable only after Task 8 guardrails.
**Research needed:** No

### Task 8: Budget cap ($20/day) + circuit breaker + rate limiter
**Objective:** Daily + per-run metered-fallback ceilings from config (ledger `state/budget.json`); breaker OPEN on 3 no-progress / 5 repeated errors / any permission-denial / **subscription-pool exhausted**; hourly call cap. OPEN/budget-hit halts dispatch + Telegrams. On subscription exhaustion, halt rather than silently overflow to metered (unless `auth.fallback_api=true`).
**Complexity:** Complex
**Dependencies:** Task 2, Task 7
**Acceptance criteria:**
- [ ] daily_usd=1 test → halt + alert; 3 simulated no-progress → breaker OPEN → dispatch stops.
- [ ] simulated subscription-exhausted signal → breaker OPEN + Telegram (no metered call when `fallback_api=false`).
**Test plan:** force each guardrail; assert halt + notification.
**Rollback:** caps → ∞; breaker disabled.
**Blast radius:** Low — fail-safe only restricts.
**Research needed:** No

### Task 9: Handoff (review) wired into the loop + auto-triage re-queue
**Objective:** After build, run Handoff `/review`; APPROVE→`/pr`; BLOCK/CHANGES→`/triage`→re-enqueue shift with recovery hint appended to prompt; cap 2 recovery cycles then → failed/ + escalate. Reviewers resolve auth subscription-first via `auth.sh` (Claude reviewer = Claude Code subscription; GPT reviewer via `codex`/ChatGPT; Gemini reviewer via `agy` OAuth, mindful of the 200/24h cap).
**Complexity:** Complex
**Dependencies:** Task 6
**Acceptance criteria:**
- [ ] seeded-bug shift → BLOCK → triaged → re-queued once → escalates after 2nd failure.
- [ ] reviewers run via subscription CLIs (no metered API keys) under default config.
**Test plan:** seed known bug; assert review→triage→re-queue→escalation path; assert subscription auth path.
**Rollback:** skip review phase (build→pr direct).
**Blast radius:** Med — controls what merges. Keep human-merge gate ON.
**Research needed:** No

### Task 10: Hypothesis memory + worktree isolation
**Objective:** Append `{shift,task,approach,outcome}` to `state/hypothesis-history.jsonl`; inject last 10 failed approaches into build prompt ("do not repeat"). Build each shift in an auto-created, auto-removed git worktree.
**Complexity:** Complex
**Dependencies:** Task 5
**Acceptance criteria:**
- [ ] repeated failed approach suppressed next prompt; 2 concurrent shifts build in separate worktrees, no collision.
**Test plan:** force repeat approach → verify skipped; run 2 shifts → no cross-contamination.
**Rollback:** disable memory injection; build in-place.
**Blast radius:** Low–Med.
**Research needed:** No

### Task 11: Claude Code adapter
**Objective:** `adapters/claude.sh` to the contract via headless `claude -p --output-format json` inside a worktree with a `settings.json` allowlist (NO `--dangerously-skip-permissions`); auth via `auth.sh` (Max credit pool, `ANTHROPIC_API_KEY` unset). Adapter selectable per-shift (bundle override) or via config default.
**Complexity:** Complex
**Dependencies:** Task 4, Task 10
**Acceptance criteria:**
- [ ] `adapters/claude.sh build` completes a toy shift, commits, writes telemetry (`auth_path=subscription`); per-shift override honored.
**Test plan:** run toy shift via claude adapter; verify commit + telemetry + selection + no metered call.
**Rollback:** route to codex adapter.
**Blast radius:** Low — isolated adapter.
**Research needed:** Yes — confirm headless permission-mode config that avoids the dangerous bypass; confirm Max credit-pool depletion behavior under sustained use.

### Task 12: Antigravity 2.0 adapter (deferred — not installed)
**Objective:** Install Antigravity 2.0, then implement `adapters/antigravity.sh` via the official `agy` CLI with **OAuth (Google AI Ultra)** auth through `auth.sh`. Respect the ~200 req/24h OAuth cap — scope this adapter as a **light-touch reviewer / secondary builder**, not the 24/7 workhorse. Documented `claude.sh` fallback when capped or unavailable. Do **not** use 3rd-party auth plugins (ban risk).
**Complexity:** Complex
**Dependencies:** Task 4, Task 11
**Acceptance criteria:**
- [ ] `antigravity.sh build` completes a toy shift via `agy` OAuth OR logs the documented blocker/cap and falls back to the claude adapter with a passing run.
- [ ] Telemetry records `auth_path` and warns near the 200/24h cap.
**Test plan:** run toy shift via antigravity adapter (or verify documented fallback triggers at the cap).
**Rollback:** route to codex/claude adapter.
**Blast radius:** Low — isolated adapter; everything else agnostic.
**Research needed:** Yes — Antigravity not present on this machine as of 2026-06-14; requires install + `agy` headless OAuth persistence discovery.

### Task 13: Dashboard repoint + Telegram notifier
**Objective:** Point the Graveyard Next.js dashboard at `state/` (queue depth, active shift, budget ledger, breaker status, **per-provider subscription headroom**); guaranteed Telegram (id 5611660528) on review BLOCK, budget-hit, subscription-exhausted, shift-complete.
**Complexity:** Moderate
**Dependencies:** Task 7
**Acceptance criteria:**
- [ ] dashboard renders live always-on state incl. subscription headroom; each event delivers a Telegram message.
**Test plan:** trigger each event; confirm UI + message.
**Rollback:** UI reads single-project metrics as today; notifier optional.
**Blast radius:** Low — read-only + outbound.
**Research needed:** No

### Task 14: launchd plist + RUNBOOK
**Objective:** `~/Library/LaunchAgents/ai.nightshift.supervisor.plist` (`Label ai.nightshift.supervisor`, `RunAtLoad`, `KeepAlive`, ProgramArguments → `nightshift-supervisor.sh`, StdOut/Err → `state/supervisor.log`). `nightshift/RUNBOOK.md` documents load/unload/status/kill-switch + the subscription-login bootstrap (`claude setup-token`, `codex` ChatGPT login, `agy` OAuth).
**Complexity:** Simple
**Dependencies:** Task 7
**Acceptance criteria:**
- [ ] `launchctl load` brings supervisor up at login; `KeepAlive` restarts after kill; RUNBOOK documents lifecycle + subscription bootstrap.
**Test plan:** load plist; kill supervisor; confirm restart.
**Rollback:** `launchctl unload`.
**Blast radius:** Med (lifecycle) — guard with Task 8 before enabling.
**Research needed:** No

---

## Critical path & sequencing

MVP (Codex-only always-on, subscription-first, with guardrails): **T1 → T2 → T3 → T4 (auth) → T5 → T6 → T7 → T8 → T9**.
Hardening/extension: T10 (memory+worktrees), T11 (claude adapter), T13 (dashboard/Telegram), T14 (plist).
**T12 (Antigravity) last** — gated on installing Antigravity 2.0; never on the always-on path.

## Rollback (whole system)
`launchctl unload` stops always-on instantly. Queue + brief/graveyard/handoff repos are renamed copies
of the originals — revert via git. No destructive change; every stage git-checkpointed before edits.
Auth layer (T4) touches a Protected Path (secrets) — requires explicit approval and never commits keys.
