#!/bin/bash
set -euo pipefail

HOSTS_FILE="$1"          # fichier hosts
PHASE="$2"               # before | after
OUTDIR="./results"
DATE="$(date +%Y%m%d_%H%M%S)"

API_USER="admin"
API_PASS="password"
API_PORT=443

mkdir -p "$OUTDIR"

#######################################
# Curl helper
#######################################
curl_api() {
    local HOST="$1"
    local URI="$2"

    curl -sk -u "$API_USER:$API_PASS" \
        "https://${HOST}:${API_PORT}${URI}"
}

#######################################
# Check one BIG-IP
#######################################
check_host() {
    local HOST="$1"
    local OUTFILE="$OUTDIR/${HOST}_${PHASE}_${DATE}.txt"

    {
        echo "========================================"
        echo "HOST  : $HOST"
        echo "PHASE : $PHASE"
        echo "DATE  : $(date)"
        echo "========================================"
        echo

        ############################
        # AFM
        ############################
        echo "### AFM POLICIES"
        AFM_JSON=$(curl_api "$HOST" "/mgmt/tm/security/firewall/policy")

        echo "$AFM_JSON" | jq -r '.items[].name' 2>/dev/null || echo "N/A"
        echo "AFM_POLICY_COUNT: $(echo "$AFM_JSON" | jq '.items | length' 2>/dev/null || echo 0)"
        echo

        ############################
        # ASM
        ############################
        echo "### ASM POLICIES"
        ASM_JSON=$(curl_api "$HOST" "/mgmt/tm/asm/policies")

        echo "$ASM_JSON" | jq -r '.items[].name' 2>/dev/null || echo "N/A"
        echo "ASM_POLICY_COUNT: $(echo "$ASM_JSON" | jq '.items | length' 2>/dev/null || echo 0)"
        echo

        ############################
        # WIDEIP
        ############################
        echo "### WIDEIP STATUS"
        WIDEIP_JSON=$(curl_api "$HOST" "/mgmt/tm/gtm/wideip/a")

        echo "$WIDEIP_JSON" | jq -r '
            .items[] |
            "\(.name) - \(.status.availabilityState)"
        ' 2>/dev/null || echo "N/A"

        echo "WIDEIP_TOTAL: $(echo "$WIDEIP_JSON" | jq '.items | length' 2>/dev/null || echo 0)"
        echo "WIDEIP_AVAILABLE: $(echo "$WIDEIP_JSON" | jq '[.items[] | select(.status.availabilityState=="available")] | length' 2>/dev/null || echo 0)"
        echo "WIDEIP_OFFLINE: $(echo "$WIDEIP_JSON" | jq '[.items[] | select(.status.availabilityState!="available")] | length' 2>/dev/null || echo 0)"
        echo

        ############################
        # VIRTUAL SERVERS (STATS)
        ############################
        echo "### VIRTUAL SERVERS STATUS"

        VS_LIST=$(curl_api "$HOST" "/mgmt/tm/ltm/virtual?\$select=name,partition,subPath")

        VS_TOTAL=0
        VS_AVAILABLE=0
        VS_OFFLINE=0

        echo "$VS_LIST" | jq -c '.items[]' | while read -r VS; do
            PARTITION=$(echo "$VS" | jq -r '.partition')
            NAME=$(echo "$VS" | jq -r '.name')
            SUBPATH=$(echo "$VS" | jq -r '.subPath // empty')

            if [[ -n "$SUBPATH" ]]; then
                URI="/mgmt/tm/ltm/virtual/~${PARTITION}~${SUBPATH}~${NAME}/stats"
                FULLNAME="${PARTITION}/${SUBPATH}/${NAME}"
            else
                URI="/mgmt/tm/ltm/virtual/~${PARTITION}~${NAME}/stats"
                FULLNAME="${PARTITION}/${NAME}"
            fi

            STATS=$(curl_api "$HOST" "$URI")

            AVAIL=$(echo "$STATS" | jq -r '
                .entries[].nestedStats.entries.status.entries.availabilityState.description
            ' 2>/dev/null || echo "unknown")

            echo "$FULLNAME - $AVAIL"

            ((VS_TOTAL++))
            if [[ "$AVAIL" == "available" ]]; then
                ((VS_AVAILABLE++))
            else
                ((VS_OFFLINE++))
            fi
        done

        echo
        echo "VS_TOTAL: $VS_TOTAL"
        echo "VS_AVAILABLE: $VS_AVAILABLE"
        echo "VS_OFFLINE: $VS_OFFLINE"

    } > "$OUTFILE" 2>&1
}

#######################################
# MAIN LOOP
#######################################
while IFS= read -r HOST; do
    [[ -z "$HOST" ]] && continue
    echo ">>> Checking $HOST"
    check_host "$HOST"
done < "$HOSTS_FILE"

echo
echo "✔ Checks completed"
echo "Results in: $OUTDIR"