# Azure Event Hub Simulator - Deployment Guide

This guide shows you the **easiest ways** to deploy the Event Hub simulator to Azure.

## 🚀 Quick Start - Azure Container Instances (Easiest)

### Prerequisites
- Azure CLI installed ([Download](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
- Azure subscription
- Event Hub already created

### Option 1: One-Click PowerShell Deployment
```powershell
# Login to Azure
az login

# Run the deployment script
.\azure-deploy\deploy-aci.ps1
```

### Option 2: Manual Azure CLI Deployment
```bash
# 1. Create resource group
az group create --name eventhub-simulator-rg --location eastus

# 2. Create container registry
az acr create --resource-group eventhub-simulator-rg --name eventhubsimacr --sku Basic --admin-enabled true

# 3. Build and push image
az acr build --registry eventhubsimacr --resource-group eventhub-simulator-rg --image eventhub-simulator:latest .

# 4. Deploy container instance
az deployment group create \
    --resource-group eventhub-simulator-rg \
    --template-file azure-deploy/aci-template.json \
    --parameters \
        eventHubConnectionString="YOUR_CONNECTION_STRING" \
        eventHubName="YOUR_EVENTHUB_NAME" \
        messageRate=100000 \
        messageDuration=600
```

## 📊 Monitoring Your Deployment

### View logs in real-time:
```bash
az container logs --resource-group eventhub-simulator-rg --name eventhub-simulator --follow
```

### Check container status:
```bash
az container show --resource-group eventhub-simulator-rg --name eventhub-simulator --query containers[0].instanceView.currentState
```

## ⚙️ Configuration Options

### 1. Environment Variables (Simplest)
```bash
export EVENT_HUB_CONNECTION_STRING="Endpoint=sb://..."
export EVENT_HUB_NAME="your-eventhub"
```

### 2. Config File (Recommended)
Edit `config.json`:
```json
{
  "eventhub": {
    "connection_string": "Endpoint=sb://...",
    "eventhub_name": "your-eventhub"
  },
  "simulator": {
    "default_rate": 1000000
  }
}
```

### 3. Azure Key Vault (Most Secure)
```json
{
  "azure_keyvault": {
    "enabled": true,
    "vault_url": "https://your-keyvault.vault.azure.net/",
    "connection_string_secret_name": "eventhub-connection-string",
    "eventhub_name_secret_name": "eventhub-name"
  }
}
```

## 🔥 High Throughput Deployment

### Multiple Container Instances
Deploy multiple instances for higher throughput:
```bash
# Deploy 5 instances, each sending 200k msg/sec = 1M total
for i in {1..5}; do
  az deployment group create \
    --resource-group eventhub-simulator-rg \
    --template-file azure-deploy/aci-template.json \
    --parameters \
      containerGroupName="eventhub-simulator-$i" \
      messageRate=200000 \
      messageDuration=3600
done
```

### Container Apps (Auto-scaling)
For production workloads with auto-scaling:
```bash
az deployment group create \
    --resource-group eventhub-simulator-rg \
    --template-file azure-deploy/container-apps-template.json \
    --parameters \
        messageRate=500000 \
        replicaCount=5
```

## 🧪 Local Testing with Docker

### Single container:
```bash
# Copy environment file
cp env.example .env
# Edit .env with your connection details

# Run locally
docker-compose up eventhub-simulator
```

### Multiple containers (simulate distributed load):
```bash
docker-compose up --scale eventhub-simulator=3
```

## 📈 Performance Tuning

### For maximum throughput, adjust these config values:

```json
{
  "simulator": {
    "max_workers": 100,           // More workers for higher throughput
    "batch_size_per_1k_rate": 200, // Larger batches
    "max_batch_size": 2000
  },
  "azure": {
    "max_batch_size": 2000        // Azure Event Hub batch limits
  }
}
```

### Resource allocation:
- **CPU**: 2-4 cores per 100k msg/sec
- **Memory**: 2-4 GB per instance  
- **Network**: Ensure adequate bandwidth

## 🛡️ Security Best Practices

1. **Use Azure Key Vault** for connection strings
2. **Enable managed identity** for container apps
3. **Use private container registries**
4. **Network isolation** with VNets

## 🧹 Cleanup

Remove all resources:
```bash
az group delete --name eventhub-simulator-rg --yes --no-wait
```

## 📞 Troubleshooting

### Common Issues:

1. **Connection failures**: Verify Event Hub connection string and firewall rules
2. **Rate limiting**: Check Event Hub throughput units
3. **Memory issues**: Increase container memory allocation
4. **Permission errors**: Ensure proper RBAC permissions

### Debug commands:
```bash
# Check container logs
az container logs --resource-group eventhub-simulator-rg --name eventhub-simulator

# Check Event Hub metrics
az monitor metrics list --resource /subscriptions/.../eventHubs/your-eventhub
```

## 🎯 Deployment Summary

| Method | Complexity | Best For | Max Throughput |
|--------|------------|----------|----------------|
| Single ACI | ⭐ | Testing | ~100k msg/sec |
| Multiple ACI | ⭐⭐ | Load testing | ~1M msg/sec |
| Container Apps | ⭐⭐⭐ | Production | ~5M+ msg/sec |
| Local Docker | ⭐ | Development | ~50k msg/sec |

Choose the deployment method that best fits your needs!
