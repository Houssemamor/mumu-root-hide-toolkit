function Get-ToolkitResolvedPath {
    param(
        [string]$Path,
        [int]$Depth = 0
    )

    if ($Depth -ge 32) {
        return $null
    }
    $fullPath = ConvertTo-ToolkitFullPath -Path $Path
    $pathRoot = if ($null -eq $fullPath) { $null } else { [IO.Path]::GetPathRoot($fullPath) }
    if ($null -eq $fullPath -or [string]::IsNullOrWhiteSpace($pathRoot)) {
        return $null
    }
    $currentPath = $pathRoot
    $relativePath = $fullPath.Substring($pathRoot.Length)
    $segments = @($relativePath.Split([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar), [StringSplitOptions]::RemoveEmptyEntries))
    $seenPaths = @{}

    foreach ($segment in $segments) {
        $key = $currentPath.ToUpperInvariant()
        if ($seenPaths.ContainsKey($key)) {
            return $null
        }
        $seenPaths[$key] = $true
        $currentPath = ConvertTo-ToolkitFullPath -Path (Join-Path $currentPath $segment)
        if ($null -eq $currentPath) {
            return $null
        }
        try {
            $item = Get-Item -LiteralPath $currentPath -Force -ErrorAction Stop
        }
        catch {
            return $null
        }
        $isReparsePoint = ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
        if (-not $isReparsePoint) {
            continue
        }
        $linkTypeProperty = $item.PSObject.Properties['LinkType']
        $targetProperty = $item.PSObject.Properties['Target']
        if ($null -eq $linkTypeProperty -or $linkTypeProperty.Value -notmatch '^(?i:Junction|SymbolicLink)$' -or
            $null -eq $targetProperty) {
            return $null
        }
        $resolvedTargets = @{}
        foreach ($target in @($targetProperty.Value)) {
            if ($target -isnot [string] -or [string]::IsNullOrWhiteSpace($target)) {
                return $null
            }
            $targetPath = Get-ToolkitMetadataPath -Path $target -Root ([IO.Path]::GetDirectoryName($currentPath))
            $resolvedTarget = Get-ToolkitResolvedPath -Path $targetPath -Depth ($Depth + 1)
            if ($null -eq $resolvedTarget) {
                return $null
            }
            $resolvedTargets[$resolvedTarget.ToUpperInvariant()] = $resolvedTarget
        }
        if ($resolvedTargets.Count -ne 1) {
            return $null
        }
        $currentPath = @($resolvedTargets.Values)[0]
    }
    return $currentPath
}

function Test-ToolkitPathWithinRoot {
    param(
        [string]$Path,
        [string]$Root
    )

    $fullPath = ConvertTo-ToolkitFullPath -Path $Path
    $fullRoot = ConvertTo-ToolkitFullPath -Path $Root
    if ($null -eq $fullPath -or $null -eq $fullRoot) {
        return $false
    }
    $resolvedPath = Get-ToolkitResolvedPath -Path $fullPath
    $resolvedRoot = Get-ToolkitResolvedPath -Path $fullRoot
    if ($null -eq $resolvedPath -or $null -eq $resolvedRoot) {
        return $false
    }
    if ($resolvedPath.Equals($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    $trimmedRoot = $resolvedRoot.TrimEnd([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar))
    $prefix = $trimmedRoot + [IO.Path]::DirectorySeparatorChar
    return $resolvedPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)
}

function Get-ToolkitEdition {
    param(
        [string]$Text,
        [string]$ExplicitEdition
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitEdition) -and $ExplicitEdition -cnotin @('Global', 'Chinese')) {
        throw 'Edition metadata is invalid.'
    }
    $inferredEdition = $null
    if ($Text -match '(?i)global') {
        $inferredEdition = 'Global'
    }
    elseif ($Text -match '(?i)mumuplayer') {
        $inferredEdition = 'Chinese'
    }
    if ($null -ne $inferredEdition -and -not [string]::IsNullOrWhiteSpace($ExplicitEdition) -and
        $inferredEdition -cne $ExplicitEdition) {
        throw 'Edition metadata conflicts with its path.'
    }
    if (-not [string]::IsNullOrWhiteSpace($ExplicitEdition)) {
        return $ExplicitEdition
    }
    if ($null -ne $inferredEdition) {
        return $inferredEdition
    }
    throw 'Edition cannot be determined.'
}

function Test-ToolkitRegistryIdentity {
    param(
        [object]$Entry,
        [string]$InstallRoot,
        [string]$ManagerPath
    )

    if (Test-ToolkitManagerFile -Path $ManagerPath -InstallRoot $InstallRoot) {
        return $true
    }
    $editionProperty = $Entry.PSObject.Properties['Edition']
    if ($null -eq $editionProperty -or $editionProperty.Value -isnot [string] -or
        [string]::IsNullOrWhiteSpace($editionProperty.Value) -or
        $editionProperty.Value -cnotin @('Global', 'Chinese')) {
        return $false
    }
    $displayName = ''
    if ($null -ne $Entry.PSObject.Properties['DisplayName'] -and $Entry.DisplayName -is [string]) {
        $displayName = $Entry.DisplayName
    }
    $identityText = $displayName + ' ' + $InstallRoot
    if ($null -ne $Entry.PSObject.Properties['Publisher'] -and $Entry.Publisher -is [string]) {
        $identityText += ' ' + $Entry.Publisher
    }
    return $identityText -match '(?i)(mumu|netease)'
}

