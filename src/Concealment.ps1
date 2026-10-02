$script:ConcealmentHmaPackage = 'org.frknkrc44.hma_oss'
$script:ConcealmentHmaAssetId = 'hma'
$script:ConcealmentVectorAssetId = 'vector'
# Concealment declares exactly these two dependencies. NeoZygisk is a root-side module, not a
# concealment dependency, so it is not acquired or installed by this workflow.
$script:ConcealmentDependencyAssetIds = @($script:ConcealmentHmaAssetId, $script:ConcealmentVectorAssetId)
$script:ConcealmentKitsunePackage = 'io.github.huskydg.magisk'
$script:ConcealmentToolkitPackage = 'com.coderstory.toolkit'
$script:ConcealmentKernelSUPackage = 'me.weishu.kernelsu'
$script:ConcealmentTemplatePackages = @(
    'org.frknkrc44.hma_oss',
    'io.github.huskydg.magisk',
    'com.coderstory.toolkit',
    'me.weishu.kernelsu'
)
$script:ConcealmentConfigVersion = 93
$script:ConcealmentTemplateName = 'Root'
$script:ConcealmentConfigPath = '/data/user/0/org.frknkrc44.hma_oss/files/config.json'
$script:ConcealmentKernelSUAllowlistPath = '/data/adb/ksu/.allowlist'
$script:ConcealmentModuleRoot = '/data/adb/modules'
$script:ConcealmentVectorModuleName = 'zygisk_vector'
$script:ConcealmentVectorModulePath = '/data/adb/modules/zygisk_vector'
$script:ConcealmentGuestStagePath = '/data/local/tmp'
$script:ConcealmentPackageListCommand = 'shell pm list packages'
$script:ConcealmentPackagePattern = '^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)+$'
$script:ConcealmentMaximumPackageLength = 255
$script:ConcealmentJsonDepth = 12
$script:ConcealmentStateFields = @(
    'Code', 'Step', 'InstanceIndex', 'CloneIndex', 'CloneName', 'Packages', 'OutOfScope',
    'TemplateName', 'TemplatePackages', 'TemplateFound', 'IsWhitelist', 'HmaConfigVersion',
    'InScope', 'Installed', 'AlreadyPresent', 'InstalledCount', 'KernelSUInstalled',
    'AllowlistPresent', 'AllowlistLength', 'ProfileStateObserved', 'BackupPath',
    'BackupVerified', 'ConfigPath', 'Handoff', 'Command'
)
$script:ConcealmentUiHandoffSteps = @(
    'Open the Hide My Applist OSS app on the selected instance.',
    'Open Settings, then Create Template, then name the template Root and choose blacklist mode.',
    'Add the installed root packages to the Root template and apply it only to each selected app.',
    'Confirm the Root template is assigned to those apps and to no other app.'
)

function New-ConcealmentState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Code,
        [string]$Step = '',
        [int]$InstanceIndex = -1,
        [hashtable]$Fields = $null
    )

    $state = @{
        Code                 = $Code
        Step                 = $Step
        InstanceIndex        = $InstanceIndex
        CloneIndex           = -1
        CloneName            = ''
        Packages             = @()
        OutOfScope           = @()
        TemplateName         = [string]$script:ConcealmentTemplateName
        TemplatePackages     = @()
        TemplateFound        = $false
        IsWhitelist          = $false
        HmaConfigVersion     = -1
        InScope              = @()
        Installed            = @()
        AlreadyPresent       = @()
        KernelSUInstalled    = $false
        AllowlistPresent     = $false
        AllowlistLength      = -1
        ProfileStateObserved = $false
        BackupPath           = ''
        BackupVerified       = $false
        ConfigPath           = [string]$script:ConcealmentConfigPath
        Handoff              = @()
    }
    if ($null -ne $Fields) {
        foreach ($fieldName in $script:ConcealmentStateFields) {
            if ($Fields.Contains($fieldName)) {
                $state[$fieldName] = $Fields[$fieldName]
            }
        }
    }
    return $state
}

function New-ConcealmentHandoff {
    param(
        [object]$Journal,
        [hashtable]$State,
        [string]$Reason
    )

    $state = $State
    $state['Steps'] = @($script:ConcealmentUiHandoffSteps)
    $message = $Reason + ' No configuration was written and no app scope changed. Configure the supported UI instead: ' + (@($script:ConcealmentUiHandoffSteps) -join ' ')
    $result = Get-ToolkitResult -Status 'Warning' -Message $message -Data $state
    $journalState = $null
    if ($null -ne $Journal -and $null -ne $Journal.PSObject -and $null -ne $Journal.PSObject.Properties['State']) {
        $journalState = $Journal.State
    }
    if ($journalState -eq 'Running') {
        try {
            Write-JournalEvent -Journal $Journal -Level 'Warning' -Message $message -Data $state
            Complete-OperationJournal -Journal $Journal -Result $result
        }
        catch {
            return Get-ToolkitResult -Status 'CriticalError' -Message ($message + ' The supported-UI handoff could not be journaled.') -Data $state
        }
    }
    return $result
}

function Get-ConcealmentTextSha256 {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text
    )

    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return [BitConverter]::ToString($sha.ComputeHash((New-Object Text.UTF8Encoding($false)).GetBytes($Text))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-ConcealmentJsonDepth {
    param(
        [AllowNull()]
        [object]$Value,
        [int]$Level = 1
    )

    if ($Level -gt $script:ConcealmentJsonDepth) {
        return $Level
    }
    if ($Value -is [pscustomobject]) {
        $deepest = $Level
        foreach ($property in @($Value.PSObject.Properties)) {
            $child = Get-ConcealmentJsonDepth -Value $property.Value -Level ($Level + 1)
            if ($child -gt $deepest) {
                $deepest = $child
            }
        }
        return $deepest
    }
    if ($Value -is [Collections.IDictionary]) {
        $deepest = $Level
        foreach ($key in $Value.Keys) {
            $child = Get-ConcealmentJsonDepth -Value $Value[$key] -Level ($Level + 1)
            if ($child -gt $deepest) {
                $deepest = $child
            }
        }
        return $deepest
    }
    if ($Value -is [Array]) {
        $deepest = $Level
        foreach ($item in $Value) {
            $child = Get-ConcealmentJsonDepth -Value $item -Level ($Level + 1)
            if ($child -gt $deepest) {
                $deepest = $child
            }
        }
        return $deepest
    }
    return $Level
}

function Test-ConcealmentPackageName {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Name
    )

    if ($Name -isnot [string] -or [string]::IsNullOrWhiteSpace($Name) -or
        $Name.Length -gt $script:ConcealmentMaximumPackageLength) {
        return $false
    }
    return ($Name -cmatch $script:ConcealmentPackagePattern)
}

$script:ConcealmentGuestShellPrefix = ''

function New-ConcealmentGuestCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,
        [int]$InstanceIndex = -1,
        [string]$ShellPrefix = ''
    )

    if ([string]::IsNullOrWhiteSpace($ShellPrefix)) {
        $ShellPrefix = $script:ConcealmentGuestShellPrefix
    }
    if ([string]::IsNullOrWhiteSpace($ShellPrefix)) {
        $ShellPrefix = 'su'
    }

    # The shared funnel owns the quoting and the allowlist; this wrapper only adds the concealment state shape.
    $request = New-ToolkitGuestCommand -Command $Command -ShellPrefix $ShellPrefix
    if ($request.Status -ne 'Success') {
        return Get-ToolkitResult -Status 'CriticalError' -Message $request.Message -Data (New-ConcealmentState -Code 'GUEST_COMMAND_INVALID' -Step 'guest-command' -InstanceIndex $InstanceIndex)
    }
    return Get-ToolkitResult -Status 'Success' -Message 'The guest command is safely quoted.' -Data (New-ConcealmentState -Code 'OK' -Step 'guest-command' -InstanceIndex $InstanceIndex -Fields @{ Command = [string]$request.Data })
}

function Get-ConcealmentRecordField {
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

function Get-ConcealmentPackageScope {
    param(
        [AllowNull()]
        [string[]]$Packages,
        [int]$InstanceIndex = -1
    )

    if ($null -eq $Packages -or @($Packages).Count -eq 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'An explicit selected package list is required. Concealment is never applied to every app.' -Data (New-ConcealmentState -Code 'PACKAGES_REQUIRED' -Step 'selection' -InstanceIndex $InstanceIndex)
    }
    $selected = @()
    foreach ($package in @($Packages)) {
        if ($package -isnot [string] -or [string]::IsNullOrWhiteSpace($package)) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'A selected package name is empty.' -Data (New-ConcealmentState -Code 'PACKAGE_NAME_INVALID' -Step 'selection' -InstanceIndex $InstanceIndex)
        }
        if ($package.IndexOfAny([char[]]@('*', '?', '%')) -ge 0) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'A selected package name is a wildcard. A wildcard is never a package and is never expanded.' -Data (New-ConcealmentState -Code 'PACKAGE_NAME_INVALID' -Step 'selection' -InstanceIndex $InstanceIndex)
        }
        if (-not (Test-ConcealmentPackageName -Name $package)) {
            return Get-ToolkitResult -Status 'CriticalError' -Message "The selected package name is not a package name: $package" -Data (New-ConcealmentState -Code 'PACKAGE_NAME_INVALID' -Step 'selection' -InstanceIndex $InstanceIndex)
        }
        $selected += $package
    }
    return Get-ToolkitResult -Status 'Success' -Message 'The selected package list is valid.' -Data (New-ConcealmentState -Code 'OK' -Step 'selection' -InstanceIndex $InstanceIndex -Fields @{ Packages = @($selected | Select-Object -Unique) })
}

