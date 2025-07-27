#!/bin/bash
# Stellar Horizon 30-Day Retention Server Setup Script
# Optimized for Linux VM with 32TB + 17.6TB disk configuration

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}================================================================${NC}"
}

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

# Main setup function
main() {
    print_header "STELLAR HORIZON 30-DAY RETENTION SERVER SETUP"
    
    echo ""
    echo "This script will set up a production-ready Stellar Horizon node with:"
    echo "• 30-day data retention (518,400 ledgers)"
    echo "• Optimized performance for your 32TB + 17.6TB disk setup"
    echo "• Automated monitoring and backup system"
    echo "• Production-grade PostgreSQL configuration"
    echo ""
    
    # Confirm setup
    read -p "Do you want to proceed with the 30-day retention setup? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Setup cancelled."
        exit 0
    fi
    
    print_header "STEP 1: SYSTEM REQUIREMENTS CHECK"
    check_system_requirements
    
    print_header "STEP 2: DISK CONFIGURATION"
    setup_disk_configuration
    
    print_header "STEP 3: ENVIRONMENT CONFIGURATION"
    setup_environment_config
    
    print_header "STEP 4: NETWORK SELECTION"
    select_network
    
    print_header "STEP 5: DEPLOYMENT"
    deploy_horizon
    
    print_header "STEP 6: POST-DEPLOYMENT SETUP"
    post_deployment_setup
    
    print_header "DEPLOYMENT COMPLETE!"
    show_final_status
}

# Check system requirements
check_system_requirements() {
    print_status "Checking system requirements for 30-day retention..."
    
    # Check if running on Linux
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        print_error "This script is designed for Linux systems."
        exit 1
    fi
    
    # Check available RAM
    total_ram=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_ram" -lt 16 ]; then
        print_warning "System has ${total_ram}GB RAM. Recommended: 32GB+ for optimal 30-day retention performance"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "RAM: ${total_ram}GB (Excellent for 30-day retention)"
    fi
    
    # Check disk configuration
    print_status "Checking disk configuration..."
    if lsblk | grep -q "sdc.*32T"; then
        print_success "Found 32TB disk (sdc) - Perfect for Horizon data"
    else
        print_warning "32TB disk (sdc) not found or not the expected size"
    fi
    
    if lsblk | grep -q "sdd.*17.6T\|sdd.*17T"; then
        print_success "Found 17.6TB disk (sdd) - Perfect for PostgreSQL"
    else
        print_warning "17.6TB disk (sdd) not found or not the expected size"
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Installing Docker..."
        install_docker
    else
        print_success "Docker is installed"
    fi
    
    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not available. Please install Docker Compose."
        exit 1
    else
        print_success "Docker Compose is available"
    fi
}

# Install Docker if not present
install_docker() {
    print_status "Installing Docker..."
    
    # Update package index
    apt update
    
    # Install Docker
    apt install -y docker.io docker-compose-v2
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Add current user to docker group if not root
    if [ "$EUID" -ne 0 ]; then
        usermod -aG docker "$USER"
        print_warning "Added user to docker group. Please log out and back in for changes to take effect."
    fi
    
    print_success "Docker installed successfully"
}

# Setup disk configuration
setup_disk_configuration() {
    print_status "Setting up optimized disk configuration for 30-day retention..."
    
    if [ "$EUID" -ne 0 ]; then
        print_error "Disk setup requires root privileges."
        print_status "Please run: sudo ./setup-30day-server.sh"
        exit 1
    fi
    
    # Check if disk setup script exists
    if [ -f "disk-setup.sh" ]; then
        print_status "Running disk setup script..."
        chmod +x disk-setup.sh
        ./disk-setup.sh
    else
        print_error "disk-setup.sh not found. Please ensure all files are present."
        exit 1
    fi
}

# Setup environment configuration
setup_environment_config() {
    print_status "Configuring environment for 30-day retention..."
    
    # Use the 30-day optimized environment file
    if [ -f "horizon-30day.env" ]; then
        cp horizon-30day.env .env
        print_success "Created .env from 30-day optimized template"
    else
        print_error "horizon-30day.env template not found!"
        exit 1
    fi
    
    # Generate a secure password
    print_status "Generating secure database password..."
    if command -v openssl &> /dev/null; then
        DB_PASSWORD=$(openssl rand -base64 32)
        sed -i "s/CHANGE_THIS_TO_A_STRONG_PASSWORD/$DB_PASSWORD/" .env
        print_success "Secure database password generated and configured"
    else
        print_warning "OpenSSL not found. Please manually set DB_PASSWORD in .env file"
        print_warning "Use a strong password like: $(date | sha256sum | base64 | head -c 32)"
    fi
    
    print_success "Environment configured for 30-day retention (518,400 ledgers)"
}

