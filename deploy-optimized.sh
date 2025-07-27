#!/bin/bash
# Stellar Horizon Optimized Deployment Script
# This script deploys Horizon with optimal disk utilization

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root for disk setup
check_root() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Check system requirements
check_requirements() {
    print_status "Checking system requirements..."
    
    # Check available RAM
    total_ram=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_ram" -lt 16 ]; then
        print_warning "System has ${total_ram}GB RAM. Recommended: 32GB+ for optimal performance"
    else
        print_success "RAM: ${total_ram}GB (Good)"
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not available. Please install Docker Compose."
        exit 1
    fi
    
    print_success "System requirements check passed"
}

# Setup disks if running as root
setup_disks() {
    if check_root; then
        print_status "Setting up optimized disk configuration..."
        chmod +x disk-setup.sh
        ./disk-setup.sh
    else
        print_warning "Not running as root. Skipping disk setup."
        print_warning "Please run 'sudo ./disk-setup.sh' separately to set up disks."
    fi
}

# Create necessary directories
create_directories() {
    print_status "Creating necessary directories..."
    
    # Create monitoring directory
    mkdir -p monitoring
    mkdir -p postgres-conf
    mkdir -p logs
    
    # Create temporary horizon directory
    sudo mkdir -p /tmp/horizon
    sudo chmod 777 /tmp/horizon
    
    print_success "Directories created"
}

# Setup monitoring configuration
setup_monitoring() {
    print_status "Setting up monitoring configuration..."
    
    # Create Prometheus configuration
    cat > monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'horizon'
    static_configs:
      - targets: ['horizon:6060']
    metrics_path: '/metrics'
    scrape_interval: 10s
  
  - job_name: 'postgres'
    static_configs:
      - targets: ['db:5432']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'redis'
    static_configs:
      - targets: ['redis:6379']
    scrape_interval: 30s
EOF

    print_success "Monitoring configuration created"
}

# Setup PostgreSQL configuration
setup_postgres_config() {
    print_status "Setting up PostgreSQL configuration..."
    
    # Create optimized PostgreSQL configuration
    cat > postgres-conf/postgresql.conf << 'EOF'
# PostgreSQL configuration optimized for Stellar Horizon

# Connection settings
max_connections = 100
shared_buffers = 4GB
effective_cache_size = 12GB
maintenance_work_mem = 1GB
checkpoint_completion_target = 0.9
wal_buffers = 64MB
default_statistics_target = 100
random_page_cost = 1.0  # Optimized for SSDs
effective_io_concurrency = 200
work_mem = 256MB

# Parallel query settings
max_worker_processes = 8
max_parallel_workers_per_gather = 4
max_parallel_workers = 8
max_parallel_maintenance_workers = 4

# Write-ahead logging
wal_level = replica
max_wal_size = 4GB
min_wal_size = 1GB

# Logging
log_min_duration_statement = 1000
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on

# Auto-vacuum settings
autovacuum = on
autovacuum_max_workers = 3
autovacuum_naptime = 20s
EOF

    # Create pg_hba.conf
    cat > postgres-conf/pg_hba.conf << 'EOF'
# PostgreSQL Client Authentication Configuration File

# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             all                                     trust
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
host    all             all             0.0.0.0/0               md5
EOF

    print_success "PostgreSQL configuration created"
}

# Configure environment for 30-day retention
configure_environment() {
    print_status "Configuring environment for 30-day retention..."
    
    if [ ! -f .env ]; then
        if [ -f horizon-30day.env ]; then
            cp horizon-30day.env .env
            print_success "Created .env from 30-day optimized template."
            print_warning "IMPORTANT: Edit .env and set a strong DB_PASSWORD before proceeding!"
            print_warning "Generate password with: openssl rand -base64 32"
        elif [ -f env.production.template ]; then
            cp env.production.template .env
            print_warning "Created .env from template. Please edit it and set a strong DB_PASSWORD."
        elif [ -f .env.example ]; then
            cp .env.example .env
            print_warning "Created .env from example. Please edit it and set a strong DB_PASSWORD."
        else
            print_error "No environment template found. Please create .env file manually."
            exit 1
        fi
    else
        print_success "Environment file (.env) already exists"
        
        # Check if it's configured for 30-day retention
        if grep -q "HISTORY_RETENTION_COUNT=518400" .env; then
            print_success "Environment is configured for 30-day retention (518,400 ledgers)"
        else
            print_warning "Environment may not be optimized for 30-day retention"
            print_warning "Verify HISTORY_RETENTION_COUNT=518400 in .env file"
        fi
    fi
    
    # Validate critical settings
    if grep -q "CHANGE_THIS_TO_A_STRONG_PASSWORD" .env; then
        print_error "Please change the default DB_PASSWORD in .env file!"
        print_error "Generate a secure password with: openssl rand -base64 32"
        exit 1
    fi
}