function Get-ToolkitInstallRoot {
    param([string]$Path)

    $fullPath = ConvertTo-ToolkitFullPath -Path $Path
    if ($null -eq $fullPath -or -not (Test-Path -LiteralPath $fullPath)) {
        return $null
    }

    $item = Get-Item -LiteralPath $fullPath -ErrorAction SilentlyContinue
    if ($item -is [IO.DirectoryInfo]) {
        return $fullPath
    }
    if ($item -isnot [IO.FileInfo]) {
        return $null
    }

    $directory = [IO.Path]::GetDirectoryName($fullPath)
    $directoryName = [IO.Path]::GetFileName($directory)
    if ($directoryName -match '^(?i:shell)$') {
        $parentDirectory = [IO.Path]::GetDirectoryName($directory)
        if ([IO.Path]::GetFileName($parentDirectory) -match '^(?i:nx_main)$') {
            return ConvertTo-ToolkitFullPath -Path ([IO.Path]::GetDirectoryName($parentDirectory))
        }
        return ConvertTo-ToolkitFullPath -Path $parentDirectory
    }
    if ($directoryName -match '^(?i:nx_main|nx_device)$') {
        return ConvertTo-ToolkitFullPath -Path ([IO.Path]::GetDirectoryName($directory))
    }
    return $directory
}

function Test-ToolkitManagerName {
    param([string]$Path)

    $fullPath = ConvertTo-ToolkitFullPath -Path $Path
    return $null -ne $fullPath -and [IO.Path]::GetFileName($fullPath) -ieq 'MuMuManager.exe'
}

function Test-ToolkitManagerFile {
    param(
        [string]$Path,
        [string]$InstallRoot
    )

    if (-not (Test-ToolkitManagerName -Path $Path)) {
        return $false
    }
    $fullPath = ConvertTo-ToolkitFullPath -Path $Path
    if ($null -eq $fullPath -or -not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        return $false
    }
    try {
        $item = Get-Item -LiteralPath $fullPath -Force -ErrorAction Stop
    }
    catch {
        return $false
    }
    if ($item -isnot [IO.FileInfo] -or ($item.Attributes -band [IO.FileAttributes]::Directory) -ne 0) {
        return $false
    }
    return Test-ToolkitPathWithinRoot -Path $fullPath -Root $InstallRoot
}

function Get-ToolkitManagerPaths {
    param([string]$InstallRoot)

    $root = ConvertTo-ToolkitFullPath -Path $InstallRoot
    if ($null -eq $root -or -not (Test-Path -LiteralPath $root -PathType Container)) {
        return @()
    }

    $managerPaths = @{}
    foreach ($relativePath in @('MuMuManager.exe', 'shell\MuMuManager.exe', 'nx_main\MuMuManager.exe', 'nx_main\shell\MuMuManager.exe')) {
        $candidate = ConvertTo-ToolkitFullPath -Path (Join-Path $root $relativePath)
        if (Test-ToolkitManagerFile -Path $candidate -InstallRoot $root) {
            $managerPaths[$candidate.ToUpperInvariant()] = $candidate
        }
    }
    return @($managerPaths.Values)
}

function Get-ToolkitMetadataPath {
    param(
        [string]$Path,
        [string]$Root
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }
    try {
        if (-not [IO.Path]::IsPathRooted($Path)) {
            $Path = Join-Path $Root $Path
        }
    }
    catch {
        return $null
    }
    return ConvertTo-ToolkitFullPath -Path $Path
}

