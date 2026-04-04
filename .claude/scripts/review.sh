#!/bin/bash
# =============================================================================
# External Code Review via Gemini API
# =============================================================================
# Called by /yolo after each task for an independent second opinion.
# Opus reads the stdout and acts on the feedback.
#
# Setup:
#   1. Export your API key: export GEMINI_API_KEY="your-key-here"
#   2. Make executable: chmod +x .claude/scripts/review.sh
#   3. Adjust the model name below for your preferred provider.
# =============================================================================

set -euo pipefail

# --- Configuration ---
REVIEWER_MODEL="${REVIEWER_MODEL:-gemini-2.5-flash}"
API_KEY="${GEMINI_API_KEY:-}"

if [ -z "$API_KEY" ]; then
  echo "[REVIEW SKIPPED] No GEMINI_API_KEY set. Export it to enable external review."
  exit 0
fi

# --- Capture the diff ---
DIFF=$(git diff HEAD 2>/dev/null || echo "No diff available")

if [ -z "$DIFF" ] || [ "$DIFF" = "No diff available" ]; then
  echo "[REVIEW SKIPPED] No changes to review."
  exit 0
fi

# Truncate very large diffs to avoid API limits
DIFF_TRUNCATED=$(echo "$DIFF" | head -c 30000)
if [ ${#DIFF} -gt 30000 ]; then
  DIFF_TRUNCATED="${DIFF_TRUNCATED}

... [TRUNCATED — diff exceeds 30KB. Review covers first 30KB only.]"
fi

# --- Optional: include spec context ---
SPEC_FILE="${1:-}"
SPEC_CONTEXT=""
if [ -n "$SPEC_FILE" ] && [ -f "$SPEC_FILE" ]; then
  SPEC_CONTEXT="

SPEC CONTEXT (the approved plan this diff implements):
$(head -c 5000 "$SPEC_FILE")"
fi

# --- Build the prompt ---
REVIEW_PROMPT="You are a Senior Code Reviewer. Review this diff for:

1. CORRECTNESS: Does it do what the spec says? Logic errors? Missing edge cases?
2. REGRESSION RISK: Could this break existing functionality?
3. SECURITY: Input validation, injection risks, auth issues, secrets in code?
4. MAINTAINABILITY: Unnecessary complexity? Code that will be hard to change later?

Score each category: PASS or FAIL with specific issues.

If ALL categories PASS, end your response with exactly: [APPROVED]
If ANY category FAILS, list specific issues with file:line references and end with: [REJECTED]
${SPEC_CONTEXT}

DIFF:
${DIFF_TRUNCATED}"

# --- Call the Gemini API ---
RESPONSE=$(curl -s --max-time 60 -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/${REVIEWER_MODEL}:generateContent?key=${API_KEY}" \
  -H 'Content-Type: application/json' \
  -d "$(python3 -c "
import json, sys
prompt = sys.stdin.read()
print(json.dumps({
    'contents': [{'parts': [{'text': prompt}]}],
    'generationConfig': {'temperature': 0.2, 'maxOutputTokens': 2048}
}))
" <<< "$REVIEW_PROMPT")" 2>/dev/null)

# --- Parse and output ---
if [ -z "$RESPONSE" ]; then
  echo "[REVIEW ERROR] No response from API. Check your API key and network."
  exit 1
fi

REVIEW_TEXT=$(python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    text = data.get('candidates', [{}])[0].get('content', {}).get('parts', [{}])[0].get('text', '')
    print(text if text else '[REVIEW ERROR] Empty response from API')
except Exception as e:
    print(f'[REVIEW ERROR] Failed to parse API response: {e}')
" <<< "$RESPONSE" 2>/dev/null)

echo "==========================================="
echo "  EXTERNAL REVIEW (${REVIEWER_MODEL})"
echo "==========================================="
echo "$REVIEW_TEXT"
echo "==========================================="
