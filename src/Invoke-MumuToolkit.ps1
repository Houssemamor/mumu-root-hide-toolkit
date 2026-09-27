[CmdletBinding()]
param(
    [string]$Action = '',
    [string]$InstallRoot = '',
    [int]$InstanceIndex = -1,
    [int]$SourceIndex = -1,
    [string]$StateRoot = '',
    [string[]]$Packages = @(),
    [string]$Mode = '',
    [object]$StartIndex = $null,
    [switch]$Confirmed,
    [switch]$NonInteractive,
    [switch]$SkipToolbar,
    [switch]$FetchDependencies,
    [switch]$ElevatedChild
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
$script:ToolkitInstanceChoiceLimit = 32
# The concealment dependencies are downloaded only on an explicit word, so the menu can reach the same
# acquisition the command line does without ever fetching silently. Anything but this word fetches
# nothing, and an elevated retry never fetches at all.
$script:ToolkitDependencyConsentWord = 'FETCH'

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
    $number = 1
    foreach ($name in $script:ToolkitActions) {
        $catalog += [pscustomobject]@{
            Number = $number
            Name = $name
            Description = [string]$script:ToolkitActionDescriptions[$name]
        }
        $number++
    }
    $catalog += [pscustomobject]@{
        Number = $number
        Name = 'Q'
        Description = [string]$script:ToolkitActionDescriptions['Q']
    }
    return $catalog
}

# The operator answers with the number the menu printed, so the number is resolved to the action name
# before anything is dispatched. An exact action name is still accepted so an existing habit or a
# scripted answer keeps working.
function Resolve-ToolkitMenuChoice {
    param([string]$Answer)

    $choice = $Answer.Trim()
    if ([string]::IsNullOrWhiteSpace($choice)) {
        return $null
    }
    $entries = @(Get-ToolkitActionCatalog)
    $number = 0
    if ([int]::TryParse($choice, [ref]$number)) {
        return ($entries | Where-Object { [int]$_.Number -eq $number } | Select-Object -First 1)
    }
    return ($entries | Where-Object { [string]$_.Name -ceq $choice } | Select-Object -First 1)
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

function Get-ToolkitTargetParameterRefusal {
    param(
        [string]$Action,
        [string]$Mode,
        [int]$SourceIndex = -1,
        [object]$StartIndex,
        [scriptblock]$Prompt
    )

    $requestedMode = ''
    if (-not [string]::IsNullOrWhiteSpace($Mode)) {
        $requestedMode = $Mode.Trim()
    }
    if ($Action -cne 'Target') {
        if ([string]::IsNullOrWhiteSpace($requestedMode) -and $null -eq $StartIndex -and $SourceIndex -lt 0) {
            return $null
        }
        return Get-ToolkitResult -Status 'CriticalError' -Message "-Mode, -StartIndex, and -SourceIndex belong to the Target action, so the $Action action was not started." -Data (@{ Code = 'TARGET_PARAMETER_MISUSE' })
    }
    if (-not [string]::IsNullOrWhiteSpace($requestedMode) -and $script:ToolkitTargetModes -cnotcontains $requestedMode) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The target mode must be Identify, Create, or Clone, so no instance was created or changed.' -Data (@{ Code = 'TARGET_MODE_INVALID' })
    }
    if ($requestedMode -ceq 'Create' -and $null -eq $Prompt -and $null -eq (ConvertTo-ToolkitInstanceIndex -Value $StartIndex)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'A noninteractive create target run requires an explicit -StartIndex that is a non-negative integer. No instance was created.' -Data (@{ Code = 'TARGET_START_INDEX_REQUIRED' })
    }
    return $null
}

