#!/usr/bin/env python3
"""
Advanced CLI interface for BofhContract interactions.

Provides commands for contract deployment, interaction, and monitoring.
"""
import sys
from typing import Optional

try:
    import click
    from web3 import Web3
except ImportError:
    print("Error: Missing required dependencies (click, web3)", file=sys.stderr)
    print("\nInstall dependencies:", file=sys.stderr)
    print("  pip install click web3", file=sys.stderr)
    sys.exit(1)

from bofh.utils.solidity import get_abi, list_contracts
from bofh.utils.web3 import get_contract, get_network_info, Web3Connector


@click.group()
@click.option('--network', default='bsc_testnet', help='Network name (bsc, bsc_testnet, ethereum, polygon)')
@click.option('--rpc', default=None, help='Custom RPC URL')
@click.pass_context
def cli(ctx, network, rpc):
    """BofhContract CLI Tool for contract interaction and management."""
    ctx.ensure_object(dict)
    ctx.obj['NETWORK'] = network
    ctx.obj['RPC'] = rpc


@cli.command()
@click.pass_context
def network_info(ctx):
    """Display information about the connected network."""
    try:
        info = get_network_info(ctx.obj['RPC'], ctx.obj['NETWORK'])
        click.echo(f"\n{'='*50}")
        click.echo(f"Network Information")
        click.echo(f"{'='*50}")
        click.echo(f"RPC URL:      {info['rpc_url']}")
        click.echo(f"Chain ID:     {info['chain_id']}")
        click.echo(f"Latest Block: {info['latest_block']}")
        click.echo(f"Gas Price:    {Web3.from_wei(info['gas_price'], 'gwei')} Gwei")
        click.echo(f"Connected:    {info['is_connected']}")
        click.echo(f"{'='*50}\n")
    except Exception as e:
        click.echo(f"Error: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.option('--address', required=True, help='Contract address')
@click.pass_context
def contract_info(ctx, address):
    """Get information about a deployed contract."""
    try:
        abi = get_abi("BofhContractV2")
        contract = get_contract(address, abi, ctx.obj['RPC'], ctx.obj['NETWORK'])

        click.echo(f"\n{'='*50}")
        click.echo(f"Contract Information")
        click.echo(f"{'='*50}")
        click.echo(f"Address:       {address}")
        click.echo(f"Base Token:    {contract.functions.getBaseToken().call()}")
        click.echo(f"Factory:       {contract.functions.getFactory().call()}")

        # Get risk parameters
        risk_params = contract.functions.getRiskParams().call()
        click.echo(f"\nRisk Parameters:")
        click.echo(f"  Max Trade Volume:     {risk_params[0]}")
        click.echo(f"  Min Pool Liquidity:   {risk_params[1]}")
        click.echo(f"  Max Price Impact:     {risk_params[2] / 10000}%")
        click.echo(f"  Sandwich Protection:  {risk_params[3] / 100}%")

        click.echo(f"\nTotal Functions: {len(contract.all_functions())}")
        click.echo(f"{'='*50}\n")

    except Exception as e:
        click.echo(f"Error: {e}", err=True)
        sys.exit(1)


@cli.command()
def list_available_contracts():
    """List all compiled contracts available."""
    try:
        contracts = list_contracts()
        if not contracts:
            click.echo("No compiled contracts found.")
            click.echo("\nMake sure to compile contracts first:")
            click.echo("  npm run compile")
        else:
            click.echo(f"\n{'='*50}")
            click.echo(f"Available Contracts ({len(contracts)})")
            click.echo(f"{'='*50}")
            for contract_name in contracts:
                click.echo(f"  - {contract_name}")
            click.echo(f"{'='*50}\n")
    except Exception as e:
        click.echo(f"Error: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.option('--address', required=True, help='Contract address')
@click.option('--path', required=True, help='Swap path (comma-separated addresses)')
@click.option('--fees', required=True, help='Fees (comma-separated basis points)')
@click.option('--amount', required=True, type=float, help='Amount to swap (in ether units)')
@click.option('--min-out', required=True, type=float, help='Minimum output amount (in ether units)')
@click.option('--deadline', default=3600, type=int, help='Deadline in seconds from now')
@click.pass_context
def simulate_swap(ctx, address, path, fees, amount, min_out, deadline):
    """Simulate a swap without executing it (view function call)."""
    try:
        abi = get_abi("BofhContractV2")
        contract = get_contract(address, abi, ctx.obj['RPC'], ctx.obj['NETWORK'])

        # Parse path and fees
        path_addresses = [Web3.to_checksum_address(addr.strip()) for addr in path.split(',')]
        fee_values = [int(fee.strip()) for fee in fees.split(',')]

        # Convert amounts to wei
        amount_wei = Web3.to_wei(amount, 'ether')

        click.echo(f"\n{'='*50}")
        click.echo(f"Swap Simulation")
        click.echo(f"{'='*50}")
        click.echo(f"Path: {' → '.join(path_addresses)}")
        click.echo(f"Fees: {fee_values}")
        click.echo(f"Amount In: {amount} ETH ({amount_wei} wei)")

        # Call view function
        result = contract.functions.getOptimalPathMetrics(path_addresses, [amount_wei]).call()

        click.echo(f"\nResults:")
        click.echo(f"  Expected Output: {Web3.from_wei(result[0], 'ether')} ETH")
        click.echo(f"  Price Impact:    {result[1] / 10000}%")
        click.echo(f"  Optimality Score: {result[2] / 1e6:.4f}")
        click.echo(f"{'='*50}\n")

    except Exception as e:
        click.echo(f"Error: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.argument('contract_name')
def show_abi(contract_name):
    """Display the ABI for a contract."""
    try:
        abi = get_abi(contract_name)
        import json
        click.echo(json.dumps(abi, indent=2))
    except Exception as e:
        click.echo(f"Error: {e}", err=True)
        sys.exit(1)


if __name__ == '__main__':
    cli(obj={})