function Get-ToolkitVmsPath {
    param(
        [string]$InstallRoot,
        [string]$CandidatePath,
        [ValidateSet('Global', 'Chinese')]
        [string]$Edition
    )

    $root = ConvertTo-ToolkitFullPath -Path $InstallRoot
    if ($null -eq $root -or -not (Test-Path -LiteralPath $root -PathType Container)) {
        throw 'InstallRoot is unavailable for VMS discovery.'
    }
    if (-not [string]::IsNullOrWhiteSpace($CandidatePath)) {
        $candidate = Get-ToolkitMetadataPath -Path $CandidatePath -Root $root
        if ($null -eq $candidate -or -not (Test-Path -LiteralPath $candidate -PathType Container)) {
            throw 'Explicit VMS path is invalid.'
        }
        return $candidate
    }

    $inferredPaths = @{}
    if ([IO.Path]::GetFileName($root) -match '^(?i:vms|vms.*)$') {
        $inferredPaths[$root.ToUpperInvariant()] = $root
    }
    $relativePaths = if ($Edition -eq 'Global') {
        @('vms', 'nx_device\12.0\vms', 'nx_device\15.0\vms')
    }
    else {
        @('MuMuPlayer\vms', 'vms', 'nx_device\12.0\vms', 'nx_device\15.0\vms')
    }
    foreach ($relativePath in $relativePaths) {
        $inferred = ConvertTo-ToolkitFullPath -Path (Join-Path $root $relativePath)
        if ($null -ne $inferred -and (Test-Path -LiteralPath $inferred -PathType Container)) {
            $inferredPaths[$inferred.ToUpperInvariant()] = $inferred
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($env:APPDATA)) {
        $userDataRelativePath = if ($Edition -eq 'Global') {
            'Netease\MuMuPlayerGlobal\vms'
        }
        else {
            'Netease\MuMuPlayer\vms'
        }
        $userDataPath = ConvertTo-ToolkitFullPath -Path (Join-Path $env:APPDATA $userDataRelativePath)
        if ($null -ne $userDataPath -and (Test-Path -LiteralPath $userDataPath -PathType Container)) {
            $inferredPaths[$userDataPath.ToUpperInvariant()] = $userDataPath
        }
    }

    $metadataPath = Join-Path $root 'nx_device\configs\install_config.json'
    if (Test-Path -LiteralPath $metadataPath -PathType Leaf) {
        try {
            $metadata = [IO.File]::ReadAllText($metadataPath) | ConvertFrom-Json -ErrorAction Stop
            foreach ($propertyName in @('vms_path', 'vmsPath', 'vms_root', 'vmsRoot')) {
                $property = $metadata.PSObject.Properties[$propertyName]
                if ($null -ne $property -and $property.Value -is [string] -and -not [string]::IsNullOrWhiteSpace($property.Value)) {
                    $metadataPathValue = Get-ToolkitMetadataPath -Path $property.Value -Root $root
                    if ($null -ne $metadataPathValue -and (Test-Path -LiteralPath $metadataPathValue -PathType Container)) {
                        $inferredPaths[$metadataPathValue.ToUpperInvariant()] = $metadataPathValue
                    }
                }
            }
        }
        catch {
        }
    }

    if ($inferredPaths.Count -gt 1) {
        throw 'Multiple VMS paths were inferred.'
    }
    if ($inferredPaths.Count -eq 1) {
        return @($inferredPaths.Values)[0]
    }
    return $null
}

function Get-ToolkitUninstallEntries {
    param([string]$Root)

    if ([string]::IsNullOrWhiteSpace($Root) -or -not (Test-Path -LiteralPath $Root)) {
        return @()
    }

    $keys = @()
    try {
        $rootItem = Get-Item -LiteralPath $Root -ErrorAction Stop
        $rootProperties = Get-ItemProperty -LiteralPath $rootItem.PSPath -ErrorAction Stop
        if ($null -ne $rootProperties.PSObject.Properties['InstallLocation']) {
            $keys = @($rootItem)
        }
        else {
            $keys = @(Get-ChildItem -LiteralPath $rootItem.PSPath -ErrorAction Stop)
        }
    }
    catch {
        return @()
    }

    $entries = @()
    foreach ($key in $keys) {
        try {
            $properties = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction Stop
            $installLocation = $properties.PSObject.Properties['InstallLocation']
            if ($null -eq $installLocation -or $installLocation.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($installLocation.Value)) {
                continue
            }
            $displayName = ''
            if ($null -ne $properties.PSObject.Properties['DisplayName'] -and $properties.DisplayName -is [string]) {
                $displayName = $properties.DisplayName
            }
            $edition = ''
            if ($null -ne $properties.PSObject.Properties['Edition'] -and $properties.Edition -is [string]) {
                $edition = $properties.Edition
            }
            $vmsPath = ''
            if ($null -ne $properties.PSObject.Properties['VmsPath'] -and $properties.VmsPath -is [string]) {
                $vmsPath = $properties.VmsPath
            }
            $publisher = ''
            if ($null -ne $properties.PSObject.Properties['Publisher'] -and $properties.Publisher -is [string]) {
                $publisher = $properties.Publisher
            }
            $entries += [pscustomobject]@{
                Root = $Root
                DisplayName = $displayName
                Publisher = $publisher
                InstallLocation = $installLocation.Value
                Edition = $edition
                VmsPath = $vmsPath
            }
        }
        catch {
        }
    }
    return @($entries)
}

function Get-ToolkitProcessExecutable {
    param([object]$ProcessRecord)

    foreach ($propertyName in @('ExecutablePath', 'Path', 'Executable', 'ManagerPath')) {
        $property = $ProcessRecord.PSObject.Properties[$propertyName]
        if ($null -ne $property -and $property.Value -is [string] -and -not [string]::IsNullOrWhiteSpace($property.Value)) {
            return ConvertTo-ToolkitFullPath -Path $property.Value
        }
    }

    $commandLineProperty = $ProcessRecord.PSObject.Properties['CommandLine']
    if ($null -eq $commandLineProperty -or $commandLineProperty.Value -isnot [string]) {
        return $null
    }
    $commandLine = [string]$commandLineProperty.Value
    $match = [regex]::Match($commandLine, '^\s*"([^"]+)"')
    if (-not $match.Success) {
        $match = [regex]::Match($commandLine, '^\s*((?:[A-Za-z]:\\).+?\.exe)(?=\s|$)', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }
    if (-not $match.Success) {
        return $null
    }
    return ConvertTo-ToolkitFullPath -Path $match.Groups[1].Value
}

function Get-ToolkitProcessVmsPaths {
    param([object]$ProcessRecord)

    $paths = @()
    foreach ($propertyName in @('VmsPath', 'VMSPath')) {
        $property = $ProcessRecord.PSObject.Properties[$propertyName]
        if ($null -ne $property) {
            if ($property.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($property.Value)) {
                throw 'ProcessSnapshot VMS metadata is invalid.'
            }
            $paths += $property.Value
        }
    }

    $commandLineProperty = $ProcessRecord.PSObject.Properties['CommandLine']
    if ($null -ne $commandLineProperty) {
        if ($commandLineProperty.Value -isnot [string]) {
            throw 'ProcessSnapshot CommandLine is invalid.'
        }
        $match = [regex]::Match([string]$commandLineProperty.Value, '(?i)(?:--vms-path|--vms_path|-vms-path)(?:=|\s+)(?:"([^"]+)"|(\S+))')
        if ($match.Success) {
            if ($match.Groups[1].Success) {
                $paths += $match.Groups[1].Value
            }
            else {
                $paths += $match.Groups[2].Value
            }
        }
    }
    return @($paths)
}

function Find-MuMuInstallations {
    param(
        [string]$Edition = 'All',
        [string[]]$RegistryRoots = @(),
        [object[]]$ProcessSnapshot = @(),
        [string[]]$FallbackRoots = @()
    )

    if ($Edition -cnotin @('All', 'Global', 'Chinese')) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Edition must be All, Global, or Chinese.'
    }

    $candidates = New-Object 'System.Collections.Generic.List[object]'
    foreach ($registryRoot in @($RegistryRoots)) {
        foreach ($entry in @(Get-ToolkitUninstallEntries -Root $registryRoot)) {
            if ($null -eq $entry) {
                return Get-ToolkitResult -Status 'CriticalError' -Message 'Registry entry is invalid.'
            }
            $installLocationProperty = $entry.PSObject.Properties['InstallLocation']
            if ($null -eq $installLocationProperty -or $installLocationProperty.Value -isnot [string] -or
                [string]::IsNullOrWhiteSpace($installLocationProperty.Value)) {
                return Get-ToolkitResult -Status 'CriticalError' -Message 'Registry InstallLocation is invalid.'
            }
            $editionProperty = $entry.PSObject.Properties['Edition']
            $explicitEdition = ''
            if ($null -ne $editionProperty) {
                if ($editionProperty.Value -isnot [string]) {
                    return Get-ToolkitResult -Status 'CriticalError' -Message 'Registry Edition is invalid.'
                }
                $explicitEdition = $editionProperty.Value
            }
            $displayName = ''
            if ($null -ne $entry.PSObject.Properties['DisplayName'] -and $entry.DisplayName -is [string]) {
                $displayName = $entry.DisplayName
            }
            $vmsCandidate = ''
            $vmsCandidateProperty = $entry.PSObject.Properties['VmsPath']
            if ($null -ne $vmsCandidateProperty) {
                if ($vmsCandidateProperty.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($vmsCandidateProperty.Value)) {
                    return Get-ToolkitResult -Status 'CriticalError' -Message 'Registry VMS path is invalid.'
                }
                $vmsCandidate = $vmsCandidateProperty.Value
            }
            $installRoot = Get-ToolkitInstallRoot -Path $installLocationProperty.Value
            if ($null -eq $installRoot) {
                return Get-ToolkitResult -Status 'CriticalError' -Message 'Registry InstallLocation is unavailable.'
            }
            $managerPaths = @(Get-ToolkitManagerPaths -InstallRoot $installRoot)
            if ($managerPaths.Count -gt 1) {
                return Get-ToolkitResult -Status 'CriticalError' -Message 'Registry manager paths conflict.'
            }
            $managerPath = if ($managerPaths.Count -eq 1) { $managerPaths[0] } else { $null }
            if (-not (Test-ToolkitRegistryIdentity -Entry $entry -InstallRoot $installRoot -ManagerPath $managerPath)) {
                continue
            }
            try {
                $candidateEdition = Get-ToolkitEdition -Text ($displayName + ' ' + $installRoot) -ExplicitEdition $explicitEdition
            }
            catch {
                return Get-ToolkitResult -Status 'CriticalError' -Message 'Registry Edition is invalid or conflicting.'
            }
            try {
                $vmsPath = Get-ToolkitVmsPath -InstallRoot $installRoot -CandidatePath $vmsCandidate -Edition $candidateEdition
            }
            catch {
                return Get-ToolkitResult -Status 'CriticalError' -Message 'Registry VMS path is invalid or ambiguous.'
            }
            [void]$candidates.Add([pscustomobject]@{
                Edition = $candidateEdition
                InstallRoot = $installRoot
                VmsPath = $vmsPath
                ManagerPath = $managerPath
                Source = 'Registry'
            })
        }
    }

    foreach ($processRecord in @($ProcessSnapshot)) {
        if ($null -eq $processRecord) {
            continue
        }
        $executablePath = Get-ToolkitProcessExecutable -ProcessRecord $processRecord
        $executableIsManager = Test-ToolkitManagerName -Path $executablePath
        $managerProperty = $processRecord.PSObject.Properties['ManagerPath']
        $reportedManagerPath = $null
        $reportedManagerIsManager = $false
        if ($null -ne $managerProperty) {
            if ($managerProperty.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($managerProperty.Value)) {
                if ($executableIsManager) {
                    return Get-ToolkitResult -Status 'CriticalError' -Message 'ProcessSnapshot.ManagerPath is invalid.'
                }
                continue
            }
            $reportedManagerPath = ConvertTo-ToolkitFullPath -Path $managerProperty.Value
            $reportedManagerIsManager = Test-ToolkitManagerName -Path $reportedManagerPath
            if ($executableIsManager -and -not $reportedManagerIsManager) {
                return Get-ToolkitResult -Status 'CriticalError' -Message 'ProcessSnapshot.ManagerPath is not MuMuManager.exe.'
            }
        }
        if (-not $executableIsManager -and -not $reportedManagerIsManager) {
            continue
        }

        $rootProperty = $processRecord.PSObject.Properties['InstallRoot']
        if ($null -ne $rootProperty) {
            if ($rootProperty.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($rootProperty.Value)) {
                return Get-ToolkitResult -Status 'CriticalError' -Message 'ProcessSnapshot.InstallRoot is invalid.'
            }
            $installRoot = ConvertTo-ToolkitFullPath -Path $rootProperty.Value
            if ($null -eq $installRoot -or -not (Test-Path -LiteralPath $installRoot -PathType Container)) {
                return Get-ToolkitResult -Status 'CriticalError' -Message 'ProcessSnapshot.InstallRoot is unavailable.'
            }
        }
        else {
            $rootSource = if ($reportedManagerIsManager) { $reportedManagerPath } else { $executablePath }
            $installRoot = Get-ToolkitInstallRoot -Path $rootSource
            if ($null -eq $installRoot) {
                return Get-ToolkitResult -Status 'CriticalError' -Message 'ProcessSnapshot manager path is unavailable.'
            }
        }

        $managerPath = if ($reportedManagerIsManager) { $reportedManagerPath } else { $executablePath }
        $detectedManagerPaths = @(Get-ToolkitManagerPaths -InstallRoot $installRoot)
        if ($detectedManagerPaths.Count -gt 1) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'ProcessSnapshot manager paths conflict.'
        }
        if ($detectedManagerPaths.Count -eq 1) {
            if ($reportedManagerIsManager -and -not $managerPath.Equals($detectedManagerPaths[0], [StringComparison]::OrdinalIgnoreCase)) {
                return Get-ToolkitResult -Status 'CriticalError' -Message 'ProcessSnapshot manager paths conflict.'
            }
            $managerPath = $detectedManagerPaths[0]
        }
        if (-not (Test-ToolkitManagerFile -Path $managerPath -InstallRoot $installRoot)) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'ProcessSnapshot manager path is not a valid MuMu manager.'
        }
        if ($executableIsManager -and -not $managerPath.Equals($executablePath, [StringComparison]::OrdinalIgnoreCase)) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'ProcessSnapshot manager paths conflict.'
        }

        $editionProperty = $processRecord.PSObject.Properties['Edition']
        $explicitEdition = ''
        if ($null -ne $editionProperty) {
            if ($editionProperty.Value -isnot [string]) {
                return Get-ToolkitResult -Status 'CriticalError' -Message 'ProcessSnapshot.Edition is invalid.'
            }
            $explicitEdition = $editionProperty.Value
        }
        try {
            $candidateEdition = Get-ToolkitEdition -Text ($installRoot + ' ' + $executablePath) -ExplicitEdition $explicitEdition
        }
        catch {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'ProcessSnapshot.Edition is invalid or conflicting.'
        }

        try {
            $processVmsCandidates = @(Get-ToolkitProcessVmsPaths -ProcessRecord $processRecord)
        }
        catch {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'ProcessSnapshot VMS metadata is invalid.'
        }
        $normalizedProcessVmsPaths = @{}
        foreach ($processVmsCandidate in $processVmsCandidates) {
            $normalizedProcessVmsPath = Get-ToolkitMetadataPath -Path $processVmsCandidate -Root $installRoot
            if ($null -eq $normalizedProcessVmsPath) {
                return Get-ToolkitResult -Status 'CriticalError' -Message 'ProcessSnapshot VMS path is invalid.'
            }
            $normalizedProcessVmsPaths[$normalizedProcessVmsPath.ToUpperInvariant()] = $normalizedProcessVmsPath
        }
        if ($normalizedProcessVmsPaths.Count -gt 1) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'ProcessSnapshot VMS paths conflict.'
        }
        $processVmsPath = if ($normalizedProcessVmsPaths.Count -eq 1) { @($normalizedProcessVmsPaths.Values)[0] } else { '' }
        try {
            $vmsPath = Get-ToolkitVmsPath -InstallRoot $installRoot -CandidatePath $processVmsPath -Edition $candidateEdition
        }
        catch {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'ProcessSnapshot VMS path is invalid or ambiguous.'
        }
        [void]$candidates.Add([pscustomobject]@{
            Edition = $candidateEdition
            InstallRoot = $installRoot
            VmsPath = $vmsPath
            ManagerPath = $managerPath
            Source = 'Process'
        })
    }

    foreach ($fallbackRoot in @($FallbackRoots)) {
        $installRoot = Get-ToolkitInstallRoot -Path $fallbackRoot
        if ($null -eq $installRoot) {
            continue
        }
        $managerPaths = @(Get-ToolkitManagerPaths -InstallRoot $installRoot)
        if ($managerPaths.Count -gt 1) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'Fallback manager paths conflict.'
        }
        $managerPath = if ($managerPaths.Count -eq 1) { $managerPaths[0] } else { $null }
        try {
            $candidateEdition = Get-ToolkitEdition -Text $installRoot -ExplicitEdition ''
        }
        catch {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'Fallback Edition cannot be determined.'
        }
        try {
            $vmsPath = Get-ToolkitVmsPath -InstallRoot $installRoot -CandidatePath '' -Edition $candidateEdition
        }
        catch {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'Fallback VMS path is invalid or ambiguous.'
        }
        [void]$candidates.Add([pscustomobject]@{
            Edition = $candidateEdition
            InstallRoot = $installRoot
            VmsPath = $vmsPath
            ManagerPath = $managerPath
            Source = 'Fallback'
        })
    }

    $installations = @{}
    foreach ($candidate in $candidates) {
        $key = $candidate.InstallRoot.ToUpperInvariant()
        if (-not $installations.ContainsKey($key)) {
            $installations[$key] = $candidate
            continue
        }

        $existing = $installations[$key]
        if ($existing.Edition -cne $candidate.Edition) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'Installation editions conflict.'
        }
        if ($null -eq $existing.VmsPath -and $null -ne $candidate.VmsPath) {
            $existing.VmsPath = $candidate.VmsPath
        }
        elseif ($null -ne $existing.VmsPath -and $null -ne $candidate.VmsPath -and
            -not $existing.VmsPath.Equals($candidate.VmsPath, [StringComparison]::OrdinalIgnoreCase)) {
            if ($existing.Source -eq 'Registry' -and $candidate.Source -eq 'Process') {
                $existing.VmsPath = $candidate.VmsPath
            }
            elseif ($existing.Source -ne 'Process' -or $candidate.Source -eq 'Process') {
                return Get-ToolkitResult -Status 'CriticalError' -Message 'MuMu installation discovery is ambiguous.'
            }
        }
        if ($null -eq $existing.ManagerPath -and $null -ne $candidate.ManagerPath) {
            $existing.ManagerPath = $candidate.ManagerPath
        }
        elseif ($null -ne $existing.ManagerPath -and $null -ne $candidate.ManagerPath -and
            -not $existing.ManagerPath.Equals($candidate.ManagerPath, [StringComparison]::OrdinalIgnoreCase)) {
            if ($existing.Source -eq 'Registry' -and $candidate.Source -eq 'Process') {
                $existing.ManagerPath = $candidate.ManagerPath
            }
            else {
                return Get-ToolkitResult -Status 'CriticalError' -Message 'MuMu installation discovery is ambiguous.'
            }
        }
    }

    $result = @($installations.Values)
    if ($Edition -ne 'All') {
        $result = @($result | Where-Object { $_.Edition -eq $Edition })
    }
    return @($result | Sort-Object Edition, InstallRoot)
}

