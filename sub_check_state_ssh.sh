#!/bin/bash

sshpass -e ssh "$HOST" "tmsh load sys config verify" 2>&1 \
| tee "$LOGFILE" \
| awk '
    /^Error:/ { print; next }
    /^there were warnings:/ { inwarn=1; next }
    inwarn { print }
'

RESULT=$(sshpass -e ssh "$HOST" "tmsh load sys config verify" 2>&1 | tee "$LOGFILE")

if echo "$RESULT" | grep -q '^Error:'; then
    echo "❌ Verification FAILED"
elif echo "$RESULT" | grep -q '^there were warnings:'; then
    echo "⚠ Verification OK with warnings"
else
    echo "✔ Verification OK"
fi