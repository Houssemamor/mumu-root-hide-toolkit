# The only command words, options, and operators a guest shell command may use.
$script:ToolkitGuestCommandVerbs = @('base64', 'cat', 'echo', 'ls', 'mkdir', 'mv', 'rm', 'rmdir', 'unzip')
$script:ToolkitGuestCommandOptions = @('-d', '-f', '-l', '-o', '-p', '-rf')
$script:ToolkitGuestCommandOperators = @('|', '>', '&&')
$script:ToolkitMaximumGuestPathLength = 255

# A wedged manager or a blocked ADB port must not hang the menu, so every external process is
# given a bounded wait and the child is terminated when the bound expires. Two minutes sits above
# the slowest legitimate child, a guest pm install of the pinned Kitsune APK on a cold instance,
# and far below any operator's patience.
if (-not (Test-Path variable:script:ToolkitProcessTimeoutSeconds)) {
    $script:ToolkitProcessTimeoutSeconds = 120
}
# A surviving grandchild can hold a redirected pipe open after the child itself is gone, so the
# captured streams are drained with a bounded wait too.
$script:ToolkitProcessDrainMilliseconds = 5000

# A read-only transport call is retried only for a transport failure or an explicit not-started
# transient. The bound is the same one the retry helper already carries.
if (-not (Test-Path variable:script:ToolkitReadOnlyAttempts)) {
    $script:ToolkitReadOnlyAttempts = 3
}
if (-not (Test-Path variable:script:ToolkitReadOnlyDelaySeconds)) {
    $script:ToolkitReadOnlyDelaySeconds = 2
}
# A semantic refusal is a decision, so it is never retried. Only a manager or guest that reports
# the work is not under way yet counts as transient.
$script:ToolkitTransientCallPattern = '(?i)\b(?:not\s+(?:started|running|ready|booted)|no\s+running\s+instance|device\s+offline)\b'
# Only these guest command words read state and change nothing. Anything else, including a shell
# su -c request whose payload the toolkit cannot inspect, is left unretried.
$script:ToolkitReadOnlyGuestPattern = '^(?:shell\s+)?(?:getprop|dumpsys|pidof|cat|ls|base64)\b'

function Test-ToolkitGuestPath {
    param([string]$Path)

    if ($Path -isnot [string] -or $Path -notmatch '^/[A-Za-z0-9._/-]+$' -or
        $Path -match '//' -or $Path -match '(^|/)\.\.(/|$)' -or
        $Path.Length -gt $script:ToolkitMaximumGuestPathLength) {
        return $false
    }
    return $true
}

# The single funnel that turns an allowlisted guest command into one adb request. The MuMu manager
# strips double quotes from the request, so the command is single quoted and nothing that could end
# that quoting is accepted. On success the request is the Data; on refusal the reason is the Message.
function New-ToolkitGuestCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    $refused = {
        param([string]$Reason)

        return Get-ToolkitResult -Status 'CriticalError' -Message "The guest command is not sent: $Reason"
    }

    if ($Command -isnot [string] -or [string]::IsNullOrWhiteSpace($Command)) {
        return (& $refused 'it is empty')
    }
    if ($Command -match '[\x00-\x1f\x7f]') {
        return (& $refused 'it carries a control character or a newline')
    }
    $tokens = @($Command -split ' ')
    if ($script:ToolkitGuestCommandVerbs -cnotcontains $tokens[0]) {
        return (& $refused "it does not start with a supported command word: $($tokens[0])")
    }
    foreach ($token in $tokens) {
        if ($script:ToolkitGuestCommandVerbs -ccontains $token -or
            $script:ToolkitGuestCommandOptions -ccontains $token -or
            $script:ToolkitGuestCommandOperators -ccontains $token) {
            continue
        }
        if ($token.StartsWith('/')) {
            if (-not (Test-ToolkitGuestPath -Path $token)) {
                return (& $refused "the path is not a plain absolute guest path: $token")
            }
            continue
        }
        if ($token -notmatch '^[A-Za-z0-9+/=]+$') {
            return (& $refused "the argument is neither a known command word nor a base64 payload: $token")
        }
    }
    return Get-ToolkitResult -Status 'Success' -Message 'The guest command is safely quoted.' -Data ('shell su -c ' + [char]39 + $Command + [char]39)
}

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

