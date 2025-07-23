# Azure Event Hub/Microsoft Fabric Eventstreams load generator

A high-performance Python application that generates synthetic JSON messages and sends them to Azure Event Hub or Microsoft Fabric Eventstreams at configurable throughput rates.

## Installation

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Configure Event Hub connection:

The application supports both configuration files and environment variables with the following priority:
1. **Environment Variables** (highest priority)
2. **Configuration File** (fallback)

### Method 1: Configuration File (Recommended for development)
Copy and customize the example config:
```bash
cp config.example.json config.json
```

Edit `config.json` with your Event Hub details:
```json
{
  "eventhub": {
    "connection_string": "Endpoint=sb://your-namespace.servicebus.windows.net/;SharedAccessKeyName=your-key-name;SharedAccessKey=your-key",
    "eventhub_name": "your-event-hub-name"
  }
}
```

### Method 2: Environment Variables (Recommended for production/CI/CD)
```bash
export EVENT_HUB_CONNECTION_STRING="Endpoint=sb://your-namespace.servicebus.windows.net/;SharedAccessKeyName=your-key-name;SharedAccessKey=your-key"
export EVENT_HUB_NAME="your-event-hub-name"
```

**Note:** Environment variables will override any values specified in `config.json` if both are present.

## Configuration

The `config.json` file allows you to customize all aspects of the simulation:

```json
{
  "simulator": {
    "default_rate": 10000,
    "default_message_size": 500,
    "max_workers": 50
  },
  "message_generation": {
    "target_field_count": 100,
    "field_count_variance": 5,
    "string_length_range": [5, 15],
    "number_range": [1, 100000]
  },
  "stock_symbols": {
    "default_symbols": ["AAPL", "GOOGL", "MSFT", "TSLA", "AMZN"]
  },
  "eventhub": {
    "connection_string": "your-connection-string",
    "eventhub_name": "your-eventhub-name"
  }
}
```

## Usage

### Basic usage (10,000 messages/second):
```bash
python eventhub_simulator.py
```

### Custom configuration:
```bash
python eventhub_simulator.py --rate 50000 --duration 300 --msg-size 1024 --stocks "AAPL,GOOGL,MSFT,TSLA,AMZN"
```

### Using stock symbols from file:
```bash
python eventhub_simulator.py --rate 25000 --stocks stocks.txt --duration 600
```

## Command Line Options

- `--rate`: Messages per second (default: 10000)
- `--stocks`: Comma-separated stock symbols OR path to file with one symbol per line
- `--duration`: Duration to run simulation in seconds (optional - runs indefinitely if not specified)
- `--msg-size`: Approximate size of each JSON message in bytes (default: 500)

## Features

- **High Throughput**: Supports up to millions of messages per second using asyncio
- **Configurable Message Size**: Generate messages of specified byte size
- **Rich Message Content**: Each message contains ~100 key-value pairs with varied data types
- **Real-time Monitoring**: Shows messages/second and total count every second
- **Graceful Shutdown**: Handles Ctrl+C interruption cleanly
- **Flexible Stock Configuration**: Use predefined list or load from file

## Sample Message Structure

```json
{
  "timestamp": "2025-07-17T10:30:45.123456Z",
  "stockName": "AAPL",
  "field_0": 42.58,
  "field_1": "random_string_xyz",
  "field_2": 12345,
  ...
  "field_98": true
}
```

## Environment Variables

The application supports both configuration files and environment variables for configuration. **Environment variables take precedence over configuration file values** when both are provided.

### Configuration Priority (highest to lowest):
1. **Environment Variables** - Override all other settings
2. **Configuration File** (`config.json`) - Fallback values
3. **Default Values** - Built-in defaults when nothing else is specified

### Available Environment Variables:

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `EVENT_HUB_CONNECTION_STRING` | Azure Event Hub connection string | Yes (if not in config) | `Endpoint=sb://namespace.servicebus.windows.net/;SharedAccessKeyName=policy;SharedAccessKey=key` |
| `EVENT_HUB_NAME` | Name of the Event Hub | Yes (if not in config) | `my-eventhub` |

### Usage Examples:

