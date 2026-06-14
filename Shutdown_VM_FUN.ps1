Set-StrictMode -Version Latest
# -------------------------------------------------------------------
# Select VMs To Shutdown
# -------------------------------------------------------------------
function Select-VMsToShutdown
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [array]$VMsAvailable
    )

    try
    {
        $selection = Read-Host `
            "Enter VM names or numbers to shutdown (comma-separated), or press Enter for ALL"

        if ([string]::IsNullOrWhiteSpace($selection))
        {
            return @($VMsAvailable)
        }

        $selected = @()

        $tokens = $selection -split '[,\s]+' |
            Where-Object { $_ }

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
                    Write-Log -Message "Selection index $index is out of range." -Level WARN
                }
            }
            else
            {
                $vmmatchs = $VMsAvailable |
                    Where-Object {
                        $_.Name -ieq $token
                    }

                if ($vmmatchs)
                {
                    $selected += $vmmatchs
                }
                else
                {
                    Write-Log -Message "No VM found matching name '$token'." -Level WARN
                }
            }
        }

        return @(
            $selected |
            Sort-Object Name -Unique
        )
    }
    catch
    {
        Write-Log -Message "Error in Select-VMsToShutdown: $($_.Exception.Message)" -Level ERROR

        return @()
    }
}

# -------------------------------------------------------------------
# Shutdown VM With Retry
# -------------------------------------------------------------------
function Stop-VMWithRetry
{
    param
    (
        [Parameter(Mandatory = $true)]
        $VM,

        [switch]$Force,

        [int]$RetryCount = 3,

        [int]$ShutdownTimeoutSeconds = 300
    )

    $attempt = 0
    $success = $false

    do
    {
        try
        {
            $attempt++

            Write-Log -Message "Attempt $attempt to shutdown VM '$($VM.Name)'" -Level INFO

            $toolsRunning = $VM.ExtensionData.Guest.ToolsRunningStatus

            if (
                $toolsRunning -eq "guestToolsRunning" -and
                -not $Force
            )
            {
                Shutdown-VMGuest `
                    -VM $VM `
                    -Confirm:$false `
                    -ErrorAction Stop
            }
            else
            {
                Stop-VM `
                    -VM $VM `
                    -Kill `
                    -Confirm:$false `
                    -ErrorAction Stop
            }

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
                $currentState -eq 'PoweredOff' -or
                $elapsed -ge $ShutdownTimeoutSeconds
            )

            if ($currentState -eq 'PoweredOff')
            {
                Write-Log -Message "VM '$($VM.Name)' shutdown successfully." -Level INFO

                $success = $true
            }
            else
            {
                throw "VM shutdown verification timed out."
            }
        }
        catch
        {
            Write-Log -Message "Failed to shutdown VM '$($VM.Name)' on attempt $attempt : $($_.Exception.Message)" -Level ERROR

            if ($attempt -lt $RetryCount)
            {
                Write-Log -Message "Retrying shutdown for '$($VM.Name)' in 10 seconds..." -Level WARN

                Start-Sleep -Seconds 10
            }
        }

    }
    until ($success -or $attempt -ge $RetryCount)

    if (-not $success)
    {
        $finalError = `
            "VM '$($VM.Name)' failed to shutdown after $RetryCount attempts."

        Write-Log -Message `
            $finalError `
            -Level ERROR

        if (Get-Command Send-AlertMail -ErrorAction SilentlyContinue)
        {
            #Send-AlertMail `
            #    -Subject "VM Shutdown Failure: $($VM.Name)" `
            #    -Body $finalError
        }
    }
}

# -------------------------------------------------------------------
# Main Automation Function
# -------------------------------------------------------------------
function Stop-VMAutomation
{
    [CmdletBinding(SupportsShouldProcess = $true)]

    param
    (
        [Parameter(Mandatory = $true)]
        [string]$Server,

        [Parameter(Mandatory = $true)]
        [PSCredential]$Credential,

        [switch]$Force
    )

    try
    {
        # Connect-VMHostServer -Server $Server -Credential $Credential
        # ---------------------------------------------------------------
        # Get Powered-ON VMs
        # ---------------------------------------------------------------
        $poweredOnVMs = Get-PoweredOnVMs

        if (-not $poweredOnVMs)
        {
            Write-Log -Message "No powered-on VMs found." -Level INFO

            return
        }

        # ---------------------------------------------------------------
        # Display VM Table
        # ---------------------------------------------------------------
        Show-PoweredOnVMs `
            -VMs $poweredOnVMs

        # ---------------------------------------------------------------
        # Select VMs
        # ---------------------------------------------------------------
        $vmsToShutdown = Select-VMsToShutdown `
            -VMsAvailable $poweredOnVMs

        if (-not $vmsToShutdown)
        {
            Write-Log -Message "No VMs selected." -Level WARN

            return
        }

        # ---------------------------------------------------------------
        # Shutdown Selected VMs
        # ---------------------------------------------------------------
        foreach ($vm in $vmsToShutdown)
        {
            if ($PSCmdlet.ShouldProcess($vm.Name, "Shutdown VM"))
            {
                Stop-VMWithRetry `
                    -VM $vm `
                    -Force:$Force
            }
        }

        Write-Log -Message "VM shutdown process completed successfully." -Level INFO
    }
    catch
    {
        $errorMessage = `
            "Stop-VMAutomation failed: $($_.Exception.Message)"

        Write-Log -Message $errorMessage -Level ERROR

        throw
    }
    finally
    {
        Disconnect-VMHostServer -Server $Server
    }
}