function ConvertTo-ToolkitBoolean {
    param([object]$Value)

    if ($Value -is [bool]) {
        return $Value
    }
    if ($Value -is [int] -or $Value -is [long]) {
        if ($Value -eq 0) {
            return $false
        }
        if ($Value -eq 1) {
            return $true
        }
        return $null
    }
    if ($Value -isnot [string]) {
        return $null
    }

    switch ([string]$Value) {
        'true' { return $true }
        'false' { return $false }
        '1' { return $true }
        '0' { return $false }
        default { return $null }
    }
}

function Get-ToolkitFirstProperty {
    param(
        [object]$InputObject,
        [string[]]$PropertyNames
    )

    foreach ($propertyName in $PropertyNames) {
        $property = $InputObject.PSObject.Properties[$propertyName]
        if ($null -ne $property) {
            return $property.Value
        }
    }
    return $null
}

function ConvertFrom-ToolkitJson {
    param(
        [string]$Text,
        [switch]$RequireInstance
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        throw 'Manager output is empty.'
    }
    try {
        $parsed = $Text | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw 'Manager output is invalid.'
    }
    if ($null -eq $parsed -or $parsed -is [string] -or $parsed -is [ValueType]) {
        throw 'Manager output is invalid.'
    }

    $errorCode = Get-ToolkitFirstProperty -InputObject $parsed -PropertyNames @('error_code', 'errcode')
    if ($null -ne $errorCode -and [string]$errorCode -notin @('0', 'False', 'false')) {
        throw 'Manager reported an error.'
    }

    if ($parsed -is [Array]) {
        $records = @($parsed)
    }
    else {
        $records = @()
        foreach ($propertyName in @('info', 'data', 'instances', 'records')) {
            $property = $parsed.PSObject.Properties[$propertyName]
            if ($null -ne $property -and $property.Value -is [Array]) {
                $records = @($property.Value)
                break
            }
        }
        if ($records.Count -eq 0 -and $null -ne $parsed.PSObject.Properties['index']) {
            $records = @($parsed)
        }
    }

    if ($records.Count -eq 0 -and -not $RequireInstance) {
        $records = @($parsed)
    }
    if ($RequireInstance -and ($records.Count -eq 0 -or @($records | Where-Object { $null -eq $_ -or $null -eq $_.PSObject.Properties['index'] }).Count -gt 0)) {
        throw 'Manager instance output is invalid.'
    }
    return @($records)
}

