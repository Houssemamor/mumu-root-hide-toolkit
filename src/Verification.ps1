if (-not (Test-Path variable:script:ToolkitBootPollAttempts)) {
    $script:ToolkitBootPollAttempts = 30
}
if (-not (Test-Path variable:script:ToolkitBootPollDelaySeconds)) {
    $script:ToolkitBootPollDelaySeconds = 3
}
# A cold boot is bounded by wall clock, not by attempts multiplied by a retried probe. The poll is the
# retry, so the probe itself is not retried, and the whole poll stops at this budget instead of running
# 30 probes that each carry the full transport bound.
if (-not (Test-Path variable:script:ToolkitBootPollBudgetSeconds)) {
    $script:ToolkitBootPollBudgetSeconds = 600
}
if (-not (Test-Path variable:script:ToolkitCampaignRestorePointFile)) {
    $script:ToolkitCampaignRestorePointFile = 'restore-point.json'
}

function Invoke-ToolkitManagerAdb {
    param(
        [string]$ManagerPath,
        [int]$InstanceIndex,
        [Parameter(Mandatory = $true)]
        [string]$Command,
        [scriptblock]$Runner = $null,
        [switch]$NoRetry
    )

    $invoke = {
        Invoke-CheckedProcess -FilePath $ManagerPath -ArgumentList @('adb', '-v', ([string]$InstanceIndex), '-c', $Command) -Runner $Runner
    }
    # A guest command is retried only when the toolkit can see that the whole command changes nothing,
    # so a repeated install, push, move, or removal can never happen.
    if ($NoRetry -or -not (Test-ToolkitReadOnlyGuestCommand -Command $Command)) {
        return (& $invoke)
    }
    $retried = Invoke-ToolkitReadOnlyCall -Description ("The read-only guest command " + $Command) -Call $invoke
    if ([string]$retried.Status -cne 'Success') {
        # The transport contract of this helper is a call object, so an exhausted retry is still
        # reported as the transport failure it is, with the recoverable reason in its text.
        return [pscustomobject]@{
            ExitCode = -1
            Text = $retried.Message
        }
    }
    return $retried.Data
}

function Get-ToolkitInstanceSettings {
    param(
        [string]$ManagerPath,
        [int]$Index,
        [string[]]$Keys,
        [scriptblock]$Runner = $null
    )

    $manager = ConvertTo-ToolkitFullPath -Path $ManagerPath
    if ($null -eq $manager -or $Index -lt 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The instance setting query is invalid.' -Data (@{ Code = 'MANAGER_UNAVAILABLE' })
    }
    $keyList = @()
    foreach ($key in @($Keys)) {
        if ($key -isnot [string] -or $key -notmatch '^[a-z][a-z0-9_]*$') {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'The instance setting query key is invalid.' -Data (@{ Code = 'SETTING_KEY_INVALID' })
        }
        $keyList += $key
    }
    if ($keyList.Count -eq 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The instance setting query key is invalid.' -Data (@{ Code = 'SETTING_KEY_INVALID' })
    }

    $argumentList = @('setting', '-v', ([string]$Index))
    foreach ($key in $keyList) {
        $argumentList += @('-k', $key)
    }
    $query = Invoke-ToolkitReadOnlyCall -Description 'The MuMu manager instance setting query' -Call {
        Invoke-CheckedProcess -FilePath $manager -ArgumentList $argumentList -Runner $Runner
    }
    if ([string]$query.Status -cne 'Success') {
        return $query
    }
    $call = $query.Data
    if ($null -eq $call -or $call.ExitCode -ne 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The instance settings could not be read.' -Data (@{ Code = 'SETTING_QUERY_FAILED' })
    }
    $parsed = $null
    try {
        $parsed = ([string]$call.Text) | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The instance settings could not be read.' -Data (@{ Code = 'SETTING_QUERY_FAILED' })
    }
    if ($null -eq $parsed -or $parsed -is [string] -or $parsed -is [ValueType]) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The instance settings could not be read.' -Data (@{ Code = 'SETTING_QUERY_FAILED' })
    }

    $values = @{}
    foreach ($key in $keyList) {
        $property = $parsed.PSObject.Properties[$key]
        if ($null -eq $property) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'The instance settings could not be read.' -Data (@{ Code = 'SETTING_QUERY_FAILED' })
        }
        $value = ConvertTo-ToolkitBoolean -Value $property.Value
        if ($null -eq $value) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'The instance settings could not be read.' -Data (@{ Code = 'SETTING_QUERY_FAILED' })
        }
        $values[$key] = $value
    }
    return Get-ToolkitResult -Status 'Success' -Message 'The instance settings were read.' -Data $values
}

