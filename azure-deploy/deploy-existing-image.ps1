# Azure Event Hub Simulator - PowerShell Deployment Script
# This script builds and deploys the simulator to Azure Container Instances

param(
    [string]$ResourceGroupName = "high-throughput-streaming-poc",
    [string]$Location = "eastus2", 
    [string]$AcrName = "eventhubsimacr",
    [string]$ContainerImage  = "eventhub-simulator-dedicated-2:latest"
)

Write-Host "🚀 Azure Event Hub Simulator Deployment" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green

# Check if user is logged in to Azure
try {
    $subscription = az account show --query id -o tsv
    if ($LASTEXITCODE -ne 0) { throw }
    Write-Host "✅ Using subscription: $subscription" -ForegroundColor Green
}
catch {
    Write-Host "❌ Please login to Azure first: az login" -ForegroundColor Red
    exit 1
}


# Get ACR login server and credentials
$acrLoginServer = az acr show --name $AcrName --resource-group $ResourceGroupName --query loginServer -o tsv
$acrCredentials = az acr credential show --name $AcrName --resource-group $ResourceGroupName --query "{username:username, password:passwords[0].value}" -o json | ConvertFrom-Json


# Deploy Container Instances
Write-Host "🚀 Deploying containers..." -ForegroundColor Yellow

# Use empty string if not provided (will fall back to config.json)
$eventHubConnectionString = ""
$eventHubName = ""

1451..1500 | ForEach-Object {
    $currentContainerName = "eventhub-simulator-$_"
    Write-Host "Deploying container: $currentContainerName" -ForegroundColor Cyan
    
    az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file "$PSScriptRoot/aci-template.json" `
        --parameters `
            containerGroupName=$currentContainerName `
            location=$Location `
            eventHubConnectionString="$eventHubConnectionString" `
            eventHubName="$eventHubName" `
            messageRate=1000000 `
            messageDuration=0 `
            containerImage="$acrLoginServer/$ContainerImage" `
            acrLoginServer="$acrLoginServer" `
            acrUsername="$($acrCredentials.username)" `
            acrPassword="$($acrCredentials.password)" `
        --output table
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ $currentContainerName deployed successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ $currentContainerName deployment failed" -ForegroundColor Red
    }
}

Write-Host "✅ All deployments complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Monitor your deployments:"
22..30 | ForEach-Object {
    Write-Host "  az container logs --resource-group $ResourceGroupName --name eventhub-simulator-$_ --follow"
}
Write-Host ""
Write-Host "Clean up resources when done:"
Write-Host "  az group delete --name $ResourceGroupName --yes --no-wait"