**Windows PowerShell:**
```powershell
$env:EVENT_HUB_CONNECTION_STRING="Endpoint=sb://your-namespace.servicebus.windows.net/;SharedAccessKeyName=your-policy;SharedAccessKey=your-key"
$env:EVENT_HUB_NAME="your-eventhub-name"
python eventhub_simulator.py
```

**Linux/macOS:**
```bash
export EVENT_HUB_CONNECTION_STRING="Endpoint=sb://your-namespace.servicebus.windows.net/;SharedAccessKeyName=your-policy;SharedAccessKey=your-key"
export EVENT_HUB_NAME="your-eventhub-name"
python eventhub_simulator.py
```

## Deployment Options

The application supports multiple deployment methods for different use cases:

### 1. Local Development
Run directly on your machine:
```bash
python eventhub_simulator.py --rate 10000 --duration 300
```

### 2. Docker Container
Build and run using Docker:
```bash
# Build the container
docker build -t eventhub-simulator .

# Run with environment variables
docker run -e EVENT_HUB_CONNECTION_STRING="your-connection-string" \
           -e EVENT_HUB_NAME="your-eventhub-name" \
           eventhub-simulator
```

#### Docker Compose (Multiple Instances)
For running multiple simulator instances locally:
```bash
# Set environment variables
export EVENT_HUB_CONNECTION_STRING="your-connection-string"
export EVENT_HUB_NAME="your-eventhub-name"

# Run multiple instances
docker-compose up
```

The `docker-compose.yml` includes 3 simulator instances, each generating 10,000 messages/second for a total of 30,000 messages/second.

### 3. Azure Container Instances (ACI) - Recommended for Load Testing

#### Quick Start
```powershell
cd azure-deploy
.\deploy-aci.ps1
```

#### Available Deployment Scripts

| Script | Purpose | Use Case |
|--------|---------|----------|
| `deploy-aci.ps1` | Complete deployment pipeline | First-time deployment |
| `deploy-existing-image.ps1` | Deploy pre-built image | Using existing container image |
| `deploy-multiple-wrapper.ps1` | Multiple instance deployment | Distributed load testing |

#### ACI Deployment Features
- **Automated Setup**: Creates Resource Group, ACR, builds image, and deploys
- **Scalable**: Deploy hundreds of instances for massive throughput
- **Cost-effective**: Pay only for runtime duration
- **Fast deployment**: Containers start in seconds

### 4. Azure Container Apps
Deploy using Azure Container Apps template:
```bash
az deployment group create \
    --resource-group your-rg \
    --template-file azure-deploy/container-apps-template.json \
    --parameters eventHubConnectionString="your-connection-string"
```

## Container Management Tools

For managing large-scale deployments (hundreds of containers), use the PowerShell management scripts:

### Quick Status Check
```powershell
cd azure-deploy
.\quick-aci-check.ps1
```
- Fast overview of all container states
- Bulk operation suggestions
- Optimized for speed

### Detailed Status Monitoring
```powershell
.\check-aci-status.ps1 -StartNumber 1 -EndNumber 100 -Detailed
```
Features:
- Progress tracking with completion percentages
- Color-coded status display
- CSV export capability
- Resource usage information (CPU, memory, restart counts)
- Filtering options (running only, stopped only)

### Bulk Container Operations
```powershell
# Start containers 1-100 in parallel
.\bulk-aci-manage.ps1 -Action start -StartNumber 1 -EndNumber 100 -Parallel

# Stop containers 200-300
.\bulk-aci-manage.ps1 -Action stop -StartNumber 200 -EndNumber 300

# Restart specific range
.\bulk-aci-manage.ps1 -Action restart -StartNumber 50 -EndNumber 60

# View logs from specific container
.\bulk-aci-manage.ps1 -Action logs -LogContainer "eventhub-simulator-1"

# Delete containers (with safety confirmation)
.\bulk-aci-manage.ps1 -Action delete -StartNumber 1 -EndNumber 10 -Force
```

#### Bulk Operations Features
- **Parallel Execution**: Process multiple containers simultaneously
- **Safety Confirmations**: Prevent accidental deletions
- **Progress Tracking**: Real-time success rates and timing
- **Configurable Concurrency**: Control Azure API load

