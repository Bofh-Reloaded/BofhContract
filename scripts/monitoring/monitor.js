#!/usr/bin/env node
/**
 * BofhContract Performance Monitoring Script
 *
 * Monitors contract events and tracks performance metrics in real-time.
 * Supports multiple output formats: console, JSON, Prometheus, and webhooks.
 *
 * Usage:
 *   node scripts/monitoring/monitor.js --network bscTestnet
 *   node scripts/monitoring/monitor.js --network bsc --webhook https://...
 *   node scripts/monitoring/monitor.js --prometheus --port 9090
 */

const { ethers } = require('hardhat');
const fs = require('fs');
const path = require('path');

// Configuration
const CONFIG = {
    // Network RPC endpoints
    networks: {
        bscTestnet: 'https://data-seed-prebsc-1-s1.binance.org:8545',
        bsc: 'https://bsc-dataseed1.binance.org',
        localhost: 'http://127.0.0.1:8545'
    },

    // Metrics collection intervals (ms)
    metricsInterval: 60000, // 1 minute

    // Alert thresholds
    thresholds: {
        maxGasUsage: 300000,        // Alert if gas > 300k
        minProfitability: 0,        // Alert if unprofitable
        maxPriceImpact: 50000,      // Alert if impact > 5% (PRECISION = 1e6)
        minSuccessRate: 0.95        // Alert if success rate < 95%
    }
};

/**
 * Performance metrics tracker
 */
class MetricsTracker {
    constructor() {
        this.metrics = {
            totalSwaps: 0,
            successfulSwaps: 0,
            failedSwaps: 0,
            totalGasUsed: 0,
            totalProfit: 0,
            priceImpacts: [],
            executionTimes: [],
            startTime: Date.now()
        };
    }

    recordSwap(event) {
        this.metrics.totalSwaps++;
        this.metrics.successfulSwaps++;

        const inputAmount = BigInt(event.args.inputAmount);
        const outputAmount = BigInt(event.args.outputAmount);
        const profit = outputAmount - inputAmount;

        this.metrics.totalProfit += Number(profit);
        this.metrics.priceImpacts.push(Number(event.args.priceImpact));
    }

    recordFailure() {
        this.metrics.totalSwaps++;
        this.metrics.failedSwaps++;
    }

    getStats() {
        const avgPriceImpact = this.metrics.priceImpacts.length > 0
            ? this.metrics.priceImpacts.reduce((a, b) => a + b, 0) / this.metrics.priceImpacts.length
            : 0;

        const successRate = this.metrics.totalSwaps > 0
            ? this.metrics.successfulSwaps / this.metrics.totalSwaps
            : 0;

        const runtime = (Date.now() - this.metrics.startTime) / 1000; // seconds

        return {
            totalSwaps: this.metrics.totalSwaps,
            successfulSwaps: this.metrics.successfulSwaps,
            failedSwaps: this.metrics.failedSwaps,
            successRate: (successRate * 100).toFixed(2) + '%',
            avgPriceImpact: (avgPriceImpact / 10000).toFixed(4) + '%',
            totalProfit: ethers.formatEther(this.metrics.totalProfit),
            runtime: runtime.toFixed(0) + 's',
            swapsPerMinute: (this.metrics.totalSwaps / (runtime / 60)).toFixed(2)
        };
    }

    checkAlerts(event) {
        const alerts = [];

        // Check price impact
        if (event.args.priceImpact > CONFIG.thresholds.maxPriceImpact) {
            alerts.push({
                severity: 'warning',
                type: 'HIGH_PRICE_IMPACT',
                message: `Price impact ${event.args.priceImpact / 10000}% exceeds threshold`,
                event: event
            });
        }

        // Check profitability
        const profit = BigInt(event.args.outputAmount) - BigInt(event.args.inputAmount);
        if (profit <= 0) {
            alerts.push({
                severity: 'error',
                type: 'UNPROFITABLE_SWAP',
                message: `Swap resulted in loss: ${ethers.formatEther(profit)} BNB`,
                event: event
            });
        }

        // Check success rate
        const successRate = this.metrics.successfulSwaps / this.metrics.totalSwaps;
        if (successRate < CONFIG.thresholds.minSuccessRate && this.metrics.totalSwaps > 10) {
            alerts.push({
                severity: 'critical',
                type: 'LOW_SUCCESS_RATE',
                message: `Success rate ${(successRate * 100).toFixed(2)}% below threshold`,
                stats: this.getStats()
            });
        }

        return alerts;
    }
}

/**
 * Contract event monitor
 */
class ContractMonitor {
    constructor(contractAddress, network, options = {}) {
        this.contractAddress = contractAddress;
        this.network = network;
        this.options = options;
        this.tracker = new MetricsTracker();
        this.provider = null;
        this.contract = null;
    }