# Network selection
select_network() {
    print_status "Select Stellar network for your 30-day retention node:"
    echo ""
    echo "1) Pubnet (Mainnet) - Production network [Recommended for production]"
    echo "   • Sync time: 12-24 hours"
    echo "   • Storage: ~300-500GB for 30 days"
    echo "   • Most active network"
    echo ""
    echo "2) Testnet - Test network [Good for testing]"
    echo "   • Sync time: 2-4 hours"
    echo "   • Storage: ~50-100GB for 30 days"
    echo "   • Stable testing environment"
    echo ""
    echo "3) Futurenet - Future features network [For development]"
    echo "   • Sync time: 1-3 hours"
    echo "   • Storage: ~20-50GB for 30 days"
    echo "   • Latest features and experiments"
    echo ""
    
    while true; do
        read -p "Select network (1-3): " network_choice
        case $network_choice in
            1)
                SELECTED_NETWORK="pubnet"
                print_success "Selected: Pubnet (Mainnet)"
                break
                ;;
            2)
                SELECTED_NETWORK="testnet"
                print_success "Selected: Testnet"
                break
                ;;
            3)
                SELECTED_NETWORK="futurenet"
                print_success "Selected: Futurenet"
                break
                ;;
            *)
                print_error "Invalid choice. Please select 1, 2, or 3."
                ;;
        esac
    done
    
    # Update environment file with selected network
    sed -i "s/STELLAR_NETWORK=pubnet/STELLAR_NETWORK=$SELECTED_NETWORK/" .env
    print_status "Updated .env with selected network: $SELECTED_NETWORK"
}

# Deploy Horizon
deploy_horizon() {
    print_status "Deploying Stellar Horizon with 30-day retention..."
    
    # Make deployment script executable
    chmod +x deploy-optimized.sh
    
    # Run deployment
    print_status "Starting automated deployment..."
    ./deploy-optimized.sh
}

# Post-deployment setup
post_deployment_setup() {
    print_status "Setting up post-deployment monitoring and maintenance..."
    
    # Make monitoring script executable
    chmod +x monitoring-backup.sh
    
    # Ask if user wants automated monitoring
    echo ""
    read -p "Set up automated monitoring and daily backups? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        ./monitoring-backup.sh setup-cron
        print_success "Automated monitoring and backups configured"
    fi
    
    # Set up log rotation
    setup_log_rotation
    
    # Create maintenance scripts
    create_maintenance_scripts
}

# Setup log rotation
setup_log_rotation() {
    print_status "Setting up log rotation for Docker containers..."
    
    # Create logrotate configuration for Docker
    cat > /etc/logrotate.d/docker-horizon << 'EOF'
/var/lib/docker/containers/*/*.log {
    daily
    missingok
    rotate 7
    compress
    notifempty
    create 644 root root
    postrotate
        /bin/kill -USR1 $(cat /var/run/docker.pid 2>/dev/null) 2>/dev/null || true
    endscript
}
EOF
    
    print_success "Log rotation configured"
}

# Create maintenance scripts
create_maintenance_scripts() {
    print_status "Creating maintenance scripts..."
    
    # Create daily maintenance script
    cat > daily-maintenance.sh << 'EOF'
#!/bin/bash
# Daily maintenance script for Stellar Horizon 30-day retention node

echo "$(date): Starting daily maintenance"

# Check system health
./monitoring-backup.sh health

# Check disk usage
df -h /data/horizon /data/postgres

# Clean up old Docker images (keep last 3 versions)
docker image prune -f --filter "until=72h"

# Check database size
docker compose exec -T db psql -U horizon -d horizon -c "SELECT pg_size_pretty(pg_database_size('horizon'));"

echo "$(date): Daily maintenance completed"
EOF
    
    chmod +x daily-maintenance.sh
    print_success "Created daily-maintenance.sh script"
}

# Show final status
show_final_status() {
    print_success "Stellar Horizon 30-Day Retention Node is now running!"
    echo ""
    echo "🌟 Node Information:"
    echo "   Network: $SELECTED_NETWORK"
    echo "   Retention: 30 days (518,400 ledgers)"
    echo "   API URL: http://$(hostname -I | awk '{print $1}'):8000"
    echo "   Metrics: http://$(hostname -I | awk '{print $1}'):6060/metrics"
    echo ""
    echo "📊 Storage Configuration:"
    echo "   Horizon Data: /data/horizon (32TB disk)"
    echo "   PostgreSQL: /data/postgres (17.6TB disk)"
    echo ""
    echo "⏱️ Expected Sync Time:"
    case "$SELECTED_NETWORK" in
        "testnet")
            echo "   Initial sync: 2-4 hours"
            ;;
        "futurenet")
            echo "   Initial sync: 1-3 hours"
            ;;
        *)
            echo "   Initial sync: 12-24 hours"
            ;;
    esac
    echo ""
    echo "🔧 Useful Commands:"
    echo "   Check sync status: ./monitoring-backup.sh sync"
    echo "   View logs: docker compose logs -f horizon"
    echo "   System health: ./monitoring-backup.sh monitor"
    echo "   Daily maintenance: ./daily-maintenance.sh"
    echo ""
    echo "📚 Next Steps:"
    echo "   1. Monitor initial sync progress"
    echo "   2. Configure firewall (ports 8000, 6060)"
    echo "   3. Set up SSL/TLS for production"
    echo "   4. Configure domain name (if needed)"
    echo ""
    echo "🚀 Your Stellar Horizon 30-day retention node is ready for production!"
}

# Run main function
main "$@" 