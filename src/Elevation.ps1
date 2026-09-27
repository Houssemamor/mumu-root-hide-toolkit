param(
    [string]$ChildAction = ''
)

# The elevated child is launched with -File, so this module is a process entry point as well as a
# dot-sourced dependency. When it is the entry point it loads the two primitives it needs itself,
# because nothing else has run by then.
if ($MyInvocation.InvocationName -ne '.') {
    . (Join-Path $PSScriptRoot 'Common.ps1')
    . (Join-Path $PSScriptRoot 'Discovery.ps1')
}

$script:ToolkitElevationEntryPath = $PSCommandPath
# The boundary is this file's own directory, which is already absolute, so this assignment must not
# depend on a helper that a dot-sourcing caller may not have loaded yet.
$script:ToolkitSourceRoot = $PSScriptRoot
$script:ToolkitNotElevatedExitCode = 1223
$script:ToolkitStopPollAttempts = 5
$script:ToolkitStopPollDelaySeconds = 1
$script:ToolkitStableStopReadings = 2
$script:ToolkitDiskFileLimit = 100000
# Only the actions that change MuMu may ask for administrator rights. Detect and Verify change
# nothing, and the quit action is not an action at all, so a read-only run never raises a prompt.
$script:ToolkitElevatableActions = @('Target', 'Root12', 'Root15', 'Conceal', 'RemoveAds', 'Restore')
# The relaunch is the one external process a person can hold open, because Windows shows the UAC
# consent dialog and waits for a human. Both halves carry their own bound: the prompt has to be
# answered inside the shared transport bound, and the elevated child runs a whole action, whose own
# worst case is its two cold-boot polls plus the bounded transport calls around them.
if (-not (Test-Path variable:script:ToolkitElevatedPromptSeconds)) {
    $script:ToolkitElevatedPromptSeconds = 120
}
if (-not (Test-Path variable:script:ToolkitElevatedActionSeconds)) {
    $script:ToolkitElevatedActionSeconds = 3600
}
# A .NET access denial and a manager that names one are the same condition, so the seam recognizes
# both the exception type and the Windows message. Nothing else may ask for rights. A guest shell
# refusal is not host evidence: su prints "permission denied" inside the guest, and that must never
# reach a UAC prompt, so the pattern names host access denials only.
$script:ToolkitPermissionFailurePattern = '(?i)unauthorizedaccess|access (?:to the path .+ )?is denied|e_accessdenied'

# The launch runs on a private runspace because the runas verb blocks the calling thread on the
# consent dialog. A bound on the caller's own thread would therefore never be reached, so the launch
# is waited on off-thread and an unanswered prompt fails closed.
$script:ToolkitElevatedLaunchScript = @'
param($FilePath, $QuotedArguments)
try {
    Start-Process -FilePath $FilePath -ArgumentList $QuotedArguments -Verb 'RunAs' -PassThru -ErrorAction Stop
}
catch {
    $native = -1
    if ($_.Exception -is [ComponentModel.Win32Exception]) {
        $native = [int]$_.Exception.NativeErrorCode
    }
    return [pscustomobject]@{ LaunchError = [string]$_.Exception.Message; NativeErrorCode = $native }
}
'@

function Invoke-ToolkitBoundedLaunch {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Script,
        [object[]]$Arguments = @(),
        [Parameter(Mandatory = $true)]
        [int]$BoundSeconds
    )

    $runspace = $null
    $pipeline = $null
    try {
        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.Open()
        $pipeline = [powershell]::Create()
        $pipeline.Runspace = $runspace
        [void]$pipeline.AddScript($Script)
        foreach ($argument in @($Arguments)) {
            [void]$pipeline.AddArgument($argument)
        }
        $handle = $pipeline.BeginInvoke()
        if (-not $handle.AsyncWaitHandle.WaitOne($BoundSeconds * 1000)) {
            try {
                $pipeline.Stop()
            }
            catch {
            }
            return $null
        }
        return @($pipeline.EndInvoke($handle))
    }
    catch {
        return $null
    }
    finally {
        if ($null -ne $pipeline) {
            $pipeline.Dispose()
        }
        if ($null -ne $runspace) {
            $runspace.Dispose()
        }
    }
}

# The process entry point arms the elevation seam. It is kept here, next to the relaunch it performs,
# so no embedded caller can raise a UAC prompt by accident: an unarmed seam simply does not elevate.
$script:ToolkitProductionElevationRunner = {
    param($ScriptPath, $Arguments)

    return (Invoke-ElevatedToolkitAction -ScriptPath $ScriptPath -Arguments $Arguments)
}

