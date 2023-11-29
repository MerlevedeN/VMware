#
#   Version:        1.0
#   Author:         MerlevedeN - https://github.com/MerlevedeN
#
#   Creation Date:  2023/09/18
#   Purpose/Change: This script will set new DNS Address to all ESXi hosts connected to the vCenter
#
#   Change: <DATE> : <CHANGE> (Also change Version)
#   Change: 2023/09/18 : Creation


 
$vCenter = "Pod-120-vCenter.SDDC.Lab"
$DNSServer1 = "10.3.36.11"
$DNSServer2 = "10.180.2.3"

Connect-VIserver -server $vCenter
$Hosts = Get-VMHost

foreach ($esx in $hosts ){

    Write-Host "Configuring DNS and Domain Name on $($esx)" -ForegroundColor Green
    Get-VMHostNetwork -VMHost $esx | Set-VMHostNetwork -DNSAddress $DNSServer1, $DNSServer2 -Confirm:$false

}