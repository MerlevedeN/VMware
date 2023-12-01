# To show your default error action type
$ErrorActionPreference = "Stop"

$cred = Get-Credential -Message "Please enter your vCenter Credentials"
$vCenter = "vCenterName"

try {
    Connect-VIServer $vCenter -Credential $cred | Out-Null
    Write-host "Connected to $($vCenter)" -ForegroundColor Green
}
catch {
    Write-Host "Error connecting to $($vCenter)" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Exit
}

# Import Custom Attributes information from CSV
$servers = import-csv -Path ".\VM_CustomAttributes.csv" -Delimiter ";"

foreach ($server in $servers){

    Write-host "   Set Attributes for $($server.VMName)" -ForegroundColor Yellow -NoNewline
    $vm = Get-VM -Name $server.VMName
    $vm | Set-Annotation -CustomAttribute "Service_Request" -Value $server.SR  | Out-Null
    $vm | Set-Annotation -CustomAttribute "Requestor" -Value $server.Requester | Out-Null
    $vm | Set-Annotation -CustomAttribute "Server_Purpose" -Value $server.Description  | Out-Null
    $vm | Set-Annotation -CustomAttribute "Deploy_date" -Value $server.Install  | Out-Null
    Write-host "  => Attributes Set" -ForegroundColor DarkGreen
}

try {
    Disconnect-VIServer $vCenter -Confirm:$false
    Write-host "Disconnected from $($vCenter)" -ForegroundColor Green
}
catch {
    Write-Host "Error disconnecting from $($vCenter)" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
