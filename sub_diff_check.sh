#!/bin/bash
set -euo pipefail

BEFORE_DIR="$1"
AFTER_DIR="$2"

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
NC="\e[0m"

extract_summary() {
    sed -n '/^===== SUMMARY =====/,/^===== END SUMMARY =====/p' "$1"
}

echo
echo "===== SUMMARY DIFF REPORT ====="
echo

for BEFORE_FILE in "$BEFORE_DIR"/*_BEFORE.txt; do
    HOST=$(basename "$BEFORE_FILE" | sed 's/_BEFORE.txt//')
    AFTER_FILE="$AFTER_DIR/${HOST}_AFTER.txt"

    if [[ ! -f "$AFTER_FILE" ]]; then
        echo -e "${YELLOW}⚠ $HOST : AFTER file missing${NC}"
        continue
    fi

    BEFORE_SUMMARY=$(mktemp)
    AFTER_SUMMARY=$(mktemp)

    extract_summary "$BEFORE_FILE" > "$BEFORE_SUMMARY"
    extract_summary "$AFTER_FILE"  > "$AFTER_SUMMARY"

    if diff -u "$BEFORE_SUMMARY" "$AFTER_SUMMARY" > /dev/null; then
        echo -e "${GREEN}✔ $HOST : no change${NC}"
    else
        echo -e "${RED}✖ $HOST : differences detected${NC}"
        diff -u "$BEFORE_SUMMARY" "$AFTER_SUMMARY"
        echo
    fi

    rm -f "$BEFORE_SUMMARY" "$AFTER_SUMMARY"
done