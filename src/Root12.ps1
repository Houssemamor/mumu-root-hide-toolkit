$script:ToolkitKitsuneAssetId = 'kitsune'
$script:ToolkitKitsunePackageName = 'io.github.huskydg.magisk'
$script:ToolkitKitsuneVersionName = '31.0-kitsune'
$script:ToolkitKitsuneVersionCode = '31000'
$script:ToolkitKitsunePrompt = 'Install -> Direct Install into system partition'
$script:ToolkitKitsuneChoice = 'Direct Install into system partition'
$script:ToolkitKitsuneRejection = 'Do not choose the ordinary Direct Install or Select and Patch a File option.'
$script:ToolkitKitsuneLaunchCommand = 'shell monkey -p io.github.huskydg.magisk -c android.intent.category.LAUNCHER 1'
# A root shell probe can briefly leave a second process named magiskd, so one sample is not enough to judge the daemon.
if (-not (Test-Path variable:script:ToolkitAndroid12DaemonSampleAttempts)) {
    $script:ToolkitAndroid12DaemonSampleAttempts = 3
}
if (-not (Test-Path variable:script:ToolkitAndroid12DaemonSettleMilliseconds)) {
    $script:ToolkitAndroid12DaemonSettleMilliseconds = 400
}
$script:ToolkitKitsuneDefaultPrompt = {
    param([string]$PromptText)

    return Read-Android12KitsuneConfirmation -PromptText $PromptText
}

function Get-Android12KitsunePrompt {
    return $script:ToolkitKitsunePrompt
}

function Test-KitsuneConfirmation {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Confirmation
    )

    # The full option text is the attestation, and CONFIRM is accepted as the short form of the same
    # answer. This gate is not a password: it exists so a run that never did the system-partition
    # install does not spend a multi-minute cold boot finding out, and the root is measured by
    # observation immediately afterwards either way. Requiring a 35 character, case sensitive
    # phrase to say "yes, I did it" bought no safety and was a typo waiting to happen.
    $answer = ([string]$Confirmation).Trim()
    if ($answer -ceq $script:ToolkitKitsuneChoice) {
        return $true
    }
    return ($answer -ceq 'CONFIRM')
}

function Read-Android12KitsuneConfirmation {
    param([string]$PromptText)

    try {
        return [string](Read-Host -Prompt $PromptText)
    }
    catch {
        return ''
    }
}

function Format-Android12InstallCommand {
    param([string]$Path)

    $fullPath = ConvertTo-ToolkitFullPath -Path $Path
    if ($null -eq $fullPath -or $fullPath -match '["\r\n]') {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The verified asset path cannot be used as a MuMu command argument.' -Data (@{ Code = 'ASSET_PATH_INVALID' })
    }
    return Get-ToolkitResult -Status 'Success' -Message 'The install command is ready.' -Data ('install -r "' + $fullPath + '"')
}

function New-Android12Recovery {
    param(
        [string]$Code,
        [string]$Step,
        [int]$SourceIndex,
        [int]$CloneIndex = -1,
        [string]$CloneName = '',
        [object]$Checks = $null
    )

    if ([string]::IsNullOrWhiteSpace($Code)) {
        throw 'The Android 12 recovery code is required.'
    }

    $record = @{
        Code = $Code
        Step = $Step
        SourceIndex = $SourceIndex
        CloneIndex = $CloneIndex
        CloneName = $CloneName
        RootVerified = $false
        VersionName = ''
        VersionCode = ''
        # The recovery record starts unread, so a step that never reached the daemon query cannot report a
        # measured count of zero.
        DaemonCount = -1
        DaemonSamples = 0
    }
    if ($null -ne $Checks) {
        $record.RootVerified = [bool](Get-Android12RecordField -Record $Checks -Name 'RootVerified')
        $record.VersionName = [string](Get-Android12RecordField -Record $Checks -Name 'VersionName')
        $record.VersionCode = [string](Get-Android12RecordField -Record $Checks -Name 'VersionCode')
        # A checks record that carries no count leaves the recovery record unread, so no step can report
        # a measured zero daemons it never measured.
        $recordDaemonCount = Get-Android12RecordField -Record $Checks -Name 'DaemonCount'
        if ($null -ne $recordDaemonCount -and [int]$recordDaemonCount -ge 0) {
            $record.DaemonCount = [int]$recordDaemonCount
        }
        $record.DaemonSamples = [int](Get-Android12RecordField -Record $Checks -Name 'DaemonSamples')
    }
    return $record
}

function Prepare-Android12Asset {
    param(
        [object]$Manifest,
        [string]$CacheRoot = '',
        [switch]$RequireCached,
        [scriptblock]$Fetch = $null
    )

    $assetCacheRoot = $CacheRoot
    if ([string]::IsNullOrWhiteSpace($assetCacheRoot)) {
        try {
            $assetCacheRoot = Get-ToolkitAssetCacheRoot
        }
        catch {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'The dependency cache root is unavailable.' -Data (@{ Code = 'CACHE_UNAVAILABLE' })
        }
    }
    try {
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetFullPath($assetCacheRoot))
    }
    catch {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The dependency cache directory is unavailable.' -Data (@{ Code = 'CACHE_UNAVAILABLE' })
    }

    $asset = Save-ToolkitAsset -Manifest $Manifest -Id $script:ToolkitKitsuneAssetId -CacheRoot $assetCacheRoot -Fetch $Fetch -RequireCached:$RequireCached
    if ($asset.Status -ne 'Success') {
        return Get-ToolkitResult -Status 'CriticalError' -Message ('The pinned Kitsune asset was not verified. ' + $asset.Message) -Data (@{ Code = 'ASSET_VERIFICATION_FAILED' })
    }
    return Get-ToolkitResult -Status 'Success' -Message 'The pinned Kitsune asset is verified in the dependency cache.' -Data ([string]$asset.Data)
}

