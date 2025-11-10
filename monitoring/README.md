# BofhContract V2 - Complete Monitoring Stack

Production-grade monitoring solution for BofhContract V2 using Prometheus, Grafana, and AlertManager.

## Overview

This monitoring stack provides complete observability for BofhContract V2 deployments with:

- **Real-time Event Indexing** - Monitors all contract events and exposes Prometheus metrics
- **Metrics Collection** - Prometheus scrapes and stores time-series data
- **Visualization** - Grafana dashboards for monitoring swap performance, gas usage, and security
- **Alerting** - AlertManager routes critical alerts to Slack, email, or PagerDuty
- **System Metrics** - Node Exporter tracks server health

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     BSC Blockchain                              │
│                  BofhContract V2 (deployed)                     │
└───────────────────────────┬─────────────────────────────────────┘
                            │ Events
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Event Indexer (Node.js)                       │
│  • Listens to contract events                                   │
│  • Exposes Prometheus metrics on :9090/metrics                  │
│  • Health check endpoint on :9090/health                        │
└───────────────────────────┬─────────────────────────────────────┘
                            │ Metrics
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Prometheus :9091                              │
│  • Scrapes metrics every 15s                                    │
│  • Stores time-series data (15 days retention)                  │
│  • Evaluates alert rules                                        │
└───────────────────┬───────────────┬─────────────────────────────┘
                    │               │
          Metrics   │               │ Alerts
                    ▼               ▼
    ┌───────────────────┐  ┌───────────────────┐
    │   Grafana :3000   │  │ AlertManager :9093│
    │  • Dashboards     │  │ • Routes alerts   │
    │  • Visualization  │  │ • Slack/Email/PD  │
    └───────────────────┘  └───────────────────┘
```

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- BofhContract V2 deployed on BSC testnet or mainnet
- Contract address available

### 1. Configuration

```bash
# Copy environment template
cp .env.example .env

# Edit .env file with your contract address
nano .env
```

**Required:**
- `CONTRACT_ADDRESS` - Your deployed BofhContract V2 address

**Optional:**
- `NETWORK` - Network to monitor (default: bscTestnet)
- `RPC_URL` - Custom RPC endpoint
- `GRAFANA_ADMIN_PASSWORD` - Change default Grafana password

### 2. Start the Stack

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Check service health
docker-compose ps
```

### 3. Access Services

Once running, access the monitoring stack:

| Service | URL | Default Credentials |
|:--------|:----|:-------------------|
| **Grafana** | http://localhost:3000 | admin/admin |
| **Prometheus** | http://localhost:9091 | - |
| **AlertManager** | http://localhost:9093 | - |
| **Event Indexer** | http://localhost:9090/metrics | - |
| **Node Exporter** | http://localhost:9100/metrics | - |

### 4. Configure Grafana Dashboard

1. Open http://localhost:3000
2. Login with admin/admin (change password on first login)
3. Navigate to **Dashboards** → **Browse**
4. Open **BofhContract V2 - Overview Dashboard**
5. You should see metrics being collected

### 5. Configure Alerts

Edit `alertmanager/config.yml` to configure Slack/email/PagerDuty:

```yaml
slack_configs:
  - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
    channel: '#critical-alerts'
```

Then restart the stack:

```bash
docker-compose restart alertmanager
```

## Components

### Event Indexer

**Purpose:** Monitors BofhContract events and exposes Prometheus metrics

**Features:**
- Real-time event listening
- Prometheus metrics export
- Health check endpoint
- Automatic reconnection on RPC failures
- Structured logging (Winston)

**Metrics Exported:**

| Metric | Type | Description |
|:-------|:-----|:-----------|
| `bofh_total_swaps` | Counter | Total swaps executed |
| `bofh_successful_swaps` | Counter | Successful swaps |
| `bofh_failed_swaps` | Counter | Failed swaps |
| `bofh_gas_used` | Gauge | Gas used per swap |
| `bofh_profit_bnb` | Gauge | Profit per swap (BNB) |
| `bofh_price_impact_percent` | Gauge | Price impact % |
| `bofh_total_profit_bnb` | Counter | Cumulative profit |
| `bofh_mev_protection_triggers` | Counter | MEV protection triggers |
| `bofh_contract_paused` | Gauge | Contract pause state |
| `bofh_pools_blacklisted_total` | Counter | Blacklisted pools |

**Configuration:**

