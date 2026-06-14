Set-StrictMode -Version Latest
<#
File env.json contains the configuration values used by this script.
Save the file in the same path where this script is saved.

# -------------------------------------------------------------------
# env.json file variables
# -------------------------------------------------------------------

{
  "LogFileName": "VMware.log", 
  "SmtpServer": "smtp.server.com",
  "SmtpUsername": "user@domain.com",
  "SmtpPassword": "password of email",
  "From": "Alerts <from@domain.com>",
  "To": "to@domain.com",
  "Port": 587,
  "UseSsl": true,
  "vmServerIP": "192.168.1.225",
  "vmUsername": "root",
  "vmPassword": "password123"
}

#>

# -------------------------------------------------------------------
# Import JSON file
# -------------------------------------------------------------------
$configPath = Join-Path $PSScriptRoot "env.json"
if (-not (Test-Path $configPath))
{
	throw "Configuration file not found: $configPath"
}
$config = Get-Content $configPath -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

# -------------------------------------------------------------------
# Load logging module
# -------------------------------------------------------------------
$logsPath = Join-Path $PSScriptRoot "WriteLogs_Fun.ps1"
if (Test-Path $logsPath)
{
	. $logsPath
	$logFilePath = Join-Path $PSScriptRoot $config.LogFileName
	Initialize-Logger -Path $logFilePath -Level DEBUG -Append
}
else
{
	Write-Error "WriteLogs_Fun.ps1 not found on script path."
	exit 1
}

# -------------------------------------------------------------------
# Load Alert mail function
# -------------------------------------------------------------------
$sendMailPath = Join-Path $PSScriptRoot "SendAlertMail_Fun.ps1"
if (Test-Path $sendMailPath)
{
	. $sendMailPath
}
else
{
	Write-Log -Message "SendAlertMail_Fun.ps1 not found on script path." -Level WARN
	exit 1
}

# -------------------------------------------------------------------
# Load VMware functions
# -------------------------------------------------------------------
$vmFunctionsPath = Join-Path $PSScriptRoot "vmFunctions.ps1"
if (Test-Path $vmFunctionsPath)
{
	. $vmFunctionsPath
}
else	{
	Write-Log -Message "vmFunctions.ps1 not found on script path." -Level WARN
	exit 1
}

# -------------------------------------------------------------------
# Load Start VM Function
# -------------------------------------------------------------------
$StartVmFunPath = Join-Path $PSScriptRoot "Start_VM_FUN.ps1"
if (Test-Path $StartVmFunPath)
{
	. $StartVmFunPath
}
else	{
	Write-Log -Message "Start_VM_FUN.ps1 not found on script path." -Level WARN
	exit 1
}

# -------------------------------------------------------------------
# Load Shutdown VM Function
# -------------------------------------------------------------------
$ShutdownVmFunPath = Join-Path $PSScriptRoot "Shutdown_VM_FUN.ps1"
if (Test-Path $ShutdownVmFunPath)
{
	. $ShutdownVmFunPath
}
else	{
	Write-Log -Message "Shutdown_VM_FUN.ps1 not found on script path." -Level WARN
	exit 1
}