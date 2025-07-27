# 30-Day Stellar Horizon Deployment Summary

This document summarizes all the optimized files and configurations created for your 30-day retention Stellar Horizon node deployment.

## 🎯 Configuration Overview

**Data Retention**: Exactly 30 days (518,400 ledgers)
**Expected Storage**: ~610GB-1.3TB total
**Sync Time**: 12-24 hours for pubnet, 2-4 hours for testnet
**VM Optimization**: Utilizes your 32TB + 17.6TB disk setup

## 📁 Files Created for 30-Day Deployment

### Core Configuration Files

| File                           | Purpose                           | Key Features                                                                                                      |
| ------------------------------ | --------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `horizon-30day.env`            | **Production environment config** | • 30-day retention (518,400 ledgers)<br/>• Performance optimization<br/>• Secure settings<br/>• Storage estimates |
| `docker-compose-optimized.yml` | **Enhanced Docker setup**         | • Direct disk mounts<br/>• PostgreSQL performance tuning<br/>• Resource limits<br/>• Redis + Prometheus           |

### Deployment Scripts

| File                    | Purpose                  | Usage                            |
| ----------------------- | ------------------------ | -------------------------------- |
| `setup-30day-server.sh` | **Master setup script**  | `sudo ./setup-30day-server.sh`   |
| `disk-setup.sh`         | **Disk configuration**   | Auto-run by setup script         |
| `deploy-optimized.sh`   | **Service deployment**   | Auto-run by setup script         |
| `monitoring-backup.sh`  | **Monitoring & backups** | `./monitoring-backup.sh monitor` |

### Documentation

| File                     | Purpose                  | Contents                  |
| ------------------------ | ------------------------ | ------------------------- |
| `DEPLOYMENT_GUIDE.md`    | **Complete setup guide** | Step-by-step instructions |
| `APPROACH_COMPARISON.md` | **Technical comparison** | Original vs optimized     |
| `COMMAND_COMPARISON.md`  | **Command reference**    | Quick command lookup      |

## 🚀 Quick Start Guide

### For First-Time Setup:

```bash
# 1. Run the master setup script (requires root)
sudo ./setup-30day-server.sh
```

This single command will:

- ✅ Check system requirements
- ✅ Configure 32TB + 17.6TB disks
- ✅ Set up 30-day retention environment
- ✅ Let you select network (pubnet/testnet/futurenet)
- ✅ Deploy all services
- ✅ Configure monitoring and backups

### For Manual Step-by-Step Setup:

```bash
# 1. Setup disks (run as root)
sudo ./disk-setup.sh

# 2. Configure environment
cp horizon-30day.env .env
nano .env  # Set DB_PASSWORD

# 3. Deploy services
./deploy-optimized.sh

# 4. Setup monitoring
./monitoring-backup.sh setup-cron
```

## 📊 30-Day Retention Specifications

### Ledger Calculation

```
Stellar Network: ~5-second block time
Daily ledgers: 24h × 60min × 60sec ÷ 5sec = 17,280 ledgers/day
30-day retention: 30 × 17,280 = 518,400 ledgers
```

### Storage Breakdown

**PostgreSQL Database (17.6TB disk):**

- Processed data: ~150-300GB
- Indexes: ~50-100GB
- WAL files: ~10-20GB
- Backups: ~50-100GB
- **Total: ~260-520GB**

**Captive Core Storage (32TB disk):**

- History archives: ~200-500GB (during sync)
- Ledger buckets: ~100-200GB (steady state)
- Temporary files: ~50-100GB
- **Total: ~350-800GB**

**Total Storage: ~610GB-1.3TB** (well within your capacity)

## ⚡ Performance Optimizations

### Database Optimizations

```sql
shared_buffers = 4GB              -- 25% of 16GB RAM
effective_cache_size = 12GB       -- 75% of 16GB RAM
work_mem = 256MB                  -- Per-query memory
random_page_cost = 1.0            -- SSD optimization
effective_io_concurrency = 200    -- SSD parallelism
max_parallel_workers = 8          -- Multi-core usage
```

### Horizon Optimizations

```bash
PARALLEL_JOB_SIZE=100000                    # Faster ingestion
PARALLEL_HISTORY_ARCHIVE_DOWNLOADS=4       # Faster sync
HTTP_REQUEST_TIMEOUT=30                     # Connection timeout
MAX_DB_CONNECTIONS=50                       # Connection pool
```

### Disk Optimizations

