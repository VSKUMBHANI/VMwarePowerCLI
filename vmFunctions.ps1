# -------------------------------------------------------------------
# Get VMware Credentials from env.json file.
# -------------------------------------------------------------------
Function Get-VMwareCredential
{
	param ()

	return New-Object System.Management.Automation.PSCredential (
		$config.vmUsername,
		(ConvertTo-SecureString $config.vmPassword -AsPlainText -Force)
	)
}

# -------------------------------------------------------------------
# Function to Test PowerCLI Module Availability
# -------------------------------------------------------------------
Function Test-PowerCLI
{
    try
    {
        # Check if module exists
        if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI))
        {
            Write-Log -Message "VMware PowerCLI module is not installed." -Level WARN
            Write-Log "Installing VMware PowerCLI..."

            # Install module
            Install-Module -Name VMware.PowerCLI -Confirm:$false -Force -ErrorAction Stop

            Write-Log -Message "VMware PowerCLI installed successfully." -Level INFO
        }
        else
        {
            Write-Log -Message "VMware PowerCLI is already installed." -Level INFO
        }
    }
    catch
    {
        Write-Log -Message "Failed to install VMware PowerCLI." -Level ERROR
        Write-Log "Error: $($_.Exception.Message)" -Level ERROR

        # Optional: stop script execution
        # throw
    }
}

# -------------------------------------------------------------------
# Connect VMware Server
# -------------------------------------------------------------------
function Connect-VMHostServer
{
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$Server,
		[Parameter(Mandatory = $true)]
		[PSCredential]$Credential
	)
	
	Write-Log -Message "Connecting to VMware server: '$Server'" -Level INFO
	
	$connection = Connect-VIServer -Server $Server -Credential $Credential -ErrorAction Stop
	
	if (-not $connection.IsConnected)
	{
		throw "Failed to connect to VMware server '$Server'."
	}
	
	Write-Log -Message "Connected successfully to: '$Server'" -Level INFO
	
	return $connection
}

# -------------------------------------------------------------------
# Disconnect VMware Server
# -------------------------------------------------------------------
function Disconnect-VMHostServer
{
	param
	(
		[string]$Server
	)

	try
	{
		$viServer = $global:DefaultVIServers |
			Where-Object {
				$_.Name -eq $Server -and $_.IsConnected
			}

		if ($viServer)
		{
			Write-Log -Message "Disconnecting from VMware server '$Server'" -Level INFO

			Disconnect-VIServer -Server $viServer -Confirm:$false -Force | Out-Null
		}
	}
	catch
	{
		Write-Log -Message "Failed to disconnect VMware server '$Server' : $($_.Exception.Message)" -Level WARN
	}
}

# -------------------------------------------------------------------
# Display ESXi Host Information
# -------------------------------------------------------------------
function Show-ESXiHostInformation
{
	$vmHosts = Get-VMHost
	
	foreach ($vmHost in $vmHosts)
	{
		$cpuTotalGHz = [math]::Round($vmHost.CpuTotalMhz / 1000, 2)
		$cpuUsedGHz = [math]::Round($vmHost.CpuUsageMhz / 1000, 2)
		
		$ramTotalGB = [math]::Round($vmHost.MemoryTotalGB, 2)
		$ramUsedGB = [math]::Round($vmHost.MemoryUsageGB, 2)
		
		$uptimeDays = (
			New-TimeSpan `
						 -Start $vmHost.ExtensionData.Summary.Runtime.BootTime `
						 -End (Get-Date)
		).Days
		
		$ipAddress = (
			$vmHost.ExtensionData.Config.Network.Vnic |
			Select-Object -First 1
		).Spec.Ip.IpAddress
		Write-Log -Message "Retrieved information for ESXi host '$($vmHost.Name)'" -Level DEBUG
		Write-Host ""
		Write-Host "==============================================================="
		Write-Host "                    ESXi HOST INFORMATION"
		Write-Host "==============================================================="
		Write-Host ""
		
		[PSCustomObject]@{
			"Hostname"	   = $vmHost.Name
			"IP Address"   = $ipAddress
			"Model"	       = $vmHost.Model
			"ESXi Version" = "$($vmHost.Version) Build $($vmHost.Build)"
			"CPU Total"    = "$cpuTotalGHz GHz"
			"CPU Usage"    = "$cpuUsedGHz GHz"
			"RAM Total"    = "$ramTotalGB GB"
			"RAM Usage"    = "$ramUsedGB GB"
			"UP Time"	   = "$uptimeDays Days"
		} | Format-List
		
		Write-Host ""
	}
}

