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
$logDir = "/var/vcap/sys/log/dynatrace-onagent-windows"
$logFile = "$logDir/dynatrace-install.log"
$dynatraceServiceName = "Dynatrace OneAgent"
$exitHelperFile = "/var/vcap/jobs/dynatrace-oneagent-windows/exit"

# ==================================================
# function section
# ==================================================
function installLog($level, $content) {
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

	$allProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
	[System.Net.ServicePointManager]::SecurityProtocol = $allProtocols
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
function Unzip($filename, $destination)
{
    installLog("INFO", "filename: $filename")
    installLog("INFO", "destination: $destination")

    [System.IO.Compression.ZipFile]::ExtractToDirectory($filename, $destination)
}

function ExpandZipFile($filename, $destination) {

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
		installLog("INFO", "Cleaning $agentDownloadTargetPath")
		if (Test-Path -Path $agentDownloadTargetPath) {
			SafeDelete $agentDownloadTargetPath
		}
	} catch {
		installLog("ERROR",AndExit "Unable to remove directory: $agentDownloadTargetPath")
	}
}

function CleanupExpandedAgent() {
	try {
		installLog("INFO", "Cleaning $agentExpandPath")
		if (Test-Path -Path $agentExpandPath) {
			SafeDelete $agentExpandPath
		}
	} catch {
		installLog("ERROR",AndExit "Unable to remove directory: $agentExpandPath")
	}
}

function CleanupAll() {
	CleanupDownload
	CleanupExpandedAgent
}


# ==================================================
# main section
# ==================================================

installLog("INFO", "Installing Dynatrace OneAgent...")

# download mode setup
if ($cfgDownloadUrl.length -eq 0){
	if ($cfgEnvironmentId.length -eq 0 -or $cfgApiToken.length -eq 0) {
		installLog("ERROR", "Invalid configuration:")
		installLog("ERROR", "Set environmentid and apitoken for Dynatrace OneAgent.")
		Exit 1
	}
	if ($cfgApiUrl.length -eq 0)  {
		$cfgApiUrl = "http://{0}.live.dynatrace.com/api" -f $cfgEnvironmentId
	}
	$cfgDownloadUrl = "{0}/v1/deployment/installer/agent/windows/default-unattended/latest?Api-Token={1}" -f $cfgApiUrl, $cfgApiToken
}

installLog("INFO", ("ENVIRONMENTID:   {0}" -f $cfgEnvironmentId))
installLog("INFO", ("API URL:         {0}" -f $cfgApiUrl))
installLog("INFO", ("API TOKEN:       {0}" -f $cfgApiToken))
installLog("INFO", ("DOWNLOADURL:     {0}" -f $cfgDownloadUrl))

# download
try {
	CleanupDownload

	installLog("INFO", "Download target: $agentDownloadTargetPath")

	if ($cfgSslMode -eq "all") {
		installLog("INFO", "Accepting all ssl certificates")
		SetupSslAcceptAll
	}

	installLog("INFO", "Downloading...")
	Invoke-WebRequest $cfgDownloadUrl -OutFile $agentDownloadTargetPath
} catch {
	installLog("ERROR", "Failed to download OneAgent for Windows")
	CleanupDownload
	Exit 1
}

# extract

try {
  CleanupExpandedAgent

	installLog("INFO", "Expanding $agentDownloadTargetPath to $agentExpandPath...")
	ExpandZipFile $agentDownloadTargetPath "$agentExpandPath"
} catch {
	installLog("ERROR", "Failed to extract $agentDownloadTargetPath")
	CleanupAll
	Exit 1
}

#run the installer

try {
    $agentInstallerFile = $agentExpandPath + "/install.bat"

    # workaround missing /quiet option in install.bat
    (Get-Content $agentInstallerFile).replace('/L*v', '/quiet /qn /L*v') | Set-Content $agentInstallerFile
    $process = Start-Process -WorkingDirectory $agentExpandPath -FilePath "install.bat" -Wait -PassThru
    $process.WaitForExit()
} catch {
    installLog("ERROR", "Failed to run OneAgent installer $agentExpandPath /install.bat")
    Exit 1
}

installLog("INFO", "Installation done")

#Note: The installer automatically started the OneAgent after installation.
do {
	installLog("INFO", "Waiting for $oneagentwatchdogProcessName to be started by the installer...")
	Start-Sleep -s 5
	$output = Get-Process | Where-Object {$_.ProcessName -match "$oneagentwatchdogProcessName"}
} while ($output.length -eq 0)

installLog("INFO", "Process $oneagentwatchdogProcessName has started")

#run this script infinitely and exit when drain-script was started
installLog("INFO", "Waiting for drain.ps1 to stop start.ps1 script...")

If (Test-Path "$exitHelperFile") {
	rm $exitHelperFile
}

while (!(Test-Path "$exitHelperFile"))
{
	Start-Sleep -s 5
}

installLog("INFO", "Uninstalling $dynatraceServiceName...")

$app = Get-WMiObject -Class Win32_Product | Where-Object { $_.Name -match "$dynatraceServiceName" }
if ($app) {
	$app.Uninstall() >$null 2>&1
	installLog("INFO", "Uninstall done")
} else {
	installLog("WARNING", "$dynatraceServiceName not found in installed products")
}

installLog("INFO", "Exiting ...")

Exit 0