function Get-ConcealmentPackageList {
    param(
        [string]$ManagerPath,
        [int]$InstanceIndex,
        [scriptblock]$Runner = $null
    )

    $call = Invoke-ToolkitManagerAdb -ManagerPath $ManagerPath -InstanceIndex $InstanceIndex -Command $script:ConcealmentPackageListCommand -Runner $Runner
    if ($null -eq $call -or $call.ExitCode -ne 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The installed package list could not be read.' -Data (New-ConcealmentState -Code 'PACKAGE_LIST_UNREADABLE' -Step 'package-list' -InstanceIndex $InstanceIndex)
    }
    $packages = @()
    foreach ($line in @(([string]$call.Text) -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        if ($line -notmatch '^\s*package:\S+\s*$') {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'The package list response is not a list of packages.' -Data (New-ConcealmentState -Code 'PACKAGE_LIST_UNREADABLE' -Step 'package-list' -InstanceIndex $InstanceIndex)
        }
        $packages += $line.Trim().Substring('package:'.Length)
    }
    return Get-ToolkitResult -Status 'Success' -Message 'The installed package list was read.' -Data $packages
}

# A package probe answers true, false, or $null for a transport failure. Collapsing the third case into
# false would report an unreadable guest as an absent package, which is the claim the caller is about to
# make about the guest.
function Test-ConcealmentPackageInstalled {
    param(
        [string]$ManagerPath,
        [int]$InstanceIndex,
        [string]$PackageName,
        [scriptblock]$Runner = $null
    )

    $call = Invoke-ToolkitManagerAdb -ManagerPath $ManagerPath -InstanceIndex $InstanceIndex -Command ('shell dumpsys package ' + $PackageName) -Runner $Runner
    if ($null -eq $call -or $call.ExitCode -eq -1) {
        return $null
    }
    if ($call.ExitCode -ne 0) {
        return $false
    }
    return ($null -ne (Get-ToolkitPackageVersion -Text ([string]$call.Text) -PackageName $PackageName))
}

function Resolve-ConcealmentInstance {
    param([object]$Instance)

    if ($null -eq $Instance -or $Instance -is [Array] -or $Instance -isnot [pscustomobject]) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The selected instance is invalid.' -Data (New-ConcealmentState -Code 'INSTANCE_INVALID' -Step 'instance')
    }
    $indexProperty = $Instance.PSObject.Properties['Index']
    if ($null -eq $indexProperty -or
        ($indexProperty.Value -isnot [string] -and $indexProperty.Value -isnot [int] -and $indexProperty.Value -isnot [long])) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The selected instance is invalid.' -Data (New-ConcealmentState -Code 'INSTANCE_INVALID' -Step 'instance')
    }
    $instanceIndex = 0
    if (-not [int]::TryParse([string]$indexProperty.Value, [ref]$instanceIndex) -or $instanceIndex -lt 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The selected instance is invalid.' -Data (New-ConcealmentState -Code 'INSTANCE_INVALID' -Step 'instance')
    }
    $installProperty = $Instance.PSObject.Properties['Install']
    if ($null -eq $installProperty -or $null -eq $installProperty.Value -or $installProperty.Value -isnot [pscustomobject]) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The selected instance install is invalid.' -Data (New-ConcealmentState -Code 'INSTANCE_INVALID' -Step 'instance' -InstanceIndex $instanceIndex)
    }
    $installRootProperty = $installProperty.Value.PSObject.Properties['InstallRoot']
    $installManagerProperty = $installProperty.Value.PSObject.Properties['ManagerPath']
    $installVmsProperty = $installProperty.Value.PSObject.Properties['VmsPath']
    if ($null -eq $installRootProperty -or $installRootProperty.Value -isnot [string] -or
        $null -eq $installManagerProperty -or $installManagerProperty.Value -isnot [string] -or
        $null -eq $installVmsProperty -or $installVmsProperty.Value -isnot [string]) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The selected instance install is invalid.' -Data (New-ConcealmentState -Code 'INSTANCE_INVALID' -Step 'instance' -InstanceIndex $instanceIndex)
    }
    $installRoot = ConvertTo-ToolkitFullPath -Path $installRootProperty.Value
    $manager = ConvertTo-ToolkitFullPath -Path $installManagerProperty.Value
    $vmsPath = ConvertTo-ToolkitFullPath -Path $installVmsProperty.Value
    if ($null -eq $manager -or $null -eq $installRoot -or
        -not (Test-ToolkitManagerFile -Path $manager -InstallRoot $installRoot)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The MuMu manager is not a valid manager inside the selected install root.' -Data (New-ConcealmentState -Code 'MANAGER_UNAVAILABLE' -Step 'instance' -InstanceIndex $instanceIndex)
    }
    if ($null -eq $vmsPath -or -not (Test-Path -LiteralPath $vmsPath -PathType Container)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The selected instance VMS path is unavailable.' -Data (New-ConcealmentState -Code 'INSTANCE_INVALID' -Step 'instance' -InstanceIndex $instanceIndex)
    }
    return Get-ToolkitResult -Status 'Success' -Message 'The selected instance is usable.' -Data @{ Manager = $manager; Index = $instanceIndex; VmsPath = $vmsPath; AndroidVersion = [string](Get-ToolkitFirstProperty -InputObject $Instance -PropertyNames @('AndroidVersion')) }
}

function Assert-ConcealmentVerifiedClone {
    param(
        [hashtable]$Resolved,
        [object]$VerifiedClone,
        [scriptblock]$Runner = $null
    )

    $manager = [string]$Resolved['Manager']
    $sourceIndex = [int]$Resolved['Index']
    $vmsPath = [string]$Resolved['VmsPath']

    $invalid = {
        param([string]$Reason)

        return Get-ToolkitResult -Status 'CriticalError' -Message $Reason -Data (New-ConcealmentState -Code 'CLONE_RECORD_INVALID' -Step 'clone' -InstanceIndex $sourceIndex)
    }
    $unverified = {
        param([string]$Reason, [int]$CloneIndex = -1, [string]$CloneName = '')

        return Get-ToolkitResult -Status 'CriticalError' -Message $Reason -Data (New-ConcealmentState -Code 'CLONE_UNVERIFIED' -Step 'clone' -InstanceIndex $sourceIndex -Fields @{ CloneIndex = $CloneIndex; CloneName = $CloneName })
    }
    if ($null -eq $VerifiedClone -or $VerifiedClone -is [Array] -or
        ($VerifiedClone -isnot [pscustomobject] -and $VerifiedClone -isnot [Collections.IDictionary])) {
        return (& $invalid 'A verified instance clone record is required before a concealment change. The selected instance is never changed and no second clone is created here.')
    }
    $reportedIndex = Get-ConcealmentRecordField -Record $VerifiedClone -Name 'CloneIndex'
    $cloneIndex = 0
    if ($reportedIndex -isnot [string] -and $reportedIndex -isnot [int] -and $reportedIndex -isnot [long]) {
        return (& $invalid 'The verified instance clone record has no usable clone index. The selected instance is never changed and no second clone is created here.')
    }
    if (-not [int]::TryParse([string]$reportedIndex, [ref]$cloneIndex) -or $cloneIndex -lt 0) {
        return (& $invalid 'The verified instance clone record has no usable clone index. The selected instance is never changed and no second clone is created here.')
    }
    $reportedName = Get-ConcealmentRecordField -Record $VerifiedClone -Name 'CloneName'
    if ($reportedName -isnot [string] -or [string]::IsNullOrWhiteSpace($reportedName)) {
        return (& $invalid 'The verified instance clone record has no usable clone name. The selected instance is never changed and no second clone is created here.')
    }
    $cloneName = [string]$reportedName
    $reportedSource = Get-ConcealmentRecordField -Record $VerifiedClone -Name 'SourceIndex'
    if ($null -ne $reportedSource) {
        $recordSourceIndex = 0
        if (($reportedSource -isnot [string] -and $reportedSource -isnot [int] -and $reportedSource -isnot [long]) -or
            -not [int]::TryParse([string]$reportedSource, [ref]$recordSourceIndex) -or $recordSourceIndex -ne $sourceIndex) {
            return (& $invalid "The verified instance clone record belongs to another selected instance. The selected instance is never changed and no second clone is created here.")
        }
    }

    $records = @(Get-MuMuInstanceRecord -ManagerPath $manager -VersionArgument ([string]$cloneIndex) -Runner $Runner)
    if ($records.Count -ne 1) {
        return (& $unverified "The recorded clone at index $cloneIndex is not reported by the MuMu manager, so no guest change was started." $cloneIndex $cloneName)
    }
    $cloneRecord = $records[0]
    $managerIndex = 0
    if (-not [int]::TryParse([string](Get-ToolkitFirstProperty -InputObject $cloneRecord -PropertyNames @('index')), [ref]$managerIndex) -or $managerIndex -ne $cloneIndex) {
        return (& $unverified "The recorded clone at index $cloneIndex is not the instance the MuMu manager reports, so no guest change was started." $cloneIndex $cloneName)
    }
    if ((ConvertTo-ToolkitBoolean -Value (Get-ToolkitFirstProperty -InputObject $cloneRecord -PropertyNames @('is_main'))) -ne $false) {
        return (& $unverified "The recorded clone at index $cloneIndex is not a reported non-base instance, so no guest change was started." $cloneIndex $cloneName)
    }
    $managerName = [string](Get-ToolkitFirstProperty -InputObject $cloneRecord -PropertyNames @('name'))
    if ([string]::IsNullOrWhiteSpace($managerName) -or $managerName -cne $cloneName) {
        return (& $unverified "The recorded clone name does not match the MuMu manager, so no guest change was started." $cloneIndex $cloneName)
    }
    $reportedVersion = [string](Get-ToolkitFirstProperty -InputObject $cloneRecord -PropertyNames @('android_version', 'androidVersion', 'system_version', 'systemVersion'))
    $selectedVersion = [string]$Resolved['AndroidVersion']
    if ([string]::IsNullOrWhiteSpace($selectedVersion)) {
        return (& $unverified 'The selected instance reports no Android version, so the recorded clone cannot be matched to it and no guest change was started. Report the instance with a known Android version.' $cloneIndex $cloneName)
    }
    if ([string]::IsNullOrWhiteSpace($reportedVersion)) {
        return (& $unverified "The recorded clone at index $cloneIndex reports no Android version, so it cannot be matched to the selected instance and no guest change was started." $cloneIndex $cloneName)
    }
    $managerVersion = ConvertTo-ToolkitAndroidVersion -Value $reportedVersion
    $expectedVersion = ConvertTo-ToolkitAndroidVersion -Value $selectedVersion
    if ([string]::IsNullOrWhiteSpace([string]$managerVersion) -or [string]::IsNullOrWhiteSpace([string]$expectedVersion) -or $managerVersion -cne $expectedVersion) {
        return (& $unverified "The recorded clone does not report the selected instance Android version, so no guest change was started." $cloneIndex $cloneName)
    }
    $reportedVmsPath = [string](Get-ToolkitFirstProperty -InputObject $cloneRecord -PropertyNames @('vms_path', 'vmsPath'))
    $cloneRoot = Get-MuMuInstanceRootPath -VmsPath $vmsPath -Index $cloneIndex -ReportedVmsPath $reportedVmsPath
    if ($null -eq $cloneRoot -or -not (Test-ToolkitPathWithinRoot -Path $cloneRoot -Root $vmsPath)) {
        return (& $unverified "The recorded clone is outside its installation boundary, so no guest change was started." $cloneIndex $cloneName)
    }
    $diskBytes = Measure-MuMuInstanceDiskBytes -InstanceRoot $cloneRoot
    if ($null -eq $diskBytes -or $diskBytes -le 0) {
        return (& $unverified "The recorded clone does not have a usable disk, so no guest change was started." $cloneIndex $cloneName)
    }
    return Get-ToolkitResult -Status 'Success' -Message 'The recorded instance clone is the verified clone of the selected instance.' -Data @{
        Manager       = $manager
        Index         = $cloneIndex
        Name          = $cloneName
        SourceIndex   = $sourceIndex
        AndroidVersion = $expectedVersion
    }
}

