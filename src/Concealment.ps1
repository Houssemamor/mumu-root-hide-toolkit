$script:ConcealmentHmaPackage = 'org.frknkrc44.hma_oss'
$script:ConcealmentHmaAssetId = 'hma'
$script:ConcealmentVectorAssetId = 'vector'
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
$script:ConcealmentVectorModuleName = 'vector'
$script:ConcealmentVectorModulePath = '/data/adb/modules/vector'
$script:ConcealmentGuestStagePath = '/data/local/tmp'
$script:ConcealmentPackageListCommand = 'shell pm list packages'
$script:ConcealmentPackagePattern = '^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)+$'
$script:ConcealmentMaximumPackageLength = 255
$script:ConcealmentMaximumGuestPathLength = 255
$script:ConcealmentJsonDepth = 12
$script:ConcealmentStateFields = @(
    'Code', 'Step', 'InstanceIndex', 'Packages', 'TemplateName', 'TemplatePackages',
    'IsWhitelist', 'HmaConfigVersion', 'InScope', 'Installed', 'AlreadyPresent',
    'KernelSUInstalled', 'AllowlistPresent', 'AllowlistLength', 'ProfileStateObserved',
    'BackupPath', 'ConfigPath', 'Handoff'
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
        Packages             = @()
        TemplateName         = [string]$script:ConcealmentTemplateName
        TemplatePackages     = @()
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
        [hashtable]$State
    )

    $state = $State
    $state['Steps'] = @($script:ConcealmentUiHandoffSteps)
    $message = 'The installed HMA configuration is not a supported schema, so no configuration was written and no app scope changed. Configure it in the supported UI instead: ' + (@($script:ConcealmentUiHandoffSteps) -join ' ')
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

function Test-ConcealmentPackageInstalled {
    param(
        [string]$ManagerPath,
        [int]$InstanceIndex,
        [string]$PackageName,
        [scriptblock]$Runner = $null
    )

    $call = Invoke-ToolkitManagerAdb -ManagerPath $ManagerPath -InstanceIndex $InstanceIndex -Command ('shell dumpsys package ' + $PackageName) -Runner $Runner
    if ($null -eq $call -or $call.ExitCode -ne 0) {
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
    if ($null -eq $installRootProperty -or $installRootProperty.Value -isnot [string] -or
        $null -eq $installManagerProperty -or $installManagerProperty.Value -isnot [string]) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The selected instance install is invalid.' -Data (New-ConcealmentState -Code 'INSTANCE_INVALID' -Step 'instance' -InstanceIndex $instanceIndex)
    }
    $installRoot = ConvertTo-ToolkitFullPath -Path $installRootProperty.Value
    $manager = ConvertTo-ToolkitFullPath -Path $installManagerProperty.Value
    if ($null -eq $manager -or $null -eq $installRoot -or
        -not (Test-ToolkitManagerFile -Path $manager -InstallRoot $installRoot)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The MuMu manager is not a valid manager inside the selected install root.' -Data (New-ConcealmentState -Code 'MANAGER_UNAVAILABLE' -Step 'instance' -InstanceIndex $instanceIndex)
    }
    return Get-ToolkitResult -Status 'Success' -Message 'The selected instance is usable.' -Data @{ Manager = $manager; Index = $instanceIndex }
}

