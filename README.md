# Stellar Horizon Starter Kit

A production-ready deployment of **Stellar Horizon** using Docker Compose. This repository provides a minimal yet production-aware setup that's easy to operate and scale.

## ✨ Features

- **Production-focused** – Separate containers for each service with persistent volumes
- **Multi-network support** – Easy switching between Pubnet, Testnet, and Futurenet
- **Health monitoring** – Built-in health checks and metrics endpoints
- **Easy operations** – Makefile for common tasks
- **Configurable** – Environment variables for all key settings
- **Scalable** – Clear path to horizontal scaling

## 🚀 Quick Start

### Prerequisites (Ubuntu 24.10)

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install Docker (using Ubuntu's package for 24.10 compatibility)
sudo apt install -y docker.io docker-compose-v2

# Alternative: Install Docker from snap (if ubuntu packages don't work)
# sudo snap install docker

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Add current user to docker group (optional, requires logout/login)
sudo usermod -aG docker $USER

# Install make and git
sudo apt install -y make git
```

### Setup and Deployment

```bash
# Clone the repository
git clone https://github.com/withObsrvr/stellar-horizon-starter-kit.git
cd stellar-horizon-starter-kit

# Copy and configure environment variables
cp .env.example .env
# Edit .env and set a strong DB_PASSWORD

# Initialize the database
make init

# Start the stack (defaults to pubnet)
make up

# Or start with a specific network
make up NETWORK=testnet
```

## 📂 Repository Structure

```
.
├── docker-compose.yml      # Docker Compose configuration
├── Makefile               # Common operations
├── .env.example           # Environment variables template
├── networks/              # Network-specific configurations
│   ├── pubnet/           # Pubnet configuration
│   ├── testnet/          # Testnet configuration
│   └── futurenet/        # Futurenet configuration
└── scripts/              # Utility scripts
    └── health-check.sh   # Health monitoring script
```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_PASSWORD` | PostgreSQL password (required) | - |
| `STELLAR_NETWORK` | Network to connect to: pubnet, testnet, futurenet | pubnet |
| `HISTORY_ARCHIVE_URLS` | History archive URL for the network | (auto-set based on network) |
| `INGEST` | Enable/disable ingestion | true |
| `HISTORY_RETENTION_COUNT` | Number of ledgers to retain | 518400 (~30 days) |
| `ADMIN_PORT` | Admin port for metrics and pprof | 6060 |
| `LOG_LEVEL` | Log level: debug, info, warn, error | info |

### Network Selection

The kit supports all three Stellar networks:

```bash
# Pubnet (mainnet)
make up NETWORK=pubnet

# Testnet
make up NETWORK=testnet

# Futurenet
make up NETWORK=futurenet
```

## 📊 Monitoring

### Health Checks

```bash
# Check if Horizon is healthy and synced
make health

# Or use the script directly
./scripts/health-check.sh
```

### Metrics

Prometheus metrics are available at `http://localhost:6060/metrics` when `ADMIN_PORT` is configured.

### Logs

```bash
# Follow logs
make logs

# Check sync progress
docker compose logs -f horizon | grep -E 'Processed ledger|Closed ledger'
```

## 🛠️ Operations

### Common Tasks

```bash
# Start the stack
make up

# Stop the stack
make down

# Restart services
make restart

# View logs
make logs

# Check health
make health

# Update Horizon
make update

# Clean all data (WARNING: destructive)
make clean
```

### Database Management

```bash
# Initialize new database
make init

# Run migrations after update
docker compose run --rm horizon stellar-horizon db migrate up
```

## 🔄 Upgrading

To upgrade Horizon to a new version:

1. Update the image tag in `docker-compose.yml`
2. Run the update command:

```bash
make update
```

This will:
- Pull the new image
- Run database migrations
- Restart the service

## 🏗️ Scaling

### Single Instance (Default)
The default configuration runs all Horizon roles in a single container: ingestion, API serving, and transaction submission.

### Horizontal Scaling
For production deployments with higher load, you can split Horizon into dedicated roles:

1. **Ingestion node**: Set `INGEST=true`, `DISABLE_TX_SUB=true`
2. **API nodes**: Set `INGEST=false`, `DISABLE_TX_SUB=true`
3. **Transaction submission nodes**: Set `INGEST=false`

All instances share the same PostgreSQL database.

## 🛡️ Production Checklist

- [ ] Set strong `DB_PASSWORD` in `.env`
- [ ] Configure automated PostgreSQL backups
- [ ] Set up TLS termination (nginx/traefik)
- [ ] Configure Prometheus monitoring
- [ ] Set up alerts for ingestion lag
- [ ] Configure log rotation
- [ ] Monitor system resources (CPU, memory, disk)
- [ ] Plan for PostgreSQL maintenance
- [ ] Document your deployment procedures

## 🐘 PostgreSQL Optimization

For optimal performance on SSDs, add to your PostgreSQL configuration:

```sql
ALTER SYSTEM SET random_page_cost = 1;
SELECT pg_reload_conf();
```

## 🆚 Differences from stellar/quickstart

| Feature | This Kit | stellar/quickstart |
|---------|----------|-------------------|
| **Purpose** | Production-ready | Development only |
| **Architecture** | Separate containers | All-in-one |
| **Data persistence** | Named volumes | Container filesystem |
| **Configuration** | Environment variables | Command-line flags |
| **Security** | Production practices | Development defaults |
| **Monitoring** | Built-in health checks | Basic only |

## 📚 Resources

- [Horizon Admin Guide](https://developers.stellar.org/docs/data/apis/horizon/admin-guide/overview)
- [Stellar Network Dashboard](https://dashboard.stellar.org/)
- [Official Helm Charts](https://github.com/stellar/helm-charts)
- [Docker Hub Images](https://hub.docker.com/r/stellar/stellar-horizon)

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.