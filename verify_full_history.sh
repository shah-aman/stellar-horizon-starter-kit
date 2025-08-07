#!/bin/bash

echo "🔍 Verifying Full History Sync Configuration..."
echo "================================================"

# Check environment configuration
echo "1. Checking HISTORY_RETENTION_COUNT..."
RETENTION=$(docker compose exec horizon env 2>/dev/null | grep HISTORY_RETENTION_COUNT | cut -d'=' -f2)
if [ "$RETENTION" = "0" ]; then
    echo "   ✅ HISTORY_RETENTION_COUNT=0 (Full History)"
elif [ "$RETENTION" = "518400" ]; then
    echo "   ❌ HISTORY_RETENTION_COUNT=518400 (30-day retention)"
    echo "   ⚠️  WARNING: You're NOT syncing full history!"
else
    echo "   ⚠️  HISTORY_RETENTION_COUNT=$RETENTION (Unknown setting)"
fi

# Check database for historical data
echo ""
echo "2. Checking database for historical data..."
MIN_LEDGER=$(docker compose exec -T db psql -U horizon -d horizon -c "SELECT MIN(sequence) FROM history_ledgers;" 2>/dev/null | grep -E '^[[:space:]]*[0-9]+[[:space:]]*$' | tr -d ' ')

if [ -n "$MIN_LEDGER" ] && [ "$MIN_LEDGER" -lt 1000 ]; then
    echo "   ✅ Earliest ledger: $MIN_LEDGER (Full History)"
elif [ -n "$MIN_LEDGER" ]; then
    echo "   ❌ Earliest ledger: $MIN_LEDGER (Recent data only)"
    echo "   ⚠️  This suggests 30-day retention, not full history"
else
    echo "   ⏳ Database not ready or no data yet"
fi

# Check total ledger count
TOTAL_LEDGERS=$(docker compose exec -T db psql -U horizon -d horizon -c "SELECT COUNT(*) FROM history_ledgers;" 2>/dev/null | grep -E '^[[:space:]]*[0-9]+[[:space:]]*$' | tr -d ' ')
if [ -n "$TOTAL_LEDGERS" ]; then
    echo "   📊 Total ledgers in database: $TOTAL_LEDGERS"
    if [ "$TOTAL_LEDGERS" -lt 600000 ]; then
        echo "   ⏳ Still syncing (full history will have 56M+ ledgers)"
    fi
fi

# Test API for old data
echo ""
echo "3. Testing API for historical data..."
OLD_LEDGER=$(curl -s "http://localhost:8000/ledgers/100" 2>/dev/null | jq -r '.sequence // "null"')
if [ "$OLD_LEDGER" = "100" ]; then
    echo "   ✅ Can access ledger 100 (Full History working)"
elif [ "$OLD_LEDGER" = "null" ]; then
    echo "   ❌ Cannot access ledger 100 (Likely 30-day retention)"
else
    echo "   ⏳ API not ready yet"
fi

# Check sync logs
echo ""
echo "4. Checking recent sync activity..."
if docker compose logs horizon | grep -q "checkpoint catchup"; then
    echo "   ✅ Checkpoint catchup detected (Full history sync)"
elif docker compose logs horizon | grep -q "ingestion"; then
    echo "   ⏳ Ingestion active (sync in progress)"
else
    echo "   ⚠️  No clear sync activity in logs"
fi

echo ""
echo "🎯 SUMMARY:"
if [ "$RETENTION" = "0" ] && [ -n "$MIN_LEDGER" ] && [ "$MIN_LEDGER" -lt 1000 ]; then
    echo "   ✅ CONFIRMED: Full History Sync is active!"
elif [ "$RETENTION" = "0" ]; then
    echo "   ⏳ Full History configured but sync just started"
else
    echo "   ❌ WARNING: NOT configured for Full History!"
    echo "   📝 Run: cp full-history.env .env"
    echo "   📝 Then: make down && make clean && make init && make up"
fi 