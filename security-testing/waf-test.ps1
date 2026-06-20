<#
.SYNOPSIS
  Probe AWS WAF. Attack payloads should return 403; the baseline returns 200.
  Requires PowerShell 7+ (uses -SkipCertificateCheck / -SkipHttpErrorCheck).
.EXAMPLE
  ./waf-test.ps1 -BaseUrl https://my-alb-123.ap-southeast-1.elb.amazonaws.com
#>
param([Parameter(Mandatory = $true)][string]$BaseUrl)

function Req($u) {
    try {
        (Invoke-WebRequest -Uri $u -SkipCertificateCheck -SkipHttpErrorCheck -TimeoutSec 15).StatusCode
    }
    catch {
        $_.Exception.Response.StatusCode.value__
    }
}

Write-Host "Baseline GET /login.php                 -> $(Req "$BaseUrl/login.php") (expect 200)"
Write-Host "SQLi  ' OR '1'='1                        -> $(Req "$BaseUrl/search.php?q=%27%20OR%20%271%27%3D%271") (expect 403)"
Write-Host "SQLi  UNION SELECT users                 -> $(Req "$BaseUrl/search.php?q=1%20UNION%20SELECT%20username%2Cpassword%20FROM%20users") (expect 403)"
Write-Host "SQLi  1; DROP TABLE users                -> $(Req "$BaseUrl/search.php?q=1%3B%20DROP%20TABLE%20users") (expect 403)"
Write-Host "XSS   <script>alert(1)</script>          -> $(Req "$BaseUrl/search.php?q=%3Cscript%3Ealert(1)%3C/script%3E") (expect 403)"
Write-Host "`n[i] 403 = blocked by AWS WAF at the edge."
