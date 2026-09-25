param(
    [string]$ChildAction = ''
)

$script:ToolkitElevationEntryPath = $PSCommandPath
$script:ToolkitNotElevatedExitCode = 1223
$script:ToolkitStopPollAttempts = 5
$script:ToolkitStopPollDelaySeconds = 1
$script:ToolkitStableStopReadings = 2
$script:ToolkitDiskFileLimit = 100000

function Test-ToolkitAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return [bool]$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
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
        [scriptblock]$Runner = $null
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
    try {
        $alreadyElevated = Test-ToolkitAdministrator
        if ($null -ne $Runner) {
            $outcome = & $Runner $powershellPath $argumentList 'RunAs'
            if ($null -eq $outcome -or $null -eq $outcome.PSObject.Properties['ExitCode']) {
                throw 'The elevated child did not report an exit code.'
            }
            $exitCode = $outcome.ExitCode
        }
        else {
            $quotedArguments = @($argumentList | ForEach-Object { ConvertTo-ProcessArgument -Argument $_ })
            $process = Start-Process -FilePath $powershellPath -ArgumentList $quotedArguments -Verb 'RunAs' -Wait -PassThru -ErrorAction Stop
            $exitCode = $process.ExitCode
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

    if ($exitCode -isnot [int] -and $exitCode -isnot [long]) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The elevated child did not report a numeric exit code.'
    }
    $exitCode = [int]$exitCode
    $elevated = ($exitCode -ne $script:ToolkitNotElevatedExitCode)
    $data = @{
        ExitCode = $exitCode
        Elevated = $elevated
        AlreadyElevated = $alreadyElevated
    }

    if (-not $elevated) {
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
        return $null
    }
    try {
        return @(ConvertFrom-ToolkitJson -Text $outcome.Text -RequireInstance)
    }
    catch {
        return $null
    }
}

