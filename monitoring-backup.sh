#!/bin/bash
# Stellar Horizon Monitoring and Backup Script
# Provides monitoring, alerting, and backup functionality

set -e

# Configuration
BACKUP_DIR="/data/postgres/backups"
LOG_FILE="/var/log/horizon-monitor.log"
ALERT_EMAIL=""  # Set this to receive alerts
TELEGRAM_BOT_TOKEN=""  # Optional: Telegram bot for alerts
TELEGRAM_CHAT_ID=""

# Thresholds
DISK_THRESHOLD=85  # Alert when disk usage exceeds this percentage
LAG_THRESHOLD=10   # Alert when ledger lag exceeds this number
MEMORY_THRESHOLD=90  # Alert when memory usage exceeds this percentage

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Alert function
send_alert() {
    local message="$1"
    local severity="$2"
    
    log "ALERT [$severity]: $message"
    
    # Send email alert if configured
    if [ ! -z "$ALERT_EMAIL" ]; then
        echo "$message" | mail -s "Stellar Horizon Alert [$severity]" "$ALERT_EMAIL" 2>/dev/null || true
    fi
    
    # Send Telegram alert if configured
    if [ ! -z "$TELEGRAM_BOT_TOKEN" ] && [ ! -z "$TELEGRAM_CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="🚨 Stellar Horizon Alert [$severity]: $message" >/dev/null 2>&1 || true
    fi
}

# Check disk usage
check_disk_usage() {
    echo -e "${BLUE}🔍 Checking disk usage...${NC}"
    
    # Check Horizon data disk
    if mountpoint -q /data/horizon; then
        local horizon_usage=$(df /data/horizon | awk 'NR==2 {print $5}' | sed 's/%//')
        echo "   Horizon disk usage: ${horizon_usage}%"
        
        if [ "$horizon_usage" -gt "$DISK_THRESHOLD" ]; then
            send_alert "Horizon disk usage is ${horizon_usage}% (threshold: ${DISK_THRESHOLD}%)" "HIGH"
        fi
    fi
    
    # Check PostgreSQL data disk
    if mountpoint -q /data/postgres; then
        local postgres_usage=$(df /data/postgres | awk 'NR==2 {print $5}' | sed 's/%//')
        echo "   PostgreSQL disk usage: ${postgres_usage}%"
        
        if [ "$postgres_usage" -gt "$DISK_THRESHOLD" ]; then
            send_alert "PostgreSQL disk usage is ${postgres_usage}% (threshold: ${DISK_THRESHOLD}%)" "HIGH"
        fi
    fi
}

# Check memory usage
check_memory_usage() {
    echo -e "${BLUE}🔍 Checking memory usage...${NC}"
    
    local memory_usage=$(free | awk '/^Mem:/ {printf "%.0f", ($3/$2)*100}')
    echo "   System memory usage: ${memory_usage}%"
    
    if [ "$memory_usage" -gt "$MEMORY_THRESHOLD" ]; then
        send_alert "System memory usage is ${memory_usage}% (threshold: ${MEMORY_THRESHOLD}%)" "MEDIUM"
    fi
    
    # Check Docker container memory usage
    echo "   Docker container memory usage:"
    docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}" | grep -E "(horizon|db|redis)" || true
}

