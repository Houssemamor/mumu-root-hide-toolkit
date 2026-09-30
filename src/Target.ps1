$script:ToolkitTargetModes = @('Identify', 'Create', 'Clone')

function ConvertTo-ToolkitInstanceIndex {
    param([object]$Value)

    if ($null -eq $Value) {
        return $null
    }
    if ($Value -isnot [string] -and $Value -isnot [int] -and $Value -isnot [long]) {
        return $null
    }
    $text = ([string]$Value).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }
    $parsed = 0
    if (-not [int]::TryParse($text, [ref]$parsed) -or $parsed -lt 0) {
        return $null
    }
    return $parsed
}

function Get-ToolkitInstanceChoices {
    param(
        [object]$Install,
        [scriptblock]$Runner = $null
    )

    if ($null -eq $Install -or $Install -is [Array]) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Install is invalid.'
    }
    $managerPath = [string](Get-ToolkitFirstProperty -InputObject $Install -PropertyNames @('ManagerPath'))
    $instances = @(Get-MuMuInstances -Install $Install -ManagerPath $managerPath -Runner $Runner)
    if ($instances.Count -eq 1 -and $null -ne $instances[0].PSObject.Properties['Status']) {
        return $instances[0]
    }

    $choices = @()
    foreach ($instance in $instances) {
        $choices += [pscustomobject]@{
            Index = [int]$instance.Index
            Name = [string]$instance.Name
            AndroidVersion = $instance.AndroidVersion
            Running = $instance.Running
            Eligible = [bool]$instance.Eligible
        }
    }
    return Get-ToolkitResult -Status 'Success' -Message "$($choices.Count) instance(s) were read from the selected installation. Nothing was changed." -Data $choices
}

function Resolve-ToolkitCloneSource {
    param(
        [object]$Install,
        [int]$SourceIndex = -1,
        [int]$InstanceIndex = -1,
        [scriptblock]$Prompt = $null,
        [scriptblock]$Runner = $null
    )

    if ($null -eq $Install -or $Install -is [Array]) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Install is invalid.'
    }
    $managerPath = [string](Get-ToolkitFirstProperty -InputObject $Install -PropertyNames @('ManagerPath'))
    $instances = @(Get-MuMuInstances -Install $Install -ManagerPath $managerPath -Runner $Runner)
    if ($instances.Count -eq 1 -and $null -ne $instances[0].PSObject.Properties['Status']) {
        return $instances[0]
    }
    $eligible = @($instances | Where-Object { $_.Eligible -eq $true })
    $requestedIndex = $SourceIndex
    if ($requestedIndex -lt 0) {
        $requestedIndex = $InstanceIndex
    }
    $selection = $null
    if ($requestedIndex -ge 0) {
        $selection = [pscustomobject]@{ Index = $requestedIndex }
    }
    elseif ($eligible.Count -gt 1) {
        $choice = Get-ToolkitMenuChoice -Label 'Select the clone source MuMu instance' -Count $eligible.Count -Prompt $Prompt
        if ($null -eq $choice) {
            return Get-ToolkitResult -Status 'CriticalError' -Message "$($eligible.Count) eligible MuMu instances were found, so an explicit clone source is required. Pass -InstanceIndex or -SourceIndex to select one without a prompt. No instance was cloned."
        }
        $selection = [pscustomobject]@{ Index = [int]$eligible[$choice - 1].Index }
    }
    $resolved = Resolve-SelectedInstance -Instances $instances -Selection $selection
    if ($null -ne $resolved.PSObject.Properties['Status']) {
        return $resolved
    }
    return Get-ToolkitResult -Status 'Success' -Message "The clone source is the MuMu instance at index $([int]$resolved.Index)." -Data $resolved
}

