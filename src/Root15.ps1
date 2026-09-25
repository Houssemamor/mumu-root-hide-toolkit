$script:Root15KernelSUPackage = 'me.weishu.kernelsu'
$script:Root15KitsunePackage = 'io.github.huskydg.magisk'
$script:Root15FieldNames = @('RootPermission', 'KernelSU', 'RootShell', 'KitsuneAbsent', 'KernelSUVersion')
if (-not (Test-Path variable:script:ToolkitBootPollAttempts)) {
    $script:ToolkitBootPollAttempts = 30
}
if (-not (Test-Path variable:script:ToolkitBootPollDelaySeconds)) {
    $script:ToolkitBootPollDelaySeconds = 3
}

function Invoke-Android15Adb {
    param(
        [string]$ManagerPath,
        [int]$InstanceIndex,
        [Parameter(Mandatory = $true)]
        [string]$Command,
        [scriptblock]$Runner = $null
    )

    return Invoke-CheckedProcess -FilePath $ManagerPath -ArgumentList @('adb', '-v', ([string]$InstanceIndex), '-c', $Command) -Runner $Runner
}

function New-Android15RootState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Code,
        [object]$Fields = $null,
        [string]$Step = '',
        [int]$SourceIndex = -1,
        [int]$CloneIndex = -1,
        [string]$CloneName = ''
    )

    $state = @{
        Code = $Code
        Step = $Step
        SourceIndex = $SourceIndex
        CloneIndex = $CloneIndex
        CloneName = $CloneName
        RootPermission = $false
        KernelSU = $false
        RootShell = $false
        KitsuneAbsent = $false
        KernelSUVersion = ''
    }
    if ($null -ne $Fields -and $Fields -is [Collections.IDictionary]) {
        foreach ($fieldName in $script:Root15FieldNames) {
            if ($Fields.Contains($fieldName)) {
                $state[$fieldName] = $Fields[$fieldName]
            }
        }
    }
    return $state
}

function New-Android15RootFailure {
    param(
        [object]$Journal,
        [string]$Message,
        [object]$Data = $null
    )

    $message = Protect-ToolkitText $Message
    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = 'The Android 15 root workflow failed.'
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

function Get-Android15RootSetting {
    param(
        [string]$ManagerPath,
        [int]$Index,
        [scriptblock]$Runner = $null
    )

    $outcome = Invoke-CheckedProcess -FilePath $ManagerPath -ArgumentList @('setting', '-v', ([string]$Index), '-k', 'root_permission') -Runner $Runner
    if ($null -eq $outcome -or $outcome.ExitCode -ne 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The MuMu manager did not report the vendor root setting.' -Data (@{ Code = 'MANAGER_FAILED' })
    }
    try {
        $records = @(ConvertFrom-ToolkitJson -Text ([string]$outcome.Text))
    }
    catch {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The vendor root setting response is not usable.' -Data (@{ Code = 'MANAGER_JSON_INVALID' })
    }
    if ($records.Count -ne 1) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The vendor root setting response does not describe exactly one instance.' -Data (@{ Code = 'SHAPE_UNSUPPORTED' })
    }
    $value = ConvertTo-ToolkitBoolean -Value (Get-ToolkitFirstProperty -InputObject $records[0] -PropertyNames @('root_permission', 'rootPermission', 'root_setting', 'rootSetting', 'value'))
    if ($null -eq $value) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The vendor root setting value is not a supported boolean.' -Data (@{ Code = 'VALUE_INVALID' })
    }
    return Get-ToolkitResult -Status 'Success' -Message 'The vendor root setting was read.' -Data (@{ Code = 'OK'; Index = $Index; Value = [bool]$value })
}