# The poll answers BOOTED or names the bound that ended it, because a timeout message that always names the
# attempt count is false whenever the wall-clock budget ended the wait first.
function Wait-ToolkitBootCompleted {
    param(
        [string]$ManagerPath,
        [int]$InstanceIndex,
        [scriptblock]$Runner = $null
    )

    $budgetBound = "the $($script:ToolkitBootPollBudgetSeconds) second wall-clock budget"
    $attemptBound = "the $($script:ToolkitBootPollAttempts) attempt ceiling"
    $budgetDeadline = [DateTime]::UtcNow.AddSeconds($script:ToolkitBootPollBudgetSeconds)
    for ($attempt = 1; $attempt -le $script:ToolkitBootPollAttempts; $attempt++) {
        if ([DateTime]::UtcNow -ge $budgetDeadline) {
            return [pscustomobject]@{ Code = 'BUDGET'; Bound = $budgetBound }
        }
        # This probe is the poll's own retry, so it is not retried inside one attempt: that would
        # multiply the process bound by the attempt count instead of bounding the poll.
        $probe = Invoke-ToolkitManagerAdb -ManagerPath $ManagerPath -InstanceIndex $InstanceIndex -Command 'shell getprop sys.boot_completed' -Runner $Runner -NoRetry
        if ($null -ne $probe -and $probe.ExitCode -eq 0 -and ([string]$probe.Text).Trim() -ceq '1') {
            return [pscustomobject]@{ Code = 'BOOTED'; Bound = '' }
        }
        if ($attempt -lt $script:ToolkitBootPollAttempts -and [DateTime]::UtcNow -lt $budgetDeadline) {
            Start-Sleep -Seconds $script:ToolkitBootPollDelaySeconds
        }
    }
    return [pscustomobject]@{ Code = 'ATTEMPTS'; Bound = $attemptBound }
}

function Get-ToolkitRootSetting {
    param(
        [string]$ManagerPath,
        [int]$Index,
        [scriptblock]$Runner = $null
    )

    $manager = ConvertTo-ToolkitFullPath -Path $ManagerPath
    if ($null -eq $manager -or $Index -lt 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The vendor root setting manager is invalid.' -Data (@{ Code = 'MANAGER_UNAVAILABLE' })
    }

    $query = Invoke-ToolkitReadOnlyCall -Description 'The MuMu manager root setting query' -Call {
        Invoke-CheckedProcess -FilePath $manager -ArgumentList @('setting', '-v', ([string]$Index), '-k', 'root_permission') -Runner $Runner
    }
    if ([string]$query.Status -cne 'Success') {
        return $query
    }
    $result = $query.Data
    if ($null -eq $result -or $result.ExitCode -ne 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The MuMu manager did not report the vendor root setting.' -Data (@{ Code = 'MANAGER_FAILED' })
    }
    $text = [string]$result.Text
    if ([string]::IsNullOrWhiteSpace($text)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The vendor root setting response is empty.' -Data (@{ Code = 'MANAGER_JSON_INVALID' })
    }
    try {
        $parsed = $text | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The vendor root setting response is not valid JSON.' -Data (@{ Code = 'MANAGER_JSON_INVALID' })
    }
    if ($null -eq $parsed -or $parsed -is [string] -or $parsed -is [ValueType]) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The vendor root setting response has an unsupported shape.' -Data (@{ Code = 'SHAPE_UNSUPPORTED' })
    }
    if ($parsed -is [Array]) {
        $records = @($parsed)
        if ($records.Count -ne 1) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'The vendor root setting response does not describe exactly one instance.' -Data (@{ Code = 'SHAPE_UNSUPPORTED' })
        }
        $record = $records[0]
    }
    else {
        $record = $parsed
    }
    if ($null -eq $record -or $record -isnot [pscustomobject]) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The vendor root setting response has an unsupported shape.' -Data (@{ Code = 'SHAPE_UNSUPPORTED' })
    }

    $errorCode = Get-ToolkitFirstProperty -InputObject $record -PropertyNames @('error_code', 'errcode')
    if ($null -ne $errorCode -and [string]$errorCode -notin @('0', 'False', 'false')) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The MuMu manager reported an error for the vendor root setting.' -Data (@{ Code = 'MANAGER_ERROR' })
    }
    $indexProperty = $record.PSObject.Properties['index']
    if ($null -ne $indexProperty) {
        $reportedIndex = 0
        if (-not [int]::TryParse([string]$indexProperty.Value, [ref]$reportedIndex) -or $reportedIndex -ne $Index) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'The vendor root setting describes a different instance.' -Data (@{ Code = 'INDEX_MISMATCH' })
        }
    }

    $reportedValue = Get-ToolkitFirstProperty -InputObject $record -PropertyNames @('root_permission', 'rootPermission', 'root_setting', 'rootSetting', 'value')
    if ($null -eq $reportedValue) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The vendor root setting response carries no supported root setting field.' -Data (@{ Code = 'SHAPE_UNSUPPORTED' })
    }
    $value = ConvertTo-ToolkitBoolean -Value $reportedValue
    if ($null -eq $value) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The vendor root setting value is not a supported boolean.' -Data (@{ Code = 'VALUE_INVALID' })
    }
    return Get-ToolkitResult -Status 'Success' -Message 'The vendor root setting was read.' -Data (@{ Code = 'OK'; Index = $Index; Value = [bool]$value })
}