function Invoke-ToolkitTarget {
    param(
        [object]$Install,
        [string]$StateRoot,
        [int]$InstanceIndex = -1,
        [int]$SourceIndex = -1,
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
    $modeRefusal = Get-ToolkitTargetParameterRefusal -Action 'Target' -Mode $targetMode -SourceIndex $SourceIndex -StartIndex $StartIndex -Prompt $Prompt
    if ($null -ne $modeRefusal) {
        return $modeRefusal
    }

    $targetStartIndex = $StartIndex
    if ($targetMode -ceq 'Create' -and $null -eq (ConvertTo-ToolkitInstanceIndex -Value $targetStartIndex)) {
        if ($null -eq $Prompt) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'A noninteractive create target run requires an explicit -StartIndex that is a non-negative integer. No instance was created.' -Data (@{ Code = 'TARGET_START_INDEX_REQUIRED' })
        }
        $targetStartIndex = ConvertTo-ToolkitInstanceIndex -Value ([string](& $Prompt 'Free instance index for the new instance'))
        if ($null -eq $targetStartIndex) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'The free instance index must be a non-negative integer, so no instance was created.' -Data (@{ Code = 'TARGET_START_INDEX_INVALID' })
        }
    }

    $targetSourceIndex = $SourceIndex
    if ($targetMode -ceq 'Clone') {
        $source = Resolve-ToolkitCloneSource -Install $Install -SourceIndex $SourceIndex -InstanceIndex $InstanceIndex -Prompt $Prompt -Runner $Runner
        if ($source.Status -ne 'Success') {
            return $source
        }
        $targetSourceIndex = [int]$source.Data.Index
    }

    $targetConfirmed = $Confirmed
    if (-not $targetConfirmed -and $null -ne $Prompt -and $targetMode -cne 'Identify') {
        $targetConfirmed = ([string](& $Prompt "Type CONFIRM to run the target mode $targetMode") -ceq 'CONFIRM')
    }

    $journal = New-ToolkitActionJournal -StateRoot $StateRoot -Operation 'Target' -Instance $Install
    $result = Select-ToolkitTarget -Install $Install -Journal $journal -Mode $targetMode -InstanceIndex $InstanceIndex -SourceIndex $targetSourceIndex -StartIndex $targetStartIndex -Confirmed:$targetConfirmed -Prompt $Prompt -Runner $Runner
    return (Close-ToolkitActionJournal -Journal $journal -Result $result)
}

# The mutating dispatch is where administrator rights become reachable. The action is attempted in
# process first, so a host that does not need rights is never pushed through a UAC prompt, and only a
# permission failure asks for them, exactly once. A declined or failed elevation fails closed: the
# in-process result is replaced by the elevation outcome and nothing is retried here.
function Invoke-ToolkitActionWithElevation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action,
        [string]$InstallRoot = '',
        [int]$InstanceIndex = -1,
        [int]$SourceIndex = -1,
        [string]$StateRoot = '',
        [string[]]$Packages = @(),
        [string]$Mode = '',
        [object]$StartIndex = $null,
        [switch]$Confirmed,
        [switch]$FetchDependencies,
        [switch]$ElevatedChild,
        [scriptblock]$Prompt = $null,
        [scriptblock]$Runner = $null,
        [scriptblock]$ElevationRunner = $null
    )

    $result = Invoke-ToolkitAction -Action $Action -InstallRoot $InstallRoot -InstanceIndex $InstanceIndex -SourceIndex $SourceIndex -StateRoot $StateRoot -Packages $Packages -Mode $Mode -StartIndex $StartIndex -Confirmed:$Confirmed -FetchDependencies:$FetchDependencies -ElevatedChild:$ElevatedChild -Prompt $Prompt -Runner $Runner
    # An elevated child is the one process that must never ask for rights again, and an unarmed seam
    # has no UAC prompt to raise, so both return the in-process outcome unchanged.
    if ($ElevatedChild -or $null -eq $ElevationRunner) {
        return $result
    }
    if (-not (Test-ToolkitPermissionFailure -Result $result)) {
        return $result
    }
    if ($script:ToolkitElevatableActions -cnotcontains $Action) {
        return $result
    }
    # A process that already holds rights gains nothing from a second prompt.
    if (Test-ToolkitAdministrator) {
        return $result
    }
    try {
        $childArguments = @(New-ToolkitElevatedChildArguments -Action $Action -InstallRoot $InstallRoot -InstanceIndex $InstanceIndex -SourceIndex $SourceIndex -StateRoot $StateRoot -Packages $Packages -Mode $Mode -StartIndex $StartIndex -Confirmed:$Confirmed)
    }
    catch {
        return Get-ToolkitResult -Status 'CriticalError' -Message ("The $Action action failed for a permission reason and cannot be relaunched with administrator rights. " + (Protect-ToolkitText ([string]$_.Exception.Message))) -Data (@{ Code = 'ELEVATION_REQUEST_INVALID'; Action = Protect-ToolkitText $Action })
    }
    $controllerPath = ConvertTo-ToolkitFullPath -Path (Join-Path $PSScriptRoot 'Invoke-MumuToolkit.ps1')
    $elevated = & $ElevationRunner $controllerPath $childArguments
    if ($null -eq $elevated -or $elevated -isnot [pscustomobject] -or $null -eq $elevated.PSObject.Properties['Status']) {
        return Get-ToolkitResult -Status 'CriticalError' -Message "The $Action action was relaunched with administrator rights and reported no outcome, so its result is unknown and nothing is retried here." -Data (@{ Code = 'ELEVATION_OUTCOME_INVALID'; Action = Protect-ToolkitText $Action })
    }
    return Get-ToolkitResult -Status ([string]$elevated.Status) -Message ("The $Action action failed without the rights it needs, so it was relaunched once with administrator rights. " + [string]$elevated.Message) -Data $elevated.Data
}

