function Get-ToolkitResolvedPath {
    param([string]$Path)

    $currentPath = ConvertTo-ToolkitFullPath -Path $Path
    $seenPaths = @{}
    for ($depth = 0; $depth -lt 32 -and $null -ne $currentPath; $depth++) {
        $key = $currentPath.ToUpperInvariant()
        if ($seenPaths.ContainsKey($key)) {
            return $null
        }
        $seenPaths[$key] = $true
        try {
            $item = Get-Item -LiteralPath $currentPath -Force -ErrorAction Stop
        }
        catch {
            return $null
        }

        $targetProperty = $item.PSObject.Properties['Target']
        if ($null -eq $targetProperty) {
            return $currentPath
        }
        $target = @($targetProperty.Value)[0]
        if ($target -isnot [string] -or [string]::IsNullOrWhiteSpace($target)) {
            return $currentPath
        }
        $itemDirectory = [IO.Path]::GetDirectoryName($currentPath)
        $currentPath = Get-ToolkitMetadataPath -Path $target -Root $itemDirectory
    }
    return $null
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

    if ($ExplicitEdition -ceq 'Global' -or $ExplicitEdition -ceq 'Chinese') {
        return $ExplicitEdition
    }
    if ($Text -match '(?i)global') {
        return 'Global'
    }
    return 'Chinese'
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
    if ($directoryName -match '^(?i:shell|nx_main|nx_device)$') {
        return ConvertTo-ToolkitFullPath -Path ([IO.Path]::GetDirectoryName($directory))
    }
    return $directory
}

