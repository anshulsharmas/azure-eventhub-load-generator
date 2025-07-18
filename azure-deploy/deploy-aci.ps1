# Azure Event Hub Simulator - PowerShell Deployment Script
# This script builds and deploys the simulator to Azure Container Instances

param(
    [string]$ResourceGroupName = "high-throughput-streaming-poc",
    [string]$Location = "eastus", 
    [string]$AcrName = "eventhubsimacr",
    [string]$ContainerGroupName = "eventhub-simulator-51",
    [string]$ContainerImage  = "eventhub-simulator-2:latest"

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

# Create resource group
Write-Host "📦 Creating resource group..." -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location --output table

# Create Azure Container Registry
Write-Host "🏗️ Creating Azure Container Registry..." -ForegroundColor Yellow
az acr create --resource-group $ResourceGroupName --name $AcrName --sku Basic --admin-enabled true --output table

# Build and push container image
Write-Host "🔨 Building and pushing container image..." -ForegroundColor Yellow
# Ensure we're in the project root directory (one level up from azure-deploy)
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    az acr build --registry $AcrName --resource-group $ResourceGroupName --image $ContainerImage .
}
finally {
    Pop-Location
}

# Get ACR login server and credentials
$acrLoginServer = az acr show --name $AcrName --resource-group $ResourceGroupName --query loginServer -o tsv
$acrCredentials = az acr credential show --name $AcrName --resource-group $ResourceGroupName --query "{username:username, password:passwords[0].value}" -o json | ConvertFrom-Json

# Prompt for Event Hub details
Write-Host "⚙️ Configuration" -ForegroundColor Yellow
Write-Host "Leave Event Hub details blank to use config.json values:" -ForegroundColor Cyan
$eventHubConnectionString = Read-Host "Enter your Event Hub Connection String (optional)"
$eventHubName = Read-Host "Enter your Event Hub Name (optional)"
$messageRate = Read-Host "Enter message rate (default: 1000000)"
if ([string]::IsNullOrEmpty($messageRate)) { $messageRate = 1000000 }
$duration = Read-Host "Enter duration in seconds (default: 0 = unlimited)"
if ([string]::IsNullOrEmpty($duration)) { $duration = 0 }

# Deploy Container Instance
Write-Host "🚀 Deploying to Azure Container Instances..." -ForegroundColor Yellow

# Use empty string if not provided (will fall back to config.json)
if ([string]::IsNullOrEmpty($eventHubConnectionString)) { $eventHubConnectionString = "" }
if ([string]::IsNullOrEmpty($eventHubName)) { $eventHubName = "" }

az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file "$PSScriptRoot/aci-template.json" `
    --parameters `
        containerGroupName=$ContainerGroupName `
        eventHubConnectionString="$eventHubConnectionString" `
        eventHubName="$eventHubName" `
        messageRate=$messageRate `
        messageDuration=$duration `
        containerImage="$acrLoginServer/$ContainerImage" `
        acrLoginServer="$acrLoginServer" `
        acrUsername="$($acrCredentials.username)" `
        acrPassword="$($acrCredentials.password)" `
    --output table

Write-Host "✅ Deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Monitor your deployment:"
Write-Host "  az container logs --resource-group $ResourceGroupName --name $ContainerGroupName --follow"
Write-Host ""
Write-Host "Clean up resources when done:"
Write-Host "  az group delete --name $ResourceGroupName --yes --no-wait"
