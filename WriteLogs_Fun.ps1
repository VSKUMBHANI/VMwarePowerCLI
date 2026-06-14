<#
.SYNOPSIS
Logging module for PowerShell scripts.

.DESCRIPTION
Provides configurable logging functionality with multiple severity levels.
Supports file and console output with automatic log file initialization.

.CONFIGURATION
$script:LogFilePath - Path to the log file (auto-initialized if not set)
$script:LogLevel    - Minimum level to log (DEBUG, INFO, WARN, or ERROR)

.FUNCTIONS
- Initialize-Logger    : Configure the logger with path and level
- Write-Log           : Write a log message
- Get-LogLevelValue   : Get numeric value for a log level
- Test-LogLevel       : Check if a level should be logged
- Get-DefaultLogFilePath : Get default log file location

.EXAMPLE
Initialize-Logger -Path "C:\Scripts\log.log" -Level DEBUG -Append
Write-Log -Message "Debug information" -Level DEBUG
Write-Log -Message "Application started"
Write-Log -Message "Something might be wrong" -Level WARN
Write-Log -Message "Something failed" -Level ERROR
#>

# Default settings (can be overridden by user)
$script:LogFilePath = $null
$script:LogLevel    = 'INFO'   # DEBUG < INFO < WARN < ERROR
$script:LogLevels   = @{
    'DEBUG' = 0
    'INFO'  = 1
    'WARN'  = 2
    'ERROR' = 3
}

# -------------------------------------------------------------------
# Function: Get-LogLevelValue
# -------------------------------------------------------------------
function Get-LogLevelValue {
    <#
    .SYNOPSIS
    Returns the numeric value for a log level.

    .DESCRIPTION
    Maps log level names to numeric values for comparison.
    DEBUG=0, INFO=1, WARN=2, ERROR=3

    .PARAMETER Level
    The log level name (DEBUG, INFO, WARN, or ERROR).

    .OUTPUTS
    System.Int32 - Numeric value of the log level
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [string]$Level
    )

    return $script:LogLevels[$Level]
}

# -------------------------------------------------------------------
# Function: Test-LogLevel
# -------------------------------------------------------------------
function Test-LogLevel {
    <#
    .SYNOPSIS
    Checks if a log level should be recorded.

    .DESCRIPTION
    Compares the requested log level against the configured minimum level.
    Returns $true if the level is equal to or higher than the minimum.

    .PARAMETER Level
    The log level to check (DEBUG, INFO, WARN, or ERROR).

    .OUTPUTS
    System.Boolean - $true if the level should be logged
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [string]$Level
    )

    return (Get-LogLevelValue -Level $Level) -ge (Get-LogLevelValue -Level $script:LogLevel)
}

# -------------------------------------------------------------------
# Function: Get-DefaultLogFilePath
# -------------------------------------------------------------------
function Get-DefaultLogFilePath {
    <#
    .SYNOPSIS
    Determines the default log file path.

    .DESCRIPTION
    Automatically determines where the log file should be created.
    Uses the script's location or current directory as the base path.

    .OUTPUTS
    System.String - Full path to the default log file
    #>
    $scriptPath = $MyInvocation.ScriptName

    if (-not $scriptPath) {
        $scriptPath = $PSCommandPath
    }

    if (-not $scriptPath) {
        $scriptPath = $MyInvocation.MyCommand.Path
    }

    if ($scriptPath) {
        $logDir  = Split-Path $scriptPath -Parent
        $logFile = "$((Split-Path $scriptPath -LeafBase)).log"
    }
    else {
        $logDir  = (Get-Location).ProviderPath
        $logFile = 'log.log'
    }

    if (-not $logDir) {
        $logDir = (Get-Location).ProviderPath
    }

    return Join-Path -Path $logDir -ChildPath $logFile
}

# -------------------------------------------------------------------
# Function: Write-Log
# -------------------------------------------------------------------
function Write-Log {
    <#
    .SYNOPSIS
    Writes a log message to the log file and console.

    .DESCRIPTION
    Records a timestamped log entry with caller information.
    - Checks if the log level meets the minimum threshold
    - Outputs to Verbose stream (console)
    - Appends to the log file (auto-initializes if needed)
    - Writes ERROR messages to Warning stream

    .PARAMETER Message
    The log message to write.

    .PARAMETER Level
    The severity level (DEBUG, INFO, WARN, or ERROR). Default is INFO.

    .EXAMPLE
    Write-Log -Message "Application started"
    Writes an INFO level message.

    .EXAMPLE
    Write-Log -Message "Connection failed" -Level ERROR
    Writes an ERROR level message with warning output.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    # Only log if level is allowed
    if (-not (Test-LogLevel $Level)) {
        return
    }

    # Caller info
    $callStack = Get-PSCallStack
    $caller    = if ($callStack.Count -gt 1) { $callStack[1] } else { $callStack[0] }

    $functionName = $caller.FunctionName
    $lineNumber   = $caller.ScriptLineNumber
    $scriptName   = $MyInvocation.ScriptName

    if (-not $scriptName) {
        $scriptName = 'Interactive'
    }
    else {
        $scriptName = Split-Path $scriptName -Leaf
    }

    # Timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Format log line - fixed widths for alignment
    # Timestamp (19) | Level (5) | Script (20) | Line (4) | Function (22) | Message
    $logLine = "{0} | {1,-5} | {2,-30} | Line {3:D4} | [{4,-25}] | {5}" -f `
        $timestamp, $Level, $scriptName, $lineNumber, $functionName, $Message

    # Console output (always visible via Verbose stream)
    Write-Verbose $logLine

    # File output (auto-init if needed)
    if (-not $script:LogFilePath) {
        Initialize-Logger -Append
    }

    if ($script:LogFilePath) {
        Add-Content -Path $script:LogFilePath -Value $logLine -Encoding UTF8
    }

    # Extra severity handling
    if ($Level -eq 'ERROR') {
        Write-Warning $logLine
    }
}

# -------------------------------------------------------------------
# Function: Initialize-Logger
# -------------------------------------------------------------------
function Initialize-Logger {
    <#
    .SYNOPSIS
    Configures the logger.

    .DESCRIPTION
    Sets the minimum log level and optional log file path. By default, the specified file is cleared unless the Append switch is used.

    .PARAMETER Path
    Path to the log file.

    .PARAMETER Level
    Minimum log level to record (DEBUG, INFO, WARN, or ERROR).

    .PARAMETER Append
    Preserve the existing log file contents instead of clearing it.
    #>
    [CmdletBinding()]
    param (
        [string]$Path,

        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO',

        [switch]$Append
    )

    if (-not $Path) {
        $Path = Get-DefaultLogFilePath
    }

    $script:LogFilePath = $Path
    $script:LogLevel    = $Level

    if ($Path) {
        $dir = Split-Path $Path -Parent
        if (-not (Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
        }

        if (-not $Append) {
            Set-Content -Path $Path -Value '' -Encoding UTF8
        }
        elseif (-not (Test-Path $Path)) {
            New-Item -Path $Path -ItemType File | Out-Null
        }
    }
}

# Example usage:
# Initialize-Logger -Path "C:\Scripts\log.log" -Level DEBUG -Append
# Write-Log -Message "Debug information" -Level DEBUG
# Write-Log -Message "Application started"
# Write-Log -Message "Something might be wrong" -Level WARN
# Write-Log -Message "Something failed" -Level ERROR