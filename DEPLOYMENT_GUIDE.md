# Stellar Horizon Optimized Deployment Guide

This guide provides comprehensive instructions for deploying Stellar Horizon on your Linux VM with optimal disk utilization.

## 🏗️ VM Disk Configuration Analysis

Your VM has the following disk configuration:

```
NAME      SIZE    MOUNTPOINT    RECOMMENDED USE
sda       2TB     /             System disk (keep for OS)
sdb       600GB   /mnt          Small auxiliary disk
sdc       32TB    unmounted     HORIZON DATA (captive core storage)
sdd       17.6TB  unmounted     POSTGRESQL DATABASE
```

## 🎯 Optimized Setup Strategy

### Disk Allocation

- **sdc (32TB)** → `/data/horizon` - Captive core storage, history archives
- **sdd (17.6TB)** → `/data/postgres` - PostgreSQL database and backups
- **sda (2TB)** → System disk (Docker, logs, temp files)
- **sdb (600GB)** → Optional additional space for monitoring/logs

### Why This Configuration?

1. **Captive Core Storage (32TB)**: During initial sync, Horizon downloads compressed history archives that can be 500GB-2TB+. The 32TB disk provides ample space for:

   - History archive downloads
   - Ledger bucket storage
   - Future growth

2. **PostgreSQL Database (17.6TB)**: The processed database grows continuously:
   - Pubnet full history: ~500GB-1TB
   - With 30-day retention: ~100-300GB
   - Includes indexes, WAL files, and backups

## 🚀 Step-by-Step Deployment

### Prerequisites

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y docker.io docker-compose-v2 make git jq curl

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group (optional)
sudo usermod -aG docker $USER
# Log out and back in for group changes to take effect
```

### 1. Setup Disks

```bash
# Clone the repository if not already done
git clone <your-repo-url>
cd stellar-horizon-starter-kit

# Run disk setup (requires root)
sudo ./disk-setup.sh
```

This script will:

- Format sdc and sdd disks with ext4
- Mount them at `/data/horizon` and `/data/postgres`
- Add entries to `/etc/fstab` for persistent mounting
- Set proper permissions

### 2. Configure Environment

```bash
# Copy the production environment template
cp env.production.template .env

# Edit the environment file
nano .env
```

**Critical settings to configure:**

```bash
# MUST CHANGE: Set a strong password
DB_PASSWORD=your-very-strong-password-here

# Choose your network
STELLAR_NETWORK=pubnet  # or testnet, futurenet

# Adjust retention based on your needs
HISTORY_RETENTION_COUNT=518400  # ~30 days

# Performance tuning
PARALLEL_JOB_SIZE=50000
LOG_LEVEL=info
```

### 3. Deploy Horizon

```bash
# Run the optimized deployment script
chmod +x deploy-optimized.sh
./deploy-optimized.sh
```

The deployment script will:

- Check system requirements
- Set up monitoring and PostgreSQL configurations
- Initialize the database
- Start all services

## 📊 Understanding Data Sync Process

### Initial Sync Timeline

- **Testnet**: 2-6 hours
- **Pubnet**: 12-48 hours (depending on hardware and network)
- **Futurenet**: 1-4 hours

### Sync Phases

1. **History Download**: Downloads compressed ledger archives
2. **Captive Core Processing**: Processes raw ledger data
3. **Database Ingestion**: Transforms and stores data in PostgreSQL
4. **Ongoing Sync**: Processes new ledgers in real-time

### Disk Usage During Sync

```
Phase 1: History Download
├── /data/horizon/core/       500GB-2TB (compressed archives)
└── /data/postgres/data/      Minimal growth

Phase 2: Processing
├── /data/horizon/core/       Peak usage (buckets + archives)
└── /data/postgres/data/      Rapid growth

Phase 3: Steady State
├── /data/horizon/core/       100-500GB (active buckets)
└── /data/postgres/data/      Steady growth based on retention
```

## 🔧 Configuration Files

### Docker Compose Optimization

The `docker-compose-optimized.yml` includes:

- PostgreSQL performance tuning for SSD storage
- Memory limits to prevent OOM issues
- Direct disk mounts for better I/O performance
- Optional Redis caching for API performance
- Prometheus monitoring setup

### PostgreSQL Optimizations

```sql
-- Key optimizations applied:
shared_buffers = 4GB              -- 25% of available RAM
effective_cache_size = 12GB       -- 75% of available RAM
work_mem = 256MB                  -- Per-query working memory
random_page_cost = 1.0            -- Optimized for SSDs
effective_io_concurrency = 200    -- SSD optimization
max_parallel_workers = 8          -- Utilize multiple cores
```

## 📈 Monitoring and Maintenance

### Health Monitoring

```bash
# Quick health check
./monitoring-backup.sh health