function Test-ToolkitAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return [bool]$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-ToolkitPermissionFailure {
    param([object]$Result)

    if ($null -eq $Result -or $Result -isnot [pscustomobject]) {
        return $false
    }
    $statusProperty = $Result.PSObject.Properties['Status']
    if ($null -eq $statusProperty -or [string]$statusProperty.Value -ceq 'Success' -or
        [string]$statusProperty.Value -ceq 'AlreadyApplied') {
        return $false
    }
    return ([string]$Result.Message -match $script:ToolkitPermissionFailurePattern)
}

function Assert-ToolkitPowerShellAction {
    param(
        [string]$Path,
        [string]$Label
    )

    $actionPath = ConvertTo-ToolkitFullPath -Path $Path
    if ([string]::IsNullOrWhiteSpace($actionPath) -or [IO.Path]::GetExtension($actionPath) -ine '.ps1') {
        throw "$Label must be a PowerShell script path."
    }
    $actionItem = Get-Item -LiteralPath $actionPath -Force -ErrorAction Stop
    if ($actionItem -isnot [IO.FileInfo] -or ($actionItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "$Label is not a regular file."
    }
    # The elevated child runs the script a Base64 payload names, so the payload may not reach outside
    # this toolkit's own source directory. The comparison is made on resolved paths, so a junction or
    # symlink on the way in cannot carry the child out of the boundary.
    if (-not (Test-ToolkitPathWithinRoot -Path $actionPath -Root $script:ToolkitSourceRoot)) {
        throw "$Label is outside the toolkit source directory."
    }
    return $actionPath
}

function New-ToolkitElevatedArgumentList {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments = @()
    )

    $entryPath = ConvertTo-ToolkitFullPath -Path $script:ToolkitElevationEntryPath
    if ([string]::IsNullOrWhiteSpace($entryPath) -or -not (Test-Path -LiteralPath $entryPath -PathType Leaf)) {
        throw 'Elevation entry point is unavailable.'
    }
    $actionPath = Assert-ToolkitPowerShellAction -Path $ScriptPath -Label 'Elevated action'
    $request = [pscustomobject]@{
        Action = $actionPath
        Arguments = @($Arguments)
    }
    $json = ConvertTo-Json -InputObject $request -Depth 4 -Compress
    $payload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
    return @(
        '-NoProfile'
        '-ExecutionPolicy'
        'RemoteSigned'
        '-File'
        $entryPath
        '-ChildAction'
        $payload
    )
}

# The elevated child repeats the caller's own request, so the operator's confirmation and every
# bound path survive the relaunch and nothing is invented on the operator's behalf. Only parameters
# the caller actually set are bound, so an action never receives a parameter it does not take.
function New-ToolkitElevatedChildArguments {
    param(
        [string]$Action,
        [string]$InstallRoot = '',
        [int]$InstanceIndex = -1,
        [int]$SourceIndex = -1,
        [string]$StateRoot = '',
        [string[]]$Packages = @(),
        [string]$Mode = '',
        [object]$StartIndex = $null,
        [switch]$Confirmed
    )

    if ($script:ToolkitElevatableActions -cnotcontains $Action) {
        throw 'The requested action is not one that may be relaunched with administrator rights.'
    }
    $arguments = @(
        '-NonInteractive'
        '-Action'
        $Action
        '-ElevatedChild'
    )
    if (-not [string]::IsNullOrWhiteSpace($InstallRoot)) {
        $arguments += @('-InstallRoot', $InstallRoot)
    }
    if ($InstanceIndex -ge 0) {
        $arguments += @('-InstanceIndex', [string]$InstanceIndex)
    }
    if ($SourceIndex -ge 0) {
        $arguments += @('-SourceIndex', [string]$SourceIndex)
    }
    if (-not [string]::IsNullOrWhiteSpace($StateRoot)) {
        $arguments += @('-StateRoot', $StateRoot)
    }
    if (@($Packages).Count -gt 0) {
        $arguments += @('-Packages', (@($Packages) -join ','))
    }
    if (-not [string]::IsNullOrWhiteSpace($Mode)) {
        $arguments += @('-Mode', $Mode)
    }
    $startIndexValue = if ($null -eq $StartIndex) { '' } else { [string]$StartIndex }
    if (-not [string]::IsNullOrWhiteSpace($startIndexValue)) {
        $arguments += @('-StartIndex', $startIndexValue)
    }
    if ($Confirmed) {
        $arguments += '-Confirmed'
    }
    return $arguments
}

