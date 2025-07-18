#!/usr/bin/env python3
"""
Azure Event Hub High-Throughput Message Simulator

This script generates synthetic JSON messages and sends them to Azure Event Hub
at configurable rates, supporting up to millions of messages per second.

Installation:
    pip install azure-eventhub asyncio-throttle

Configuration:
    Connection details can be provided via:
    1. config.json file (recommended)
    2. Environment variables: EVENT_HUB_CONNECTION_STRING, EVENT_HUB_NAME

Example Usage:
    # Basic usage (10,000 msg/sec for indefinite duration)
    python eventhub_simulator.py
    
    # High throughput with custom settings
    python eventhub_simulator.py --rate 100000 --duration 300 --msg-size 1024
    
    # Using custom stock list
    python eventhub_simulator.py --rate 50000 --stocks "AAPL,GOOGL,MSFT" --duration 600
    
    # Using stock list from file
    python eventhub_simulator.py --rate 25000 --stocks stocks.txt
"""

import os
import sys
import json
import time
import random
import string
import asyncio
import argparse
import signal
from datetime import datetime, timezone
from typing import List, Dict, Any, Optional
from concurrent.futures import ThreadPoolExecutor
import logging

try:
    from azure.eventhub.aio import EventHubProducerClient
    from azure.eventhub import EventData
except ImportError:
    print("Error: Azure Event Hub SDK not found. Install with: pip install azure-eventhub")
    sys.exit(1)


# Global variables for graceful shutdown
shutdown_event = asyncio.Event()
stats = {
    'total_sent': 0,
    'last_second_count': 0,
    'start_time': None,
    'last_stats_time': None
}


def load_config(config_path: str = 'config.json') -> Dict[str, Any]:
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


def get_eventhub_connection_details(config: Dict[str, Any]) -> tuple[str, str]:
    """Get Event Hub connection details from environment variables, config, or Azure Key Vault."""
    # Get values from config file first
    eventhub_config = config.get('eventhub', {})
    config_connection_string = eventhub_config.get('connection_string')
    config_eventhub_name = eventhub_config.get('eventhub_name')
    
    # Environment variables override config values (PRIORITY 1)
    connection_string = os.getenv('EVENT_HUB_CONNECTION_STRING') or config_connection_string
    eventhub_name = os.getenv('EVENT_HUB_NAME') or config_eventhub_name
    
    # Try Azure Key Vault if neither env vars nor config have values
    keyvault_config = config.get('azure_keyvault', {})
    if keyvault_config.get('enabled', False) and not connection_string:
        try:
            from azure.keyvault.secrets import SecretClient
            from azure.identity import DefaultAzureCredential
            
            vault_url = keyvault_config.get('vault_url')
            connection_secret_name = keyvault_config.get('connection_string_secret_name', 'eventhub-connection-string')
            eventhub_secret_name = keyvault_config.get('eventhub_name_secret_name', 'eventhub-name')
            
            if vault_url:
                credential = DefaultAzureCredential()
                client = SecretClient(vault_url=vault_url, credential=credential)
                
                if not connection_string:
                    connection_string = client.get_secret(connection_secret_name).value
                if not eventhub_name:
                    eventhub_name = client.get_secret(eventhub_secret_name).value
                    
                print("✅ Retrieved connection details from Azure Key Vault")
        except Exception as e:
            print(f"⚠️  Warning: Could not retrieve from Key Vault: {e}")
    
    # Validate required values
    if not connection_string:
        print("Error: Event Hub connection string not found in:")
        print("  1. EVENT_HUB_CONNECTION_STRING environment variable")
        print("  2. config.json 'eventhub.connection_string'")
        print("  3. Azure Key Vault (if configured)")
        sys.exit(1)
    
    if not eventhub_name:
        print("Error: Event Hub name not found in:")
        print("  1. EVENT_HUB_NAME environment variable")
        print("  2. config.json 'eventhub.eventhub_name'") 
        print("  3. Azure Key Vault (if configured)")
        sys.exit(1)
    
    return connection_string, eventhub_name


