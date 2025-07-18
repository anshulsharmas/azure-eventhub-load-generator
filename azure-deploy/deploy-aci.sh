#!/bin/bash

# Azure Event Hub Simulator - Easy Deployment Script
# This script builds and deploys the simulator to Azure Container Instances

set -e

# Configuration
RESOURCE_GROUP_NAME="eventhub-simulator-rg"
LOCATION="eastus"
ACR_NAME="eventhubsimacr"
CONTAINER_GROUP_NAME="eventhub-simulator"

# Parse command line arguments
BUILD_IMAGE=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build)
            BUILD_IMAGE=false
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --skip-build    Skip building the container image (use existing image)"
            echo "  --help, -h      Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for available options"
            exit 1
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Azure Event Hub Simulator Deployment${NC}"
echo "======================================"

# Check if user is logged in to Azure
if ! az account show > /dev/null 2>&1; then
    echo -e "${RED}❌ Please login to Azure first: az login${NC}"
    exit 1
fi

# Get current subscription info
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo -e "${GREEN}✅ Using subscription: $SUBSCRIPTION_ID${NC}"

# Create resource group
echo -e "${YELLOW}📦 Creating resource group...${NC}"
az group create \
    --name $RESOURCE_GROUP_NAME \
    --location $LOCATION \
    --output table

# Create Azure Container Registry
echo -e "${YELLOW}🏗️  Creating Azure Container Registry...${NC}"
az acr create \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $ACR_NAME \
    --sku Basic \
    --admin-enabled true \
    --output table

# Build and push container image (optional)
if [ "$BUILD_IMAGE" = true ]; then
    echo -e "${YELLOW}🔨 Building and pushing container image...${NC}"
    az acr build \
        --registry $ACR_NAME \
        --resource-group $RESOURCE_GROUP_NAME \
        --image eventhub-simulator:latest \
        .
else
    echo -e "${YELLOW}⏭️  Skipping image build (using existing image)...${NC}"
fi

# Get ACR login server and credentials
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP_NAME --query loginServer -o tsv)
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --resource-group $RESOURCE_GROUP_NAME --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --resource-group $RESOURCE_GROUP_NAME --query "passwords[0].value" -o tsv)

# Prompt for Event Hub details
echo -e "${YELLOW}⚙️  Configuration${NC}"
read -p "Enter your Event Hub Connection String: " EVENT_HUB_CONNECTION_STRING
read -p "Enter your Event Hub Name: " EVENT_HUB_NAME
read -p "Enter message rate (default: 50000): " MESSAGE_RATE
MESSAGE_RATE=${MESSAGE_RATE:-50000}
read -p "Enter duration in seconds (default: 600): " DURATION
DURATION=${DURATION:-600}

# Deploy Container Instance
echo -e "${YELLOW}🚀 Deploying to Azure Container Instances...${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
az deployment group create \
    --resource-group $RESOURCE_GROUP_NAME \
    --template-file "$SCRIPT_DIR/aci-template.json" \
    --parameters \
        containerGroupName=$CONTAINER_GROUP_NAME \
        eventHubConnectionString="$EVENT_HUB_CONNECTION_STRING" \
        eventHubName="$EVENT_HUB_NAME" \
        messageRate=$MESSAGE_RATE \
        messageDuration=$DURATION \
        containerImage="$ACR_LOGIN_SERVER/eventhub-simulator:latest" \
        acrLoginServer="$ACR_LOGIN_SERVER" \
        acrUsername="$ACR_USERNAME" \
        acrPassword="$ACR_PASSWORD" \
    --output table

echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo "Monitor your deployment:"
echo "  az container logs --resource-group $RESOURCE_GROUP_NAME --name $CONTAINER_GROUP_NAME --follow"
echo ""
echo "Clean up resources when done:"
echo "  az group delete --name $RESOURCE_GROUP_NAME --yes --no-wait"
