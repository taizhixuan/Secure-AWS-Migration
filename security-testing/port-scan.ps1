<#
.SYNOPSIS
  Port-scan the public ALB endpoint. Expected: only 80 and 443 reachable.
.EXAMPLE
  ./port-scan.ps1 -Target my-alb-123.ap-southeast-1.elb.amazonaws.com
#>
param([Parameter(Mandatory = $true)][string]$Target)

$ports = 22, 80, 443, 3306

if (Get-Command nmap -ErrorAction SilentlyContinue) {
    nmap -Pn -p 22,80,443,3306 $Target
}
else {
    Write-Host "nmap not found; falling back to Test-NetConnection per port.`n"
    foreach ($p in $ports) {
        $r = Test-NetConnection -ComputerName $Target -Port $p -WarningAction SilentlyContinue
        $state = if ($r.TcpTestSucceeded) { "OPEN" } else { "closed/filtered" }
        "{0,-6} {1}" -f $p, $state
    }
}

Write-Host "`n[i] Expected: 80 OPEN, 443 OPEN; 22 and 3306 closed/filtered."