function Test-Android15Root {
    param(
        [string]$ManagerPath,
        [int]$InstanceIndex,
        [scriptblock]$Runner = $null
    )

    $manager = ConvertTo-ToolkitFullPath -Path $ManagerPath
    if ($null -eq $manager -or $InstanceIndex -lt 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The Android 15 root verification manager is invalid.' -Data (New-Android15RootState -Code 'MANAGER_UNAVAILABLE')
    }

    $rootSetting = Get-Android15RootSetting -ManagerPath $manager -Index $InstanceIndex -Runner $Runner
    if ($rootSetting.Status -ne 'Success') {
        return Get-ToolkitResult -Status 'CriticalError' -Message ('The Android 15 vendor root setting could not be read. ' + $rootSetting.Message) -Data (New-Android15RootState -Code 'ROOT_SETTING_UNREADABLE')
    }
    if ($rootSetting.Data.Value -ne $true) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The Android 15 instance does not report the enabled built-in root.' -Data (New-Android15RootState -Code 'ROOT_NOT_ENABLED')
    }
    $fields = @{ RootPermission = $true }

    $packageCall = Invoke-Android15Adb -ManagerPath $manager -InstanceIndex $InstanceIndex -Command ('shell dumpsys package ' + $script:Root15KernelSUPackage) -Runner $Runner
    if ($null -eq $packageCall -or $packageCall.ExitCode -ne 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The built-in KernelSU package query failed.' -Data (New-Android15RootState -Code 'ADB_FAILED' -Fields $fields)
    }
    $versionMatch = [regex]::Match([string]$packageCall.Text, '(?m)^\s*versionName=(\S+)')
    if (-not $versionMatch.Success) {
        return Get-ToolkitResult -Status 'CriticalError' -Message "The built-in KernelSU package $script:Root15KernelSUPackage is not installed." -Data (New-Android15RootState -Code 'KERNELSU_ABSENT' -Fields $fields)
    }
    $fields['KernelSU'] = $true
    $fields['KernelSUVersion'] = $versionMatch.Groups[1].Value

    $rootCall = Invoke-Android15Adb -ManagerPath $manager -InstanceIndex $InstanceIndex -Command 'shell su -c id' -Runner $Runner
    if ($null -eq $rootCall) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The root shell query failed.' -Data (New-Android15RootState -Code 'ADB_FAILED' -Fields $fields)
    }
    if ($rootCall.ExitCode -ne 0 -or ([string]$rootCall.Text) -notmatch '(?m)uid=0\(') {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The built-in root shell did not return a root identity.' -Data (New-Android15RootState -Code 'ROOT_DENIED' -Fields $fields)
    }
    $fields['RootShell'] = $true

    $kitsuneCall = Invoke-Android15Adb -ManagerPath $manager -InstanceIndex $InstanceIndex -Command ('shell pm list packages ' + $script:Root15KitsunePackage) -Runner $Runner
    if ($null -eq $kitsuneCall -or $kitsuneCall.ExitCode -ne 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The Kitsune package query failed, so an absent Kitsune package could not be confirmed.' -Data (New-Android15RootState -Code 'ADB_FAILED' -Fields $fields)
    }
    $kitsunePattern = '(?m)^\s*package:\s*' + [regex]::Escape($script:Root15KitsunePackage) + '\s*$'
    if (([string]$kitsuneCall.Text) -match $kitsunePattern) {
        return Get-ToolkitResult -Status 'CriticalError' -Message "The instance already has the Kitsune package $script:Root15KitsunePackage, which this workflow never installs and cannot account for." -Data (New-Android15RootState -Code 'KITSUNE_PRESENT' -Fields $fields)
    }
    $fields['KitsuneAbsent'] = $true

    return Get-ToolkitResult -Status 'Success' -Message 'The Android 15 built-in KernelSU root is verified.' -Data (New-Android15RootState -Code 'OK' -Fields $fields)
}

function Wait-Android15BootCompleted {
    param(
        [string]$ManagerPath,
        [int]$InstanceIndex,
        [scriptblock]$Runner = $null
    )

    for ($attempt = 1; $attempt -le $script:ToolkitBootPollAttempts; $attempt++) {
        $probe = Invoke-Android15Adb -ManagerPath $ManagerPath -InstanceIndex $InstanceIndex -Command 'shell getprop sys.boot_completed' -Runner $Runner
        if ($null -ne $probe -and $probe.ExitCode -eq 0 -and ([string]$probe.Text).Trim() -ceq '1') {
            return $true
        }
        if ($attempt -lt $script:ToolkitBootPollAttempts) {
            Start-Sleep -Seconds $script:ToolkitBootPollDelaySeconds
        }
    }
    return $false
}