function Read-ConcealmentHmaConfig {
    param(
        [string]$ManagerPath,
        [int]$InstanceIndex,
        [scriptblock]$Runner = $null
    )

    $readCommand = New-ConcealmentGuestCommand -Command ('cat ' + $script:ConcealmentConfigPath) -InstanceIndex $InstanceIndex
    if ($readCommand.Status -ne 'Success') {
        return $readCommand
    }
    $call = Invoke-ToolkitManagerAdb -ManagerPath $ManagerPath -InstanceIndex $InstanceIndex -Command $readCommand.Data.Command -Runner $Runner
    if ($null -eq $call -or $call.ExitCode -ne 0) {
        return Get-ToolkitResult -Status 'Warning' -Message ("The HMA configuration could not be read from $script:ConcealmentConfigPath.") -Data (New-ConcealmentState -Code 'HMA_CONFIG_UNREADABLE' -Step 'config-read' -InstanceIndex $InstanceIndex)
    }
    $text = [string]$call.Text
    if ([string]::IsNullOrWhiteSpace($text)) {
        return Get-ToolkitResult -Status 'Warning' -Message ("The HMA configuration at $script:ConcealmentConfigPath could not be read: the read returned nothing.") -Data (New-ConcealmentState -Code 'HMA_CONFIG_UNREADABLE' -Step 'config-read' -InstanceIndex $InstanceIndex)
    }

    $unsupported = {
        param([string]$Reason, [int]$FoundVersion)

        return Get-ToolkitResult -Status 'Warning' -Message $Reason -Data (New-ConcealmentState -Code 'HMA_SCHEMA_UNSUPPORTED' -Step 'config-read' -InstanceIndex $InstanceIndex -Fields @{ HmaConfigVersion = $FoundVersion })
    }

    $document = $null
    $parseFailure = ''
    try {
        Assert-NoDuplicateJournalProperty -Json $text
        $document = $text | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        $parseFailure = Protect-ToolkitText ([string]$_.Exception.Message)
    }
    if (-not [string]::IsNullOrWhiteSpace($parseFailure)) {
        return (& $unsupported "The HMA configuration is not strict JSON, so it was not modified. Reader reason: $parseFailure" -1)
    }
    if ($null -eq $document -or $document -is [Array] -or $document -isnot [pscustomobject]) {
        return (& $unsupported 'The HMA configuration is not a supported document, so it was not modified.' -1)
    }
    $versionProperty = $document.PSObject.Properties['configVersion']
    if ($null -eq $versionProperty -or
        ($versionProperty.Value -isnot [int] -and $versionProperty.Value -isnot [long])) {
        return (& $unsupported "The HMA configuration has no usable configVersion, so it was not modified. The supported version is $($script:ConcealmentConfigVersion)." -1)
    }
    $configVersion = [int]$versionProperty.Value
    if ($configVersion -ne $script:ConcealmentConfigVersion) {
        return (& $unsupported "The HMA configuration version $configVersion is not the supported version $($script:ConcealmentConfigVersion), so it was not modified." $configVersion)
    }

    $templatesProperty = $document.PSObject.Properties['templates']
    if ($null -ne $templatesProperty -and
        ($null -eq $templatesProperty.Value -or $templatesProperty.Value -is [Array] -or $templatesProperty.Value -isnot [pscustomobject])) {
        return (& $unsupported "The HMA configuration has no usable template map, so it was not modified. Version: $configVersion." $configVersion)
    }
    $templateProperty = $null
    if ($null -ne $templatesProperty) {
        $templateProperty = $templatesProperty.Value.PSObject.Properties[$script:ConcealmentTemplateName]
    }
    if ($null -ne $templateProperty) {
        if ($null -eq $templateProperty.Value -or $templateProperty.Value -is [Array] -or $templateProperty.Value -isnot [pscustomobject]) {
            return (& $unsupported "The HMA configuration template $($script:ConcealmentTemplateName) is not a supported template, so it was not modified. Version: $configVersion." $configVersion)
        }
        $appListProperty = $templateProperty.Value.PSObject.Properties['appList']
        if ($null -ne $appListProperty) {
            if ($null -eq $appListProperty.Value -or $appListProperty.Value -isnot [Array]) {
                return (& $unsupported "The HMA configuration template $($script:ConcealmentTemplateName) has no usable app list, so it was not modified. Version: $configVersion." $configVersion)
            }
            foreach ($entry in @($appListProperty.Value)) {
                if ($entry -isnot [string] -or [string]::IsNullOrWhiteSpace($entry)) {
                    return (& $unsupported "The HMA configuration template $($script:ConcealmentTemplateName) has an unusable app list entry, so it was not modified. Version: $configVersion." $configVersion)
                }
            }
        }
    }

    $scopeProperty = $document.PSObject.Properties['scope']
    if ($null -ne $scopeProperty) {
        if ($null -eq $scopeProperty.Value -or $scopeProperty.Value -is [Array] -or $scopeProperty.Value -isnot [pscustomobject]) {
            return (& $unsupported "The HMA configuration scope is not a per-app scope map, so it was not modified. Version: $configVersion." $configVersion)
        }
        $scopeValue = $scopeProperty.Value
        foreach ($scopeEntry in @($scopeValue.PSObject.Properties)) {
            if ([string]::IsNullOrWhiteSpace($scopeEntry.Name) -or
                $scopeEntry.Value -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$scopeEntry.Value)) {
                return (& $unsupported "The HMA configuration scope map is unusable, so it was not modified. Version: $configVersion." $configVersion)
            }
        }
    }

    $data = New-ConcealmentState -Code 'OK' -Step 'config-read' -InstanceIndex $InstanceIndex -Fields @{
        HmaConfigVersion = $configVersion
    }
    $data['Document'] = $document
    $data['Text'] = $text
    $data['Sha256'] = Get-ConcealmentTextSha256 -Text $text
    return Get-ToolkitResult -Status 'Success' -Message 'The supported HMA configuration was read.' -Data $data
}

function Get-ConcealmentTargetIndex {
    param(
        [object]$Resolved,
        [int]$TargetIndex
    )

    if ($TargetIndex -lt 0) {
        return [int]$Resolved['Index']
    }
    return $TargetIndex
}

function Get-HmaConfig {
    param(
        [object]$Instance,
        [int]$TargetIndex = -1,
        [scriptblock]$Runner = $null
    )

    $resolved = Resolve-ConcealmentInstance -Instance $Instance
    if ($resolved.Status -ne 'Success') {
        return Get-ToolkitResult -Status 'CriticalError' -Message $resolved.Message -Data $resolved.Data
    }
    $targetIndex = Get-ConcealmentTargetIndex -Resolved $resolved.Data -TargetIndex $TargetIndex
    $config = Read-ConcealmentHmaConfig -ManagerPath ([string]$resolved.Data.Manager) -InstanceIndex $targetIndex -Runner $Runner
    if ($config.Status -ne 'Success') {
        return New-ConcealmentHandoff -Journal $null -Reason $config.Message -State (New-ConcealmentState -Code ([string]$config.Data.Code) -Step 'config-read' -InstanceIndex $targetIndex -Fields @{ HmaConfigVersion = $config.Data.HmaConfigVersion })
    }
    return Get-ToolkitResult -Status 'Success' -Message $config.Message -Data $config.Data
}