function Read-ConcealmentHmaConfig {
    param(
        [string]$ManagerPath,
        [int]$InstanceIndex,
        [scriptblock]$Runner = $null
    )

    $readCommand = 'shell su -c "cat ' + $script:ConcealmentConfigPath + '"'
    $call = Invoke-ToolkitManagerAdb -ManagerPath $ManagerPath -InstanceIndex $InstanceIndex -Command $readCommand -Runner $Runner
    if ($null -eq $call -or $call.ExitCode -ne 0) {
        return Get-ToolkitResult -Status 'Warning' -Message ("The HMA configuration could not be read from $script:ConcealmentConfigPath.") -Data (New-ConcealmentState -Code 'HMA_CONFIG_UNREADABLE' -Step 'config-read' -InstanceIndex $InstanceIndex)
    }
    $text = [string]$call.Text
    if ([string]::IsNullOrWhiteSpace($text)) {
        return Get-ToolkitResult -Status 'Warning' -Message 'The HMA configuration read returned nothing.' -Data (New-ConcealmentState -Code 'HMA_CONFIG_UNREADABLE' -Step 'config-read' -InstanceIndex $InstanceIndex)
    }

    $unsupported = {
        param([string]$Reason, [int]$FoundVersion)

        return Get-ToolkitResult -Status 'Warning' -Message $Reason -Data (New-ConcealmentState -Code 'HMA_SCHEMA_UNSUPPORTED' -Step 'config-read' -InstanceIndex $InstanceIndex -Fields @{ HmaConfigVersion = $FoundVersion })
    }

    $document = $null
    try {
        Assert-NoDuplicateJournalProperty -Json $text
        $document = $text | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return (& $unsupported 'The HMA configuration is not strict JSON and was not modified.' -1)
    }
    if ($null -eq $document -or $document -is [Array] -or $document -isnot [pscustomobject]) {
        return (& $unsupported 'The HMA configuration is not a supported document and was not modified.' -1)
    }
    $versionProperty = $document.PSObject.Properties['configVersion']
    if ($null -eq $versionProperty -or
        ($versionProperty.Value -isnot [int] -and $versionProperty.Value -isnot [long])) {
        return (& $unsupported 'The HMA configuration carries no usable configVersion and was not modified.' -1)
    }
    $configVersion = [int]$versionProperty.Value
    if ($configVersion -ne $script:ConcealmentConfigVersion) {
        return (& $unsupported "The HMA configuration version $configVersion is not the supported version $($script:ConcealmentConfigVersion) and was not modified." $configVersion)
    }

    $templatesProperty = $document.PSObject.Properties['templates']
    if ($null -ne $templatesProperty -and
        ($null -eq $templatesProperty.Value -or $templatesProperty.Value -is [Array] -or $templatesProperty.Value -isnot [pscustomobject])) {
        return (& $unsupported 'The HMA configuration has no usable template map and was not modified.' $configVersion)
    }
    $templateProperty = $null
    if ($null -ne $templatesProperty) {
        $templateProperty = $templatesProperty.Value.PSObject.Properties[$script:ConcealmentTemplateName]
    }
    if ($null -ne $templateProperty) {
        if ($null -eq $templateProperty.Value -or $templateProperty.Value -is [Array] -or $templateProperty.Value -isnot [pscustomobject]) {
            return (& $unsupported "The HMA configuration template $($script:ConcealmentTemplateName) is not a supported template and was not modified." $configVersion)
        }
        $appListProperty = $templateProperty.Value.PSObject.Properties['appList']
        if ($null -ne $appListProperty) {
            if ($null -eq $appListProperty.Value -or $appListProperty.Value -isnot [Array]) {
                return (& $unsupported "The HMA configuration template $($script:ConcealmentTemplateName) has no usable app list and was not modified." $configVersion)
            }
            foreach ($entry in @($appListProperty.Value)) {
                if ($entry -isnot [string] -or [string]::IsNullOrWhiteSpace($entry)) {
                    return (& $unsupported "The HMA configuration template $($script:ConcealmentTemplateName) has an unusable app list entry and was not modified." $configVersion)
                }
            }
        }
    }

    $appsProperty = $document.PSObject.Properties['apps']
    if ($null -ne $appsProperty) {
        if ($null -eq $appsProperty.Value -or $appsProperty.Value -is [Array] -or $appsProperty.Value -isnot [pscustomobject]) {
            return (& $unsupported 'The HMA configuration has no usable app scope map and was not modified.' $configVersion)
        }
        foreach ($appProperty in @($appsProperty.Value.PSObject.Properties)) {
            if ([string]::IsNullOrWhiteSpace($appProperty.Name) -or
                $appProperty.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($appProperty.Value)) {
                return (& $unsupported 'The HMA configuration app scope map is unusable and was not modified.' $configVersion)
            }
        }
    }

    $data = New-ConcealmentState -Code 'OK' -Step 'config-read' -InstanceIndex $InstanceIndex -Fields @{
        HmaConfigVersion = $configVersion
    }
    $data['Document'] = $document
    $data['Text'] = $text
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $data['Sha256'] = [BitConverter]::ToString($sha.ComputeHash((New-Object Text.UTF8Encoding($false)).GetBytes($text))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
    return Get-ToolkitResult -Status 'Success' -Message 'The supported HMA configuration was read.' -Data $data
}

function Get-HmaConfig {
    param(
        [object]$Instance,
        [scriptblock]$Runner = $null
    )

    $resolved = Resolve-ConcealmentInstance -Instance $Instance
    if ($resolved.Status -ne 'Success') {
        return New-ConcealmentHandoff -Journal $null -State $resolved.Data
    }
    $config = Read-ConcealmentHmaConfig -ManagerPath $resolved.Data.Manager -InstanceIndex $resolved.Data.Index -Runner $Runner
    if ($config.Status -ne 'Success') {
        return New-ConcealmentHandoff -Journal $null -State (New-ConcealmentState -Code ([string]$config.Data.Code) -Step 'config-read' -InstanceIndex $resolved.Data.Index)
    }
    return Get-ToolkitResult -Status 'Success' -Message $config.Message -Data $config.Data
}

function New-ReusableRootTemplate {
    param(
        [object]$Instance,
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
    $instanceIndex = [int]$resolved.Data.Index

    $config = Read-ConcealmentHmaConfig -ManagerPath $resolved.Data.Manager -InstanceIndex $instanceIndex -Runner $Runner
    if ($config.Status -ne 'Success') {
        return New-ConcealmentHandoff -Journal $Journal -State (New-ConcealmentState -Code ([string]$config.Data.Code) -Step 'config-read' -InstanceIndex $instanceIndex)
    }

    $packageList = Get-ConcealmentPackageList -ManagerPath $resolved.Data.Manager -InstanceIndex $instanceIndex -Runner $Runner
    if ($packageList.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message $packageList.Message -Data $packageList.Data
    }
    $installed = @($packageList.Data)

    $template = Get-ConcealmentRootTemplate -Document $config.Data.Document -InstalledPackages $installed -InstanceIndex $instanceIndex
    if ($template.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message $template.Message -Data $template.Data
    }

    $state = New-ConcealmentState -Code 'OK' -Step 'template' -InstanceIndex $instanceIndex -Fields @{
        TemplateName     = $script:ConcealmentTemplateName
        TemplatePackages = @($template.Data.TemplatePackages)
        IsWhitelist      = $false
        HmaConfigVersion = $config.Data.HmaConfigVersion
    }
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message "The reusable blacklist Root template was verified with $(@($template.Data.TemplatePackages).Count) package(s). No configuration was written." -Data $state
    }
    catch {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The verified Root template could not be journaled.' -Data (New-ConcealmentState -Code 'JOURNAL_WRITE_FAILED' -Step 'template' -InstanceIndex $instanceIndex)
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

    $existing = @()
    $isWhitelist = $false
    $templatesProperty = $Document.PSObject.Properties['templates']
    if ($null -ne $templatesProperty) {
        $templateProperty = $templatesProperty.Value.PSObject.Properties[$script:ConcealmentTemplateName]
        if ($null -ne $templateProperty) {
            $whitelistProperty = $templateProperty.Value.PSObject.Properties['isWhitelist']
            if ($null -ne $whitelistProperty -and $whitelistProperty.Value -is [bool]) {
                if ($whitelistProperty.Value -eq $true) {
                    return (& $invalid "The existing HMA template $($script:ConcealmentTemplateName) is a whitelist template and is never flipped to a blacklist automatically. Rename or remove it in the HMA app, then run the workflow again.")
                }
                $isWhitelist = $false
            }
            $appListProperty = $templateProperty.Value.PSObject.Properties['appList']
            if ($null -ne $appListProperty) {
                $existing = @($appListProperty.Value | ForEach-Object { [string]$_ })
            }
        }
    }

    $installed = @()
    foreach ($rootPackage in $script:ConcealmentTemplatePackages) {
        if ($null -eq $InstalledPackages -or @($InstalledPackages) -ccontains $rootPackage) {
            $installed += $rootPackage
        }
    }
    $merged = @(@($existing) + @($installed) | Select-Object -Unique)
    return Get-ToolkitResult -Status 'Success' -Message 'The reusable Root template is described.' -Data (New-ConcealmentState -Code 'OK' -Step 'template' -InstanceIndex $InstanceIndex -Fields @{
            TemplateName     = $script:ConcealmentTemplateName
            TemplatePackages = $merged
            IsWhitelist      = $isWhitelist
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
    if ($Path -notmatch '^/[A-Za-z0-9._/-]+$' -or $Path -match '//' -or
        $Path -match '(^|/)\.\.(/|$)' -or $Path.Length -gt $script:ConcealmentMaximumGuestPathLength) {
        return New-ToolkitRootFailure -Journal $Journal -Message "The guest file path is not a plain absolute path: $Path" -Data (New-ConcealmentState -Code 'GUEST_WRITE_FAILED' -Step 'guest-write' -InstanceIndex $InstanceIndex)
    }
    if ($Text -isnot [string] -or [string]::IsNullOrWhiteSpace($Text)) {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The guest file content is empty.' -Data (New-ConcealmentState -Code 'GUEST_WRITE_FAILED' -Step 'guest-write' -InstanceIndex $InstanceIndex)
    }

    $payload = [Convert]::ToBase64String((New-Object Text.UTF8Encoding($false)).GetBytes($Text))
    $temporaryPath = $Path + '.toolkit.tmp'
    $writeCommand = 'shell su -c "echo ' + $payload + ' | base64 -d > ' + $temporaryPath + ' && mv ' + $temporaryPath + ' ' + $Path + '"'
    $call = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $InstanceIndex -Command $writeCommand -Runner $Runner
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

function Install-ConcealmentDependencies {
    param(
        [object]$Instance,
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
    $instanceIndex = [int]$resolved.Data.Index

    $hmaAsset = Save-ToolkitManifestAsset -Manifest $Manifest -Id $script:ConcealmentHmaAssetId -CacheRoot $CacheRoot
    if ($hmaAsset.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message $hmaAsset.Message -Data (New-ConcealmentState -Code ([string]$hmaAsset.Data.Code) -Step 'asset' -InstanceIndex $instanceIndex)
    }
    $vectorAsset = Save-ToolkitManifestAsset -Manifest $Manifest -Id $script:ConcealmentVectorAssetId -CacheRoot $CacheRoot
    if ($vectorAsset.Status -ne 'Success') {
        return New-ToolkitRootFailure -Journal $Journal -Message $vectorAsset.Message -Data (New-ConcealmentState -Code ([string]$vectorAsset.Data.Code) -Step 'asset' -InstanceIndex $instanceIndex)
    }
    $hmaPath = [string]$hmaAsset.Data.Asset
    $vectorPath = [string]$vectorAsset.Data.Asset
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message 'The pinned HMA and Vector assets were verified by size and SHA-256 before any instance change.' -Data (New-ConcealmentState -Code 'OK' -Step 'asset' -InstanceIndex $instanceIndex)
    }
    catch {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The verified concealment dependencies could not be journaled.' -Data (New-ConcealmentState -Code 'JOURNAL_WRITE_FAILED' -Step 'asset' -InstanceIndex $instanceIndex)
    }

    $installed = @()
    $alreadyPresent = @()
    $hmaInstalled = Test-ConcealmentPackageInstalled -ManagerPath $manager -InstanceIndex $instanceIndex -PackageName $script:ConcealmentHmaPackage -Runner $Runner
    if (-not $hmaInstalled) {
        $installCommand = Format-Android12InstallCommand -Path $hmaPath
        if ($installCommand.Status -ne 'Success') {
            return New-ToolkitRootFailure -Journal $Journal -Message $installCommand.Message -Data (New-ConcealmentState -Code 'ASSET_PATH_INVALID' -Step 'hma-install' -InstanceIndex $instanceIndex)
        }
        $apkInstall = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $instanceIndex -Command ([string]$installCommand.Data) -Runner $Runner
        if ($null -eq $apkInstall -or $apkInstall.ExitCode -ne 0) {
            return New-ToolkitRootFailure -Journal $Journal -Message "The verified HMA APK was not installed on the instance at index $instanceIndex." -Data (New-ConcealmentState -Code 'APK_INSTALL_FAILED' -Step 'hma-install' -InstanceIndex $instanceIndex)
        }
        if (-not (Test-ConcealmentPackageInstalled -ManagerPath $manager -InstanceIndex $instanceIndex -PackageName $script:ConcealmentHmaPackage -Runner $Runner)) {
            return New-ToolkitRootFailure -Journal $Journal -Message "The verified HMA APK install did not leave the package $($script:ConcealmentHmaPackage) installed on the instance at index $instanceIndex." -Data (New-ConcealmentState -Code 'APK_INSTALL_FAILED' -Step 'hma-install' -InstanceIndex $instanceIndex)
        }
        $installed += $script:ConcealmentHmaAssetId
    }
    else {
        $alreadyPresent += $script:ConcealmentHmaAssetId
    }

    $moduleList = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $instanceIndex -Command ('shell su -c "ls ' + $script:ConcealmentVectorModulePath + '"') -Runner $Runner
    if ($null -ne $moduleList -and $moduleList.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace([string]$moduleList.Text)) {
        $alreadyPresent += $script:ConcealmentVectorAssetId
    }
    else {
        $assetName = [IO.Path]::GetFileName($vectorPath)
        $stagedPath = $script:ConcealmentGuestStagePath + '/' + $assetName
        $extractPath = $script:ConcealmentGuestStagePath + '/vector-extract-' + [Guid]::NewGuid().ToString('N')
        $push = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $instanceIndex -Command ('push "' + $vectorPath + '" ' + $stagedPath) -Runner $Runner
        if ($null -eq $push -or $push.ExitCode -ne 0) {
            return New-ToolkitRootFailure -Journal $Journal -Message 'The verified Vector module was not staged on the instance.' -Data (New-ConcealmentState -Code 'MODULE_PUSH_FAILED' -Step 'vector-install' -InstanceIndex $instanceIndex)
        }
        $extract = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $instanceIndex -Command ('shell su -c "mkdir -p ' + $extractPath + ' && unzip -o ' + $stagedPath + ' -d ' + $extractPath + '"') -Runner $Runner
        if ($null -eq $extract -or $extract.ExitCode -ne 0) {
            return New-ToolkitRootFailure -Journal $Journal -Message 'The verified Vector module was not extracted on the instance.' -Data (New-ConcealmentState -Code 'MODULE_EXTRACT_FAILED' -Step 'vector-install' -InstanceIndex $instanceIndex)
        }
        $listing = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $instanceIndex -Command ('shell su -c "ls ' + $extractPath + '"') -Runner $Runner
        $entries = @()
        if ($null -ne $listing -and $listing.ExitCode -eq 0) {
            $entries = @(([string]$listing.Text) -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() })
        }
        if ($entries.Count -ne 1 -or $entries[0] -cne $script:ConcealmentVectorModuleName) {
            return New-ToolkitRootFailure -Journal $Journal -Message "The verified Vector archive does not contain exactly the $($script:ConcealmentVectorModuleName) module directory and was not installed." -Data (New-ConcealmentState -Code 'MODULE_LAYOUT_UNSUPPORTED' -Step 'vector-install' -InstanceIndex $instanceIndex)
        }
        $move = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $instanceIndex -Command ('shell su -c "mv ' + $extractPath + '/' + $script:ConcealmentVectorModuleName + ' ' + $script:ConcealmentVectorModulePath + ' && rmdir ' + $extractPath + '"') -Runner $Runner
        if ($null -eq $move -or $move.ExitCode -ne 0) {
            return New-ToolkitRootFailure -Journal $Journal -Message "The extracted Vector module was not moved into $($script:ConcealmentVectorModulePath)." -Data (New-ConcealmentState -Code 'MODULE_INSTALL_FAILED' -Step 'vector-install' -InstanceIndex $instanceIndex)
        }
        $moduleList = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $instanceIndex -Command ('shell su -c "ls ' + $script:ConcealmentVectorModulePath + '"') -Runner $Runner
        if ($null -eq $moduleList -or $moduleList.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace([string]$moduleList.Text)) {
            return New-ToolkitRootFailure -Journal $Journal -Message "The Vector module directory $($script:ConcealmentVectorModulePath) is not present after the install." -Data (New-ConcealmentState -Code 'MODULE_INSTALL_FAILED' -Step 'vector-install' -InstanceIndex $instanceIndex)
        }
        $installed += $script:ConcealmentVectorAssetId
    }

    $status = if ($installed.Count -eq 0) { 'AlreadyApplied' } else { 'Success' }
    $message = "Concealment dependencies are in place on the instance at index $instanceIndex. Installed: $($installed.Count). Already present: $($alreadyPresent.Count)."
    $state = New-ConcealmentState -Code 'OK' -Step 'complete' -InstanceIndex $instanceIndex -Fields @{
        Installed      = @($installed)
        AlreadyPresent = @($alreadyPresent)
    }
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message $message -Data $state
        Complete-OperationJournal -Journal $Journal -Result (Get-ToolkitResult -Status $status -Message $message -Data $state)
    }
    catch {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The installed concealment dependencies could not be journaled.' -Data (New-ConcealmentState -Code 'JOURNAL_WRITE_FAILED' -Step 'complete' -InstanceIndex $instanceIndex)
    }
    return Get-ToolkitResult -Status $status -Message $message -Data $state
}

function Set-AppConcealment {
    param(
        [object]$Instance,
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
    $instanceIndex = [int]$resolved.Data.Index

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
        return New-ToolkitRootFailure -Journal $Journal -Message "The selection covers all $($installed.Count) installed package(s), which is a global scope. Concealment is applied only to an explicit subset of apps; select fewer apps and run the workflow again." -Data (New-ConcealmentState -Code 'ALL_APPS_REFUSED' -Step 'selection' -InstanceIndex $instanceIndex -Fields @{ Packages = $selected })
    }
    foreach ($packageName in $selected) {
        if ($installed -cnotcontains $packageName) {
            return New-ToolkitRootFailure -Journal $Journal -Message "The selected package is not installed on the instance: $packageName" -Data (New-ConcealmentState -Code 'PACKAGE_NOT_INSTALLED' -Step 'selection' -InstanceIndex $instanceIndex -Fields @{ Packages = $selected })
        }
    }

    $config = Read-ConcealmentHmaConfig -ManagerPath $manager -InstanceIndex $instanceIndex -Runner $Runner
    if ($config.Status -ne 'Success') {
        return New-ConcealmentHandoff -Journal $Journal -State (New-ConcealmentState -Code ([string]$config.Data.Code) -Step 'config-read' -InstanceIndex $instanceIndex)
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

    $applications = [ordered]@{}
    $appsProperty = $config.Data.Document.PSObject.Properties['apps']
    if ($null -ne $appsProperty) {
        foreach ($property in @($appsProperty.Value.PSObject.Properties)) {
            if (-not (Test-ConcealmentPackageName -Name $property.Name)) {
                return New-ToolkitRootFailure -Journal $Journal -Message "The existing HMA app scope holds a key that is not a package name, so it is never rewritten: $($property.Name)" -Data (New-ConcealmentState -Code 'HMA_TEMPLATE_INVALID' -Step 'config-write' -InstanceIndex $instanceIndex)
            }
            $applications[[string]$property.Name] = [string]$property.Value
        }
    }
    foreach ($packageName in $selected) {
        $applications[[string]$packageName] = [string]$script:ConcealmentTemplateName
    }
    $document['apps'] = $applications

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
        return New-ToolkitRootFailure -Journal $Journal -Message 'The prepared HMA configuration no longer describes the supported schema and was not written.' -Data (New-ConcealmentState -Code 'HMA_WRITE_FAILED' -Step 'config-write' -InstanceIndex $instanceIndex)
    }

    $backupPath = [string]$config.Data.ConfigPath + '.backup-' + ([string]$config.Data.Sha256).Substring(0, 12)
    $existingBackup = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $instanceIndex -Command ('shell su -c "ls ' + $backupPath + '"') -Runner $Runner
    if ($null -eq $existingBackup -or $existingBackup.ExitCode -ne 0) {
        $backup = Set-ConcealmentGuestText -ManagerPath $manager -InstanceIndex $instanceIndex -Path $backupPath -Text ([string]$config.Data.Text) -Journal $Journal -Runner $Runner
        if ($backup.Status -ne 'Success') {
            return New-ToolkitRootFailure -Journal $Journal -Message $backup.Message -Data (New-ConcealmentState -Code 'HMA_BACKUP_FAILED' -Step 'config-backup' -InstanceIndex $instanceIndex)
        }
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
    $message = "The blacklist Root template was applied to $($selected.Count) explicitly selected app(s) on the instance at index $instanceIndex. The KernelSU Superuser profile is not machine readable, so confirm it in the app: " + ($flatSteps -join ' ')
    $state = New-ConcealmentState -Code 'OK' -Step 'complete' -InstanceIndex $instanceIndex -Fields @{
        Packages         = $selected
        InScope          = $selected
        TemplateName     = $script:ConcealmentTemplateName
        TemplatePackages = $templatePackages
        IsWhitelist      = $false
        HmaConfigVersion = $config.Data.HmaConfigVersion
        BackupPath       = $backupPath
        Handoff          = $handoff
    }
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message $message -Data $state
        Complete-OperationJournal -Journal $Journal -Result (Get-ToolkitResult -Status 'Success' -Message $message -Data $state)
    }
    catch {
        return New-ToolkitRootFailure -Journal $Journal -Message 'The applied concealment scope could not be journaled.' -Data (New-ConcealmentState -Code 'JOURNAL_WRITE_FAILED' -Step 'complete' -InstanceIndex $instanceIndex)
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
        return New-ConcealmentHandoff -Journal $null -State (New-ConcealmentState -Code ([string]$config.Data.Code) -Step 'config-read' -InstanceIndex $InstanceIndex)
    }

    $template = Get-ConcealmentRootTemplate -Document $config.Data.Document -InstalledPackages $null -InstanceIndex $InstanceIndex
    $templatePackages = @()
    if ($template.Status -eq 'Success') {
        $templatePackages = @($template.Data.TemplatePackages)
    }

    $document = $config.Data.Document
    $inScope = @()
    foreach ($packageName in $selected) {
        $assigned = $false
        $appsProperty = $document.PSObject.Properties['apps']
        if ($null -ne $appsProperty -and $null -ne $appsProperty.Value.PSObject.Properties[$packageName]) {
            if ([string]$appsProperty.Value.PSObject.Properties[$packageName].Value -ceq [string]$script:ConcealmentTemplateName) {
                $assigned = $true
            }
        }
        if ($assigned) {
            $inScope += $packageName
        }
    }

    $kernelSuInstalled = Test-ConcealmentPackageInstalled -ManagerPath $manager -InstanceIndex $InstanceIndex -PackageName $script:ConcealmentKernelSUPackage -Runner $Runner
    $allowlistPresent = $false
    $allowlistLength = -1
    $allowlistCall = Invoke-ToolkitManagerAdb -ManagerPath $manager -InstanceIndex $InstanceIndex -Command ('shell su -c "ls -l ' + $script:ConcealmentKernelSUAllowlistPath + '"') -Runner $Runner
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
    $message = "HMA scope covers $($inScope.Count) of $($selected.Count) requested app(s) on the instance at index $InstanceIndex through the blacklist Root template. The KernelSU Superuser profile is not machine readable, so confirm it in the app: " + ($flatSteps -join ' ')

    return Get-ToolkitResult -Status 'Success' -Message $message -Data (New-ConcealmentState -Code 'OK' -Step 'verify' -InstanceIndex $InstanceIndex -Fields @{
            Packages             = $selected
            InScope              = $inScope
            TemplateName         = $script:ConcealmentTemplateName
            TemplatePackages     = $templatePackages
            HmaConfigVersion     = $config.Data.HmaConfigVersion
            KernelSUInstalled    = $kernelSuInstalled
            AllowlistPresent     = $allowlistPresent
            AllowlistLength      = $allowlistLength
            ProfileStateObserved = $false
            Handoff              = $handoff
        })
}