function ConvertTo-ToolkitFullPath {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    try {
        $fullPath = [IO.Path]::GetFullPath($Path)
        $pathRoot = [IO.Path]::GetPathRoot($fullPath)
        if (-not [string]::IsNullOrWhiteSpace($pathRoot) -and $fullPath.Length -gt $pathRoot.Length) {
            $separators = [char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
            $fullPath = $fullPath.TrimEnd($separators)
        }
    }
    catch {
        return $null
    }

    return $fullPath
}

function Protect-ToolkitText {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Text
    )

    if ($null -eq $Text) {
        return $null
    }
    $authorizationPattern = '(?i)(["'']?authorization["'']?\s*(?::|=|\bis\b)\s*)(?:Bearer|Basic)\s+[^\s,;}\[\]]+'
    $Text = [regex]::Replace($Text, $authorizationPattern, '$1[REDACTED]')
    $labeledPattern = '(?i)(["'']?(?:token|password|secret|authorization|cookie|key)["'']?\s*(?::|=|\bis\b)\s*)(?:"[^"]*"|''[^'']*''|[^\s,;}\[\]]+)'
    $Text = [regex]::Replace($Text, $labeledPattern, '$1[REDACTED]')
    $tokenPattern = '(?i)\b(?:gh[pousr]_[A-Za-z0-9_]+|github_pat_[A-Za-z0-9_]+|sk-[A-Za-z0-9_-]+|AKIA[0-9A-Z]{16})\b'
    return [regex]::Replace($Text, $tokenPattern, '[REDACTED]')
}

function Invoke-WithRetry {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [scriptblock]$Operation,
        [ValidateRange(1, 10)]
        [int]$Attempts = 3,
        [ValidateRange(0, 60)]
        [int]$DelaySeconds = 2
    )

    $lastResult = Get-ToolkitResult -Status 'RecoverableError' -Message 'Operation did not run.'
    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try {
            $outputs = @(& $Operation)
            $invalidMessage = if ($outputs.Count -eq 0) {
                'Operation returned no output.'
            }
            elseif ($outputs.Count -gt 1) {
                "Operation returned $($outputs.Count) output items; expected one toolkit result object."
            }
            elseif ($outputs[0] -is [Array]) {
                'Operation returned one array; expected one toolkit result object.'
            }
            elseif ($outputs[0] -is [pscustomobject]) {
                $propertyCount = @($outputs[0].PSObject.Properties).Count
                "Operation returned one object with $propertyCount properties; expected exactly Status, Message, and Data."
            }
            else {
                "Operation returned one $($outputs[0].GetType().FullName) value; expected one toolkit result object."
            }
            if ($outputs.Count -eq 1 -and $outputs[0] -is [pscustomobject]) {
                $candidate = $outputs[0]
                $propertyNames = @($candidate.PSObject.Properties | ForEach-Object { $_.Name })
                $hasExactProperties = $propertyNames.Count -eq 3 -and
                    $propertyNames -ccontains 'Status' -and
                    $propertyNames -ccontains 'Message' -and
                    $propertyNames -ccontains 'Data'
                if (-not $hasExactProperties) {
                    if ($propertyNames.Count -eq 3) {
                        $invalidMessage = 'Operation returned one object with invalid property names or casing; expected exactly Status, Message, and Data.'
                    }
                }
                elseif ($candidate.Status -isnot [string] -or
                    @('Success', 'AlreadyApplied', 'Warning', 'RecoverableError', 'CriticalError') -cnotcontains $candidate.Status) {
                    $invalidMessage = 'Operation returned one object with a noncanonical Status; expected a canonical toolkit status.'
                }
                elseif ($candidate.Message -isnot [string] -or [string]::IsNullOrWhiteSpace($candidate.Message)) {
                    $invalidMessage = 'Operation returned one object with an empty or invalid Message.'
                }
                else {
                    $message = Protect-ToolkitText $candidate.Message
                    if (-not [string]::IsNullOrWhiteSpace($message)) {
                        return Get-ToolkitResult -Status $candidate.Status -Message $message -Data $candidate.Data
                    }
                    $invalidMessage = 'Operation returned one object whose Message could not be sanitized.'
                }
            }
            return Get-ToolkitResult -Status 'RecoverableError' -Message (Protect-ToolkitText $invalidMessage)
        }
        catch {
            $message = Protect-ToolkitText ([string]$_.Exception.Message)
            if ([string]::IsNullOrWhiteSpace($message)) {
                $message = 'Operation failed.'
            }
            $lastResult = Get-ToolkitResult -Status 'RecoverableError' -Message $message
        }
        if ($attempt -lt $Attempts) {
            Start-Sleep -Seconds $DelaySeconds
        }
    }
    return $lastResult
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
        [scriptblock]$Runner = $null,
        [ValidateRange(0, 3600)]
        [int]$TimeoutSeconds = 0
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

    # Zero means the shared bound, so every call site inherits it without opting in.
    $boundSeconds = $TimeoutSeconds
    if ($boundSeconds -le 0) {
        $boundSeconds = [int]$script:ToolkitProcessTimeoutSeconds
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
        # The redirected streams are drained while the child runs, so a large payload cannot fill a
        # pipe buffer and wedge the child before the bounded wait expires.
        $standardOutputTask = $process.StandardOutput.ReadToEndAsync()
        $standardErrorTask = $process.StandardError.ReadToEndAsync()
        $timedOut = -not $process.WaitForExit($boundSeconds * 1000)
        if ($timedOut) {
            try {
                $process.Kill()
            }
            catch {
            }
        }
        [void][Threading.Tasks.Task]::WaitAll(
            [Threading.Tasks.Task[]]@($standardOutputTask, $standardErrorTask),
            $script:ToolkitProcessDrainMilliseconds)
        $text = if ($standardOutputTask.IsCompleted -and -not $standardOutputTask.IsFaulted) { $standardOutputTask.Result } else { '' }
        $standardError = if ($standardErrorTask.IsCompleted -and -not $standardErrorTask.IsFaulted) { $standardErrorTask.Result } else { '' }
        if ($timedOut) {
            return [pscustomobject]@{
                ExitCode = -1
                Text = "The process did not exit within the $boundSeconds second timeout and was terminated: $FilePath"
            }
        }
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

# A retryable failure is a transport failure, which is the only kind a read-only query may repeat.
# A call that reports nothing to retry on, or a semantic refusal, is answered once.
function Test-ToolkitRetryableCall {
    param([AllowNull()][object]$Call)

    if ($null -eq $Call -or $null -eq $Call.PSObject) {
        return $true
    }
    $exitCode = $Call.PSObject.Properties['ExitCode']
    if ($null -eq $exitCode) {
        return $true
    }
    if ($exitCode.Value -eq -1) {
        return $true
    }
    if ($exitCode.Value -eq 0) {
        return $false
    }
    $text = $Call.PSObject.Properties['Text']
    if ($null -eq $text) {
        return $false
    }
    return ([string]$text.Value -match $script:ToolkitTransientCallPattern)
}

# The bounded retry for a read-only transport call. A retryable failure is thrown so the bounded
# retry loop counts the attempt, and every other outcome is returned once, so a semantic refusal is
# never repeated. Exhaustion surfaces the recoverable result, which is what makes exit code 2 and
# the menu's Warning branch reachable, and the last underlying error stays in its message.
function Invoke-ToolkitReadOnlyCall {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Description,
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [scriptblock]$Call
    )

    $operation = {
        $call = & $Call
        if (Test-ToolkitRetryableCall -Call $call) {
            throw ($Description + ' failed. ' + [string]$call.Text)
        }
        return (Get-ToolkitResult -Status 'Success' -Message ($Description + ' ran.') -Data $call)
    }
    return (Invoke-WithRetry -Operation $operation -Attempts $script:ToolkitReadOnlyAttempts -DelaySeconds $script:ToolkitReadOnlyDelaySeconds)
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

function Get-ToolkitStateRoot {
    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        throw 'LOCALAPPDATA is not available.'
    }

    [IO.Path]::Combine(
        $env:LOCALAPPDATA,
        'mumu-root-hide-toolkit'
    )
}

