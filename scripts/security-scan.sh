#!/bin/bash
# Security scan script for BofhContract
# Runs Slither static analysis with appropriate filters

set -e

echo "🔍 Running Slither security analysis..."
echo ""

# Check if slither is installed
if ! command -v slither &> /dev/null; then
    echo "❌ Slither is not installed"
    echo "Install with: pip install slither-analyzer"
    exit 1
fi

echo "Slither version: $(slither --version)"
echo ""

# Create reports directory if it doesn't exist
mkdir -p reports

# Run Slither with appropriate filters
echo "Running analysis..."
slither . \
    --filter-paths "node_modules|test|.variants|mocks" \
    --exclude naming-convention,solc-version,low-level-calls \
    --json reports/slither-report.json \
    --sarif reports/slither-results.sarif \
    || SLITHER_EXIT=$?

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Analysis Results"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Parse results if report exists
if [ -f reports/slither-report.json ]; then
    CRITICAL=$(jq '[.results.detectors[] | select(.impact == "Critical")] | length' reports/slither-report.json)
    HIGH=$(jq '[.results.detectors[] | select(.impact == "High")] | length' reports/slither-report.json)
    MEDIUM=$(jq '[.results.detectors[] | select(.impact == "Medium")] | length' reports/slither-report.json)
    LOW=$(jq '[.results.detectors[] | select(.impact == "Low")] | length' reports/slither-report.json)
    INFO=$(jq '[.results.detectors[] | select(.impact == "Informational")] | length' reports/slither-report.json)

    echo "Severity Breakdown:"
    echo "  Critical:      $CRITICAL"
    echo "  High:          $HIGH"
    echo "  Medium:        $MEDIUM"
    echo "  Low:           $LOW"
    echo "  Informational: $INFO"
    echo ""

    # Show critical and high severity issues
    if [ "$CRITICAL" -gt "0" ] || [ "$HIGH" -gt "0" ]; then
        echo "❌ CRITICAL OR HIGH SEVERITY ISSUES FOUND!"
        echo ""
        echo "Details:"
        jq -r '.results.detectors[] | select(.impact == "High" or .impact == "Critical") | "  - [\(.impact)] \(.check): \(.description)"' reports/slither-report.json
        echo ""
        echo "Full report: reports/slither-report.json"
        exit 1
    else
        echo "✅ No critical or high severity issues found"
    fi

    # Show medium severity issues as warnings
    if [ "$MEDIUM" -gt "0" ]; then
        echo ""
        echo "⚠️  Medium severity issues found (review recommended):"
        jq -r '.results.detectors[] | select(.impact == "Medium") | "  - \(.check): \(.description)"' reports/slither-report.json | head -5
        if [ "$MEDIUM" -gt "5" ]; then
            echo "  ... and $((MEDIUM - 5)) more"
        fi
    fi
else
    echo "⚠️  Slither report not generated"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Reports saved to:"
echo "  - JSON:  reports/slither-report.json"
echo "  - SARIF: reports/slither-results.sarif"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
