/**
 * BofhContract Event Indexer with Prometheus Metrics
 *
 * This service monitors BofhContract events and exposes Prometheus metrics
 * for production monitoring with Grafana dashboards.
 */

const { ethers } = require('ethers');
const express = require('express');
const promClient = require('prom-client');
const winston = require('winston');
require('dotenv').config();

// ============================================================================
// Configuration
// ============================================================================

const CONFIG = {
    // Network configuration
    network: process.env.NETWORK || 'bscTestnet',
    rpcUrl: process.env.RPC_URL || 'https://data-seed-prebsc-1-s1.binance.org:8545',
    contractAddress: process.env.CONTRACT_ADDRESS,

    // Server configuration
    metricsPort: parseInt(process.env.METRICS_PORT || '9090'),

    // Monitoring configuration
    pollInterval: parseInt(process.env.POLL_INTERVAL || '15000'), // 15 seconds
    startBlock: parseInt(process.env.START_BLOCK || 'latest'),
};

// Validate required configuration
if (!CONFIG.contractAddress) {
    console.error('ERROR: CONTRACT_ADDRESS environment variable is required');
    process.exit(1);
}

// ============================================================================
// Logger Setup
// ============================================================================

const logger = winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json()
    ),
    transports: [
        new winston.transports.Console({
            format: winston.format.combine(
                winston.format.colorize(),
                winston.format.simple()
            )
        }),
        new winston.transports.File({ filename: 'indexer-error.log', level: 'error' }),
        new winston.transports.File({ filename: 'indexer-combined.log' })
    ]
});

// ============================================================================
// Prometheus Metrics Setup
// ============================================================================

// Create a Registry
const register = new promClient.Registry();

// Add default metrics (CPU, memory, etc.)
promClient.collectDefaultMetrics({ register });

// Custom metrics for BofhContract
const metrics = {
    // Counters
    totalSwaps: new promClient.Counter({
        name: 'bofh_total_swaps',
        help: 'Total number of swaps executed',
        registers: [register]
    }),

    successfulSwaps: new promClient.Counter({
        name: 'bofh_successful_swaps',
        help: 'Number of successful swaps',
        registers: [register]
    }),

    failedSwaps: new promClient.Counter({
        name: 'bofh_failed_swaps',
        help: 'Number of failed swaps',
        registers: [register]
    }),

    totalProfitBnb: new promClient.Counter({
        name: 'bofh_total_profit_bnb',
        help: 'Cumulative profit in BNB',
        registers: [register]
    }),

    mevProtectionTriggers: new promClient.Counter({
        name: 'bofh_mev_protection_triggers',
        help: 'Times MEV protection was triggered',
        registers: [register]
    }),

    poolsBlacklisted: new promClient.Counter({
        name: 'bofh_pools_blacklisted_total',
        help: 'Number of pools blacklisted',
        registers: [register]
    }),

    // Gauges
    gasUsed: new promClient.Gauge({
        name: 'bofh_gas_used',
        help: 'Gas used by last swap',
        registers: [register]
    }),

    profitBnb: new promClient.Gauge({
        name: 'bofh_profit_bnb',
        help: 'Profit in BNB for last swap',
        registers: [register]
    }),

    priceImpactPercent: new promClient.Gauge({
        name: 'bofh_price_impact_percent',
        help: 'Price impact percentage for last swap',
        registers: [register]
    }),

    contractPaused: new promClient.Gauge({
        name: 'bofh_contract_paused',
        help: 'Contract pause state (0=active, 1=paused)',
        registers: [register]
    }),

    maxPriceImpact: new promClient.Gauge({
        name: 'bofh_max_price_impact',
        help: 'Current maximum price impact setting',
        registers: [register]
    }),

    maxTradeVolume: new promClient.Gauge({
        name: 'bofh_max_trade_volume',
        help: 'Current maximum trade volume setting',
        registers: [register]
    }),

    minPoolLiquidity: new promClient.Gauge({
        name: 'bofh_min_pool_liquidity',
        help: 'Current minimum pool liquidity setting',
        registers: [register]
    }),

    mevProtectionEnabled: new promClient.Gauge({
        name: 'bofh_mev_protection_enabled',
        help: 'MEV protection status (0=disabled, 1=enabled)',
        registers: [register]
    }),

    // Histograms
    swapDuration: new promClient.Histogram({
        name: 'bofh_swap_duration_seconds',
        help: 'Swap execution duration in seconds',
        buckets: [0.1, 0.5, 1, 2, 5, 10, 30],
        registers: [register]
    }),

    swapPathLength: new promClient.Histogram({
        name: 'bofh_swap_path_length',
        help: 'Distribution of swap path lengths',
        buckets: [2, 3, 4, 5, 6],
        registers: [register]
    })
};

// ============================================================================
// Contract ABI (minimal for events we monitor)
// ============================================================================