# Check Horizon sync status
check_horizon_sync() {
    echo -e "${BLUE}🔍 Checking Horizon sync status...${NC}"
    
    local horizon_response
    if horizon_response=$(curl -s --connect-timeout 5 http://localhost:8000 2>/dev/null); then
        local history_latest=$(echo "$horizon_response" | jq -r '.history_latest_ledger // empty' 2>/dev/null)
        local core_latest=$(echo "$horizon_response" | jq -r '.core_latest_ledger // empty' 2>/dev/null)
        
        if [ ! -z "$history_latest" ] && [ ! -z "$core_latest" ] && [ "$history_latest" != "null" ] && [ "$core_latest" != "null" ]; then
            local lag=$((core_latest - history_latest))
            echo "   History ledger: $history_latest"
            echo "   Core ledger: $core_latest"
            echo "   Lag: $lag ledgers"
            
            if [ "$lag" -gt "$LAG_THRESHOLD" ]; then
                send_alert "Horizon sync lag is $lag ledgers (threshold: $LAG_THRESHOLD)" "MEDIUM"
            else
                echo -e "   ${GREEN}✓ Sync status: Good${NC}"
            fi
        else
            send_alert "Unable to determine Horizon sync status" "MEDIUM"
        fi
    else
        send_alert "Horizon API is not responding" "HIGH"
    fi
}

# Check service health
check_service_health() {
    echo -e "${BLUE}🔍 Checking service health...${NC}"
    
    # Check Horizon health
    if curl -s --connect-timeout 5 http://localhost:8000/health >/dev/null 2>&1; then
        echo -e "   ${GREEN}✓ Horizon: Healthy${NC}"
    else
        echo -e "   ${RED}✗ Horizon: Unhealthy${NC}"
        send_alert "Horizon health check failed" "HIGH"
    fi
    
    # Check database connectivity
    if docker compose exec -T db pg_isready -U horizon >/dev/null 2>&1; then
        echo -e "   ${GREEN}✓ PostgreSQL: Healthy${NC}"
    else
        echo -e "   ${RED}✗ PostgreSQL: Unhealthy${NC}"
        send_alert "PostgreSQL health check failed" "HIGH"
    fi
    
    # Check container status
    local unhealthy_containers=$(docker compose ps --services | while read service; do
        if ! docker compose ps "$service" | grep -q "Up"; then
            echo "$service"
        fi
    done)
    
    if [ ! -z "$unhealthy_containers" ]; then
        send_alert "Unhealthy containers: $unhealthy_containers" "HIGH"
    fi
}

# Database backup
backup_database() {
    echo -e "${BLUE}💾 Creating database backup...${NC}"
    
    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"
    
    # Create backup filename with timestamp
    local backup_file="$BACKUP_DIR/horizon_backup_$(date +%Y%m%d_%H%M%S).sql.gz"
    
    # Create compressed backup
    if docker compose exec -T db pg_dump -U horizon horizon | gzip > "$backup_file"; then
        local backup_size=$(du -h "$backup_file" | cut -f1)
        echo -e "   ${GREEN}✓ Backup created: $backup_file ($backup_size)${NC}"
        log "Database backup created: $backup_file ($backup_size)"
        
        # Clean up old backups (keep last 7 days)
        find "$BACKUP_DIR" -name "horizon_backup_*.sql.gz" -mtime +7 -delete
        
        return 0
    else
        echo -e "   ${RED}✗ Backup failed${NC}"
        send_alert "Database backup failed" "HIGH"
        return 1
    fi
}

# Check database size and growth
check_database_metrics() {
    echo -e "${BLUE}📊 Checking database metrics...${NC}"
    
    # Get database size
    local db_size=$(docker compose exec -T db psql -U horizon -d horizon -t -c "SELECT pg_size_pretty(pg_database_size('horizon'));" 2>/dev/null | xargs)
    echo "   Database size: $db_size"
    
    # Get table sizes (top 5)
    echo "   Largest tables:"
    docker compose exec -T db psql -U horizon -d horizon -t -c "
        SELECT 
            schemaname,
            tablename,
            pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
        FROM pg_tables 
        WHERE schemaname = 'public'
        ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC 
        LIMIT 5;
    " 2>/dev/null | while IFS='|' read schema table size; do
        echo "     $(echo $table | xargs): $(echo $size | xargs)"
    done
}

# Performance metrics
show_performance_metrics() {
    echo -e "${BLUE}⚡ Performance metrics...${NC}"
    
    # CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    echo "   CPU usage: ${cpu_usage}%"
    
    # Load average
    local load_avg=$(uptime | awk -F'load average:' '{print $2}')
    echo "   Load average:$load_avg"
    
    # Disk I/O
    echo "   Disk I/O:"
    iostat -x 1 1 | grep -E "(sdc|sdd)" | awk '{printf "     %s: %s%% util\n", $1, $10}' 2>/dev/null || echo "     iostat not available"
}

# Main monitoring function
run_monitoring() {
    echo -e "${GREEN}🚀 Starting Stellar Horizon monitoring...${NC}"
    echo "Time: $(date)"
    echo "=============================================="
    
    check_service_health
    check_horizon_sync
    check_disk_usage
    check_memory_usage
    check_database_metrics
    show_performance_metrics
    
    echo "=============================================="
    echo -e "${GREEN}✅ Monitoring complete${NC}"
}

# Backup function
run_backup() {
    echo -e "${GREEN}🚀 Starting database backup...${NC}"
    backup_database
}

# Usage information
show_usage() {
    echo "Stellar Horizon Monitoring and Backup Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  monitor     Run full monitoring check"
    echo "  backup      Create database backup"
    echo "  health      Quick health check"
    echo "  sync        Check sync status only"
    echo "  disk        Check disk usage only"
    echo "  setup-cron  Set up automated monitoring"
    echo "  help        Show this help message"
}

# Set up cron jobs
setup_cron() {
    echo "Setting up automated monitoring..."
    
    # Create cron job for monitoring (every 5 minutes)
    (crontab -l 2>/dev/null; echo "*/5 * * * * $(realpath $0) monitor >> /var/log/horizon-monitor.cron.log 2>&1") | crontab -
    
    # Create cron job for backup (daily at 2 AM)
    (crontab -l 2>/dev/null; echo "0 2 * * * $(realpath $0) backup >> /var/log/horizon-backup.log 2>&1") | crontab -
    
    echo "✅ Cron jobs set up:"
    echo "   - Monitoring: Every 5 minutes"
    echo "   - Backup: Daily at 2 AM"
    echo ""
    echo "Logs will be written to:"
    echo "   - Monitor: /var/log/horizon-monitor.cron.log"
    echo "   - Backup: /var/log/horizon-backup.log"
}

# Main script logic
case "${1:-help}" in
    "monitor")
        run_monitoring
        ;;
    "backup")
        run_backup
        ;;
    "health")
        check_service_health
        ;;
    "sync")
        check_horizon_sync
        ;;
    "disk")
        check_disk_usage
        ;;
    "setup-cron")
        setup_cron
        ;;
    "help"|*)
        show_usage
        ;;
esac 