function Get-ToolkitPackageVersion {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Text,
        [string]$PackageName
    )

    if ([string]::IsNullOrWhiteSpace($Text) -or [string]::IsNullOrWhiteSpace($PackageName)) {
        return $null
    }

    $headerPattern = '(?m)^\s*Package \[' + [regex]::Escape($PackageName) + '\](?=[\s(:])'
    $headerMatch = [regex]::Match($Text, $headerPattern)
    if (-not $headerMatch.Success) {
        return $null
    }

    $nextHeaderRegex = New-Object Text.RegularExpressions.Regex '(?m)^\s*Package \['
    $nextHeader = $nextHeaderRegex.Match($Text, $headerMatch.Index + $headerMatch.Length)
    $blockEnd = if ($nextHeader.Success) { $nextHeader.Index } else { $Text.Length }
    $block = $Text.Substring($headerMatch.Index, $blockEnd - $headerMatch.Index)

    $nameMatch = [regex]::Match($block, '(?m)^\s*versionName=(\S+)')
    $codeMatch = [regex]::Match($block, '(?m)^\s*versionCode=(\d+)\b')
    return @{
        VersionName = if ($nameMatch.Success) { $nameMatch.Groups[1].Value } else { '' }
        VersionCode = if ($codeMatch.Success) { $codeMatch.Groups[1].Value } else { '' }
    }
}

function Get-ToolkitRootShellStatus {
    param(
        [AllowNull()]
        [object]$Call
    )

    if ($null -eq $Call -or $Call.ExitCode -eq -1) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The root shell query could not be executed.' -Data (@{ Code = 'ADB_FAILED' })
    }
    if ($Call.ExitCode -eq 0 -and ([string]$Call.Text) -match '(?m)uid=0\(') {
        return Get-ToolkitResult -Status 'Success' -Message 'The root shell returned a root identity.' -Data (@{ Code = 'OK'; RootShell = $true })
    }
    # The guest says the binary is not there either with exit 127 or in the shell's own words, and this
    # build normalises the exit code, so the wording is the only reliable signal. Without it a missing su
    # was classified as a denial, which is a different claim about the guest, and it also stopped the
    # fallback probe from ever running on exactly the guests that need it.
    #
    # Only the unambiguous phrasings count. "Permission denied" and a non-root uid are denials and are
    # deliberately not matched, so a refusal is never retried into a success by a fallback that would
    # answer.
    if ($Call.ExitCode -eq 127 -or ([string]$Call.Text) -match '(?i)(no such file or directory|inaccessible or not found)') {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The root shell binary is not available in the guest, so the root state is unknown and no denial can be concluded.' -Data (@{ Code = 'ROOT_UNAVAILABLE' })
    }
    if ($Call.ExitCode -ne 0 -and [string]::IsNullOrWhiteSpace([string]$Call.Text)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The root shell query returned no guest output, so a guest refusal cannot be concluded.' -Data (@{ Code = 'ADB_FAILED' })
    }
    return Get-ToolkitResult -Status 'CriticalError' -Message 'The root shell did not return a root identity.' -Data (@{ Code = 'ROOT_DENIED' })
}

# The canonical probe is "su -c id". A guest can carry a working Magisk root whose su is not on the PATH,
# where only "magisk su" resolves and a single probe reports a live root as absent. The fallbacks are
# tried only when the canonical probe says the binary is missing, never when it answers without a root
# identity, because that answer is a denial and must not be retried into a success.
$script:ToolkitRootShellProbes = @('shell su -c id', 'shell magisk su -c id', 'shell /system/bin/magisk su -c id')

# Runs the probe sequence and classifies it. The canonical probe is the only verdict that stands on its
# own: a fallback can promote the result to a success by proving a root, but it can never replace the
# canonical failure with one of its own. A guest without su returns "not found" from every probe in a
# slightly different shape, and letting the last fallback's wording decide produced ROOT_DENIED for a
# guest that simply has no su, which is a different claim.
function Invoke-ToolkitRootShellProbe {
    param(
        [string]$ManagerPath,
        [int]$InstanceIndex,
        [scriptblock]$Runner = $null
    )

    $canonicalCommand = $script:ToolkitRootShellProbes[0]
    $canonicalCall = Invoke-ToolkitManagerAdb -ManagerPath $ManagerPath -InstanceIndex $InstanceIndex -Command $canonicalCommand -Runner $Runner
    $canonicalStatus = Get-ToolkitRootShellStatus -Call $canonicalCall
    if ([string]$canonicalStatus.Status -ceq 'Success') {
        return $canonicalStatus
    }
    if ([string](Get-ToolkitRecordValue -Record $canonicalStatus.Data -PropertyNames @('Code')) -cne 'ROOT_UNAVAILABLE') {
        return $canonicalStatus
    }
    foreach ($command in @($script:ToolkitRootShellProbes | Select-Object -Skip 1)) {
        $call = Invoke-ToolkitManagerAdb -ManagerPath $ManagerPath -InstanceIndex $InstanceIndex -Command $command -Runner $Runner
        $status = Get-ToolkitRootShellStatus -Call $call
        if ([string]$status.Status -ceq 'Success') {
            # A fallback answered, so the guest does have a root and the canonical probe simply could not
            # see it. The probe that answered is named so the result is auditable rather than a bare pass.
            return Get-ToolkitResult -Status 'Success' -Message ('The root shell returned a root identity through ' + $command + ', which is the fallback probe. The canonical probe reported no su on the PATH.') -Data (@{ Code = 'OK'; RootShell = $true; Probe = $command })
        }
    }
    return $canonicalStatus
}

