#!/bin/bash
# =============================================================================
# karpathy-loop.sh — The Ratchet
# =============================================================================
# Faithful adaptation of Karpathy's autoresearch loop for general coding tasks.
# Like autoresearch: branch → edit → commit → evaluate → keep or reset → repeat.
#
# The AI agent calls this script to enforce the ratchet mechanically.
# The agent decides WHAT to try. This script decides WHETHER to keep it.
#
# Usage (called by the AI agent, not by humans directly):
#   bash .claude/scripts/karpathy-loop.sh \
#     --action evaluate \
#     --description "switched to connection pooling" \
#     --test "npm run test" \
#     --build "npm run build"
#
#   bash .claude/scripts/karpathy-loop.sh --action setup --tag "auth-oauth2"
#   bash .claude/scripts/karpathy-loop.sh --action status
#   bash .claude/scripts/karpathy-loop.sh --action abort
#
# Actions:
#   setup     — Create experiment branch, initialize results.tsv, record baseline
#   evaluate  — Run evaluation, keep or discard based on ratchet
#   status    — Print current best score and iteration count
#   abort     — Return to the branch we started from
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_FILE="results.tsv"

# --- Argument Parsing ---
ACTION=""
TAG=""
DESCRIPTION=""
TEST_CMD=""
BUILD_CMD=""
LINT_CMD=""
TYPECHECK_CMD=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --action)      ACTION="$2"; shift 2 ;;
        --tag)         TAG="$2"; shift 2 ;;
        --description) DESCRIPTION="$2"; shift 2 ;;
        --test)        TEST_CMD="$2"; shift 2 ;;
        --build)       BUILD_CMD="$2"; shift 2 ;;
        --lint)        LINT_CMD="$2"; shift 2 ;;
        --typecheck)   TYPECHECK_CMD="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: karpathy-loop.sh --action <setup|evaluate|status|abort> [OPTIONS]"
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [ -z "$ACTION" ]; then
    echo "Error: --action is required (setup|evaluate|status|abort)" >&2
    exit 1
fi

# --- Helpers ---
timestamp() { date '+%Y-%m-%dT%H:%M:%S'; }
short_hash() { git rev-parse --short HEAD 2>/dev/null || echo "0000000"; }

get_best_score() {
    if [ ! -f "$RESULTS_FILE" ]; then
        echo "0"
        return
    fi
    # Get the highest score from kept experiments
    awk -F'\t' '$4 == "keep" { if ($2 > max) max = $2 } END { print (max ? max : 0) }' "$RESULTS_FILE"
}

get_iteration_count() {
    if [ ! -f "$RESULTS_FILE" ]; then
        echo "0"
        return
    fi
    # Count non-header lines
    tail -n +2 "$RESULTS_FILE" | wc -l | tr -d ' '
}

build_eval_args() {
    local args=""
    [ -n "$TEST_CMD" ]      && args="$args --test \"$TEST_CMD\""
    [ -n "$BUILD_CMD" ]     && args="$args --build \"$BUILD_CMD\""
    [ -n "$LINT_CMD" ]      && args="$args --lint \"$LINT_CMD\""
    [ -n "$TYPECHECK_CMD" ] && args="$args --typecheck \"$TYPECHECK_CMD\""
    echo "$args"
}

# =============================================================================
# ACTION: setup
# =============================================================================
if [ "$ACTION" = "setup" ]; then
    if [ -z "$TAG" ]; then
        TAG="$(date +%b%d | tr '[:upper:]' '[:lower:]')"
    fi

    BRANCH="experiment/${TAG}"

    # Check branch doesn't already exist
    if git rev-parse --verify "$BRANCH" > /dev/null 2>&1; then
        echo "Error: Branch $BRANCH already exists. Use a different tag." >&2
        exit 1
    fi

    # Create branch
    git checkout -b "$BRANCH"

    # Initialize results.tsv
    echo -e "commit\tscore\tstatus\ttimestamp\tdescription" > "$RESULTS_FILE"

    # Record baseline score
    EVAL_ARGS=$(build_eval_args)
    BASELINE_SCORE=$(eval "bash \"$SCRIPT_DIR/evaluate-task.sh\" $EVAL_ARGS" 2>/dev/null || echo "0")
    COMMIT=$(short_hash)

    echo -e "${COMMIT}\t${BASELINE_SCORE}\tbaseline\t$(timestamp)\tinitial baseline" >> "$RESULTS_FILE"

    echo "=== Karpathy Loop Setup ===" >&2
    echo "Branch: $BRANCH" >&2
    echo "Baseline score: ${BASELINE_SCORE}/100" >&2
    echo "Results log: $RESULTS_FILE" >&2
    echo "===========================" >&2

    # Output for the agent
    echo "$BASELINE_SCORE"

