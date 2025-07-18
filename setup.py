#!/usr/bin/env python3
"""
Setup script for Azure Event Hub Simulator
"""

import subprocess
import sys
import os

def install_requirements():
    """Install required packages."""
    print("Installing required packages...")
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"])
        print("✓ Requirements installed successfully")
    except subprocess.CalledProcessError as e:
        print(f"✗ Failed to install requirements: {e}")
        return False
    return True

def check_environment():
    """Check if required environment variables are set."""
    print("\nChecking environment variables...")
    
    required_vars = ['EVENT_HUB_CONNECTION_STRING', 'EVENT_HUB_NAME']
    missing_vars = []
    
    for var in required_vars:
        if not os.getenv(var):
            missing_vars.append(var)
    
    if missing_vars:
        print("✗ Missing required environment variables:")
        for var in missing_vars:
            print(f"  - {var}")
        print("\nPlease set these environment variables before running the simulator.")
        print("Example:")
        print('export EVENT_HUB_CONNECTION_STRING="Endpoint=sb://..."')
        print('export EVENT_HUB_NAME="your-event-hub-name"')
        return False
    else:
        print("✓ All required environment variables are set")
        return True

def main():
    print("Azure Event Hub Simulator Setup")
    print("=" * 40)
    
    # Install requirements
    if not install_requirements():
        sys.exit(1)
    
    # Check environment
    env_ok = check_environment()
    
    print("\n" + "=" * 40)
    if env_ok:
        print("✓ Setup completed successfully!")
        print("\nYou can now run the simulator:")
        print("python eventhub_simulator.py --help")
    else:
        print("⚠ Setup completed with warnings.")
        print("Please configure environment variables before running.")

if __name__ == '__main__':
    main()