function Get-Android12RecordField {
    param(
        [object]$Record,
        [string]$Name
    )

    if ($null -eq $Record) {
        return $null
    }
    if ($Record -is [Collections.IDictionary]) {
        if (-not $Record.Contains($Name)) {
            return $null
        }
        return $Record[$Name]
    }
    $property = $Record.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Resolve-Android12Clone {
    param(
        [object]$CloneResult,
        [object]$Journal
    )

    if ($null -eq $CloneResult -or $CloneResult -is [Array] -or $CloneResult -isnot [pscustomobject] -or
        $null -eq $CloneResult.PSObject.Properties['Data']) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The MuMu manager reported a clone without a verified clone record.' -Data (@{ Code = 'CLONE_UNVERIFIED' })
    }
    $data = $CloneResult.Data
    if ($null -eq $data -or $data -is [Array] -or ($data -isnot [pscustomobject] -and $data -isnot [Collections.IDictionary])) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The MuMu manager reported a clone without a verified clone record.' -Data (@{ Code = 'CLONE_UNVERIFIED' })
    }
    $reportedIndex = Get-Android12RecordField -Record $data -Name 'CloneIndex'
    $cloneIndex = 0
    if ($reportedIndex -isnot [string] -and $reportedIndex -isnot [int] -and $reportedIndex -isnot [long]) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The verified clone index is invalid.' -Data (@{ Code = 'CLONE_INVALID' })
    }
    if (-not [int]::TryParse([string]$reportedIndex, [ref]$cloneIndex) -or $cloneIndex -lt 0) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The verified clone index is invalid.' -Data (@{ Code = 'CLONE_INVALID' })
    }
    $reportedName = Get-Android12RecordField -Record $data -Name 'CloneName'
    if ($reportedName -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$reportedName)) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The verified clone name is invalid.' -Data (@{ Code = 'CLONE_INVALID' })
    }
    return Get-ToolkitResult -Status 'Success' -Message 'The verified clone record is usable.' -Data (@{
            Code = 'OK'
            CloneIndex = $cloneIndex
            CloneName = [string]$reportedName
        })
}

function Assert-AndroidResumeClone {
    param(
        [string]$ManagerPath,
        [string]$VmsPath,
        [object]$Record,
        # The Android version the clone has to be. This validator is shared by both root workflows, and it
        # used to hardcode 12.0, so the Android 15 resume path validated its own clone against the Android
        # 12 rules and refused every clone it was given.
        [string]$ExpectedVersion = '12.0',
        [scriptblock]$Runner = $null
    )

    if ($null -eq $Record -or $Record -is [Array] -or ($Record -isnot [pscustomobject] -and $Record -isnot [Collections.IDictionary])) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The recorded recovery clone is invalid.' -Data (@{ Code = 'RESUME_RECORD_INVALID' })
    }
    $reportedIndex = Get-Android12RecordField -Record $Record -Name 'CloneIndex'
    if ($reportedIndex -isnot [string] -and $reportedIndex -isnot [int] -and $reportedIndex -isnot [long]) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The recorded recovery clone has no usable index.' -Data (@{ Code = 'RESUME_RECORD_INVALID' })
    }
    $cloneIndex = 0
    if (-not [int]::TryParse([string]$reportedIndex, [ref]$cloneIndex) -or $cloneIndex -lt 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The recorded recovery clone index is invalid.' -Data (@{ Code = 'RESUME_RECORD_INVALID' })
    }
    $reportedName = Get-Android12RecordField -Record $Record -Name 'CloneName'
    $expectedName = ''
    if ($null -ne $reportedName) {
        if ($reportedName -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$reportedName)) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'The recorded recovery clone name is invalid.' -Data (@{ Code = 'RESUME_RECORD_INVALID' })
        }
        $expectedName = [string]$reportedName
    }
    $manager = ConvertTo-ToolkitFullPath -Path $ManagerPath
    $vms = ConvertTo-ToolkitFullPath -Path $VmsPath
    if ($null -eq $manager -or $null -eq $vms -or -not (Test-Path -LiteralPath $vms -PathType Container)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The recorded recovery clone cannot be revalidated against this installation.' -Data (@{ Code = 'RESUME_RECORD_INVALID' })
    }

    $records = @(Get-MuMuInstanceRecord -ManagerPath $manager -VersionArgument ([string]$cloneIndex) -Runner $Runner)
    if ($records.Count -ne 1) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The recorded recovery clone is not reported by the MuMu manager.' -Data (@{ Code = 'RESUME_CLONE_MISSING' })
    }
    $cloneRecord = $records[0]
    $reportedIndex = 0
    if (-not [int]::TryParse([string]$cloneRecord.index, [ref]$reportedIndex) -or $reportedIndex -ne $cloneIndex) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The recorded recovery clone index does not match the MuMu manager.' -Data (@{ Code = 'RESUME_CLONE_IDENTITY' })
    }
    if ((ConvertTo-ToolkitBoolean -Value (Get-ToolkitFirstProperty -InputObject $cloneRecord -PropertyNames @('is_main'))) -ne $false) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The recorded recovery clone is not a reported non-base instance.' -Data (@{ Code = 'RESUME_CLONE_IDENTITY' })
    }
    $reportedNameProperty = $cloneRecord.PSObject.Properties['name']
    if ($null -eq $reportedNameProperty -or $reportedNameProperty.Value -isnot [string] -or
        [string]::IsNullOrWhiteSpace([string]$reportedNameProperty.Value)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The recorded recovery clone has no usable name.' -Data (@{ Code = 'RESUME_CLONE_IDENTITY' })
    }
    $cloneName = [string]$reportedNameProperty.Value
    if (-not [string]::IsNullOrWhiteSpace($expectedName) -and $cloneName -cne $expectedName) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The recorded recovery clone name does not match the MuMu manager.' -Data (@{ Code = 'RESUME_CLONE_IDENTITY' })
    }

    $reportedVersion = ConvertTo-ToolkitAndroidVersion -Value (Get-ToolkitFirstProperty -InputObject $cloneRecord -PropertyNames @('android_version', 'androidVersion', 'system_version', 'systemVersion'))
    if ($null -eq $reportedVersion) {
        $reportedVersion = Get-ToolkitInstanceAndroidVersion -VmsPath $vms -Index $cloneIndex
    }
    if ($reportedVersion -cne $ExpectedVersion) {
        $expectedLabel = 'Android ' + ([string]$ExpectedVersion -replace '\.0$', '')
        return Get-ToolkitResult -Status 'CriticalError' -Message ('The recorded recovery clone is not an ' + $expectedLabel + ' instance.') -Data (@{ Code = 'RESUME_CLONE_VERSION' })
    }

    $reportedVmsPath = [string](Get-ToolkitFirstProperty -InputObject $cloneRecord -PropertyNames @('vms_path', 'vmsPath'))
    $cloneRoot = Get-MuMuInstanceRootPath -VmsPath $vms -Index $cloneIndex -ReportedVmsPath $reportedVmsPath
    if ($null -eq $cloneRoot -or -not (Test-ToolkitPathWithinRoot -Path $cloneRoot -Root $vms)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The recorded recovery clone is outside its installation boundary.' -Data (@{ Code = 'RESUME_CLONE_CONTAINMENT' })
    }
    $diskBytes = Measure-MuMuInstanceDiskBytes -InstanceRoot $cloneRoot
    if ($null -eq $diskBytes -or $diskBytes -le 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The recorded recovery clone does not have a usable disk.' -Data (@{ Code = 'RESUME_CLONE_DISK' })
    }

    return Get-ToolkitResult -Status 'Success' -Message 'The recorded recovery clone is revalidated.' -Data (@{
            Code = 'OK'
            CloneIndex = $cloneIndex
            CloneName = $cloneName
        })
}

