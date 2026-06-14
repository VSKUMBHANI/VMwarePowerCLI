# Email notification function.
# alerts.json file contain the details of SMTP server and credenatial.
<# Example: Define Suject and Body variable or pass the direct value
$Subject = "Test"
$Body = "Test Body"
Send-AlertMail -Subject $Subject -Body $Body

Or
Send-AlertMail -Subject "Test" -Body "Test Body"
#>

<# Use this function on other script then simple import it using below:

# Load Alert mail function
$sendMailPath = Join-Path $PSScriptRoot "SendAlertMail_Fun.ps1"

if (Test-Path $sendMailPath) {
    . $sendMailPath
}
else {
    Write-Error "SendAlertMail_Fun.ps1 not found on script path."
    exit 1
}

#>

<# Load logging module (Require if run individual)
$logsPath = Join-Path $PSScriptRoot "WriteLogs_Fun.ps1"
if (Test-Path $logsPath) {
    . $logsPath
    $logFilePath = Join-Path $PSScriptRoot "Master.log"
    Initialize-Logger -Path $logFilePath -Level DEBUG -Append
}#>

# -------------------------------------------------------------------
# Function: Send-AlertMail
# -------------------------------------------------------------------

function Send-AlertMail {
    param (
        [string]$Subject,
        [string]$Body
    )

    try {
        <# (Require if run individual)
        $configPath = Join-Path $PSScriptRoot "alerts.json"

        if (-not (Test-Path $configPath)) {
            throw "Configuration file not found: $configPath"
        }

        $config = Get-Content $configPath -ErrorAction Stop |
                  ConvertFrom-Json -ErrorAction Stop #>

        $requiredProperties = @(
            'SmtpServer',
            'From',
            'To',
            'SmtpUsername',
            'SmtpPassword'
        )

        foreach ($property in $requiredProperties) {
            if (-not $config.PSObject.Properties.Name -contains $property `
                -or [string]::IsNullOrWhiteSpace($config.$property)) {

                throw "Missing required configuration property: $property"
            }
        }

        $smtpServer = $config.SmtpServer
        $smtpPort   = if ($config.Port) { [int]$config.Port } else { 587 }
        $from       = $config.From
        $to         = $config.To
        $useSsl     = if ($null -ne $config.UseSsl) { [bool]$config.UseSsl } else { $true }

        $securePassword = ConvertTo-SecureString `
            $config.SmtpPassword `
            -AsPlainText `
            -Force

        $smtpCredential = New-Object `
            System.Management.Automation.PSCredential (
                $config.SmtpUsername,
                $securePassword
            )

        $mailMessage = New-Object System.Net.Mail.MailMessage
        $mailMessage.From = $from
        $mailMessage.To.Add($to)
        $mailMessage.Subject = $Subject
        $mailMessage.Body = $Body
        $mailMessage.IsBodyHtml = $true

        $smtpClient = New-Object System.Net.Mail.SmtpClient($smtpServer, $smtpPort)
        $smtpClient.EnableSsl = $useSsl
        $smtpClient.Credentials = New-Object System.Net.NetworkCredential(
            $smtpCredential.UserName,
            $smtpCredential.GetNetworkCredential().Password
        )
        $smtpClient.DeliveryMethod = [System.Net.Mail.SmtpDeliveryMethod]::Network

        Write-Log -Message "Sending alert email to: $to" -Level DEBUG

        $smtpClient.Send($mailMessage)

        Write-Log -Message "Alert email sent successfully" -Level INFO
    }
    catch {
        Write-Log -Message "Send-AlertMail failed: $($_.Exception.Message)" -Level ERROR
        throw
    }
}