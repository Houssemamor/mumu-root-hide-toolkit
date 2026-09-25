function Get-ToolkitResult {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Success', 'AlreadyApplied', 'Warning', 'RecoverableError', 'CriticalError')]
        [string]$Status,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,
        [object]$Data = $null
    )

    $statuses = @('Success', 'AlreadyApplied', 'Warning', 'RecoverableError', 'CriticalError')
    if ($statuses -cnotcontains $Status) {
        throw 'Result status is not canonical.'
    }
    if ([string]::IsNullOrWhiteSpace($Message)) {
        throw 'Result message must not be empty.'
    }

    [pscustomobject]@{
        Status = $Status
        Message = $Message
        Data = $Data
    }
}

function ConvertTo-ProcessArgument {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Argument
    )

    if ($null -eq $Argument) {
        return '""'
    }

    $builder = New-Object Text.StringBuilder
    [void]$builder.Append('"')
    $pendingBackslashes = 0
    foreach ($character in $Argument.ToCharArray()) {
        if ($character -eq [char]'\') {
            $pendingBackslashes++
            continue
        }
        if ($character -eq [char]'"') {
            [void]$builder.Append([char]'\', ($pendingBackslashes * 2) + 1)
            [void]$builder.Append('"')
            $pendingBackslashes = 0
            continue
        }
        if ($pendingBackslashes -gt 0) {
            [void]$builder.Append([char]'\', $pendingBackslashes)
            $pendingBackslashes = 0
        }
        [void]$builder.Append($character)
    }
    if ($pendingBackslashes -gt 0) {
        [void]$builder.Append([char]'\', $pendingBackslashes * 2)
    }
    [void]$builder.Append('"')
    $builder.ToString()
}

function Invoke-CheckedProcess {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList = @(),
        [scriptblock]$Runner = $null
    )

    if ($null -ne $Runner) {
        try {
            return & $Runner $FilePath $ArgumentList
        }
        catch {
            return [pscustomobject]@{
                ExitCode = -1
                Text = "Process launch failed: $($_.Exception.Message)"
            }
        }
    }

    $encodedArguments = New-Object 'System.Collections.Generic.List[string]'
    foreach ($argument in $ArgumentList) {
        [void]$encodedArguments.Add((ConvertTo-ProcessArgument -Argument $argument))
    }

    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FilePath
    $startInfo.Arguments = $encodedArguments -join ' '
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) {
            throw New-Object InvalidOperationException 'Process did not start.'
        }
        $standardOutputTask = $process.StandardOutput.ReadToEndAsync()
        $standardErrorTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $text = $standardOutputTask.Result
        $standardError = $standardErrorTask.Result
        if (-not [string]::IsNullOrEmpty($standardError)) {
            if (-not [string]::IsNullOrEmpty($text)) {
                $text += [Environment]::NewLine
            }
            $text += $standardError
        }

        [pscustomobject]@{
            ExitCode = $process.ExitCode
            Text = $text
        }
    }
    catch {
        [pscustomobject]@{
            ExitCode = -1
            Text = "Process launch failed: $($_.Exception.Message)"
        }
    }
    finally {
        $process.Dispose()
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