# Full monitoring report
./monitoring-backup.sh monitor

# Check sync status
./monitoring-backup.sh sync

# Check disk usage
./monitoring-backup.sh disk
```

### Automated Monitoring Setup

```bash
# Set up automated monitoring and backups
./monitoring-backup.sh setup-cron
```

This creates:

- Health monitoring every 5 minutes
- Daily database backups at 2 AM
- Automatic alerts for issues

### Manual Monitoring Commands

```bash
# View real-time logs
docker compose logs -f horizon

# Check sync progress
docker compose logs horizon | grep -E 'Processed ledger|Closed ledger'

# Monitor database size
docker compose exec db psql -U horizon -d horizon -c "SELECT pg_size_pretty(pg_database_size('horizon'));"

# Check disk usage
df -h /data/horizon /data/postgres

# View container resource usage
docker stats
```

## 🔍 Performance Tuning

### Memory Usage

- **System RAM**: 32GB+ recommended for pubnet
- **PostgreSQL**: 8-16GB allocated
- **Horizon**: 4-8GB allocated
- **Leave headroom**: For OS and temporary operations

### Disk I/O Optimization

The setup includes several I/O optimizations:

- Direct disk mounts (no Docker volumes)
- `noatime` mount option to reduce write operations
- PostgreSQL tuned for SSD storage
- Separate disks for different workloads

### Network Considerations

- Reliable internet connection essential
- Consider bandwidth costs for initial sync
- Monitor for network-related sync issues

## 🚨 Troubleshooting

### Common Issues

**Out of Disk Space During Sync**

```bash
# Check current disk usage
df -h /data/horizon /data/postgres

# Clean up old Docker images
docker system prune -a

# Reduce history retention temporarily
# Edit .env: HISTORY_RETENTION_COUNT=259200  # 15 days
docker compose restart horizon
```

**Slow Sync Performance**

```bash
# Check if using optimized configuration
ls -la docker-compose-optimized.yml

# Monitor disk I/O
iostat -x 1

# Check PostgreSQL query performance
docker compose exec db psql -U horizon -d horizon -c "SELECT query, mean_time, calls FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;"
```

**Memory Issues**

```bash
# Check memory usage
free -h
docker stats

# Reduce PostgreSQL memory if needed
# Edit docker-compose-optimized.yml and reduce shared_buffers
```

**Database Connection Issues**

```bash
# Check PostgreSQL status
docker compose exec db pg_isready -U horizon

# View PostgreSQL logs
docker compose logs db

# Check connection limits
docker compose exec db psql -U horizon -d horizon -c "SHOW max_connections;"
```

## 📋 Maintenance Checklist

### Daily

- [x] Check sync status: `./monitoring-backup.sh sync`
- [x] Monitor disk usage: `./monitoring-backup.sh disk`
- [x] Review logs for errors: `docker compose logs --tail=100 horizon`

### Weekly

- [x] Full system monitoring: `./monitoring-backup.sh monitor`
- [x] Verify backups are working: `ls -la /data/postgres/backups/`
- [x] Check database performance metrics
- [x] Review and clean up old Docker images: `docker system prune`

### Monthly

- [x] Update Horizon image: `make update`
- [x] Review disk usage trends
- [x] Optimize database if needed: `VACUUM ANALYZE`
- [x] Test backup restoration procedure

## 🔐 Security Considerations

### Network Security

- Configure firewall to only allow necessary ports (8000, 6060)
- Use SSH key authentication
- Consider VPN for admin access

### Database Security

- Use strong PostgreSQL password
- Limit database connections
- Regular security updates
- Encrypted backups for sensitive environments

### Monitoring Security

- Secure metrics endpoints
- Use authentication for monitoring dashboards
- Regular log review for suspicious activity

## 📚 Additional Resources

- [Stellar Horizon Admin Guide](https://developers.stellar.org/docs/data/apis/horizon/admin-guide/overview)
- [PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [Docker Production Deployment Guide](https://docs.docker.com/config/containers/live-restore/)
- [Stellar Network Status](https://dashboard.stellar.org/)

## 🆘 Support

If you encounter issues:

1. **Check logs**: `docker compose logs horizon`
2. **Run health check**: `./monitoring-backup.sh health`
3. **Review this guide** for troubleshooting steps
4. **Check Stellar documentation** for known issues
5. **Join Stellar Developer Discord** for community support

---

**Note**: Initial sync can take significant time and disk space. Monitor progress and ensure adequate resources are available throughout the process.