function Enable-Android15Root {
    param(
        [object]$Instance,
        [object]$Journal,
        [scriptblock]$Runner = $null
    )

    try {
        Assert-OperationJournal $Journal
    }
    catch {
        return New-Android15RootFailure -Journal $null -Message 'The Android 15 root journal is invalid.' -Data (New-Android15RootState -Code 'JOURNAL_INVALID')
    }

    if ($null -eq $Instance -or $Instance -is [Array] -or $Instance -isnot [pscustomobject]) {
        return New-Android15RootFailure -Journal $Journal -Message 'The selected instance is invalid.' -Data (New-Android15RootState -Code 'INSTANCE_INVALID')
    }
    $indexProperty = $Instance.PSObject.Properties['Index']
    if ($null -eq $indexProperty -or
        ($indexProperty.Value -isnot [string] -and $indexProperty.Value -isnot [int] -and $indexProperty.Value -isnot [long])) {
        return New-Android15RootFailure -Journal $Journal -Message 'The selected instance is invalid.' -Data (New-Android15RootState -Code 'INSTANCE_INVALID')
    }
    $sourceIndex = 0
    if (-not [int]::TryParse([string]$indexProperty.Value, [ref]$sourceIndex) -or $sourceIndex -lt 0) {
        return New-Android15RootFailure -Journal $Journal -Message 'The selected instance is invalid.' -Data (New-Android15RootState -Code 'INSTANCE_INVALID')
    }

    $versionProperty = $Instance.PSObject.Properties['AndroidVersion']
    $sourceVersion = $null
    if ($null -ne $versionProperty) {
        $sourceVersion = ConvertTo-ToolkitAndroidVersion -Value $versionProperty.Value
    }
    if ($sourceVersion -cne '15.0') {
        return New-Android15RootFailure -Journal $Journal -Message 'Android 15 root requires an Android 15 instance. Android 12 instances use the Kitsune workflow.' -Data (New-Android15RootState -Code 'ANDROID_VERSION_UNSUPPORTED' -Step 'version' -SourceIndex $sourceIndex)
    }

    $installProperty = $Instance.PSObject.Properties['Install']
    if ($null -eq $installProperty -or $null -eq $installProperty.Value -or $installProperty.Value -isnot [pscustomobject]) {
        return New-Android15RootFailure -Journal $Journal -Message 'The selected instance install is invalid.' -Data (New-Android15RootState -Code 'INSTANCE_INVALID')
    }
    $installRootProperty = $installProperty.Value.PSObject.Properties['InstallRoot']
    $installManagerProperty = $installProperty.Value.PSObject.Properties['ManagerPath']
    $installVmsProperty = $installProperty.Value.PSObject.Properties['VmsPath']
    if ($null -eq $installRootProperty -or $installRootProperty.Value -isnot [string] -or
        $null -eq $installManagerProperty -or $installManagerProperty.Value -isnot [string] -or
        $null -eq $installVmsProperty -or $installVmsProperty.Value -isnot [string]) {
        return New-Android15RootFailure -Journal $Journal -Message 'The selected instance install is invalid.' -Data (New-Android15RootState -Code 'INSTANCE_INVALID')
    }
    $installRoot = ConvertTo-ToolkitFullPath -Path $installRootProperty.Value
    $manager = ConvertTo-ToolkitFullPath -Path $installManagerProperty.Value
    $vmsPath = ConvertTo-ToolkitFullPath -Path $installVmsProperty.Value
    if ($null -eq $manager -or $null -eq $installRoot -or
        -not (Test-ToolkitManagerFile -Path $manager -InstallRoot $installRoot)) {
        return New-Android15RootFailure -Journal $Journal -Message 'The MuMu manager is not a valid manager inside the selected install root.' -Data (New-Android15RootState -Code 'MANAGER_UNAVAILABLE')
    }
    if ($null -eq $vmsPath -or -not (Test-Path -LiteralPath $vmsPath -PathType Container)) {
        return New-Android15RootFailure -Journal $Journal -Message 'The selected instance VMS path is unavailable.' -Data (New-Android15RootState -Code 'INSTANCE_INVALID')
    }

    $startMessage = "The Android 15 built-in root workflow started for the selected instance at index $sourceIndex. No instance has been changed yet."
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message $startMessage -Data (New-Android15RootState -Code 'OK' -Step 'start' -SourceIndex $sourceIndex)
    }
    catch {
        return New-Android15RootFailure -Journal $Journal -Message 'The Android 15 root start could not be journaled.' -Data (New-Android15RootState -Code 'JOURNAL_WRITE_FAILED' -Step 'start' -SourceIndex $sourceIndex)
    }

    $clone = New-InstanceClone -ManagerPath $manager -Instance $Instance -Journal $Journal -Runner $Runner
    $cloneIsResult = ($null -ne $clone -and $clone -is [pscustomobject] -and $null -ne $clone.PSObject.Properties['Status'])
    if ($cloneIsResult -and [string]$clone.Status -ne 'Success') {
        return $clone
    }
    $unverifiedClone = {
        New-Android15RootFailure -Journal $Journal -Message 'The MuMu manager did not report a verified instance clone, so no instance was reconfigured.' -Data (New-Android15RootState -Code 'CLONE_UNVERIFIED' -Step 'clone' -SourceIndex $sourceIndex)
    }
    if (-not $cloneIsResult -or $null -eq $clone.Data -or $clone.Data -is [Array] -or
        $clone.Data -isnot [Collections.IDictionary] -or -not $clone.Data.Contains('CloneIndex') -or
        -not $clone.Data.Contains('CloneName')) {
        return (& $unverifiedClone)
    }
    $reportedCloneIndex = $clone.Data['CloneIndex']
    if ($reportedCloneIndex -isnot [string] -and $reportedCloneIndex -isnot [int] -and $reportedCloneIndex -isnot [long]) {
        return (& $unverifiedClone)
    }
    $cloneIndex = 0
    if (-not [int]::TryParse([string]$reportedCloneIndex, [ref]$cloneIndex) -or $cloneIndex -lt 0) {
        return (& $unverifiedClone)
    }
    if ($cloneIndex -eq $sourceIndex) {
        return (& $unverifiedClone)
    }
    $reportedCloneName = $clone.Data['CloneName']
    if ($reportedCloneName -isnot [string] -or [string]::IsNullOrWhiteSpace($reportedCloneName)) {
        return (& $unverifiedClone)
    }
    $cloneName = [string]$reportedCloneName

    $cloneMessage = "The Android 15 root workflow continues on the clone at index $cloneIndex, which is the only instance it will reconfigure. The selected instance at index $sourceIndex is only stopped for the clone."
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message $cloneMessage -Data (New-Android15RootState -Code 'OK' -Step 'clone' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    catch {
        return New-Android15RootFailure -Journal $Journal -Message 'The verified clone could not be journaled.' -Data (New-Android15RootState -Code 'JOURNAL_WRITE_FAILED' -Step 'clone' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }

    $previousSetting = Get-Android15RootSetting -ManagerPath $manager -Index $cloneIndex -Runner $Runner
    if ($previousSetting.Status -ne 'Success') {
        return New-Android15RootFailure -Journal $Journal -Message ('The clone vendor root setting could not be read, so nothing was changed. ' + $previousSetting.Message) -Data (New-Android15RootState -Code 'ROOT_SETTING_UNREADABLE' -Step 'root-read' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    $alreadyEnabled = ($previousSetting.Data.Value -eq $true)
    if (-not $alreadyEnabled) {
        $enableRoot = Invoke-CheckedProcess -FilePath $manager -ArgumentList @('setting', '-v', ([string]$cloneIndex), '-k', 'root_permission', '-val', 'true') -Runner $Runner
        if ($null -eq $enableRoot -or $enableRoot.ExitCode -ne 0) {
            return New-Android15RootFailure -Journal $Journal -Message 'The built-in root could not be enabled on the clone.' -Data (New-Android15RootState -Code 'ROOT_TOGGLE_FAILED' -Step 'root-enable' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
        }
        $enabledSetting = Get-Android15RootSetting -ManagerPath $manager -Index $cloneIndex -Runner $Runner
        if ($enabledSetting.Status -ne 'Success') {
            return New-Android15RootFailure -Journal $Journal -Message ('The clone did not report a readable vendor root setting after the change. ' + $enabledSetting.Message) -Data (New-Android15RootState -Code 'ROOT_SETTING_UNREADABLE' -Step 'root-enable' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
        }
        if ($enabledSetting.Data.Value -ne $true) {
            return New-Android15RootFailure -Journal $Journal -Message 'The clone did not report the enabled built-in root after the change.' -Data (New-Android15RootState -Code 'ROOT_NOT_ENABLED' -Step 'root-enable' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
        }
    }
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message "The built-in Android 15 root is enabled on the clone at index $cloneIndex and is kept enabled. The built-in KernelSU is the only root implementation this workflow uses, and it is never disabled again." -Data (New-Android15RootState -Code 'OK' -Step 'root-enable' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    catch {
        return New-Android15RootFailure -Journal $Journal -Message 'The enabled built-in root could not be journaled.' -Data (New-Android15RootState -Code 'JOURNAL_WRITE_FAILED' -Step 'root-enable' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }

    $launch = Invoke-CheckedProcess -FilePath $manager -ArgumentList @('control', '-v', ([string]$cloneIndex), 'launch') -Runner $Runner
    if ($null -eq $launch -or $launch.ExitCode -ne 0) {
        return New-Android15RootFailure -Journal $Journal -Message 'The clone did not accept the cold-boot launch request.' -Data (New-Android15RootState -Code 'BOOT_CONTROL_FAILED' -Step 'cold-boot' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message "The clone at index $cloneIndex was cold-booted from a verified stopped state so the built-in root change takes effect." -Data (New-Android15RootState -Code 'OK' -Step 'cold-boot' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    catch {
        return New-Android15RootFailure -Journal $Journal -Message 'The cold boot could not be journaled.' -Data (New-Android15RootState -Code 'JOURNAL_WRITE_FAILED' -Step 'cold-boot' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    if (-not (Wait-Android15BootCompleted -ManagerPath $manager -InstanceIndex $cloneIndex -Runner $Runner)) {
        return New-Android15RootFailure -Journal $Journal -Message "The clone did not report sys.boot_completed=1 after $($script:ToolkitBootPollAttempts) checks, so the Android 15 root state is unknown. The built-in root was left enabled on the clone." -Data (New-Android15RootState -Code 'BOOT_TIMEOUT' -Step 'cold-boot' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }

    $checks = Test-Android15Root -ManagerPath $manager -InstanceIndex $cloneIndex -Runner $Runner
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message 'The Android 15 vendor root setting, built-in KernelSU package, root shell, and Kitsune absence checks were recorded.' -Data $checks.Data
    }
    catch {
        return New-Android15RootFailure -Journal $Journal -Message 'The Android 15 root checks could not be journaled.' -Data (New-Android15RootState -Code 'JOURNAL_WRITE_FAILED' -Step 'verification' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    if ($checks.Status -ne 'Success') {
        return New-Android15RootFailure -Journal $Journal -Message $checks.Message -Data (New-Android15RootState -Code ([string]$checks.Data.Code) -Fields $checks.Data -Step 'verification' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }

    $status = if ($alreadyEnabled) { 'AlreadyApplied' } else { 'Success' }
    $successData = New-Android15RootState -Code 'OK' -Fields $checks.Data -Step 'complete' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName
    if ($alreadyEnabled) {
        $successMessage = "The Android 15 built-in root was already enabled on the clone at index $cloneIndex and its built-in KernelSU package, root shell, and absent Kitsune package are verified."
    }
    else {
        $successMessage = "The Android 15 built-in root is enabled and its built-in KernelSU package, root shell, and absent Kitsune package are verified on the clone at index $cloneIndex."
    }
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message $successMessage -Data $successData
        Complete-OperationJournal -Journal $Journal -Result (Get-ToolkitResult -Status $status -Message $successMessage -Data $successData)
    }
    catch {
        return New-Android15RootFailure -Journal $Journal -Message 'The verified Android 15 root could not be journaled.' -Data (New-Android15RootState -Code 'JOURNAL_WRITE_FAILED' -Step 'complete' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    return Get-ToolkitResult -Status $status -Message $successMessage -Data $successData
}
