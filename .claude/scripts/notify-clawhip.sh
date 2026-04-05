#!/bin/bash
# =============================================================================
# notify-clawhip.sh — SpecForge lifecycle notifications via Clawhip agent events
# =============================================================================
# Usage:
#   bash .claude/scripts/notify-clawhip.sh started  --session feature-slug --summary "spec approved"
#   bash .claude/scripts/notify-clawhip.sh finished --session feature-slug --summary "PR ready: <url>" --elapsed 420
#   bash .claude/scripts/notify-clawhip.sh failed   --session feature-slug --error "review blocked"
# =============================================================================

set -euo pipefail

STATE="${1:-}"
if [[ -z "$STATE" ]]; then
    echo "Usage: notify-clawhip.sh <started|blocked|finished|failed> [options]" >&2
    exit 1
fi
shift

NAME="${SPECFORGE_NOTIFY_NAME:-specforge-autopilot}"
PROJECT="${SPECFORGE_NOTIFY_PROJECT:-SpecForge}"
SESSION=""
SUMMARY=""
ERROR_MESSAGE=""
ELAPSED=""
CHANNEL=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name) NAME="$2"; shift 2 ;;
        --project) PROJECT="$2"; shift 2 ;;
        --session) SESSION="$2"; shift 2 ;;
        --summary) SUMMARY="$2"; shift 2 ;;
        --error) ERROR_MESSAGE="$2"; shift 2 ;;
        --elapsed) ELAPSED="$2"; shift 2 ;;
        --channel) CHANNEL="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: notify-clawhip.sh <started|blocked|finished|failed> [--session ID] [--summary TEXT] [--error TEXT] [--elapsed SECS] [--channel CHANNEL_ID]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

CLAW="${CLAWHIP_BIN:-}"
if [[ -z "$CLAW" ]]; then
    if command -v clawhip >/dev/null 2>&1; then
        CLAW="$(command -v clawhip)"
    elif [[ -x "$HOME/.cargo/bin/clawhip" ]]; then
        CLAW="$HOME/.cargo/bin/clawhip"
    else
        echo "clawhip binary not found on PATH or at \$HOME/.cargo/bin/clawhip" >&2
        exit 1
    fi
fi

ARGS=(agent "$STATE" --name "$NAME" --project "$PROJECT")
if [[ -n "$SESSION" ]]; then
    ARGS+=(--session "$SESSION")
fi
if [[ -n "$SUMMARY" ]]; then
    ARGS+=(--summary "$SUMMARY")
fi
if [[ -n "$ELAPSED" ]]; then
    ARGS+=(--elapsed "$ELAPSED")
fi
if [[ -n "$CHANNEL" ]]; then
    ARGS+=(--channel "$CHANNEL")
fi
if [[ "$STATE" == "failed" ]]; then
    if [[ -z "$ERROR_MESSAGE" ]]; then
        echo "--error is required for failed notifications" >&2
        exit 1
    fi
    ARGS+=(--error "$ERROR_MESSAGE")
fi

exec "$CLAW" "${ARGS[@]}"