function Invoke-ToolkitAction {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action,
        [string]$InstallRoot = '',
        [int]$InstanceIndex = -1,
        [int]$SourceIndex = -1,
        [string]$StateRoot = '',
        [string[]]$Packages = @(),
        [string]$Mode = '',
        [object]$StartIndex = $null,
        [switch]$Confirmed,
        [switch]$FetchDependencies,
        [switch]$ElevatedChild,
        [scriptblock]$Prompt = $null,
        [scriptblock]$Runner = $null
    )

    $refusal = Get-ToolkitActionRefusal -Action $Action

    if ($null -ne $refusal) {
        return $refusal
    }

    $parameterRefusal = Get-ToolkitTargetParameterRefusal -Action $Action -Mode $Mode -SourceIndex $SourceIndex -StartIndex $StartIndex -Prompt $Prompt
    if ($null -ne $parameterRefusal) {
        return $parameterRefusal
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
        return (Invoke-ToolkitTarget -Install $install.Data -StateRoot $statePath -InstanceIndex $InstanceIndex -SourceIndex $SourceIndex -Mode $Mode -StartIndex $StartIndex -Confirmed:$Confirmed -Prompt $Prompt -Runner $Runner)
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
        # A concealment evidence that is not verified is a failure of the report, so its severity
        # reaches the action status instead of being printed beside a claimed Success.
        $concealmentStatus = [string](Get-ToolkitRecordValue -Record (Get-ToolkitRecordValue -Record $report -PropertyNames @('Concealment')) -PropertyNames @('Status'))
        $status = if ($concealmentStatus -ceq 'CriticalError') {
            'CriticalError'
        }
        elseif (@($report.Failures).Count -eq 0) {
            'Success'
        }
        else {
            'Warning'
        }
        # The concealment result is named in the headline so the summary line is never quieter than
        # the block it introduces.
        $concealmentCode = [string](Get-ToolkitRecordValue -Record (Get-ToolkitRecordValue -Record $report -PropertyNames @('Concealment')) -PropertyNames @('Code'))
        if ([string]::IsNullOrWhiteSpace($concealmentCode)) {
            $concealmentCode = 'CLONE_UNVERIFIED'
        }
        return Get-ToolkitResult -Status $status -Message "The read-only report for the instance at index $selectedIndex is collected. Root state: $($report.Guest.Root). Concealment: $concealmentCode. $($report.Install.Edition) installation $($report.Install.InstallRoot)." -Data ([pscustomobject]@{ Report = $report })
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
        try {
            $manifest = Get-ToolkitManifest -Path (Join-Path $PSScriptRoot 'Manifest.json')
        }
        catch {
            return Get-ToolkitResult -Status 'CriticalError' -Message ('The dependency manifest could not be loaded, so nothing was installed and no app scope changed. ' + [string]$_.Exception.Message) -Data (@{ Code = 'MANIFEST_INVALID' })
        }
        # The HMA scope this action writes is unreadable without the HMA package and the Vector module,
        # so both are installed or verified first. Acquisition and mutation stay separate phases: the
        # pinned assets are fetched and verified here, and the install itself is cached-only, so no
        # download can happen after rights are raised.
        if ($FetchDependencies -and -not $ElevatedChild) {
            foreach ($assetId in @($script:ConcealmentDependencyAssetIds)) {
                $fetched = Save-ToolkitManifestAsset -Manifest $manifest -Id $assetId
                if ($fetched.Status -ne 'Success') {
                    return Get-ToolkitResult -Status 'CriticalError' -Message ("The pinned concealment dependency was not acquired, so nothing was installed and no app scope changed. " + [string]$fetched.Message) -Data $fetched.Data
                }
            }
        }
        $dependencyJournal = New-ToolkitActionJournal -StateRoot $statePath -Operation 'ConcealDependencies' -Instance $selected
        $dependencies = Install-ConcealmentDependencies -Instance $selected -VerifiedClone $clone.Data -Manifest $manifest -Journal $dependencyJournal
        if ($dependencies.Status -notin @('Success', 'AlreadyApplied')) {
            return $dependencies
        }
        $journal = New-ToolkitActionJournal -StateRoot $statePath -Operation 'Conceal' -Instance $selected
        $result = Set-AppConcealment -Instance $selected -VerifiedClone $clone.Data -Packages $Packages -Journal $journal
        return (Close-ToolkitActionJournal -Journal $journal -Result $result)
    }

    return Get-ToolkitResult -Status 'CriticalError' -Message "The requested action has no implementation: $Action" -Data (@{ Code = 'ACTION_UNKNOWN'; Requested = Protect-ToolkitText $Action })
}