# =============================================================================
# ACTION: evaluate
# =============================================================================
elif [ "$ACTION" = "evaluate" ]; then
    if [ -z "$DESCRIPTION" ]; then
        DESCRIPTION="unnamed experiment"
    fi

    BEST_SCORE=$(get_best_score)
    COMMIT=$(short_hash)
    ITERATION=$(get_iteration_count)

    # Run the evaluation harness
    EVAL_ARGS=$(build_eval_args)
    SCORE=$(eval "bash \"$SCRIPT_DIR/evaluate-task.sh\" $EVAL_ARGS" 2>/dev/null || echo "0")

    echo "=== Experiment #$((ITERATION + 1)) ===" >&2
    echo "Description: $DESCRIPTION" >&2
    echo "Score: ${SCORE}/100 (best: ${BEST_SCORE}/100)" >&2

    # --- The Ratchet ---
    if [ "$SCORE" -gt "$BEST_SCORE" ]; then
        # IMPROVED — keep the commit, advance the branch
        echo -e "${COMMIT}\t${SCORE}\tkeep\t$(timestamp)\t${DESCRIPTION}" >> "$RESULTS_FILE"
        echo "Decision: KEEP (${SCORE} > ${BEST_SCORE})" >&2
        echo "===========================" >&2
        echo "KEEP:${SCORE}"
    elif [ "$SCORE" -eq "$BEST_SCORE" ] && [ "$SCORE" -gt 0 ]; then
        # EQUAL — discard (Karpathy: equal or worse = discard)
        # But if score is 100, keep anyway (can't improve further)
        if [ "$SCORE" -eq 100 ]; then
            echo -e "${COMMIT}\t${SCORE}\tkeep\t$(timestamp)\t${DESCRIPTION}" >> "$RESULTS_FILE"
            echo "Decision: KEEP (perfect score)" >&2
            echo "===========================" >&2
            echo "KEEP:${SCORE}"
        else
            echo -e "${COMMIT}\t${SCORE}\tdiscard\t$(timestamp)\t${DESCRIPTION}" >> "$RESULTS_FILE"
            git reset --hard HEAD~1 2>/dev/null || true
            echo "Decision: DISCARD (${SCORE} = ${BEST_SCORE}, not improved)" >&2
            echo "===========================" >&2
            echo "DISCARD:${SCORE}"
        fi
    else
        # WORSE — discard, reset to previous commit
        echo -e "${COMMIT}\t${SCORE}\tdiscard\t$(timestamp)\t${DESCRIPTION}" >> "$RESULTS_FILE"
        git reset --hard HEAD~1 2>/dev/null || true
        echo "Decision: DISCARD (${SCORE} < ${BEST_SCORE})" >&2
        echo "===========================" >&2
        echo "DISCARD:${SCORE}"
    fi

# =============================================================================
# ACTION: status
# =============================================================================
elif [ "$ACTION" = "status" ]; then
    BEST=$(get_best_score)
    COUNT=$(get_iteration_count)
    BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")

    echo "=== Karpathy Loop Status ==="
    echo "Branch: $BRANCH"
    echo "Best score: ${BEST}/100"
    echo "Iterations: $COUNT"
    if [ -f "$RESULTS_FILE" ]; then
        echo ""
        echo "Recent experiments:"
        tail -5 "$RESULTS_FILE" | column -t -s$'\t'
    fi
    echo "============================="

# =============================================================================
# ACTION: abort
# =============================================================================
elif [ "$ACTION" = "abort" ]; then
    # Find the parent branch (where we branched from)
    CURRENT=$(git branch --show-current 2>/dev/null || echo "")
    if [[ "$CURRENT" == experiment/* ]]; then
        echo "Aborting experiment on $CURRENT" >&2
        echo "Results preserved in $RESULTS_FILE" >&2
        git checkout - 2>/dev/null || git checkout main 2>/dev/null
        echo "Returned to $(git branch --show-current)"
    else
        echo "Not on an experiment branch. Nothing to abort." >&2
    fi

else
    echo "Error: Unknown action '$ACTION'. Use: setup, evaluate, status, abort" >&2
    exit 1
fi