class MessageGenerator:
    """Generates synthetic JSON messages with configurable size and content."""
    
    def __init__(self, target_size: int = 500, stock_symbols: List[str] = None, config: Dict[str, Any] = None):
        self.target_size = target_size
        self.stock_symbols = stock_symbols or ['AAPL', 'GOOGL', 'MSFT', 'TSLA', 'AMZN']
        self.config = config or {}
        
        # Get message generation settings from config
        msg_config = self.config.get('message_generation', {})
        self.target_field_count = msg_config.get('target_field_count', 100)
        self.field_count_variance = msg_config.get('field_count_variance', 5)
        self.size_tolerance = msg_config.get('size_tolerance', 50)
        self.string_length_range = msg_config.get('string_length_range', [5, 15])
        self.number_range = msg_config.get('number_range', [1, 100000])
        self.float_precision = msg_config.get('float_precision', 2)
        
        self.field_templates = self._create_field_templates()
        
    def _create_field_templates(self) -> List[callable]:
        """Create templates for generating different types of field values."""
        min_str, max_str = self.string_length_range
        min_num, max_num = self.number_range
        
        return [
            lambda: random.randint(min_num, max_num),  # integers
            lambda: round(random.uniform(0.01, max_num / 100), self.float_precision),  # floats
            lambda: random.choice([True, False]),  # booleans
            lambda: ''.join(random.choices(string.ascii_letters + string.digits, k=random.randint(min_str, max_str))),  # strings
            lambda: random.choice(['active', 'inactive', 'pending', 'completed', 'failed']),  # status strings
            lambda: f"user_{random.randint(1000, 9999)}",  # user IDs
            lambda: f"session_{random.randint(100000, 999999)}",  # session IDs
            lambda: random.randint(1000000000, 9999999999),  # large numbers (timestamps, IDs)
        ]
    
    def generate_message(self) -> str:
        """Generate a single JSON message close to the target size."""
        message = {
            'timestamp': datetime.now(timezone.utc).isoformat(),
            'stockName': random.choice(self.stock_symbols)
        }
        
        # Start with base message and calculate remaining space
        base_json = json.dumps(message, separators=(',', ':'))
        remaining_size = self.target_size - len(base_json) - 2  # Account for outer braces
        
        field_count = 0
        current_size = len(base_json)
        
        # Add fields until we reach target size or target field count
        max_fields = self.target_field_count + random.randint(-self.field_count_variance, self.field_count_variance)
        while current_size < self.target_size - self.size_tolerance and field_count < max_fields:
            field_name = f"field_{field_count}"
            field_value = random.choice(self.field_templates)()
            
            # Calculate the size this field would add
            field_json = f'"{field_name}":{json.dumps(field_value, separators=(",", ":"))}'
            field_size = len(field_json) + 1  # +1 for comma
            
            # If adding this field would exceed target, try a smaller value
            if current_size + field_size > self.target_size:
                if isinstance(field_value, str) and len(field_value) > 5:
                    # Truncate string to fit
                    max_str_len = self.target_size - current_size - len(field_name) - 10
                    if max_str_len > 0:
                        field_value = field_value[:max_str_len]
                    else:
                        break
                elif isinstance(field_value, (int, float)) and field_count > 10:
                    # Use smaller number
                    field_value = random.randint(1, 99)
                else:
                    break
            
            message[field_name] = field_value
            current_size += field_size
            field_count += 1
        
        return json.dumps(message, separators=(',', ':'))