function Get-MuMuInstanceRunningState {
    param([object]$Record)

    return ConvertTo-ToolkitBoolean -Value (Get-ToolkitFirstProperty -InputObject $Record -PropertyNames @('is_process_started', 'is_android_started', 'running'))
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
    foreach ($candidate in @((Join-Path $root ([string]$Index)), (Join-Path (Join-Path $root 'vms') ([string]$Index)))) {
        $instanceRoot = ConvertTo-ToolkitFullPath -Path $candidate
        if ($null -ne $instanceRoot -and (Test-Path -LiteralPath $instanceRoot -PathType Container)) {
            return $instanceRoot
        }
    }
    return $null
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

function New-InstanceCloneFailure {
    param(
        [object]$Journal,
        [string]$Message
    )

    $message = Protect-ToolkitText $Message
    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = 'Clone verification failed.'
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
        return New-InstanceCloneFailure -Journal $Journal -Message 'The clone manager must be MuMuManager.exe.'
    }
    $managerItem = $null
    try {
        $managerItem = Get-Item -LiteralPath $manager -Force -ErrorAction Stop
    }
    catch {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The clone manager is unavailable.'
    }
    if ($managerItem -isnot [IO.FileInfo] -or ($managerItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The clone manager is not a regular file.'
    }
    if ($null -eq $Journal) {
        return New-InstanceCloneFailure -Journal $null -Message 'A clone journal is required.'
    }
    try {
        Assert-OperationJournal $Journal
    }
    catch {
        return New-InstanceCloneFailure -Journal $null -Message 'The clone journal is invalid.'
    }
    if ($null -eq $Instance -or $Instance -is [Array] -or $Instance -isnot [pscustomobject]) {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The source instance is invalid.'
    }
    $indexProperty = $Instance.PSObject.Properties['Index']
    if ($null -eq $indexProperty -or
        ($indexProperty.Value -isnot [string] -and $indexProperty.Value -isnot [int] -and $indexProperty.Value -isnot [long])) {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The source instance index is invalid.'
    }
    $sourceIndex = 0
    if (-not [int]::TryParse([string]$indexProperty.Value, [ref]$sourceIndex) -or $sourceIndex -lt 0) {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The source instance index is invalid.'
    }
    $nameProperty = $Instance.PSObject.Properties['Name']
    if ($null -eq $nameProperty -or $nameProperty.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($nameProperty.Value)) {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The source instance name is invalid.'
    }
    $sourceName = [string]$nameProperty.Value
    $installProperty = $Instance.PSObject.Properties['Install']
    if ($null -eq $installProperty -or $null -eq $installProperty.Value -or $installProperty.Value -isnot [pscustomobject]) {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The source instance install is invalid.'
    }
    $vmsProperty = $installProperty.Value.PSObject.Properties['VmsPath']
    if ($null -eq $vmsProperty -or $vmsProperty.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($vmsProperty.Value)) {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The source instance VMS path is invalid.'
    }
    $vmsPath = ConvertTo-ToolkitFullPath -Path $vmsProperty.Value
    if ($null -eq $vmsPath -or -not (Test-Path -LiteralPath $vmsPath -PathType Container)) {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The source instance VMS path is unavailable.'
    }
    $versionProperty = $Instance.PSObject.Properties['AndroidVersion']
    $sourceVersionValue = $null
    if ($null -ne $versionProperty) {
        $sourceVersionValue = $versionProperty.Value
    }
    $sourceVersion = ConvertTo-ToolkitAndroidVersion -Value $sourceVersionValue
    if ($null -eq $sourceVersion) {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The source instance Android version is invalid.'
    }

    $preRecords = @(Get-MuMuInstanceRecord -ManagerPath $manager -VersionArgument 'all' -Runner $Runner)
    if ($preRecords.Count -eq 0) {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The MuMu manager did not report instance state.'
    }
    $preIndexes = @{}
    $preNames = @()
    $sourceRecords = @()
    foreach ($preRecord in $preRecords) {
        $preIndexProperty = $preRecord.PSObject.Properties['index']
        $parsedIndex = 0
        if ($null -eq $preIndexProperty -or -not [int]::TryParse([string]$preIndexProperty.Value, [ref]$parsedIndex) -or $parsedIndex -lt 0) {
            return New-InstanceCloneFailure -Journal $Journal -Message 'The MuMu manager returned an invalid instance index.'
        }
        $preIndexes[[string]$parsedIndex] = $true
        $preNameProperty = $preRecord.PSObject.Properties['name']
        $preNames += if ($null -eq $preNameProperty -or $preNameProperty.Value -isnot [string]) { '' } else { [string]$preNameProperty.Value }
        if ($parsedIndex -eq $sourceIndex) {
            $sourceRecords += $preRecord
        }
    }
    if ($sourceRecords.Count -ne 1) {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The MuMu manager did not report exactly one source instance.'
    }

    $sourceRunning = Get-MuMuInstanceRunningState -Record $sourceRecords[0]
    if ($null -eq $sourceRunning) {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The source instance running state is unknown.'
    }
    if ($sourceRunning) {
        $shutdown = Invoke-CheckedProcess -FilePath $manager -ArgumentList @('control', '-v', [string]$sourceIndex, 'shutdown') -Runner $Runner
        if ($null -eq $shutdown -or $shutdown.ExitCode -ne 0) {
            return New-InstanceCloneFailure -Journal $Journal -Message 'The source instance did not accept a shutdown request.'
        }
    }
    if (-not (Wait-MuMuInstanceStopped -ManagerPath $manager -Index $sourceIndex -Runner $Runner)) {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The source instance did not reach a stable stopped state.'
    }

    $clone = Invoke-CheckedProcess -FilePath $manager -ArgumentList @('clone', '-v', [string]$sourceIndex, '-n', '1') -Runner $Runner
    if ($null -eq $clone -or $clone.ExitCode -ne 0) {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The MuMu manager clone command failed.'
    }

    $postRecords = @(Get-MuMuInstanceRecord -ManagerPath $manager -VersionArgument 'all' -Runner $Runner)
    $newRecords = @($postRecords | Where-Object { -not $preIndexes.ContainsKey([string]$_.index) })
    if ($newRecords.Count -ne 1) {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The MuMu manager did not report exactly one new instance after the clone.'
    }
    $cloneRecord = $newRecords[0]
    $cloneIndex = 0
    if (-not [int]::TryParse([string]$cloneRecord.index, [ref]$cloneIndex) -or $cloneIndex -lt 0) {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The clone instance index is invalid.'
    }
    $cloneNameProperty = $cloneRecord.PSObject.Properties['name']
    if ($null -eq $cloneNameProperty -or $cloneNameProperty.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($cloneNameProperty.Value)) {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The clone instance name is missing.'
    }
    $cloneName = [string]$cloneNameProperty.Value
    foreach ($preName in $preNames) {
        if ($preName -cne $sourceName -and $preName -ceq $cloneName) {
            return New-InstanceCloneFailure -Journal $Journal -Message 'The clone instance name collides with an existing instance.'
        }
    }

    $cloneRoot = Get-MuMuInstanceRootPath -VmsPath $vmsPath -Index $cloneIndex -ReportedVmsPath ([string](Get-ToolkitFirstProperty -InputObject $cloneRecord -PropertyNames @('vms_path', 'vmsPath')))
    if ($null -eq $cloneRoot) {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The clone instance VMS root is missing.'
    }
    $cloneVersion = ConvertTo-ToolkitAndroidVersion -Value (Get-ToolkitFirstProperty -InputObject $cloneRecord -PropertyNames @('android_version', 'androidVersion', 'system_version', 'systemVersion'))
    if ($null -eq $cloneVersion) {
        $cloneVersion = Get-ToolkitInstanceAndroidVersion -VmsPath $vmsPath -Index $cloneIndex
    }
    if ($null -eq $cloneVersion) {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The clone instance Android version could not be verified.'
    }
    if ($cloneVersion -cne $sourceVersion) {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The clone instance Android version does not match the source instance.'
    }

    $diskBytes = Measure-MuMuInstanceDiskBytes -InstanceRoot $cloneRoot
    if ($null -eq $diskBytes) {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The clone instance disk could not be measured.'
    }
    if ($diskBytes -le 0) {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The clone instance does not have a usable disk and does not boot.'
    }
    $cloneIsMain = ConvertTo-ToolkitBoolean -Value (Get-ToolkitFirstProperty -InputObject $cloneRecord -PropertyNames @('is_main'))
    if ($cloneIsMain -ne $false) {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The clone instance is not a bootable non-base instance.'
    }
    if ((Get-MuMuInstanceRunningState -Record $cloneRecord) -ne $false) {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The clone instance is not in a stopped boot-ready state.'
    }

    $cloneData = @{
        SourceIndex = $sourceIndex
        CloneIndex = $cloneIndex
        CloneName = $cloneName
        AndroidVersion = $cloneVersion
        DiskBytes = $diskBytes
        VmsPath = $cloneRoot
        BootReady = $true
    }
    $cloneMessage = "Clone verified at index $cloneIndex."
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message $cloneMessage -Data $cloneData
    }
    catch {
        return New-InstanceCloneFailure -Journal $Journal -Message 'The verified clone could not be journaled.'
    }
    return Get-ToolkitResult -Status 'Success' -Message $cloneMessage -Data $cloneData
}

if (-not [string]::IsNullOrWhiteSpace($ChildAction)) {
    Invoke-ToolkitElevatedChild -Payload $ChildAction
}