function Get-ConcealmentStoredRootTemplate {
    param(
        [object]$Document,
        [int]$InstanceIndex = -1
    )

    $stored = @()
    $isWhitelist = $false
    $found = $false
    $templatesProperty = $Document.PSObject.Properties['templates']
    if ($null -ne $templatesProperty) {
        $templateProperty = $templatesProperty.Value.PSObject.Properties[$script:ConcealmentTemplateName]
        if ($null -ne $templateProperty) {
            $found = $true
            $whitelistProperty = $templateProperty.Value.PSObject.Properties['isWhitelist']
            if ($null -ne $whitelistProperty -and $whitelistProperty.Value -is [bool]) {
                $isWhitelist = [bool]$whitelistProperty.Value
            }
            $appListProperty = $templateProperty.Value.PSObject.Properties['appList']
            if ($null -ne $appListProperty -and $null -ne $appListProperty.Value) {
                $stored = @($appListProperty.Value | ForEach-Object { [string]$_ })
            }
        }
    }
    return [pscustomobject]@{
        Code             = 'OK'
        Found            = $found
        IsWhitelist      = $isWhitelist
        TemplatePackages = $stored
        InstanceIndex    = $InstanceIndex
    }
}

function New-ReusableRootTemplate {
    param(
        [object]$Instance,
        [object]$Journal,
        [int]$TargetIndex = -1,
        [scriptblock]$Runner = $null
    )

    try {
        Assert-OperationJournal $Journal
    }
    catch {
        return New-ToolkitRootFailure -Journal $null -Message 'The concealment journal is invalid.' -Data (New-ConcealmentState -Code 'JOURNAL_INVALID' -Step 'journal')
    }
    $resolved = Resolve-ConcealmentInstance -Instance $Instance
    if ($resolved.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message $resolved.Message -Data $resolved.Data
    }
    $manager = [string]$resolved.Data.Manager
    $targetIndex = Get-ConcealmentTargetIndex -Resolved $resolved.Data -TargetIndex $TargetIndex

    $config = Read-ConcealmentHmaConfig -ManagerPath $manager -InstanceIndex $targetIndex -Runner $Runner
    if ($config.Status -ne 'Success') {
        return New-ConcealmentHandoff -Journal $Journal -Reason $config.Message -State (New-ConcealmentState -Code ([string]$config.Data.Code) -Step 'config-read' -InstanceIndex $targetIndex -Fields @{ HmaConfigVersion = $config.Data.HmaConfigVersion })
    }

    $packageList = Get-ConcealmentPackageList -ManagerPath $manager -InstanceIndex $targetIndex -Runner $Runner
    if ($packageList.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message $packageList.Message -Data $packageList.Data
    }
    $installed = @($packageList.Data)

    $template = Get-ConcealmentRootTemplate -Document $config.Data.Document -InstalledPackages $installed -InstanceIndex $targetIndex
    if ($template.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message $template.Message -Data $template.Data
    }

    $state = New-ConcealmentState -Code 'OK' -Step 'template' -InstanceIndex $targetIndex -Fields @{
        TemplateName     = $script:ConcealmentTemplateName
        TemplatePackages = @($template.Data.TemplatePackages)
        IsWhitelist      = $false
        HmaConfigVersion = $config.Data.HmaConfigVersion
    }
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message "The reusable blacklist Root template was verified with $(@($template.Data.TemplatePackages).Count) package(s). No configuration was written." -Data $state
    }
    catch {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The verified Root template could not be journaled.' -Data (New-ConcealmentState -Code 'JOURNAL_WRITE_FAILED' -Step 'template' -InstanceIndex $targetIndex)
    }
    return Get-ToolkitResult -Status 'Success' -Message 'The reusable blacklist Root template is verified and no configuration was written.' -Data $state
}

function Get-ConcealmentRootTemplate {
    param(
        [object]$Document,
        [string[]]$InstalledPackages,
        [int]$InstanceIndex = -1
    )

    $invalid = {
        param([string]$Reason)

        return Get-ToolkitResult -Status 'CriticalError' -Message $Reason -Data (New-ConcealmentState -Code 'HMA_TEMPLATE_INVALID' -Step 'template' -InstanceIndex $InstanceIndex)
    }

    $stored = Get-ConcealmentStoredRootTemplate -Document $Document -InstanceIndex $InstanceIndex
    if ($stored.Found -and $stored.IsWhitelist) {
        return (& $invalid "The existing HMA template $($script:ConcealmentTemplateName) is a whitelist template and is never flipped to a blacklist automatically. Rename or remove it in the HMA app, then run the workflow again.")
    }

    $installed = @()
    foreach ($rootPackage in $script:ConcealmentTemplatePackages) {
        if ($null -eq $InstalledPackages -or @($InstalledPackages) -ccontains $rootPackage) {
            $installed += $rootPackage
        }
    }
    $merged = @(@($stored.TemplatePackages) + @($installed) | Select-Object -Unique)
    return Get-ToolkitResult -Status 'Success' -Message 'The reusable Root template is described.' -Data (New-ConcealmentState -Code 'OK' -Step 'template' -InstanceIndex $InstanceIndex -Fields @{
            TemplateName     = $script:ConcealmentTemplateName
            TemplatePackages = $merged
            IsWhitelist      = $false
        })
}

function Set-ConcealmentGuestText {
    param(
        [string]$ManagerPath,
        [int]$InstanceIndex,
        [string]$Path,
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Text,
        [object]$Journal = $null,
        [scriptblock]$Runner = $null
    )

    $manager = ConvertTo-ToolkitFullPath -Path $ManagerPath
    if ($null -eq $manager -or $InstanceIndex -lt 0) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The guest file manager path is invalid.' -Data (New-ConcealmentState -Code 'GUEST_WRITE_FAILED' -Step 'guest-write' -InstanceIndex $InstanceIndex)
    }
    if (-not (Test-ToolkitGuestPath -Path $Path)) {
        return New-ToolkitRootFailure -Journal $Journal -Message "The guest file path is not a plain absolute path: $Path" -Data (New-ConcealmentState -Code 'GUEST_WRITE_FAILED' -Step 'guest-write' -InstanceIndex $InstanceIndex)
    }
    if ($Text -isnot [string] -or [string]::IsNullOrWhiteSpace($Text)) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The guest file content is empty.' -Data (New-ConcealmentState -Code 'GUEST_WRITE_FAILED' -Step 'guest-write' -InstanceIndex $InstanceIndex)
    }

    $payload = [Convert]::ToBase64String((New-Object Text.UTF8Encoding($false)).GetBytes($Text))
    $temporaryPath = $Path + '.toolkit.tmp'
    $writeCommand = New-ConcealmentGuestCommand -Command ('echo ' + $payload + ' | base64 -d > ' + $temporaryPath + ' && mv ' + $temporaryPath + ' ' + $Path) -InstanceIndex $InstanceIndex
    if ($writeCommand.Status -ne 'Success') {
        return $writeCommand
    }
    $call = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $InstanceIndex -Command $writeCommand.Data.Command -Runner $Runner
    if ($null -eq $call -or $call.ExitCode -ne 0) {
        return New-ToolkitRootFailure -Journal $Journal -Message "The guest file was not replaced: $Path" -Data (New-ConcealmentState -Code 'GUEST_WRITE_FAILED' -Step 'guest-write' -InstanceIndex $InstanceIndex)
    }
    $state = New-ConcealmentState -Code 'OK' -Step 'guest-write' -InstanceIndex $InstanceIndex -Fields @{ ConfigPath = $Path }
    if ($null -ne $Journal -and $null -ne $Journal.PSObject -and $Journal.State -eq 'Running') {
        try {
            Write-JournalEvent -Journal $Journal -Level 'Info' -Message "The guest file was replaced through a temporary file in its own directory: $Path" -Data $state
        }
        catch {
            return New-ToolkitRootFailure -Journal $Journal -Message 'The replaced guest file could not be journaled.' -Data (New-ConcealmentState -Code 'JOURNAL_WRITE_FAILED' -Step 'guest-write' -InstanceIndex $InstanceIndex)
        }
    }
    return Get-ToolkitResult -Status 'Success' -Message "The guest file was replaced: $Path" -Data $state
}

function Get-ConcealmentGuestFile {
    param(
        [string]$ManagerPath,
        [int]$InstanceIndex,
        [string]$Path,
        [scriptblock]$Runner = $null
    )

    $manager = ConvertTo-ToolkitFullPath -Path $ManagerPath
    if ($null -eq $manager -or $InstanceIndex -lt 0 -or -not (Test-ToolkitGuestPath -Path $Path)) {
        return $null
    }
    $readCommand = New-ConcealmentGuestCommand -Command ('cat ' + $Path) -InstanceIndex $InstanceIndex
    if ($readCommand.Status -ne 'Success') {
        return $null
    }
    $call = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $InstanceIndex -Command $readCommand.Data.Command -Runner $Runner
    if ($null -eq $call -or $call.ExitCode -ne 0) {
        return $null
    }
    return [string]$call.Text
}