# -------------------------------------------------------------------
# Display VMware Summary
# -------------------------------------------------------------------
function Show-VMwareSummary
{
	$allVMs = Get-VM
	
	$poweredOnVMs = @(
		$allVMs |
		Where-Object {
			$_.PowerState -eq 'PoweredOn'
		}
	)
	
	$poweredOffVMs = @(
		$allVMs |
		Where-Object {
			$_.PowerState -eq 'PoweredOff'
		}
	)
	
	$datastores = Get-Datastore
	$vmNetworks = Get-VirtualPortGroup
	
	Write-Host ""
	Write-Host "==============================================================="
	Write-Host "                 VMWARE ENVIRONMENT SUMMARY"
	Write-Host "==============================================================="
	Write-Host ""
	
	[PSCustomObject]@{
		"Total VMs"	      = $allVMs.Count
		"Powered ON VMs"  = $poweredOnVMs.Count
		"Powered OFF VMs" = $poweredOffVMs.Count
		"Datastores"	  = $datastores.Count
		"VM Networks"	  = $vmNetworks.Count
	} | Format-Table -AutoSize
	
	Write-Host ""
}

# -------------------------------------------------------------------
# Get Powered-ON VMs
# -------------------------------------------------------------------
function Get-PoweredOnVMs
{
	return @(
		Get-VM |
		Where-Object {
			$_.PowerState -eq 'PoweredOn'
		}
	)
}

# -------------------------------------------------------------------
# Get Powered-ON VMs
# -------------------------------------------------------------------
function Show-PoweredOnVMs
{
	param
	(
		[array]$VMs
	)
	
	Write-Host ""
	Write-Host "==============================================================="
	Write-Host "                    POWERED-ON VM LIST"
	Write-Host "==============================================================="
	Write-Host ""
	
	$VMs |
	Select-Object `
				  @{
		Name   = 'No'; Expression = {
			[array]::IndexOf($VMs, $_) + 1
		}
	},
				  @{
		Name = 'VM Name'; Expression = {
			$_.Name
		}
	},
				  @{
		Name = 'Current State'; Expression = {
			$_.PowerState
		}
	},
				  @{
		Name = 'Guest OS'; Expression = {
			$_.Guest.OSFullName
		}
	},
				  @{
		Name = 'Assigned CPU'; Expression = {
			$_.NumCpu
		}
	},
				  @{
		Name					   = 'Assigned RAM'; Expression = {
			"{0:N0} GB" -f $_.MemoryGB
		}
	} |
	Format-Table -AutoSize
	
	Write-Host ""
}

# -------------------------------------------------------------------
# Get Powered-Off VMs
# -------------------------------------------------------------------
function Get-PoweredOffVMs
{
	return @(
		Get-VM |
		Where-Object {
			$_.PowerState -eq 'PoweredOff'
		}
	)
}

# -------------------------------------------------------------------
# Display Powered-Off VMs
# -------------------------------------------------------------------
function Show-PoweredOffVMs
{
	param
	(
		[array]$VMs
	)
	
	Write-Host ""
	Write-Host "==============================================================="
	Write-Host "                    POWERED-OFF VM LIST"
	Write-Host "==============================================================="
	Write-Host ""
	
	$VMs |
	Select-Object `
				  @{
		Name   = 'No'; Expression = {
			[array]::IndexOf($VMs, $_) + 1
		}
	},
				  @{
		Name = 'VM Name'; Expression = {
			$_.Name
		}
	},
				  @{
		Name = 'Current State'; Expression = {
			$_.PowerState
		}
	},
				  @{
		Name = 'Guest OS'; Expression = {
			$_.Guest.OSFullName
		}
	},
				  @{
		Name = 'Assigned CPU'; Expression = {
			$_.NumCpu
		}
	},
				  @{
		Name					   = 'Assigned RAM'; Expression = {
			"{0:N0} GB" -f $_.MemoryGB
		}
	} |
	Format-Table -AutoSize
	
	Write-Host ""
}

