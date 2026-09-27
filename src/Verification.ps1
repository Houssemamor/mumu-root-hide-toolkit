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

function Wait-ToolkitBootCompleted {
    param(
        [string]$ManagerPath,
        [int]$InstanceIndex,
        [scriptblock]$Runner = $null
    )

    $budgetDeadline = [DateTime]::UtcNow.AddSeconds($script:ToolkitBootPollBudgetSeconds)
    for ($attempt = 1; $attempt -le $script:ToolkitBootPollAttempts; $attempt++) {
        if ([DateTime]::UtcNow -ge $budgetDeadline) {
            return $false
        }
        # This probe is the poll's own retry, so it is not retried inside one attempt: that would
        # multiply the process bound by the attempt count instead of bounding the poll.
        $probe = Invoke-ToolkitManagerAdb -ManagerPath $ManagerPath -InstanceIndex $InstanceIndex -Command 'shell getprop sys.boot_completed' -Runner $Runner -NoRetry
        if ($null -ne $probe -and $probe.ExitCode -eq 0 -and ([string]$probe.Text).Trim() -ceq '1') {
            return $true
        }
        if ($attempt -lt $script:ToolkitBootPollAttempts -and [DateTime]::UtcNow -lt $budgetDeadline) {
            Start-Sleep -Seconds $script:ToolkitBootPollDelaySeconds
        }
    }
    return $false
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
    if ($Call.ExitCode -eq 127) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The root shell binary is not available in the guest, so the root state is unknown and no denial can be concluded.' -Data (@{ Code = 'ROOT_UNAVAILABLE' })
    }
    if ($Call.ExitCode -ne 0 -and [string]::IsNullOrWhiteSpace([string]$Call.Text)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The root shell query returned no guest output, so a guest refusal cannot be concluded.' -Data (@{ Code = 'ADB_FAILED' })
    }
    return Get-ToolkitResult -Status 'CriticalError' -Message 'The root shell did not return a root identity.' -Data (@{ Code = 'ROOT_DENIED' })
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
        if ([string]$record.Operation -cnotmatch '^(Root12|Root15)$' -or [string]$record.State -cne 'Completed') {
            continue
        }
        if ($null -eq $record.Result) {
            continue
        }
        $data = Get-ToolkitRecordValue -Record $record.Result -PropertyNames @('Data')
        $cloneIndex = Get-ToolkitRecordValue -Record $data -PropertyNames @('CloneIndex')
        $cloneName = Get-ToolkitRecordValue -Record $data -PropertyNames @('CloneName')
        $sourceIndex = Get-ToolkitRecordValue -Record $data -PropertyNames @('SourceIndex')
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
        HmaInstalled = $false
        VectorModuleInstalled = $false
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
            $guest['DaemonCount'] = [int](Get-ToolkitRecordValue -Record $checks.Data -PropertyNames @('DaemonCount'))
        }
    }
    elseif ($AndroidVersion -ceq '15.0') {
        if (-not (Test-ToolkitCommandAvailable -Name 'Test-Android15Root')) {
            $guest['Failure'] = 'The Android 15 verification command is not loaded, so the guest root state is unread.'
            return $guest
        }
        $checks = Test-Android15Root -ManagerPath $ManagerPath -InstanceIndex $InstanceIndex -Runner $Runner
        if ($null -ne $checks -and $null -ne $checks.Data) {
            $guest['RootPermission'] = [bool](Get-ToolkitRecordValue -Record $checks.Data -PropertyNames @('RootPermission'))
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
        }
        elseif ($null -ne $module -and $module.ExitCode -eq -1) {
            # An unread probe is not an absent module, so the field is left undetected and the reason is
            # reported instead of claiming a false.
            $guest['VectorModuleInstalled'] = $null
            $guest['Failure'] = $guest['Failure'] + " The Vector module at $modulePath could not be read: $([string]$module.Text)"
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
        HmaInstalled = $false
        VectorModuleInstalled = $false
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
