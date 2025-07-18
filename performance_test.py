#!/usr/bin/env python3
"""
Performance test script for Azure Event Hub Simulator

This script runs various performance tests to determine optimal settings
for your system and Azure Event Hub configuration.
"""

import asyncio
import time
import subprocess
import sys
from typing import List, Tuple

def run_test(rate: int, duration: int = 30, msg_size: int = 500) -> Tuple[int, float]:
    """Run a single performance test."""
    print(f"\nTesting {rate:,} msg/sec for {duration}s (msg size: {msg_size} bytes)")
    
    cmd = [
        sys.executable, "eventhub_simulator.py",
        "--rate", str(rate),
        "--duration", str(duration),
        "--msg-size", str(msg_size)
    ]
    
    start_time = time.time()
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=duration + 10)
        elapsed = time.time() - start_time
        
        # Parse output to get actual rate
        output_lines = result.stdout.split('\n')
        total_sent = 0
        
        for line in reversed(output_lines):
            if "Total messages sent:" in line:
                total_sent = int(line.split(":")[1].strip().replace(",", ""))
                break
        
        actual_rate = total_sent / elapsed if elapsed > 0 else 0
        
        if result.returncode == 0:
            print(f"✓ Success: {total_sent:,} messages sent, {actual_rate:,.0f} msg/sec actual rate")
            return total_sent, actual_rate
        else:
            print(f"✗ Failed: {result.stderr}")
            return 0, 0.0
            
    except subprocess.TimeoutExpired:
        print("✗ Test timed out")
        return 0, 0.0
    except Exception as e:
        print(f"✗ Error: {e}")
        return 0, 0.0

def main():
    print("Azure Event Hub Simulator Performance Test")
    print("=" * 50)
    print("This will run a series of performance tests to find optimal settings.")
    print("Make sure your Event Hub connection is configured properly.")
    
    input("\nPress Enter to start performance tests...")
    
    # Test different rates
    test_rates = [1000, 5000, 10000, 25000, 50000, 100000]
    test_duration = 30
    
    results = []
    
    print(f"\nRunning {len(test_rates)} performance tests ({test_duration}s each)...")
    
    for rate in test_rates:
        total_sent, actual_rate = run_test(rate, test_duration)
        results.append((rate, total_sent, actual_rate))
        
        # If we're significantly underperforming, don't test higher rates
        if actual_rate < rate * 0.5 and rate > 10000:
            print(f"\nStopping tests - performance degraded significantly at {rate:,} msg/sec")
            break
    
    # Results summary
    print(f"\n{'='*60}")
    print("PERFORMANCE TEST RESULTS")
    print(f"{'='*60}")
    print(f"{'Target Rate':<12} {'Messages Sent':<15} {'Actual Rate':<12} {'Efficiency'}")
    print("-" * 60)
    
    best_rate = 0
    best_efficiency = 0
    
    for target_rate, total_sent, actual_rate in results:
        efficiency = (actual_rate / target_rate * 100) if target_rate > 0 else 0
        print(f"{target_rate:,:<12} {total_sent:,:<15} {actual_rate:,.0f:<12} {efficiency:.1f}%")
        
        if efficiency > best_efficiency and efficiency > 80:  # At least 80% efficiency
            best_rate = target_rate
            best_efficiency = efficiency
    
    print("-" * 60)
    
    if best_rate > 0:
        print(f"\nRECOMMENDED SETTINGS:")
        print(f"Optimal rate: {best_rate:,} messages/second ({best_efficiency:.1f}% efficiency)")
        print(f"\nTo run at optimal settings:")
        print(f"python eventhub_simulator.py --rate {best_rate}")
    else:
        print(f"\nNo optimal rate found. Try:")
        print("1. Check your Event Hub partition count and throughput units")
        print("2. Verify network connectivity")
        print("3. Start with lower rates (1000-5000 msg/sec)")
    
    # Test different message sizes at best rate
    if best_rate > 0:
        print(f"\nTesting different message sizes at {best_rate:,} msg/sec...")
        size_tests = [256, 512, 1024, 2048]
        
        for size in size_tests:
            total_sent, actual_rate = run_test(best_rate, 20, size)
            efficiency = (actual_rate / best_rate * 100) if best_rate > 0 else 0
            print(f"Message size {size:,} bytes: {efficiency:.1f}% efficiency")

if __name__ == '__main__':
    main()