function New-MuMuInstance {
    param(
        [string]$ManagerPath,
        [object]$Install,
        [object]$Journal,
        [int]$Count = 1,
        [object]$StartIndex = $null,
        [string]$AndroidVersion = '',
        [switch]$Confirmed,
        [scriptblock]$Runner = $null
    )

    $manager = ConvertTo-ToolkitFullPath -Path $ManagerPath
    if ($null -eq $manager -or -not (Test-ToolkitManagerName -Path $manager)) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The create manager must be MuMuManager.exe.'
    }
    if ($null -eq $Journal) {
        return New-ToolkitInstanceFailure -Journal $null -Message 'A create journal is required.'
    }
    try {
        Assert-OperationJournal $Journal
    }
    catch {
        return New-ToolkitInstanceFailure -Journal $null -Message 'The create journal is invalid.'
    }
    if (-not $Confirmed) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'Creating a MuMu instance requires an explicit confirmation. Rerun it with -Confirmed. No instance was created.' -Code 'USER_CONFIRMATION_REQUIRED'
    }
    if ($Count -ne 1) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'Exactly one instance can be created at a time, so no instance was created.'
    }
    $requestedIndex = $null
    if ($null -ne $StartIndex) {
        $requestedIndex = ConvertTo-ToolkitInstanceIndex -Value $StartIndex
        if ($null -eq $requestedIndex) {
            return New-ToolkitInstanceFailure -Journal $Journal -Message 'The requested start index must be a non-negative integer, so no instance was created.'
        }
    }

    if ($null -eq $Install -or $Install -is [Array]) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The create install is invalid.'
    }
    $installRootProperty = $Install.PSObject.Properties['InstallRoot']
    $vmsProperty = $Install.PSObject.Properties['VmsPath']
    if ($null -eq $installRootProperty -or $installRootProperty.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($installRootProperty.Value) -or
        $null -eq $vmsProperty -or $vmsProperty.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($vmsProperty.Value)) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The create install paths are invalid.'
    }
    $installRoot = ConvertTo-ToolkitFullPath -Path $installRootProperty.Value
    $vmsPath = ConvertTo-ToolkitFullPath -Path $vmsProperty.Value
    if ($null -eq $installRoot -or -not (Test-Path -LiteralPath $installRoot -PathType Container) -or
        $null -eq $vmsPath -or -not (Test-Path -LiteralPath $vmsPath -PathType Container)) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The create install paths are unavailable.'
    }
    if (-not (Test-ToolkitManagerFile -Path $manager -InstallRoot $installRoot)) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The create manager is not a valid MuMu manager inside the install root.'
    }
    $selectedManagerPath = [string](Get-ToolkitFirstProperty -InputObject $Install -PropertyNames @('ManagerPath'))
    if (-not [string]::IsNullOrWhiteSpace($selectedManagerPath) -and
        -not $manager.Equals((ConvertTo-ToolkitFullPath -Path $selectedManagerPath), [StringComparison]::OrdinalIgnoreCase)) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The create manager conflicts with the selected installation.'
    }

    $preRecords = @(Get-MuMuInstanceRecord -ManagerPath $manager -VersionArgument 'all' -Runner $Runner)
    if ($preRecords.Count -eq 0) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The MuMu manager did not report instance state.'
    }
    $preIndexes = @{}
    foreach ($preRecord in $preRecords) {
        $preIndexProperty = $preRecord.PSObject.Properties['index']
        $parsedPreIndex = 0
        if ($null -eq $preIndexProperty -or -not [int]::TryParse([string]$preIndexProperty.Value, [ref]$parsedPreIndex) -or $parsedPreIndex -lt 0) {
            return New-ToolkitInstanceFailure -Journal $Journal -Message 'The MuMu manager returned an invalid instance index.'
        }
        $preIndexes[[string]$parsedPreIndex] = $true
    }
    if ($null -ne $requestedIndex -and $preIndexes.ContainsKey([string]$requestedIndex)) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message "The requested index $requestedIndex is already in use, so no instance was created."
    }

    # The engine is named explicitly when the caller asked for one, because the manager otherwise picks
    # a default and a create aimed at the Android 15 root must not silently land on Android 12.
    $createArguments = @('create', '-n', [string]$Count)
    $requestedVersion = ConvertTo-ToolkitAndroidVersion -Value $AndroidVersion
    if (-not [string]::IsNullOrWhiteSpace($requestedVersion)) {
        $createArguments += @('-ver', ([string]$requestedVersion -replace '\.0$', ''))
    }
    $create = Invoke-CheckedProcess -FilePath $manager -ArgumentList $createArguments -Runner $Runner
    if ($null -eq $create -or $create.ExitCode -ne 0) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The MuMu manager create command failed.'
    }

    $postRecords = @(Get-MuMuInstanceRecord -ManagerPath $manager -VersionArgument 'all' -Runner $Runner)
    $newRecords = @($postRecords | Where-Object { -not $preIndexes.ContainsKey([string]$_.index) })
    if ($newRecords.Count -ne 1) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The MuMu manager did not report exactly one new instance after the create command.'
    }
    $createdRecord = $newRecords[0]
    $createdIndex = 0
    if (-not [int]::TryParse([string]$createdRecord.index, [ref]$createdIndex) -or $createdIndex -lt 0) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The created instance index is invalid.'
    }
    $nameProperty = $createdRecord.PSObject.Properties['name']
    if ($null -eq $nameProperty -or $nameProperty.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($nameProperty.Value)) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The created instance name is missing.'
    }
    $createdName = [string]$nameProperty.Value

    $reportedVmsPath = [string](Get-ToolkitFirstProperty -InputObject $createdRecord -PropertyNames @('vms_path', 'vmsPath'))
    if (-not [string]::IsNullOrWhiteSpace($reportedVmsPath)) {
        $reportedRoot = Get-ToolkitMetadataPath -Path $reportedVmsPath -Root $vmsPath
        if ($null -eq $reportedRoot) {
            return New-ToolkitInstanceFailure -Journal $Journal -Message 'The created instance VMS path is invalid.'
        }
        if (-not (Test-ToolkitPathWithinRoot -Path $reportedRoot -Root $vmsPath)) {
            return New-ToolkitInstanceFailure -Journal $Journal -Message 'The created instance VMS path is outside the install boundary.'
        }
    }
    $createdRoot = Get-MuMuInstanceRootPath -VmsPath $vmsPath -Index $createdIndex -ReportedVmsPath $reportedVmsPath
    if ($null -eq $createdRoot) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The created instance root is missing.'
    }
    if (-not (Test-ToolkitPathWithinRoot -Path $createdRoot -Root $vmsPath)) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The created instance root is outside the install boundary.'
    }
    if ((ConvertTo-ToolkitBoolean -Value (Get-ToolkitFirstProperty -InputObject $createdRecord -PropertyNames @('is_main'))) -ne $false) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The created instance is not a reported non-base instance.'
    }
    $createdVersion = ConvertTo-ToolkitAndroidVersion -Value (Get-ToolkitFirstProperty -InputObject $createdRecord -PropertyNames @('android_version', 'androidVersion', 'system_version', 'systemVersion'))
    if ([string]::IsNullOrWhiteSpace($createdVersion)) {
        $createdVersion = Get-ToolkitInstanceAndroidVersion -VmsPath $vmsPath -Index $createdIndex
    }
    if ([string]::IsNullOrWhiteSpace($createdVersion)) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The created instance Android version could not be verified.'
    }
    $diskBytes = Measure-MuMuInstanceDiskBytes -InstanceRoot $createdRoot
    if ($null -eq $diskBytes) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The created instance disk could not be measured.'
    }
    if ($diskBytes -le 0) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The created instance does not have a usable disk.'
    }

    $createdData = @{
        Mode = 'Create'
        Index = $createdIndex
        Name = $createdName
        AndroidVersion = $createdVersion
        Running = Get-MuMuInstanceRunningState -Record $createdRecord
        DiskBytes = $diskBytes
        VmsPath = $createdRoot
        RequestedIndex = $requestedIndex
        StaticReady = $true
        ColdBootVerified = $false
    }
    $createdMessage = "Instance statically verified at index $createdIndex. A cold boot is not verified."
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message $createdMessage -Data $createdData
    }
    catch {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The verified created instance could not be journaled.'
    }
    return Get-ToolkitResult -Status 'Success' -Message $createdMessage -Data $createdData
}

