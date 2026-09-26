[CmdletBinding()]
param(
    [string]$Action = '',
    [string]$InstallRoot = '',
    [int]$InstanceIndex = -1,
    [string]$StateRoot = '',
    [string[]]$Packages = @(),
    [string]$Mode = '',
    [object]$StartIndex = $null,
    [switch]$Confirmed,
    [switch]$NonInteractive,
    [switch]$SkipToolbar
)

$script:ToolkitActions = @('Detect', 'Verify', 'Target', 'Root12', 'Root15', 'Conceal', 'RemoveAds', 'Restore')
$script:ToolkitDispatchedActions = @('Detect', 'Verify', 'Target', 'Root12', 'Root15', 'Conceal', 'RemoveAds', 'Restore')
$script:ToolkitActionDescriptions = @{
    Detect    = 'Discover MuMu installations and instances and report their state.'
    Verify    = 'Collect the read-only status report for the selected instance.'
    Target    = 'Identify the instance to work on, or create or clone one. Identify changes nothing; Create and Clone need an explicit confirmation.'
    Root12    = 'Root an Android 12 instance with the pinned Kitsune release on a verified clone.'
    Root15    = 'Enable the built-in Android 15 root on a verified clone.'
    Conceal   = 'Apply the Root concealment template to explicitly selected apps on a verified clone.'
    RemoveAds = 'Suppress the MuMu campaign advertisements for the selected installation.'
    Restore   = 'Restore the MuMu campaign files from the toolkit restore point.'
    Q         = 'Quit the toolkit.'
}
$script:ToolkitRegistryRoots = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
)
$script:ToolkitRecoveryGuidance = 'Recovery: run Verify for a read-only report, then retry the action. The operation journal and the log are kept under the toolkit state directory.'

. (Join-Path $PSScriptRoot 'Common.ps1')
. (Join-Path $PSScriptRoot 'Manifest.ps1')
. (Join-Path $PSScriptRoot 'Journal.ps1')
. (Join-Path $PSScriptRoot 'Discovery.ps1')
. (Join-Path $PSScriptRoot 'Elevation.ps1')
. (Join-Path $PSScriptRoot 'Backup.ps1')
. (Join-Path $PSScriptRoot 'Ads.ps1')
. (Join-Path $PSScriptRoot 'Verification.ps1')
. (Join-Path $PSScriptRoot 'Root12.ps1')
. (Join-Path $PSScriptRoot 'Root15.ps1')
. (Join-Path $PSScriptRoot 'Concealment.ps1')
. (Join-Path $PSScriptRoot 'Target.ps1')

function Get-ToolkitActionCatalog {
    $catalog = @()
    foreach ($name in $script:ToolkitActions) {
        $catalog += [pscustomobject]@{
            Name = $name
            Description = [string]$script:ToolkitActionDescriptions[$name]
        }
    }
    $catalog += [pscustomobject]@{
        Name = 'Q'
        Description = [string]$script:ToolkitActionDescriptions['Q']
    }
    return $catalog
}

function Get-ToolkitDiscoverySources {
    $registryRoots = @()
    foreach ($root in $script:ToolkitRegistryRoots) {
        if (Test-Path -LiteralPath $root) {
            $registryRoots += $root
        }
    }
    $processSnapshot = @()
    try {
        $processes = @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop)
    }
    catch {
        $processes = @()
    }
    foreach ($process in $processes) {
        $executable = Get-ToolkitProcessExecutable -ProcessRecord $process
        if (Test-ToolkitProcessName -Path $executable) {
            $processSnapshot += [pscustomobject]@{
                ExecutablePath = [string]$executable
                CommandLine = [string](Get-ToolkitFirstProperty -InputObject $process -PropertyNames @('CommandLine'))
            }
        }
    }
    return @{
        RegistryRoots = $registryRoots
        ProcessSnapshot = $processSnapshot
        FallbackRoots = @()
    }
}