function Install-ConcealmentDependencies {
    param(
        [object]$Instance,
        [object]$VerifiedClone,
        [object]$Manifest,
        [object]$Journal,
        [string]$CacheRoot = '',
        [scriptblock]$Runner = $null
    )

    try {
        Assert-OperationJournal $Journal
    }
    catch {
        return New-ToolkitRootFailure -Journal $null -Message 'The concealment journal is invalid.' -Data (New-ConcealmentState -Code 'JOURNAL_INVALID' -Step 'journal')
    }
    $resolved = Resolve-ConcealmentInstance -Instance $Instance
    if ($resolved.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message $resolved.Message -Data $resolved.Data
    }
    $manager = [string]$resolved.Data.Manager
    $sourceIndex = [int]$resolved.Data.Index

    $hmaAsset = Save-ToolkitManifestAsset -Manifest $Manifest -Id $script:ConcealmentHmaAssetId -CacheRoot $CacheRoot -RequireCached
    if ($hmaAsset.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message $hmaAsset.Message -Data (New-ConcealmentState -Code ([string]$hmaAsset.Data.Code) -Step 'asset' -InstanceIndex $sourceIndex)
    }
    $vectorAsset = Save-ToolkitManifestAsset -Manifest $Manifest -Id $script:ConcealmentVectorAssetId -CacheRoot $CacheRoot -RequireCached
    if ($vectorAsset.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message $vectorAsset.Message -Data (New-ConcealmentState -Code ([string]$vectorAsset.Data.Code) -Step 'asset' -InstanceIndex $sourceIndex)
    }
    $hmaPath = [string]$hmaAsset.Data.Asset
    $vectorPath = [string]$vectorAsset.Data.Asset

    $clone = $null
    if ($null -eq $VerifiedClone) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'A verified instance clone record is required before installing concealment dependencies. The selected instance is never changed and no second clone is created here.' -Data (New-ConcealmentState -Code 'CLONE_REQUIRED' -Step 'clone' -InstanceIndex $sourceIndex)
    }
    $clone = Assert-ConcealmentVerifiedClone -Resolved $resolved.Data -VerifiedClone $VerifiedClone -Runner $Runner
    if ($clone.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message $clone.Message -Data $clone.Data
    }
    $instanceIndex = [int]$clone.Data.Index
    $cloneName = [string]$clone.Data.Name
    $cloneFields = @{ CloneIndex = $instanceIndex; CloneName = $cloneName }

    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message "The pinned HMA and Vector assets were verified by size and SHA-256 in the dependency cache before any instance change. The verified clone at index $instanceIndex is the only instance that will be changed." -Data (New-ConcealmentState -Code 'OK' -Step 'asset' -InstanceIndex $instanceIndex -Fields $cloneFields)
    }
    catch {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The verified concealment dependencies could not be journaled.' -Data (New-ConcealmentState -Code 'JOURNAL_WRITE_FAILED' -Step 'asset' -InstanceIndex $instanceIndex -Fields $cloneFields)
    }

    # Which privileged word this guest answers is resolved once, against the clone and never the source,
    # and only after the journal is writable, because a run that cannot record what it did must not touch a
    # guest at all. A clone that Root12 rooted properly has no /system/bin/su, because disabling the vendor
    # root removes that symlink, so asking su would fail every command here before it reached the guest.
    $shellPrefix = Resolve-ToolkitGuestShellPrefix -ManagerPath $manager -InstanceIndex $instanceIndex -Runner $Runner
    if ($shellPrefix.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message $shellPrefix.Message -Data (New-ConcealmentState -Code ([string]$shellPrefix.Data.Code) -Step 'shell-prefix' -InstanceIndex $instanceIndex -Fields $cloneFields)
    }
    $script:ConcealmentGuestShellPrefix = [string]$shellPrefix.Data.Prefix

    $installed = @()
    $alreadyPresent = @()
    $quotedApk = Format-ToolkitQuotedPath -Path $hmaPath -Label 'verified HMA asset path'
    if ($quotedApk.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message $quotedApk.Message -Data (New-ConcealmentState -Code ([string]$quotedApk.Data.Code) -Step 'asset' -InstanceIndex $instanceIndex -Fields $cloneFields)
    }
    $quotedVector = Format-ToolkitQuotedPath -Path $vectorPath -Label 'verified Vector asset path'
    if ($quotedVector.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message $quotedVector.Message -Data (New-ConcealmentState -Code ([string]$quotedVector.Data.Code) -Step 'asset' -InstanceIndex $instanceIndex -Fields $cloneFields)
    }
    $hmaInstalled = Test-ConcealmentPackageInstalled -ManagerPath $manager -InstanceIndex $instanceIndex -PackageName $script:ConcealmentHmaPackage -Runner $Runner
    if ($null -eq $hmaInstalled) {
        return New-ToolkitRootFailure -Journal $Journal -Message "The HMA package state on the clone at index $instanceIndex could not be read, so the install was not attempted and the guest state is unknown." -Data (New-ConcealmentState -Code 'ADB_FAILED' -Step 'hma-install' -InstanceIndex $instanceIndex -Fields $cloneFields)
    }
    if (-not $hmaInstalled) {
        $apkInstall = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $instanceIndex -Command ('install -r ' + [string]$quotedApk.Data) -Runner $Runner
        if ($null -eq $apkInstall -or $apkInstall.ExitCode -ne 0) {
            return New-ToolkitRootFailure -Journal $Journal -Message "The verified HMA APK was not installed on the clone at index $instanceIndex." -Data (New-ConcealmentState -Code 'APK_INSTALL_FAILED' -Step 'hma-install' -InstanceIndex $instanceIndex -Fields $cloneFields)
        }
        $hmaReadBack = Test-ConcealmentPackageInstalled -ManagerPath $manager -InstanceIndex $instanceIndex -PackageName $script:ConcealmentHmaPackage -Runner $Runner
        if ($null -eq $hmaReadBack) {
            return New-ToolkitRootFailure -Journal $Journal -Message "The HMA package state on the clone at index $instanceIndex could not be read back after the install, so the install is not claimed." -Data (New-ConcealmentState -Code 'ADB_FAILED' -Step 'hma-install' -InstanceIndex $instanceIndex -Fields $cloneFields)
        }
        if (-not $hmaReadBack) {
            return New-ToolkitRootFailure -Journal $Journal -Message "The verified HMA APK install did not leave the package $($script:ConcealmentHmaPackage) installed on the clone at index $instanceIndex." -Data (New-ConcealmentState -Code 'APK_INSTALL_FAILED' -Step 'hma-install' -InstanceIndex $instanceIndex -Fields $cloneFields)
        }
        $installed += $script:ConcealmentHmaAssetId
    }
    else {
        $alreadyPresent += $script:ConcealmentHmaAssetId
    }

    $moduleListCommand = New-ConcealmentGuestCommand -Command ('ls ' + $script:ConcealmentVectorModulePath) -InstanceIndex $instanceIndex
    if ($moduleListCommand.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message $moduleListCommand.Message -Data (New-ConcealmentState -Code ([string]$moduleListCommand.Data.Code) -Step 'vector-install' -InstanceIndex $instanceIndex -Fields $cloneFields)
    }
    $moduleList = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $instanceIndex -Command $moduleListCommand.Data.Command -Runner $Runner
    if ($null -ne $moduleList -and $moduleList.ExitCode -eq -1) {
        return New-ToolkitRootFailure -Journal $Journal -Message "The Vector module directory $($script:ConcealmentVectorModulePath) could not be read, so whether the module is installed is unknown and nothing was installed." -Data (New-ConcealmentState -Code 'ADB_FAILED' -Step 'vector-install' -InstanceIndex $instanceIndex -Fields $cloneFields)
    }
    if ($null -ne $moduleList -and $moduleList.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace([string]$moduleList.Text)) {
        $alreadyPresent += $script:ConcealmentVectorAssetId
    }
    else {
        $stagedPath = $script:ConcealmentGuestStagePath + '/' + [IO.Path]::GetFileName($vectorPath)
        $extractPath = $script:ConcealmentGuestStagePath + '/vector-extract-' + [Guid]::NewGuid().ToString('N')
        if (-not (Test-ToolkitGuestPath -Path $stagedPath) -or -not (Test-ToolkitGuestPath -Path $extractPath)) {
            return New-ToolkitRootFailure -Journal $Journal -Message 'The verified Vector module staging path is not a plain absolute guest path, so nothing was staged.' -Data (New-ConcealmentState -Code 'ASSET_PATH_INVALID' -Step 'vector-install' -InstanceIndex $instanceIndex -Fields $cloneFields)
        }
        $push = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $instanceIndex -Command ('push ' + [string]$quotedVector.Data + ' ' + $stagedPath) -Runner $Runner
        if ($null -eq $push -or $push.ExitCode -ne 0) {
            return New-ToolkitRootFailure -Journal $Journal -Message 'The verified Vector module was not staged on the clone.' -Data (New-ConcealmentState -Code 'MODULE_PUSH_FAILED' -Step 'vector-install' -InstanceIndex $instanceIndex -Fields $cloneFields)
        }
        # Every failure after the push removes the pushed archive and the staging directory, so a rejected archive is not left in the guest.
        $cleanupStaging = {
            $cleanupCommand = New-ConcealmentGuestCommand -Command ('rm -rf ' + $extractPath + ' ' + $stagedPath) -InstanceIndex $instanceIndex
            if ($cleanupCommand.Status -ne 'Success') {
                return
            }
            [void](Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $instanceIndex -Command $cleanupCommand.Data.Command -Runner $Runner)
        }
        $extractCommand = New-ConcealmentGuestCommand -Command ('mkdir -p ' + $extractPath + ' && unzip -o ' + $stagedPath + ' -d ' + $extractPath) -InstanceIndex $instanceIndex
        if ($extractCommand.Status -ne 'Success') {
            (& $cleanupStaging)
            return New-ToolkitRootFailure -Journal $Journal -Message $extractCommand.Message -Data (New-ConcealmentState -Code ([string]$extractCommand.Data.Code) -Step 'vector-install' -InstanceIndex $instanceIndex -Fields $cloneFields)
        }
        $extract = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $instanceIndex -Command $extractCommand.Data.Command -Runner $Runner
        if ($null -eq $extract -or $extract.ExitCode -ne 0) {
            (& $cleanupStaging)
            return New-ToolkitRootFailure -Journal $Journal -Message 'The verified Vector module was not extracted on the clone.' -Data (New-ConcealmentState -Code 'MODULE_EXTRACT_FAILED' -Step 'vector-install' -InstanceIndex $instanceIndex -Fields $cloneFields)
        }
        $listingCommand = New-ConcealmentGuestCommand -Command ('ls ' + $extractPath) -InstanceIndex $instanceIndex
        if ($listingCommand.Status -ne 'Success') {
            (& $cleanupStaging)
            return New-ToolkitRootFailure -Journal $Journal -Message $listingCommand.Message -Data (New-ConcealmentState -Code ([string]$listingCommand.Data.Code) -Step 'vector-install' -InstanceIndex $instanceIndex -Fields $cloneFields)
        }
        $listing = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $instanceIndex -Command $listingCommand.Data.Command -Runner $Runner
        if ($null -eq $listing -or $listing.ExitCode -eq -1) {
            # A transport failure leaves the entry list empty, which is not a layout the archive can be
            # blamed for, so it is reported the same way the module directory probe above reports one.
            (& $cleanupStaging)
            return New-ToolkitRootFailure -Journal $Journal -Message "The extracted Vector module directory could not be read, so the archive layout is unknown and nothing was installed." -Data (New-ConcealmentState -Code 'ADB_FAILED' -Step 'vector-install' -InstanceIndex $instanceIndex -Fields $cloneFields)
        }
        $entries = @()
        if ($null -ne $listing -and $listing.ExitCode -eq 0) {
            $entries = @(([string]$listing.Text) -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() })
        }
        $hasModuleDirectory = $entries -ccontains $script:ConcealmentVectorModuleName
        $hasRootModuleProp = $entries -ccontains 'module.prop'
        if ($hasModuleDirectory -and $hasRootModuleProp) {
            (& $cleanupStaging)
            return New-ToolkitRootFailure -Journal $Journal -Message "The verified Vector archive is both a $($script:ConcealmentVectorModuleName) module directory and a flat module archive, so the module root is ambiguous and nothing was installed." -Data (New-ConcealmentState -Code 'MODULE_LAYOUT_UNSUPPORTED' -Step 'vector-install' -InstanceIndex $instanceIndex -Fields $cloneFields)
        }
        if ($hasModuleDirectory) {
            $moveCommand = New-ConcealmentGuestCommand -Command ('mv ' + $extractPath + '/' + $script:ConcealmentVectorModuleName + ' ' + $script:ConcealmentVectorModulePath + ' && rmdir ' + $extractPath) -InstanceIndex $instanceIndex
        }
        elseif ($hasRootModuleProp) {
            $moduleProp = Get-ConcealmentGuestFile -ManagerPath $manager -InstanceIndex $instanceIndex -Path ($extractPath + '/module.prop') -Runner $Runner
            $moduleId = ''
            if ($null -ne $moduleProp -and $moduleProp -match '(?m)^id=(.+)$') {
                $moduleId = $Matches[1].Trim()
            }
            $moduleFiles = @($entries | Where-Object { $_ -like '*.sh' -or $_ -ceq 'bin' })
            $nestedModuleRoots = @()
            foreach ($entry in @($entries | Where-Object { $_ -cne 'module.prop' -and $_ -notlike '*.sh' })) {
                if ($null -ne (Get-ConcealmentGuestFile -ManagerPath $manager -InstanceIndex $instanceIndex -Path ($extractPath + '/' + $entry + '/module.prop') -Runner $Runner)) {
                    $nestedModuleRoots += $entry
                }
            }
            if ($moduleId -cne $script:ConcealmentVectorModuleName -or $moduleFiles.Count -eq 0 -or $nestedModuleRoots.Count -gt 0) {
                (& $cleanupStaging)
                $reason = "the root module.prop declares id='$moduleId' instead of $($script:ConcealmentVectorModuleName)"
                if ($moduleFiles.Count -eq 0) {
                    $reason = 'the flat archive has no module script and no bin directory'
                }
                if ($nestedModuleRoots.Count -gt 0) {
                    $reason = "the flat archive carries another module root: $($nestedModuleRoots -join ', ')"
                }
                return New-ToolkitRootFailure -Journal $Journal -Message "The verified Vector archive is a flat module archive that is not the pinned module, because $reason. Nothing was installed." -Data (New-ConcealmentState -Code 'MODULE_LAYOUT_UNSUPPORTED' -Step 'vector-install' -InstanceIndex $instanceIndex -Fields $cloneFields)
            }
            $moveCommand = New-ConcealmentGuestCommand -Command ('mv ' + $extractPath + ' ' + $script:ConcealmentVectorModulePath) -InstanceIndex $instanceIndex
        }
        else {
            (& $cleanupStaging)
            return New-ToolkitRootFailure -Journal $Journal -Message "The verified Vector archive is neither a single $($script:ConcealmentVectorModuleName) module directory nor a flat module archive with a root module.prop, and was not installed. Extracted entries: $($entries -join ', ')" -Data (New-ConcealmentState -Code 'MODULE_LAYOUT_UNSUPPORTED' -Step 'vector-install' -InstanceIndex $instanceIndex -Fields $cloneFields)
        }
        if ($moveCommand.Status -ne 'Success') {
            (& $cleanupStaging)
            return New-ToolkitRootFailure -Journal $Journal -Message $moveCommand.Message -Data (New-ConcealmentState -Code ([string]$moveCommand.Data.Code) -Step 'vector-install' -InstanceIndex $instanceIndex -Fields $cloneFields)
        }
        $move = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $instanceIndex -Command $moveCommand.Data.Command -Runner $Runner
        if ($null -eq $move -or $move.ExitCode -ne 0) {
            (& $cleanupStaging)
            return New-ToolkitRootFailure -Journal $Journal -Message "The extracted Vector module was not moved into $($script:ConcealmentVectorModulePath)." -Data (New-ConcealmentState -Code 'MODULE_INSTALL_FAILED' -Step 'vector-install' -InstanceIndex $instanceIndex -Fields $cloneFields)
        }
        $moduleList = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $instanceIndex -Command $moduleListCommand.Data.Command -Runner $Runner
        if ($null -eq $moduleList -or $moduleList.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace([string]$moduleList.Text)) {
            return New-ToolkitRootFailure -Journal $Journal -Message "The Vector module directory $($script:ConcealmentVectorModulePath) is not present after the install." -Data (New-ConcealmentState -Code 'MODULE_INSTALL_FAILED' -Step 'vector-install' -InstanceIndex $instanceIndex -Fields $cloneFields)
        }
        $installed += $script:ConcealmentVectorAssetId
    }

    $status = if ($installed.Count -eq 0) { 'AlreadyApplied' } else { 'Success' }
    $message = "Concealment dependencies are in place on the verified clone at index $instanceIndex. Installed: $($installed.Count). Already present: $($alreadyPresent.Count)."
    $state = New-ConcealmentState -Code 'OK' -Step 'complete' -InstanceIndex $instanceIndex -Fields @{
        Installed      = @($installed)
        AlreadyPresent = @($alreadyPresent)
        CloneIndex     = $instanceIndex
        CloneName      = $cloneName
    }
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message $message -Data $state
        Complete-OperationJournal -Journal $Journal -Result (Get-ToolkitResult -Status $status -Message $message -Data $state)
    }
    catch {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The installed concealment dependencies could not be journaled.' -Data (New-ConcealmentState -Code 'JOURNAL_WRITE_FAILED' -Step 'complete' -InstanceIndex $instanceIndex -Fields $cloneFields)
    }
    return Get-ToolkitResult -Status $status -Message $message -Data $state
}