function Format-ToolkitInstanceChoices {
    param([object]$Choices)

    $lines = @()
    $records = @($Choices)
    $listed = 0
    foreach ($instance in $records) {
        if ($listed -ge $script:ToolkitInstanceChoiceLimit) {
            break
        }
        if ($null -eq $instance -or $null -eq $instance.PSObject) {
            continue
        }
        $name = Protect-ToolkitText ([string](Get-ToolkitRecordValue -Record $instance -PropertyNames @('Name')))
        $lines += ('  Instance ' + [string](Get-ToolkitRecordValue -Record $instance -PropertyNames @('Index')) +
            ' | ' + $name +
            ' | Android ' + [string](Get-ToolkitRecordValue -Record $instance -PropertyNames @('AndroidVersion')) +
            ' | Running ' + [string](Get-ToolkitRecordValue -Record $instance -PropertyNames @('Running')) +
            ' | Eligible ' + [string](Get-ToolkitRecordValue -Record $instance -PropertyNames @('Eligible')))
        $listed++
    }
    if ($records.Count -gt $listed) {
        $lines += ('  ' + ($records.Count - $listed) + ' more instance(s) were not listed. Run the read-only report for the full list.')
    }
    return $lines
}

# PowerShell -File hands a comma separated list over as one string, so the documented -Packages a,b
# form is split once here. The elevated child repeats the same argument, so it normalizes it the
# same way, and the selection that was verified in the parent is the selection the child applies.
function ConvertTo-ToolkitPackageSelection {
    param([string[]]$Packages = @())

    $selected = @()
    foreach ($entry in @($Packages)) {
        if ($entry -isnot [string] -or [string]::IsNullOrWhiteSpace($entry)) {
            continue
        }
        foreach ($name in ($entry -split ',')) {
            $trimmed = $name.Trim()
            if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
                $selected += $trimmed
            }
        }
    }
    # The unary comma keeps an empty selection an empty array instead of nothing at all.
    return , $selected
}

# A report field that carries no value is named with one of these two markers, so a rendered report is a fixed record instead of a varying one.
$script:ToolkitReportAbsentText = 'not-detected'
$script:ToolkitReportEmptyText = 'none'

