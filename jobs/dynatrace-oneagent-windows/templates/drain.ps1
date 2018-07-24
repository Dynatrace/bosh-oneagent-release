# Name of the service wrapping the start.ps1 script.
$wrapperServiceName = "dynatrace-oneagent-windows"

$drainLogFile = "/var/vcap/sys/log/dynatrace-oneagent-windows/drain.log"
$dynatraceServiceName = "Dynatrace OneAgent"
$registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains"
$removeDomains = @()
$removeDomains = "dynatrace.com", "dynatrace-managed.com"
$cfgDownloadUrl = "<%= properties.dynatrace.downloadurl %>"

$tempDir = "/var/vcap/data/dt_tmp"
$exitHelperFile = "$tempDir/exit"

function drainLog($level, $content) {
	$line = "{0} {1} {2}" -f (Get-Date), $level, $content
	Write-Output $line | Out-File -Encoding utf8 -Append $drainLogFile
}

If ($cfgDownloadUrl -ne "" -and $cfgDownloadUrl -match "^https:\/\/") {
	$splitOptions = [System.StringSplitOptions]::RemoveEmptyEntries
	$customDownloadUrl = $cfgDownloadUrl.Split("//", $splitOptions)[1].Split("/", $splitOptions)[0]
	If( $customDownloadUrl -match "[a-zA-Z0-9]") {
		$removeDomains += "$customDownloadUrl"
	}
}

# This signals start.ps1 to start uninstalling the agent, and to exit itself.
# If start.ps1 finishes successfully, it will delete this file.
Write-Output 'die' | Out-File -Encoding utf8 $exitHelperFile

Start-Sleep -s 5

drainLog "INFO" "Waiting until $wrapperServiceName service shuts down"

$timer =  [system.diagnostics.stopwatch]::StartNew()

do {
	# Time-out after 5 minutes waiting.
	if ($timer.Elapsed.TotalSeconds -gt (5 * 60)) {
		drainLog "ERROR" "Time-out while waiting for $wrapperServiceName service shutdown."
		exit 1
	}

	Start-Sleep -s 3
	$output = Get-Service | Where-Object {$_.Name -match "$wrapperServiceName"}
} while ($output.length -ne 0 -and $output.Status -eq 'Running')

drainLog "INFO" "$dynatraceServiceName service has stopped"

foreach ($domain in $removeDomains) {
	if (Test-Path "$registryPath\$domain") {
		Remove-Item "$registryPath\$domain" -Recurse
		drainLog "INFO" "Removed $domain from trusted sites"
	}
}

# start.ps1 should have deleted the exit helper file if everything went well.
# If it's still there, then the script failed at some point.
if (Test-Path $exitHelperFile) {
	drainLog "WARN" "$exitHelperFile exists. start.ps1 likely failed."
	drainLog "ERROR" "Failed"
	exit 1
}

drainLog "INFO" "Success"

Write-Host 0
exit 0
