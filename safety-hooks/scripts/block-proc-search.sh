#!/bin/bash
# Block grep/search/find commands that target virtual filesystems (/proc, /sys, /dev)
# These can cause infinite reads and pin CPU for hours.

ALLOW='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'

input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // empty')

if [ -z "$cmd" ]; then
  echo "$ALLOW"
  exit 0
fi

if echo "$cmd" | grep -qP '(grep|ugrep|rg|ag|find|fd)\b.*\s/proc\b'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Blocked: search command targeting /proc — virtual filesystems can cause infinite reads. Search project directories instead."}}'
  exit 0
fi

if echo "$cmd" | grep -qP '(grep|ugrep|rg|ag|find|fd)\b.*\s/sys\b'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Blocked: search command targeting /sys — virtual filesystems can cause infinite reads. Search project directories instead."}}'
  exit 0
fi

if echo "$cmd" | grep -qP '(grep|ugrep|rg|ag|find|fd)\b.*\s/dev\b'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Blocked: search command targeting /dev — virtual filesystems can cause infinite reads. Search project directories instead."}}'
  exit 0
fi

echo "$ALLOW"
