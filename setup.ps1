# Azure Event Hub Simulator - PowerShell Setup Script

Write-Host "Azure Event Hub Simulator - PowerShell Setup" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Check if Python is installed
try {
    $pythonVersion = python --version 2>&1
    Write-Host "Found: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "Error: Python is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Python 3.7+ and try again" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "`nInstalling dependencies..." -ForegroundColor Yellow

# Install requirements
try {
    python -m pip install -r requirements.txt
    Write-Host "Dependencies installed successfully!" -ForegroundColor Green
} catch {
    Write-Host "Error: Failed to install requirements" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""

# Check environment variables
$connectionString = $env:EVENT_HUB_CONNECTION_STRING
$eventHubName = $env:EVENT_HUB_NAME

if ([string]::IsNullOrEmpty($connectionString)) {
    Write-Host "Warning: EVENT_HUB_CONNECTION_STRING environment variable is not set" -ForegroundColor Yellow
    Write-Host "Please set this variable before running the simulator" -ForegroundColor Yellow
    Write-Host ""
}

if ([string]::IsNullOrEmpty($eventHubName)) {
    Write-Host "Warning: EVENT_HUB_NAME environment variable is not set" -ForegroundColor Yellow
    Write-Host "Please set this variable before running the simulator" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Example commands:" -ForegroundColor Cyan
Write-Host "  python eventhub_simulator.py --help" -ForegroundColor White
Write-Host "  python eventhub_simulator.py --rate 10000 --duration 300" -ForegroundColor White
Write-Host "  python performance_test.py" -ForegroundColor White
Write-Host ""

# Offer to set environment variables if missing
if ([string]::IsNullOrEmpty($connectionString) -or [string]::IsNullOrEmpty($eventHubName)) {
    $setVars = Read-Host "Would you like to set environment variables now? (y/n)"
    if ($setVars -eq "y" -or $setVars -eq "Y") {
        if ([string]::IsNullOrEmpty($connectionString)) {
            $connectionString = Read-Host "Enter EVENT_HUB_CONNECTION_STRING"
            [Environment]::SetEnvironmentVariable("EVENT_HUB_CONNECTION_STRING", $connectionString, "User")
        }
        
        if ([string]::IsNullOrEmpty($eventHubName)) {
            $eventHubName = Read-Host "Enter EVENT_HUB_NAME"
            [Environment]::SetEnvironmentVariable("EVENT_HUB_NAME", $eventHubName, "User")
        }
        
        Write-Host "Environment variables set! Restart PowerShell to use them." -ForegroundColor Green
    }
}

Read-Host "Press Enter to exit"