function Test-Android12Root {
    param(
        [string]$ManagerPath,
        [int]$InstanceIndex,
        [scriptblock]$Runner = $null
    )

    $manager = ConvertTo-ToolkitFullPath -Path $ManagerPath
    if ($null -eq $manager -or $InstanceIndex -lt 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The Android 12 root verification manager is invalid.' -Data (@{ Code = 'MANAGER_UNAVAILABLE' })
    }

    $packageCall = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $InstanceIndex -Command ('shell dumpsys package ' + $script:ToolkitKitsunePackageName) -Runner $Runner
    if ($null -eq $packageCall -or $packageCall.ExitCode -ne 0) {
        # The daemon query never ran, so its count is unread rather than a measured zero.
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The Kitsune package query failed.' -Data (@{ Code = 'ADB_FAILED'; DaemonCount = -1 })
    }
    $packageFields = Get-ToolkitPackageVersion -Text ([string]$packageCall.Text) -PackageName $script:ToolkitKitsunePackageName
    if ($null -eq $packageFields) {
        return Get-ToolkitResult -Status 'CriticalError' -Message "The Kitsune package $script:ToolkitKitsunePackageName is not installed." -Data @{
                Code = 'PACKAGE_MISSING'
                PackageName = $script:ToolkitKitsunePackageName
                VersionName = ''
                VersionCode = ''
                DaemonCount = -1
                RootVerified = $false
            }
    }
    $versionName = [string]$packageFields.VersionName
    $versionCode = [string]$packageFields.VersionCode
    if ($versionName -cne $script:ToolkitKitsuneVersionName -or $versionCode -cne $script:ToolkitKitsuneVersionCode) {
        return Get-ToolkitResult -Status 'CriticalError' -Message "The installed package is not the pinned Kitsune release $script:ToolkitKitsuneVersionName." -Data (@{
                Code = 'PACKAGE_VERSION_MISMATCH'
                PackageName = $script:ToolkitKitsunePackageName
                VersionName = $versionName
                VersionCode = $versionCode
                DaemonCount = -1
                RootVerified = $false
            })
    }

    $daemonPids = @()
    $daemonExitCode = $null
    $daemonSamples = 0
    for ($attempt = 1; $attempt -le $script:ToolkitAndroid12DaemonSampleAttempts; $attempt++) {
        $daemonCall = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $InstanceIndex -Command 'shell pidof magiskd' -Runner $Runner
        $daemonSamples = $attempt
        $daemonExitCode = $null
        $daemonPids = @()
        if ($null -ne $daemonCall) {
            $daemonExitCode = $daemonCall.ExitCode
            $daemonPids = @(([string]$daemonCall.Text) -split '\s+' | Where-Object { $_ })
        }
        if ($daemonExitCode -eq 0 -and $daemonPids.Count -eq 1) {
            break
        }
        # Only a readable count is resampled, so the helper process has time to exit. A transport failure is classified from its own sample.
        $readableCount = ($daemonExitCode -eq 0 -or ($daemonExitCode -eq 1 -and $daemonPids.Count -eq 0))
        if (-not $readableCount) {
            break
        }
        if ($attempt -lt $script:ToolkitAndroid12DaemonSampleAttempts) {
            Start-Sleep -Milliseconds $script:ToolkitAndroid12DaemonSettleMilliseconds
        }
    }
    if ($daemonExitCode -eq 0) {
        if ($daemonPids.Count -eq 0) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'The Kitsune root daemon is not running.' -Data (@{
                    Code = 'DAEMON_ABSENT'
                    PackageName = $script:ToolkitKitsunePackageName
                    VersionName = $versionName
                    VersionCode = $versionCode
                    DaemonCount = 0
                    DaemonSamples = $daemonSamples
                    RootVerified = $false
                })
        }
        if ($daemonPids.Count -ne 1) {
            return Get-ToolkitResult -Status 'CriticalError' -Message "The Kitsune root daemon is running $($daemonPids.Count) times instead of once." -Data (@{
                    Code = 'DAEMON_DUPLICATE'
                    PackageName = $script:ToolkitKitsunePackageName
                    VersionName = $versionName
                    VersionCode = $versionCode
                    DaemonCount = $daemonPids.Count
                    DaemonSamples = $daemonSamples
                    RootVerified = $false
                })
        }
    }
    elseif ($daemonExitCode -eq 1 -and $daemonPids.Count -eq 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The Kitsune root daemon query reported no running daemon.' -Data (@{
                Code = 'DAEMON_ABSENT'
                PackageName = $script:ToolkitKitsunePackageName
                VersionName = $versionName
                VersionCode = $versionCode
                DaemonCount = 0
                DaemonSamples = $daemonSamples
                RootVerified = $false
            })
    }
    else {
        # The daemon query never produced a count, so the field is unread rather than a measured zero.
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The Kitsune root daemon query failed.' -Data (@{ Code = 'ADB_FAILED'; DaemonCount = -1; DaemonSamples = $daemonSamples })
    }

    $rootShell = Invoke-ToolkitRootShellProbe -ManagerPath $manager -InstanceIndex $InstanceIndex -Runner $Runner
    if ($rootShell.Status -ne 'Success') {
        return Get-ToolkitResult -Status 'CriticalError' -Message ('The Kitsune root shell could not be verified. ' + $rootShell.Message) -Data @{
                Code = [string]$rootShell.Data.Code
                PackageName = $script:ToolkitKitsunePackageName
                VersionName = $versionName
                VersionCode = $versionCode
                DaemonCount = $daemonPids.Count
                DaemonSamples = $daemonSamples
                RootVerified = $false
            }
    }

    return Get-ToolkitResult -Status 'Success' -Message 'The Android 12 Kitsune root is verified.' -Data (@{
            Code = 'OK'
            PackageName = $script:ToolkitKitsunePackageName
            VersionName = $versionName
            VersionCode = $versionCode
            DaemonCount = $daemonPids.Count
            DaemonSamples = $daemonSamples
            RootVerified = $true
        })
}