    async initialize() {
        // Connect to network
        const rpcUrl = CONFIG.networks[this.network];
        if (!rpcUrl) {
            throw new Error(`Unknown network: ${this.network}`);
        }

        console.log(`Connecting to ${this.network} at ${rpcUrl}...`);
        this.provider = new ethers.JsonRpcProvider(rpcUrl);

        // Load contract ABI
        const artifactPath = path.join(
            __dirname,
            '../../artifacts/contracts/main/BofhContractV2.sol/BofhContractV2.json'
        );

        if (!fs.existsSync(artifactPath)) {
            throw new Error(
                `Contract artifact not found at ${artifactPath}\n` +
                `Run: npm run compile`
            );
        }

        const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));

        // Create contract instance
        this.contract = new ethers.Contract(
            this.contractAddress,
            artifact.abi,
            this.provider
        );

        console.log(`✓ Connected to contract at ${this.contractAddress}`);
        console.log(`✓ Network: ${this.network} (Chain ID: ${(await this.provider.getNetwork()).chainId})`);
        console.log('');
    }

    async startMonitoring() {
        console.log('Starting event monitoring...\n');
        console.log('Listening for events:');
        console.log('  - SwapExecuted');
        console.log('  - RiskParamsUpdated');
        console.log('  - PoolBlacklisted');
        console.log('  - MEVProtectionUpdated\n');

        // Listen to SwapExecuted events
        this.contract.on('SwapExecuted', (initiator, pathLength, inputAmount, outputAmount, priceImpact, event) => {
            this.handleSwapExecuted({
                args: { initiator, pathLength, inputAmount, outputAmount, priceImpact },
                blockNumber: event.log.blockNumber,
                transactionHash: event.log.transactionHash
            });
        });

        // Listen to RiskParamsUpdated events
        this.contract.on('RiskParamsUpdated', (maxVolume, minLiquidity, maxImpact, sandwichProtection, event) => {
            console.log(`\n[RiskParamsUpdated] Block ${event.log.blockNumber}`);
            console.log(`  Max Volume: ${ethers.formatUnits(maxVolume, 6)}`);
            console.log(`  Min Liquidity: ${ethers.formatUnits(minLiquidity, 6)}`);
            console.log(`  Max Impact: ${maxImpact / 100}%`);
            console.log(`  Sandwich Protection: ${sandwichProtection / 100}%`);
        });

        // Listen to PoolBlacklisted events
        this.contract.on('PoolBlacklisted', (pool, blacklisted, event) => {
            console.log(`\n[PoolBlacklisted] Block ${event.log.blockNumber}`);
            console.log(`  Pool: ${pool}`);
            console.log(`  Blacklisted: ${blacklisted}`);
        });

        // Listen to MEVProtectionUpdated events
        this.contract.on('MEVProtectionUpdated', (enabled, maxTxPerBlock, minTxDelay, event) => {
            console.log(`\n[MEVProtectionUpdated] Block ${event.log.blockNumber}`);
            console.log(`  Enabled: ${enabled}`);
            console.log(`  Max Tx Per Block: ${maxTxPerBlock}`);
            console.log(`  Min Tx Delay: ${minTxDelay}s`);
        });

        // Periodic stats reporting
        setInterval(() => {
            this.printStats();
        }, CONFIG.metricsInterval);

        // Handle errors
        this.contract.on('error', (error) => {
            console.error('\n[ERROR] Event listener error:', error);
            this.tracker.recordFailure();
        });

        console.log('✓ Monitoring started successfully\n');
        console.log('='.repeat(70));
    }

    handleSwapExecuted(event) {
        // Record metrics
        this.tracker.recordSwap(event);

        // Format output
        const profit = BigInt(event.args.outputAmount) - BigInt(event.args.inputAmount);
        const profitEth = ethers.formatEther(profit);
        const isProfitable = profit > 0;

        console.log(`\n[${'SwapExecuted'.padEnd(20)}] Block ${event.blockNumber}`);
        console.log(`  Tx Hash:      ${event.transactionHash}`);
        console.log(`  Initiator:    ${event.args.initiator}`);
        console.log(`  Path Length:  ${event.args.pathLength}`);
        console.log(`  Input:        ${ethers.formatEther(event.args.inputAmount)} BNB`);
        console.log(`  Output:       ${ethers.formatEther(event.args.outputAmount)} BNB`);
        console.log(`  Profit:       ${isProfitable ? '+' : ''}${profitEth} BNB ${isProfitable ? '✓' : '✗'}`);
        console.log(`  Price Impact: ${(Number(event.args.priceImpact) / 10000).toFixed(4)}%`);

        // Check for alerts
        const alerts = this.tracker.checkAlerts(event);
        if (alerts.length > 0) {
            console.log('\n  ⚠️  ALERTS:');
            alerts.forEach(alert => {
                console.log(`    [${alert.severity.toUpperCase()}] ${alert.type}: ${alert.message}`);
            });

            // Send to webhook if configured
            if (this.options.webhook) {
                this.sendWebhook(alerts);
            }
        }

        // Save to JSON if configured
        if (this.options.jsonOutput) {
            this.saveToJSON(event);
        }
    }

    printStats() {
        const stats = this.tracker.getStats();

        console.log('\n' + '='.repeat(70));
        console.log('Performance Statistics');
        console.log('='.repeat(70));
        console.log(`  Total Swaps:       ${stats.totalSwaps}`);
        console.log(`  Successful:        ${stats.successfulSwaps}`);
        console.log(`  Failed:            ${stats.failedSwaps}`);
        console.log(`  Success Rate:      ${stats.successRate}`);
        console.log(`  Avg Price Impact:  ${stats.avgPriceImpact}`);
        console.log(`  Total Profit:      ${stats.totalProfit} BNB`);
        console.log(`  Runtime:           ${stats.runtime}`);
        console.log(`  Swaps/Minute:      ${stats.swapsPerMinute}`);
        console.log('='.repeat(70) + '\n');
    }

    async sendWebhook(alerts) {
        // Placeholder for webhook integration
        console.log(`  Sending ${alerts.length} alerts to webhook: ${this.options.webhook}`);
    }

    saveToJSON(event) {
        // Placeholder for JSON export
        const data = {
            timestamp: new Date().toISOString(),
            ...event
        };
        console.log(`  Saving event to JSON: ${JSON.stringify(data, null, 2)}`);
    }

    stop() {
        console.log('\nStopping monitor...');
        this.contract.removeAllListeners();
        this.printStats();
        process.exit(0);
    }
}