function Get-ToolkitActionRefusal {
    param([string]$Action)

    if ($script:ToolkitActions -cnotcontains $Action) {
        return Get-ToolkitResult -Status 'CriticalError' -Message "The requested action is not a toolkit action: $Action" -Data (@{ Code = 'ACTION_UNKNOWN'; Requested = Protect-ToolkitText $Action })
    }
    if ($script:ToolkitDispatchedActions -cnotcontains $Action) {
        return Get-ToolkitResult -Status 'CriticalError' -Message "The requested action has no implementation: $Action" -Data (@{ Code = 'ACTION_UNKNOWN'; Requested = Protect-ToolkitText $Action })
    }
    return $null
}

function Get-ToolkitStatePath {
    param(
        [string]$Requested,
        [switch]$Create
    )

    $path = $Requested
    if ([string]::IsNullOrWhiteSpace($path)) {
        $path = Get-ToolkitStateRoot
    }
    $fullPath = ConvertTo-ToolkitFullPath -Path $path
    if ($null -eq $fullPath) {
        return $null
    }
    if ($Create) {
        [void][IO.Directory]::CreateDirectory($fullPath)
    }
    return $fullPath
}

function Get-ToolkitMenuChoice {
    param(
        [string]$Label,
        [int]$Count,
        [scriptblock]$Prompt
    )

    if ($null -eq $Prompt) {
        return $null
    }
    $answer = ''
    try {
        $answer = [string](& $Prompt ($Label + ' (1-' + $Count + '): '))
    }
    catch {
        return $null
    }
    $choice = 0
    if (-not [int]::TryParse($answer.Trim(), [ref]$choice) -or $choice -lt 1 -or $choice -gt $Count) {
        return $null
    }
    return $choice
}

function Resolve-ToolkitInstall {
    param(
        [string]$InstallRoot = '',
        [scriptblock]$Prompt = $null
    )

    $sources = Get-ToolkitDiscoverySources
    $discovered = @(Find-MuMuInstallations -Edition 'All' -RegistryRoots @($sources.RegistryRoots) -ProcessSnapshot @($sources.ProcessSnapshot) -FallbackRoots @($sources.FallbackRoots))
    if ($discovered.Count -gt 0 -and $null -ne $discovered[0].PSObject.Properties['Status']) {
        return $discovered[0]
    }
    $installs = @($discovered)
    if ($installs.Count -eq 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'No MuMu installation was discovered.' -Data (@{ Code = 'INSTALL_NOT_DISCOVERED' })
    }

    if (-not [string]::IsNullOrWhiteSpace($InstallRoot)) {
        $requested = ConvertTo-ToolkitFullPath -Path $InstallRoot
        if ($null -eq $requested) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'The requested installation path is invalid.' -Data (@{ Code = 'INSTALL_INVALID' })
        }
        $matches = @($installs | Where-Object {
                $candidate = ConvertTo-ToolkitFullPath -Path ([string]$_.InstallRoot)
                $null -ne $candidate -and $candidate.Equals($requested, [StringComparison]::OrdinalIgnoreCase)
            })
        if ($matches.Count -eq 0) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'The requested installation was not discovered on this system.' -Data (@{ Code = 'INSTALL_NOT_DISCOVERED' })
        }
        return Get-ToolkitResult -Status 'Success' -Message 'The requested installation was selected.' -Data $matches[0]
    }

    if ($installs.Count -eq 1) {
        return Get-ToolkitResult -Status 'Success' -Message 'The only discovered installation was selected.' -Data $installs[0]
    }

    $choice = Get-ToolkitMenuChoice -Label 'Select the MuMu installation' -Count $installs.Count -Prompt $Prompt
    if ($null -eq $choice) {
        return Get-ToolkitResult -Status 'CriticalError' -Message "$($installs.Count) MuMu installations were discovered, so an explicit selection is required. Pass -InstallRoot with the exact installation path to select one without a prompt." -Data (@{ Code = 'INSTALL_SELECTION_REQUIRED' })
    }
    return Get-ToolkitResult -Status 'Success' -Message 'An installation was selected.' -Data $installs[$choice - 1]
}