function New-ToolkitRootFailure {
    param(
        [object]$Journal,
        [string]$Message,
        [object]$Data = $null
    )

    $message = Protect-ToolkitText $Message
    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = 'The root workflow failed.'
    }
    $result = Get-ToolkitResult -Status 'CriticalError' -Message $message -Data $Data
    $journalState = $null
    if ($null -ne $Journal -and $null -ne $Journal.PSObject -and $null -ne $Journal.PSObject.Properties['State']) {
        $journalState = $Journal.State
    }
    if ($journalState -ne 'Running') {
        return $result
    }
    try {
        Write-JournalEvent -Journal $Journal -Level 'Error' -Message $message -Data $Data
        Fail-OperationJournal -Journal $Journal -Result $result
    }
    catch {
        return Get-ToolkitResult -Status 'CriticalError' -Message ($message + ' The failure could not be journaled.') -Data $Data
    }
    return $result
}

function Get-ToolkitRecordValue {
    param(
        [AllowNull()]
        [object]$Record,
        [string[]]$PropertyNames
    )

    if ($null -eq $Record) {
        return $null
    }
    if ($Record -is [Collections.IDictionary]) {
        foreach ($propertyName in $PropertyNames) {
            if ($Record.Contains($propertyName)) {
                # Returning a one-element collection unrolls it into the element, so an array is wrapped
                # to keep a single package name distinguishable from a one-element package list.
                $value = $Record[$propertyName]
                if ($value -is [Array]) {
                    return , $value
                }
                return $value
            }
        }
        return $null
    }
    foreach ($propertyName in $PropertyNames) {
        $property = $Record.PSObject.Properties[$propertyName]
        if ($null -ne $property) {
            $value = $property.Value
            if ($value -is [Array]) {
                return , $value
            }
            return $value
        }
    }
    return $null
}

function Get-ToolkitJournalRecords {
    param([string]$StateRoot)

    $records = @()
    if ([string]::IsNullOrWhiteSpace($StateRoot)) {
        return $records
    }
    $journalRoot = ConvertTo-ToolkitFullPath -Path ([IO.Path]::Combine($StateRoot, 'journals'))
    if ($null -eq $journalRoot -or -not [IO.Directory]::Exists($journalRoot)) {
        return $records
    }
    foreach ($path in @([IO.Directory]::GetFiles($journalRoot, '*.json', [IO.SearchOption]::TopDirectoryOnly))) {
        $record = $null
        try {
            $record = Get-OperationJournal -Path $path
        }
        catch {
            $record = $null
        }
        if ($null -ne $record) {
            $records += $record
        }
    }
    return @($records | Sort-Object -Property StartedAt -Descending)
}

function Get-ToolkitVerifiedClone {
    param(
        [string]$StateRoot,
        [object]$Install,
        [int]$Index = -1
    )

    if ($null -eq $Install -or $Install -is [Array] -or $Install -isnot [pscustomobject]) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'A verified instance clone record is required, and the selected installation is invalid.' -Data (@{ Code = 'CLONE_RECORD_MISSING' })
    }
    $installRootProperty = $Install.PSObject.Properties['InstallRoot']
    $installRoot = $null
    if ($null -ne $installRootProperty -and $installRootProperty.Value -is [string]) {
        $installRoot = ConvertTo-ToolkitFullPath -Path $installRootProperty.Value
    }
    if ($null -eq $installRoot -or $Index -lt 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'A verified instance clone record is required, and the selected installation or instance is invalid. Complete the matching Android 12 or Android 15 root action first.' -Data (@{ Code = 'CLONE_RECORD_MISSING' })
    }

    foreach ($record in @(Get-ToolkitJournalRecords -StateRoot $StateRoot)) {
        if ([string]$record.Operation -cnotmatch '^(Root12|Root15)$') {
            continue
        }
        # "The operation completed" and "the clone was verified" are different facts, and conflating them
        # made a run that verified its clone and then failed at a later check refuse to resume, which cost a
        # full instance of disk for a retry of something that had already been set up. A failed journal is
        # therefore accepted only when it carries the structured checkpoint where the clone was verified, so
        # a clone that failed while being made is still refused.
        $cloneWasVerified = ([string]$record.State -ceq 'Completed')
        if (-not $cloneWasVerified) {
            $verifiedCheckpoint = $null
            foreach ($checkpoint in @($record.Checkpoints)) {
                $checkpointData = Get-ToolkitRecordValue -Record $checkpoint -PropertyNames @('Data')
                if ((Get-ToolkitRecordValue -Record $checkpointData -PropertyNames @('StaticReady')) -eq $true -and
                    $null -ne (Get-ToolkitRecordValue -Record $checkpointData -PropertyNames @('CloneIndex'))) {
                    $verifiedCheckpoint = $checkpointData
                    break
                }
            }
            if ($null -eq $verifiedCheckpoint) {
                continue
            }
        }
        if ($null -eq $record.Result) {
            continue
        }
        $data = Get-ToolkitRecordValue -Record $record.Result -PropertyNames @('Data')
        $cloneIndex = Get-ToolkitRecordValue -Record $data -PropertyNames @('CloneIndex')
        $cloneName = Get-ToolkitRecordValue -Record $data -PropertyNames @('CloneName')
        $sourceIndex = Get-ToolkitRecordValue -Record $data -PropertyNames @('SourceIndex')

        if (-not $cloneWasVerified) {
            # A failed journal's result describes the failure, not the clone, so the payload is rebuilt from
            # the verified-clone checkpoint. Returning Success with the failure's own data would name a
            # clone in the message and then report no clone index at all.
            $cloneIndex = Get-ToolkitRecordValue -Record $verifiedCheckpoint -PropertyNames @('CloneIndex')
            $cloneName = Get-ToolkitRecordValue -Record $verifiedCheckpoint -PropertyNames @('CloneName')
            $sourceIndex = Get-ToolkitRecordValue -Record $verifiedCheckpoint -PropertyNames @('SourceIndex')
            $data = [ordered]@{
                Code             = 'OK'
                Step             = 'resume'
                SourceIndex      = $sourceIndex
                CloneIndex       = $cloneIndex
                CloneName        = [string]$cloneName
                AndroidVersion   = Get-ToolkitRecordValue -Record $verifiedCheckpoint -PropertyNames @('AndroidVersion')
                RecoveredAs      = 'verified-clone-checkpoint'
            }
        }
        if ($null -eq $cloneIndex -or [string]::IsNullOrWhiteSpace([string]$cloneName)) {
            continue
        }
        $parsedCloneIndex = 0
        if (-not [int]::TryParse([string]$cloneIndex, [ref]$parsedCloneIndex) -or $parsedCloneIndex -lt 0) {
            continue
        }
        if ($null -ne $sourceIndex) {
            $parsedSourceIndex = 0
            if (-not [int]::TryParse([string]$sourceIndex, [ref]$parsedSourceIndex) -or $parsedSourceIndex -ne $Index) {
                continue
            }
        }
        $recordInstallRoot = $null
        $recordedInstall = Get-ToolkitRecordValue -Record $record.Instance -PropertyNames @('Install')
        $recordedRoot = Get-ToolkitRecordValue -Record $recordedInstall -PropertyNames @('InstallRoot')
        if ($recordedRoot -is [string]) {
            $recordInstallRoot = ConvertTo-ToolkitFullPath -Path $recordedRoot
        }
        if ($null -eq $recordInstallRoot -or -not $recordInstallRoot.Equals($installRoot, [StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        return Get-ToolkitResult -Status 'Success' -Message "A verified instance clone record for the instance at index $Index was recovered at index $parsedCloneIndex." -Data $data
    }

    return Get-ToolkitResult -Status 'CriticalError' -Message "No verified instance clone record for the instance at index $Index was found in the operation journal. The selected instance is never changed without one, so the change was refused. Complete the matching Android 12 or Android 15 root action first." -Data (@{ Code = 'CLONE_RECORD_MISSING' })
}

function Get-ToolkitSharedValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Default = ''
    )

    $variable = Get-Variable -Name $Name -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $variable) {
        return $Default
    }
    $value = $variable.Value
    if ($null -eq $value -or ($value -isnot [string] -and $value -isnot [int] -and $value -isnot [long])) {
        return $Default
    }
    return [string]$value
}

