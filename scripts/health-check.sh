#!/bin/bash

# Health check script for Stellar Horizon
# Returns 0 if healthy, 1 if unhealthy

HORIZON_URL="${HORIZON_URL:-http://localhost:8000}"
TIMEOUT="${TIMEOUT:-5}"

# Function to check Horizon health
check_horizon() {
    local response
    response=$(curl -s -w "\n%{http_code}" --connect-timeout "$TIMEOUT" "$HORIZON_URL/health" 2>/dev/null)
    local http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        echo "✓ Horizon is healthy"
        return 0
    else
        echo "✗ Horizon is unhealthy (HTTP $http_code)"
        return 1
    fi
}

# Function to check if Horizon is synced
check_sync() {
    local response
    response=$(curl -s --connect-timeout "$TIMEOUT" "$HORIZON_URL" 2>/dev/null)
    
    if [ -z "$response" ]; then
        echo "✗ Cannot connect to Horizon"
        return 1
    fi
    
    local history_latest_ledger=$(echo "$response" | grep -o '"history_latest_ledger":[0-9]*' | cut -d: -f2)
    local core_latest_ledger=$(echo "$response" | grep -o '"core_latest_ledger":[0-9]*' | cut -d: -f2)
    
    if [ -z "$history_latest_ledger" ] || [ -z "$core_latest_ledger" ]; then
        echo "✗ Cannot determine sync status"
        return 1
    fi
    
    local lag=$((core_latest_ledger - history_latest_ledger))
    
    if [ "$lag" -le 1 ]; then
        echo "✓ Horizon is synced (history: $history_latest_ledger, core: $core_latest_ledger)"
        return 0
    else
        echo "⚠ Horizon is catching up (lag: $lag ledgers)"
        return 0  # Still healthy, just catching up
    fi
}

# Main health check
main() {
    echo "Checking Horizon health..."
    
    if ! check_horizon; then
        exit 1
    fi
    
    if ! check_sync; then
        exit 1
    fi
    
    echo "✓ All health checks passed"
    exit 0
}

main