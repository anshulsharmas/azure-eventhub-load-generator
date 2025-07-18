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
    "connection_string": "Endpoint=sb://your-namespace.servicebus.windows.net/;SharedAccessKeyName=your-policy;SharedAccessKey=your-key;EntityPath=your-eventhub",
    "eventhub_name": "your-eventhub-name"
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

## Azure Container Instance Deployment

The application includes automated deployment scripts for running the load generator on Azure Container Instances (ACI), which is ideal for high-throughput testing without managing infrastructure.

### Quick Deploy

Use the PowerShell deployment script for a complete automated deployment:

```powershell
cd azure-deploy
.\deploy-aci.ps1
```

### Deployment Options

#### 1. Automated Deployment (Recommended)
The `deploy-aci.ps1` script handles the entire deployment process:

- Creates Azure Resource Group
- Sets up Azure Container Registry (ACR)
- Builds and pushes the container image
- Deploys to Azure Container Instances
- Configures environment variables

**Parameters:**
```powershell
.\deploy-aci.ps1 -ResourceGroupName "my-rg" -Location "eastus" -AcrName "myacr" -ContainerGroupName "my-simulator" -ContainerImage "simulator:latest"
```

#### 2. Using Existing Container Image
If you have a pre-built image, use the existing image deployment:

```powershell
.\deploy-existing-image.ps1 -ResourceGroupName "my-rg" -ContainerImage "myacr.azurecr.io/simulator:latest"
```

#### 3. Multiple Instance Deployment
For distributed load testing, deploy multiple container instances:

```powershell
.\deploy-multiple-wrapper.ps1 -ResourceGroupName "my-rg" -InstanceCount 5 -MessageRate 50000
```

### Configuration for ACI

During deployment, you can configure:

- **Event Hub Connection**: Provide connection string and Event Hub name
- **Message Rate**: Messages per second (default: 1,000,000)
- **Duration**: Runtime in seconds (default: unlimited)
- **Container Resources**: CPU and memory allocation

### Monitoring ACI Deployment

**View logs:**
```bash
az container logs --resource-group <resource-group> --name <container-group> --follow
```

**Check status:**
```bash
az container show --resource-group <resource-group> --name <container-group> --query "containers[0].instanceView.currentState"
```

**Monitor performance:**
```bash
az monitor metrics list --resource <container-group-resource-id> --metric "CpuUsage,MemoryUsage"
```

### Cleanup

Remove all deployed resources:
```bash
az group delete --name <resource-group> --yes --no-wait
```

### ACI Benefits

- **Serverless**: No VM management required
- **Scalable**: Deploy multiple instances for distributed load
- **Cost-effective**: Pay only for runtime duration
- **Fast deployment**: Containers start in seconds
- **Integrated monitoring**: Built-in Azure Monitor integration

## Performance Notes

- Uses asyncio for concurrent message sending
- Implements connection pooling for optimal throughput
- Batch sends messages for better performance
- Memory efficient message generation
- Supports scaling to system resource limits
