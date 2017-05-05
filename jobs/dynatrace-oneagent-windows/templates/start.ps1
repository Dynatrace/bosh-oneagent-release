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

$oneagentwatchdogProcessName = "oneagentwatchdog"
$agentDownloadTargetPath = "/var/vcap/data/tmp/Dynatrace-OneAgent-Windows.zip"
$agentExpandPath = "/var/vcap/data/tmp/dynatrace-oneagent-windows"
$logPath = "/var/vcap/sys/log/dynatrace-oneagent-windows/dynatrace-install.log"
$dynatraceServiceName = "Dynatrace OneAgent"
$exitHelperFile = "/var/vcap/jobs/dynatrace-oneagent-windows/exit"

# ==================================================
# function section
# ==================================================

function Log($level, $content) {
	$line = "{0} {1} {2}" -f (Get-Date), $level, $content

	try {
	    Write-Host ("LOG: {0}" -f $line)
	} catch {
	}

	try {
	    Write-Output $line | Out-File -Encoding ascii -Append $logPath
	} catch {
	}
}

function LogInfo($content) {
	Log "INFO" $content
}

function LogWarning($content) {
	Log "WARNING" $content
}

function LogError($content) {
	if ($_.Exception -ne $null) {
		Log "ERROR" ("Exception.Message = {0}" -f $_.Exception.Message)
	}
	Log "ERROR" $content
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

	$allProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
	[System.Net.ServicePointManager]::SecurityProtocol = $allProtocols
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
function Unzip
{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

function ExpandZipFile($filename, $destination) {
    LogInfo "filename: $filename"
    LogInfo "destination: $destination"

	Unzip "$filename" "$destination"
}

function SafeDelete($path) {
	try {
		Remove-Item -Recurse $path -Force
	} catch {
	}
}

function CleanupDownload() {
	try {
		LogInfo "Cleaning $agentDownloadTargetPath"
		if (Test-Path -Path $agentDownloadTargetPath) {
			SafeDelete $agentDownloadTargetPath
		}
	} catch {
		LogErrorAndExit "Unable to remove directory: $agentDownloadTargetPath"
	}
}

function CleanupExpandedAgent() {
	try {
		LogInfo "Cleaning $agentExpandPath"
		if (Test-Path -Path $agentExpandPath) {
			SafeDelete $agentExpandPath
		}
	} catch {
		LogErrorAndExit "Unable to remove directory: $agentExpandPath"
	}
}

function CleanupAll() {
	CleanupDownload
	CleanupExpandedAgent
}

function ExitFailed() {
	Log "ABORT" "Installation failed. See $logPath for more information."
	Exit 1
}

function ExitSuccess() {
	Exit 0
}

# ==================================================
# main section
# ==================================================

LogInfo "Installing Dynatrace OneAgent..."

# download mode setup
if ($cfgDownloadUrl.length -eq 0){
	if ($cfgEnvironmentId.length -eq 0 -or $cfgApiToken.length -eq 0) {
		LogError "Invalid configuration:"
		LogError "Set environmentid and apitoken for Dynatrace OneAgent."
		ExitFailed
	}
	if ($cfgApiUrl.length -eq 0)  {
		$cfgApiUrl = "http://{0}.live.dynatrace.com/api" -f $cfgEnvironmentId
	}
	$cfgDownloadUrl = "{0}/v1/deployment/installer/agent/windows/default-unattended/latest?Api-Token={1}" -f $cfgApiUrl, $cfgApiToken
}

LogInfo ("ENVIRONMENTID:   {0}" -f $cfgEnvironmentId)
LogInfo ("API URL:         {0}" -f $cfgApiUrl)
LogInfo ("API TOKEN:       {0}" -f $cfgApiToken)
LogInfo ("DOWNLOADURL:     {0}" -f $cfgDownloadUrl)

# download
try {
	CleanupDownload

	LogInfo "Download target: $agentDownloadTargetPath"

	if ($cfgSslMode -eq "all") {
		LogInfo "Accepting all ssl certificates"
		SetupSslAcceptAll
	}

	LogInfo "Downloading..."
	Invoke-WebRequest $cfgDownloadUrl -OutFile $agentDownloadTargetPath
} catch {
	LogError "Failed to download OneAgent for Windows"
	CleanupDownload
	ExitFailed
}

# extract

try {
  CleanupExpandedAgent

	LogInfo "Expanding $agentDownloadTargetPath to $agentExpandPath..."
	ExpandZipFile $agentDownloadTargetPath "$agentExpandPath"
} catch {
	LogError "Failed to extract $agentDownloadTargetPath"
	CleanupAll
	ExitFailed
}

#run the installer

try {
    $agentInstallerFile = $agentExpandPath + "/install.bat"

    # workaround missing /quiet option in install.bat
    (Get-Content $agentInstallerFile).replace('/L*v', '/quiet /qn /L*v') | Set-Content $agentInstallerFile
    $process = Start-Process -WorkingDirectory $agentExpandPath -FilePath "install.bat" -Wait -PassThru
    $process.WaitForExit()
} catch {
    LogError "Failed to run OneAgent installer $agentExpandPath /install.bat"
    ExitFailed
}

LogInfo "Installation done"

#Note: The installer automatically started the OneAgent after installation.
do {
	LogInfo "Waiting for $oneagentwatchdogProcessName to be started by the installer..."
	Start-Sleep -s 5
	$output = Get-Process | Where-Object {$_.ProcessName -match "$oneagentwatchdogProcessName"}
} while ($output.length -eq 0)

LogInfo "Process $oneagentwatchdogProcessName has started"

#run this script infinitely and exit when drain-script was started
LogInfo "Waiting for drain.ps1 to stop start.ps1 script..."

If (Test-Path "$exitHelperFile") {
	rm $exitHelperFile
}

while (!(Test-Path "$exitHelperFile"))
{
	Start-Sleep -s 5
}

LogInfo "Uninstalling $dynatraceServiceName..."

$app = Get-WMiObject -Class Win32_Product | Where-Object { $_.Name -match "$dynatraceServiceName" }
if ($app) {
	$app.Uninstall() >$null 2>&1
	LogInfo "Uninstall done"
} else {
	LogWarning "$dynatraceServiceName not found in installed products"
}

LogInfo "Exiting ..."

exit 0