function Restore-Android12VendorRoot {
    param(
        [string]$ManagerPath,
        [int]$CloneIndex,
        [int]$SourceIndex,
        [string]$CloneName,
        [object]$CleanupChecks,
        [object]$Journal,
        [scriptblock]$Runner = $null
    )

    $manager = ConvertTo-ToolkitFullPath -Path $ManagerPath
    $enableRoot = Invoke-CheckedProcess -FilePath $manager -ArgumentList @('setting', '-v', ([string]$CloneIndex), '-k', 'root_permission', '-val', 'true') -Runner $Runner
    if ($null -eq $enableRoot -or $enableRoot.ExitCode -ne 0) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The Kitsune root did not survive disabling the MuMu vendor root, and the vendor root could not be enabled again on the clone, so the clone is left without a verified root. No further change was made.' -Data (New-Android12Recovery -Code 'ROOT_RECOVERY_FAILED' -Step 'vendor-root-restore' -SourceIndex $SourceIndex -CloneIndex $CloneIndex -CloneName $CloneName -Checks $CleanupChecks.Data)
    }
    $restoredSettings = Get-ToolkitInstanceSettings -ManagerPath $manager -Index $CloneIndex -Keys @('root_permission', 'system_disk_readonly') -Runner $Runner
    if ($restoredSettings.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message ('The vendor root was enabled again on the clone, but the clone settings could not be read afterwards, so the Kitsune root is not verified. ' + $restoredSettings.Message) -Data (New-Android12Recovery -Code 'ROOT_RECOVERY_FAILED' -Step 'vendor-root-restore' -SourceIndex $SourceIndex -CloneIndex $CloneIndex -CloneName $CloneName -Checks $CleanupChecks.Data)
    }
    $restoredRootValue = Get-ToolkitRecordValue -Record $restoredSettings.Data -PropertyNames @('root_permission')
    if ($restoredRootValue -ne $true) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The vendor root write was accepted, but the clone does not report the enabled vendor root afterwards, so the Kitsune root is not verified.' -Data (New-Android12Recovery -Code 'ROOT_RECOVERY_FAILED' -Step 'vendor-root-restore' -SourceIndex $SourceIndex -CloneIndex $CloneIndex -CloneName $CloneName -Checks $CleanupChecks.Data)
    }
    $restoredSystemDiskValue = Get-ToolkitRecordValue -Record $restoredSettings.Data -PropertyNames @('system_disk_readonly')
    if ($restoredSystemDiskValue -ne $false) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The clone reports a read-only system disk again, so Kitsune cannot install into the system partition and the Kitsune root is not verified.' -Data (New-Android12Recovery -Code 'ROOT_RECOVERY_FAILED' -Step 'vendor-root-restore' -SourceIndex $SourceIndex -CloneIndex $CloneIndex -CloneName $CloneName -Checks $CleanupChecks.Data)
    }
    $restoreChecks = Test-Android12Root -ManagerPath $manager -InstanceIndex $CloneIndex -Runner $Runner
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message 'The Android 12 package, root daemon, and root shell checks were repeated after the MuMu vendor root was enabled again on the clone.' -Data $restoreChecks.Data
    }
    catch {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The Android 12 root checks after the vendor root was enabled again could not be journaled.' -Data (New-Android12Recovery -Code 'JOURNAL_WRITE_FAILED' -Step 'vendor-root-restore-verification' -SourceIndex $SourceIndex -CloneIndex $CloneIndex -CloneName $CloneName -Checks $restoreChecks.Data)
    }
    if ($restoreChecks.Status -ne 'Success') {
        # The readback above proved the vendor root is enabled, so the record must say the operator is left with it on.
        $failedRestoreData = New-Android12Recovery -Code 'ROOT_RECOVERY_FAILED' -Step 'vendor-root-restore-verification' -SourceIndex $SourceIndex -CloneIndex $CloneIndex -CloneName $CloneName -Checks $restoreChecks.Data
        $failedRestoreData['VendorRootRetained'] = $true
        return New-ToolkitRootFailure -Journal $Journal -Message ('The MuMu vendor root is enabled again on the clone, but the Kitsune root still does not verify, so the clone is left with the vendor root on and without a verified root. ' + $restoreChecks.Message) -Data $failedRestoreData
    }

    $restoreData = New-Android12Recovery -Code 'ROOT_AFTER_DISABLE_ROLLED_BACK' -Step 'vendor-root-restore' -SourceIndex $SourceIndex -CloneIndex $CloneIndex -CloneName $CloneName -Checks $restoreChecks.Data
    $restoreData['VendorRootRetained'] = $true
    $restoreData['SystemDiskReadonly'] = $false
    $restoreData['PackageName'] = $script:ToolkitKitsunePackageName
    $restoreMessage = "The Kitsune root does not survive disabling the MuMu vendor root on MuMu 6.8. The adb shell there stays uid=2000, root is provided by the Magisk su, and disabling the vendor root removes the /system/bin/su path that provides it, so the clone at index $CloneIndex keeps the vendor root enabled. The Kitsune root is verified again with the vendor root on, the retained vendor root is documented here, and the action is reported as a warning, not as a success."
    try {
        Write-JournalEvent -Journal $Journal -Level 'Warning' -Message $restoreMessage -Data $restoreData
        Complete-OperationJournal -Journal $Journal -Result (Get-ToolkitResult -Status 'Warning' -Message $restoreMessage -Data $restoreData)
    }
    catch {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The retained-vendor-root Android 12 result could not be journaled.' -Data (New-Android12Recovery -Code 'JOURNAL_WRITE_FAILED' -Step 'vendor-root-restore' -SourceIndex $SourceIndex -CloneIndex $CloneIndex -CloneName $CloneName -Checks $restoreChecks.Data)
    }
    return Get-ToolkitResult -Status 'Warning' -Message $restoreMessage -Data $restoreData
}

