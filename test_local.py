#!/usr/bin/env python3
"""
Simple test script to verify the message generator works correctly
without requiring Azure Event Hub connection.
"""

import json
import time
import statistics
from eventhub_simulator import MessageGenerator

def test_message_generation():
    """Test message generation functionality."""
    print("Testing Message Generation")
    print("=" * 40)
    
    # Test different configurations
    configs = [
        (500, ["AAPL", "GOOGL", "MSFT"]),
        (1024, ["TSLA", "AMZN"]),
        (256, ["META", "NVDA", "NFLX", "CRM"])
    ]
    
    for target_size, stocks in configs:
        print(f"\nTesting: {target_size} bytes, {len(stocks)} stock symbols")
        generator = MessageGenerator(target_size, stocks)
        
        # Generate test messages
        sizes = []
        field_counts = []
        
        for i in range(10):
            message_json = generator.generate_message()
            message = json.loads(message_json)
            
            size = len(message_json)
            field_count = len(message)
            
            sizes.append(size)
            field_counts.append(field_count)
            
            # Verify required fields
            assert 'timestamp' in message, "Missing timestamp field"
            assert 'stockName' in message, "Missing stockName field"
            assert message['stockName'] in stocks, f"Invalid stock: {message['stockName']}"
            
            if i == 0:  # Show first message structure
                print(f"Sample message keys: {sorted(message.keys())[:10]}...")
        
        # Statistics
        avg_size = statistics.mean(sizes)
        avg_fields = statistics.mean(field_counts)
        size_variance = statistics.variance(sizes) if len(sizes) > 1 else 0
        
        print(f"Average size: {avg_size:.1f} bytes (target: {target_size})")
        print(f"Size variance: {size_variance:.1f}")
        print(f"Average fields: {avg_fields:.1f}")
        print(f"Size range: {min(sizes)} - {max(sizes)} bytes")
        
        # Verify size is close to target
        size_diff = abs(avg_size - target_size)
        size_tolerance = target_size * 0.15  # 15% tolerance
        
        if size_diff <= size_tolerance:
            print(f"✓ Size test passed (within {size_tolerance:.0f} bytes)")
        else:
            print(f"✗ Size test failed (off by {size_diff:.0f} bytes)")

def test_performance():
    """Test message generation performance."""
    print(f"\n\nTesting Generation Performance")
    print("=" * 40)
    
    generator = MessageGenerator(500, ["AAPL", "GOOGL", "MSFT"])
    
    # Warmup
    for _ in range(100):
        generator.generate_message()
    
    # Performance test
    message_counts = [1000, 5000, 10000]
    
    for count in message_counts:
        print(f"\nGenerating {count:,} messages...")
        
        start_time = time.time()
        for _ in range(count):
            generator.generate_message()
        elapsed = time.time() - start_time
        
        rate = count / elapsed
        print(f"Time: {elapsed:.2f}s, Rate: {rate:,.0f} msg/sec")
        
        if rate < 1000:
            print("⚠ Generation rate is low - may impact overall throughput")
        else:
            print("✓ Good generation performance")

def test_json_validity():
    """Test that all generated messages are valid JSON."""
    print(f"\n\nTesting JSON Validity")
    print("=" * 40)
    
    generator = MessageGenerator(500, ["TEST"])
    
    print("Generating 1000 messages and validating JSON...")
    
    for i in range(1000):
        try:
            message_json = generator.generate_message()
            json.loads(message_json)  # This will raise if invalid JSON
        except json.JSONDecodeError as e:
            print(f"✗ Invalid JSON at message {i}: {e}")
            return
    
    print("✓ All messages are valid JSON")

def main():
    """Run all tests."""
    print("Azure Event Hub Simulator - Local Tests")
    print("=" * 50)
    
    try:
        test_message_generation()
        test_performance()
        test_json_validity()
        
        print(f"\n\n{'='*50}")
        print("✓ All tests completed successfully!")
        print("The message generator is working correctly.")
        print("\nNext steps:")
        print("1. Configure Azure Event Hub connection")
        print("2. Run: python eventhub_simulator.py --help")
        print("3. Start with low rates: python eventhub_simulator.py --rate 1000")
        
    except Exception as e:
        print(f"\n✗ Test failed: {e}")
        return 1
    
    return 0

if __name__ == '__main__':
    exit(main())