# -------------------------------------------------------------------
# Get Datastore Details From VM
# -------------------------------------------------------------------
function Get-VMDataStoreDetails
{
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$VMName
	)

	try
	{
		$vm = Get-VM -Name $VMName -ErrorAction Stop

		$datastores = Get-Datastore -VM $vm -ErrorAction Stop

		if (-not $datastores)
		{
			Write-Log -Message "No datastore found for VM '$VMName'" -Level WARN

			return
		}

		Write-Host ""
		Write-Host "==============================================================="
		Write-Host "                 DATASTORE DETAILS FOR VM"
		Write-Host "==============================================================="
		Write-Host ""

		$datastores |
			Select-Object `
				@{
					Name = 'VM Name'
					Expression = {
						$vm.Name
					}
				},
				@{
					Name = 'Datastore Name'
					Expression = {
						$_.Name
					}
				},
				@{
					Name = 'Type'
					Expression = {
						$_.Type
					}
				},
				@{
					Name = 'Capacity (GB)'
					Expression = {
						"{0:N2}" -f $_.CapacityGB
					}
				},
				@{
					Name = 'Free Space (GB)'
					Expression = {
						"{0:N2}" -f $_.FreeSpaceGB
					}
				},
				@{
					Name = 'State'
					Expression = {
						$_.State
					}
				} |
			Format-Table -AutoSize
	}
	catch
	{
		Write-Log -Message "Failed to get datastore details for VM '$VMName' : $($_.Exception.Message)" -Level ERROR
	}
}

# -------------------------------------------------------------------
# Display ESXi Datastore Details
# -------------------------------------------------------------------
function Show-ESXiDatastores
{
	try
	{
		$datastores = Get-Datastore -ErrorAction Stop

		if (-not $datastores)
		{
			Write-Log -Message "No datastores found." -Level WARN

			return
		}

		Write-Host ""
		Write-Host "==============================================================="
		Write-Host "                    ESXi DATASTORE DETAILS"
		Write-Host "==============================================================="
		Write-Host ""

		$datastores |
			Select-Object `
				@{
					Name = 'Datastore Name'
					Expression = {
						$_.Name
					}
				},
				@{
					Name = 'Type'
					Expression = {
						$_.Type
					}
				},
				@{
					Name = 'Capacity (GB)'
					Expression = {
						"{0:N2}" -f $_.CapacityGB
					}
				},
				@{
					Name = 'Used Space (GB)'
					Expression = {
						"{0:N2}" -f ($_.CapacityGB - $_.FreeSpaceGB)
					}
				},
				@{
					Name = 'Free Space (GB)'
					Expression = {
						"{0:N2}" -f $_.FreeSpaceGB
					}
				},
				@{
					Name = 'Accessible'
					Expression = {
						$_.ExtensionData.Summary.Accessible
					}
				},
				@{
					Name = 'State'
					Expression = {
						$_.State
					}
				} |
			Format-Table -AutoSize

		Write-Host ""
	}
	catch
	{
		Write-Log -Message "Failed to retrieve datastore details : $($_.Exception.Message)" -Level ERROR
	}
}

