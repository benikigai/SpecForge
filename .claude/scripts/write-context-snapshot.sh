#!/bin/bash
# =============================================================================
# write-context-snapshot.sh — Persist a markdown context snapshot for handoffs
# =============================================================================
# Usage:
#   bash .claude/scripts/write-context-snapshot.sh \
#     --feature auth-oauth \
#     --title "OAuth Authentication" \
#     --phase "Spec approved" \
#     --status "waiting for execution" \
#     --summary "Approved Option B with 4 tasks"
#
# Optional repeated flags:
#   --section "Heading::Body text"
# =============================================================================

set -euo pipefail

FEATURE=""
TITLE=""
PHASE=""
STATUS=""
SUMMARY=""
OUTPUT_DIR="docs/specs"
SECTIONS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --feature) FEATURE="$2"; shift 2 ;;
        --title) TITLE="$2"; shift 2 ;;
        --phase) PHASE="$2"; shift 2 ;;
        --status) STATUS="$2"; shift 2 ;;
        --summary) SUMMARY="$2"; shift 2 ;;
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        --section) SECTIONS+=("$2"); shift 2 ;;
        --help|-h)
            echo "Usage: write-context-snapshot.sh --feature <slug> --title <title> --phase <phase> --status <status> [--summary <text>] [--section 'Heading::Body']"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$FEATURE" || -z "$TITLE" || -z "$PHASE" || -z "$STATUS" ]]; then
    echo "Missing required arguments. Need --feature, --title, --phase, and --status." >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

TIMESTAMP="$(date -u +"%Y-%m-%d %H:%M UTC")"
OUT_FILE="${OUTPUT_DIR}/${FEATURE}-context.md"

{
    echo "# Context: ${TITLE}"
    echo "**Last updated:** ${TIMESTAMP}"
    echo "**Current phase:** ${PHASE}"
    echo "**Status:** ${STATUS}"
    if [[ -n "$SUMMARY" ]]; then
        echo "**Summary:** ${SUMMARY}"
    fi
    echo
    for section in "${SECTIONS[@]}"; do
        HEADING="${section%%::*}"
        BODY="${section#*::}"
        echo "## ${HEADING}"
        echo "${BODY}"
        echo
    done
} > "$OUT_FILE"

echo "$OUT_FILE"