function Resolve-ToolkitInstance {
    param(
        [object]$Install,
        [int]$InstanceIndex = -1,
        [scriptblock]$Prompt = $null
    )

    $managerPath = [string](Get-ToolkitFirstProperty -InputObject $Install -PropertyNames @('ManagerPath'))
    $instances = @(Get-MuMuInstances -Install $Install -ManagerPath $managerPath)
    if ($instances.Count -eq 1 -and $null -ne $instances[0].PSObject.Properties['Status']) {
        return $instances[0]
    }
    $eligible = @($instances | Where-Object { $null -ne $_.PSObject.Properties['Eligible'] -and $_.Eligible -eq $true })
    if ($eligible.Count -eq 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'No eligible MuMu instance was found for the selected installation.' -Data (@{ Code = 'INSTANCE_NOT_AVAILABLE' })
    }

    $selection = $null
    if ($InstanceIndex -ge 0) {
        $selection = [pscustomobject]@{ Index = $InstanceIndex }
    }
    elseif ($eligible.Count -gt 1) {
        $choice = Get-ToolkitMenuChoice -Label 'Select the MuMu instance' -Count $eligible.Count -Prompt $Prompt
        if ($null -eq $choice) {
            return Get-ToolkitResult -Status 'CriticalError' -Message "$($eligible.Count) eligible MuMu instances were found, so an explicit selection is required. Pass -InstanceIndex to select one without a prompt." -Data (@{ Code = 'INSTANCE_SELECTION_REQUIRED' })
        }
        $selection = [pscustomobject]@{ Index = [int](Get-ToolkitFirstProperty -InputObject $eligible[$choice - 1] -PropertyNames @('Index')) }
    }

    $resolved = Resolve-SelectedInstance -Instances $instances -Selection $selection
    if ($null -ne $resolved.PSObject.Properties['Status']) {
        return $resolved
    }
    $index = [int]$resolved.Index
    $selected = @($instances | Where-Object { [int]$_.Index -eq $index })[0]
    return Get-ToolkitResult -Status 'Success' -Message "The MuMu instance at index $index was selected out of $($instances.Count) instance(s)." -Data ([pscustomobject]@{
            Instance = $selected
            InstanceCount = $instances.Count
        })
}

function New-ToolkitActionJournal {
    param(
        [string]$StateRoot,
        [string]$Operation,
        [object]$Instance
    )

    return New-OperationJournal -Root ([IO.Path]::Combine($StateRoot, 'journals')) -Operation $Operation -Instance $Instance
}

function Close-ToolkitActionJournal {
    param(
        [object]$Journal,
        [object]$Result
    )

    if ($null -eq $Journal -or [string]$Journal.State -ne 'Running') {
        return $Result
    }
    if ([string]$Result.Status -in @('Success', 'AlreadyApplied', 'Warning')) {
        Complete-OperationJournal -Journal $Journal -Result $Result
    }
    else {
        Fail-OperationJournal -Journal $Journal -Result $Result
    }
    return $Result
}

function New-ToolkitCampaignRoot {
    param(
        [string]$StateRoot,
        [object]$Install
    )

    $scope = Get-ToolkitCampaignScopeKey -Install $Install
    $parent = [IO.Path]::Combine([IO.Path]::Combine($StateRoot, 'campaigns'), $scope)
    [void][IO.Directory]::CreateDirectory($parent)
    $name = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $root = [IO.Path]::Combine($parent, $name)
    [void][IO.Directory]::CreateDirectory($root)
    return $root
}

function Get-ToolkitCampaignBackupRoots {
    param(
        [string]$StateRoot,
        [object]$Install
    )

    return @(Get-ToolkitCampaignRestorePoints -StateRoot $StateRoot -Install $Install | ForEach-Object { [string]$_.BackupRoot })
}