function Test-ToolkitCommandAvailable {
    param([Parameter(Mandatory = $true)][string]$Name)

    return ($null -ne (Get-Command $Name -ErrorAction SilentlyContinue))
}

function Get-ToolkitCampaignScopeKey {
    param([object]$Install)

    $installRoot = $null
    $reported = Get-ToolkitRecordValue -Record $Install -PropertyNames @('InstallRoot')
    if ($reported -is [string]) {
        $installRoot = ConvertTo-ToolkitFullPath -Path $reported
    }
    if ($null -eq $installRoot) {
        return ''
    }
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($installRoot.ToUpperInvariant())
        $hash = $sha.ComputeHash($bytes)
    }
    finally {
        $sha.Dispose()
    }
    return (($hash | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 16)
}

function Get-ToolkitCampaignRestorePoints {
    param(
        [string]$StateRoot,
        [object]$Install
    )

    $records = @()
    $scope = Get-ToolkitCampaignScopeKey -Install $Install
    if ([string]::IsNullOrWhiteSpace($StateRoot) -or [string]::IsNullOrWhiteSpace($scope)) {
        return $records
    }
    $parent = [IO.Path]::Combine([IO.Path]::Combine($StateRoot, 'campaigns'), $scope)
    if (-not [IO.Directory]::Exists($parent)) {
        return $records
    }
    $roots = @()
    foreach ($directory in @([IO.Directory]::GetDirectories($parent))) {
        $manifestPath = [IO.Path]::Combine($directory, [string]$script:ToolkitCampaignRestorePointFile)
        if (-not [IO.File]::Exists($manifestPath)) {
            continue
        }
        $written = [DateTime]::MinValue
        try {
            $written = [IO.File]::GetLastWriteTimeUtc($manifestPath)
        }
        catch {
            $written = [DateTime]::MinValue
        }
        $roots += [pscustomobject]@{
            BackupRoot = $directory
            ManifestPath = $manifestPath
            Written = $written
        }
    }
    return @($roots | Sort-Object -Property Written -Descending)
}

function Get-ToolkitVirtualizationState {
    try {
        $computer = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        if ($null -eq $computer -or $null -eq $computer.PSObject.Properties['HypervisorPresent']) {
            return 'Unknown'
        }
        $present = ConvertTo-ToolkitBoolean -Value $computer.HypervisorPresent
        if ($null -eq $present) {
            return 'Unknown'
        }
        if ([bool]$present) {
            return 'Enabled'
        }
        return 'Disabled'
    }
    catch {
        return 'Unknown'
    }
}