function Install-Android12Root {
    param(
        [object]$Instance,
        [object]$Manifest,
        [object]$Journal,
        [bool]$Interactive = $false,
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Confirmation = '',
        [string]$CacheRoot = '',
        [scriptblock]$Runner = $null,
        [scriptblock]$Prompt = $null,
        [object]$ResumeClone = $null,
        # The run authorization is separate from the Kitsune choice further down. It defaults to on for a
        # direct caller, which is how this flow was always invoked, and the menu passes it explicitly so
        # the confirmation it collected is the one that gates the copy. Without the gate a declined run
        # still cloned an instance and installed the artifact before anything was asked.
        [bool]$RunConfirmed = $true,
        [switch]$RequireCachedAsset
    )

    try {
        Assert-OperationJournal $Journal
    }
    catch {
        return New-ToolkitRootFailure -Journal $null -Message 'The Android 12 root journal is invalid.' -Data (@{ Code = 'JOURNAL_INVALID' })
    }

    if ($null -eq $Instance -or $Instance -is [Array] -or $Instance -isnot [pscustomobject]) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The selected instance is invalid.' -Data (@{ Code = 'INSTANCE_INVALID' })
    }
    $indexProperty = $Instance.PSObject.Properties['Index']
    if ($null -eq $indexProperty -or
        ($indexProperty.Value -isnot [string] -and $indexProperty.Value -isnot [int] -and $indexProperty.Value -isnot [long])) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The selected instance is invalid.' -Data (@{ Code = 'INSTANCE_INVALID' })
    }
    $sourceIndex = 0
    if (-not [int]::TryParse([string]$indexProperty.Value, [ref]$sourceIndex) -or $sourceIndex -lt 0) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The selected instance is invalid.' -Data (@{ Code = 'INSTANCE_INVALID' })
    }

    $versionProperty = $Instance.PSObject.Properties['AndroidVersion']
    $sourceVersion = $null
    if ($null -ne $versionProperty) {
        $sourceVersion = ConvertTo-ToolkitAndroidVersion -Value $versionProperty.Value
    }
    if ($sourceVersion -cne '12.0') {
        return New-ToolkitRootFailure -Journal $Journal -Message 'Android 12 root requires an Android 12 instance. Android 15 instances use the built-in KernelSU workflow.' -Data (@{
                Code = 'ANDROID_VERSION_UNSUPPORTED'
                AndroidVersion = [string]$sourceVersion
            })
    }

    $installProperty = $Instance.PSObject.Properties['Install']
    if ($null -eq $installProperty -or $null -eq $installProperty.Value -or $installProperty.Value -isnot [pscustomobject]) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The selected instance is invalid.' -Data (@{ Code = 'INSTANCE_INVALID' })
    }
    $installRootProperty = $installProperty.Value.PSObject.Properties['InstallRoot']
    $installManagerProperty = $installProperty.Value.PSObject.Properties['ManagerPath']
    $installVmsProperty = $installProperty.Value.PSObject.Properties['VmsPath']
    if ($null -eq $installRootProperty -or $installRootProperty.Value -isnot [string] -or
        $null -eq $installManagerProperty -or $installManagerProperty.Value -isnot [string] -or
        $null -eq $installVmsProperty -or $installVmsProperty.Value -isnot [string]) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The selected instance install is invalid.' -Data (@{ Code = 'INSTANCE_INVALID' })
    }
    $installRoot = ConvertTo-ToolkitFullPath -Path $installRootProperty.Value
    $manager = ConvertTo-ToolkitFullPath -Path $installManagerProperty.Value
    $vmsPath = ConvertTo-ToolkitFullPath -Path $installVmsProperty.Value
    if ($null -eq $manager -or $null -eq $installRoot -or
        -not (Test-ToolkitManagerFile -Path $manager -InstallRoot $installRoot)) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The MuMu manager is not a valid manager inside the selected install root.' -Data (@{ Code = 'MANAGER_UNAVAILABLE' })
    }
    if ($null -eq $vmsPath -or -not (Test-Path -LiteralPath $vmsPath -PathType Container)) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The selected instance VMS path is unavailable.' -Data (@{ Code = 'INSTANCE_INVALID' })
    }

    # The confirmation gate is placed before the dependency work on purpose. A run that stops for a
    # missing confirmation has not been authorized yet, so it must not reach the network or write to the
    # per-user asset cache, and it must not be the run that fails because a download could not happen.
    if (-not $Interactive) {
        return New-ToolkitRootFailure -Journal $Journal -Message ('USER_CONFIRMATION_REQUIRED: The Kitsune install into the system partition must be confirmed by the operator, and only ' + $script:ToolkitKitsunePrompt + ' is accepted. No instance was changed and the dependency cache was not touched.') -Data (@{ Code = 'USER_CONFIRMATION_REQUIRED' })
    }

    $asset = Prepare-Android12Asset -Manifest $Manifest -CacheRoot $CacheRoot -RequireCached:$RequireCachedAsset
    if ($asset.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message $asset.Message -Data $asset.Data
    }
    $installCommand = Format-Android12InstallCommand -Path ([string]$asset.Data)
    if ($installCommand.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message $installCommand.Message -Data $installCommand.Data
    }
    $apkInstallCommand = [string]$installCommand.Data
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message 'The pinned Kitsune asset was verified by size and SHA-256 after the operator confirmation and before any instance change.' -Data (@{ Asset = [string]$asset.Data })
    }
    catch {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The verified Kitsune asset could not be journaled.' -Data (@{ Code = 'JOURNAL_WRITE_FAILED' })
    }

    # The run authorization is checked here, before the clone, and not only against the interactive flag
    # above. A resume still revalidates its recorded clone, so authorizing it costs nothing and refusing it
    # changes nothing.
    if (-not $RunConfirmed) {
        return New-ToolkitRootFailure -Journal $Journal -Message ('USER_CONFIRMATION_REQUIRED: The Android 12 root copies the instance and installs the pinned Kitsune release, so it must be confirmed before the copy is made. No instance was created or changed and the dependency cache was not touched.') -Data (@{ Code = 'USER_CONFIRMATION_REQUIRED' })
    }

    $cloneIndex = -1
    $cloneName = ''
    if ($null -ne $ResumeClone) {
        $resumeCheck = Assert-AndroidResumeClone -ManagerPath $manager -VmsPath $vmsPath -Record $ResumeClone -ExpectedVersion '12.0' -Runner $Runner
        if ($resumeCheck.Status -ne 'Success') {
            return New-ToolkitRootFailure -Journal $Journal -Message $resumeCheck.Message -Data (New-Android12Recovery -Code ([string]$resumeCheck.Data.Code) -Step 'resume' -SourceIndex $sourceIndex -CloneIndex ([int](Get-Android12RecordField -Record $resumeCheck.Data -Name 'CloneIndex')) -CloneName ([string](Get-Android12RecordField -Record $resumeCheck.Data -Name 'CloneName')))
        }
        $cloneIndex = [int]$resumeCheck.Data.CloneIndex
        $cloneName = [string]$resumeCheck.Data.CloneName
        $resumeMessage = "The Android 12 root workflow resumed on the verified clone at index $cloneIndex. Its identity, Android version, installation boundary, and disk were revalidated and no second clone was created."
    }
    else {
        $clone = New-InstanceClone -ManagerPath $manager -Instance $Instance -Journal $Journal -Runner $Runner
        if ($null -eq $clone -or $clone -isnot [pscustomobject] -or $null -eq $clone.PSObject.Properties['Status'] -or
            [string]$clone.Status -ne 'Success') {
            return New-ToolkitRootFailure -Journal $Journal -Message 'The MuMu manager did not report a verified instance clone.' -Data (@{ Code = 'CLONE_UNVERIFIED' })
        }
        $resolvedClone = Resolve-Android12Clone -CloneResult $clone -Journal $Journal
        if ($resolvedClone.Status -ne 'Success') {
            return $resolvedClone
        }
        $cloneIndex = [int]$resolvedClone.Data.CloneIndex
        $cloneName = [string]$resolvedClone.Data.CloneName
        $resumeMessage = "The Android 12 root workflow continues on the clone at index $cloneIndex, which is the only instance it will reconfigure. The selected instance at index $sourceIndex is only stopped for the clone."
    }
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message $resumeMessage -Data (New-Android12Recovery -Code 'OK' -Step 'clone' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    catch {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The verified clone could not be journaled.' -Data (New-Android12Recovery -Code 'JOURNAL_WRITE_FAILED' -Step 'clone' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }

    $previousRootSetting = Get-ToolkitRootSetting -ManagerPath $manager -Index $cloneIndex -Runner $Runner
    if ($previousRootSetting.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message ('The clone vendor root setting could not be read before the temporary vendor root was enabled, so nothing was changed. ' + $previousRootSetting.Message) -Data (New-Android12Recovery -Code 'VENDOR_ROOT_SETTING_UNREADABLE' -Step 'vendor-root-read' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    $previousRootValue = [bool]$previousRootSetting.Data.Value
    $enableRoot = Invoke-CheckedProcess -FilePath $manager -ArgumentList @('setting', '-v', ([string]$cloneIndex), '-k', 'root_permission', '-val', 'true') -Runner $Runner
    if ($null -eq $enableRoot -or $enableRoot.ExitCode -ne 0) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The temporary vendor root could not be enabled on the clone.' -Data (New-Android12Recovery -Code 'VENDOR_ROOT_ENABLE_FAILED' -Step 'vendor-root-enable' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    $writableSystem = Invoke-CheckedProcess -FilePath $manager -ArgumentList @('setting', '-v', ([string]$cloneIndex), '-k', 'system_disk_readonly', '-val', 'false') -Runner $Runner
    if ($null -eq $writableSystem -or $writableSystem.ExitCode -ne 0) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The clone system disk could not be made writable, which Kitsune needs for a system partition install. The temporary vendor root was left enabled.' -Data (New-Android12Recovery -Code 'SYSTEM_DISK_ENABLE_FAILED' -Step 'vendor-root-enable' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    $enabledSettings = Get-ToolkitInstanceSettings -ManagerPath $manager -Index $cloneIndex -Keys @('root_permission', 'system_disk_readonly') -Runner $Runner
    if ($enabledSettings.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message ('The clone did not report readable preparation settings after the change. ' + $enabledSettings.Message) -Data (New-Android12Recovery -Code 'VENDOR_ROOT_SETTING_UNREADABLE' -Step 'vendor-root-enable' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    $enabledRootValue = Get-ToolkitRecordValue -Record $enabledSettings.Data -PropertyNames @('root_permission')
    if ($enabledRootValue -ne $true) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The clone did not report the enabled vendor root after the change.' -Data (New-Android12Recovery -Code 'VENDOR_ROOT_NOT_ENABLED' -Step 'vendor-root-enable' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    $enabledSystemDiskValue = Get-ToolkitRecordValue -Record $enabledSettings.Data -PropertyNames @('system_disk_readonly')
    if ($enabledSystemDiskValue -ne $false) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The clone still reports a read-only system disk, so Kitsune cannot install into the system partition. The temporary vendor root was left enabled.' -Data (New-Android12Recovery -Code 'SYSTEM_DISK_NOT_WRITABLE' -Step 'vendor-root-enable' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message 'The temporary vendor root is enabled on the clone and its system disk is writable, which Kitsune needs for a system partition install. The vendor root is disabled again only after root verification.' -Data (@{
                PreviousRootSetting = [string]$previousRootValue
                RootSetting = 'true'
                SystemDiskReadonly = 'false'
            })
    }
    catch {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The enabled preparation settings could not be journaled.' -Data (New-Android12Recovery -Code 'JOURNAL_WRITE_FAILED' -Step 'vendor-root-enable' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }

    $preInstallLaunch = Invoke-CheckedProcess -FilePath $manager -ArgumentList @('control', '-v', ([string]$cloneIndex), 'launch') -Runner $Runner
    if ($null -eq $preInstallLaunch -or $preInstallLaunch.ExitCode -ne 0) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The clone did not accept the launch request that precedes the APK install, so the verified APK was not installed. The temporary vendor root was left enabled.' -Data (New-Android12Recovery -Code 'PREINSTALL_LAUNCH_FAILED' -Step 'preinstall-launch' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    $bootWait = Wait-ToolkitBootCompleted -ManagerPath $manager -InstanceIndex $cloneIndex -Runner $Runner
    if ([string]$bootWait.Code -cne 'BOOTED') {
        return New-ToolkitRootFailure -Journal $Journal -Message "The clone did not report sys.boot_completed=1 before $($bootWait.Bound) ended the wait, so the verified APK was not installed. The temporary vendor root was left enabled." -Data (New-Android12Recovery -Code 'PREINSTALL_BOOT_TIMEOUT' -Step 'preinstall-launch' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message 'The clone was launched and reported sys.boot_completed=1 before the APK install, because the MuMu manager rejects ADB on a stopped instance.' -Data (New-Android12Recovery -Code 'OK' -Step 'preinstall-launch' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    catch {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The pre-install clone launch could not be journaled.' -Data (New-Android12Recovery -Code 'JOURNAL_WRITE_FAILED' -Step 'preinstall-launch' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }

    $apkInstall = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $cloneIndex -Command $apkInstallCommand -Runner $Runner
    if ($null -eq $apkInstall -or $apkInstall.ExitCode -ne 0) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The verified Kitsune APK was not installed on the clone.' -Data (New-Android12Recovery -Code 'APK_INSTALL_FAILED' -Step 'apk-install' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message 'The verified Kitsune APK was installed on the clone.' -Data (@{ Command = $apkInstallCommand })
    }
    catch {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The installed Kitsune APK could not be journaled.' -Data (New-Android12Recovery -Code 'JOURNAL_WRITE_FAILED' -Step 'apk-install' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }

    $apkLaunch = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $cloneIndex -Command $script:ToolkitKitsuneLaunchCommand -Runner $Runner
    if ($null -eq $apkLaunch -or $apkLaunch.ExitCode -ne 0) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The installed Kitsune app did not start on the clone. Open it from the emulator and repeat the guided install.' -Data (New-Android12Recovery -Code 'APK_LAUNCH_FAILED' -Step 'apk-launch' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }

    # The prompt answers the wrong question if it only names the app option: the operator is asked to
    # type something here, and this is the second gate, so the word CONFIRM that released the first one
    # is rejected here. The exact answer is named in the prompt because the match is case sensitive, and
    # a prompt that hides what to type strands the operator at a gate they cannot pass.
    $promptText = 'Kitsune: in the app on the clone, choose ' + $script:ToolkitKitsunePrompt + '. Not the ordinary Direct Install and not Select and Patch a File. If the system-partition option is not shown, close the Kitsune app and open it again. Once you have made that choice here, type CONFIRM (or the full option text, ' + $script:ToolkitKitsuneChoice + ')'
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message "In the Kitsune app choose $promptText The workflow is paused until the operator confirms that exact choice." -Data (@{
                Prompt = $promptText
                Rejection = $script:ToolkitKitsuneRejection
                CloneIndex = $cloneIndex
            })
    }
    catch {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The Kitsune system-partition instruction could not be journaled.' -Data (New-Android12Recovery -Code 'JOURNAL_WRITE_FAILED' -Step 'confirmation' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }

    $answer = $Confirmation
    if ([string]::IsNullOrWhiteSpace($answer)) {
        $promptScript = $Prompt
        if ($null -eq $promptScript) {
            $promptScript = $script:ToolkitKitsuneDefaultPrompt
        }
        try {
            $answer = [string](& $promptScript $promptText)
        }
        catch {
            $answer = ''
        }
    }
    if (-not (Test-KitsuneConfirmation -Confirmation $answer)) {
        return New-ToolkitRootFailure -Journal $Journal -Message ('USER_CONFIRMATION_REQUIRED: Only ' + $script:ToolkitKitsuneChoice + ' is accepted, and it was not confirmed. The cold boot, the root verification, and the vendor root change were not started. Boot the reported clone to recover, then resume this workflow on that clone.') -Data (New-Android12Recovery -Code 'USER_CONFIRMATION_REQUIRED' -Step 'confirmation' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }

    # The cold boot below is silent for minutes, and a silent console reads as a hang. The operator has
    # already answered every question, so the line says what is happening and, more importantly, that
    # nothing is required from them: they must not type a word to release the wait, because the wait ends
    # on the guest reporting sys.boot_completed=1 or on the bound, and never on an answer. A machine run
    # has nobody to reassure, so the journal is the only place the fact is recorded.
    if ($Interactive -and (Get-Command Write-ToolkitConsoleLine -CommandType Function -ErrorAction SilentlyContinue)) {
        Write-ToolkitConsoleLine ('  The clone at index ' + [string]$cloneIndex + ' (' + $cloneName + ') is rebooting now. This is automatic: nothing else is needed from you, and no word will release the wait. The root is checked as soon as the guest reports it finished booting.')
    }
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message "The Kitsune system-partition install was confirmed, so the clone is cold-booted and the root is verified without any further operator answer." -Data @{
                CloneIndex = $cloneIndex
                CloneName = $cloneName
            }
    }
    catch {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The cold boot notice could not be journaled.' -Data (New-Android12Recovery -Code 'JOURNAL_WRITE_FAILED' -Step 'cold-boot-notice' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }

    $shutdown = Invoke-CheckedProcess -FilePath $manager -ArgumentList @('control', '-v', ([string]$cloneIndex), 'shutdown') -Runner $Runner
    if ($null -eq $shutdown -or $shutdown.ExitCode -ne 0) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The clone did not accept the cold-boot shutdown request.' -Data (New-Android12Recovery -Code 'BOOT_CONTROL_FAILED' -Step 'cold-boot' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    if (-not (Wait-MuMuInstanceStopped -ManagerPath $manager -Index $cloneIndex -Runner $Runner)) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The clone did not reach a stable stopped state before the cold boot.' -Data (New-Android12Recovery -Code 'STOP_TIMEOUT' -Step 'cold-boot' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    $launch = Invoke-CheckedProcess -FilePath $manager -ArgumentList @('control', '-v', ([string]$cloneIndex), 'launch') -Runner $Runner
    if ($null -eq $launch -or $launch.ExitCode -ne 0) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The clone did not accept the cold-boot launch request.' -Data (New-Android12Recovery -Code 'BOOT_CONTROL_FAILED' -Step 'cold-boot' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    $coldBootWait = Wait-ToolkitBootCompleted -ManagerPath $manager -InstanceIndex $cloneIndex -Runner $Runner
    if ([string]$coldBootWait.Code -cne 'BOOTED') {
        return New-ToolkitRootFailure -Journal $Journal -Message "The clone did not report sys.boot_completed=1 before $($coldBootWait.Bound) ended the wait. The Kitsune root state is unknown and the vendor root was left enabled." -Data (New-Android12Recovery -Code 'BOOT_TIMEOUT' -Step 'cold-boot' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }

    $checks = Test-Android12Root -ManagerPath $manager -InstanceIndex $cloneIndex -Runner $Runner
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message 'The Android 12 package, root daemon, and root shell checks were recorded.' -Data $checks.Data
    }
    catch {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The Android 12 root checks could not be journaled.' -Data (New-Android12Recovery -Code 'JOURNAL_WRITE_FAILED' -Step 'verification' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName)
    }
    if ($checks.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message ('The Android 12 root is not verified, so the temporary vendor root was left enabled. ' + $checks.Message) -Data (New-Android12Recovery -Code ([string]$checks.Data.Code) -Step 'verification' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName -Checks $checks.Data)
    }

    $disableRoot = Invoke-CheckedProcess -FilePath $manager -ArgumentList @('setting', '-v', ([string]$cloneIndex), '-k', 'root_permission', '-val', 'false') -Runner $Runner
    if ($null -eq $disableRoot -or $disableRoot.ExitCode -ne 0) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The Kitsune root is verified, but the temporary vendor root could not be disabled on the clone.' -Data (New-Android12Recovery -Code 'VENDOR_ROOT_DISABLE_FAILED' -Step 'vendor-root-disable' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName -Checks $checks.Data)
    }
    $finalSetting = Get-ToolkitRootSetting -ManagerPath $manager -Index $cloneIndex -Runner $Runner
    if ($finalSetting.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message ('The Kitsune root is verified, but the clone vendor root setting is no longer readable. ' + $finalSetting.Message) -Data (New-Android12Recovery -Code 'VENDOR_ROOT_SETTING_UNREADABLE' -Step 'vendor-root-disable' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName -Checks $checks.Data)
    }
    if ($finalSetting.Data.Value -ne $false) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The Kitsune root is verified, but the clone still reports the enabled vendor root.' -Data (New-Android12Recovery -Code 'VENDOR_ROOT_NOT_DISABLED' -Step 'vendor-root-disable' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName -Checks $checks.Data)
    }

    $cleanupChecks = Test-Android12Root -ManagerPath $manager -InstanceIndex $cloneIndex -Runner $Runner
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message 'The Android 12 package, root daemon, and root shell checks were repeated after the temporary vendor root was disabled, because disabling it can remove the root shell.' -Data $cleanupChecks.Data
    }
    catch {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The Android 12 root checks after the temporary vendor root was disabled could not be journaled.' -Data (New-Android12Recovery -Code 'JOURNAL_WRITE_FAILED' -Step 'post-cleanup-verification' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName -Checks $cleanupChecks.Data)
    }
    if ($cleanupChecks.Status -ne 'Success') {
        return Restore-Android12VendorRoot -ManagerPath $manager -CloneIndex $cloneIndex -SourceIndex $sourceIndex -CloneName $cloneName -CleanupChecks $cleanupChecks -Journal $Journal -Runner $Runner
    }

    $successData = New-Android12Recovery -Code 'OK' -Step 'complete' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName -Checks $cleanupChecks.Data
    $successData['PackageName'] = $script:ToolkitKitsunePackageName
    $successMessage = "Android 12 Kitsune root is verified on the clone at index $cloneIndex, the temporary vendor root on that clone is disabled, and the root was checked again after the temporary vendor root was disabled."
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message $successMessage -Data $successData
        Complete-OperationJournal -Journal $Journal -Result (Get-ToolkitResult -Status 'Success' -Message $successMessage -Data $successData)
    }
    catch {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The verified Android 12 root could not be journaled.' -Data (New-Android12Recovery -Code 'JOURNAL_WRITE_FAILED' -Step 'complete' -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName -Checks $checks.Data)
    }
    return Get-ToolkitResult -Status 'Success' -Message $successMessage -Data $successData
}
