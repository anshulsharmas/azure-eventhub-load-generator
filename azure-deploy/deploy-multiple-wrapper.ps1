# Minimal wrapper to deploy containers 11-20
# Just loops and calls deploy-aci.ps1 with different ContainerGroupName

param(
    [string]$ResourceGroupName = "high-throughput-streaming-poc",
    [string]$Location = "eastus2", 
    [string]$AcrName = "eventhubsimacr"
)

$deployScript = "$PSScriptRoot/deploy-aci.ps1"
# Loop through numbers 11-20 and call deploy-aci.ps1 with different ContainerGroupName
11..20 | ForEach-Object {
    $containerGroupName = "eventhub-simulator-$_"
    Write-Host "Deploying container: $containerGroupName"
    
    & $deployScript -ResourceGroupName $ResourceGroupName -Location $Location -AcrName $AcrName -ContainerGroupName $containerGroupName
}
