$script:ToolkitKitsuneAssetId = 'kitsune'
$script:ToolkitKitsunePackageName = 'io.github.huskydg.magisk'
$script:ToolkitKitsuneVersionName = '31.0-kitsune'
$script:ToolkitKitsuneVersionCode = '31000'
$script:ToolkitKitsunePrompt = 'Install -> Direct Install into system partition'
$script:ToolkitKitsuneChoice = 'Direct Install into system partition'
$script:ToolkitKitsuneRejection = 'Do not choose the ordinary Direct Install or Select and Patch a File option.'
$script:ToolkitBootPollAttempts = 30
$script:ToolkitBootPollDelaySeconds = 3

function Get-Android12KitsunePrompt {
    return $script:ToolkitKitsunePrompt
}

function Test-KitsuneConfirmation {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Confirmation
    )

    return ($Confirmation -ceq $script:ToolkitKitsuneChoice)
}

function Invoke-Android12Adb {
    param(
        [string]$ManagerPath,
        [int]$InstanceIndex,
        [string[]]$Command,
        [scriptblock]$Runner = $null
    )

    $argumentList = New-Object 'System.Collections.Generic.List[string]'
    foreach ($argument in @(@('adb', '-v', ([string]$InstanceIndex), '-c') + @($Command))) {
        [void]$argumentList.Add([string]$argument)
    }
    return Invoke-CheckedProcess -FilePath $ManagerPath -ArgumentList $argumentList.ToArray() -Runner $Runner
}

function New-Android12Recovery {
    param(
        [int]$SourceIndex,
        [int]$CloneIndex = -1,
        [string]$CloneName = ''
    )

    return @{
        Code = 'UNKNOWN'
        Step = ''
        SourceIndex = $SourceIndex
        CloneIndex = $CloneIndex
        CloneName = $CloneName
        RootVerified = $false
        VersionName = ''
        VersionCode = ''
        DaemonCount = 0
    }
}

function New-Android12RootFailure {
    param(
        [object]$Journal,
        [string]$Message,
        [object]$Data = $null
    )

    $message = Protect-ToolkitText $Message
    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = 'The Android 12 root workflow failed.'
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

    $packageCall = Invoke-Android12Adb -ManagerPath $manager -InstanceIndex $InstanceIndex -Command @('shell', ('dumpsys package ' + $script:ToolkitKitsunePackageName)) -Runner $Runner
    if ($null -eq $packageCall -or $packageCall.ExitCode -ne 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The Kitsune package query failed.' -Data (@{ Code = 'ADB_FAILED' })
    }
    $packageText = [string]$packageCall.Text
    $nameMatch = [regex]::Match($packageText, '(?m)^\s*versionName=(\S+)')
    $codeMatch = [regex]::Match($packageText, '(?m)^\s*versionCode=(\d+)\b')
    if (-not $nameMatch.Success -or -not $codeMatch.Success) {
        return Get-ToolkitResult -Status 'CriticalError' -Message "The Kitsune package $script:ToolkitKitsunePackageName is not installed." -Data (@{
                Code = 'PACKAGE_MISSING'
                PackageName = $script:ToolkitKitsunePackageName
                VersionName = ''
                VersionCode = ''
                DaemonCount = 0
                RootVerified = $false
            })
    }
    $versionName = $nameMatch.Groups[1].Value
    $versionCode = $codeMatch.Groups[1].Value
    if ($versionName -cne $script:ToolkitKitsuneVersionName -or $versionCode -cne $script:ToolkitKitsuneVersionCode) {
        return Get-ToolkitResult -Status 'CriticalError' -Message "The installed package is not the pinned Kitsune release $script:ToolkitKitsuneVersionName." -Data (@{
                Code = 'PACKAGE_VERSION_MISMATCH'
                PackageName = $script:ToolkitKitsunePackageName
                VersionName = $versionName
                VersionCode = $versionCode
                DaemonCount = 0
                RootVerified = $false
            })
    }

    $daemonCall = Invoke-Android12Adb -ManagerPath $manager -InstanceIndex $InstanceIndex -Command @('shell', 'pidof magiskd') -Runner $Runner
    if ($null -eq $daemonCall -or $daemonCall.ExitCode -ne 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The Kitsune root daemon query failed.' -Data (@{ Code = 'ADB_FAILED' })
    }
    $daemonPids = @(([string]$daemonCall.Text) -split '\s+' | Where-Object { $_ })
    if ($daemonPids.Count -eq 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The Kitsune root daemon is not running.' -Data (@{
                Code = 'DAEMON_ABSENT'
                PackageName = $script:ToolkitKitsunePackageName
                VersionName = $versionName
                VersionCode = $versionCode
                DaemonCount = 0
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
                RootVerified = $false
            })
    }

    $rootCall = Invoke-Android12Adb -ManagerPath $manager -InstanceIndex $InstanceIndex -Command @('shell', 'su -c id') -Runner $Runner
    $rootVerified = ($null -ne $rootCall -and $rootCall.ExitCode -eq 0 -and ([string]$rootCall.Text) -match '(?m)uid=0\(')
    if (-not $rootVerified) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The Kitsune root shell did not return a root identity.' -Data (@{
                Code = 'ROOT_DENIED'
                PackageName = $script:ToolkitKitsunePackageName
                VersionName = $versionName
                VersionCode = $versionCode
                DaemonCount = $daemonPids.Count
                RootVerified = $false
            })
    }

    return Get-ToolkitResult -Status 'Success' -Message 'The Android 12 Kitsune root is verified.' -Data (@{
            Code = 'OK'
            PackageName = $script:ToolkitKitsunePackageName
            VersionName = $versionName
            VersionCode = $versionCode
            DaemonCount = $daemonPids.Count
            RootVerified = $true
        })
}