function Invoke-ToolkitElevatedChild {
    param([string]$Payload)

    if (-not (Test-ToolkitAdministrator)) {
        exit $script:ToolkitNotElevatedExitCode
    }

    $exitCode = 1
    try {
        $json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Payload))
        $request = $json | ConvertFrom-Json -ErrorAction Stop
        $childArguments = @()
        if ($null -ne $request.PSObject.Properties['Arguments']) {
            $childArguments = @($request.Arguments | ForEach-Object { [string]$_ })
        }
        $actionPath = Assert-ToolkitPowerShellAction -Path ([string]$request.Action) -Label 'Elevated child action'
        $global:LASTEXITCODE = 0
        & $actionPath @childArguments
        $exitCode = $global:LASTEXITCODE
    }
    catch {
        [Console]::Error.WriteLine('Elevated child action failed: ' + [string]$_.Exception.Message)
        $exitCode = 1
    }
    if ($null -eq $exitCode) {
        $exitCode = 1
    }
    exit $exitCode
}

function Invoke-ElevatedToolkitAction {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments = @(),
        [scriptblock]$Runner = $null,
        [scriptblock]$Launch = $null
    )

    $argumentList = $null
    try {
        $argumentList = @(New-ToolkitElevatedArgumentList -ScriptPath $ScriptPath -Arguments $Arguments)
    }
    catch {
        return Get-ToolkitResult -Status 'CriticalError' -Message ('Elevated action request is invalid: ' + (Protect-ToolkitText ([string]$_.Exception.Message)))
    }

    $powershellPath = Join-Path $PSHOME 'powershell.exe'
    $alreadyElevated = $false
    $exitCode = $null
    $exitCodeReported = $false
    $elevatedChild = $null
    if ($null -eq $Runner) {
        $quotedArguments = @($argumentList | ForEach-Object { ConvertTo-ProcessArgument -Argument $_ })
        $launchScript = $script:ToolkitElevatedLaunchScript
        if ($null -ne $Launch) {
            $launchScript = $Launch.ToString()
        }
        try {
            $alreadyElevated = Test-ToolkitAdministrator
            $outcome = Invoke-ToolkitBoundedLaunch -Script $launchScript -Arguments @($powershellPath, $quotedArguments) -BoundSeconds $script:ToolkitElevatedPromptSeconds
        }
        catch {
            $outcome = $null
        }
        if ($null -eq $outcome) {
            return Get-ToolkitResult -Status 'CriticalError' -Message "The Windows UAC prompt was not answered within the $($script:ToolkitElevatedPromptSeconds) second bound, so no elevated child was confirmed and the action fails closed."
        }
        $launched = @($outcome)[0]
        if ($launched -isnot [Diagnostics.Process]) {
            $nativeErrorCode = -1
            if ($null -ne $launched.PSObject.Properties['NativeErrorCode']) {
                $nativeErrorCode = [int]$launched.NativeErrorCode
            }
            $message = if ($nativeErrorCode -eq 1223) {
                'Elevation was denied or cancelled by Windows.'
            }
            else {
                $launchFailure = if ($null -ne $launched.PSObject.Properties['LaunchError']) { [string]$launched.LaunchError } else { 'the elevated child did not start.' }
                'Elevated launch failed: ' + (Protect-ToolkitText $launchFailure)
            }
            return Get-ToolkitResult -Status 'CriticalError' -Message $message
        }
        $elevatedChild = $launched
        try {
            if (-not $elevatedChild.WaitForExit($script:ToolkitElevatedActionSeconds * 1000)) {
                try {
                    $elevatedChild.Kill()
                }
                catch {
                }
                return Get-ToolkitResult -Status 'CriticalError' -Message "The elevated child did not complete within the $($script:ToolkitElevatedActionSeconds) second bound, so it was terminated and the action fails closed. Read the operation journal and the log before retrying."
            }
            $exitCode = $elevatedChild.ExitCode
            $exitCodeReported = $true
        }
        catch {
            return Get-ToolkitResult -Status 'CriticalError' -Message ('The elevated child could not be waited on: ' + (Protect-ToolkitText ([string]$_.Exception.Message)))
        }
        finally {
            $elevatedChild.Dispose()
        }
    }
    else {
        try {
            $alreadyElevated = Test-ToolkitAdministrator
            $outcome = & $Runner $powershellPath $argumentList 'RunAs'
            if ($null -ne $outcome -and $null -ne $outcome.PSObject -and $null -ne $outcome.PSObject.Properties['ExitCode']) {
                $exitCode = $outcome.ExitCode
                $exitCodeReported = $true
            }
        }
        catch {
            $exception = $_.Exception
            $nativeErrorCode = -1
            if ($exception -is [ComponentModel.Win32Exception]) {
                $nativeErrorCode = $exception.NativeErrorCode
            }
            $message = if ($nativeErrorCode -eq 1223) {
                'Elevation was denied or cancelled by Windows.'
            }
            else {
                'Elevated launch failed: ' + (Protect-ToolkitText ([string]$exception.Message))
            }
            return Get-ToolkitResult -Status 'CriticalError' -Message $message
        }
    }

    if (-not $exitCodeReported) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The elevated child did not report an exit code.'
    }
    if ($exitCode -isnot [int] -and $exitCode -isnot [long]) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The elevated child did not report a numeric exit code.'
    }
    $exitCode = [int]$exitCode
    $data = @{
        ExitCode = $exitCode
        Elevated = ($exitCode -eq 0)
        AlreadyElevated = $alreadyElevated
    }

    if ($exitCode -eq $script:ToolkitNotElevatedExitCode) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The elevated child did not confirm administrator rights.' -Data $data
    }
    if ($exitCode -ne 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message "The elevated child action failed with exit code $exitCode." -Data $data
    }
    return Get-ToolkitResult -Status 'Success' -Message 'The elevated child action completed.' -Data $data
}

