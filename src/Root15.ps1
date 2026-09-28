$script:Root15KernelSUPackage = 'me.weishu.kernelsu'
$script:Root15KitsunePackage = 'io.github.huskydg.magisk'
$script:Root15FieldNames = @('RootPermission', 'KernelSU', 'RootShell', 'KitsuneAbsent', 'KernelSUVersion')
$script:Root15PackageListCommand = 'shell pm list packages'

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
        # The vendor root setting is unread until a read answers for this instance, so a failed read
        # cannot be reported as a disabled vendor root.
        RootPermission = $null
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

    $rootSetting = Get-ToolkitRootSetting -ManagerPath $manager -Index $InstanceIndex -Runner $Runner
    if ($rootSetting.Status -ne 'Success') {
        return Get-ToolkitResult -Status 'CriticalError' -Message ('The Android 15 vendor root setting could not be read. ' + $rootSetting.Message) -Data (New-Android15RootState -Code 'ROOT_SETTING_UNREADABLE')
    }
    if ($rootSetting.Data.Value -ne $true) {
        # The read answered for this instance, so a disabled vendor root is a claim the manager made.
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The Android 15 instance does not report the enabled built-in root.' -Data (New-Android15RootState -Code 'ROOT_NOT_ENABLED' -Fields @{ RootPermission = $false })
    }
    $fields = @{ RootPermission = $true }

    $packageCall = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $InstanceIndex -Command ('shell dumpsys package ' + $script:Root15KernelSUPackage) -Runner $Runner
    if ($null -eq $packageCall -or $packageCall.ExitCode -ne 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The built-in KernelSU package query failed.' -Data (New-Android15RootState -Code 'ADB_FAILED' -Fields $fields)
    }
    $packageFields = Get-ToolkitPackageVersion -Text ([string]$packageCall.Text) -PackageName $script:Root15KernelSUPackage
    if ($null -eq $packageFields -or [string]::IsNullOrWhiteSpace([string]$packageFields.VersionName)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message "The built-in KernelSU package $script:Root15KernelSUPackage is not installed." -Data (New-Android15RootState -Code 'KERNELSU_ABSENT' -Fields $fields)
    }
    $fields['KernelSU'] = $true
    $fields['KernelSUVersion'] = [string]$packageFields.VersionName

    $kitsuneCall = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $InstanceIndex -Command $script:Root15PackageListCommand -Runner $Runner
    if ($null -eq $kitsuneCall -or $kitsuneCall.ExitCode -ne 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The package list query failed, so an absent Kitsune package could not be confirmed.' -Data (New-Android15RootState -Code 'ADB_FAILED' -Fields $fields)
    }
    $kitsuneLine = 'package:' + $script:Root15KitsunePackage
    $kitsuneObserved = @()
    foreach ($line in @(([string]$kitsuneCall.Text) -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        if ($line -notmatch '^\s*package:\S+\s*$') {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'The package list response is not a list of packages, so an absent Kitsune package could not be confirmed.' -Data (New-Android15RootState -Code 'ADB_FAILED' -Fields $fields)
        }
        if ($line.Trim() -ceq $kitsuneLine) {
            $kitsuneObserved += $line.Trim()
        }
    }
    # The inherited package is reported before the root shell, because a Kitsune instance has no built-in root to probe and the shell result would name the wrong cause.
    if ($kitsuneObserved.Count -gt 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message ("The instance already has the Kitsune package $script:Root15KitsunePackage, which this workflow never installs and cannot account for. Observed in the guest package list: " + ($kitsuneObserved -join ', ') + '. This workflow verifies the built-in KernelSU root only, so no root result is claimed for this instance.') -Data (New-Android15RootState -Code 'KITSUNE_PRESENT' -Fields $fields)
    }
    $fields['KitsuneAbsent'] = $true

    $rootCall = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $InstanceIndex -Command 'shell su -c id' -Runner $Runner
    $rootShell = Get-ToolkitRootShellStatus -Call $rootCall
    if ($rootShell.Status -ne 'Success') {
        return Get-ToolkitResult -Status 'CriticalError' -Message ('The built-in root shell could not be verified. ' + $rootShell.Message) -Data (New-Android15RootState -Code ([string]$rootShell.Data.Code) -Fields $fields)
    }
    $fields['RootShell'] = $true

    return Get-ToolkitResult -Status 'Success' -Message 'The Android 15 built-in KernelSU root is verified.' -Data (New-Android15RootState -Code 'OK' -Fields $fields)
}