function Set-AppConcealment {
    param(
        [object]$Instance,
        [object]$VerifiedClone,
        [string[]]$Packages,
        [object]$Journal,
        [scriptblock]$Runner = $null
    )

    try {
        Assert-OperationJournal $Journal
    }
    catch {
        return New-ToolkitRootFailure -Journal $null -Message 'The concealment journal is invalid.' -Data (New-ConcealmentState -Code 'JOURNAL_INVALID' -Step 'journal')
    }
    $resolved = Resolve-ConcealmentInstance -Instance $Instance
    if ($resolved.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message $resolved.Message -Data $resolved.Data
    }
    $manager = [string]$resolved.Data.Manager
    $sourceIndex = [int]$resolved.Data.Index

    $clone = $null
    if ($null -eq $VerifiedClone) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'A verified instance clone record is required before applying concealment. The selected instance is never changed and no second clone is created here.' -Data (New-ConcealmentState -Code 'CLONE_REQUIRED' -Step 'clone' -InstanceIndex $sourceIndex)
    }
    $clone = Assert-ConcealmentVerifiedClone -Resolved $resolved.Data -VerifiedClone $VerifiedClone -Runner $Runner
    if ($clone.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message $clone.Message -Data $clone.Data
    }
    $instanceIndex = [int]$clone.Data.Index
    $cloneName = [string]$clone.Data.Name
    $cloneFields = @{ CloneIndex = $instanceIndex; CloneName = $cloneName }

    $scope = Get-ConcealmentPackageScope -Packages $Packages -InstanceIndex $instanceIndex
    if ($scope.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message $scope.Message -Data $scope.Data
    }
    $selected = @($scope.Data.Packages)

    $packageList = Get-ConcealmentPackageList -ManagerPath $manager -InstanceIndex $instanceIndex -Runner $Runner
    if ($packageList.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message $packageList.Message -Data $packageList.Data
    }
    $installed = @($packageList.Data)
    if ($selected.Count -ge $installed.Count) {
        return New-ToolkitRootFailure -Journal $Journal -Message "The selection covers all $($installed.Count) installed package(s) on the verified clone, which is a global scope. Concealment is applied only to an explicit subset of apps; select fewer apps and run the workflow again." -Data (New-ConcealmentState -Code 'ALL_APPS_REFUSED' -Step 'selection' -InstanceIndex $instanceIndex -Fields @{ Packages = $selected })
    }
    foreach ($packageName in $selected) {
        if ($installed -cnotcontains $packageName) {
            return New-ToolkitRootFailure -Journal $Journal -Message "The selected package is not installed on the verified clone: $packageName" -Data (New-ConcealmentState -Code 'PACKAGE_NOT_INSTALLED' -Step 'selection' -InstanceIndex $instanceIndex -Fields @{ Packages = $selected })
        }
    }

    $config = Read-ConcealmentHmaConfig -ManagerPath $manager -InstanceIndex $instanceIndex -Runner $Runner
    if ($config.Status -ne 'Success') {
        return New-ConcealmentHandoff -Journal $Journal -Reason $config.Message -State (New-ConcealmentState -Code ([string]$config.Data.Code) -Step 'config-read' -InstanceIndex $instanceIndex -Fields @{ HmaConfigVersion = $config.Data.HmaConfigVersion })
    }

    $template = Get-ConcealmentRootTemplate -Document $config.Data.Document -InstalledPackages $installed -InstanceIndex $instanceIndex
    if ($template.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message $template.Message -Data $template.Data
    }
    $templatePackages = @($template.Data.TemplatePackages)

    $document = [ordered]@{}
    foreach ($property in @($config.Data.Document.PSObject.Properties)) {
        $document[[string]$property.Name] = $property.Value
    }
    $templates = [ordered]@{}
    $templatesProperty = $config.Data.Document.PSObject.Properties['templates']
    if ($null -ne $templatesProperty) {
        foreach ($property in @($templatesProperty.Value.PSObject.Properties)) {
            $templates[[string]$property.Name] = $property.Value
        }
    }
    $templates[[string]$script:ConcealmentTemplateName] = [ordered]@{
        isWhitelist = $false
        appList     = @($templatePackages)
    }
    $document['templates'] = $templates

    # HMA 93 reads the per-app assignment from the scope map; the toolkit never writes an apps key.
    $assignments = [ordered]@{}
    $scopeProperty = $config.Data.Document.PSObject.Properties['scope']
    if ($null -ne $scopeProperty) {
        $existingScope = $scopeProperty.Value
        foreach ($property in @($existingScope.PSObject.Properties)) {
            if (-not (Test-ConcealmentPackageName -Name $property.Name)) {
                return New-ToolkitRootFailure -Journal $Journal -Message "The existing HMA scope holds a key that is not a package name, so it is never rewritten: $($property.Name)" -Data (New-ConcealmentState -Code 'HMA_TEMPLATE_INVALID' -Step 'config-write' -InstanceIndex $instanceIndex -Fields $cloneFields)
            }
            $assignments[[string]$property.Name] = [string]$property.Value
        }
    }
    foreach ($packageName in $selected) {
        $assignments[[string]$packageName] = [string]$script:ConcealmentTemplateName
    }
    $document['scope'] = $assignments

    if ((Get-ConcealmentJsonDepth -Value $document) -gt $script:ConcealmentJsonDepth) {
        return New-ToolkitRootFailure -Journal $Journal -Message "The HMA configuration is nested deeper than $($script:ConcealmentJsonDepth) levels, so writing it would truncate the operator's own settings. Nothing was written and no backup was taken." -Data (New-ConcealmentState -Code 'HMA_WRITE_FAILED' -Step 'config-write' -InstanceIndex $instanceIndex -Fields $cloneFields)
    }
    $text = ($document | ConvertTo-Json -Depth $script:ConcealmentJsonDepth)
    $written = $null
    try {
        $written = $text | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        $written = $null
    }
    $writtenVersion = -1
    if ($null -ne $written -and $null -ne $written.PSObject.Properties['configVersion']) {
        $writtenVersion = [int]$written.configVersion
    }
    if ($writtenVersion -ne $script:ConcealmentConfigVersion -or
        $null -eq $written.PSObject.Properties['templates'].Value.PSObject.Properties[$script:ConcealmentTemplateName]) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The prepared HMA configuration no longer describes the supported schema and was not written.' -Data (New-ConcealmentState -Code 'HMA_WRITE_FAILED' -Step 'config-write' -InstanceIndex $instanceIndex -Fields $cloneFields)
    }

    $originalText = [string]$config.Data.Text
    $originalSha = [string]$config.Data.Sha256
    $backupPath = [string]$config.Data.ConfigPath + '.backup-' + $originalSha.Substring(0, 12)
    $existingBackupCommand = New-ConcealmentGuestCommand -Command ('ls ' + $backupPath) -InstanceIndex $instanceIndex
    if ($existingBackupCommand.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message $existingBackupCommand.Message -Data (New-ConcealmentState -Code ([string]$existingBackupCommand.Data.Code) -Step 'config-backup' -InstanceIndex $instanceIndex -Fields ($cloneFields + @{ BackupPath = $backupPath }))
    }
    $existingBackup = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $instanceIndex -Command $existingBackupCommand.Data.Command -Runner $Runner
    if ($null -eq $existingBackup -or $existingBackup.ExitCode -ne 0) {
        $backup = Set-ConcealmentGuestText -ManagerPath $manager -InstanceIndex $instanceIndex -Path $backupPath -Text $originalText -Journal $Journal -Runner $Runner
        if ($backup.Status -ne 'Success') {
            $backupCode = if ([string]$backup.Data.Code -ceq 'JOURNAL_WRITE_FAILED') { 'JOURNAL_WRITE_FAILED' } else { 'HMA_BACKUP_FAILED' }
            return New-ToolkitRootFailure -Journal $Journal -Message $backup.Message -Data (New-ConcealmentState -Code $backupCode -Step 'config-backup' -InstanceIndex $instanceIndex -Fields ($cloneFields + @{ BackupPath = $backupPath }))
        }
    }
    $readBack = Get-ConcealmentGuestFile -ManagerPath $manager -InstanceIndex $instanceIndex -Path $backupPath -Runner $Runner
    $readBackBytes = 0L
    if ($null -ne $readBack) {
        $readBackBytes = [long](New-Object Text.UTF8Encoding($false)).GetByteCount($readBack)
    }
    $originalBytes = [long](New-Object Text.UTF8Encoding($false)).GetByteCount($originalText)
    if ($null -eq $readBack -or $readBackBytes -ne $originalBytes -or
        (Get-ConcealmentTextSha256 -Text $readBack) -cne $originalSha) {
        return New-ToolkitRootFailure -Journal $Journal -Message "The HMA configuration backup at $backupPath could not be read back byte for byte, so the original configuration was not overwritten." -Data (New-ConcealmentState -Code 'HMA_BACKUP_FAILED' -Step 'config-backup' -InstanceIndex $instanceIndex -Fields ($cloneFields + @{ BackupPath = $backupPath }))
    }

    $write = Set-ConcealmentGuestText -ManagerPath $manager -InstanceIndex $instanceIndex -Path ([string]$config.Data.ConfigPath) -Text $text -Journal $Journal -Runner $Runner
    if ($write.Status -ne 'Success') {
        return $write
    }

    $handoff = @()
    $flatSteps = @()
    foreach ($packageName in $selected) {
        $packageSteps = @(Get-KernelSUProfileSteps -PackageName $packageName)
        $handoff += , $packageSteps
        $flatSteps += $packageSteps
    }
    $message = "The blacklist Root template was applied to $($selected.Count) explicitly selected app(s) on the verified clone at index $instanceIndex. The KernelSU Superuser profile is not machine readable, so confirm it in the app: " + ($flatSteps -join ' ')
    $state = New-ConcealmentState -Code 'OK' -Step 'complete' -InstanceIndex $instanceIndex -Fields @{
        Packages         = $selected
        InScope          = $selected
        TemplateName     = $script:ConcealmentTemplateName
        TemplatePackages = $templatePackages
        IsWhitelist      = $false
        HmaConfigVersion = $config.Data.HmaConfigVersion
        BackupPath       = $backupPath
        BackupVerified   = $true
        Handoff          = $handoff
        CloneIndex       = $instanceIndex
        CloneName        = $cloneName
    }
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message $message -Data $state
        Complete-OperationJournal -Journal $Journal -Result (Get-ToolkitResult -Status 'Success' -Message $message -Data $state)
    }
    catch {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The applied concealment scope could not be journaled.' -Data (New-ConcealmentState -Code 'JOURNAL_WRITE_FAILED' -Step 'complete' -InstanceIndex $instanceIndex -Fields $cloneFields)
    }
    return Get-ToolkitResult -Status 'Success' -Message $message -Data $state
}

