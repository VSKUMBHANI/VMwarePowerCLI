Set-StrictMode -Version Latest

# -------------------------------------------------------------------
# Self-elevate the script if required
# -------------------------------------------------------------------
If (-Not ([Security.Principal.WindowsPrincipal] `
		[Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
		[Security.Principal.WindowsBuiltInRole] 'Administrator'))
{
	If ([int](Get-CimInstance -Class Win32_OperatingSystem |
			Select-Object -ExpandProperty BuildNumber) -ge 6000)
	{
		$CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
		
		Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
	
		Exit
	}
}

# -------------------------------------------------------------------
# Enforce PowerShell Version Requirement
# -------------------------------------------------------------------
$psVersion = $PSVersionTable.PSVersion

if ($psVersion.Major -lt 7)
{
	Write-Log "ERROR: Unsupported PowerShell Version Detected" -Level ERROR
	Write-Log "This script requires PowerShell 7 or later."
	Write-Log "Detected version: $psVersion"
	Write-Log "Please install PowerShell 7:"
	Write-Log "https://aka.ms/powershell"
	exit 1
}

# -------------------------------------------------------------------
# Import Config
# -------------------------------------------------------------------
$configFilePath = Join-Path $PSScriptRoot "Config.ps1"

if (Test-Path $configFilePath)
{
	. $configFilePath
}
else
{
	Write-Host "Config.ps1 not found on script path."
	exit 1
}

# Get script file name.
$scriptFile = Split-Path -Path $PSCommandPath -Leaf

try
{
	Write-Log -Message "--> Script started: [$scriptFile] <--"
	Test-PowerCLI
	
	Write-Log -Message "Retrieving VMware credentials" -Level INFO
	
	$VmCredential = Get-VMwareCredential
	Connect-VMHostServer -Server $config.vmServerIP -Credential $VmCredential
}
catch
{
	Write-Log -Message "Script execution failed: $($_.Exception.Message)" -Level ERROR
	throw
}

# -------------------------------------------------------------------
# Menu Functions Map
# -------------------------------------------------------------------
$menu = @(
	@{ Id = 1; Name = "Start VMs";        Command = "Start-VMAutomation" }
	@{ Id = 2; Name = "Shutdown VMs";     Command = "Stop-VMAutomation" }
	@{ Id = 3; Name = "VM Summary";       Command = "Show-VMwareSummary" }
	@{ Id = 4; Name = "ESXi Hosts Info";  Command = "Show-ESXiHostInformation" }
	@{ Id = 5; Name = "Datastores";       Command = "Show-ESXiDatastores" }
	@{ Id = 6; Name = "VM Full Details";   Command = "Show-SelectedVMFullDetails" }
	@{ Id = 7; Name = "Exit";             Command = "Exit" }
)

# -------------------------------------------------------------------
# Show Menu
# -------------------------------------------------------------------
function Show-Menu
{
	Write-Host ""
	Write-Host "====================================================="
	Write-Host "            VMware Automation Control Menu"
	Write-Host "====================================================="
	Write-Host ""

	foreach ($item in $menu)
	{
		Write-Host "[$($item.Id)] $($item.Name)"
	}

	Write-Host ""
}

# -------------------------------------------------------------------
# Execute Selection
# -------------------------------------------------------------------
function Select-Selection
{
	param
	(
		[int]$Choice
	)

	$selected = $menu | Where-Object { $_.Id -eq $Choice }

	if (-not $selected)
	{
		Write-Host "Invalid selection"
		return
	}

	if ($selected.Command -eq "Exit")
	{
		Write-Host "Exiting..."
        Write-Log -Message "--> Script finished: [$scriptFile] <--" -Level INFO
		exit
	}

	# ----------------------------------------------------------------
	# Execute function dynamically
	# ----------------------------------------------------------------
	try
	{
		switch ($selected.Command)
		{
			"Start-VMAutomation"
			{
				Start-VMAutomation -Server $config.vmServerIP -Credential $VmCredential
			}

			"Stop-VMAutomation"
			{
				Stop-VMAutomation -Server $config.vmServerIP -Credential $VmCredential
			}

			"Show-VMwareSummary"
			{
				Show-VMwareSummary
			}

			"Show-ESXiHostInformation"
			{
				Show-ESXiHostInformation
			}

			"Show-ESXiDatastores"
			{
				Show-ESXiDatastores
			}

			"Show-SelectedVMFullDetails"
			{
				Show-SelectedVMFullDetails
			}
		}
	}
	catch
	{
		Write-Host "Error executing function: $($_.Exception.Message)"
	}
}

# -------------------------------------------------------------------
# MAIN LOOP
# -------------------------------------------------------------------

while ($true)
{
	Show-Menu

	$choice = Read-Host "Enter your choice"

	if ($choice -match '^\d+$')
	{
		Select-Selection -Choice $choice
	}
	else
	{
		Write-Host "Please enter a valid number"
	}

	Write-Host ""
	Read-Host "Press Enter to continue"
}