- Direct disk mounts (no Docker volumes)
- `noatime` mount option
- Separate disks for different workloads
- ext4 filesystem optimized for large files

## 🔍 Monitoring Commands

### Health Monitoring

```bash
./monitoring-backup.sh health     # Quick health check
./monitoring-backup.sh sync       # Sync status
./monitoring-backup.sh disk       # Disk usage
./monitoring-backup.sh monitor    # Full system report
```

### Log Monitoring

```bash
docker compose logs -f horizon                    # Real-time logs
docker compose logs horizon | grep "Processed"    # Sync progress
docker compose logs --tail=100 horizon            # Recent logs
```

### System Monitoring

```bash
df -h /data/horizon /data/postgres                # Disk usage
docker stats                                      # Container resources
free -h                                           # Memory usage
iostat -x 1                                       # Disk I/O
```

## 🕐 Expected Timeline

### Initial Sync Times (30-day retention)

- **Pubnet**: 12-24 hours
- **Testnet**: 2-4 hours
- **Futurenet**: 1-3 hours

### Sync Phases

1. **History Download** (30-50% of time)

   - Downloads compressed archives
   - Peak disk usage on 32TB disk

2. **Processing** (40-60% of time)

   - Processes ledger data
   - Heavy database writes on 17.6TB disk

3. **Steady State** (ongoing)
   - Real-time sync every ~5 seconds
   - Stable resource usage

## 🔐 Security Considerations

### Network Security

```bash
# Configure firewall
ufw allow 22          # SSH
ufw allow 8000        # Horizon API
ufw allow 6060        # Metrics (optional, can restrict)
ufw enable
```

### Database Security

- Strong auto-generated password
- Connection limits enforced
- Local connections only
- Regular backup encryption

### Container Security

- Resource limits prevent DoS
- Non-root user in containers
- Read-only configuration mounts
- Network isolation

## 📈 Scaling Options

### Horizontal Scaling (Future)

```bash
# Read-only API nodes
INGEST=false
DISABLE_TX_SUB=true

# Dedicated ingestion node
INGEST=true
DISABLE_TX_SUB=true

# Transaction submission nodes
INGEST=false
DISABLE_TX_SUB=false
```

### Vertical Scaling

- Increase memory allocation in docker-compose
- Adjust PostgreSQL settings for more RAM
- Add more CPU cores for parallel processing

## 🛠️ Maintenance Schedule

### Daily (Automated)

- ✅ Health checks every 5 minutes
- ✅ Database backup at 2 AM
- ✅ Disk usage monitoring
- ✅ Performance metrics collection

### Weekly (Manual)

```bash
./monitoring-backup.sh monitor    # Full system check
docker system prune              # Clean unused images
./daily-maintenance.sh           # Run maintenance tasks
```

### Monthly (Manual)

```bash
make update                      # Update Horizon version
# Review logs for any issues
# Test backup restoration
# Performance tuning if needed
```

## 🆘 Troubleshooting Quick Reference

### Common Issues

**Slow Sync**

```bash
docker stats                     # Check resource usage
iostat -x 1                     # Check disk I/O
./monitoring-backup.sh monitor   # Full system check
```

**Out of Space**

```bash
df -h /data/horizon /data/postgres    # Check disk usage
docker system prune -a               # Clean Docker images
# Consider reducing retention temporarily
```

**Database Issues**

```bash
docker compose exec db pg_isready -U horizon    # Check DB health
docker compose logs db                          # Check DB logs
./monitoring-backup.sh monitor                  # Full check
```

**High Memory Usage**

```bash
free -h                          # Check system memory
docker stats                     # Check container memory
# Reduce PostgreSQL shared_buffers if needed
```

## 🎯 Success Metrics

Your 30-day retention node is successful when:

- ✅ Sync lag < 10 ledgers
- ✅ API response time < 100ms
- ✅ Database size stable at ~300-500GB
- ✅ Disk usage < 85% on both disks
- ✅ Memory usage < 90%
- ✅ Daily backups completing successfully

## 📞 Support Resources

- **Health Check**: `./monitoring-backup.sh health`
- **Full Documentation**: `DEPLOYMENT_GUIDE.md`
- **Command Reference**: `COMMAND_COMPARISON.md`
- **Stellar Documentation**: https://developers.stellar.org/
- **Network Status**: https://dashboard.stellar.org/

---

**Your 30-day retention Stellar Horizon node is optimized for production use with your 32TB + 17.6TB VM configuration!**