function Get-KernelSUProfileSteps {
    param([string]$PackageName)

    if (-not (Test-ConcealmentPackageName -Name $PackageName)) {
        return @()
    }
    return @(
        "Open KernelSU Superuser and select $PackageName.",
        'Keep Superuser disabled.',
        'Choose Custom and enable Umount modules.'
    )
}

function Test-Concealment {
    param(
        [string]$ManagerPath,
        [int]$InstanceIndex,
        [string[]]$Packages,
        [scriptblock]$Runner = $null
    )

    $manager = ConvertTo-ToolkitFullPath -Path $ManagerPath
    if ($null -eq $manager -or $InstanceIndex -lt 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The concealment verification manager is invalid.' -Data (New-ConcealmentState -Code 'MANAGER_UNAVAILABLE' -Step 'verify' -InstanceIndex $InstanceIndex)
    }
    $scope = Get-ConcealmentPackageScope -Packages $Packages -InstanceIndex $InstanceIndex
    if ($scope.Status -ne 'Success') {
        return Get-ToolkitResult -Status 'CriticalError' -Message $scope.Message -Data $scope.Data
    }
    $selected = @($scope.Data.Packages)

    $config = Read-ConcealmentHmaConfig -ManagerPath $manager -InstanceIndex $InstanceIndex -Runner $Runner
    if ($config.Status -ne 'Success') {
        return New-ConcealmentHandoff -Journal $null -Reason $config.Message -State (New-ConcealmentState -Code ([string]$config.Data.Code) -Step 'config-read' -InstanceIndex $InstanceIndex -Fields @{ HmaConfigVersion = $config.Data.HmaConfigVersion })
    }

    $packageList = Get-ConcealmentPackageList -ManagerPath $manager -InstanceIndex $InstanceIndex -Runner $Runner
    if ($packageList.Status -ne 'Success') {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The installed package list could not be read, so the concealment scope and the Root template contents cannot be reported from observation.' -Data $packageList.Data
    }
    $installed = @($packageList.Data)

    $document = $config.Data.Document
    $stored = Get-ConcealmentStoredRootTemplate -Document $document -InstanceIndex $InstanceIndex
    $inScope = @()
    $outOfScope = @()
    foreach ($packageName in $selected) {
        $assigned = $false
        $scopeProperty = $document.PSObject.Properties['scope']
        if ($null -ne $scopeProperty) {
            $storedScope = $scopeProperty.Value
            if ($null -ne $storedScope.PSObject.Properties[$packageName]) {
                if ([string]$storedScope.PSObject.Properties[$packageName].Value -ceq [string]$script:ConcealmentTemplateName) {
                    $assigned = $true
                }
            }
        }
        if ($assigned) {
            $inScope += $packageName
        }
        else {
            $outOfScope += $packageName
        }
    }

    $kernelSuInstalled = Test-ConcealmentPackageInstalled -ManagerPath $manager -InstanceIndex $InstanceIndex -PackageName $script:ConcealmentKernelSUPackage -Runner $Runner
    if ($null -eq $kernelSuInstalled) {
        return New-ToolkitRootFailure -Journal $null -Message "The KernelSU package state on the instance at index $InstanceIndex could not be read, so no KernelSU profile state is claimed in either direction." -Data (New-ConcealmentState -Code 'ADB_FAILED' -Step 'verify' -InstanceIndex $InstanceIndex)
    }
    $allowlistPresent = $false
    $allowlistLength = -1
    $allowlistCommand = New-ConcealmentGuestCommand -Command ('ls -l ' + $script:ConcealmentKernelSUAllowlistPath) -InstanceIndex $InstanceIndex
    if ($allowlistCommand.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $null -Message $allowlistCommand.Message -Data (New-ConcealmentState -Code ([string]$allowlistCommand.Data.Code) -Step 'verify' -InstanceIndex $InstanceIndex)
    }
    $allowlistCall = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $InstanceIndex -Command $allowlistCommand.Data.Command -Runner $Runner
    if ($null -ne $allowlistCall -and $allowlistCall.ExitCode -eq 0) {
        $allowlistPresent = $true
        $lengthMatch = [regex]::Match([string]$allowlistCall.Text, '(?m)^\S+\s+\d+\s+\S+\s+\S+\s+(\d+)\s')
        if ($lengthMatch.Success) {
            $parsedLength = 0L
            if ([long]::TryParse($lengthMatch.Groups[1].Value, [ref]$parsedLength)) {
                $allowlistLength = $parsedLength
            }
        }
    }

    $handoff = @()
    $flatSteps = @()
    foreach ($packageName in $selected) {
        $packageSteps = @(Get-KernelSUProfileSteps -PackageName $packageName)
        $handoff += , $packageSteps
        $flatSteps += $packageSteps
    }

    $observed = @{
        Packages             = $selected
        InScope              = $inScope
        OutOfScope           = $outOfScope
        TemplateName         = $script:ConcealmentTemplateName
        TemplatePackages     = @($stored.TemplatePackages)
        TemplateFound        = $stored.Found
        IsWhitelist          = $stored.IsWhitelist
        HmaConfigVersion     = $config.Data.HmaConfigVersion
        InstalledCount       = $installed.Count
        KernelSUInstalled    = $kernelSuInstalled
        AllowlistPresent     = $allowlistPresent
        AllowlistLength      = $allowlistLength
        ProfileStateObserved = $false
        Handoff              = $handoff
    }
    $evidenceMessage = "HMA scope covers $($inScope.Count) of $($selected.Count) requested app(s) on the instance at index $InstanceIndex through the blacklist Root template, read from the installed configuration version $($config.Data.HmaConfigVersion). The KernelSU Superuser profile is not machine readable, so confirm it in the app: " + ($flatSteps -join ' ')

    if ($stored.IsWhitelist) {
        return Get-ToolkitResult -Status 'Warning' -Message "The stored HMA template $($script:ConcealmentTemplateName) is a whitelist template, so this workflow cannot report it as a verified blacklist scope. Create a blacklist Root template in the supported UI. $evidenceMessage" -Data (New-ConcealmentState -Code 'TEMPLATE_NOT_BLACKLIST' -Step 'verify' -InstanceIndex $InstanceIndex -Fields $observed)
    }
    if (-not $stored.Found -or @($stored.TemplatePackages).Count -eq 0) {
        return Get-ToolkitResult -Status 'Warning' -Message "The stored HMA configuration carries no usable $($script:ConcealmentTemplateName) template: the template is missing or its app list is empty, so an assignment to it hides nothing and is not reported as verified. Create the blacklist Root template in the supported UI. $evidenceMessage" -Data (New-ConcealmentState -Code 'TEMPLATE_MISSING' -Step 'verify' -InstanceIndex $InstanceIndex -Fields $observed)
    }
    if ($inScope.Count -ne $selected.Count) {
        return Get-ToolkitResult -Status 'Warning' -Message "Concealment is not fully applied: $($inScope.Count) of $($selected.Count) requested app(s) carry the blacklist Root template. Out of scope: $($outOfScope -join ', '). $evidenceMessage" -Data (New-ConcealmentState -Code 'SCOPE_INCOMPLETE' -Step 'verify' -InstanceIndex $InstanceIndex -Fields $observed)
    }
    if (-not $kernelSuInstalled) {
        return Get-ToolkitResult -Status 'Warning' -Message "The HMA scope on the instance at index $InstanceIndex carries the blacklist Root template for every requested app, but the KernelSU package is not installed there, so this workflow claims no KernelSU profile state on this instance. On an Android 12 Kitsune clone the root comes from Kitsune, not KernelSU, so the manual handoff is the only remaining step. $evidenceMessage" -Data (New-ConcealmentState -Code 'KERNELSU_ABSENT' -Step 'verify' -InstanceIndex $InstanceIndex -Fields $observed)
    }
    return Get-ToolkitResult -Status 'Success' -Message $evidenceMessage -Data (New-ConcealmentState -Code 'OK' -Step 'verify' -InstanceIndex $InstanceIndex -Fields $observed)
}

