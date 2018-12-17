# ==================================================
# dynatrace installation script
# ==================================================
# configuration section
# ==================================================

$ProgressPreference = "SilentlyContinue"

$cfgDownloadUrl = "<%= properties.dynatrace.downloadurl %>"
$cfgProxy = "<%= properties.dynatrace.proxy %>"
$cfgEnvironmentId = "<%= properties.dynatrace.environmentid %>"
$cfgApiToken = "<%= properties.dynatrace.apitoken %>"
$cfgApiUrl = "<%= properties.dynatrace.apiurl %>"
$cfgSslMode = "<%= properties.dynatrace.sslmode %>"
$cfgHostGroup = "<%= properties.dynatrace.hostgroup %>"
$cfgHostTags = "<%= properties.dynatrace.hosttags %>"
$cfgHostProps = "<%= properties.dynatrace.hostprops %> BOSH_RELEASE_VERSION=<%= spec.release.version %>"
$cfgInfraOnly = "<%= properties.dynatrace.infraonly %>"

$oneagentwatchdogProcessName = "oneagentwatchdog"
$tempDir = "/var/vcap/data/dt_tmp"
$installerFile = "$tempDir/Dynatrace-OneAgent-Windows.zip"
$agentExpandPath = "$tempDir/dynatrace-oneagent-windows"
$logDir = "/var/vcap/sys/log/dynatrace-oneagent-windows"
$logFile = "$logDir/dynatrace-install.log"
$configDir = "$env:ProgramData\dynatrace\oneagent\agent\config"
$dynatraceServiceName = "Dynatrace OneAgent"
$exitHelperFile = "$tempDir/exit"

# ==================================================
# function section
# ==================================================
function installLog ($level, $content) {
	$line = "{0} {1} {2}" -f (Get-Date), $level, $content

	Write-Host $line
	Write-Output $line | Out-File -Encoding utf8 -Append $logFile
}