function Enable-Android15Root {
    param(
        [object]$Instance,
        [object]$Journal,
        [switch]$Confirmed,
        [object]$ResumeClone = $null,
        [scriptblock]$Runner = $null
    )

    try {
        Assert-OperationJournal $Journal
    }
    catch {
        return New-ToolkitRootFailure -Journal $null -Message 'The Android 15 root journal is invalid.' -Data (New-Android15RootState -Code 'JOURNAL_INVALID')
    }

    if ($null -eq $Instance -or $Instance -is [Array] -or $Instance -isnot [pscustomobject]) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The selected instance is invalid.' -Data (New-Android15RootState -Code 'INSTANCE_INVALID')
    }
    $indexProperty = $Instance.PSObject.Properties['Index']
    if ($null -eq $indexProperty -or
        ($indexProperty.Value -isnot [string] -and $indexProperty.Value -isnot [int] -and $indexProperty.Value -isnot [long])) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The selected instance is invalid.' -Data (New-Android15RootState -Code 'INSTANCE_INVALID')
    }
    $sourceIndex = 0
    if (-not [int]::TryParse([string]$indexProperty.Value, [ref]$sourceIndex) -or $sourceIndex -lt 0) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The selected instance is invalid.' -Data (New-Android15RootState -Code 'INSTANCE_INVALID')
    }

    $versionProperty = $Instance.PSObject.Properties['AndroidVersion']
    $sourceVersion = $null
    if ($null -ne $versionProperty) {
        $sourceVersion = ConvertTo-ToolkitAndroidVersion -Value $versionProperty.Value
    }
    if ($sourceVersion -cne '15.0') {
        return New-ToolkitRootFailure -Journal $Journal -Message "The Android 15 root workflow does not support the selected instance. No instance was changed." -Data (New-Android15RootState -Code 'ANDROID_VERSION_UNSUPPORTED' -Step 'version' -SourceIndex $sourceIndex)
    }

    $installProperty = $Instance.PSObject.Properties['Install']
    if ($null -eq $installProperty -or $null -eq $installProperty.Value -or $installProperty.Value -isnot [pscustomobject]) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The selected instance install is invalid.' -Data (New-Android15RootState -Code 'INSTANCE_INVALID')
    }
    $installRootProperty = $installProperty.Value.PSObject.Properties['InstallRoot']
    $installManagerProperty = $installProperty.Value.PSObject.Properties['ManagerPath']
    $installVmsProperty = $installProperty.Value.PSObject.Properties['VmsPath']
    if ($null -eq $installRootProperty -or $installRootProperty.Value -isnot [string] -or
        $null -eq $installManagerProperty -or $installManagerProperty.Value -isnot [string] -or
        $null -eq $installVmsProperty -or $installVmsProperty.Value -isnot [string]) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The selected instance install is invalid.' -Data (New-Android15RootState -Code 'INSTANCE_INVALID')
    }
    $installRoot = ConvertTo-ToolkitFullPath -Path $installRootProperty.Value
    $manager = ConvertTo-ToolkitFullPath -Path $installManagerProperty.Value
    $vmsPath = ConvertTo-ToolkitFullPath -Path $installVmsProperty.Value
    if ($null -eq $manager -or $null -eq $installRoot -or
        -not (Test-ToolkitManagerFile -Path $manager -InstallRoot $installRoot)) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The MuMu manager is not a valid manager inside the selected install root.' -Data (New-Android15RootState -Code 'MANAGER_UNAVAILABLE')
    }
    if ($null -eq $vmsPath -or -not (Test-Path -LiteralPath $vmsPath -PathType Container)) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The selected instance VMS path is unavailable.' -Data (New-Android15RootState -Code 'INSTANCE_INVALID')
    }

    if (-not $Confirmed) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'USER_CONFIRMATION_REQUIRED: The Android 15 built-in root flow creates a verified clone of the selected instance, enables the built-in root on that clone, and cold-boots it. Run the action from the menu, or pass the confirmation the controller collects. No instance was changed.' -Data (New-Android15RootState -Code 'USER_CONFIRMATION_REQUIRED' -Step 'confirmation' -SourceIndex $sourceIndex)
    }

    $startMessage = "The Android 15 built-in root workflow started for the selected instance at index $sourceIndex. No instance has been changed yet."
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message $startMessage -Data (New-Android15RootState -Code 'OK' -Step 'start' -SourceIndex $sourceIndex)
    }
    catch {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The Android 15 root start could not be journaled.' -Data (New-Android15RootState -Code 'JOURNAL_WRITE_FAILED' -Step 'start' -SourceIndex $sourceIndex)
    }

    # A recorded clone is resumed rather than copied again, so choosing "continue on its clone" in the menu
    # does not silently spend a second instance. The recorded identity, version, installation boundary and
    # disk are revalidated against the manager first, exactly as the Android 12 resume path does, because a
    # recorded index is a claim about the past rather than a reading of the present.
    $cloneIndex = -1
    $cloneName = ''
    if ($null -ne $ResumeClone) {
        $resume = Assert-Android12ResumeClone -ManagerPath $manager -VmsPath $vmsPath -Record $ResumeClone -Runner $Runner
        if ($resume.Status -ne 'Success') {
            return New-ToolkitRootFailure -Journal $Journal -Message $resume.Message -Data (New-Android15RootState -Code ([string]$resume.Data.Code) -Step 'resume' -SourceIndex $sourceIndex -CloneIndex ([int](Get-Android12RecordField -Record $resume.Data -Name 'CloneIndex')) -CloneName ([string](Get-Android12RecordField -Record $resume.Data -Name 'CloneName')))
        }
        $cloneIndex = [int]$resume.Data.CloneIndex
        $cloneName = [string]$resume.Data.CloneName
        $cloneMessage = "The Android 15 root workflow resumed on the verified clone at index $cloneIndex. Its identity, Android version, installation boundary and disk were revalidated and no second clone was created."
    }
    else {
        $clone = New-InstanceClone -ManagerPath $manager -Instance $Instance -Journal $Journal -Runner $Runner
        $cloneIsResult = ($null -ne $clone -and $clone -is [pscustomobject] -and $null -ne $clone.PSObject.Properties['Status'])
        if ($cloneIsResult -and [string]$clone.Status -ne 'Success') {
            return $clone
        }
        $unverifiedClone = {
            New-ToolkitRootFailure -Journal $Journal -Message 'The MuMu manager did not report a verified instance clone, so no instance was reconfigured.' -Data (New-Android15RootState -Code 'CLONE_UNVERIFIED' -Step 'clone' -SourceIndex $sourceIndex)
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
    }
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message $cloneMessage -Data (New-Android15RootState -Code 'OK' -Step 'clone' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    catch {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The verified clone could not be journaled.' -Data (New-Android15RootState -Code 'JOURNAL_WRITE_FAILED' -Step 'clone' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }

    $previousSetting = Get-ToolkitRootSetting -ManagerPath $manager -Index $cloneIndex -Runner $Runner
    if ($previousSetting.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message ('The clone vendor root setting could not be read, so nothing was changed. ' + $previousSetting.Message) -Data (New-Android15RootState -Code 'ROOT_SETTING_UNREADABLE' -Step 'root-read' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    $alreadyEnabled = ($previousSetting.Data.Value -eq $true)
    if (-not $alreadyEnabled) {
        $enableRoot = Invoke-CheckedProcess -FilePath $manager -ArgumentList @('setting', '-v', ([string]$cloneIndex), '-k', 'root_permission', '-val', 'true') -Runner $Runner
        if ($null -eq $enableRoot -or $enableRoot.ExitCode -ne 0) {
            return New-ToolkitRootFailure -Journal $Journal -Message 'The built-in root could not be enabled on the clone.' -Data (New-Android15RootState -Code 'ROOT_TOGGLE_FAILED' -Step 'root-enable' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
        }
        $enabledSetting = Get-ToolkitRootSetting -ManagerPath $manager -Index $cloneIndex -Runner $Runner
        if ($enabledSetting.Status -ne 'Success') {
            return New-ToolkitRootFailure -Journal $Journal -Message ('The clone did not report a readable vendor root setting after the change. ' + $enabledSetting.Message) -Data (New-Android15RootState -Code 'ROOT_SETTING_UNREADABLE' -Step 'root-enable' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
        }
        if ($enabledSetting.Data.Value -ne $true) {
            return New-ToolkitRootFailure -Journal $Journal -Message 'The clone did not report the enabled built-in root after the change.' -Data (New-Android15RootState -Code 'ROOT_NOT_ENABLED' -Step 'root-enable' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName -Fields @{ RootPermission = $false })
        }
    }
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message "The built-in Android 15 root is enabled on the clone at index $cloneIndex and is kept enabled. The built-in KernelSU is the only root implementation this workflow uses, and it is never disabled again." -Data (New-Android15RootState -Code 'OK' -Step 'root-enable' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    catch {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The enabled built-in root could not be journaled.' -Data (New-Android15RootState -Code 'JOURNAL_WRITE_FAILED' -Step 'root-enable' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }

    $launch = Invoke-CheckedProcess -FilePath $manager -ArgumentList @('control', '-v', ([string]$cloneIndex), 'launch') -Runner $Runner
    if ($null -eq $launch -or $launch.ExitCode -ne 0) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The clone did not accept the cold-boot launch request.' -Data (New-Android15RootState -Code 'BOOT_CONTROL_FAILED' -Step 'cold-boot' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message "The clone at index $cloneIndex was cold-booted from a verified stopped state so the built-in root change takes effect." -Data (New-Android15RootState -Code 'OK' -Step 'cold-boot' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    catch {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The cold boot could not be journaled.' -Data (New-Android15RootState -Code 'JOURNAL_WRITE_FAILED' -Step 'cold-boot' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    $bootWait = Wait-ToolkitBootCompleted -ManagerPath $manager -InstanceIndex $cloneIndex -Runner $Runner
    if ([string]$bootWait.Code -cne 'BOOTED') {
        return New-ToolkitRootFailure -Journal $Journal -Message "The clone did not report sys.boot_completed=1 before $($bootWait.Bound) ended the wait, so the Android 15 root state is unknown. The built-in root was left enabled on the clone." -Data (New-Android15RootState -Code 'BOOT_TIMEOUT' -Step 'cold-boot' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }

    $checks = Test-Android15Root -ManagerPath $manager -InstanceIndex $cloneIndex -Runner $Runner
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message 'The Android 15 vendor root setting, built-in KernelSU package, root shell, and Kitsune absence checks were recorded.' -Data $checks.Data
    }
    catch {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The Android 15 root checks could not be journaled.' -Data (New-Android15RootState -Code 'JOURNAL_WRITE_FAILED' -Step 'verification' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    if ($checks.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message $checks.Message -Data (New-Android15RootState -Code ([string]$checks.Data.Code) -Fields $checks.Data -Step 'verification' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
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
        return New-ToolkitRootFailure -Journal $Journal -Message 'The verified Android 15 root could not be journaled.' -Data (New-Android15RootState -Code 'JOURNAL_WRITE_FAILED' -Step 'complete' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    return Get-ToolkitResult -Status $status -Message $successMessage -Data $successData
}