function Invoke-ToolkitAdvertisements {
    param(
        [object]$Install,
        [string]$StateRoot,
        [switch]$Restore
    )

    $campaign = Get-MuMuCampaignPaths -Install $Install
    if ($campaign.Status -ne 'Success') {
        return $campaign
    }
    $boundary = [string](Get-ToolkitRecordValue -Record $Install -PropertyNames @('InstallRoot'))
    $boundary = if ([string]::IsNullOrWhiteSpace($boundary)) { $null } else { ConvertTo-ToolkitFullPath -Path $boundary }
    if ($null -eq $boundary) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The selected installation has no campaign root, so the advertisement restore boundary cannot be resolved and no advertisement file is changed.' -Data (@{ Code = 'CAMPAIGN_BOUNDARY_REQUIRED' })
    }

    $existing = @(Get-ToolkitCampaignBackupRoots -StateRoot $StateRoot -Install $Install)
    if ($existing.Count -gt 0) {
        $journal = New-ToolkitActionJournal -StateRoot $StateRoot -Operation 'RestoreAds' -Instance $Install
        $restored = Restore-MuMuAds -BackupRoot $existing[0] -AllowedRoot $boundary -Journal $journal
        $restored = Close-ToolkitActionJournal -Journal $journal -Result $restored
        if ($Restore -or $restored.Status -ne 'Success') {
            return $restored
        }
    }
    elseif ($Restore) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The toolkit holds no advertisement restore point for the selected installation, so no advertisement file is changed.' -Data (@{ Code = 'CAMPAIGN_RESTORE_POINT_MISSING' })
    }

    $backupRoot = New-ToolkitCampaignRoot -StateRoot $StateRoot -Install $Install
    $journal = New-ToolkitActionJournal -StateRoot $StateRoot -Operation 'RemoveAds' -Instance $Install
    $suppressed = Suppress-MuMuAds -Paths @($campaign.Data) -BackupRoot $backupRoot -Journal $journal
    return (Close-ToolkitActionJournal -Journal $journal -Result $suppressed)
}

function Invoke-ToolkitTarget {
    param(
        [object]$Install,
        [string]$StateRoot,
        [int]$InstanceIndex = -1,
        [string]$Mode = '',
        [object]$StartIndex = $null,
        [switch]$Confirmed,
        [scriptblock]$Prompt = $null,
        [scriptblock]$Runner = $null
    )

    $targetMode = ''
    if (-not [string]::IsNullOrWhiteSpace($Mode)) {
        $targetMode = $Mode.Trim()
    }
    elseif ($null -ne $Prompt) {
        $targetMode = ([string](& $Prompt 'Target mode: Identify, Create, or Clone')).Trim()
    }
    if ([string]::IsNullOrWhiteSpace($targetMode)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'A noninteractive target run requires an explicit mode. Pass -Mode Identify, -Mode Create, or -Mode Clone. No instance was created or changed.' -Data (@{ Code = 'TARGET_MODE_REQUIRED' })
    }

    $targetStartIndex = $StartIndex
    if ($targetMode -ceq 'Create' -and $null -eq $targetStartIndex) {
        if ($null -eq $Prompt) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'A noninteractive create target run requires an explicit -StartIndex. No instance was created.' -Data (@{ Code = 'TARGET_START_INDEX_REQUIRED' })
        }
        $targetStartIndex = ([string](& $Prompt 'Free instance index for the new instance')).Trim()
    }

    $targetConfirmed = $Confirmed
    if (-not $targetConfirmed -and $null -ne $Prompt -and $targetMode -cne 'Identify') {
        $targetConfirmed = ([string](& $Prompt "Type CONFIRM to run the target mode $targetMode") -ceq 'CONFIRM')
    }

    $journal = New-ToolkitActionJournal -StateRoot $StateRoot -Operation 'Target' -Instance $Install
    $result = Select-ToolkitTarget -Install $Install -Journal $journal -Mode $targetMode -InstanceIndex $InstanceIndex -StartIndex $targetStartIndex -Confirmed:$targetConfirmed -Prompt $Prompt -Runner $Runner
    return (Close-ToolkitActionJournal -Journal $journal -Result $result)
}

