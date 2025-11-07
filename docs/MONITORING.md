# BofhContract V2 Performance Monitoring Guide

Comprehensive guide for monitoring BofhContract V2 performance, metrics, and alerts.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Monitoring Script](#monitoring-script)
- [Grafana Dashboard](#grafana-dashboard)
- [Prometheus Metrics](#prometheus-metrics)
- [Alert Rules](#alert-rules)
- [Integration Examples](#integration-examples)
- [Troubleshooting](#troubleshooting)

---

## Overview

BofhContract V2 includes comprehensive monitoring capabilities for tracking:

- **Gas Usage** - Track gas consumption per swap
- **Success Rates** - Monitor swap success/failure rates
- **Profitability** - Track profit/loss on each swap
- **Price Impact** - Monitor price impact across swaps
- **MEV Protection** - Track MEV protection effectiveness
- **Contract State** - Monitor paused state, risk parameters, blacklisted pools

### Monitoring Stack

The recommended monitoring stack includes:

- **Event Listener** - JavaScript script monitoring contract events
- **Prometheus** - Metrics collection and storage
- **Grafana** - Visualization and dashboards
- **Alertmanager** - Alert routing and notifications

---

## Quick Start

### Prerequisites

```bash
# Install dependencies
npm install

# Compile contracts
npm run compile
```

### Start Monitoring

```bash
# Basic monitoring (BSC Testnet)
CONTRACT_ADDRESS=0x... node scripts/monitoring/monitor.js

# With options
node scripts/monitoring/monitor.js \
  --network bscTestnet \
  --address 0x... \
  --webhook https://hooks.slack.com/...
```

### View Live Stats

The monitoring script outputs:
- Real-time swap events
- Periodic performance statistics
- Alerts for anomalies

**Example Output:**
```
[SwapExecuted            ] Block 45123456
  Tx Hash:      0xabc123...
  Initiator:    0x1234...
  Path Length:  3
  Input:        1.0 BNB
  Output:       1.005 BNB
  Profit:       +0.005 BNB ✓
  Price Impact: 0.4500%

==================================================
Performance Statistics
==================================================
  Total Swaps:       127
  Successful:        125
  Failed:            2
  Success Rate:      98.43%
  Avg Price Impact:  0.5234%
  Total Profit:      0.635 BNB
  Runtime:           3600s
  Swaps/Minute:      2.12
==================================================
```

---

## Monitoring Script

### Basic Usage

```bash
node scripts/monitoring/monitor.js --address CONTRACT_ADDRESS
```

### Command-Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--network <name>` | Network to connect to (bscTestnet, bsc, localhost) | `bscTestnet` |
| `--address <address>` | Contract address to monitor (required) | - |
| `--webhook <url>` | Webhook URL for alerts | - |
| `--json` | Save events to JSON files | `false` |
| `--prometheus` | Enable Prometheus metrics endpoint | `false` |
| `--port <port>` | Prometheus port | `9090` |
| `--help` | Show help message | - |

### Environment Variables

```bash
# Set contract address via environment variable
export CONTRACT_ADDRESS=0x1234567890123456789012345678901234567890

# Run monitor
node scripts/monitoring/monitor.js --network bsc
```

### Monitored Events

The script listens to the following contract events:

#### SwapExecuted
```solidity
event SwapExecuted(
    address indexed initiator,
    uint256 pathLength,
    uint256 inputAmount,
    uint256 outputAmount,
    uint256 priceImpact
);
```

**Tracked Metrics:**
- Initiator address
- Swap path length
- Input/output amounts
- Calculated profit/loss
- Price impact percentage

#### RiskParamsUpdated
```solidity
event RiskParamsUpdated(
    uint256 maxTradeVolume,
    uint256 minPoolLiquidity,
    uint256 maxPriceImpact,
    uint256 sandwichProtectionBips
);
```

**Tracked Changes:**
- Maximum trade volume
- Minimum pool liquidity
- Maximum price impact threshold
- Sandwich protection basis points

#### PoolBlacklisted
```solidity
event PoolBlacklisted(
    address indexed pool,
    bool blacklisted
);
```

**Tracked State:**
- Pool address
- Blacklist status

#### MEVProtectionUpdated
```solidity
event MEVProtectionUpdated(
    bool enabled,
    uint256 maxTxPerBlock,
    uint256 minTxDelay
);
```

**Tracked Configuration:**
- MEV protection enabled/disabled
- Maximum transactions per block
- Minimum transaction delay

### Alert Thresholds

The monitoring script includes configurable alert thresholds:

```javascript
const thresholds = {
    maxGasUsage: 300000,        // Alert if gas > 300k
    minProfitability: 0,        // Alert if unprofitable
    maxPriceImpact: 50000,      // Alert if impact > 5% (PRECISION = 1e6)
    minSuccessRate: 0.95        // Alert if success rate < 95%
};
```

**Alert Types:**

1. **High Price Impact** (Warning)
   - Triggered when price impact > 5%
   - Indicates large trade relative to pool size

2. **Unprofitable Swap** (Error)
   - Triggered when output < input
   - Indicates losing trade

3. **Low Success Rate** (Critical)
   - Triggered when success rate < 95% (after 10+ swaps)
   - Indicates systemic issues

---

## Grafana Dashboard

### Installation

1. **Install Grafana:**
```bash
# macOS
brew install grafana
brew services start grafana

# Ubuntu/Debian
sudo apt-get install -y grafana
sudo systemctl start grafana-server

# Docker
docker run -d -p 3000:3000 --name=grafana grafana/grafana
```

2. **Access Grafana:**
   - Open http://localhost:3000
   - Default login: admin/admin

3. **Import Dashboard:**
   - Navigate to Dashboards → Import
   - Upload `scripts/monitoring/grafana-dashboard.json`
   - Select Prometheus data source
   - Click Import

### Dashboard Panels

The BofhContract V2 dashboard includes 7 panels:

#### 1. Total Swaps (Gauge)
- **Metric:** `bofh_total_swaps`
- **Description:** Total number of swaps executed
- **Type:** Gauge

#### 2. Success Rate (Gauge)
- **Metric:** `(bofh_successful_swaps / bofh_total_swaps) * 100`
- **Description:** Percentage of successful swaps
- **Thresholds:** Green > 95%, Yellow > 90%, Red < 90%
- **Type:** Gauge

#### 3. Swap Rate (Time Series)
- **Metric:** `rate(bofh_total_swaps[5m])`
- **Description:** Swaps per second over 5-minute window
- **Type:** Line chart

#### 4. Gas Usage (Time Series)
- **Metrics:**
  - `bofh_gas_used` - Actual gas used
  - `avg_over_time(bofh_gas_used[5m])` - 5-minute average
- **Description:** Gas consumption per swap
- **Thresholds:** Green < 250k, Yellow < 300k, Red > 300k
- **Type:** Line chart

#### 5. Profit Distribution (Time Series)
- **Metric:** `bofh_profit_bnb`
- **Description:** Profit/loss per swap in BNB
- **Thresholds:** Red < 0, Yellow = 0, Green > 0.001
- **Type:** Bar chart

#### 6. Price Impact (Time Series)
- **Metrics:**
  - `bofh_price_impact_percent` - Actual price impact
  - `avg_over_time(bofh_price_impact_percent[5m])` - 5-minute average
- **Description:** Price impact percentage per swap
- **Thresholds:** Green < 3%, Yellow < 5%, Red > 5%
- **Type:** Line chart

#### 7. Recent Swaps (Table)
- **Metric:** `topk(10, bofh_swap_events)`
- **Description:** Last 10 swap events with details
- **Type:** Table

### Customization

Edit the dashboard JSON to customize:

```json
{
  "panels": [
    {
      "id": 1,
      "title": "Custom Panel",
      "targets": [
        {
          "expr": "your_prometheus_query",
          "refId": "A"
        }
      ]
    }
  ]
}
```

---

## Prometheus Metrics

### Exported Metrics

The monitoring system exports the following Prometheus metrics:

| Metric Name | Type | Description |
|-------------|------|-------------|
| `bofh_total_swaps` | Counter | Total number of swaps executed |
| `bofh_successful_swaps` | Counter | Number of successful swaps |
| `bofh_failed_swaps` | Counter | Number of failed swaps |
| `bofh_gas_used` | Gauge | Gas used by last swap |
| `bofh_profit_bnb` | Gauge | Profit in BNB for last swap |
| `bofh_price_impact_percent` | Gauge | Price impact % for last swap |
| `bofh_total_profit_bnb` | Counter | Cumulative profit in BNB |
| `bofh_mev_protection_triggers` | Counter | Times MEV protection triggered |
| `bofh_contract_paused` | Gauge | Contract pause state (0/1) |
| `bofh_max_price_impact` | Gauge | Current max price impact setting |
| `bofh_pools_blacklisted` | Counter | Number of blacklisted pools |
| `bofh_avg_pool_volatility` | Gauge | Average pool volatility |

### Prometheus Configuration

**prometheus.yml:**
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'bofhcontract'
    static_configs:
      - targets: ['localhost:9090']
    metric_relabel_configs:
      - source_labels: [__name__]
        regex: 'bofh_.*'
        action: keep
```

### Starting Prometheus

```bash
# macOS
brew install prometheus
prometheus --config.file=prometheus.yml

# Ubuntu/Debian
sudo apt-get install prometheus
sudo systemctl start prometheus

# Docker
docker run -d -p 9090:9090 \
  -v $(pwd)/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus
```

Access Prometheus UI: http://localhost:9090

---

## Alert Rules

### Prometheus Alert Configuration

Place `scripts/monitoring/alerts.yml` in your Prometheus configuration directory.

**Load alerts in prometheus.yml:**
```yaml
rule_files:
  - 'alerts.yml'

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - 'localhost:9093'
```

### Alert Categories

#### 1. Gas Usage Alerts

**HighGasUsage** (Warning)
- **Condition:** `bofh_gas_used > 300000` for 2 minutes
- **Action:** Investigate gas optimization opportunities

**ExtremeGasUsage** (Critical)
- **Condition:** `bofh_gas_used > 400000` for 1 minute
- **Action:** Immediate investigation required

#### 2. Success Rate Alerts

**LowSuccessRate** (Warning)
- **Condition:** Success rate < 95% for 5 minutes
- **Action:** Check pool liquidity and MEV protection

**CriticalSuccessRate** (Critical)
- **Condition:** Success rate < 90% for 2 minutes
- **Action:** Consider pausing contract

#### 3. Price Impact Alerts

**HighPriceImpact** (Warning)
- **Condition:** Price impact > 5% for 1 minute
- **Action:** Review swap amounts and pool sizes

**ExtremePriceImpact** (Critical)
- **Condition:** Price impact > 10% for 30 seconds
- **Action:** Immediate review required

#### 4. Profitability Alerts

**UnprofitableSwaps** (Warning)
- **Condition:** Failed swap rate > 10% of successful swaps for 3 minutes
- **Action:** Review fee structures and market conditions

**NegativeTotalProfit** (Critical)
- **Condition:** Total profit < 0 for 10 minutes
- **Action:** Pause trading and investigate

### Alertmanager Configuration

**alertmanager.yml:**
```yaml
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'component']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default'
  routes:
    - match:
        severity: critical
      receiver: 'critical-alerts'
    - match:
        severity: warning
      receiver: 'warning-alerts'

receivers:
  - name: 'default'
    webhook_configs:
      - url: 'http://localhost:5001/'

  - name: 'critical-alerts'
    slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#critical-alerts'
        title: '🚨 Critical Alert: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'

  - name: 'warning-alerts'
    slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#warnings'
        title: '⚠️ Warning: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

---

## Integration Examples

### Slack Webhook Integration

```bash
node scripts/monitoring/monitor.js \
  --address 0x... \
  --webhook https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

**Slack Message Format:**
```json
{
  "text": "🚨 Alert: High Price Impact",
  "attachments": [
    {
      "color": "warning",
      "fields": [
        {
          "title": "Price Impact",
          "value": "6.5%",
          "short": true
        },
        {
          "title": "Threshold",
          "value": "5.0%",
          "short": true
        }
      ]
    }
  ]
}
```

### Discord Webhook Integration

Similar to Slack, use Discord webhook URL:

```bash
node scripts/monitoring/monitor.js \
  --address 0x... \
  --webhook https://discord.com/api/webhooks/YOUR/WEBHOOK
```

### Custom Webhook Handler

```javascript
// webhook-handler.js
const express = require('express');
const app = express();

app.post('/webhook', express.json(), (req, res) => {
    const alert = req.body;
    console.log('Received alert:', alert);

    // Process alert
    if (alert.severity === 'critical') {
        // Send to PagerDuty, email, etc.
        sendCriticalAlert(alert);
    }

    res.status(200).send('OK');
});

app.listen(5001);
```

---

## Troubleshooting

### Common Issues

#### 1. No Events Detected

**Symptoms:**
```
No swap activity detected in the last 15 minutes
```

**Solutions:**
- Verify contract address is correct
- Check network connection
- Ensure contract has been deployed
- Verify swaps are actually occurring on-chain

#### 2. Connection Errors

**Symptoms:**
```
Error: Failed to connect to https://...
```

**Solutions:**
- Check RPC endpoint availability
- Try alternative RPC endpoint
- Verify network selection (bscTestnet vs bsc)
- Check firewall/proxy settings

#### 3. Missing Contract Artifacts

**Symptoms:**
```
Contract artifact not found at artifacts/contracts/...
```

**Solutions:**
```bash
# Compile contracts
npm run compile

# Verify artifact exists
ls -la artifacts/contracts/main/BofhContractV2.sol/
```

#### 4. High Memory Usage

**Symptoms:**
- Script consuming excessive memory
- Slow performance over time

**Solutions:**
- Reduce metrics retention period
- Implement metric pruning
- Restart monitor periodically

### Debug Mode

Enable verbose logging:

```bash
NODE_ENV=development node scripts/monitoring/monitor.js \
  --address 0x...
```

### Testing Monitoring

Generate test events on local network:

```bash
# Start local Hardhat node
npx hardhat node

# Deploy contract
npx hardhat run scripts/deploy.js --network localhost

# Monitor local contract
node scripts/monitoring/monitor.js \
  --network localhost \
  --address DEPLOYED_ADDRESS

# Execute test swaps (in another terminal)
npx hardhat run scripts/test-swap.js --network localhost
```

---

## Best Practices

### 1. Monitoring Checklist

- [ ] Monitor running 24/7 with process manager (PM2, systemd)
- [ ] Alerts configured for critical metrics
- [ ] Grafana dashboards accessible to team
- [ ] Webhook notifications to Slack/Discord
- [ ] Backup monitoring solution (redundancy)
- [ ] Regular review of alert thresholds
- [ ] Documented escalation procedures

### 2. Alert Fatigue Prevention

- Set appropriate thresholds to avoid false positives
- Use alert grouping (Alertmanager)
- Implement alert suppression during maintenance
- Regular review and tuning of alert rules

### 3. Data Retention

- Prometheus: 15 days default
- Grafana: Configure based on needs
- Export critical data for long-term storage

### 4. Security

- Restrict Grafana access (authentication)
- Secure Prometheus endpoint
- Use HTTPS for webhooks
- Rotate API keys regularly

---

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [BofhContract API Reference](./API_REFERENCE.md)
- [Deployment Guide](./DEPLOYMENT.md)

---

**Last Updated:** 2025-11-07
**Version:** 1.0
**Maintainer:** BofhContract Team
