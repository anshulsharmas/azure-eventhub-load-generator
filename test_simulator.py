#!/usr/bin/env python3
"""
Test version of the Event Hub simulator without Azure dependencies.
This shows you how the script works and can be used to test the configuration loading.
"""

import json
import argparse
import sys
import os

def load_config(config_path: str = 'config.json'):
    """Load configuration from JSON file."""
    try:
        with open(config_path, 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Warning: Config file '{config_path}' not found. Using defaults.")
        return {}
    except json.JSONDecodeError as e:
        print(f"Error parsing config file '{config_path}': {e}")
        sys.exit(1)

def get_eventhub_connection_details(config):
    """Get Event Hub connection details from config or environment variables."""
    # Try config file first
    eventhub_config = config.get('eventhub', {})
    connection_string = eventhub_config.get('connection_string')
    eventhub_name = eventhub_config.get('eventhub_name')
    
    # Fall back to environment variables if not in config
    if not connection_string:
        connection_string = os.getenv('EVENT_HUB_CONNECTION_STRING')
    if not eventhub_name:
        eventhub_name = os.getenv('EVENT_HUB_NAME')
    
    return connection_string, eventhub_name

def main():
    # Load configuration first
    config = load_config()
    
    # Get default values from config
    default_rate = config.get('simulator', {}).get('default_rate', 10000)
    default_msg_size = config.get('simulator', {}).get('default_message_size', 500)
    default_stocks = ','.join(config.get('stock_symbols', {}).get('default_symbols', ['AAPL', 'GOOGL', 'MSFT', 'TSLA', 'AMZN']))
    
    parser = argparse.ArgumentParser(
        description='Azure Event Hub High-Throughput Message Simulator (Test Version)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python test_simulator.py --rate 50000 --duration 300
  python test_simulator.py --rate 100000 --stocks "AAPL,GOOGL,MSFT" --msg-size 1024
  python test_simulator.py --rate 25000 --stocks stocks.txt --duration 600
        """
    )
    
    parser.add_argument('--rate', type=int, default=default_rate,
                       help=f'Messages per second (default: {default_rate})')
    parser.add_argument('--stocks', type=str, 
                       default=default_stocks,
                       help='Comma-separated stock symbols or path to file')
    parser.add_argument('--duration', type=int,
                       help='Duration to run in seconds (optional)')
    parser.add_argument('--msg-size', type=int, default=default_msg_size,
                       help=f'Approximate message size in bytes (default: {default_msg_size})')
    
    args = parser.parse_args()
    
    # Get Event Hub connection details
    connection_string, eventhub_name = get_eventhub_connection_details(config)
    
    # Display configuration
    print("Configuration loaded successfully!")
    print(f"Rate: {args.rate:,} messages/second")
    print(f"Message size: {args.msg_size} bytes")
    print(f"Stocks: {args.stocks}")
    print(f"Duration: {'Unlimited' if not args.duration else f'{args.duration} seconds'}")
    print(f"Event Hub Name: {eventhub_name}")
    print(f"Connection String: {connection_string[:50]}..." if connection_string else "Connection String: Not found")
    
    if connection_string and eventhub_name:
        print("\n✅ Configuration is valid! Ready to run with Azure Event Hub.")
    else:
        print("\n❌ Missing connection details. Please check your config.json file.")
    
    print("\nTo run the full simulator, install Azure dependencies:")
    print("pip install azure-eventhub azure-eventhub-checkpointstoreblob")

if __name__ == '__main__':
    main()