function Invoke-ToolkitAction {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action,
        [string]$InstallRoot = '',
        [int]$InstanceIndex = -1,
        [string]$StateRoot = '',
        [string[]]$Packages = @(),
        [string]$Mode = '',
        [object]$StartIndex = $null,
        [switch]$Confirmed,
        [scriptblock]$Prompt = $null,
        [scriptblock]$Runner = $null
    )

    $refusal = Get-ToolkitActionRefusal -Action $Action
    if ($null -ne $refusal) {
        return $refusal
    }

    $statePath = Get-ToolkitStatePath -Requested $StateRoot -Create
    if ($null -eq $statePath) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The toolkit state directory could not be resolved, so no action was started.' -Data (@{ Code = 'STATE_ROOT_UNAVAILABLE' })
    }

    $install = Resolve-ToolkitInstall -InstallRoot $InstallRoot -Prompt $Prompt
    if ($install.Status -ne 'Success') {
        return $install
    }

    if ($Action -ceq 'RemoveAds' -or $Action -ceq 'Restore') {
        return (Invoke-ToolkitAdvertisements -Install $install.Data -StateRoot $statePath -Restore:($Action -ceq 'Restore'))
    }

    if ($Action -ceq 'Target') {
        return (Invoke-ToolkitTarget -Install $install.Data -StateRoot $statePath -InstanceIndex $InstanceIndex -Mode $Mode -StartIndex $StartIndex -Confirmed:$Confirmed -Prompt $Prompt -Runner $Runner)
    }

    if (-not [string]::IsNullOrWhiteSpace($Mode) -or -not [string]::IsNullOrWhiteSpace($StartIndex)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message "-Mode and -StartIndex belong to the Target action, so the $Action action was not started." -Data (@{ Code = 'TARGET_PARAMETER_MISUSE' })
    }

    $instance = Resolve-ToolkitInstance -Install $install.Data -InstanceIndex $InstanceIndex -Prompt $Prompt
    if ($instance.Status -ne 'Success') {
        return $instance
    }
    $selected = $instance.Data.Instance
    $selectedIndex = [int]$selected.Index
    $summary = @{
        Edition        = [string]$install.Data.Edition
        InstallRoot    = [string]$install.Data.InstallRoot
        ManagerPath    = [string]$install.Data.ManagerPath
        InstanceIndex  = $selectedIndex
        InstanceName   = [string]$selected.Name
        AndroidVersion = [string]$selected.AndroidVersion
        Running        = $selected.Running
        RootSetting    = $selected.RootSetting
        InstanceCount  = [int]$instance.Data.InstanceCount
    }

    if ($Action -ceq 'Detect') {
        return Get-ToolkitResult -Status 'Success' -Message "Discovered $($summary.Edition) installation $($summary.InstallRoot) with $($summary.InstanceCount) instance(s)." -Data $summary
    }

    if ($Action -ceq 'Verify') {
        $report = Get-ToolkitReport -Install $install.Data -Instance $selected -Journal $null -StateRoot $statePath -Runner $Runner
        $status = if (@($report.Failures).Count -eq 0) { 'Success' } else { 'Warning' }
        return Get-ToolkitResult -Status $status -Message "The read-only report for the instance at index $selectedIndex is collected. Root state: $($report.Guest.Root). $($report.Install.Edition) installation $($report.Install.InstallRoot)." -Data ([pscustomobject]@{ Report = $report })
    }

    if ($Action -ceq 'Root12') {
        try {
            $manifest = Get-ToolkitManifest -Path (Join-Path $PSScriptRoot 'Manifest.json')
        }
        catch {
            return Get-ToolkitResult -Status 'CriticalError' -Message ('The dependency manifest could not be loaded, so no instance was changed. ' + [string]$_.Exception.Message) -Data (@{ Code = 'MANIFEST_INVALID' })
        }
        $journal = New-ToolkitActionJournal -StateRoot $statePath -Operation 'Root12' -Instance $selected
        $result = Install-Android12Root -Instance $selected -Manifest $manifest -Journal $journal -Interactive:($null -ne $Prompt) -Prompt $Prompt
        return (Close-ToolkitActionJournal -Journal $journal -Result $result)
    }

    if ($Action -ceq 'Root15') {
        if (-not $Confirmed) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'The Android 15 built-in root action requires an explicit confirmation. Rerun it with -Confirmed after the target instance has been checked. No instance was changed.' -Data (@{ Code = 'USER_CONFIRMATION_REQUIRED' })
        }
        $journal = New-ToolkitActionJournal -StateRoot $statePath -Operation 'Root15' -Instance $selected
        $result = Enable-Android15Root -Instance $selected -Journal $journal -Confirmed
        return (Close-ToolkitActionJournal -Journal $journal -Result $result)
    }

    if ($Action -ceq 'Conceal') {
        if (@($Packages).Count -eq 0) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'No application package was selected, so the concealment template was not applied. Pass -Packages with the exact package names to change.' -Data (@{ Code = 'PACKAGES_REQUIRED' })
        }
        $clone = Get-ToolkitVerifiedClone -StateRoot $statePath -Install $install.Data -Index $selectedIndex
        if ($clone.Status -ne 'Success') {
            return $clone
        }
        $journal = New-ToolkitActionJournal -StateRoot $statePath -Operation 'Conceal' -Instance $selected
        $result = Set-AppConcealment -Instance $selected -VerifiedClone $clone.Data -Packages $Packages -Journal $journal
        return (Close-ToolkitActionJournal -Journal $journal -Result $result)
    }

    return Get-ToolkitResult -Status 'CriticalError' -Message "The requested action has no implementation: $Action" -Data (@{ Code = 'ACTION_UNKNOWN'; Requested = Protect-ToolkitText $Action })
}