const CONTRACT_ABI = [
    // Events
    'event SwapExecuted(address indexed initiator, uint256 pathLength, uint256 inputAmount, uint256 outputAmount, uint256 priceImpact)',
    'event RiskParamsUpdated(uint256 maxTradeVolume, uint256 minPoolLiquidity, uint256 maxPriceImpact, uint256 sandwichProtectionBips)',
    'event PoolBlacklisted(address indexed pool, bool blacklisted)',
    'event MEVProtectionUpdated(bool enabled, uint256 maxTxPerBlock, uint256 minTxDelay)',
    'event SecurityStateChanged(bool paused, bool locked)',
    'event EmergencyTokenRecovery(address indexed token, address indexed to, uint256 amount, address indexed executor)',

    // View functions for state queries
    'function isPaused() view returns (bool)',
    'function getRiskParameters() view returns (uint256 maxVolume, uint256 minLiquidity, uint256 maxImpact, uint256 sandwichProtection)',
    'function getMEVProtectionConfig() view returns (bool enabled, uint256 maxTx, uint256 minDelay)'
];

// ============================================================================
// Blockchain Connection
// ============================================================================

let provider;
let contract;

async function initializeBlockchainConnection() {
    try {
        // Create provider
        provider = new ethers.JsonRpcProvider(CONFIG.rpcUrl);

        // Create contract instance
        contract = new ethers.Contract(
            CONFIG.contractAddress,
            CONTRACT_ABI,
            provider
        );

        // Verify connection
        const network = await provider.getNetwork();
        logger.info(`Connected to ${network.name} (chainId: ${network.chainId})`);
        logger.info(`Monitoring contract: ${CONFIG.contractAddress}`);

        // Query initial state
        await updateContractState();

        return true;
    } catch (error) {
        logger.error('Failed to initialize blockchain connection:', error);
        return false;
    }
}

// ============================================================================
// State Queries
// ============================================================================

async function updateContractState() {
    try {
        // Query pause state
        const isPaused = await contract.isPaused();
        metrics.contractPaused.set(isPaused ? 1 : 0);

        // Query risk parameters
        const [maxVolume, minLiquidity, maxImpact, sandwichProtection] =
            await contract.getRiskParameters();

        metrics.maxTradeVolume.set(Number(maxVolume));
        metrics.minPoolLiquidity.set(Number(minLiquidity));
        metrics.maxPriceImpact.set(Number(maxImpact));

        // Query MEV protection
        const [mevEnabled, maxTx, minDelay] = await contract.getMEVProtectionConfig();
        metrics.mevProtectionEnabled.set(mevEnabled ? 1 : 0);

        logger.debug('Contract state updated');
    } catch (error) {
        logger.error('Failed to update contract state:', error.message);
    }
}

// ============================================================================
// Event Handlers
// ============================================================================

function handleSwapExecuted(initiator, pathLength, inputAmount, outputAmount, priceImpact, event) {
    try {
        const pathLen = Number(pathLength);
        const input = Number(ethers.formatEther(inputAmount));
        const output = Number(ethers.formatEther(outputAmount));
        const impact = Number(priceImpact) / 1e6 * 100; // Convert to percentage
        const profit = output - input;

        // Update metrics
        metrics.totalSwaps.inc();
        if (profit >= 0) {
            metrics.successfulSwaps.inc();
            metrics.totalProfitBnb.inc(profit);
        } else {
            metrics.failedSwaps.inc();
        }

        metrics.profitBnb.set(profit);
        metrics.priceImpactPercent.set(impact);
        metrics.swapPathLength.observe(pathLen);

        // Log event
        logger.info('SwapExecuted', {
            blockNumber: event.blockNumber,
            txHash: event.transactionHash,
            initiator,
            pathLength: pathLen,
            input: input.toFixed(6),
            output: output.toFixed(6),
            profit: profit.toFixed(6),
            priceImpact: impact.toFixed(4)
        });

        // Alert on high price impact
        if (impact > 5.0) {
            logger.warn(`High price impact detected: ${impact.toFixed(2)}%`);
        }

        // Alert on unprofitable swap
        if (profit < 0) {
            logger.warn(`Unprofitable swap detected: ${profit.toFixed(6)} BNB`);
        }
    } catch (error) {
        logger.error('Error handling SwapExecuted event:', error);
    }
}

function handleRiskParamsUpdated(maxTradeVolume, minPoolLiquidity, maxPriceImpact, sandwichProtectionBips, event) {
    try {
        metrics.maxTradeVolume.set(Number(maxTradeVolume));
        metrics.minPoolLiquidity.set(Number(minPoolLiquidity));
        metrics.maxPriceImpact.set(Number(maxPriceImpact));

        logger.info('RiskParamsUpdated', {
            blockNumber: event.blockNumber,
            txHash: event.transactionHash,
            maxTradeVolume: maxTradeVolume.toString(),
            minPoolLiquidity: minPoolLiquidity.toString(),
            maxPriceImpact: maxPriceImpact.toString(),
            sandwichProtectionBips: sandwichProtectionBips.toString()
        });
    } catch (error) {
        logger.error('Error handling RiskParamsUpdated event:', error);
    }
}

