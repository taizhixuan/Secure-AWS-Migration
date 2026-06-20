<#
.SYNOPSIS
  Run ALL Part E security tests against the deployed SIS and print the results.
.EXAMPLE
  ./run-all.ps1
  ./run-all.ps1 -Alb my-alb-1234.ap-southeast-1.elb.amazonaws.com
.NOTES
  Needs: AWS CLI configured (T3/T4). nmap optional (T1 falls back to Test-NetConnection).
#>
param(
  [string]$Alb    = "mmu-sis-prod-alb-1870207398.ap-southeast-1.elb.amazonaws.com",
  [string]$Region = "ap-southeast-1",
  [string]$Prefix = "mmu-sis-prod"
)
$base = "https://$Alb"

Write-Host "`n========== T1 - PORT SCAN ($Alb) ==========" -ForegroundColor Cyan
if (Get-Command nmap -ErrorAction SilentlyContinue) {
  nmap -Pn -p 22,80,443,3306 $Alb
} else {
  Write-Host "(nmap not found - using Test-NetConnection)"
  foreach ($p in 22,80,443,3306) {
    $r = Test-NetConnection $Alb -Port $p -WarningAction SilentlyContinue
    "{0,-6} {1}" -f $p, ($(if ($r.TcpTestSucceeded) { 'open' } else { 'filtered' }))
  }
}

Write-Host "`n========== T2 - WAF (SQL-injection / XSS) ==========" -ForegroundColor Cyan
curl.exe -sk -o NUL -w "Legitimate /login.php                 -> %{http_code}\n" "$base/login.php"
curl.exe -sk -o NUL -w "SQLi       ' OR '1'='1                -> %{http_code}\n" "$base/search.php?q=%27%20OR%20%271%27%3D%271"
curl.exe -sk -o NUL -w "SQLi       UNION SELECT users         -> %{http_code}\n" "$base/search.php?q=1%20UNION%20SELECT%20username,password%20FROM%20users"
curl.exe -sk -o NUL -w "XSS        <script>alert(1)</script>  -> %{http_code}\n" "$base/search.php?q=%3Cscript%3Ealert(1)%3C/script%3E"

Write-Host "`n========== T5 - HTTPS / redirect ==========" -ForegroundColor Cyan
curl.exe -sk -o NUL -w "HTTP  http://  -> %{http_code} (expect 301)\n" "http://$Alb/"
curl.exe -sk -o NUL -w "HTTPS https:// -> %{http_code} (expect 200)\n" "$base/health.php"

Write-Host "`n========== T3 - ENCRYPTION AT REST ==========" -ForegroundColor Cyan
aws rds describe-db-instances --region $Region --query "DBInstances[?contains(DBInstanceIdentifier,'$Prefix')].{ID:DBInstanceIdentifier,Encrypted:StorageEncrypted,KMS:KmsKeyId}" --output table
foreach ($b in (aws s3api list-buckets --query "Buckets[?contains(Name,'$Prefix')].Name" --output text).Split()) {
  if ($b) { Write-Host "-- $b"; aws s3api get-bucket-encryption --bucket $b --query "ServerSideEncryptionConfiguration.Rules[].ApplyServerSideEncryptionByDefault" --output table }
}
aws secretsmanager list-secrets --region $Region --query "SecretList[?contains(Name,'$Prefix')].{Name:Name,KmsKeyId:KmsKeyId}" --output table

Write-Host "`n========== T4 - CLOUDTRAIL AUDIT ==========" -ForegroundColor Cyan
aws cloudtrail describe-trails --region $Region --query "trailList[?contains(Name,'$Prefix')].{Name:Name,MultiRegion:IsMultiRegionTrail,Validation:LogFileValidationEnabled,KMS:KmsKeyId}" --output table

Write-Host "`n========== ALL SECURITY TESTS DONE ==========" -ForegroundColor Green