function Format-ToolkitResult {
    param([object]$Result)

    $lines = @('[' + [string]$Result.Status + '] ' + [string]$Result.Message)
    $data = $Result.Data
    if ($null -ne $data -and $data -is [Collections.IDictionary]) {
        foreach ($key in @($data.Keys | Sort-Object)) {
            if ([string]$key -ceq 'Log') {
                continue
            }
            $value = $data[$key]
            if ($value -is [string] -or $value -is [bool] -or $value -is [int] -or $value -is [long]) {
                $lines += ('  ' + [string]$key + ' = ' + [string]$value)
            }
        }
        if ($data.Contains('Log') -and -not [string]::IsNullOrWhiteSpace([string]$data['Log'])) {
            $lines += ('  Log: ' + [string]$data['Log'])
        }
    }
    if ([string]$Result.Status -in @('RecoverableError', 'CriticalError')) {
        $lines += ('  ' + $script:ToolkitRecoveryGuidance)
    }
    return $lines
}

function Invoke-MenuAction {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action,
        [string]$InstallRoot = '',
        [int]$InstanceIndex = -1,
        [string]$StateRoot = '',
        [string[]]$Packages = @(),
        [string]$Mode = '',
        [object]$StartIndex = $null,
        [switch]$Confirmed,
        [scriptblock]$Prompt = $null,
        [scriptblock]$Runner = $null,
        [string]$LogPath = ''
    )

    $result = $null
    $refusal = Get-ToolkitActionRefusal -Action $Action
    if ($null -ne $refusal) {
        $result = $refusal
    }
    else {
        try {
            if ($null -ne $Runner) {
                $result = & $Runner $Action
            }
            else {
                $result = Invoke-ToolkitAction -Action $Action -InstallRoot $InstallRoot -InstanceIndex $InstanceIndex -StateRoot $StateRoot -Packages $Packages -Mode $Mode -StartIndex $StartIndex -Confirmed:$Confirmed -Prompt $Prompt
            }
        }
        catch {
            $message = Protect-ToolkitText ([string]$_.Exception.Message)
            if ([string]::IsNullOrWhiteSpace($message)) {
                $message = 'The action failed without a reported reason.'
            }
            $result = Get-ToolkitResult -Status 'CriticalError' -Message ("The $Action action failed. " + $message) -Data (@{ Code = 'ACTION_THREW' })
        }
    }

    if ($null -eq $result -or $result -is [Array] -or $result -isnot [pscustomobject]) {
        $result = Get-ToolkitResult -Status 'CriticalError' -Message "The action $Action returned no structured result, so its outcome is unknown and no later step may assume success." -Data (@{ Code = 'ACTION_RESULT_INVALID' })
    }
    elseif (@($result.PSObject.Properties).Count -ne 3 -or
        $null -eq $result.PSObject.Properties['Status'] -or
        $null -eq $result.PSObject.Properties['Message'] -or
        $null -eq $result.PSObject.Properties['Data']) {
        $result = Get-ToolkitResult -Status 'CriticalError' -Message "The action $Action returned an unsupported result shape, so its outcome is unknown and no later step may assume success." -Data (@{ Code = 'ACTION_RESULT_INVALID' })
    }
    elseif (@('Success', 'AlreadyApplied', 'Warning', 'RecoverableError', 'CriticalError') -cnotcontains [string]$result.Status) {
        $result = Get-ToolkitResult -Status 'CriticalError' -Message "The action $Action returned a noncanonical status, so its outcome is unknown and no later step may assume success." -Data (@{ Code = 'ACTION_RESULT_INVALID' })
    }

    if ([string]$result.Status -in @('Success', 'AlreadyApplied')) {
        return $result
    }

    $data = @{}
    if ($result.Data -is [Collections.IDictionary]) {
        foreach ($key in @($result.Data.Keys)) {
            $data[[string]$key] = $result.Data[$key]
        }
    }
    elseif ($null -ne $result.Data) {
        foreach ($property in @($result.Data.PSObject.Properties)) {
            $data[[string]$property.Name] = $property.Value
        }
    }
    $level = if ([string]$result.Status -ceq 'CriticalError') { 'Error' } else { 'Warning' }
    $logPath = Write-ToolkitLogEntry -Level $level -Message ("Action " + $Action + ' returned ' + [string]$result.Status + ': ' + [string]$result.Message) -LogPath $LogPath
    $data['Log'] = $logPath
    return Get-ToolkitResult -Status ([string]$result.Status) -Message ([string]$result.Message) -Data $data
}

