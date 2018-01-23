# ==================================================
# dynatrace pre-installation script
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

$logPath = "/var/vcap/sys/log/dynatrace-oneagent-windows/dynatrace-install.log"

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

# ==================================================
# main section
# ==================================================

LogInfo "Checking Dynatrace credentials and connectivity..."

# download mode setup
if ($cfgDownloadUrl.length -eq 0){
	if ($cfgEnvironmentId.length -eq 0 -or $cfgApiToken.length -eq 0) {
		LogError "Invalid configuration:"
		LogError "Set environmentid and apitoken for Dynatrace OneAgent."
		Exit 1
	}
	if ($cfgApiUrl.length -eq 0)  {
		$cfgApiUrl = "http://{0}.live.dynatrace.com/api" -f $cfgEnvironmentId
	}
	$cfgDownloadUrl = "{0}/v1/deployment/installer/agent/windows/default-unattended/latest?Api-Token={1}" -f $cfgApiUrl, $cfgApiToken
}

try {
	if ($cfgSslMode -eq "all") {
		LogInfo "Accepting all ssl certificates"
		SetupSslAcceptAll
	}
	Invoke-WebRequest -Method Head -UseBasicParsing -Uri $cfgDownloadUrl

} catch {
  LogError "Unable to connect to $cfgDownloadUrl"
	LogError "Error: $_.Exception.Response"
	Exit 1
}

LogInfo "Successfully connected to $cfgDownloadUrl"
Exit 0
