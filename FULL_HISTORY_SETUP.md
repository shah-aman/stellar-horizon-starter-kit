# 🚀 Full History Sync Setup Guide

This guide shows how to configure Stellar Horizon for **full history sync** with maximum performance using the enhanced original setup.

## ✨ What's Enhanced

The original simple `docker-compose.yml` has been enhanced with:

- **Full history retention** (`HISTORY_RETENTION_COUNT=0`)
- **Latest Horizon image** for best performance
- **Optimized parallel processing** (8 parallel downloads, 75K job size)
- **PostgreSQL performance tuning** (2GB shared buffers, parallel workers)
- **Increased timeouts** for large history operations
- **Resource optimization** for fastest possible sync

## 🚀 Quick Start

### 1. Setup Configuration

```bash
# Copy the full history configuration
cp full-history.env .env

# Edit .env and set a strong password
nano .env
# Change: DB_PASSWORD=your_strong_password_here
```

### 2. Initialize and Start

```bash
# Initialize the database
make init

# Start full history sync (this will take days!)
make up

# Monitor sync progress
make logs
```

## ⚡ Performance Optimizations Applied

### Docker Compose Enhancements

| Setting                | Original           | Enhanced        | Benefit                         |
| ---------------------- | ------------------ | --------------- | ------------------------------- |
| **Image Version**      | `22.0.3`           | `latest`        | Latest performance improvements |
| **History Retention**  | `518400` (30 days) | `0` (unlimited) | Full history                    |
| **Parallel Downloads** | Not set            | `8`             | 8x faster archive downloads     |
| **Job Size**           | Not set            | `75000`         | Optimized batch processing      |
| **DB Connections**     | Not set            | `100`           | Better DB utilization           |
| **Timeouts**           | `30s`              | `120s`          | Handle large operations         |

### PostgreSQL Optimizations

```sql
shared_buffers = 2GB              # Large buffer cache
effective_cache_size = 6GB        # Assume 6GB available for caching
maintenance_work_mem = 512MB      # Fast maintenance operations
checkpoint_completion_target = 0.9 # Smooth checkpoints
work_mem = 128MB                  # Large sort/hash operations
max_connections = 150             # Support high concurrency
random_page_cost = 1.1            # Optimized for SSD storage
```

## 📊 Performance Expectations

### Sync Times (Estimated)

| Network       | Dataset Size | Sync Time | Storage Needed |
| ------------- | ------------ | --------- | -------------- |
| **Pubnet**    | ~20TB        | 7-21 days | 25-35TB        |
| **Testnet**   | ~5TB         | 2-7 days  | 8-15TB         |
| **Futurenet** | ~2TB         | 1-3 days  | 5-10TB         |

_Times depend on hardware, network speed, and disk I/O performance_

### Hardware Recommendations

For **fastest possible sync**:

- **CPU**: 16+ cores (more parallel processing)
- **RAM**: 32GB+ (larger PostgreSQL buffers)
- **Storage**: NVMe SSD (fast random I/O)
- **Network**: 1Gbps+ stable connection
- **Disk Space**: 40TB+ for Pubnet full history

## 🔧 Advanced Performance Tuning

### For Even Faster Sync

Edit `.env` and add these advanced settings:

```bash
# Maximum performance (use with caution)
PARALLEL_JOB_SIZE=100000
PARALLEL_HISTORY_ARCHIVE_DOWNLOADS=12
MAX_DB_CONNECTIONS=150

# Reduce logging overhead
LOG_LEVEL=warn

# Disable unnecessary features during sync
ENABLE_ASSET_STATS=false
```

### System-Level Optimizations

```bash
# Increase file descriptor limits
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Optimize kernel for database workloads
echo 'vm.swappiness=1' | sudo tee -a /etc/sysctl.conf
echo 'vm.dirty_background_ratio=5' | sudo tee -a /etc/sysctl.conf
echo 'vm.dirty_ratio=10' | sudo tee -a /etc/sysctl.conf

# Apply settings
sudo sysctl -p
```

## 📈 Monitoring During Sync

### Essential Monitoring Commands

```bash
# Monitor sync progress
docker compose logs -f horizon | grep -E "Processed ledger|ingestion"

# Check current ledger
curl -s http://localhost:8000/ledgers?order=desc&limit=1 | jq '.._embedded.records[0].sequence'

# Monitor disk usage
df -h

# Monitor PostgreSQL performance
docker compose exec db psql -U horizon -d horizon -c "
SELECT
    schemaname,
    tablename,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes,
    n_live_tup as live_tuples,
    n_dead_tup as dead_tuples
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC
LIMIT 10;"
```

### Health Checks

```bash
# Overall health
make health

# Detailed sync status
curl -s http://localhost:6060/metrics | grep -E "horizon_ingest|stellar_core"

# Database size
docker compose exec db psql -U horizon -d horizon -c "
SELECT
    pg_size_pretty(pg_database_size('horizon')) as db_size,
    pg_size_pretty(pg_total_relation_size('history_ledgers')) as ledgers_size,
    pg_size_pretty(pg_total_relation_size('history_transactions')) as tx_size;"
```

## 🛠️ Troubleshooting

### Common Issues

**Sync appears stuck:**

```bash
# Check if Horizon is actually processing
docker compose logs horizon | tail -20

# Restart if needed
make restart
```

**Out of disk space:**

```bash
# Check disk usage
df -h

# Clean Docker system (careful!)
docker system prune -f
```

**PostgreSQL connection issues:**

```bash
# Check PostgreSQL logs
docker compose logs db

# Verify connections
docker compose exec db psql -U horizon -c "SELECT count(*) FROM pg_stat_activity;"
```

### Performance Issues

**Slow sync speed:**

```bash
# Increase parallel downloads (in .env)
PARALLEL_HISTORY_ARCHIVE_DOWNLOADS=16

# Increase job size (uses more memory)
PARALLEL_JOB_SIZE=150000

# Restart to apply changes
make restart
```

## 🔄 Comparing with 30-Day Setup

| Aspect                  | 30-Day Setup | Full History Setup  |
| ----------------------- | ------------ | ------------------- |
| **Storage**             | ~1TB         | ~25-35TB            |
| **Sync Time**           | 12-24 hours  | 7-21 days           |
| **Ongoing Performance** | Fast         | Slower (more data)  |
| **API Response Time**   | Fast         | Slower for old data |
| **Resource Usage**      | Moderate     | High                |

## 📋 Success Checklist

- [ ] Used `full-history.env` as `.env`
- [ ] Set strong `DB_PASSWORD`
- [ ] Have sufficient storage (25-35TB for Pubnet)
- [ ] System has adequate RAM (32GB+)
- [ ] Network connection is stable
- [ ] Monitoring is set up
- [ ] Started sync with `make up`
- [ ] Confirmed sync is progressing with `make logs`

## 🎯 Expected Results

After successful full history sync:

✅ **Complete historical data** since Stellar genesis  
✅ **All transactions** queryable via API  
✅ **Full ledger history** available  
✅ **Maximum data completeness** for analytics

The enhanced setup provides the **fastest possible full history sync** while maintaining the simplicity of the original approach!