# Initialize database
init_database() {
    print_status "Initializing Horizon database..."
    
    # Use optimized docker-compose file if it exists
    COMPOSE_FILE="docker-compose.yml"
    if [ -f "docker-compose-optimized.yml" ]; then
        COMPOSE_FILE="docker-compose-optimized.yml"
        print_status "Using optimized Docker Compose configuration"
    fi
    
    # Start database first
    docker compose -f "$COMPOSE_FILE" up -d db
    
    # Wait for database to be ready
    print_status "Waiting for database to be ready..."
    sleep 30
    
    # Initialize Horizon database
    docker compose -f "$COMPOSE_FILE" run --rm --entrypoint="" horizon /usr/bin/stellar-horizon db init
    
    print_success "Database initialized"
}

# Start services
start_services() {
    print_status "Starting Stellar Horizon services..."
    
    COMPOSE_FILE="docker-compose.yml"
    if [ -f "docker-compose-optimized.yml" ]; then
        COMPOSE_FILE="docker-compose-optimized.yml"
    fi
    
    # Set default network if not specified
    export STELLAR_NETWORK=${STELLAR_NETWORK:-pubnet}
    
    docker compose -f "$COMPOSE_FILE" up -d
    
    print_success "Services started"
}

# Display status and next steps for 30-day retention setup
show_status() {
    print_success "Stellar Horizon 30-Day Retention Node deployment completed!"
    echo ""
    echo "🌟 Service URLs:"
    echo "   Horizon API: http://localhost:8000"
    echo "   Admin/Metrics: http://localhost:6060"
    echo "   Prometheus: http://localhost:9090 (if enabled)"
    echo ""
    echo "📊 30-Day Retention Configuration:"
    echo "   Data Retention: 30 days (518,400 ledgers)"
    echo "   Expected Storage: ~610GB-1.3TB total"
    echo "   Network: ${STELLAR_NETWORK:-pubnet}"
    echo ""
    echo "💾 Disk Usage (Your VM Setup):"
    df -h /data/horizon /data/postgres 2>/dev/null || echo "   Run disk setup as root to see disk usage"
    echo "   32TB disk: Captive core storage (/data/horizon)"
    echo "   17.6TB disk: PostgreSQL database (/data/postgres)"
    echo ""
    echo "⏱️ Expected Sync Times for 30-Day Retention:"
    case "${STELLAR_NETWORK:-pubnet}" in
        "testnet")
            echo "   Testnet: 2-4 hours (initial sync)"
            ;;
        "futurenet")
            echo "   Futurenet: 1-3 hours (initial sync)"
            ;;
        *)
            echo "   Pubnet: 12-24 hours (initial sync)"
            ;;
    esac
    echo "   After initial sync: Real-time (5-second intervals)"
    echo ""
    echo "📊 Monitoring Commands:"
    echo "   Full System Check: ./monitoring-backup.sh monitor"
    echo "   Sync Status: ./monitoring-backup.sh sync"
    echo "   Health Check: ./monitoring-backup.sh health"
    echo "   View Logs: docker compose logs -f horizon"
    echo ""
    echo "⚡ 30-Day Retention Monitoring Tips:"
    echo "   1. Monitor sync progress: docker compose logs -f horizon | grep 'Processed ledger'"
    echo "   2. Check API status: curl http://localhost:8000/health"
    echo "   3. View metrics: http://localhost:6060/metrics"
    echo "   4. Database will stabilize at ~300-500GB after initial sync"
    echo "   5. Set up automated monitoring: ./monitoring-backup.sh setup-cron"
    echo ""
    echo "🔧 Configuration Details:"
    echo "   Network: ${STELLAR_NETWORK:-pubnet}"
    echo "   Retention: 30 days (518,400 ledgers)"
    echo "   Parallel Jobs: 100,000 (optimized for faster sync)"
    echo "   Environment File: .env"
    echo "   Compose File: $([ -f "docker-compose-optimized.yml" ] && echo "docker-compose-optimized.yml" || echo "docker-compose.yml")"
    echo ""
    echo "🚀 Next Steps:"
    echo "   1. Monitor initial sync progress with logs"
    echo "   2. Set up automated monitoring and backups"
    echo "   3. Configure firewall (allow ports 8000, 6060)"
    echo "   4. Set up SSL/TLS for production API access"
}

# Main deployment process
main() {
    echo "🚀 Starting Stellar Horizon Optimized Deployment"
    echo "================================================"
    
    check_requirements
    setup_disks
    create_directories
    setup_monitoring
    setup_postgres_config
    configure_environment
    
    # Ask user if they want to proceed with deployment
    echo ""
    read -p "Proceed with Horizon deployment? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        init_database
        start_services
        show_status
    else
        print_status "Deployment cancelled. You can run this script again when ready."
    fi
}

# Run main function
main "$@" 