function ConvertTo-ToolkitReportText {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) {
        return $script:ToolkitReportAbsentText
    }
    # A negative count or index is the report's own unread marker, not a measured value.
    if ($Value -is [int] -and [int]$Value -lt 0) {
        return $script:ToolkitReportAbsentText
    }
    if ($Value -isnot [string] -and $Value -isnot [ValueType]) {
        # A collection is printed as its count and its quoted elements, so two package names can never
        # be read as one odd package name with a separator in it.
        $items = @($Value)
        if ($items.Count -eq 0) {
            return $script:ToolkitReportEmptyText
        }
        $quoted = @($items | ForEach-Object { '"' + (Protect-ToolkitText ([string]$_)) + '"' })
        return ([string]$items.Count + ': ' + ($quoted -join ', '))
    }
    $text = [string]$Value
    if ($text.Length -eq 0) {
        return $script:ToolkitReportEmptyText
    }
    # The report carries manager and guest text, so it is redacted on the way out like every other toolkit output.
    return (Protect-ToolkitText $text)
}

function Test-ToolkitReportShape {
    param([AllowNull()][object]$Report)

    if ($null -eq $Report -or $Report -is [string] -or $Report -is [ValueType] -or $Report -is [Array]) {
        return $false
    }
    # A report is recognized by its own identifying fields, so a result that carries no report is left alone.
    foreach ($fieldName in @('Install', 'Guest', 'Failures', 'Instances', 'Ads', 'Backups', 'Virtualization', 'JournalState', 'ManagerVersion', 'Mutated')) {
        if ($null -ne (Get-ToolkitRecordValue -Record $Report -PropertyNames @($fieldName))) {
            return $true
        }
    }
    return $false
}

function Format-ToolkitReport {
    param([AllowNull()][object]$Report)

    $lines = @()
    $install = Get-ToolkitRecordValue -Record $Report -PropertyNames @('Install')
    foreach ($fieldName in @('Edition', 'InstallRoot', 'VmsPath', 'ManagerPath', 'Source')) {
        $lines += ('  Install.' + $fieldName + ' = ' + (ConvertTo-ToolkitReportText (Get-ToolkitRecordValue -Record $install -PropertyNames @($fieldName))))
    }
    $lines += ('  ManagerVersion = ' + (ConvertTo-ToolkitReportText (Get-ToolkitRecordValue -Record $Report -PropertyNames @('ManagerVersion'))))

    # The instance rows carry the root setting the manager reports, because that is the only per-instance root evidence the manager holds.
    # An absent list and an empty one both mean there is nothing to list, because the field reader returns no value for either.
    $instanceValue = Get-ToolkitRecordValue -Record $Report -PropertyNames @('Instances')
    $instances = @()
    if ($null -ne $instanceValue) {
        $instances = @($instanceValue)
    }
    if ($instances.Count -eq 0) {
        $lines += ('  Instances: ' + $script:ToolkitReportEmptyText)
    }
    else {
        $lines += '  Instances:'
        foreach ($instance in $instances) {
            $lines += ('    Instance ' + (ConvertTo-ToolkitReportText (Get-ToolkitRecordValue -Record $instance -PropertyNames @('Index'))) +
                ' | ' + (ConvertTo-ToolkitReportText (Get-ToolkitRecordValue -Record $instance -PropertyNames @('Name'))) +
                ' | Android ' + (ConvertTo-ToolkitReportText (Get-ToolkitRecordValue -Record $instance -PropertyNames @('AndroidVersion'))) +
                ' | Running ' + (ConvertTo-ToolkitReportText (Get-ToolkitRecordValue -Record $instance -PropertyNames @('Running'))) +
                ' | RootSetting ' + (ConvertTo-ToolkitReportText (Get-ToolkitRecordValue -Record $instance -PropertyNames @('RootSetting'))))
        }
    }

    $lines += ('  Virtualization = ' + (ConvertTo-ToolkitReportText (Get-ToolkitRecordValue -Record $Report -PropertyNames @('Virtualization'))))

    $guest = Get-ToolkitRecordValue -Record $Report -PropertyNames @('Guest')
    foreach ($fieldName in @('Root', 'Code', 'RootPermission', 'Kitsune', 'KernelSU', 'DaemonCount', 'HmaInstalled', 'VectorModuleInstalled')) {
        $lines += ('  Guest.' + $fieldName + ' = ' + (ConvertTo-ToolkitReportText (Get-ToolkitRecordValue -Record $guest -PropertyNames @($fieldName))))
    }

    $advertisements = Get-ToolkitRecordValue -Record $Report -PropertyNames @('Ads')
    $lines += ('  Ads.RestorePoint = ' + (ConvertTo-ToolkitReportText (Get-ToolkitRecordValue -Record $advertisements -PropertyNames @('RestorePoint'))))
    $backups = Get-ToolkitRecordValue -Record $Report -PropertyNames @('Backups')
    $lines += ('  Backups.CloneIndex = ' + (ConvertTo-ToolkitReportText (Get-ToolkitRecordValue -Record $backups -PropertyNames @('CloneIndex'))))
    $lines += ('  Backups.CloneName = ' + (ConvertTo-ToolkitReportText (Get-ToolkitRecordValue -Record $backups -PropertyNames @('CloneName'))))
    # Concealment is a per-app claim, so the report carries the packages it observed in scope rather
    # than a single yes or no.
    $concealment = Get-ToolkitRecordValue -Record $Report -PropertyNames @('Concealment')
    foreach ($fieldName in @('Target', 'Status', 'Code', 'Packages', 'InScope', 'OutOfScope', 'TemplateFound', 'IsWhitelist', 'HmaConfigVersion', 'KernelSUInstalled', 'AllowlistPresent')) {
        $lines += ('  Concealment.' + $fieldName + ' = ' + (ConvertTo-ToolkitReportText (Get-ToolkitRecordValue -Record $concealment -PropertyNames @($fieldName))))
    }
    foreach ($fieldName in @('JournalState', 'JournalOperation', 'JournalId')) {
        $lines += ('  ' + $fieldName + ' = ' + (ConvertTo-ToolkitReportText (Get-ToolkitRecordValue -Record $Report -PropertyNames @($fieldName))))
    }

    $failureValue = Get-ToolkitRecordValue -Record $Report -PropertyNames @('Failures')
    $failures = @()
    if ($null -ne $failureValue) {
        $failures = @($failureValue)
    }
    if ($failures.Count -eq 0) {
        $lines += ('  Failures: ' + $script:ToolkitReportEmptyText)
    }
    else {
        $lines += '  Failures:'
        for ($failureIndex = 0; $failureIndex -lt $failures.Count; $failureIndex++) {
            $lines += ('    Failure ' + ($failureIndex + 1) + ' = ' + (ConvertTo-ToolkitReportText $failures[$failureIndex]))
        }
    }
    return $lines
}