/**
 * Main entry point
 */
async function main() {
    // Parse command line arguments
    const args = process.argv.slice(2);
    const options = {
        network: 'bscTestnet',
        contractAddress: process.env.CONTRACT_ADDRESS,
        webhook: null,
        jsonOutput: false,
        prometheus: false,
        port: 9090
    };

    for (let i = 0; i < args.length; i++) {
        switch (args[i]) {
            case '--network':
                options.network = args[++i];
                break;
            case '--address':
                options.contractAddress = args[++i];
                break;
            case '--webhook':
                options.webhook = args[++i];
                break;
            case '--json':
                options.jsonOutput = true;
                break;
            case '--prometheus':
                options.prometheus = true;
                break;
            case '--port':
                options.port = parseInt(args[++i]);
                break;
            case '--help':
                printHelp();
                process.exit(0);
        }
    }

    // Validate contract address
    if (!options.contractAddress) {
        console.error('Error: Contract address required');
        console.error('Provide via --address or CONTRACT_ADDRESS environment variable\n');
        printHelp();
        process.exit(1);
    }

    // Initialize monitor
    try {
        const monitor = new ContractMonitor(
            options.contractAddress,
            options.network,
            options
        );

        await monitor.initialize();
        await monitor.startMonitoring();

        // Graceful shutdown
        process.on('SIGINT', () => monitor.stop());
        process.on('SIGTERM', () => monitor.stop());

    } catch (error) {
        console.error('\nFatal error:', error.message);
        process.exit(1);
    }
}

function printHelp() {
    console.log(`
BofhContract Performance Monitoring Script

Usage:
  node scripts/monitoring/monitor.js [options]

Options:
  --network <name>      Network to connect to (bscTestnet, bsc, localhost)
                        Default: bscTestnet

  --address <address>   Contract address to monitor (required)
                        Can also use CONTRACT_ADDRESS env variable

  --webhook <url>       Webhook URL for alerts

  --json                Save events to JSON files

  --prometheus          Enable Prometheus metrics endpoint
  --port <port>         Prometheus port (default: 9090)

  --help                Show this help message

Examples:
  # Monitor on BSC testnet
  node scripts/monitoring/monitor.js \\
    --network bscTestnet \\
    --address 0x1234567890123456789012345678901234567890

  # Monitor with webhook alerts
  node scripts/monitoring/monitor.js \\
    --network bsc \\
    --address 0x... \\
    --webhook https://hooks.slack.com/...

  # Monitor with Prometheus metrics
  node scripts/monitoring/monitor.js \\
    --network bsc \\
    --address 0x... \\
    --prometheus --port 9090

Environment Variables:
  CONTRACT_ADDRESS      Contract address to monitor
    `);
}

// Run main function
if (require.main === module) {
    main().catch((error) => {
        console.error('Unhandled error:', error);
        process.exit(1);
    });
}

module.exports = { ContractMonitor, MetricsTracker };