function ConvertTo-ToolkitAndroidVersion {
    param([object]$Value)

    if ($null -eq $Value) {
        return $null
    }
    $text = ([string]$Value).Trim()
    if ($text -match '^12(?:\.0)*$') {
        return '12.0'
    }
    if ($text -match '^15(?:\.0)*$') {
        return '15.0'
    }
    return $text
}

function Get-ToolkitInstanceAndroidVersion {
    param(
        [string]$VmsPath,
        [int]$Index
    )

    $roots = @(
        (Join-Path $VmsPath ([string]$Index)),
        (Join-Path (Join-Path $VmsPath 'vms') ([string]$Index)),
        (Join-Path $VmsPath ('vms' + [string]$Index))
    )
    if ([IO.Path]::GetFileName($VmsPath) -eq [string]$Index) {
        $roots = @($VmsPath) + $roots
    }

    foreach ($instanceRoot in $roots) {
        if (-not (Test-Path -LiteralPath $instanceRoot -PathType Container)) {
            continue
        }
        $files = @(
            (Join-Path $instanceRoot 'android_version.txt'),
            (Join-Path $instanceRoot 'android_version'),
            (Join-Path $instanceRoot 'system.prop'),
            (Join-Path $instanceRoot 'build.prop'),
            (Join-Path $instanceRoot 'config.json')
        )
        $configDirectory = Join-Path $instanceRoot 'configs'
        if (Test-Path -LiteralPath $configDirectory -PathType Container) {
            $files += @(Get-ChildItem -LiteralPath $configDirectory -Filter '*.json' -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
        }

        foreach ($metadataFile in $files) {
            if (-not (Test-Path -LiteralPath $metadataFile -PathType Leaf)) {
                continue
            }
            try {
                $text = [IO.File]::ReadAllText($metadataFile)
                $match = [regex]::Match($text, '(?im)^\s*(?:ro\.build\.version\.release|android_version|androidVersion|system_version|systemVersion)\s*[=:]\s*["'']?(\d+(?:\.\d+)*)')
                if ($match.Success) {
                    $version = ConvertTo-ToolkitAndroidVersion -Value $match.Groups[1].Value
                    if ($null -ne $version) {
                        return $version
                    }
                }
                if ([IO.Path]::GetExtension($metadataFile) -ieq '.json') {
                    $metadata = $text | ConvertFrom-Json -ErrorAction Stop
                    $value = Get-ToolkitFirstProperty -InputObject $metadata -PropertyNames @('android_version', 'androidVersion', 'system_version', 'systemVersion')
                    $version = ConvertTo-ToolkitAndroidVersion -Value $value
                    if ($null -ne $version) {
                        return $version
                    }
                }
            }
            catch {
            }
        }
    }
    return $null
}

function Get-MuMuRootSetting {
    param(
        [string]$ManagerPath,
        [int]$Index,
        [object]$InfoRecord
    )

    $reportedValue = Get-ToolkitFirstProperty -InputObject $InfoRecord -PropertyNames @('root_permission', 'rootPermission', 'root_setting', 'rootSetting')
    $hasReportedValue = $null -ne $InfoRecord.PSObject.Properties['root_permission'] -or
        $null -ne $InfoRecord.PSObject.Properties['rootPermission'] -or
        $null -ne $InfoRecord.PSObject.Properties['root_setting'] -or
        $null -ne $InfoRecord.PSObject.Properties['rootSetting']
    if ($hasReportedValue) {
        return ConvertTo-ToolkitBoolean -Value $reportedValue
    }

    $result = Invoke-CheckedProcess -FilePath $ManagerPath -ArgumentList @('setting', '-v', [string]$Index, '-k', 'root_permission')
    if ($null -eq $result -or $result.ExitCode -ne 0) {
        return $null
    }
    try {
        $records = @(ConvertFrom-ToolkitJson -Text $result.Text)
        if ($records.Count -ne 1) {
            return $null
        }
        $value = Get-ToolkitFirstProperty -InputObject $records[0] -PropertyNames @('root_permission', 'rootPermission', 'value')
        return ConvertTo-ToolkitBoolean -Value $value
    }
    catch {
        return $null
    }
}

function Get-MuMuInstances {
    param(
        [object]$Install,
        [string]$ManagerPath
    )

    if ($null -eq $Install -or $Install -is [Array]) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Install is invalid.'
    }
    $requiredInstallFields = @('Edition', 'InstallRoot', 'VmsPath', 'ManagerPath', 'Source')
    foreach ($fieldName in $requiredInstallFields) {
        $field = $Install.PSObject.Properties[$fieldName]
        if ($null -eq $field -or $field.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($field.Value)) {
            return Get-ToolkitResult -Status 'CriticalError' -Message "Install.$fieldName is required."
        }
    }
    $installEdition = [string]$Install.Edition
    $installSource = [string]$Install.Source
    if ($installEdition -cnotin @('Global', 'Chinese')) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Install.Edition is invalid.'
    }
    if ($installSource -cnotin @('Registry', 'Process', 'Fallback')) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Install.Source is invalid.'
    }

    $rootProperty = $Install.PSObject.Properties['InstallRoot']
    $vmsProperty = $Install.PSObject.Properties['VmsPath']
    $installManagerProperty = $Install.PSObject.Properties['ManagerPath']
    if ($null -eq $rootProperty -or $rootProperty.Value -isnot [string] -or
        $null -eq $vmsProperty -or $vmsProperty.Value -isnot [string] -or
        $null -eq $installManagerProperty -or $installManagerProperty.Value -isnot [string]) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Install path fields are invalid.'
    }

    $installRoot = ConvertTo-ToolkitFullPath -Path $rootProperty.Value
    $vmsPath = ConvertTo-ToolkitFullPath -Path $vmsProperty.Value
    if ($null -eq $installRoot -or -not (Test-Path -LiteralPath $installRoot -PathType Container) -or
        $null -eq $vmsPath -or -not (Test-Path -LiteralPath $vmsPath -PathType Container)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'MuMu installation paths are unavailable.'
    }
    $installManagerPath = ConvertTo-ToolkitFullPath -Path $installManagerProperty.Value
    if (-not (Test-ToolkitManagerFile -Path $installManagerPath -InstallRoot $installRoot)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Install.ManagerPath is invalid.'
    }

    $managerCandidate = $ManagerPath
    if ([string]::IsNullOrWhiteSpace($managerCandidate)) {
        $managerCandidate = $installManagerPath
    }
    $managerPath = ConvertTo-ToolkitFullPath -Path $managerCandidate
    if (-not (Test-ToolkitManagerFile -Path $managerPath -InstallRoot $installRoot)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'ManagerPath is not a valid MuMu manager.'
    }
    $detectedManagerPaths = @(Get-ToolkitManagerPaths -InstallRoot $installRoot)
    if ($detectedManagerPaths.Count -gt 1) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Manager paths conflict.'
    }
    if ($detectedManagerPaths.Count -eq 1 -and -not $managerPath.Equals($detectedManagerPaths[0], [StringComparison]::OrdinalIgnoreCase)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Manager paths conflict.'
    }

    $managerResult = Invoke-CheckedProcess -FilePath $managerPath -ArgumentList @('info', '-v', 'all')
    if ($null -eq $managerResult -or $managerResult.ExitCode -ne 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'MuMu manager query failed.'
    }
    try {
        $managerRecords = @(ConvertFrom-ToolkitJson -Text $managerResult.Text -RequireInstance)
    }
    catch {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Manager JSON is invalid.'
    }

    $indexedRecords = @()
    foreach ($managerRecord in $managerRecords) {
        $parsedIndex = 0
        $rawIndex = $managerRecord.index
        if ($rawIndex -isnot [string] -and $rawIndex -isnot [int] -and $rawIndex -isnot [long]) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'MuMu manager returned an invalid instance index.'
        }
        if (-not [int]::TryParse([string]$rawIndex, [ref]$parsedIndex) -or $parsedIndex -lt 0) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'MuMu manager returned an invalid instance index.'
        }
        $indexedRecords += [pscustomobject]@{ Index = $parsedIndex; Record = $managerRecord }
    }
    if (@($indexedRecords | Group-Object Index | Where-Object { $_.Count -ne 1 }).Count -gt 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'MuMu manager returned duplicate instance indexes.'
    }

    $instances = @()
    foreach ($indexedRecord in @($indexedRecords | Sort-Object Index)) {
        $managerRecord = $indexedRecord.Record
        $instanceVmsPath = $vmsPath
        $reportedVmsProperties = @($managerRecord.PSObject.Properties['vms_path'], $managerRecord.PSObject.Properties['vmsPath'])
        $reportedVmsProperties = @($reportedVmsProperties | Where-Object { $null -ne $_ })
        if ($reportedVmsProperties.Count -gt 0) {
            $reportedVmsPaths = @{}
            foreach ($reportedVmsProperty in $reportedVmsProperties) {
                if ($reportedVmsProperty.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($reportedVmsProperty.Value)) {
                    return Get-ToolkitResult -Status 'CriticalError' -Message 'Instance VMS path is invalid.'
                }
                $reportedVmsPath = Get-ToolkitMetadataPath -Path $reportedVmsProperty.Value -Root $installRoot
                if ($null -eq $reportedVmsPath -or -not (Test-Path -LiteralPath $reportedVmsPath -PathType Container)) {
                    return Get-ToolkitResult -Status 'CriticalError' -Message 'Instance VMS path is invalid.'
                }
                $reportedVmsPaths[$reportedVmsPath.ToUpperInvariant()] = $reportedVmsPath
            }
            if ($reportedVmsPaths.Count -ne 1) {
                return Get-ToolkitResult -Status 'CriticalError' -Message 'Instance VMS paths conflict.'
            }
            $instanceVmsPath = @($reportedVmsPaths.Values)[0]
        }

        $nameProperty = $managerRecord.PSObject.Properties['name']
        if ($null -eq $nameProperty -or $nameProperty.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($nameProperty.Value)) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'Instance name is invalid.'
        }

        $isMain = $null
        $mainProperty = $managerRecord.PSObject.Properties['is_main']
        if ($null -ne $mainProperty) {
            $isMain = ConvertTo-ToolkitBoolean -Value $mainProperty.Value
            if ($null -eq $isMain) {
                return Get-ToolkitResult -Status 'CriticalError' -Message 'is_main is invalid.'
            }
        }

        $running = $false
        $runningValue = Get-ToolkitFirstProperty -InputObject $managerRecord -PropertyNames @('is_process_started', 'is_android_started', 'running')
        if ($null -ne $managerRecord.PSObject.Properties['is_process_started'] -or
            $null -ne $managerRecord.PSObject.Properties['is_android_started'] -or
            $null -ne $managerRecord.PSObject.Properties['running']) {
            $running = ConvertTo-ToolkitBoolean -Value $runningValue
            if ($null -eq $running) {
                return Get-ToolkitResult -Status 'CriticalError' -Message 'Running state is invalid.'
            }
        }

        $androidVersionValue = $null
        foreach ($androidPropertyName in @('android_version', 'androidVersion', 'system_version', 'systemVersion')) {
            $androidProperty = $managerRecord.PSObject.Properties[$androidPropertyName]
            if ($null -ne $androidProperty) {
                $androidVersionValue = $androidProperty.Value
                break
            }
        }
        if ($null -ne $androidVersionValue -and $androidVersionValue -isnot [string] -and $androidVersionValue -isnot [int] -and $androidVersionValue -isnot [long]) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'AndroidVersion is invalid.'
        }
        $androidVersion = ConvertTo-ToolkitAndroidVersion -Value $androidVersionValue
        if ($null -eq $androidVersion) {
            $androidVersion = Get-ToolkitInstanceAndroidVersion -VmsPath $instanceVmsPath -Index $indexedRecord.Index
        }

        $eligible = $true
        $reason = $null
        if ($isMain -eq $true) {
            $eligible = $false
            $reason = 'Base instances cannot be selected.'
        }
        elseif ($null -eq $isMain) {
            $eligible = $false
            $reason = 'Base instance state is unknown.'
        }
        elseif ($androidVersion -notin @('12.0', '15.0')) {
            $eligible = $false
            $reason = 'Unsupported Android version.'
        }

        $hasReportedRootSetting = $null -ne $managerRecord.PSObject.Properties['root_permission'] -or
            $null -ne $managerRecord.PSObject.Properties['rootPermission'] -or
            $null -ne $managerRecord.PSObject.Properties['root_setting'] -or
            $null -ne $managerRecord.PSObject.Properties['rootSetting']
        $rootSetting = $null
        if ($hasReportedRootSetting -or $eligible) {
            $rootSetting = Get-MuMuRootSetting -ManagerPath $managerPath -Index $indexedRecord.Index -InfoRecord $managerRecord
        }
        if (($hasReportedRootSetting -or $eligible) -and $null -eq $rootSetting) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'root_permission is invalid.'
        }

        $instanceInstall = [pscustomobject]@{
            Edition = $installEdition
            InstallRoot = $installRoot
            VmsPath = $instanceVmsPath
            ManagerPath = $managerPath
            Source = $installSource
        }

        $instances += [pscustomobject]@{
            Index = [int]$indexedRecord.Index
            Name = [string]$nameProperty.Value
            AndroidVersion = $androidVersion
            Install = $instanceInstall
            Running = [bool]$running
            RootSetting = $rootSetting
            Eligible = $eligible
            IneligibleReason = $reason
        }
    }
    return @($instances)
}