# -------------------------------------------------------------------
# Display Full VMware VM Details
# -------------------------------------------------------------------
function Show-VMFullDetails
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$VMName
	)

	try
	{
		Write-Log -Message "Retrieving details for VM '$VMName'" -Level INFO

		# ---------------------------------------------------------------
		# Get VM
		# ---------------------------------------------------------------
		$vm = Get-VM -Name $VMName -ErrorAction Stop

		if (-not $vm)
		{
			throw "VM '$VMName' not found."
		}

		# ---------------------------------------------------------------
		# Get IP Addresses
		# ---------------------------------------------------------------
		$ipAddresses = @(
			$vm.Guest.IPAddress |
			Where-Object {
				$_ -match '\d+\.\d+\.\d+\.\d+'
			}
		) -join ', '

		# ---------------------------------------------------------------
		# Get Datastores
		# ---------------------------------------------------------------
		$datastores = @(
			$vm |
			Get-Datastore |
			Select-Object -ExpandProperty Name
		) -join ', '

		# ---------------------------------------------------------------
		# Get Network Adapters
		# ---------------------------------------------------------------
		$networks = @(
			Get-NetworkAdapter -VM $vm |
			Select-Object -ExpandProperty NetworkName
		) -join ', '

		# ---------------------------------------------------------------
		# Get Snapshot Details
		# ---------------------------------------------------------------
		$snapshots = Get-Snapshot -VM $vm -ErrorAction SilentlyContinue

		$snapshotCount = if ($snapshots)
		{
			$snapshots.Count
		}
		else
		{
			0
		}

		# ---------------------------------------------------------------
		# Build Report
		# ---------------------------------------------------------------
		$report = [PSCustomObject]@{
			"VM Name"              = $vm.Name
			"Power State"          = $vm.PowerState
			"Guest OS"             = $vm.Guest.OSFullName
			"VM Version"           = $vm.Version
			"ESXi Host"            = $vm.VMHost
			"CPU Count"            = $vm.NumCpu
			"RAM (GB)"             = $vm.MemoryGB
			"Provisioned Space"    = "{0:N2} GB" -f $vm.ProvisionedSpaceGB
			"Used Space"           = "{0:N2} GB" -f $vm.UsedSpaceGB
			"Datastore"            = $datastores
			"Network"              = $networks
			"IP Address"           = $ipAddresses
			"VMware Tools Status"  = $vm.ExtensionData.Guest.ToolsRunningStatus
			"VMware Tools Version" = $vm.ExtensionData.Guest.ToolsVersionStatus2
			"Snapshots"            = $snapshotCount
			"Boot Time"            = $vm.ExtensionData.Runtime.BootTime
			"Created Time"         = $vm.ExtensionData.Config.CreateDate
			"Folder"               = $vm.Folder
			"Resource Pool"        = $vm.ResourcePool
			"Notes"                = $vm.Notes
		}

		Write-Host ""
		Write-Host "==============================================================="
		Write-Host "                     VM FULL DETAILS"
		Write-Host "==============================================================="
		Write-Host ""

		$report | Format-List | Out-Host

		Write-Host ""

		# ---------------------------------------------------------------
		# Show Virtual Disks
		# ---------------------------------------------------------------
		Write-Host "-------------------- Virtual Disks --------------------"
		Write-Host ""

		Get-HardDisk -VM $vm |
			Select-Object `
				Name,
				CapacityGB,
				Filename,
				StorageFormat |
			Format-Table -AutoSize |
			Out-Host

		Write-Host ""

		# ---------------------------------------------------------------
		# Show Network Adapters
		# ---------------------------------------------------------------
		Write-Host "-------------------- Network Adapters --------------------"
		Write-Host ""

		Get-NetworkAdapter -VM $vm |
			Select-Object `
				Name,
				Type,
				MacAddress,
				NetworkName,
				Connected |
			Format-Table -AutoSize |
			Out-Host

		Write-Host ""

		# ---------------------------------------------------------------
		# Show Snapshots
		# ---------------------------------------------------------------
		if ($snapshots)
		{
			Write-Host "-------------------- Snapshots --------------------"
			Write-Host ""

			$snapshots |
				Select-Object `
					Name,
					Description,
					Created,
					SizeGB |
				Format-Table -AutoSize |
				Out-Host

			Write-Host ""
		}
	}
	catch
	{
		Write-Log -Message "Failed to retrieve VM details for '$VMName' : $($_.Exception.Message)" -Level ERROR

		throw
	}
}

# -------------------------------------------------------------------
# Display selected Full VM details 
# -------------------------------------------------------------------
function Show-SelectedVMFullDetails
{
	try
	{
		$vms = Get-VM | Sort-Object Name

		if (-not $vms)
		{
			Write-Log -Message "No VMs found in inventory." -Level WARN
			return
		}

		# ---------------------------------------------------------------
		# Display VM List
		# ---------------------------------------------------------------
		Write-Host ""
		Write-Host "==================== AVAILABLE VMs ===================="
		Write-Host ""

		$index = 0

		$vms | ForEach-Object {
			$index++
			Write-Host "[$index] $($_.Name) - $($_.PowerState)"
		}

		Write-Host ""
		$selection = Read-Host "Enter VM numbers or names (comma-separated)"

		if ([string]::IsNullOrWhiteSpace($selection))
		{
			Write-Host "No selection made."
			return
		}

		# ---------------------------------------------------------------
		# Parse Selection
		# ---------------------------------------------------------------
		$selectedVMs = @()

		$tokens = $selection -split '[,\s]+' | Where-Object { $_ }

		foreach ($token in $tokens)
		{
			if ($token -match '^\d+$')
			{
				$index = [int]$token

				if ($index -ge 1 -and $index -le $vms.Count)
				{
					$selectedVMs += $vms[$index - 1]
				}
			}
			else
			{
				$selectedVMs += $vms | Where-Object { $_.Name -ieq $token }
			}
		}

		$selectedVMs = $selectedVMs | Sort-Object Name -Unique

		if (-not $selectedVMs)
		{
			Write-Log -Message "No matching VMs found for selection." -Level WARN
			return
		}

		# ---------------------------------------------------------------
		# Show Full Details
		# ---------------------------------------------------------------
		foreach ($vm in $selectedVMs)
		{
			Write-Host ""
			Write-Host "==============================================================="
			Write-Host " VM DETAILS: $($vm.Name)"
			Write-Host "==============================================================="
			Write-Host ""

			$report = [PSCustomObject]@{
				"VM Name"             = $vm.Name
				"Power State"         = $vm.PowerState
				"Guest OS"            = $vm.Guest.OSFullName
				"VM Version"          = $vm.Version
				"ESXi Host"           = $vm.VMHost
				"CPU"                 = $vm.NumCpu
				"RAM (GB)"            = $vm.MemoryGB
				"Provisioned (GB)"    = "{0:N2}" -f $vm.ProvisionedSpaceGB
				"Used (GB)"           = "{0:N2}" -f $vm.UsedSpaceGB
				"Tools Status"        = $vm.ExtensionData.Guest.ToolsRunningStatus
				"Boot Time"           = $vm.ExtensionData.Runtime.BootTime
			}

			$report | Format-List | Out-Host

			# -----------------------------------------------------------
			# Disks
			# -----------------------------------------------------------
			Write-Host "-------------------- DISKS --------------------"
			Get-HardDisk -VM $vm |
				Select-Object Name, CapacityGB, StorageFormat |
				Format-Table -AutoSize |
				Out-Host

			# -----------------------------------------------------------
			# Network
			# -----------------------------------------------------------
			Write-Host "-------------------- NETWORK --------------------"
			Get-NetworkAdapter -VM $vm |
				Select-Object Name, NetworkName, MacAddress, Connected |
				Format-Table -AutoSize |
				Out-Host

			# -----------------------------------------------------------
			# Datastores
			# -----------------------------------------------------------
			Write-Host "-------------------- DATASTORE --------------------"
			$vm | Get-Datastore |
				Select-Object Name, Type, CapacityGB, FreeSpaceGB |
				Format-Table -AutoSize |
				Out-Host
		}
	}
	catch
	{
		Write-Log -Message "Error in VM selection/details: $($_.Exception.Message)" -Level ERROR
		throw
	}
}