Environment variables in `.env`:
- `NETWORK` - Network name
- `RPC_URL` - Blockchain RPC endpoint
- `CONTRACT_ADDRESS` - Contract to monitor
- `METRICS_PORT` - Metrics endpoint port (default: 9090)
- `POLL_INTERVAL` - State polling interval (default: 15000ms)
- `LOG_LEVEL` - Logging level (info, debug, warn, error)

### Prometheus

**Purpose:** Collects and stores time-series metrics

**Features:**
- 15-second scrape interval
- 15-day data retention
- Alert rule evaluation
- Web UI for queries and exploration

**Configuration:** `prometheus/prometheus.yml`

**Access:** http://localhost:9091

**Example Queries:**
```promql
# Success rate over last 5 minutes
(bofh_successful_swaps / bofh_total_swaps) * 100

# Average gas usage (5min window)
avg_over_time(bofh_gas_used[5m])

# Swap rate per second
rate(bofh_total_swaps[1m])
```

### Grafana

**Purpose:** Visualization dashboards

**Features:**
- Pre-configured BofhContract dashboard
- 12 visualization panels
- Real-time data updates (10s refresh)
- Threshold-based color coding
- Historical data analysis

**Dashboard Panels:**
1. Total Swaps (gauge)
2. Success Rate (gauge with thresholds)
3. Total Profit (BNB)
4. Contract Status
5. Swap Rate (time series)
6. Gas Usage (time series with average)
7. Price Impact (time series)
8. Profit per Swap (bar chart)
9. MEV Protection Status
10. MEV Triggers Count
11. Blacklisted Pools Count
12. Swap Path Length Distribution

**Access:** http://localhost:3000

### AlertManager

**Purpose:** Routes and manages alerts

**Features:**
- Severity-based routing (critical, warning, info)
- Alert grouping and deduplication
- Inhibition rules (suppress related alerts)
- Multiple receiver support (Slack, email, PagerDuty)
- Customizable notification templates

**Alert Rules:**

| Alert | Severity | Threshold | Action |
|:------|:---------|:----------|:-------|
| HighGasUsage | Warning | > 300k gas for 2min | Investigate optimization |
| ExtremeGasUsage | Critical | > 400k gas for 1min | Immediate action |
| LowSuccessRate | Warning | < 95% for 5min | Check liquidity/MEV |
| CriticalSuccessRate | Critical | < 90% for 2min | Consider pausing |
| HighPriceImpact | Warning | > 5% for 1min | Review swap sizes |
| ExtremePriceImpact | Critical | > 10% for 30s | Immediate review |
| ContractPaused | Warning | Paused for 1min | Informational |
| MEVProtectionDisabled | Warning | Disabled for 5min | Security risk |
| IndexerDown | Critical | Service down 1min | Restart service |

**Configuration:** `alertmanager/config.yml`

**Access:** http://localhost:9093

### Node Exporter

**Purpose:** System metrics (CPU, memory, disk, network)

**Features:**
- Host system metrics
- Useful for capacity planning
- Helps correlate contract performance with system load

**Access:** http://localhost:9100/metrics

## Management Commands

### Start/Stop

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# Stop and remove volumes (CAUTION: deletes all data)
docker-compose down -v
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f event-indexer
docker-compose logs -f prometheus
docker-compose logs -f grafana
```

### Restart Services

```bash
# Restart all
docker-compose restart

# Restart specific service
docker-compose restart event-indexer
docker-compose restart prometheus
```

### Check Health

```bash
# Service status
docker-compose ps

# Event indexer health
curl http://localhost:9090/health

# Prometheus health
curl http://localhost:9091/-/healthy

# AlertManager health
curl http://localhost:9093/-/healthy
```

### Update Services

```bash
# Pull latest images
docker-compose pull

# Rebuild event indexer
docker-compose build event-indexer