function Get-ToolkitManagerPath {
    param([string]$InstallRoot)

    $root = ConvertTo-ToolkitFullPath -Path $InstallRoot
    if ($null -eq $root -or -not (Test-Path -LiteralPath $root -PathType Container)) {
        return $null
    }

    foreach ($relativePath in @('MuMuManager.exe', 'shell\MuMuManager.exe', 'nx_main\MuMuManager.exe', 'nx_main\shell\MuMuManager.exe')) {
        $candidate = ConvertTo-ToolkitFullPath -Path (Join-Path $root $relativePath)
        if ($null -ne $candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $candidate
        }
    }
    return $null
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
        [string]$CandidatePath
    )

    $root = ConvertTo-ToolkitFullPath -Path $InstallRoot
    if ($null -eq $root) {
        return $null
    }

    $candidate = Get-ToolkitMetadataPath -Path $CandidatePath -Root $root
    if ($null -ne $candidate -and (Test-Path -LiteralPath $candidate -PathType Container)) {
        return $candidate
    }
    if ([IO.Path]::GetFileName($root) -match '^(?i:vms|vms.*)$' -and (Test-Path -LiteralPath $root -PathType Container)) {
        return $root
    }
    foreach ($relativePath in @('vms', 'MuMu\vms', 'MuMuPlayer\vms', 'nx_device\12.0\vms', 'nx_device\15.0\vms')) {
        $fallback = ConvertTo-ToolkitFullPath -Path (Join-Path $root $relativePath)
        if ($null -ne $fallback -and (Test-Path -LiteralPath $fallback -PathType Container)) {
            return $fallback
        }
    }

    $metadataPath = Join-Path $root 'nx_device\configs\install_config.json'
    if (Test-Path -LiteralPath $metadataPath -PathType Leaf) {
        try {
            $metadata = [IO.File]::ReadAllText($metadataPath) | ConvertFrom-Json -ErrorAction Stop
            foreach ($propertyName in @('vms_path', 'vmsPath', 'vms_root', 'vmsRoot')) {
                $property = $metadata.PSObject.Properties[$propertyName]
                if ($null -ne $property -and $property.Value -is [string]) {
                    $metadataPathValue = Get-ToolkitMetadataPath -Path $property.Value -Root $root
                    if ($null -ne $metadataPathValue -and (Test-Path -LiteralPath $metadataPathValue -PathType Container)) {
                        return $metadataPathValue
                    }
                }
            }
        }
        catch {
        }
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
            $entries += [pscustomobject]@{
                Root = $Root
                DisplayName = $displayName
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

function Get-ToolkitProcessVmsPath {
    param([object]$ProcessRecord)

    foreach ($propertyName in @('VmsPath', 'VMSPath')) {
        $property = $ProcessRecord.PSObject.Properties[$propertyName]
        if ($null -ne $property -and $property.Value -is [string] -and -not [string]::IsNullOrWhiteSpace($property.Value)) {
            return $property.Value
        }
    }

    $commandLineProperty = $ProcessRecord.PSObject.Properties['CommandLine']
    if ($null -eq $commandLineProperty -or $commandLineProperty.Value -isnot [string]) {
        return $null
    }
    $match = [regex]::Match([string]$commandLineProperty.Value, '(?i)(?:--vms-path|--vms_path|-vms-path)(?:=|\s+)(?:"([^"]+)"|(\S+))')
    if (-not $match.Success) {
        return $null
    }
    if ($match.Groups[1].Success) {
        return $match.Groups[1].Value
    }
    return $match.Groups[2].Value
}

function Find-MuMuInstallations {
    param(
        [ValidateSet('All', 'Global', 'Chinese')]
        [string]$Edition = 'All',
        [string[]]$RegistryRoots = @(),
        [object[]]$ProcessSnapshot = @(),
        [string[]]$FallbackRoots = @()
    )

    $candidates = New-Object 'System.Collections.Generic.List[object]'
    foreach ($registryRoot in @($RegistryRoots)) {
        foreach ($entry in @(Get-ToolkitUninstallEntries -Root $registryRoot)) {
            $installRoot = Get-ToolkitInstallRoot -Path $entry.InstallLocation
            if ($null -eq $installRoot) {
                continue
            }
            $managerPath = Get-ToolkitManagerPath -InstallRoot $installRoot
            $vmsPath = Get-ToolkitVmsPath -InstallRoot $installRoot -CandidatePath $entry.VmsPath
            $candidateEdition = Get-ToolkitEdition -Text ($entry.DisplayName + ' ' + $installRoot) -ExplicitEdition $entry.Edition
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
        if ($null -eq $executablePath -or -not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
            continue
        }

        $rootProperty = $processRecord.PSObject.Properties['InstallRoot']
        if ($null -ne $rootProperty -and $rootProperty.Value -is [string]) {
            $installRoot = ConvertTo-ToolkitFullPath -Path $rootProperty.Value
            if ($null -eq $installRoot -or -not (Test-Path -LiteralPath $installRoot -PathType Container) -or -not (Test-ToolkitPathWithinRoot -Path $executablePath -Root $installRoot)) {
                continue
            }
        }
        else {
            $installRoot = Get-ToolkitInstallRoot -Path $executablePath
            if ($null -eq $installRoot) {
                continue
            }
        }

        $managerPath = Get-ToolkitManagerPath -InstallRoot $installRoot
        $managerProperty = $processRecord.PSObject.Properties['ManagerPath']
        if ($null -ne $managerProperty -and $managerProperty.Value -is [string]) {
            $reportedManagerPath = ConvertTo-ToolkitFullPath -Path $managerProperty.Value
            if ($null -eq $reportedManagerPath -or -not (Test-Path -LiteralPath $reportedManagerPath -PathType Leaf) -or -not (Test-ToolkitPathWithinRoot -Path $reportedManagerPath -Root $installRoot)) {
                continue
            }
            $managerPath = $reportedManagerPath
        }
        $vmsPath = Get-ToolkitVmsPath -InstallRoot $installRoot -CandidatePath (Get-ToolkitProcessVmsPath -ProcessRecord $processRecord)
        $editionProperty = $processRecord.PSObject.Properties['Edition']
        $explicitEdition = ''
        if ($null -ne $editionProperty -and $editionProperty.Value -is [string]) {
            $explicitEdition = $editionProperty.Value
        }
        $candidateEdition = Get-ToolkitEdition -Text ($explicitEdition + ' ' + $executablePath) -ExplicitEdition $explicitEdition
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
        $managerPath = Get-ToolkitManagerPath -InstallRoot $installRoot
        $vmsPath = Get-ToolkitVmsPath -InstallRoot $installRoot
        [void]$candidates.Add([pscustomobject]@{
            Edition = Get-ToolkitEdition -Text $installRoot -ExplicitEdition ''
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

    if ($null -eq $Install) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'MuMu installation input is invalid.'
    }
    $rootProperty = $Install.PSObject.Properties['InstallRoot']
    $vmsProperty = $Install.PSObject.Properties['VmsPath']
    if ($null -eq $rootProperty -or $rootProperty.Value -isnot [string] -or
        $null -eq $vmsProperty -or $vmsProperty.Value -isnot [string]) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'MuMu installation input is invalid.'
    }

    $installRoot = ConvertTo-ToolkitFullPath -Path $rootProperty.Value
    $vmsPath = ConvertTo-ToolkitFullPath -Path $vmsProperty.Value
    if ($null -eq $installRoot -or -not (Test-Path -LiteralPath $installRoot -PathType Container) -or
        $null -eq $vmsPath -or -not (Test-Path -LiteralPath $vmsPath -PathType Container)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'MuMu installation paths are unavailable.'
    }

    $managerCandidate = $ManagerPath
    if ([string]::IsNullOrWhiteSpace($managerCandidate)) {
        $installManagerProperty = $Install.PSObject.Properties['ManagerPath']
        if ($null -ne $installManagerProperty -and $installManagerProperty.Value -is [string]) {
            $managerCandidate = $installManagerProperty.Value
        }
    }
    $managerPath = ConvertTo-ToolkitFullPath -Path $managerCandidate
    if ($null -eq $managerPath -or -not (Test-Path -LiteralPath $managerPath -PathType Leaf) -or
        -not (Test-ToolkitPathWithinRoot -Path $managerPath -Root $installRoot)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'MuMu manager path is unavailable.'
    }

    $managerResult = Invoke-CheckedProcess -FilePath $managerPath -ArgumentList @('info', '-v', 'all')
    if ($null -eq $managerResult -or $managerResult.ExitCode -ne 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'MuMu manager query failed.'
    }
    try {
        $managerRecords = @(ConvertFrom-ToolkitJson -Text $managerResult.Text -RequireInstance)
    }
    catch {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'MuMu manager query returned invalid instance metadata.'
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
        $reportedVmsProperty = $managerRecord.PSObject.Properties['vms_path']
        if ($null -eq $reportedVmsProperty) {
            $reportedVmsProperty = $managerRecord.PSObject.Properties['vmsPath']
        }
        if ($null -ne $reportedVmsProperty) {
            if ($reportedVmsProperty.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($reportedVmsProperty.Value)) {
                return Get-ToolkitResult -Status 'CriticalError' -Message 'MuMu manager returned stale instance metadata.'
            }
            $instanceVmsPath = Get-ToolkitMetadataPath -Path $reportedVmsProperty.Value -Root $installRoot
            if ($null -eq $instanceVmsPath -or -not (Test-Path -LiteralPath $instanceVmsPath -PathType Container)) {
                return Get-ToolkitResult -Status 'CriticalError' -Message 'MuMu manager returned stale instance metadata.'
            }
        }

        $nameProperty = $managerRecord.PSObject.Properties['name']
        if ($null -eq $nameProperty -or $nameProperty.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($nameProperty.Value)) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'MuMu manager returned invalid instance metadata.'
        }

        $isMain = $false
        $mainProperty = $managerRecord.PSObject.Properties['is_main']
        if ($null -ne $mainProperty) {
            $isMain = ConvertTo-ToolkitBoolean -Value $mainProperty.Value
            if ($null -eq $isMain) {
                return Get-ToolkitResult -Status 'CriticalError' -Message 'MuMu manager returned invalid instance metadata.'
            }
        }

        $running = $false
        $runningValue = Get-ToolkitFirstProperty -InputObject $managerRecord -PropertyNames @('is_process_started', 'is_android_started', 'running')
        if ($null -ne $managerRecord.PSObject.Properties['is_process_started'] -or
            $null -ne $managerRecord.PSObject.Properties['is_android_started'] -or
            $null -ne $managerRecord.PSObject.Properties['running']) {
            $running = ConvertTo-ToolkitBoolean -Value $runningValue
            if ($null -eq $running) {
                return Get-ToolkitResult -Status 'CriticalError' -Message 'MuMu manager returned invalid instance metadata.'
            }
        }

        $androidVersionValue = Get-ToolkitFirstProperty -InputObject $managerRecord -PropertyNames @('android_version', 'androidVersion', 'system_version', 'systemVersion')
        $androidVersion = ConvertTo-ToolkitAndroidVersion -Value $androidVersionValue
        if ($null -eq $androidVersion) {
            $androidVersion = Get-ToolkitInstanceAndroidVersion -VmsPath $instanceVmsPath -Index $indexedRecord.Index
        }

        $rootSetting = Get-MuMuRootSetting -ManagerPath $managerPath -Index $indexedRecord.Index -InfoRecord $managerRecord
        if ($null -eq $rootSetting) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'MuMu manager returned an invalid root setting.'
        }

        $instanceInstall = [pscustomobject]@{
            Edition = [string]$Install.Edition
            InstallRoot = $installRoot
            VmsPath = $instanceVmsPath
            ManagerPath = $managerPath
            Source = [string]$Install.Source
        }
        $eligible = $true
        $reason = $null
        if ($isMain) {
            $eligible = $false
            $reason = 'Base instances cannot be selected.'
        }
        elseif ($androidVersion -notin @('12.0', '15.0')) {
            $eligible = $false
            $reason = 'Unsupported Android version.'
        }

        $instances += [pscustomobject]@{
            Index = [int]$indexedRecord.Index
            Name = [string]$nameProperty.Value
            AndroidVersion = $androidVersion
            Install = $instanceInstall
            Running = [bool]$running
            RootSetting = [bool]$rootSetting
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

    $eligible = @($Instances | Where-Object {
        $null -ne $_ -and
        $null -ne $_.PSObject.Properties['Eligible'] -and
        (ConvertTo-ToolkitBoolean -Value $_.Eligible) -eq $true
    })

    if ($null -ne $Selection) {
        $selectionIndexProperty = $null
        if ($null -ne $Selection.PSObject) {
            $selectionIndexProperty = $Selection.PSObject.Properties['Index']
        }
        if ($null -eq $selectionIndexProperty) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'Select exactly one eligible MuMu instance.'
        }
        $selectedIndex = 0
        if (-not [int]::TryParse([string]$selectionIndexProperty.Value, [ref]$selectedIndex)) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'Select exactly one eligible MuMu instance.'
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