function Invoke-MenuLoop {
    param(
        [scriptblock]$Reader,
        [scriptblock]$Writer,
        [scriptblock]$Runner = $null,
        [hashtable]$ActionArguments = @{},
        [string]$StateRoot = '',
        [string]$LogPath = ''
    )

    $write = $Writer
    if ($null -eq $write) {
        $write = { param($Line) Write-Host $Line }
    }
    $exitCode = 0
    while ($true) {
        $read = $null
        try {
            $read = & $Reader
        }
        catch {
            $message = Protect-ToolkitText ([string]$_.Exception.Message)
            if ([string]::IsNullOrWhiteSpace($message)) {
                $message = 'The menu reader failed without a reported reason.'
            }
            $logEntry = Write-ToolkitLogEntry -Level 'Error' -Message ('The menu could not read a selection: ' + $message) -LogPath $LogPath
            $failure = Get-ToolkitResult -Status 'CriticalError' -Message ('The menu could not read a selection. ' + $message) -Data (@{ Code = 'MENU_READ_FAILED'; Log = $logEntry })
            foreach ($line in @(Format-ToolkitResult -Result $failure)) {
                & $write $line
            }
            return (Get-ToolkitExitCode $failure)
        }
        if ($null -eq $read) {
            return $exitCode
        }
        $answer = [string]$read
        $choice = $answer.Trim()
        if ([string]::IsNullOrWhiteSpace($choice)) {
            continue
        }
        if ($choice -ceq 'Q') {
            return $exitCode
        }
        $arguments = @{}
        foreach ($key in @($ActionArguments.Keys)) {
            $arguments[[string]$key] = $ActionArguments[$key]
        }
        $arguments['Action'] = $choice
        $arguments['Runner'] = $Runner
        $arguments['StateRoot'] = $StateRoot
        $arguments['LogPath'] = $LogPath
        $result = $null
        try {
            $result = Invoke-MenuAction @arguments
        }
        catch {
            $result = Get-ToolkitResult -Status 'CriticalError' -Message 'The action could not be completed.' -Data (@{ Code = 'ACTION_THREW' })
        }
        foreach ($line in @(Format-ToolkitResult -Result $result)) {
            & $write $line
        }
        $code = Get-ToolkitExitCode $result
        if ($code -ne 0) {
            $exitCode = $code
        }
    }
}