class EventHubSender:
    """Handles high-throughput sending to Azure Event Hub."""
    
    def __init__(self, connection_string: str, eventhub_name: str):
        self.connection_string = connection_string
        self.eventhub_name = eventhub_name
        self.producer = None
        
    async def __aenter__(self):
        self.producer = EventHubProducerClient.from_connection_string(
            conn_str=self.connection_string,
            eventhub_name=self.eventhub_name
        )
        return self
        
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.producer:
            await self.producer.close()
    
    async def send_batch(self, messages: List[str]) -> int:
        """Send a batch of messages to Event Hub."""
        try:
            async with self.producer:
                event_data_batch = await self.producer.create_batch()
                
                for message in messages:
                    try:
                        event_data_batch.add(EventData(message))
                    except ValueError:
                        # Batch is full, send it and create a new one
                        await self.producer.send_batch(event_data_batch)
                        event_data_batch = await self.producer.create_batch()
                        event_data_batch.add(EventData(message))
                
                # Send the final batch
                if len(event_data_batch) > 0:
                    await self.producer.send_batch(event_data_batch)
                
                return len(messages)
        except Exception as e:
            logging.error(f"Error sending batch: {e}")
            return 0


async def message_sender_worker(
    sender: EventHubSender,
    message_generator: MessageGenerator,
    rate_per_worker: int,
    worker_id: int,
    config: Dict[str, Any] = None
):
    """Worker coroutine that sends messages at specified rate."""
    simulator_config = config.get('simulator', {}) if config else {}
    min_batch = simulator_config.get('min_batch_size', 1)
    max_batch = simulator_config.get('max_batch_size', 1000)
    batch_size_per_1k = simulator_config.get('batch_size_per_1k_rate', 100)
    
    # Calculate adaptive batch size
    target_batch = (rate_per_worker // 10) if rate_per_worker > 0 else batch_size_per_1k
    batch_size = max(min_batch, min(max_batch, target_batch))
    
    sleep_time = batch_size / rate_per_worker if rate_per_worker > 0 else 0.01
    
    logging.info(f"Worker {worker_id} starting: {rate_per_worker} msg/sec, batch size: {batch_size}")
    
    while not shutdown_event.is_set():
        try:
            # Generate batch of messages
            messages = [message_generator.generate_message() for _ in range(batch_size)]
            
            # Send batch
            sent_count = await sender.send_batch(messages)
            
            # Update statistics
            stats['total_sent'] += sent_count
            stats['last_second_count'] += sent_count
            
            # Rate limiting
            if sleep_time > 0:
                await asyncio.sleep(sleep_time)
                
        except asyncio.CancelledError:
            break
        except Exception as e:
            logging.error(f"Worker {worker_id} error: {e}")
            await asyncio.sleep(0.1)  # Brief pause on error


async def stats_reporter():
    """Reports statistics every second."""
    stats['start_time'] = time.time()
    stats['last_stats_time'] = stats['start_time']
    
    while not shutdown_event.is_set():
        try:
            await asyncio.sleep(1.0)
            
            current_time = time.time()
            elapsed = current_time - stats['start_time']
            
            # Calculate rates
            current_rate = stats['last_second_count']
            avg_rate = stats['total_sent'] / elapsed if elapsed > 0 else 0
            
            print(f"\r[{elapsed:.0f}s] Current: {current_rate:,} msg/sec | "
                  f"Average: {avg_rate:,.0f} msg/sec | "
                  f"Total: {stats['total_sent']:,} messages", end='', flush=True)
            
            # Reset counter for next second
            stats['last_second_count'] = 0
            stats['last_stats_time'] = current_time
            
        except asyncio.CancelledError:
            break


def signal_handler(signum, frame):
    """Handle Ctrl+C gracefully."""
    print("\n\nShutdown signal received. Stopping gracefully...")
    shutdown_event.set()


def load_stock_symbols(stocks_input: str) -> List[str]:
    """Load stock symbols from string or file."""
    if ',' in stocks_input:
        # Comma-separated list
        return [s.strip().upper() for s in stocks_input.split(',') if s.strip()]
    elif os.path.isfile(stocks_input):
        # File path
        try:
            with open(stocks_input, 'r') as f:
                return [line.strip().upper() for line in f if line.strip()]
        except Exception as e:
            print(f"Error reading stocks file '{stocks_input}': {e}")
            sys.exit(1)
    else:
        # Single stock symbol
        return [stocks_input.upper()]


async def main():
    # Load configuration first
    config = load_config()
    
    # Get default values from config
    default_rate = config.get('simulator', {}).get('default_rate', 10000)
    default_msg_size = config.get('simulator', {}).get('default_message_size', 500)
    default_stocks = ','.join(config.get('stock_symbols', {}).get('default_symbols', ['AAPL', 'GOOGL', 'MSFT', 'TSLA', 'AMZN']))
    
    parser = argparse.ArgumentParser(
        description='Azure Event Hub High-Throughput Message Simulator',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --rate 50000 --duration 300
  %(prog)s --rate 100000 --stocks "AAPL,GOOGL,MSFT" --msg-size 1024
  %(prog)s --rate 25000 --stocks stocks.txt --duration 600
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
    
    # Load stock symbols
    stock_symbols = load_stock_symbols(args.stocks)
    print(f"Loaded {len(stock_symbols)} stock symbols: {', '.join(stock_symbols[:5])}{'...' if len(stock_symbols) > 5 else ''}")
    
    # Set up logging
    logging.basicConfig(level=logging.WARNING, format='%(levelname)s: %(message)s')
    
    # Set up graceful shutdown
    signal.signal(signal.SIGINT, signal_handler)
    
    # Initialize components
    message_generator = MessageGenerator(args.msg_size, stock_symbols, config)
    
    print(f"Starting Azure Event Hub Simulator...")
    print(f"Target rate: {args.rate:,} messages/second")
    print(f"Message size: ~{args.msg_size} bytes")
    print(f"Duration: {'Unlimited' if not args.duration else f'{args.duration} seconds'}")
    print(f"Event Hub: {eventhub_name}")
    print("Press Ctrl+C to stop gracefully\n")
    
    # Calculate optimal number of workers based on config
    simulator_config = config.get('simulator', {})
    max_workers = simulator_config.get('max_workers', 50)
    batch_size_per_1k = simulator_config.get('batch_size_per_1k_rate', 100)
    
    num_workers = min(max_workers, max(1, args.rate // 1000))  # 1 worker per 1000 msg/sec, with config max
    rate_per_worker = args.rate // num_workers
    
    print(f"Using {num_workers} workers, {rate_per_worker:,} msg/sec per worker\n")
    
    try:
        async with EventHubSender(connection_string, eventhub_name) as sender:
            # Start all workers and stats reporter
            tasks = []
            
            # Create sender workers
            for i in range(num_workers):
                task = asyncio.create_task(
                    message_sender_worker(sender, message_generator, rate_per_worker, i, config)
                )
                tasks.append(task)
            
            # Add stats reporter
            stats_task = asyncio.create_task(stats_reporter())
            tasks.append(stats_task)
            
            # Run for specified duration or until interrupted
            if args.duration:
                await asyncio.sleep(args.duration)
                shutdown_event.set()
            else:
                # Wait for shutdown signal
                while not shutdown_event.is_set():
                    await asyncio.sleep(0.1)
            
            # Cancel all tasks
            for task in tasks:
                task.cancel()
            
            # Wait for tasks to complete
            await asyncio.gather(*tasks, return_exceptions=True)
    
    except Exception as e:
        logging.error(f"Fatal error: {e}")
        sys.exit(1)
    
    finally:
        # Final statistics
        elapsed = time.time() - stats['start_time'] if stats['start_time'] else 0
        avg_rate = stats['total_sent'] / elapsed if elapsed > 0 else 0
        
        print(f"\n\nFinal Statistics:")
        print(f"Total runtime: {elapsed:.1f} seconds")
        print(f"Total messages sent: {stats['total_sent']:,}")
        print(f"Average rate: {avg_rate:,.0f} messages/second")
        print("Simulation completed.")


if __name__ == '__main__':
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nShutdown requested by user.")
    except Exception as e:
        print(f"Fatal error: {e}")
        sys.exit(1)
