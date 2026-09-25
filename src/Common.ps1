function Get-ToolkitResult {
    param(
        [ValidateSet('Success', 'AlreadyApplied', 'Warning', 'RecoverableError', 'CriticalError')]
        [string]$Status,
        [string]$Message,
        [object]$Data = $null
    )

    [pscustomobject]@{
        Status = $Status
        Message = $Message
        Data = $Data
    }
}

function Invoke-CheckedProcess {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList = @(),
        [scriptblock]$Runner = $null
    )

    if ($null -ne $Runner) {
        return & $Runner $FilePath $ArgumentList
    }

    $ErrorActionPreference = 'Continue'
    $output = @(& $FilePath @ArgumentList 2>&1 | ForEach-Object { [string]$_ })
    $exitCode = if ($null -eq $LASTEXITCODE) { 1 } else { [int]$LASTEXITCODE }

    [pscustomobject]@{
        ExitCode = $exitCode
        Text = $output -join [Environment]::NewLine
    }
}

function Get-ToolkitLogPath {
    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        throw 'LOCALAPPDATA is not available.'
    }

    [IO.Path]::Combine(
        $env:LOCALAPPDATA,
        'mumu-root-hide-toolkit',
        'logs',
        'mumu-root-hide-toolkit.log'
    )
}
