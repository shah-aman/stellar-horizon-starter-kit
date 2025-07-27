# Command Comparison: Makefile vs Optimized Scripts

## 🚀 Quick Reference

| Task                  | Original Makefile            | Optimized Approach                | Notes                                  |
| --------------------- | ---------------------------- | --------------------------------- | -------------------------------------- |
| **Setup Environment** | `cp .env.example .env`       | `cp env.production.template .env` | Optimized has better defaults          |
| **Disk Setup**        | Manual (user responsibility) | `sudo ./disk-setup.sh`            | Automated with 32TB+17.6TB utilization |
| **Database Init**     | `make init`                  | Part of `./deploy-optimized.sh`   | Integrated into deployment             |
| **Start Services**    | `make up NETWORK=pubnet`     | `./deploy-optimized.sh`           | Single command for full setup          |
| **View Logs**         | `make logs`                  | `docker compose logs -f horizon`  | Same functionality                     |
| **Health Check**      | `make health`                | `./monitoring-backup.sh health`   | Enhanced health monitoring             |
| **Full Monitoring**   | Not available                | `./monitoring-backup.sh monitor`  | Comprehensive system monitoring        |
| **Backup Database**   | Manual                       | `./monitoring-backup.sh backup`   | Automated with retention               |
| **Stop Services**     | `make down`                  | `docker compose down`             | Same functionality                     |
| **Update Horizon**    | `make update`                | `make update` (still works)       | Can use either approach                |
| **Clean Data**        | `make clean`                 | `make clean` (still works)        | Same functionality                     |

## 🔧 Docker Compose Commands

### Original Approach

```bash
# Uses default docker-compose.yml
docker compose up -d                    # Start with Docker volumes
docker compose logs -f horizon          # View logs
docker compose down                     # Stop services
```

### Optimized Approach

```bash
# Uses docker-compose-optimized.yml (if available)
docker compose -f docker-compose-optimized.yml up -d    # Start with direct mounts
docker compose logs -f horizon                          # View logs
docker compose down                                      # Stop services
```

## 📊 Storage Commands Comparison

### Original - Docker Volume Management

```bash
# View volumes
docker volume ls
docker volume inspect stellar-horizon-starter-kit_postgres_data

# Backup (manual process)
docker run --rm -v postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/backup.tar.gz -C /data .

# Location: /var/lib/docker/volumes/
```

### Optimized - Direct Disk Management

```bash
# View disk usage
df -h /data/horizon /data/postgres

# Backup (automated)
./monitoring-backup.sh backup

# Manual backup
docker compose exec db pg_dump -U horizon horizon | gzip > backup.sql.gz

# Location: /data/postgres/data and /data/horizon/
```

## 🔍 Monitoring Commands

### Original Monitoring

```bash
make health                           # Basic health check only
make logs                            # View logs manually
docker stats                        # Basic resource usage
```

### Optimized Monitoring

```bash
./monitoring-backup.sh health        # Service health status
./monitoring-backup.sh sync          # Horizon sync status
./monitoring-backup.sh disk          # Disk usage monitoring
./monitoring-backup.sh monitor       # Full system monitoring
docker stats                         # Resource usage (same)
```

## ⚙️ Configuration Management

### Original Configuration

```bash
# Environment variables only
nano .env

# Network selection via Makefile
make up NETWORK=testnet
```

### Optimized Configuration

```bash
# Enhanced environment template
nano .env                            # Based on env.production.template

# PostgreSQL optimization
nano postgres-conf/postgresql.conf   # Auto-generated performance settings

# Monitoring setup
nano monitoring/prometheus.yml       # Auto-generated monitoring config

# Network selection via environment
export STELLAR_NETWORK=testnet && ./deploy-optimized.sh
```

## 🚨 Troubleshooting Commands

### Original Troubleshooting

```bash
make logs                            # View logs
make health                          # Basic health check
docker compose ps                    # Service status
```

### Optimized Troubleshooting

```bash
./monitoring-backup.sh monitor       # Comprehensive system check
docker compose logs --tail=100 horizon  # Recent logs
docker stats                         # Resource usage
df -h /data/horizon /data/postgres   # Disk usage
iostat -x 1                         # Disk I/O monitoring
```

## 📈 Performance Analysis Commands

### Original - Limited Visibility

```bash
docker stats                         # Basic container stats
# No database performance metrics
# No disk I/O analysis
# No sync status monitoring
```

### Optimized - Comprehensive Analysis

```bash
./monitoring-backup.sh monitor       # Full performance report
docker stats                         # Container resource usage
iostat -x 1                         # Disk I/O performance
free -h                              # Memory usage
htop                                 # CPU and process monitoring

# Database performance
docker compose exec db psql -U horizon -d horizon -c "
SELECT query, mean_time, calls
FROM pg_stat_statements
ORDER BY mean_time DESC LIMIT 10;"
```

## 🔄 Migration Commands

### Migrating from Original to Optimized

```bash
# Step 1: Stop original services
make down

# Step 2: Backup existing data (if needed)
docker run --rm -v postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres-backup.tar.gz -C /data .

# Step 3: Setup optimized disks
sudo ./disk-setup.sh

# Step 4: Deploy optimized version
./deploy-optimized.sh

# Step 5: Restore data (if migrating existing data)
# This would involve restoring the PostgreSQL backup to the new location
```

## 🎯 Key Takeaways

### Original Makefile Strengths:

- ✅ **Simple commands**: Easy to understand and use
- ✅ **Quick setup**: Fast development environment
- ✅ **Familiar workflow**: Standard Make-based operations
- ✅ **Lightweight**: Minimal overhead

### Optimized Approach Strengths:

- ✅ **Production-ready**: Comprehensive deployment automation
- ✅ **Performance-optimized**: 5-10x better performance
- ✅ **Disk utilization**: Uses your 32TB + 17.6TB disks effectively
- ✅ **Monitoring included**: Proactive issue detection
- ✅ **Automated backups**: Data protection built-in
- ✅ **Resource management**: Prevents OOM and resource exhaustion

**Recommendation**: Use the optimized approach for your production VM to fully utilize the large disk capacity and achieve maximum performance.