function Resolve-SelectedInstance {
    param(
        [object[]]$Instances,
        [object]$Selection
    )

    $eligible = @()
    foreach ($instance in @($Instances)) {
        if ($null -eq $instance -or $instance -is [Array]) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'Instance record is invalid.'
        }
        $indexProperty = $instance.PSObject.Properties['Index']
        if ($null -eq $indexProperty -or
            ($indexProperty.Value -isnot [string] -and $indexProperty.Value -isnot [int] -and $indexProperty.Value -isnot [long])) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'Instance Index is invalid.'
        }
        $instanceIndex = 0
        if (-not [int]::TryParse([string]$indexProperty.Value, [ref]$instanceIndex) -or $instanceIndex -lt 0) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'Instance Index is invalid.'
        }
        $eligibleProperty = $instance.PSObject.Properties['Eligible']
        if ($null -eq $eligibleProperty) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'Instance Eligible is invalid.'
        }
        $isEligible = ConvertTo-ToolkitBoolean -Value $eligibleProperty.Value
        if ($null -eq $isEligible) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'Instance Eligible is invalid.'
        }
        if ($isEligible) {
            $eligible += $instance
        }
    }

    if ($null -ne $Selection) {
        $selectionIndexProperty = $null
        if ($null -ne $Selection.PSObject) {
            $selectionIndexProperty = $Selection.PSObject.Properties['Index']
        }
        if ($null -eq $selectionIndexProperty) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'Select exactly one eligible MuMu instance.'
        }
        if ($selectionIndexProperty.Value -isnot [string] -and $selectionIndexProperty.Value -isnot [int] -and $selectionIndexProperty.Value -isnot [long]) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'Selection Index is invalid.'
        }
        $selectedIndex = 0
        if (-not [int]::TryParse([string]$selectionIndexProperty.Value, [ref]$selectedIndex) -or $selectedIndex -lt 0) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'Selection Index is invalid.'
        }
        $matches = @($eligible | Where-Object { [int]$_.Index -eq $selectedIndex })
        if ($matches.Count -ne 1) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'Select exactly one eligible MuMu instance.'
        }
        return $matches[0]
    }

    if ($eligible.Count -ne 1) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Select exactly one eligible MuMu instance.'
    }
    return $eligible[0]
}