function Write-ToolkitLogEntry {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,
        [string]$LogPath = ''
    )

    $path = $LogPath
    if ([string]::IsNullOrWhiteSpace($path)) {
        $path = Get-ToolkitLogPath
    }
    $text = Protect-ToolkitText $Message
    if ([string]::IsNullOrWhiteSpace($text)) {
        $text = 'The action reported no detail.'
    }
    $level = Protect-ToolkitText $Level
    $entry = '[' + [DateTime]::UtcNow.ToString('o') + '] [' + $level + '] ' + $text + [Environment]::NewLine
    $directory = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($path))
    [void][IO.Directory]::CreateDirectory($directory)
    [IO.File]::AppendAllText([IO.Path]::GetFullPath($path), $entry, (New-Object Text.UTF8Encoding($false)))
    return [IO.Path]::GetFullPath($path)
}

function Get-ToolkitExitCode {
    param([object]$Result)

    if ($null -eq $Result -or $Result -is [Array] -or $Result -isnot [pscustomobject]) {
        return 1
    }
    $propertyNames = @($Result.PSObject.Properties | ForEach-Object { $_.Name })
    if ($propertyNames.Count -ne 3 -or
        $propertyNames -cnotcontains 'Status' -or
        $propertyNames -cnotcontains 'Message' -or
        $propertyNames -cnotcontains 'Data') {
        return 1
    }
    switch ([string]$Result.Status) {
        'Success' { return 0 }
        'AlreadyApplied' { return 0 }
        'Warning' { return 0 }
        'RecoverableError' { return 2 }
        'CriticalError' { return 1 }
        default { return 1 }
    }
}
