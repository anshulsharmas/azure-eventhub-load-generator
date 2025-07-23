# Bulk ACI Management Script
# This script helps manage multiple Azure Container Instances

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("start", "stop", "restart", "delete", "logs")]
    [string]$Action,
    
    [string]$ResourceGroupName = "high-throughput-streaming-poc",
    [int]$StartNumber = 1,
    [int]$EndNumber = 35,
    [string]$ContainerNamePrefix = "eventhub-simulator-",
    [switch]$Force,
    [switch]$Parallel,
    [int]$MaxConcurrency = 10,
    [string]$LogContainer = ""
)

Write-Host "Bulk ACI Management Tool" -ForegroundColor Green
Write-Host "========================" -ForegroundColor Green
Write-Host "Action: $Action" -ForegroundColor Yellow
Write-Host "Range: $ContainerNamePrefix$StartNumber to $ContainerNamePrefix$EndNumber" -ForegroundColor Yellow
Write-Host ""

# Check Azure login
try {
    $subscription = az account show --query id -o tsv 2>$null
    if ($LASTEXITCODE -ne 0) { throw }
    Write-Host "Using subscription: $subscription" -ForegroundColor Green
}
catch {
    Write-Host "Please login to Azure first: az login" -ForegroundColor Red
    exit 1
}

# Safety check for destructive operations
if ($Action -eq "delete" -and -not $Force) {
    $confirmRange = "$ContainerNamePrefix$StartNumber to $ContainerNamePrefix$EndNumber"
    $confirmation = Read-Host "This will DELETE containers $confirmRange in $ResourceGroupName. Type 'DELETE' to confirm"
    if ($confirmation -ne "DELETE") {
        Write-Host "Operation cancelled" -ForegroundColor Red
        exit 1
    }
}

# Special handling for logs action
if ($Action -eq "logs") {
    if ([string]::IsNullOrEmpty($LogContainer)) {
        Write-Host "For logs action, please specify -LogContainer parameter" -ForegroundColor Red
        Write-Host "Example: .\bulk-aci-manage.ps1 -Action logs -LogContainer eventhub-simulator-1" -ForegroundColor Gray
        exit 1
    }
    
    Write-Host "Fetching logs for: $LogContainer" -ForegroundColor Yellow
    az container logs --resource-group $ResourceGroupName --name $LogContainer --follow
    exit 0
}

# Build container list
$containers = @()
for ($i = $StartNumber; $i -le $EndNumber; $i++) {
    $containers += "$ContainerNamePrefix$i"
}

Write-Host "Target containers: $($containers.Count)" -ForegroundColor Cyan

# Function to execute action on a single container
function Invoke-ContainerAction {
    param($ContainerName, $Action, $ResourceGroupName)
    
    try {
        switch ($Action) {
            "start" {
                Write-Host "Starting $ContainerName..." -ForegroundColor Green
                az container start --resource-group $ResourceGroupName --name $ContainerName
            }
            "stop" {
                Write-Host "Stopping $ContainerName..." -ForegroundColor Yellow
                az container stop --resource-group $ResourceGroupName --name $ContainerName
            }
            "restart" {
                Write-Host "Restarting $ContainerName..." -ForegroundColor Blue
                az container restart --resource-group $ResourceGroupName --name $ContainerName
            }
            "delete" {
                Write-Host "Deleting $ContainerName..." -ForegroundColor Red
                az container delete --resource-group $ResourceGroupName --name $ContainerName --yes
            }
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "${ContainerName}: $Action completed" -ForegroundColor Green
            return $true
        } else {
            Write-Host "${ContainerName}: $Action failed" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "${ContainerName}: Error - $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Execute actions
$successCount = 0
$failureCount = 0
$startTime = Get-Date

if ($Parallel) {
    Write-Host "Executing $Action in parallel (max $MaxConcurrency concurrent operations)..." -ForegroundColor Yellow
    
    # Split containers into batches
    $batches = @()
    for ($i = 0; $i -lt $containers.Count; $i += $MaxConcurrency) {
        $batch = $containers[$i..([Math]::Min($i + $MaxConcurrency - 1, $containers.Count - 1))]
        $batches += ,$batch
    }
    
    foreach ($batch in $batches) {
        Write-Host "Processing batch of $($batch.Count) containers..." -ForegroundColor Cyan
        
        $jobs = @()
        foreach ($container in $batch) {
            $job = Start-Job -ScriptBlock {
                param($ContainerName, $Action, $ResourceGroupName)
                
                try {
                    switch ($Action) {
                        "start" { az container start --resource-group $ResourceGroupName --name $ContainerName --no-wait }
                        "stop" { az container stop --resource-group $ResourceGroupName --name $ContainerName }
                        "restart" { az container restart --resource-group $ResourceGroupName --name $ContainerName --no-wait }
                        "delete" { az container delete --resource-group $ResourceGroupName --name $ContainerName --yes --no-wait }
                    }
                    
                    return @{
                        Container = $ContainerName
                        Success = ($LASTEXITCODE -eq 0)
                        ExitCode = $LASTEXITCODE
                    }
                }
                catch {
                    return @{
                        Container = $ContainerName
                        Success = $false
                        Error = $_.Exception.Message
                    }
                }
            } -ArgumentList $container, $Action, $ResourceGroupName
            
            $jobs += $job
        }
        
        # Wait for batch to complete
        $jobs | Wait-Job | ForEach-Object {
            $result = Receive-Job $_
            Remove-Job $_
            
            if ($result.Success) {
                Write-Host "$($result.Container): $Action completed" -ForegroundColor Green
                $successCount++
            } else {
                Write-Host "$($result.Container): $Action failed" -ForegroundColor Red
                $failureCount++
            }
        }
        
        Start-Sleep -Seconds 1  # Brief pause between batches
    }
} else {
    Write-Host "Executing $Action sequentially..." -ForegroundColor Yellow
    
    foreach ($container in $containers) {
        if (Invoke-ContainerAction -ContainerName $container -Action $Action -ResourceGroupName $ResourceGroupName) {
            $successCount++
        } else {
            $failureCount++
        }
        
        # Small delay to avoid overwhelming Azure API
        Start-Sleep -Milliseconds 500
    }
}

# Summary
$endTime = Get-Date
$duration = $endTime - $startTime

Write-Host ""
Write-Host "Operation Summary" -ForegroundColor Green
Write-Host "=================" -ForegroundColor Green
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $failureCount" -ForegroundColor Red
Write-Host "Duration: $($duration.TotalSeconds.ToString('F1')) seconds" -ForegroundColor Cyan
Write-Host "Success Rate: $(if($containers.Count -gt 0) { [math]::Round(($successCount / $containers.Count) * 100, 1) } else { 0 })%" -ForegroundColor Cyan

if ($Action -eq "start" -or $Action -eq "restart") {
    Write-Host ""
    Write-Host "Note: Containers may take a few minutes to fully start and begin processing" -ForegroundColor Yellow
    Write-Host "Check status with: .\check-aci-status.ps1 -StartNumber $StartNumber -EndNumber $EndNumber" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Bulk operation completed!" -ForegroundColor Green