function Format-ToolkitResult {
    param([object]$Result)

    $lines = @('[' + [string]$Result.Status + '] ' + [string]$Result.Message)
    $data = $Result.Data
    if ($null -ne $data -and $data -is [Collections.IDictionary]) {
        foreach ($key in @($data.Keys | Sort-Object)) {
            if ([string]$key -ceq 'Log' -or [string]$key -ceq 'Instances') {
                continue
            }
            $value = $data[$key]
            if ($value -is [string] -or $value -is [bool] -or $value -is [int] -or $value -is [long]) {
                $lines += ('  ' + [string]$key + ' = ' + [string]$value)
            }
        }
        if ($data.Contains('Instances')) {
            $lines += @(Format-ToolkitInstanceChoices -Choices $data['Instances'])
        }
        if ($data.Contains('Log') -and -not [string]::IsNullOrWhiteSpace([string]$data['Log'])) {
            $lines += ('  Log: ' + [string]$data['Log'])
        }
    }
    # The read-only report is nested inside the data and is not a scalar, so the loop above cannot print it.
    $report = Get-ToolkitRecordValue -Record $data -PropertyNames @('Report')
    if (Test-ToolkitReportShape -Report $report) {
        $lines += @(Format-ToolkitReport -Report $report)
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
        [int]$SourceIndex = -1,
        [string]$StateRoot = '',
        [string[]]$Packages = @(),
        [string]$Mode = '',
        [object]$StartIndex = $null,
        [switch]$Confirmed,
        [switch]$FetchDependencies,
        [switch]$ElevatedChild,
        [scriptblock]$Prompt = $null,
        [scriptblock]$Runner = $null,
        [scriptblock]$ElevationRunner = $null,
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
                $result = Invoke-ToolkitActionWithElevation -Action $Action -InstallRoot $InstallRoot -InstanceIndex $InstanceIndex -SourceIndex $SourceIndex -StateRoot $StateRoot -Packages $Packages -Mode $Mode -StartIndex $StartIndex -Confirmed:$Confirmed -FetchDependencies:$FetchDependencies -ElevatedChild:$ElevatedChild -Prompt $Prompt -ElevationRunner $ElevationRunner
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
        $entry = Resolve-ToolkitMenuChoice -Answer $answer
        if ($null -eq $entry) {
            if (-not [string]::IsNullOrWhiteSpace($answer.Trim())) {
                # An answer that matches no printed number is reported against the printed range instead
                # of being dispatched as an action name, so a mistyped digit never runs something.
                & $write ('Select a number from 1-' + @(Get-ToolkitActionCatalog).Count + ', or press Enter to see the menu again.')
            }
            continue
        }
        if ([string]$entry.Name -ceq 'Q') {
            return $exitCode
        }
        $arguments = @{}
        foreach ($key in @($ActionArguments.Keys)) {
            $arguments[[string]$key] = $ActionArguments[$key]
        }
        $arguments['Action'] = [string]$entry.Name
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

# The menu asks for the download consent only when a download is actually missing, so a hot cache asks
# nothing. Verification is read-only: it hashes the cached files and never reaches the network.
function Test-ToolkitConcealmentCacheHot {
    $cacheRoot = ''
    $manifest = $null
    try {
        $cacheRoot = Get-ToolkitAssetCacheRoot
        $manifest = Get-ToolkitManifest -Path (Join-Path $PSScriptRoot 'Manifest.json')
    }
    catch {
        return $false
    }
    foreach ($assetId in @($script:ConcealmentDependencyAssetIds)) {
        $verified = Get-VerifiedAsset -Manifest $manifest -Id $assetId -CacheRoot $cacheRoot
        if ([string]$verified.Status -cne 'Success') {
            return $false
        }
    }
    return $true
}

function Start-ToolkitController {
    param(
        [string]$Action = '',
        [string]$InstallRoot = '',
        [int]$InstanceIndex = -1,
        [int]$SourceIndex = -1,
        [string]$StateRoot = '',
        [string[]]$Packages = @(),
        [string]$Mode = '',
        [object]$StartIndex = $null,
        [switch]$Confirmed,
        [switch]$NonInteractive,
        [switch]$SkipToolbar,
        [switch]$FetchDependencies,
        [switch]$ElevatedChild,
        [scriptblock]$Reader = $null,
        [scriptblock]$Writer = $null,
        [scriptblock]$Prompt = $null,
        [scriptblock]$ActionRunner = $null,
        [scriptblock]$ElevationRunner = $null
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
    $Packages = ConvertTo-ToolkitPackageSelection -Packages $Packages
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
        $result = Invoke-MenuAction -Action $Action -InstallRoot $InstallRoot -InstanceIndex $InstanceIndex -SourceIndex $SourceIndex -StateRoot $statePath -Packages $Packages -Mode $Mode -StartIndex $StartIndex -Confirmed:$Confirmed -FetchDependencies:$FetchDependencies -ElevatedChild:$ElevatedChild -LogPath $logPath -ElevationRunner $ElevationRunner
        foreach ($line in @(Format-ToolkitResult -Result $result)) {
            & $write $line
        }
        return (Get-ToolkitExitCode $result)
    }

    $read = $Reader
    if ($null -eq $read) {
        $read = { param() Read-Host ('Select an action (1-' + @(Get-ToolkitActionCatalog).Count + ')') }
    }
    $ask = $Prompt
    if ($null -eq $ask) {
        $ask = { param($Question) [string](Read-Host $Question) }
    }
    $runner = $ActionRunner
    if ($null -eq $runner) {
        # A closure sees the locals it was built from, not the script scope, so the consent word is
        # captured here where the runner is assembled.
        $consentWord = $script:ToolkitDependencyConsentWord
        $runner = {
            param($Choice)

            $selectedPackages = @($Packages)
            # An explicit -FetchDependencies is the consent, and a cache that already holds both verified
            # pinned assets needs no download, so the question is asked only when it can change the run.
            $fetchDependencies = $FetchDependencies
            if ($Choice -ceq 'Conceal') {
                if ($selectedPackages.Count -eq 0) {
                    $answer = [string](& $ask 'Comma-separated application package names for the Root template')
                    $selectedPackages = @($answer -split ',' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
                }
                if (-not $fetchDependencies -and -not (Test-ToolkitConcealmentCacheHot)) {
                    # The consent is asked for exactly as the command line asks for it, so a cold cache is
                    # reachable from the menu and a declining answer still downloads nothing.
                    $consent = [string](& $ask ('Type ' + $consentWord + ' to download the pinned concealment dependencies into the per-user cache now'))
                    $fetchDependencies = $consent.Trim() -ceq $consentWord
                }
            }
            $confirmed = $Confirmed
            if ($Choice -ceq 'Root15' -and -not $confirmed) {
                $confirmed = ([string](& $ask 'Type CONFIRM to enable the built-in Android 15 root') -ceq 'CONFIRM')
            }
            $targetMode = ''
            $targetStartIndex = $null
            $targetSourceIndex = $SourceIndex
            if ($Choice -ceq 'Target') {
                $targetMode = $Mode
                $targetStartIndex = $StartIndex
            }
            return (Invoke-ToolkitActionWithElevation -Action $Choice -InstallRoot $InstallRoot -InstanceIndex $InstanceIndex -SourceIndex $targetSourceIndex -StateRoot $statePath -Packages $selectedPackages -Mode $targetMode -StartIndex $targetStartIndex -Confirmed:$confirmed -FetchDependencies:$fetchDependencies -ElevatedChild:$ElevatedChild -Prompt $ask -ElevationRunner $ElevationRunner)
        }.GetNewClosure()
    }

    if (-not $SkipToolbar) {
        & $write 'MuMu Root Hide Toolkit'
        & $write 'Detect and Verify change nothing.'
        & $write 'Target identifies the instance to work on, or creates or clones one. Identify changes nothing; Create and Clone ask for CONFIRM first and are the only ways this toolkit adds an instance.'
        & $write 'Root12 and Root15 stop the selected instance when needed, create and verify a clone, and change only that clone. Conceal changes only the verified clone.'
        & $write 'Conceal asks whether to download its pinned Hide My Applist and Vector dependencies when the per-user cache does not already hold them. Type FETCH to allow that download now; any other answer downloads nothing.'
        & $write 'RemoveAds and Restore change only the MuMu campaign files inside the selected installation, and every change keeps an exact backup.'
        & $write 'A mutating action that is denied the rights it needs asks for administrator rights once, in its own window, and fails closed if that is declined or the prompt is not answered in time. Detect and Verify never ask.'
        foreach ($entry in @(Get-ToolkitActionCatalog)) {
            & $write ('  ' + ([string]$entry.Number) + '  ' + ([string]$entry.Name).PadRight(10) + [string]$entry.Description)
        }
    }
    return (Invoke-MenuLoop -Reader $read -Writer $write -Runner $runner -StateRoot $statePath -LogPath $logPath)
}

if ($MyInvocation.InvocationName -ne '.') {
    # UAC is a process-level concern, so only the entry point arms the elevation seam and only the
    # entry point that is not already the elevated child carries it. An elevated child therefore has
    # no seam at all and cannot ask for rights a second time, whatever the dispatcher decides.
    $elevationRunner = $null
    if (-not $ElevatedChild) {
        $elevationRunner = $script:ToolkitProductionElevationRunner
    }
    exit (Start-ToolkitController -Action $Action -InstallRoot $InstallRoot -InstanceIndex $InstanceIndex -SourceIndex $SourceIndex -StateRoot $StateRoot -Packages $Packages -Mode $Mode -StartIndex $StartIndex -Confirmed:$Confirmed -NonInteractive:$NonInteractive -SkipToolbar:$SkipToolbar -FetchDependencies:$FetchDependencies -ElevatedChild:$ElevatedChild -ElevationRunner $elevationRunner)
}