function Get-MuMuInstanceRecord {
    param(
        [string]$ManagerPath,
        [string]$VersionArgument,
        [scriptblock]$Runner
    )

    $outcome = Invoke-CheckedProcess -FilePath $ManagerPath -ArgumentList @('info', '-v', $VersionArgument) -Runner $Runner
    if ($null -eq $outcome -or $outcome.ExitCode -ne 0) {
        return @()
    }
    try {
        return @(ConvertFrom-ToolkitJson -Text $outcome.Text -RequireInstance)
    }
    catch {
        return @()
    }
}

function Get-MuMuInstanceRunningState {
    param([object]$Record)

    return ConvertTo-ToolkitBoolean -Value (Get-ToolkitFirstProperty -InputObject $Record -PropertyNames @('is_process_started', 'is_android_started', 'running'))
}

function Get-ToolkitNamedInstanceRoots {
    param(
        [string]$Root,
        [int]$Index
    )

    $namedRoots = @()
    if ([string]::IsNullOrWhiteSpace($Root) -or -not (Test-Path -LiteralPath $Root -PathType Container)) {
        return $namedRoots
    }
    $childDirectories = @()
    try {
        $childDirectories = @([IO.Directory]::GetDirectories($Root))
    }
    catch {
        return $namedRoots
    }
    $indexPattern = '(?i)-' + [regex]::Escape([string]$Index) + '$'
    foreach ($childDirectory in $childDirectories) {
        $childName = [IO.Path]::GetFileName($childDirectory)
        if ($childName -match '(?i)(^|-)base$' -or $childName -notmatch $indexPattern) {
            continue
        }
        $namedRoots += $childDirectory
    }
    return $namedRoots
}

function Get-MuMuInstanceRootPath {
    param(
        [string]$VmsPath,
        [int]$Index,
        [string]$ReportedVmsPath
    )

    $root = $VmsPath
    if (-not [string]::IsNullOrWhiteSpace($ReportedVmsPath)) {
        $root = Get-ToolkitMetadataPath -Path $ReportedVmsPath -Root $VmsPath
        if ($null -eq $root) {
            return $null
        }
    }
    $baseDirectories = @($root, (Join-Path $root 'vms'))
    foreach ($baseDirectory in $baseDirectories) {
        $candidate = ConvertTo-ToolkitFullPath -Path (Join-Path $baseDirectory ([string]$Index))
        if ($null -eq $candidate) {
            continue
        }
        if (-not (Test-Path -LiteralPath $candidate -PathType Container)) {
            continue
        }
        if (-not (Test-ToolkitPathWithinRoot -Path $candidate -Root $VmsPath)) {
            return $null
        }
        return $candidate
    }
    $namedRoots = @()
    foreach ($baseDirectory in $baseDirectories) {
        foreach ($namedRoot in @(Get-ToolkitNamedInstanceRoots -Root $baseDirectory -Index $Index)) {
            $namedFullPath = ConvertTo-ToolkitFullPath -Path $namedRoot
            if ($null -eq $namedFullPath) {
                continue
            }
            if (-not (Test-ToolkitPathWithinRoot -Path $namedFullPath -Root $VmsPath)) {
                return $null
            }
            $namedRoots += $namedFullPath
        }
    }
    if ($namedRoots.Count -ne 1) {
        return $null
    }
    return $namedRoots[0]
}