function SetupSslAcceptAll {
	$codeProvider = New-Object Microsoft.CSharp.CSharpCodeProvider
	$codeCompilerParams = New-Object System.CodeDom.Compiler.CompilerParameters
	$codeCompilerParams.GenerateExecutable = $false
	$codeCompilerParams.GenerateInMemory = $true
	$codeCompilerParams.IncludeDebugInformation = $false
	$codeCompilerParams.ReferencedAssemblies.Add("System.DLL") > $null
	$trustAllSource=@'
		namespace Local.ToolkitExtensions.Net.CertificatePolicy {
			public class TrustAll : System.Net.ICertificatePolicy {
				public TrustAll() {}
				public bool CheckValidationResult(System.Net.ServicePoint sp,System.Security.Cryptography.X509Certificates.X509Certificate cert, System.Net.WebRequest req, int problem) {
					return true;
				}
			}
		}
'@

	$trustAllResults = $codeProvider.CompileAssemblyFromSource($codeCompilerParams, $trustAllSource)
	$truxtAllAssembly=$trustAllResults.CompiledAssembly

	$trustAll = $truxtAllAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")

	[System.Net.ServicePointManager]::CertificatePolicy = $trustAll

	$allProtocols = [System.Net.SecurityProtocolType]'Tls,Tls11,Tls12'
	[System.Net.ServicePointManager]::SecurityProtocol = $allProtocols
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
function Unzip($filename, $destination)
{
	installLog "INFO" "Extracting $filename to $destination"

	[System.IO.Compression.ZipFile]::ExtractToDirectory($filename, $destination)
}

function deleteItem($path) {
	try {
		Remove-Item -Recurse $path -Force
	} catch {
	}
}

function removeInstallerArchive() {
	try {
		installLog "INFO" "Cleaning $installerFile"
		if (Test-Path -Path $installerFile) {
			deleteItem $installerFile
		}
	} catch {
		installLog "ERROR" "Unable to remove directory: $installerFile"
	}
}

function removeExpandedInstaller() {
	try {
		installLog "INFO" "Cleaning $agentExpandPath"
		if (Test-Path -Path $agentExpandPath) {
			deleteItem $agentExpandPath
		}
	} catch {
		installLog "ERROR" "Unable to remove directory: $agentExpandPath"
	}
}

function CleanupAll() {
	removeInstallerArchive
	removeExpandedInstaller
}

function downloadAgent($src, $dest) {
	$downloadUrl = $src
	$installerPath = $dest
	$retryTimeout = 0
	$downloadErrors = 0

	if ($cfgSslMode -eq "all") {
		installLog "INFO" "Accepting all ssl certificates"
		SetupSslAcceptAll
	}

	while($downloadErrors -lt 3) {
		Start-Sleep -s $retryTimeout

		Try {
			installLog "INFO" "Downloading Dynatrace agent from $downloadUrl to $installerPath"
			Invoke-WebRequest $downloadUrl -Outfile $installerPath
			Break
		} Catch {
			installLog "ERROR" "Failed to download: $($_.Exception.Message)"

			$downloadErrors = $downloadErrors + 1
			$retryTimeout = $retryTimeout + 5
			installLog "ERROR" "Dynatrace agent download failed, retrying in $retryTimeout seconds"
		}
	}

	if ($downloadErrors -eq 3) {
		installLog "ERROR" "Downloading agent installer failed!"
		Exit 1
	}
}

function configureProxySettings() {
	if ($cfgProxy) {
		installLog "INFO" "Proxy settings found, setting system proxy to $cfgProxy"

		try {
			$reg = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"

			Set-ItemProperty -Path $reg -Name ProxyServer -Value $cfgProxy
			Set-ItemProperty -Path $reg -Name ProxyEnable -Value 1
		} catch {
			installLog "ERROR" "Setting system proxy failed!"
			Exit 1
		}
	}
}

function setHostTags() {
	if ($cfgHostTags -ne "") {
		$hostTagsFile = "${configDir}\hostautotag.conf"

		installLog "INFO" "Setting host tags to '$cfgHostTags' at $hostTagsFile"
		Set-Content -Path $hostTagsFile -Value $cfgHostTags
	}
}

function setHostProps() {
	$hostPropsFile = "${configDir}\hostcustomproperties.conf"

	installLog "INFO" "Setting host properties to '$cfgHostProps' at $hostPropsFile"
	Set-Content -Path $hostPropsFile -Value $cfgHostProps
}

# ==================================================
# main section
# ==================================================

installLog "INFO" "Dynatrace BOSH Add-on version <%= spec.release.version %>"

installLog "INFO" "Installing Dynatrace OneAgent..."
CleanupAll

if (!(Test-Path $tempDir)) {
	New-Item -ItemType Directory -Path $tempDir
}

if (!(Test-Path $agentExpandPath)) {
	New-Item -ItemType Directory -Path $agentExpandPath
}

if (!(Test-Path $configDir)) {
	New-Item -ItemType Directory -Path $configDir
}

configureProxySettings
setHostTags
setHostProps

# download mode setup
if ($cfgDownloadUrl.length -eq 0){
	if ($cfgEnvironmentId.length -eq 0) {
		installLog "ERROR" "Invalid configuration: Please provide environment ID!"
		Exit 1
	} elseif ($cfgApiToken.Length -eq 0) {
		installLog "ERROR" "Invalid configuration: Please provide API token!"
	}

	if ($cfgApiUrl.length -eq 0)  {
		$cfgApiUrl = "http://{0}.live.dynatrace.com/api" -f $cfgEnvironmentId
	}
	$cfgDownloadUrl = "{0}/v1/deployment/installer/agent/windows/default-unattended/latest?Api-Token={1}" -f $cfgApiUrl, $cfgApiToken
}

# do we really want to log these?
installLog "INFO" "Using API URL $cfgApiUrl"

downloadAgent $cfgDownloadUrl $installerFile

try {
	installLog "INFO" "Expanding $installerFile to $agentExpandPath..."
	Unzip "$installerFile" "$agentExpandPath"
} catch {
	installLog "ERROR" "Failed to extract $installerFile to $agentExpandPath"
	Exit 1
}

#run the installer
try {
	$commandArguments = "/quiet /qn"
	if ($cfgHostGroup -ne "") {
		installLog "INFO" "Setting host group to $cfgHostGroup"
		$commandArguments += " HOST_GROUP=$cfgHostGroup"
	}

	if ($cfgInfraOnly -eq "1") {
		installLog "INFO" "Enabling Infra-Only mode"
		$commandArguments += " INFRA_ONLY=$cfgInfraOnly"
	}

	# Arguments passed to install.bat will be appended to the agent installation command.
	$process = Start-Process -WorkingDirectory $agentExpandPath -FilePath "install.bat" -ArgumentList $commandArguments -Wait -PassThru
	$process.WaitForExit()
	if ($process.ExitCode -ne 0) {
		throw "Installation process exited with code $($process.ExitCode)"
	}
} catch {
	installLog "ERROR" "Failed to run OneAgent installer $agentExpandPath/install.bat: $($_.Exception.Message)"
	Exit 1
}
installLog "INFO" "Installation done"

#Note: The installer automatically started the OneAgent after installation.
$watchdogWaitCounter = 0
do {
	if($watchdogWaitCounter -gt 300) {
		installLog "ERROR" "{0} did not start in time!" -f $oneagentwatchdogProcessName
		Exit 1
	}

	installLog "INFO" "Waiting for $oneagentwatchdogProcessName to be started by the installer..."
	Start-Sleep -s 5
	$output = Get-Process | Where-Object {$_.ProcessName -match "$oneagentwatchdogProcessName"}
	$watchdogWaitCounter++
} while ($output.length -eq 0)
installLog "INFO" "Process $oneagentwatchdogProcessName has started"

#run this script infinitely and exit when drain-script was started
installLog "INFO" "Waiting for drain.ps1 to stop start.ps1 script..."

If (Test-Path "$exitHelperFile") {
	Remove-Item $exitHelperFile
}

while (!(Test-Path "$exitHelperFile")) {
	Start-Sleep -s 5
}

installLog "INFO" "Uninstalling $dynatraceServiceName..."

$app = Get-WMiObject -Class Win32_Product | Where-Object { $_.Name -match "$dynatraceServiceName" }
if ($app) {
	$app.Uninstall() >$null 2>&1
	installLog "INFO" "Uninstalling $dynatraceServiceName done"
} else {
	installLog "WARNING" "$dynatraceServiceName not found in installed products"
}

CleanupAll
installLog "INFO" "Exiting ..."

# Remove exit helper file. This will indicate to drain.ps1 that we have uninstalled the agent successfully.
Remove-Item $exitHelperFile

Exit 0