function Wait-Android12BootCompleted {
    param(
        [string]$ManagerPath,
        [int]$InstanceIndex,
        [scriptblock]$Runner = $null
    )

    for ($attempt = 1; $attempt -le $script:ToolkitBootPollAttempts; $attempt++) {
        $probe = Invoke-Android12Adb -ManagerPath $ManagerPath -InstanceIndex $InstanceIndex -Command @('shell', 'getprop sys.boot_completed') -Runner $Runner
        if ($null -ne $probe -and $probe.ExitCode -eq 0 -and ([string]$probe.Text).Trim() -ceq '1') {
            return $true
        }
        if ($attempt -lt $script:ToolkitBootPollAttempts) {
            Start-Sleep -Seconds $script:ToolkitBootPollDelaySeconds
        }
    }
    return $false
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
        [scriptblock]$Runner = $null
    )

    try {
        Assert-OperationJournal $Journal
    }
    catch {
        return New-Android12RootFailure -Journal $null -Message 'The Android 12 root journal is invalid.' -Data (@{ Code = 'JOURNAL_INVALID' })
    }

    if ($null -eq $Instance -or $Instance -is [Array] -or $Instance -isnot [pscustomobject]) {
        return New-Android12RootFailure -Journal $Journal -Message 'The selected instance is invalid.' -Data (@{ Code = 'INSTANCE_INVALID' })
    }
    $indexProperty = $Instance.PSObject.Properties['Index']
    if ($null -eq $indexProperty -or
        ($indexProperty.Value -isnot [string] -and $indexProperty.Value -isnot [int] -and $indexProperty.Value -isnot [long])) {
        return New-Android12RootFailure -Journal $Journal -Message 'The selected instance is invalid.' -Data (@{ Code = 'INSTANCE_INVALID' })
    }
    $sourceIndex = 0
    if (-not [int]::TryParse([string]$indexProperty.Value, [ref]$sourceIndex) -or $sourceIndex -lt 0) {
        return New-Android12RootFailure -Journal $Journal -Message 'The selected instance is invalid.' -Data (@{ Code = 'INSTANCE_INVALID' })
    }

    $versionProperty = $Instance.PSObject.Properties['AndroidVersion']
    $sourceVersion = $null
    if ($null -ne $versionProperty) {
        $sourceVersion = ConvertTo-ToolkitAndroidVersion -Value $versionProperty.Value
    }
    if ($sourceVersion -cne '12.0') {
        return New-Android12RootFailure -Journal $Journal -Message 'Android 12 root requires an Android 12 instance. Android 15 instances use the built-in KernelSU workflow.' -Data (@{
                Code = 'ANDROID_VERSION_UNSUPPORTED'
                AndroidVersion = [string]$sourceVersion
            })
    }

    $installProperty = $Instance.PSObject.Properties['Install']
    if ($null -eq $installProperty -or $null -eq $installProperty.Value -or $installProperty.Value -isnot [pscustomobject]) {
        return New-Android12RootFailure -Journal $Journal -Message 'The selected instance is invalid.' -Data (@{ Code = 'INSTANCE_INVALID' })
    }
    $installRootProperty = $installProperty.Value.PSObject.Properties['InstallRoot']
    $installManagerProperty = $installProperty.Value.PSObject.Properties['ManagerPath']
    if ($null -eq $installRootProperty -or $installRootProperty.Value -isnot [string] -or
        $null -eq $installManagerProperty -or $installManagerProperty.Value -isnot [string]) {
        return New-Android12RootFailure -Journal $Journal -Message 'The selected instance install is invalid.' -Data (@{ Code = 'INSTANCE_INVALID' })
    }
    $installRoot = ConvertTo-ToolkitFullPath -Path $installRootProperty.Value
    $manager = ConvertTo-ToolkitFullPath -Path $installManagerProperty.Value
    if ($null -eq $manager -or $null -eq $installRoot -or
        -not (Test-ToolkitManagerFile -Path $manager -InstallRoot $installRoot)) {
        return New-Android12RootFailure -Journal $Journal -Message 'The MuMu manager is not a valid manager inside the selected install root.' -Data (@{ Code = 'MANAGER_UNAVAILABLE' })
    }

    $assetCacheRoot = $CacheRoot
    if ([string]::IsNullOrWhiteSpace($assetCacheRoot)) {
        try {
            $assetCacheRoot = Get-ToolkitAssetCacheRoot
        }
        catch {
            return New-Android12RootFailure -Journal $Journal -Message 'The dependency cache root is unavailable.' -Data (@{ Code = 'CACHE_UNAVAILABLE' })
        }
    }
    $asset = Save-ToolkitAsset -Manifest $Manifest -Id $script:ToolkitKitsuneAssetId -CacheRoot $assetCacheRoot
    if ($asset.Status -ne 'Success') {
        return New-Android12RootFailure -Journal $Journal -Message ('The pinned Kitsune asset was not verified. ' + $asset.Message) -Data (@{ Code = 'ASSET_VERIFICATION_FAILED' })
    }
    $assetPath = [string]$asset.Data
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message 'The pinned Kitsune asset was verified by size and SHA-256 before any instance change.' -Data (@{ Asset = $assetPath })
    }
    catch {
        return New-Android12RootFailure -Journal $Journal -Message 'The verified Kitsune asset could not be journaled.' -Data (@{ Code = 'ASSET_VERIFICATION_FAILED' })
    }

    if (-not $Interactive) {
        return New-Android12RootFailure -Journal $Journal -Message ('USER_CONFIRMATION_REQUIRED: The Kitsune install into the system partition must be confirmed by the operator, and only ' + $script:ToolkitKitsunePrompt + ' is accepted. No instance was changed.') -Data (@{ Code = 'USER_CONFIRMATION_REQUIRED' })
    }

    $clone = New-InstanceClone -ManagerPath $manager -Instance $Instance -Journal $Journal -Runner $Runner
    if ($clone.Status -ne 'Success' -or $null -eq $clone.Data) {
        return $clone
    }
    $cloneIndex = 0
    if (-not [int]::TryParse([string]$clone.Data.CloneIndex, [ref]$cloneIndex) -or $cloneIndex -lt 0) {
        return New-Android12RootFailure -Journal $Journal -Message 'The verified clone index is invalid.' -Data (@{ Code = 'CLONE_INVALID'; SourceIndex = $sourceIndex })
    }
    $cloneName = [string]$clone.Data.CloneName
    $recovery = New-Android12Recovery -SourceIndex $sourceIndex -CloneIndex $cloneIndex -CloneName $cloneName
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message "The clone at index $cloneIndex is the only instance this workflow will change. The selected instance at index $sourceIndex is left untouched." -Data $recovery
    }
    catch {
        return New-Android12RootFailure -Journal $Journal -Message 'The verified clone could not be journaled.' -Data $recovery
    }

    $previousRootSetting = Get-MuMuRootSetting -ManagerPath $manager -Index $cloneIndex -InfoRecord ([pscustomobject]@{}) -Runner $Runner
    $enableRoot = Invoke-CheckedProcess -FilePath $manager -ArgumentList @('setting', '-v', ([string]$cloneIndex), '-k', 'root_permission', '-val', 'true') -Runner $Runner
    if ($null -eq $enableRoot -or $enableRoot.ExitCode -ne 0) {
        $recovery.Code = 'VENDOR_ROOT_ENABLE_FAILED'
        $recovery.Step = 'vendor-root-enable'
        return New-Android12RootFailure -Journal $Journal -Message 'The temporary vendor root could not be enabled on the clone.' -Data $recovery
    }
    if ((Get-MuMuRootSetting -ManagerPath $manager -Index $cloneIndex -InfoRecord ([pscustomobject]@{}) -Runner $Runner) -ne $true) {
        $recovery.Code = 'VENDOR_ROOT_NOT_ENABLED'
        $recovery.Step = 'vendor-root-enable'
        return New-Android12RootFailure -Journal $Journal -Message 'The clone did not report the enabled vendor root after the change.' -Data $recovery
    }
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message 'The temporary vendor root is enabled on the clone and is disabled again only after root verification.' -Data (@{
                PreviousRootSetting = [string]$previousRootSetting
                RootSetting = 'true'
            })
    }
    catch {
        return New-Android12RootFailure -Journal $Journal -Message 'The enabled vendor root could not be journaled.' -Data $recovery
    }

    $apkInstall = Invoke-Android12Adb -ManagerPath $manager -InstanceIndex $cloneIndex -Command @('install', '-r', $assetPath) -Runner $Runner
    if ($null -eq $apkInstall -or $apkInstall.ExitCode -ne 0) {
        $recovery.Code = 'APK_INSTALL_FAILED'
        $recovery.Step = 'apk-install'
        return New-Android12RootFailure -Journal $Journal -Message 'The verified Kitsune APK was not installed on the clone.' -Data $recovery
    }
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message 'The verified Kitsune APK was installed on the clone.' -Data (@{ Asset = $assetPath })
    }
    catch {
        return New-Android12RootFailure -Journal $Journal -Message 'The installed Kitsune APK could not be journaled.' -Data $recovery
    }

    $prompt = Get-Android12KitsunePrompt
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message "In the Kitsune app choose $prompt. $($script:ToolkitKitsuneRejection) The workflow is paused until the operator confirms that exact choice." -Data (@{
                Prompt = $prompt
                Rejection = $script:ToolkitKitsuneRejection
                CloneIndex = $cloneIndex
            })
    }
    catch {
        return New-Android12RootFailure -Journal $Journal -Message 'The Kitsune system-partition instruction could not be journaled.' -Data $recovery
    }

    if (-not (Test-KitsuneConfirmation -Confirmation $Confirmation)) {
        $recovery.Code = 'USER_CONFIRMATION_REQUIRED'
        $recovery.Step = 'confirmation'
        return New-Android12RootFailure -Journal $Journal -Message ('USER_CONFIRMATION_REQUIRED: Only ' + $prompt + ' is accepted, and it was not confirmed. The cold boot, the root verification, and the vendor root change were not started. Boot the reported clone to recover.') -Data $recovery
    }

    $shutdown = Invoke-CheckedProcess -FilePath $manager -ArgumentList @('control', '-v', ([string]$cloneIndex), 'shutdown') -Runner $Runner
    if ($null -eq $shutdown -or $shutdown.ExitCode -ne 0) {
        $recovery.Code = 'BOOT_CONTROL_FAILED'
        $recovery.Step = 'cold-boot'
        return New-Android12RootFailure -Journal $Journal -Message 'The clone did not accept the cold-boot shutdown request.' -Data $recovery
    }
    if (-not (Wait-MuMuInstanceStopped -ManagerPath $manager -Index $cloneIndex -Runner $Runner)) {
        $recovery.Code = 'STOP_TIMEOUT'
        $recovery.Step = 'cold-boot'
        return New-Android12RootFailure -Journal $Journal -Message 'The clone did not reach a stable stopped state before the cold boot.' -Data $recovery
    }
    $launch = Invoke-CheckedProcess -FilePath $manager -ArgumentList @('control', '-v', ([string]$cloneIndex), 'launch') -Runner $Runner
    if ($null -eq $launch -or $launch.ExitCode -ne 0) {
        $recovery.Code = 'BOOT_CONTROL_FAILED'
        $recovery.Step = 'cold-boot'
        return New-Android12RootFailure -Journal $Journal -Message 'The clone did not accept the cold-boot launch request.' -Data $recovery
    }
    if (-not (Wait-Android12BootCompleted -ManagerPath $manager -InstanceIndex $cloneIndex -Runner $Runner)) {
        $recovery.Code = 'BOOT_TIMEOUT'
        $recovery.Step = 'cold-boot'
        return New-Android12RootFailure -Journal $Journal -Message "The clone did not report sys.boot_completed=1 after $($script:ToolkitBootPollAttempts) checks. The Kitsune root state is unknown and the vendor root was left enabled." -Data $recovery
    }

    $checks = Test-Android12Root -ManagerPath $manager -InstanceIndex $cloneIndex -Runner $Runner
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message 'The Android 12 package, root daemon, and root shell checks were recorded.' -Data $checks.Data
    }
    catch {
        $recovery.Code = 'JOURNAL_WRITE_FAILED'
        $recovery.Step = 'verification'
        return New-Android12RootFailure -Journal $Journal -Message 'The Android 12 root checks could not be journaled.' -Data $recovery
    }
    if ($checks.Status -ne 'Success') {
        $recovery.Code = [string]$checks.Data.Code
        $recovery.Step = 'verification'
        return New-Android12RootFailure -Journal $Journal -Message ('The Android 12 root is not verified, so the temporary vendor root was left enabled. ' + $checks.Message) -Data $recovery
    }

    $recovery.RootVerified = [bool]$checks.Data.RootVerified
    $recovery.VersionName = [string]$checks.Data.VersionName
    $recovery.VersionCode = [string]$checks.Data.VersionCode
    $recovery.DaemonCount = [int]$checks.Data.DaemonCount
    $disableRoot = Invoke-CheckedProcess -FilePath $manager -ArgumentList @('setting', '-v', ([string]$cloneIndex), '-k', 'root_permission', '-val', 'false') -Runner $Runner
    if ($null -eq $disableRoot -or $disableRoot.ExitCode -ne 0) {
        $recovery.Code = 'VENDOR_ROOT_DISABLE_FAILED'
        $recovery.Step = 'vendor-root-disable'
        return New-Android12RootFailure -Journal $Journal -Message 'The Kitsune root is verified, but the temporary vendor root could not be disabled on the clone.' -Data $recovery
    }
    if ((Get-MuMuRootSetting -ManagerPath $manager -Index $cloneIndex -InfoRecord ([pscustomobject]@{}) -Runner $Runner) -ne $false) {
        $recovery.Code = 'VENDOR_ROOT_NOT_DISABLED'
        $recovery.Step = 'vendor-root-disable'
        return New-Android12RootFailure -Journal $Journal -Message 'The Kitsune root is verified, but the clone still reports the enabled vendor root.' -Data $recovery
    }

    $successData = @{
        Code = 'OK'
        SourceIndex = $sourceIndex
        CloneIndex = $cloneIndex
        CloneName = $cloneName
        PackageName = $script:ToolkitKitsunePackageName
        VersionName = [string]$checks.Data.VersionName
        VersionCode = [string]$checks.Data.VersionCode
        DaemonCount = [int]$checks.Data.DaemonCount
        RootVerified = $true
    }
    $successMessage = "Android 12 Kitsune root is verified on the clone at index $cloneIndex, and the temporary vendor root on that clone is disabled."
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message $successMessage -Data $successData
        Complete-OperationJournal -Journal $Journal -Result (Get-ToolkitResult -Status 'Success' -Message $successMessage -Data $successData)
    }
    catch {
        return New-Android12RootFailure -Journal $Journal -Message 'The verified Android 12 root could not be journaled.' -Data $successData
    }
    return Get-ToolkitResult -Status 'Success' -Message $successMessage -Data $successData
}