function Measure-MuMuInstanceDiskBytes {
    param([string]$InstanceRoot)

    $total = [long]0
    $fileCount = 0
    try {
        foreach ($file in [IO.Directory]::EnumerateFiles($InstanceRoot, '*', [IO.SearchOption]::AllDirectories)) {
            $fileCount++
            if ($fileCount -gt $script:ToolkitDiskFileLimit) {
                return $null
            }
            $total += [long](New-Object IO.FileInfo($file)).Length
        }
    }
    catch {
        return $null
    }
    return $total
}

function New-ToolkitInstanceFailure {
    param(
        [object]$Journal,
        [string]$Message
    )

    $message = Protect-ToolkitText $Message
    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = 'The instance operation failed.'
    }
    $result = Get-ToolkitResult -Status 'CriticalError' -Message $message
    if ($null -eq $Journal) {
        return $result
    }
    $journalState = $null
    if ($null -ne $Journal.PSObject -and $null -ne $Journal.PSObject.Properties['State']) {
        $journalState = $Journal.State
    }
    if ($journalState -ne 'Running') {
        return $result
    }
    try {
        Write-JournalEvent -Journal $Journal -Level 'Error' -Message $message -Data $null
        Fail-OperationJournal -Journal $Journal -Result $result
    }
    catch {
        return Get-ToolkitResult -Status 'CriticalError' -Message ($message + ' The failure could not be journaled.')
    }
    return $result
}

function Wait-MuMuInstanceStopped {
    param(
        [string]$ManagerPath,
        [int]$Index,
        [scriptblock]$Runner
    )

    $stableReadings = 0
    for ($attempt = 1; $attempt -le $script:ToolkitStopPollAttempts; $attempt++) {
        if ($attempt -gt 1) {
            Start-Sleep -Seconds $script:ToolkitStopPollDelaySeconds
        }
        $records = @(Get-MuMuInstanceRecord -ManagerPath $ManagerPath -VersionArgument ([string]$Index) -Runner $Runner)
        if ($records.Count -ne 1) {
            $stableReadings = 0
            continue
        }
        $running = Get-MuMuInstanceRunningState -Record $records[0]
        if ($null -eq $running -or $running) {
            $stableReadings = 0
            continue
        }
        $stableReadings++
        if ($stableReadings -ge $script:ToolkitStableStopReadings) {
            return $true
        }
    }
    return $false
}