# The apps the toolkit itself assigned to the blacklist Root template, read from the installed HMA
# configuration. The verifier needs a package selection, and this is the one the toolkit can observe
# without asking the operator to name apps again.
function Get-ConcealmentScopePackages {
    param([object]$Document)

    $packages = @()
    $scopeProperty = $Document.PSObject.Properties['scope']
    if ($null -eq $scopeProperty -or $scopeProperty.Value -isnot [pscustomobject]) {
        return $packages
    }
    foreach ($entry in @($scopeProperty.Value.PSObject.Properties)) {
        if (Test-ConcealmentPackageName -Name $entry.Name) {
            $packages += $entry.Name
        }
    }
    return @($packages | Sort-Object -Unique)
}

# The read-only report calls the verifier here, so concealment is never a claim without evidence. The
# block is a fixed record: every field is present whether or not anything could be observed.
function Get-ConcealmentEvidence {
    param(
        [string]$ManagerPath,
        [int]$CloneIndex,
        [scriptblock]$Runner = $null
    )

    $evidence = [ordered]@{
        Target            = ''
        Status            = 'NotVerified'
        Code              = 'CLONE_UNVERIFIED'
        Packages          = @()
        InScope           = @()
        OutOfScope        = @()
        TemplateFound     = $false
        IsWhitelist       = $false
        HmaConfigVersion  = -1
        KernelSUInstalled = $false
        AllowlistPresent  = $false
        Message           = 'No concealment evidence was collected for the verified clone.'
    }
    $manager = ConvertTo-ToolkitFullPath -Path $ManagerPath
    if ($null -eq $manager -or $CloneIndex -lt 0) {
        return $evidence
    }
    $evidence['Target'] = [string]$CloneIndex
    $config = Read-ConcealmentHmaConfig -ManagerPath $manager -InstanceIndex $CloneIndex -Runner $Runner
    if ($config.Status -ne 'Success') {
        $evidence['Status'] = [string]$config.Status
        $evidence['Code'] = [string]$config.Data.Code
        $evidence['Message'] = [string]$config.Message
        return $evidence
    }
    $evidence['HmaConfigVersion'] = [int]$config.Data.HmaConfigVersion
    $stored = Get-ConcealmentStoredRootTemplate -Document $config.Data.Document -InstanceIndex $CloneIndex
    $evidence['TemplateFound'] = [bool]$stored.Found
    $evidence['IsWhitelist'] = [bool]$stored.IsWhitelist
    $scoped = @(Get-ConcealmentScopePackages -Document $config.Data.Document)
    if ($scoped.Count -eq 0) {
        $evidence['Code'] = 'SCOPE_EMPTY'
        $evidence['Message'] = "The installed HMA configuration on the verified clone at index $CloneIndex assigns the blacklist $($script:ConcealmentTemplateName) template to no app, so no concealment is claimed."
        return $evidence
    }
    $verification = Test-Concealment -ManagerPath $manager -InstanceIndex $CloneIndex -Packages $scoped -Runner $Runner
    $evidence['Status'] = [string]$verification.Status
    $evidence['Code'] = [string]$verification.Data.Code
    $evidence['Packages'] = @($scoped)
    $evidence['InScope'] = @($verification.Data.InScope)
    $evidence['OutOfScope'] = @($verification.Data.OutOfScope)
    $evidence['KernelSUInstalled'] = [bool]$verification.Data.KernelSUInstalled
    $evidence['AllowlistPresent'] = [bool]$verification.Data.AllowlistPresent
    $evidence['Message'] = [string]$verification.Message
    return $evidence
}
