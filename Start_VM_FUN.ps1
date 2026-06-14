Set-StrictMode -Version Latest
# -------------------------------------------------------------------
# Select VMs to Start
# -------------------------------------------------------------------
function Select-VMsToStart
{
	param
	(
		[Parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[array]$VMsAvailable
	)

	try
	{
		if (-not $VMsAvailable -or $VMsAvailable.Count -eq 0)
		{
			throw "No available VMs provided to select from."
		}

		$selection = Read-Host "Enter VM names or numbers to start (comma-separated), or press Enter for ALL"

		if ([string]::IsNullOrWhiteSpace($selection))
		{
			return @($VMsAvailable)
		}

		$selected = @()

		$tokens = $selection -split '[,\s]+' | Where-Object { $_ }

		foreach ($token in $tokens)
		{
			if ($token -match '^[0-9]+$')
			{
				$index = [int]$token

				if ($index -ge 1 -and $index -le $VMsAvailable.Count)
				{
					$selected += $VMsAvailable[$index - 1]
				}
				else
				{
					if (Get-Command Write-Log -ErrorAction SilentlyContinue)
					{
						Write-Log -Message "Selection index $index is out of range." -Level WARN
					}
					else
					{
						Write-Host "Selection index $index is out of range."
					}
				}
			}
			else
			{
				$vmmatches = $VMsAvailable | Where-Object { $_.Name -ieq $token }
				if ($vmmatches)
				{
					$selected += $vmmatches
				}
				else
				{
					if (Get-Command Write-Log -ErrorAction SilentlyContinue)
					{
						Write-Log -Message "No VM found matching name '$token'." -Level WARN
					}
					else
					{
						Write-Host "No VM found matching name '$token'."
					}
				}
			}
		}

		$final = @(
			$selected | Sort-Object Name -Unique
		)

		if (-not $final)
		{
			if (Get-Command Write-Log -ErrorAction SilentlyContinue)
			{
				Write-Log -Message "No valid VMs selected." -Level WARN
			}
			else
			{
				Write-Host "No valid VMs selected."
			}
		}

		return $final
	}
	catch
	{
		$err = $_.Exception.Message
		if (Get-Command Write-Log -ErrorAction SilentlyContinue)
		{
			Write-Log -Message "Error in Select-VMsToStart: $err" -Level ERROR
		}
		else
		{
			Write-Host "Error in Select-VMsToStart: $err"
		}

		return @()
	}
}

# -------------------------------------------------------------------
# Start VM With Retry
# -------------------------------------------------------------------
function Start-VMWithRetry
{
	param
	(
		[Parameter(Mandatory = $true)]
		$VM,
		[int]$RetryCount = 3,
		[int]$StartupTimeoutSeconds = 300
	)
	
	$attempt = 0
	$success = $false
	
	do
	{
		try
		{
			$attempt++
			
			Write-Log -Message "Attempt $attempt to start VM '$($VM.Name)'" -Level INFO
			Start-VM -VM $VM -Confirm:$false -ErrorAction Stop | Out-Null
			
			$elapsed = 0
			
			do
			{
				Start-Sleep -Seconds 5
				
				$currentState = (
					Get-VM -Name $VM.Name
				).PowerState
				
				$elapsed += 5
				
			}
			until (
				$currentState -eq 'PoweredOn' -or
				$elapsed -ge $StartupTimeoutSeconds
			)
			
			if ($currentState -eq 'PoweredOn')
			{
				Write-Log -Message `
						  "VM '$($VM.Name)' started successfully." `
						  -Level INFO
				
				$success = $true
			}
			else
			{
				throw "VM startup verification timed out."
			}
		}
		catch
		{
			Write-Log -Message "Failed to start VM '$($VM.Name)' on attempt $attempt : $($_.Exception.Message)" -Level ERROR
			
			if ($attempt -lt $RetryCount)
			{
				Write-Log -Message "Retrying startup for '$($VM.Name)' in 10 seconds..." -Level WARN
				
				Start-Sleep -Seconds 10
			}
		}
		
	}
	until ($success -or $attempt -ge $RetryCount)
	
	if (-not $success)
	{
		$finalError = `
		"VM '$($VM.Name)' failed to start after $RetryCount attempts."
		
		Write-Log -Message $finalError -Level ERROR
		
		if (Get-Command Send-AlertMail -ErrorAction SilentlyContinue)
		{
            #Send-AlertMail -Subject "VM Start Failure: $($VM.Name)" -Body $finalError
		}
	}
}

# -------------------------------------------------------------------
# Main Automation Function
# -------------------------------------------------------------------
function Start-VMAutomation
{
	[CmdletBinding(SupportsShouldProcess = $true)]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$Server,
		[Parameter(Mandatory = $true)]
		[PSCredential]$Credential
	)
	
	try
	{
		# Connect-VMHostServer -Server $Server -Credential $Credential
		# ---------------------------------------------------------------
		# Get Powered-Off VMs
		# ---------------------------------------------------------------
		$poweredOffVMs = Get-PoweredOffVMs
		
		if (-not $poweredOffVMs)
		{
			Write-Log -Message "No powered-off VMs found." -Level INFO
			return
		}
		
		# ---------------------------------------------------------------
		# Display VM Table
		# ---------------------------------------------------------------
		Show-PoweredOffVMs -VMs $poweredOffVMs
		
		# ---------------------------------------------------------------
		# Select VMs
		# ---------------------------------------------------------------
		$vmsToStart = Select-VMsToStart -VMsAvailable $poweredOffVMs
		
		if (-not $vmsToStart)
		{
			Write-Log -Message "No VMs selected." -Level WARN
			return
		}
		
		# ---------------------------------------------------------------
		# Start Selected VMs
		# ---------------------------------------------------------------
		foreach ($vm in $vmsToStart)
		{
			if ($PSCmdlet.ShouldProcess($vm.Name, "Start VM"))
			{
				Start-VMWithRetry -VM $vm
			}
		}
		
		Write-Log -Message "VM startup process completed successfully." -Level INFO
	}
	catch
	{
		$errorMessage = "Start-VMAutomation failed: $($_.Exception.Message)"
		
		Write-Log -Message $errorMessage -Level ERROR
		
		if (Get-Command Send-AlertMail -ErrorAction SilentlyContinue)
		{
            #Send-AlertMail -Subject "VMware Automation Failure" -Body $errorMessage
		}
		
		throw
	}
	finally
	{
		Disconnect-VMHostServer -Server $Server
	}
}