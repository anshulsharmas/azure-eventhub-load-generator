# Azure Container Instances Status Checker
# This script checks the status of multiple ACI instances from eventhub-simulator-1 to eventhub-simulator-800

param(
    [string]$ResourceGroupName = "high-throughput-streaming-poc",
    [int]$StartNumber = 1,
    [int]$EndNumber = 800,
    [string]$ContainerNamePrefix = "eventhub-simulator-",
    [switch]$ShowOnlyRunning,
    [switch]$ShowOnlyStopped,
    [switch]$Detailed,
    [switch]$ExportToCsv,
    [string]$CsvPath = "aci-status-$(Get-Date -Format 'yyyy-MM-dd-HHmm').csv"
)

Write-Host "Azure Container Instances Status Checker" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green

# Check if user is logged in to Azure
try {
    $subscription = az account show --query id -o tsv 2>$null
    if ($LASTEXITCODE -ne 0) { throw }
    Write-Host "Using subscription: $subscription" -ForegroundColor Green
}
catch {
    Write-Host "Please login to Azure first: az login" -ForegroundColor Red
    exit 1
}

# Verify resource group exists
Write-Host "Checking resource group: $ResourceGroupName" -ForegroundColor Yellow
$rgExists = az group exists --name $ResourceGroupName
if ($rgExists -eq "false") {
    Write-Host "Resource group '$ResourceGroupName' does not exist" -ForegroundColor Red
    exit 1
}

Write-Host "Resource group found" -ForegroundColor Green
Write-Host ""

# Initialize results array
$results = @()
$runningCount = 0
$stoppedCount = 0
$notFoundCount = 0
$errorCount = 0

Write-Host "Checking container instances $StartNumber to $EndNumber..." -ForegroundColor Yellow
Write-Host ""

# Progress tracking
$total = $EndNumber - $StartNumber + 1
$current = 0

for ($i = $StartNumber; $i -le $EndNumber; $i++) {
    $current++
    $containerName = "$ContainerNamePrefix$i"
    
    # Show progress every 50 containers
    if ($current % 50 -eq 0 -or $current -eq $total) {
        $percentComplete = [math]::Round(($current / $total) * 100, 1)
        Write-Progress -Activity "Checking ACI Status" -Status "Processed $current of $total containers ($percentComplete%)" -PercentComplete $percentComplete
    }
    
    try {
        # Get container instance details
        $aciInfo = az container show --resource-group $ResourceGroupName --name $containerName --query "{state:instanceView.state,restartCount:instanceView.restartCount,cpu:containers[0].resources.requests.cpu,memory:containers[0].resources.requests.memoryInGb,image:containers[0].image,startTime:instanceView.events[0].firstTimestamp}" -o json 2>$null
        
        if ($LASTEXITCODE -eq 0 -and $aciInfo) {
            $container = $aciInfo | ConvertFrom-Json
            $state = $container.state
            $restartCount = $container.restartCount
            $cpu = $container.cpu
            $memory = $container.memory
            $image = $container.image
            $startTime = $container.startTime
            
            # Determine status color
            $statusColor = switch ($state) {
                "Running" { "Green"; $runningCount++ }
                "Terminated" { "Red"; $stoppedCount++ }
                "Pending" { "Yellow"; $runningCount++ }
                "Succeeded" { "Cyan"; $stoppedCount++ }
                "Failed" { "Red"; $errorCount++ }
                default { "Gray"; $errorCount++ }
            }
            
            # Create result object
            $result = [PSCustomObject]@{
                ContainerName = $containerName
                State = $state
                RestartCount = $restartCount
                CPU = $cpu
                Memory = "$memory GB"
                Image = $image
                StartTime = $startTime
                Status = "Found"
            }
            
            $results += $result
            
            # Apply filters and display
            $shouldShow = $true
            if ($ShowOnlyRunning -and $state -ne "Running") { $shouldShow = $false }
            if ($ShowOnlyStopped -and $state -eq "Running") { $shouldShow = $false }
            
            if ($shouldShow) {
                if ($Detailed) {
                    Write-Host "Container: $containerName" -ForegroundColor White
                    Write-Host "   State: $state" -ForegroundColor $statusColor
                    Write-Host "   Restarts: $restartCount" -ForegroundColor Gray
                    Write-Host "   Resources: $cpu CPU, $memory GB RAM" -ForegroundColor Gray
                    Write-Host "   Image: $image" -ForegroundColor Gray
                    Write-Host "   Start Time: $startTime" -ForegroundColor Gray
                    Write-Host ""
                } else {
                    Write-Host "[$containerName] " -NoNewline -ForegroundColor White
                    Write-Host "$state" -ForegroundColor $statusColor
                }
            }
        } else {
            $notFoundCount++
            $result = [PSCustomObject]@{
                ContainerName = $containerName
                State = "Not Found"
                RestartCount = "N/A"
                CPU = "N/A"
                Memory = "N/A"
                Image = "N/A"
                StartTime = "N/A"
                Status = "Not Found"
            }
            
            $results += $result
            
            if (-not $ShowOnlyRunning -and -not $ShowOnlyStopped) {
                Write-Host "[$containerName] " -NoNewline -ForegroundColor White
                Write-Host "Not Found" -ForegroundColor Gray
            }
        }
    }
    catch {
        $errorCount++
        $result = [PSCustomObject]@{
            ContainerName = $containerName
            State = "Error"
            RestartCount = "N/A"
            CPU = "N/A"
            Memory = "N/A"
            Image = "N/A"
            StartTime = "N/A"
            Status = "Error: $($_.Exception.Message)"
        }
        
        $results += $result
        
        Write-Host "[$containerName] " -NoNewline -ForegroundColor White
        Write-Host "Error checking status" -ForegroundColor Red
    }
}