function Get-ToolkitGuestState {
    param(
        [string]$ManagerPath,
        [int]$InstanceIndex,
        [string]$AndroidVersion,
        [scriptblock]$Runner = $null
    )

    $guest = [ordered]@{
        Root = 'Unknown'
        Code = 'GUEST_UNREAD'
        RootPermission = $null
        Kitsune = ''
        KernelSU = ''
        DaemonCount = -1
        # A guest that answered answers true or false. A package list the guest never answered leaves the
        # field absent, because an absence claim has to be a claim the guest made.
        HmaInstalled = $null
        VectorModuleInstalled = $null
        Failure = ''
    }
    if ([string]::IsNullOrWhiteSpace($ManagerPath) -or $InstanceIndex -lt 0) {
        $guest['Failure'] = 'The guest state was not read because no manager or instance is selected.'
        return $guest
    }

    $checks = $null
    if ($AndroidVersion -ceq '12.0') {
        if (-not (Test-ToolkitCommandAvailable -Name 'Test-Android12Root')) {
            $guest['Failure'] = 'The Android 12 verification command is not loaded, so the guest root state is unread.'
            return $guest
        }
        $checks = Test-Android12Root -ManagerPath $ManagerPath -InstanceIndex $InstanceIndex -Runner $Runner
        if ($null -ne $checks -and $null -ne $checks.Data) {
            $guest['Kitsune'] = [string](Get-ToolkitRecordValue -Record $checks.Data -PropertyNames @('VersionName'))
            # A count the guest never produced keeps the report's own unread marker, because casting a
            # missing count to zero would be a claim that no root daemon is running.
            $daemonCount = Get-ToolkitRecordValue -Record $checks.Data -PropertyNames @('DaemonCount')
            if ($null -ne $daemonCount -and [int]$daemonCount -ge 0) {
                $guest['DaemonCount'] = [int]$daemonCount
            }
        }
    }
    elseif ($AndroidVersion -ceq '15.0') {
        if (-not (Test-ToolkitCommandAvailable -Name 'Test-Android15Root')) {
            $guest['Failure'] = 'The Android 15 verification command is not loaded, so the guest root state is unread.'
            return $guest
        }
        $checks = Test-Android15Root -ManagerPath $ManagerPath -InstanceIndex $InstanceIndex -Runner $Runner
        if ($null -ne $checks -and $null -ne $checks.Data) {
            # A vendor root setting the check never read keeps the report's own unread marker, because
            # casting a missing value to false would claim the vendor root is disabled.
            $rootPermission = Get-ToolkitRecordValue -Record $checks.Data -PropertyNames @('RootPermission')
            if ($null -ne $rootPermission) {
                $guest['RootPermission'] = [bool]$rootPermission
            }
            $guest['KernelSU'] = [string](Get-ToolkitRecordValue -Record $checks.Data -PropertyNames @('KernelSUVersion'))
        }
    }
    else {
        $guest['Root'] = 'Unsupported'
        $guest['Code'] = 'ANDROID_VERSION_UNSUPPORTED'
        $guest['Failure'] = "The root state of Android version $AndroidVersion is not read because only Android 12 and Android 15 instances are supported."
        return $guest
    }

    if ($null -ne $checks -and [string]$checks.Status -ceq 'Success') {
        $guest['Root'] = 'Verified'
        $guest['Code'] = 'OK'
    }
    else {
        $guest['Root'] = 'Unverified'
        $guest['Code'] = 'GUEST_UNREAD'
        if ($null -ne $checks) {
            $guest['Code'] = [string](Get-ToolkitRecordValue -Record $checks.Data -PropertyNames @('Code'))
            $guest['Failure'] = [string]$checks.Message
        }
        else {
            $guest['Failure'] = 'The guest root state could not be read.'
        }
    }

    $packages = $null
    if (Test-ToolkitCommandAvailable -Name 'Get-ConcealmentPackageList') {
        $packages = Get-ConcealmentPackageList -ManagerPath $ManagerPath -InstanceIndex $InstanceIndex -Runner $Runner
    }
    if ($null -eq $packages) {
        $guest['Failure'] = $guest['Failure'] + ' The concealment package list command is not loaded, so the HMA package state is unread.'
    }
    elseif ([string]$packages.Status -ceq 'Success') {
        $hmaPackage = Get-ToolkitSharedValue -Name 'ConcealmentHmaPackage'
        $guest['HmaInstalled'] = @($packages.Data) -ccontains $hmaPackage
    }
    else {
        $guest['Failure'] = $guest['Failure'] + ' ' + [string]$packages.Message
    }
    $modulePath = Get-ToolkitSharedValue -Name 'ConcealmentVectorModulePath'
    $moduleCommand = ''
    if (-not [string]::IsNullOrWhiteSpace($modulePath)) {
        # The shared funnel is the only place a su -c request is built, so the report cannot emit the double-quoted form.
        $moduleRequest = New-ToolkitGuestCommand -Command ('ls ' + $modulePath)
        if ($moduleRequest.Status -ceq 'Success') {
            $moduleCommand = [string]$moduleRequest.Data
        }
        else {
            $guest['Failure'] = $guest['Failure'] + ' ' + $moduleRequest.Message
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($moduleCommand) -and (Test-ToolkitCommandAvailable -Name 'Invoke-ToolkitManagerAdb')) {
        $module = Invoke-ToolkitManagerAdb -ManagerPath $ManagerPath -InstanceIndex $InstanceIndex -Command $moduleCommand -Runner $Runner
        if ($null -ne $module -and $module.ExitCode -eq 0) {
            $guest['VectorModuleInstalled'] = $true
            # A module directory is not a loaded module. The root implementation skips a disabled module at
            # boot and leaves the directory in place, and the marker is listed by this same directory probe,
            # so one read answers both "is it there" and "will it load". A separate probe for the marker
            # would be a second command that neither a guest nor a fixture can tell from the first.
            $moduleEntries = @(([string]$module.Text) -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            if ($moduleEntries -ccontains 'disable') {
                $guest['Failure'] = $guest['Failure'] + ' The Vector module directory is present but it carries the disable marker, so the root implementation skips it at boot and nothing it would hide is hidden. Enable the module in the root implementation and boot the clone.'
            }
        }
        elseif ($null -ne $module -and $module.ExitCode -eq -1) {
            # An unread probe is not an absent module, so the field is left undetected and the reason is
            # reported instead of claiming a false.
            $guest['VectorModuleInstalled'] = $null
            $guest['Failure'] = $guest['Failure'] + " The Vector module at $modulePath could not be read: $([string]$module.Text)"
        }
        elseif ($null -ne $module -and ([string]$module.Text) -match '(?i)no such file or directory' -and
            ([string]$module.Text) -match [regex]::Escape([string]$modulePath)) {
            # Only the guest saying the probed path is not there is an absence. The missing path has to be
            # named in the answer, because on a clone with no su at all the same words describe the command
            # word rather than the module, and reading that as an absence reports a module that is installed
            # as not installed.
            $guest['VectorModuleInstalled'] = $false
        }
        elseif ($null -ne $module) {
            $guest['VectorModuleInstalled'] = $null
            $guest['Failure'] = $guest['Failure'] + " The guest did not say whether $modulePath exists, so the Vector module state is unknown: $([string]$module.Text)"
        }
    }
    return $guest
}

function Get-ToolkitReport {
    param(
        [object]$Install,
        [object]$Instance,
        [object]$Journal,
        [string]$StateRoot = '',
        [scriptblock]$Runner = $null
    )

    $failures = @()
    $guestDefaults = [ordered]@{
        Root = 'Unknown'
        Code = 'GUEST_UNREAD'
        RootPermission = $null
        Kitsune = ''
        KernelSU = ''
        DaemonCount = -1
        HmaInstalled = $null
        VectorModuleInstalled = $null
        Failure = ''
    }
    $report = [ordered]@{
        Install = [ordered]@{
            Edition = 'Unknown'
            InstallRoot = ''
            VmsPath = ''
            ManagerPath = ''
            Source = 'Unknown'
        }
        ManagerVersion = 'Unknown'
        Instances = @()
        Instance = $null
        Virtualization = 'Unknown'
        Guest = $guestDefaults
        Ads = [ordered]@{
            CampaignFiles = @()
            RestorePoint = 'Unknown'
        }
        Backups = [ordered]@{
            CloneIndex = -1
            CloneName = ''
        }
        Concealment = [ordered]@{
            Target = ''
            Status = 'NotVerified'
            Code = 'CLONE_UNVERIFIED'
            Packages = @()
            InScope = @()
            OutOfScope = @()
            TemplateFound = $false
            IsWhitelist = $false
            HmaConfigVersion = -1
            KernelSUInstalled = $false
            AllowlistPresent = $false
            Message = 'No verified clone record is available for this instance, so no concealment evidence was collected.'
        }
        JournalState = 'None'
        JournalOperation = ''
        JournalId = ''
        Failures = @()
        Mutated = $false
    }

    if ($null -ne $Journal -and $null -ne $Journal.PSObject.Properties['State']) {
        $report['JournalState'] = [string]$Journal.State
        $report['JournalOperation'] = [string](Get-ToolkitRecordValue -Record $Journal -PropertyNames @('Operation'))
        $report['JournalId'] = [string](Get-ToolkitRecordValue -Record $Journal -PropertyNames @('Id'))
    }
    elseif (-not [string]::IsNullOrWhiteSpace($StateRoot)) {
        $latest = @(Get-ToolkitJournalRecords -StateRoot $StateRoot)
        if ($latest.Count -gt 0) {
            $report['JournalState'] = [string]$latest[0].State
            $report['JournalOperation'] = [string]$latest[0].Operation
            $report['JournalId'] = [string]$latest[0].Id
        }
    }

    if ($null -eq $Install -or $Install -is [Array] -or $Install -isnot [pscustomobject]) {
        $report['Failures'] = @('No installation was selected, so no installation or guest state was read.')
        return [pscustomobject]$report
    }

    $installRoot = $null
    foreach ($fieldName in @('Edition', 'InstallRoot', 'VmsPath', 'ManagerPath', 'Source')) {
        $value = ''
        $property = $Install.PSObject.Properties[$fieldName]
        if ($null -ne $property -and $property.Value -is [string]) {
            $value = [string]$property.Value
        }
        $report['Install'][$fieldName] = $value
        if ($fieldName -eq 'InstallRoot') {
            $installRoot = ConvertTo-ToolkitFullPath -Path $value
        }
    }

    $managerPath = [string]$report['Install']['ManagerPath']
    if ([IO.File]::Exists($managerPath)) {
        try {
            $managerItem = Get-Item -LiteralPath $managerPath -Force -ErrorAction Stop
            $managerVersion = [string]$managerItem.VersionInfo.ProductVersion
            if (-not [string]::IsNullOrWhiteSpace($managerVersion)) {
                $report['ManagerVersion'] = $managerVersion
            }
        }
        catch {
            $failures += 'The manager version could not be read.'
        }
    }
    else {
        $failures += 'The MuMu manager could not be located, so no manager version or instance state was read.'
    }

    if (-not [string]::IsNullOrWhiteSpace($managerPath)) {
        if (-not (Test-ToolkitCommandAvailable -Name 'Get-MuMuInstances')) {
            $failures += 'The instance discovery command is not loaded, so no instance state was read.'
        }
        else {
            $discovered = @(Get-MuMuInstances -Install $Install -ManagerPath $managerPath)
            if ($discovered.Count -eq 1 -and $null -ne $discovered[0].PSObject.Properties['Status']) {
                $failures += "The instance list could not be read. $($discovered[0].Message)"
            }
            else {
                $summaries = @()
                foreach ($record in $discovered) {
                    $summaries += [ordered]@{
                        Index = [int](Get-ToolkitRecordValue -Record $record -PropertyNames @('Index'))
                        Name = [string](Get-ToolkitRecordValue -Record $record -PropertyNames @('Name'))
                        AndroidVersion = [string](Get-ToolkitRecordValue -Record $record -PropertyNames @('AndroidVersion'))
                        Running = Get-ToolkitRecordValue -Record $record -PropertyNames @('Running')
                        RootSetting = Get-ToolkitRecordValue -Record $record -PropertyNames @('RootSetting')
                        Eligible = Get-ToolkitRecordValue -Record $record -PropertyNames @('Eligible')
                    }
                }
                $report['Instances'] = $summaries
            }
        }
    }

    $selectedIndex = -1
    if ($null -ne $Instance -and $null -ne $Instance.PSObject -and $null -ne $Instance.PSObject.Properties['Index']) {
        $parsedIndex = 0
        if ([int]::TryParse([string]$Instance.Index, [ref]$parsedIndex) -and $parsedIndex -ge 0) {
            $selectedIndex = $parsedIndex
        }
    }
    if ($selectedIndex -ge 0) {
        $selected = @(@($report['Instances']) | Where-Object { [int]$_.Index -eq $selectedIndex })
        if ($selected.Count -eq 0) {
            $failures += "The selected instance at index $selectedIndex is not reported by the MuMu manager."
        }
        else {
            $report['Instance'] = $selected[0]
            $guest = Get-ToolkitGuestState -ManagerPath $managerPath -InstanceIndex $selectedIndex -AndroidVersion ([string]$selected[0].AndroidVersion) -Runner $Runner
            $report['Guest'] = $guest
            if (-not [string]::IsNullOrWhiteSpace([string]$guest['Failure'])) {
                $failures += [string]$guest['Failure']
            }
            $clone = Get-ToolkitVerifiedClone -StateRoot $StateRoot -Install $Install -Index $selectedIndex
            if ([string]$clone.Status -ceq 'Success') {
                $report['Backups']['CloneIndex'] = [int]$clone.Data.CloneIndex
                $report['Backups']['CloneName'] = [string]$clone.Data.CloneName
                # Concealment only ever changes the verified clone, so its evidence is read there.
                if (Test-ToolkitCommandAvailable -Name 'Get-ConcealmentEvidence') {
                    $evidence = Get-ConcealmentEvidence -ManagerPath $managerPath -CloneIndex ([int]$clone.Data.CloneIndex) -Runner $Runner
                    $report['Concealment'] = $evidence
                    # A concealment evidence that is not verified is a failure of the report, so it is
                    # recorded with its code instead of being printed beside a clean failure list.
                    $evidenceStatus = [string](Get-ToolkitRecordValue -Record $evidence -PropertyNames @('Status'))
                    $evidenceCode = [string](Get-ToolkitRecordValue -Record $evidence -PropertyNames @('Code'))
                    $evidenceMessage = [string](Get-ToolkitRecordValue -Record $evidence -PropertyNames @('Message'))
                    if ($evidenceStatus -cne 'Success') {
                        $failures += "Concealment evidence on the verified clone is $evidenceCode, not a verified scope. $evidenceMessage"
                    }
                }
                else {
                    $failures += 'The concealment verification command is not loaded, so no concealment evidence was read.'
                }
            }
        }
    }

    $report['Virtualization'] = Get-ToolkitVirtualizationState

    if (-not (Test-ToolkitCommandAvailable -Name 'Get-MuMuCampaignPaths')) {
        $failures += 'The advertisement discovery command is not loaded, so no advertisement state was read.'
    }
    else {
        $campaign = Get-MuMuCampaignPaths -Install $Install
        if ([string]$campaign.Status -ceq 'Success') {
            $report['Ads']['CampaignFiles'] = @($campaign.Data)
        }
        else {
            $failures += [string]$campaign.Message
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($StateRoot)) {
        $report['Ads']['RestorePoint'] = if (@(Get-ToolkitCampaignRestorePoints -StateRoot $StateRoot -Install $Install).Count -gt 0) { 'Present' } else { 'Missing' }
    }
    if ($null -eq $installRoot) {
        $failures += 'The installation root could not be resolved.'
    }

    $report['Failures'] = $failures
    return [pscustomobject]$report
}