function Start-ToolkitController {
    param(
        [string]$Action = '',
        [string]$InstallRoot = '',
        [int]$InstanceIndex = -1,
        [string]$StateRoot = '',
        [string[]]$Packages = @(),
        [string]$Mode = '',
        [object]$StartIndex = $null,
        [switch]$Confirmed,
        [switch]$NonInteractive,
        [switch]$SkipToolbar,
        [scriptblock]$Reader = $null,
        [scriptblock]$Writer = $null,
        [scriptblock]$Prompt = $null,
        [scriptblock]$ActionRunner = $null
    )

    $statePath = $null
    try {
        $statePath = Get-ToolkitStatePath -Requested $StateRoot -Create
    }
    catch {
        $statePath = $null
    }
    if ($null -eq $statePath) {
        [Console]::Error.WriteLine('[CriticalError] The toolkit state directory could not be resolved, so no action was started.')
        return 1
    }
    $logPath = [IO.Path]::Combine($statePath, 'logs', 'mumu-root-hide-toolkit.log')
    $write = $Writer
    if ($null -eq $write) {
        $write = { param($Line) Write-Host $Line }
    }

    if ($NonInteractive) {
        if ([string]::IsNullOrWhiteSpace($Action)) {
            $result = Get-ToolkitResult -Status 'CriticalError' -Message 'A noninteractive run requires -Action. Use -Action Detect for a read-only run.' -Data (@{ Code = 'ACTION_REQUIRED' })
            foreach ($line in @(Format-ToolkitResult -Result $result)) {
                & $write $line
            }
            return (Get-ToolkitExitCode $result)
        }
        $result = Invoke-MenuAction -Action $Action -InstallRoot $InstallRoot -InstanceIndex $InstanceIndex -StateRoot $statePath -Packages $Packages -Mode $Mode -StartIndex $StartIndex -Confirmed:$Confirmed -LogPath $logPath
        foreach ($line in @(Format-ToolkitResult -Result $result)) {
            & $write $line
        }
        return (Get-ToolkitExitCode $result)
    }

    $read = $Reader
    if ($null -eq $read) {
        $read = { param() Read-Host 'Select an action' }
    }
    $ask = $Prompt
    if ($null -eq $ask) {
        $ask = { param($Question) [string](Read-Host $Question) }
    }
    $runner = $ActionRunner
    if ($null -eq $runner) {
        $runner = {
            param($Choice)

            $selectedPackages = @($Packages)
            if ($Choice -ceq 'Conceal' -and $selectedPackages.Count -eq 0) {
                $answer = [string](& $ask 'Comma-separated application package names for the Root template')
                $selectedPackages = @($answer -split ',' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            }
            $confirmed = $Confirmed
            if ($Choice -ceq 'Root15' -and -not $confirmed) {
                $confirmed = ([string](& $ask 'Type CONFIRM to enable the built-in Android 15 root') -ceq 'CONFIRM')
            }
            $targetMode = ''
            $targetStartIndex = $null
            if ($Choice -ceq 'Target') {
                $targetMode = $Mode
                $targetStartIndex = $StartIndex
            }
            return (Invoke-ToolkitAction -Action $Choice -InstallRoot $InstallRoot -InstanceIndex $InstanceIndex -StateRoot $statePath -Packages $selectedPackages -Mode $targetMode -StartIndex $targetStartIndex -Confirmed:$confirmed -Prompt $ask)
        }.GetNewClosure()
    }

    if (-not $SkipToolbar) {
        & $write 'MuMu Root Hide Toolkit'
        & $write 'Detect and Verify change nothing.'
        & $write 'Target identifies the instance to work on, or creates or clones one. Identify changes nothing; Create and Clone ask for CONFIRM first and are the only ways this toolkit adds an instance.'
        & $write 'Root12 and Root15 stop the selected instance when needed, create and verify a clone, and change only that clone. Conceal changes only the verified clone.'
        & $write 'RemoveAds and Restore change only the MuMu campaign files inside the selected installation, and every change keeps an exact backup.'
        foreach ($entry in @(Get-ToolkitActionCatalog)) {
            & $write ('  ' + ([string]$entry.Name).PadRight(10) + [string]$entry.Description)
        }
    }
    return (Invoke-MenuLoop -Reader $read -Writer $write -Runner $runner -StateRoot $statePath -LogPath $logPath)
}

if ($MyInvocation.InvocationName -ne '.') {
    exit (Start-ToolkitController -Action $Action -InstallRoot $InstallRoot -InstanceIndex $InstanceIndex -StateRoot $StateRoot -Packages $Packages -Mode $Mode -StartIndex $StartIndex -Confirmed:$Confirmed -NonInteractive:$NonInteractive -SkipToolbar:$SkipToolbar)
}