# Clear progress bar
Write-Progress -Activity "Checking ACI Status" -Completed

Write-Host ""
Write-Host "Summary Statistics" -ForegroundColor Green
Write-Host "==================" -ForegroundColor Green
Write-Host "Running/Pending: $runningCount" -ForegroundColor Green
Write-Host "Stopped/Failed: $($stoppedCount + $errorCount)" -ForegroundColor Red
Write-Host "Not Found: $notFoundCount" -ForegroundColor Gray
Write-Host "Total Checked: $total" -ForegroundColor White

# Calculate percentages
if ($total -gt 0) {
    $runningPercent = [math]::Round(($runningCount / $total) * 100, 1)
    $stoppedPercent = [math]::Round((($stoppedCount + $errorCount) / $total) * 100, 1)
    $notFoundPercent = [math]::Round(($notFoundCount / $total) * 100, 1)
    
    Write-Host ""
    Write-Host "Percentages:" -ForegroundColor Cyan
    Write-Host "   Running: $runningPercent%" -ForegroundColor Green
    Write-Host "   Stopped: $stoppedPercent%" -ForegroundColor Red
    Write-Host "   Not Found: $notFoundPercent%" -ForegroundColor Gray
}

# Export to CSV if requested
if ($ExportToCsv) {
    Write-Host ""
    Write-Host "Exporting results to CSV: $CsvPath" -ForegroundColor Yellow
    $results | Export-Csv -Path $CsvPath -NoTypeInformation
    Write-Host "CSV exported successfully" -ForegroundColor Green
}

Write-Host ""
Write-Host "Useful commands:" -ForegroundColor Cyan
Write-Host "   View logs: az container logs --resource-group $ResourceGroupName --name <container-name> --follow" -ForegroundColor Gray
Write-Host "   Restart container: az container restart --resource-group $ResourceGroupName --name <container-name>" -ForegroundColor Gray
Write-Host "   Delete container: az container delete --resource-group $ResourceGroupName --name <container-name> --yes" -ForegroundColor Gray
Write-Host ""
Write-Host "Script completed!" -ForegroundColor Green
