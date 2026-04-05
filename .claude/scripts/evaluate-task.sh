#!/bin/bash
# =============================================================================
# evaluate-task.sh — Scalar Metric Evaluator for Karpathy Loop
# =============================================================================
# The fixed evaluation harness. Like Karpathy's prepare.py, this file is
# NEVER modified by the agent. It computes a single score (0-100) from
# objective, machine-checkable criteria.
#
# Usage:
#   bash .claude/scripts/evaluate-task.sh --test "npm run test" --build "npm run build" --lint "npm run lint"
#   bash .claude/scripts/evaluate-task.sh --test "pytest tests/" --build "python -m py_compile src/*.py"
#   bash .claude/scripts/evaluate-task.sh --test "cargo test" --build "cargo build" --lint "cargo clippy"
#
# Returns: prints a single integer 0-100 to stdout (the scalar metric)
# Also prints breakdown to stderr for logging
# =============================================================================

set -uo pipefail

# --- Argument Parsing ---
TEST_CMD=""
BUILD_CMD=""
LINT_CMD=""
TYPECHECK_CMD=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --test)      TEST_CMD="$2"; shift 2 ;;
        --build)     BUILD_CMD="$2"; shift 2 ;;
        --lint)      LINT_CMD="$2"; shift 2 ;;
        --typecheck) TYPECHECK_CMD="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: evaluate-task.sh [--test CMD] [--build CMD] [--lint CMD] [--typecheck CMD]"
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# --- Scoring ---
# Weights (must sum to 100):
#   Tests:     40 points (the primary signal — does it work?)
#   Build:     30 points (does it compile/not crash?)
#   Lint:      15 points (is it clean?)
#   Typecheck: 15 points (are types correct?)
# If a command is not provided, its points are redistributed proportionally.

SCORE=0
MAX_POSSIBLE=0
BREAKDOWN=""

run_gate() {
    local name="$1"
    local cmd="$2"
    local points="$3"

    if [ -z "$cmd" ]; then
        # No command provided — skip this gate
        return 0
    fi

    MAX_POSSIBLE=$((MAX_POSSIBLE + points))

    if eval "$cmd" > /dev/null 2>&1; then
        SCORE=$((SCORE + points))
        BREAKDOWN="${BREAKDOWN}  ${name}: PASS (+${points})\n"
        return 0
    else
        BREAKDOWN="${BREAKDOWN}  ${name}: FAIL (+0)\n"
        return 1
    fi
}

run_gate "tests"     "$TEST_CMD"      40
run_gate "build"     "$BUILD_CMD"     30
run_gate "lint"      "$LINT_CMD"      15
run_gate "typecheck" "$TYPECHECK_CMD" 15

# --- Normalize to 0-100 ---
if [ "$MAX_POSSIBLE" -gt 0 ]; then
    NORMALIZED=$(( (SCORE * 100) / MAX_POSSIBLE ))
else
    # No gates configured — everything passes vacuously
    NORMALIZED=100
fi

# --- Output ---
# Score to stdout (machine-readable)
echo "$NORMALIZED"

# Breakdown to stderr (human-readable, for logging)
echo -e "--- Evaluation ---" >&2
echo -e "$BREAKDOWN" >&2
echo -e "  Raw: ${SCORE}/${MAX_POSSIBLE}" >&2
echo -e "  Normalized: ${NORMALIZED}/100" >&2
echo -e "------------------" >&2
