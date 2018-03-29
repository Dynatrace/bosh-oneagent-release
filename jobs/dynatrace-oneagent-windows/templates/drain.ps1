$drainLogFile = "/var/vcap/sys/log/dynatrace-oneagent-windows/drain.log"
$dynatraceServiceName = "Dynatrace OneAgent"
$registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains"
$removeDomains = @()
$removeDomains = "dynatrace.com", "dynatrace-managed.com"
$cfgDownloadUrl = "<%= properties.dynatrace.downloadurl %>"

If ($cfgDownloadUrl -ne "" -and $cfgDownloadUrl -match "^https:\/\/") {
    $splitOptions = [System.StringSplitOptions]::RemoveEmptyEntries
    $customDownloadUrl = $cfgDownloadUrl.Split("//", $splitOptions)[1].Split("/", $splitOptions)[0]
    If( $customDownloadUrl -match "[a-zA-Z0-9]") {
        $removeDomains += "$customDownloadUrl"
    }
}

Write-Output 'die' | Out-File -Encoding utf8 /var/vcap/jobs/dynatrace-oneagent-windows/exit

Start-Sleep -s 5

#wait for start.ps1 to uninstall Dynatrace OneAgent
do {
	Start-Sleep -s 3
	$output = Get-Service | Where-Object {$_.Name -match "$dynatraceServiceName"}
} while ($output.length -ne 0 -and $output.Status -eq 'Running')

foreach($domain in $removeDomains) {
    If(Test-Path "$registryPath\$domain") {
        Remove-Item "$registryPath\$domain" -Recurse
        Write-Output "Removed $domain from trusted sites" | Out-File -Encoding utf8 $drainLogFile
    } 
}
Start-Sleep -s 15

If ((Get-Service dynatrace-oneagent-windows -ErrorAction SilentlyContinue).Status -ne "Running") {
    Write-Output 'success' | Out-File -Encoding utf8 $drainLogFile
} Else {
    Write-Output 'failed' | Out-File -Encoding utf8 $drainLogFile
    Write-Host 1
}

Write-Host 0