# Restart with new images
docker-compose up -d
```

## Troubleshooting

### Event Indexer Not Connecting

**Symptoms:**
```
Failed to connect to blockchain
```

**Solutions:**
1. Verify `CONTRACT_ADDRESS` in `.env`
2. Check RPC endpoint is reachable
3. Verify network selection (bscTestnet vs bsc)
4. Check contract is deployed at address

```bash
# Test RPC connection
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  https://data-seed-prebsc-1-s1.binance.org:8545
```

### No Metrics in Grafana

**Symptoms:**
- Dashboard shows "No data"
- Panels are empty

**Solutions:**
1. Check Prometheus is scraping successfully:
   - Open http://localhost:9091/targets
   - Verify `bofh-event-indexer` target is "UP"
2. Check event indexer metrics endpoint:
   - Open http://localhost:9090/metrics
   - Verify metrics are being exported
3. Check Grafana data source:
   - Grafana → Configuration → Data Sources
   - Test Prometheus connection

### Alerts Not Firing

**Symptoms:**
- No Slack/email notifications
- Alerts not showing in AlertManager

**Solutions:**
1. Check AlertManager configuration:
   ```bash
   docker-compose exec alertmanager amtool check-config /etc/alertmanager/config.yml
   ```
2. Verify webhook URLs are correct in `alertmanager/config.yml`
3. Check AlertManager UI: http://localhost:9093
4. Test Slack webhook:
   ```bash
   curl -X POST -H 'Content-type: application/json' \
     --data '{"text":"Test alert"}' \
     YOUR_SLACK_WEBHOOK_URL
   ```

### High Memory Usage

**Symptoms:**
- Prometheus using excessive memory
- System slowdown

**Solutions:**
1. Reduce retention period in `docker-compose.yml`:
   ```yaml
   - '--storage.tsdb.retention.time=7d'  # Reduce from 15d
   ```
2. Increase Docker memory limit
3. Add resource limits to `docker-compose.yml`:
   ```yaml
   prometheus:
     deploy:
       resources:
         limits:
           memory: 2G
   ```

### Container Keeps Restarting

**Symptoms:**
```
docker-compose ps
# Shows container restarting repeatedly
```

**Solutions:**
1. Check logs for errors:
   ```bash
   docker-compose logs event-indexer
   ```
2. Verify `.env` file is present and valid
3. Check Docker has enough resources
4. Rebuild container:
   ```bash
   docker-compose up -d --build event-indexer
   ```

## Production Deployment

### Security Hardening

1. **Change default passwords:**
   ```bash
   # In .env
   GRAFANA_ADMIN_PASSWORD=your-strong-password
   ```

2. **Enable HTTPS:**
   - Use reverse proxy (nginx, Caddy)
   - Configure SSL certificates
   - Update Grafana root URL

3. **Restrict network access:**
   ```yaml
   # In docker-compose.yml
   ports:
     - "127.0.0.1:3000:3000"  # Only localhost
   ```

4. **Enable authentication:**
   - Prometheus: Use basic auth
   - AlertManager: Configure authentication
   - Grafana: Enable OAuth/LDAP

### High Availability

1. **Redundant event indexers:**
   ```yaml
   event-indexer:
     deploy:
       replicas: 3
   ```

2. **Prometheus clustering:**
   - Deploy multiple Prometheus instances
   - Use Thanos for long-term storage

3. **External storage:**
   - Use cloud provider volumes
   - Enable automated backups

### Monitoring the Monitoring

1. **Dead man's switch:**
   ```promql
   # Alert if no metrics received
   up{job="bofh-event-indexer"} == 0
   ```

2. **Watchdog alerts:**
   - Alert if alert manager is down
   - Alert if Prometheus is down

3. **External monitoring:**
   - Pingdom/StatusCake for uptime
   - External health check endpoint

## Cost Estimates

### Infrastructure

| Component | Resources | Monthly Cost (AWS) |
|:----------|:----------|:-------------------|
| Event Indexer | t3.small (2 vCPU, 2GB RAM) | ~$15 |
| Prometheus | t3.small (2 vCPU, 2GB RAM) | ~$15 |
| Grafana/AlertManager | t3.micro (1 vCPU, 1GB RAM) | ~$8 |
| EBS Storage | 50GB | ~$5 |
| **Total** | | **~$43/month** |

### RPC Costs

- Public RPC: Free (rate limited)
- Private RPC (QuickNode/Infura): $50-200/month

**Total estimated monthly cost:** $50-250

## Performance Tuning

### Event Indexer

```javascript
// Adjust polling interval for lower RPC usage
POLL_INTERVAL=30000  // 30 seconds instead of 15

// Reduce log level in production
LOG_LEVEL=warn
```

### Prometheus

```yaml
# Reduce scrape frequency
scrape_interval: 30s  # Instead of 15s

# Shorter retention for less storage
--storage.tsdb.retention.time=7d
```

### Grafana

```json
// Increase refresh interval
"refresh": "30s"  // Instead of 10s
```

## Support

For issues or questions:

1. Check [docs/MONITORING.md](../docs/MONITORING.md) for detailed documentation
2. Review Docker logs: `docker-compose logs -f`
3. Open an issue on GitHub with logs and configuration

## License

UNLICENSED - See LICENSE file in project root

---

**Last Updated:** 2025-11-10
**Version:** 1.0.0
**Maintainer:** Bofh Team