### Management Workflow Examples

**Daily Operations:**
```powershell
# 1. Quick status overview
.\quick-aci-check.ps1

# 2. Start any stopped containers
.\bulk-aci-manage.ps1 -Action start -StartNumber 1 -EndNumber 800 -Parallel

# 3. Export detailed status report
.\check-aci-status.ps1 -Detailed -ExportToCsv -CsvPath "daily-status.csv"
```

**Maintenance Window:**
```powershell
# 1. Stop all containers
.\bulk-aci-manage.ps1 -Action stop -StartNumber 1 -EndNumber 800 -Parallel

# 2. Restart specific problematic containers
.\bulk-aci-manage.ps1 -Action restart -StartNumber 100 -EndNumber 110

# 3. Start all containers back up
.\bulk-aci-manage.ps1 -Action start -StartNumber 1 -EndNumber 800 -Parallel
```

### Monitoring and Troubleshooting

**View real-time logs:**
```bash
az container logs --resource-group high-throughput-streaming-poc --name eventhub-simulator-1 --follow
```

**Check container performance:**
```bash
az container show --resource-group high-throughput-streaming-poc --name eventhub-simulator-1 --query "containers[0].instanceView"
```

**Monitor Azure metrics:**
```bash
az monitor metrics list --resource /subscriptions/your-sub/resourceGroups/your-rg/providers/Microsoft.ContainerInstance/containerGroups/eventhub-simulator-1 --metric "CpuUsage,MemoryUsage"
```

### Deployment Architecture

For high-throughput scenarios, the typical deployment pattern is:
- **800+ Container Instances**: Each running independently
- **Load Balancing**: Distributed across Azure regions
- **Monitoring**: Centralized logging and metrics collection
- **Management**: Automated start/stop/restart operations

### Prerequisites for Azure Deployment

1. **Azure CLI**: Install and authenticate
   ```bash
   az login
   ```

2. **PowerShell 5.1+**: For management scripts

3. **Azure Permissions**: Contributor access to target resource group

4. **Event Hub**: Pre-created Azure Event Hub or Fabric Eventstream

## Performance Notes

- Uses asyncio for concurrent message sending
- Implements connection pooling for optimal throughput
- Batch sends messages for better performance
- Memory efficient message generation
- Supports scaling to system resource limits

## Quick Reference

### Common Commands

**Local Testing:**
```bash
# Basic load test
python eventhub_simulator.py --rate 50000 --duration 300

# Custom message size and stocks
python eventhub_simulator.py --rate 100000 --msg-size 1024 --stocks "AAPL,GOOGL,MSFT"
```

**Docker:**
```bash
# Single instance
docker run -e EVENT_HUB_CONNECTION_STRING="..." -e EVENT_HUB_NAME="..." eventhub-simulator

# Multiple instances
docker-compose up
```

**Azure Deployment:**
```powershell
# Quick deploy to Azure
cd azure-deploy
.\deploy-aci.ps1

# Check status of 800 containers
.\quick-aci-check.ps1

# Start containers 1-100
.\bulk-aci-manage.ps1 -Action start -StartNumber 1 -EndNumber 100 -Parallel

# View logs
.\bulk-aci-manage.ps1 -Action logs -LogContainer "eventhub-simulator-1"
```

### Performance Targets

| Deployment | Expected Throughput | Use Case |
|------------|-------------------|----------|
| Local (single process) | 50K-100K msg/sec | Development/testing |
| Docker Compose (3 instances) | 150K-300K msg/sec | Local load testing |
| Single ACI | 50K-200K msg/sec | Cloud testing |
| 800 ACI instances | 40M-160M msg/sec | Production load testing |

### Troubleshooting

**Connection Issues:**
- Verify Event Hub connection string format
- Check Event Hub name matches configuration
- Ensure proper Azure permissions

**Performance Issues:**
- Increase `max_workers` in config
- Use parallel deployment (`-Parallel` flag)
- Monitor Azure resource limits

**Container Issues:**
- Check container logs: `az container logs --name <container> --follow`
- Verify resource group and container names
- Ensure Azure CLI authentication: `az login`