function Select-ToolkitTarget {
    param(
        [object]$Install,
        [object]$Journal,
        [string]$Mode = 'Identify',
        [int]$InstanceIndex = -1,
        [int]$SourceIndex = -1,
        [object]$StartIndex = $null,
        [string]$AndroidVersion = '',
        [switch]$Confirmed,
        [scriptblock]$Prompt = $null,
        [scriptblock]$Runner = $null
    )

    if ($null -eq $Journal) {
        return New-ToolkitInstanceFailure -Journal $null -Message 'A target journal is required.'
    }
    try {
        Assert-OperationJournal $Journal
    }
    catch {
        return New-ToolkitInstanceFailure -Journal $null -Message 'The target journal is invalid.'
    }
    if ($null -eq $Install -or $Install -is [Array]) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'Install is invalid.'
    }
    if ($script:ToolkitTargetModes -cnotcontains $Mode) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The target mode must be Identify, Create, or Clone, so no instance was created or changed.'
    }
    if (-not $Confirmed -and $Mode -cne 'Identify') {
        return New-ToolkitInstanceFailure -Journal $Journal -Message "The $Mode target mode requires an explicit confirmation. Rerun it with -Confirmed. No instance was created or changed." -Code 'USER_CONFIRMATION_REQUIRED'
    }

    $managerPath = [string](Get-ToolkitFirstProperty -InputObject $Install -PropertyNames @('ManagerPath'))
    $edition = [string](Get-ToolkitFirstProperty -InputObject $Install -PropertyNames @('Edition'))

    if ($Mode -ceq 'Create') {
        $created = New-MuMuInstance -ManagerPath $managerPath -Install $Install -Journal $Journal -Count 1 -StartIndex $StartIndex -AndroidVersion $AndroidVersion -Confirmed -Runner $Runner
        if ($created.Status -ne 'Success') {
            return $created
        }
        $createdData = @{
            Mode = 'Create'
            Index = [int]$created.Data.Index
            Name = [string]$created.Data.Name
            AndroidVersion = [string]$created.Data.AndroidVersion
            Edition = $edition
            Running = $created.Data.Running
            DiskBytes = $created.Data.DiskBytes
            VmsPath = [string]$created.Data.VmsPath
            RequestedIndex = $created.Data.RequestedIndex
            StaticReady = $true
            ColdBootVerified = $false
        }
        $createdMessage = "The created MuMu instance at index $($createdData.Index) is the selected target."
        try {
            Write-JournalEvent -Journal $Journal -Level 'Info' -Message $createdMessage -Data $createdData
        }
        catch {
            return New-ToolkitInstanceFailure -Journal $Journal -Message 'The created target could not be journaled.'
        }
        return Get-ToolkitResult -Status 'Success' -Message $createdMessage -Data $createdData
    }

    if ($Mode -ceq 'Clone') {
        $source = Resolve-ToolkitCloneSource -Install $Install -SourceIndex $SourceIndex -InstanceIndex $InstanceIndex -Prompt $Prompt -Runner $Runner
        if ($source.Status -ne 'Success') {
            return $source
        }
        $cloneSourceIndex = [int]$source.Data.Index
        $clone = New-InstanceClone -ManagerPath $managerPath -Instance $source.Data -Journal $Journal -Runner $Runner
        if ($clone.Status -ne 'Success') {
            return $clone
        }
        $cloneData = @{
            Mode = 'Clone'
            Index = [int]$clone.Data.CloneIndex
            Name = [string]$clone.Data.CloneName
            AndroidVersion = [string]$clone.Data.AndroidVersion
            Edition = $edition
            Running = $false
            SourceIndex = [int]$clone.Data.SourceIndex
            DiskBytes = $clone.Data.DiskBytes
            VmsPath = [string]$clone.Data.VmsPath
            StaticReady = $true
            ColdBootVerified = $false
        }
        $cloneMessage = "The clone of instance $cloneSourceIndex at index $($cloneData.Index) is the selected target."
        try {
            Write-JournalEvent -Journal $Journal -Level 'Info' -Message $cloneMessage -Data $cloneData
        }
        catch {
            return New-ToolkitInstanceFailure -Journal $Journal -Message 'The cloned target could not be journaled.'
        }
        return Get-ToolkitResult -Status 'Success' -Message $cloneMessage -Data $cloneData
    }

    $listing = Get-ToolkitInstanceChoices -Install $Install -Runner $Runner
    if ($listing.Status -ne 'Success') {
        return $listing
    }
    $instances = @($listing.Data)
    $eligible = @($instances | Where-Object { $_.Eligible -eq $true })
    if ($eligible.Count -eq 0) {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'No eligible MuMu instance was found in the selected installation, so no target was selected.'
    }
    $selection = $null
    if ($InstanceIndex -ge 0) {
        $selection = [pscustomobject]@{ Index = $InstanceIndex }
    }
    elseif ($eligible.Count -gt 1) {
        $choice = Get-ToolkitMenuChoice -Label 'Select the target MuMu instance' -Count $eligible.Count -Prompt $Prompt
        if ($null -eq $choice) {
            return New-ToolkitInstanceFailure -Journal $Journal -Message "$($eligible.Count) eligible MuMu instances were found, so an explicit target is required. Pass -InstanceIndex to select one without a prompt."
        }
        $selection = [pscustomobject]@{ Index = [int]$eligible[$choice - 1].Index }
    }
    $resolved = Resolve-SelectedInstance -Instances $instances -Selection $selection
    if ($null -ne $resolved.PSObject.Properties['Status']) {
        return $resolved
    }
    $targetData = @{
        Mode = 'Identify'
        Index = [int]$resolved.Index
        Name = [string]$resolved.Name
        AndroidVersion = [string]$resolved.AndroidVersion
        Edition = $edition
        Running = $resolved.Running
        Eligible = [bool]$resolved.Eligible
        InstanceCount = $instances.Count
        Instances = $instances
    }
    $targetMessage = "The MuMu instance at index $($targetData.Index) is the selected target. Nothing was changed."
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message $targetMessage -Data $targetData
    }
    catch {
        return New-ToolkitInstanceFailure -Journal $Journal -Message 'The selected target could not be journaled.'
    }
    return Get-ToolkitResult -Status 'Success' -Message $targetMessage -Data $targetData
}