function handlePoolBlacklisted(pool, blacklisted, event) {
    try {
        if (blacklisted) {
            metrics.poolsBlacklisted.inc();
        }

        logger.info('PoolBlacklisted', {
            blockNumber: event.blockNumber,
            txHash: event.transactionHash,
            pool,
            blacklisted
        });
    } catch (error) {
        logger.error('Error handling PoolBlacklisted event:', error);
    }
}

function handleMEVProtectionUpdated(enabled, maxTxPerBlock, minTxDelay, event) {
    try {
        metrics.mevProtectionEnabled.set(enabled ? 1 : 0);

        if (enabled) {
            logger.info('MEVProtectionUpdated', {
                blockNumber: event.blockNumber,
                txHash: event.transactionHash,
                enabled,
                maxTxPerBlock: maxTxPerBlock.toString(),
                minTxDelay: minTxDelay.toString()
            });
        } else {
            logger.warn('MEV Protection DISABLED', {
                blockNumber: event.blockNumber,
                txHash: event.transactionHash
            });
        }
    } catch (error) {
        logger.error('Error handling MEVProtectionUpdated event:', error);
    }
}

function handleSecurityStateChanged(paused, locked, event) {
    try {
        metrics.contractPaused.set(paused ? 1 : 0);

        if (paused) {
            logger.warn('Contract PAUSED', {
                blockNumber: event.blockNumber,
                txHash: event.transactionHash
            });
        } else {
            logger.info('Contract UNPAUSED', {
                blockNumber: event.blockNumber,
                txHash: event.transactionHash
            });
        }
    } catch (error) {
        logger.error('Error handling SecurityStateChanged event:', error);
    }
}

function handleEmergencyTokenRecovery(token, to, amount, executor, event) {
    try {
        logger.warn('EmergencyTokenRecovery', {
            blockNumber: event.blockNumber,
            txHash: event.transactionHash,
            token,
            to,
            amount: amount.toString(),
            executor
        });
    } catch (error) {
        logger.error('Error handling EmergencyTokenRecovery event:', error);
    }
}

// ============================================================================
// Event Listener Setup
// ============================================================================

async function setupEventListeners() {
    try {
        // Listen to all events
        contract.on('SwapExecuted', handleSwapExecuted);
        contract.on('RiskParamsUpdated', handleRiskParamsUpdated);
        contract.on('PoolBlacklisted', handlePoolBlacklisted);
        contract.on('MEVProtectionUpdated', handleMEVProtectionUpdated);
        contract.on('SecurityStateChanged', handleSecurityStateChanged);
        contract.on('EmergencyTokenRecovery', handleEmergencyTokenRecovery);

        logger.info('Event listeners registered successfully');
    } catch (error) {
        logger.error('Failed to setup event listeners:', error);
        throw error;
    }
}

// ============================================================================
// Express Server for Prometheus Metrics
// ============================================================================

const app = express();

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        network: CONFIG.network,
        contractAddress: CONFIG.contractAddress,
        uptime: process.uptime()
    });
});

// Metrics endpoint for Prometheus
app.get('/metrics', async (req, res) => {
    try {
        res.set('Content-Type', register.contentType);
        res.end(await register.metrics());
    } catch (error) {
        res.status(500).end(error);
    }
});

// Start server
function startMetricsServer() {
    app.listen(CONFIG.metricsPort, () => {
        logger.info(`Metrics server listening on port ${CONFIG.metricsPort}`);
        logger.info(`Prometheus metrics: http://localhost:${CONFIG.metricsPort}/metrics`);
        logger.info(`Health check: http://localhost:${CONFIG.metricsPort}/health`);
    });
}

// ============================================================================
// Periodic State Updates
// ============================================================================

function startPeriodicUpdates() {
    setInterval(async () => {
        await updateContractState();
    }, CONFIG.pollInterval);

    logger.info(`Periodic state updates enabled (interval: ${CONFIG.pollInterval}ms)`);
}

// ============================================================================
// Main Execution
// ============================================================================

async function main() {
    logger.info('Starting BofhContract Event Indexer...');
    logger.info('Configuration:', {
        network: CONFIG.network,
        contractAddress: CONFIG.contractAddress,
        metricsPort: CONFIG.metricsPort,
        pollInterval: CONFIG.pollInterval
    });

    // Initialize blockchain connection
    const connected = await initializeBlockchainConnection();
    if (!connected) {
        logger.error('Failed to connect to blockchain. Exiting...');
        process.exit(1);
    }

    // Setup event listeners
    await setupEventListeners();

    // Start metrics server
    startMetricsServer();

    // Start periodic state updates
    startPeriodicUpdates();

    logger.info('Event indexer is running and monitoring events');
}

// ============================================================================
// Error Handling
// ============================================================================

process.on('uncaughtException', (error) => {
    logger.error('Uncaught Exception:', error);
    process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
    logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

process.on('SIGINT', () => {
    logger.info('Received SIGINT, shutting down gracefully...');
    process.exit(0);
});

process.on('SIGTERM', () => {
    logger.info('Received SIGTERM, shutting down gracefully...');
    process.exit(0);
});

// ============================================================================
// Start the Application
// ============================================================================

main().catch((error) => {
    logger.error('Fatal error:', error);
    process.exit(1);
});
