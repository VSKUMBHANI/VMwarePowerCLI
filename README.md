# VMwarePowerCLI

PowerShell automation scripts using VMware PowerCLI to start and shutdown virtual machines, display summaries, and send alert emails.

**Prerequisites**
- PowerShell 7 or later (scripts enforce this at startup)
- VMware PowerCLI module (the scripts will try to install it if missing)

Quick setup:

1. Edit `env.json` with your VMware and SMTP settings.
2. Run PowerShell 7 as Administrator.
3. Start the interactive menu with:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\Main.ps1
```

# Knowledge Base — VMwarePowerCLI scripts

This document describes the scripts included in this repository, their purpose, required inputs, and example usage.

## Overview
- Purpose: Simple PowerCLI automation to start/shutdown VMs, show summaries, and send alerts.
- Prerequisites: PowerShell 7+, VMware PowerCLI module (the scripts will attempt to install it if missing).

## Files

- `Config.ps1`: Loads `env.json` and imports helper modules. Ensures logging and alert functions are available.

- `env.json`: JSON configuration storing runtime values:
  - `LogFileName`: log filename (e.g. `VMware.log`)
  - `SmtpServer`, `SmtpUsername`, `SmtpPassword`, `From`, `To`, `Port`, `UseSsl`: SMTP settings for alert emails
  - `vmServerIP`, `vmUsername`, `vmPassword`: VMware server address and credentials

- `WriteLogs_Fun.ps1`: Lightweight logging module. Exposes:
  - `Initialize-Logger -Path <path> -Level <DEBUG|INFO|WARN|ERROR> -Append`
  - `Write-Log -Message <string> -Level <level>`

- `SendAlertMail_Fun.ps1`: Sends email alerts using SMTP configuration from `env.json`. Use `Send-AlertMail -Subject <s> -Body <b>`.

- `vmFunctions.ps1`: Core VMware helper functions:
  - `Get-VMwareCredential()` — builds PSCredential from `env.json` values
  - `Test-PowerCLI()` — verifies/installs VMware.PowerCLI module
  - `Connect-VMHostServer -Server <ip> -Credential <pscred>` — connects to vCenter/ESXi
  - `Disconnect-VMHostServer -Server <ip>` — disconnects cleanly
  - Several display helpers: `Show-VMwareSummary`, `Show-ESXiHostInformation`, `Get-VMDataStoreDetails`, etc.

- `Start_VM_FUN.ps1`:
  - Interactive selection to start VMs (`Select-VMsToStart`)
  - `Start-VMWithRetry` with configurable retries and timeout
  - `Start-VMAutomation -Server <ip> -Credential <pscred>` — main entry to start VMs

- `Shutdown_VM_FUN.ps1`:
  - Interactive selection to shutdown VMs (`Select-VMsToShutdown`)
  - `Stop-VMWithRetry` supports graceful guest shutdown or forced stop
  - `Stop-VMAutomation -Server <ip> -Credential <pscred> [-Force]` — main entry to shutdown VMs

- `Main.ps1`: CLI/menu wrapper that:
  - Elevates to administrator if needed
  - Loads `Config.ps1` and dependencies
  - Connects to VMware server using `Get-VMwareCredential`
  - Presents a menu for Start, Shutdown, Summary, Host Info, Datastores, VM Details


## env.json example

{
  "LogFileName": "VMware.log",
  "SmtpServer": "smtp.server.com",
  "SmtpUsername": "user@domain.com",
  "SmtpPassword": "smtpuserpassword",
  "From": "VMware <from@domain.com>",
  "To": "to@domain.com",
  "Port": 587,
  "UseSsl": true,
  "vmServerIP": "192.168.1.28",
  "vmUsername": "root",
  "vmPassword": "vmware_user_password"
}

Notes: keep this file next to the scripts and protect secrets (consider using a credential store in production).


## How to run

1. Open PowerShell 7 (pwsh) as Administrator.
2. Change directory to repository folder.
3. Edit `env.json` with your environment values.
4. Run `.\Main.ps1` to start the interactive menu.

Example (PowerShell):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\Main.ps1
```


## Troubleshooting
- If PowerCLI installation fails, install manually: `Install-Module VMware.PowerCLI -Scope CurrentUser`.
- Check `LogFileName` contents for details (path set by `Config.ps1`).
- Email send failures will be logged; verify SMTP settings in `env.json`.

## Next steps and suggestions
- Replace plaintext passwords with secure credential stores or Windows Credential Manager.
- Add unit/integration tests for critical helper functions.

