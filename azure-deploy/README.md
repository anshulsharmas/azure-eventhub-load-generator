# Azure Container Instance Management Scripts

This directory contains PowerShell scripts for managing multiple Azure Container Instances for the Event Hub load generator.

## Scripts Overview

### 1. `check-aci-status.ps1` - Comprehensive Status Checker
**Purpose**: Check the status of multiple ACI instances with detailed information.

**Usage Examples**:
```powershell
# Check all containers from 1 to 800
.\check-aci-status.ps1

# Check specific range
.\check-aci-status.ps1 -StartNumber 1 -EndNumber 100

# Show only running containers
.\check-aci-status.ps1 -ShowOnlyRunning

# Show only stopped containers  
.\check-aci-status.ps1 -ShowOnlyStopped

# Detailed view with full information
.\check-aci-status.ps1 -Detailed -StartNumber 1 -EndNumber 50

# Export results to CSV
.\check-aci-status.ps1 -ExportToCsv -CsvPath "my-aci-status.csv"

# Use different resource group
.\check-aci-status.ps1 -ResourceGroupName "my-other-rg"
```

**Features**:
- ✅ Progress tracking with percentage completion
- ✅ Color-coded status display
- ✅ Summary statistics with percentages
- ✅ CSV export capability
- ✅ Detailed resource information (CPU, memory, restart counts)
- ✅ Filtering options (running only, stopped only)

### 2. `quick-aci-check.ps1` - Fast Overview
**Purpose**: Quick status check optimized for speed.

**Usage Examples**:
```powershell
# Quick check all containers
.\quick-aci-check.ps1

# Check specific range
.\quick-aci-check.ps1 -StartNumber 1 -EndNumber 200

# Show only running containers
.\quick-aci-check.ps1 -OnlyRunning

# Different resource group
.\quick-aci-check.ps1 -ResourceGroupName "my-rg"
```

**Features**:
- ⚡ Fast execution (fetches all containers at once)
- ✅ Simple summary statistics
- ✅ Bulk operation commands
- ✅ Running container list

### 3. `bulk-aci-manage.ps1` - Bulk Operations
**Purpose**: Perform bulk operations on multiple containers.

**Usage Examples**:
```powershell
# Start containers 1-10
.\bulk-aci-manage.ps1 -Action start -StartNumber 1 -EndNumber 10

# Stop containers 50-100 in parallel
.\bulk-aci-manage.ps1 -Action stop -StartNumber 50 -EndNumber 100 -Parallel

# Restart containers with custom concurrency
.\bulk-aci-manage.ps1 -Action restart -StartNumber 1 -EndNumber 20 -Parallel -MaxConcurrency 5

# Delete containers (requires confirmation)
.\bulk-aci-manage.ps1 -Action delete -StartNumber 1 -EndNumber 10 -Force

# View logs for specific container
.\bulk-aci-manage.ps1 -Action logs -LogContainer "eventhub-simulator-1"
```

**Actions Supported**:
- `start` - Start stopped containers
- `stop` - Stop running containers  
- `restart` - Restart containers
- `delete` - Delete containers (with safety confirmation)
- `logs` - View logs for a specific container

**Features**:
- 🚀 Parallel execution support
- ✅ Safety confirmations for destructive operations
- ✅ Progress tracking and success rates
- ✅ Configurable concurrency limits
- ✅ Sequential or parallel modes

## Common Parameters

All scripts support these common parameters:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ResourceGroupName` | "high-throughput-streaming-poc" | Azure resource group name |
| `StartNumber` | 1 | Starting container number |
| `EndNumber` | 800 | Ending container number |
| `ContainerNamePrefix` | "eventhub-simulator-" | Container name prefix |

## Prerequisites

1. **Azure CLI**: Install and login
   ```powershell
   az login
   ```

2. **PowerShell 5.1+**: Windows PowerShell or PowerShell Core

3. **Azure Subscription**: Access to the resource group containing the containers

## Workflow Examples

### Daily Operations Workflow
```powershell
# 1. Quick status check
.\quick-aci-check.ps1

# 2. Start containers that aren't running
.\bulk-aci-manage.ps1 -Action start -StartNumber 1 -EndNumber 100 -Parallel

# 3. Detailed status check with CSV export
.\check-aci-status.ps1 -Detailed -ExportToCsv

# 4. Monitor specific container logs
.\bulk-aci-manage.ps1 -Action logs -LogContainer "eventhub-simulator-1"
```

### Maintenance Workflow
```powershell
# 1. Check current status
.\check-aci-status.ps1 -ShowOnlyRunning

# 2. Restart problematic containers
.\bulk-aci-manage.ps1 -Action restart -StartNumber 50 -EndNumber 60

# 3. Stop all containers for maintenance
.\bulk-aci-manage.ps1 -Action stop -StartNumber 1 -EndNumber 800 -Parallel

# 4. Start them back up
.\bulk-aci-manage.ps1 -Action start -StartNumber 1 -EndNumber 800 -Parallel
```

### Cleanup Workflow
```powershell
# 1. Check what's running
.\quick-aci-check.ps1

# 2. Stop all containers
.\bulk-aci-manage.ps1 -Action stop -StartNumber 1 -EndNumber 800 -Parallel

# 3. Delete all containers (after confirmation)
.\bulk-aci-manage.ps1 -Action delete -StartNumber 1 -EndNumber 800 -Force
```

## Performance Tips

1. **Use Quick Check First**: Use `quick-aci-check.ps1` for daily monitoring
2. **Parallel Operations**: Use `-Parallel` flag for bulk operations on many containers
3. **Adjust Concurrency**: Use `-MaxConcurrency` to control Azure API load
4. **Filter Results**: Use filtering options to reduce output noise
5. **Export Data**: Use CSV export for analysis and reporting

## Troubleshooting

### Common Issues

**"Please login to Azure first"**
```powershell
az login
```

**"Resource group does not exist"**
```powershell
# Check resource group name
az group list --query "[].name" -o table
```

**"Too many parallel operations"**
```powershell
# Reduce concurrency
.\bulk-aci-manage.ps1 -Action start -MaxConcurrency 5
```

### Debug Mode

For troubleshooting, you can enable verbose output:
```powershell
$VerbosePreference = "Continue"
.\check-aci-status.ps1 -Verbose
```

## Security Notes

- Scripts require Azure CLI authentication
- Destructive operations (`delete`) require explicit confirmation
- No credentials are stored in scripts
- Uses Azure CLI's existing authentication tokens