function New-InstanceClone {
    param(
        [string]$ManagerPath,
        [object]$Instance,
        [object]$Journal,
        [scriptblock]$Runner = $null
    )

    $manager = ConvertTo-ToolkitFullPath -Path $ManagerPath
    if ($null -eq $manager -or -not (Test-ToolkitManagerName -Path $manager)) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The clone manager must be MuMuManager.exe.'
    }
    if ($null -eq $Journal) {
        return New-ToolkitInstanceFailure -Journal $null -Message 'A clone journal is required.'
    }
    try {
        Assert-OperationJournal $Journal
    }
    catch {
        return New-ToolkitInstanceFailure -Journal $null -Message 'The clone journal is invalid.'
    }
    if ($null -eq $Instance -or $Instance -is [Array] -or $Instance -isnot [pscustomobject]) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The source instance is invalid.'
    }
    $indexProperty = $Instance.PSObject.Properties['Index']
    if ($null -eq $indexProperty -or
        ($indexProperty.Value -isnot [string] -and $indexProperty.Value -isnot [int] -and $indexProperty.Value -isnot [long])) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The source instance index is invalid.'
    }
    $sourceIndex = 0
    if (-not [int]::TryParse([string]$indexProperty.Value, [ref]$sourceIndex) -or $sourceIndex -lt 0) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The source instance index is invalid.'
    }
    $nameProperty = $Instance.PSObject.Properties['Name']
    if ($null -eq $nameProperty -or $nameProperty.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($nameProperty.Value)) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The source instance name is invalid.'
    }
    $sourceName = [string]$nameProperty.Value
    $installProperty = $Instance.PSObject.Properties['Install']
    if ($null -eq $installProperty -or $null -eq $installProperty.Value -or $installProperty.Value -isnot [pscustomobject]) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The source instance install is invalid.'
    }
    $installRootProperty = $installProperty.Value.PSObject.Properties['InstallRoot']
    if ($null -eq $installRootProperty -or $installRootProperty.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($installRootProperty.Value)) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The source instance install root is invalid.'
    }
    $installRoot = ConvertTo-ToolkitFullPath -Path $installRootProperty.Value
    if ($null -eq $installRoot -or -not (Test-Path -LiteralPath $installRoot -PathType Container)) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The source instance install root is unavailable.'
    }
    if (-not (Test-ToolkitManagerFile -Path $manager -InstallRoot $installRoot)) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The clone manager is not a valid MuMu manager inside the install root.'
    }
    $vmsProperty = $installProperty.Value.PSObject.Properties['VmsPath']
    if ($null -eq $vmsProperty -or $vmsProperty.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($vmsProperty.Value)) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The source instance VMS path is invalid.'
    }
    $vmsPath = ConvertTo-ToolkitFullPath -Path $vmsProperty.Value
    if ($null -eq $vmsPath -or -not (Test-Path -LiteralPath $vmsPath -PathType Container)) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The source instance VMS path is unavailable.'
    }
    $versionProperty = $Instance.PSObject.Properties['AndroidVersion']
    $sourceVersionValue = $null
    if ($null -ne $versionProperty) {
        $sourceVersionValue = $versionProperty.Value
    }
    $sourceVersion = ConvertTo-ToolkitAndroidVersion -Value $sourceVersionValue
    if ($null -eq $sourceVersion) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The source instance Android version is invalid.'
    }

    $preRecords = @(Get-MuMuInstanceRecord -ManagerPath $manager -VersionArgument 'all' -Runner $Runner)
    if ($preRecords.Count -eq 0) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The MuMu manager did not report instance state.'
    }
    $preIndexes = @{}
    $preNames = @()
    $sourceRecords = @()
    foreach ($preRecord in $preRecords) {
        $preIndexProperty = $preRecord.PSObject.Properties['index']
        $parsedIndex = 0
        if ($null -eq $preIndexProperty -or -not [int]::TryParse([string]$preIndexProperty.Value, [ref]$parsedIndex) -or $parsedIndex -lt 0) {
            return New-ToolkitInstanceFailure -Journal $Journal -Message 'The MuMu manager returned an invalid instance index.'
        }
        $preIndexes[[string]$parsedIndex] = $true
        $preNameProperty = $preRecord.PSObject.Properties['name']
        $preNames += if ($null -eq $preNameProperty -or $preNameProperty.Value -isnot [string]) { '' } else { [string]$preNameProperty.Value }
        if ($parsedIndex -eq $sourceIndex) {
            $sourceRecords += $preRecord
        }
    }
    if ($sourceRecords.Count -ne 1) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The MuMu manager did not report exactly one source instance.'
    }

    $sourceRunning = Get-MuMuInstanceRunningState -Record $sourceRecords[0]
    if ($null -eq $sourceRunning) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The source instance running state is unknown.'
    }
    if ($sourceRunning) {
        $shutdown = Invoke-CheckedProcess -FilePath $manager -ArgumentList @('control', '-v', [string]$sourceIndex, 'shutdown') -Runner $Runner
        if ($null -eq $shutdown -or $shutdown.ExitCode -ne 0) {
            return New-ToolkitInstanceFailure -Journal $Journal -Message 'The source instance did not accept a shutdown request.'
        }
    }
    if (-not (Wait-MuMuInstanceStopped -ManagerPath $manager -Index $sourceIndex -Runner $Runner)) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The source instance did not reach a stable stopped state.'
    }

    $clone = Invoke-CheckedProcess -FilePath $manager -ArgumentList @('clone', '-v', [string]$sourceIndex, '-n', '1') -Runner $Runner
    if ($null -eq $clone -or $clone.ExitCode -ne 0) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The MuMu manager clone command failed.'
    }

    $postRecords = @(Get-MuMuInstanceRecord -ManagerPath $manager -VersionArgument 'all' -Runner $Runner)
    $newRecords = @($postRecords | Where-Object { -not $preIndexes.ContainsKey([string]$_.index) })
    if ($newRecords.Count -ne 1) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The MuMu manager did not report exactly one new instance after the clone.'
    }
    $cloneRecord = $newRecords[0]
    $cloneIndex = 0
    if (-not [int]::TryParse([string]$cloneRecord.index, [ref]$cloneIndex) -or $cloneIndex -lt 0) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The clone instance index is invalid.'
    }
    $cloneNameProperty = $cloneRecord.PSObject.Properties['name']
    if ($null -eq $cloneNameProperty -or $cloneNameProperty.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($cloneNameProperty.Value)) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The clone instance name is missing.'
    }
    $cloneName = [string]$cloneNameProperty.Value
    foreach ($preName in $preNames) {
        if ($preName -cne $sourceName -and $preName -ceq $cloneName) {
            return New-ToolkitInstanceFailure -Journal $Journal -Message 'The clone instance name collides with an existing instance.'
        }
    }

    $reportedVmsPath = [string](Get-ToolkitFirstProperty -InputObject $cloneRecord -PropertyNames @('vms_path', 'vmsPath'))
    if (-not [string]::IsNullOrWhiteSpace($reportedVmsPath)) {
        $reportedRoot = Get-ToolkitMetadataPath -Path $reportedVmsPath -Root $vmsPath
        if ($null -eq $reportedRoot) {
            return New-ToolkitInstanceFailure -Journal $Journal -Message 'The clone instance VMS path is invalid.'
        }
        if (-not (Test-ToolkitPathWithinRoot -Path $reportedRoot -Root $vmsPath)) {
            return New-ToolkitInstanceFailure -Journal $Journal -Message 'The clone instance VMS path is outside the source install boundary.'
        }
    }
    $cloneRoot = Get-MuMuInstanceRootPath -VmsPath $vmsPath -Index $cloneIndex -ReportedVmsPath $reportedVmsPath
    if ($null -eq $cloneRoot) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The clone instance VMS root is missing.'
    }
    if (-not (Test-ToolkitPathWithinRoot -Path $cloneRoot -Root $vmsPath)) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The clone instance VMS root is outside the source install boundary.'
    }
    $cloneVersion = ConvertTo-ToolkitAndroidVersion -Value (Get-ToolkitFirstProperty -InputObject $cloneRecord -PropertyNames @('android_version', 'androidVersion', 'system_version', 'systemVersion'))
    if ($null -eq $cloneVersion) {
        $cloneVersion = Get-ToolkitInstanceAndroidVersion -VmsPath $vmsPath -Index $cloneIndex
    }
    if ($null -eq $cloneVersion) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The clone instance Android version could not be verified.'
    }
    if ($cloneVersion -cne $sourceVersion) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The clone instance Android version does not match the source instance.'
    }

    $diskBytes = Measure-MuMuInstanceDiskBytes -InstanceRoot $cloneRoot
    if ($null -eq $diskBytes) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The clone instance disk could not be measured.'
    }
    if ($diskBytes -le 0) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The clone instance does not have a usable disk.'
    }
    $cloneIsMain = ConvertTo-ToolkitBoolean -Value (Get-ToolkitFirstProperty -InputObject $cloneRecord -PropertyNames @('is_main'))
    if ($cloneIsMain -ne $false) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The clone instance is not a reported non-base instance.'
    }
    if ((Get-MuMuInstanceRunningState -Record $cloneRecord) -ne $false) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The clone instance is not reported in a stopped state.'
    }

    $cloneData = @{
        SourceIndex = $sourceIndex
        CloneIndex = $cloneIndex
        CloneName = $cloneName
        AndroidVersion = $cloneVersion
        DiskBytes = $diskBytes
        VmsPath = $cloneRoot
        StaticReady = $true
        ColdBootVerified = $false
    }
    $cloneMessage = "Clone statically verified at index $cloneIndex. A cold boot is not verified."
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message $cloneMessage -Data $cloneData
    }
    catch {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The verified clone could not be journaled.'
    }
    return Get-ToolkitResult -Status 'Success' -Message $cloneMessage -Data $cloneData
}

if (-not [string]::IsNullOrWhiteSpace($ChildAction)) {
    Invoke-ToolkitElevatedChild -Payload $ChildAction
}
