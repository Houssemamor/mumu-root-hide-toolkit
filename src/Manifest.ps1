function Get-ToolkitManifest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Manifest file does not exist: $Path"
    }

    try {
        $manifest = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Manifest JSON is invalid: $($_.Exception.Message)"
    }

    if ($null -eq $manifest -or $manifest -is [Array]) {
        throw 'Manifest root must be an object.'
    }
    if ($null -eq $manifest.PSObject.Properties['schemaVersion'] -or
        (($manifest.schemaVersion -isnot [int] -and $manifest.schemaVersion -isnot [long]) -or
        $manifest.schemaVersion -ne 1)) {
        throw 'Manifest schema version is invalid.'
    }
    if ($null -eq $manifest.PSObject.Properties['mumu'] -or
        $manifest.mumu -is [Array] -or
        $null -eq $manifest.mumu.PSObject.Properties['testedVersion'] -or
        $manifest.mumu.testedVersion -isnot [string] -or
        $manifest.mumu.testedVersion -ne '6.8.0.0') {
        throw 'Manifest MuMu version is invalid.'
    }
    if ($null -eq $manifest.PSObject.Properties['dependencies']) {
        throw 'Manifest dependencies are missing.'
    }

    $expectedAssets = @(
        [pscustomobject]@{
            Id = 'kitsune'
            Version = 'v31.0-25fa2159'
            AssetName = 'app-release.apk'
            Url = 'https://github.com/Jordan231111/KitsuneMagisk/releases/download/v31.0-25fa2159/app-release.apk'
            Size = [long]12574128
            Sha256 = 'fac319d2de262fcfff1684e13e1a5c61c486d2a773a7a8ffcfdbfe6f763a7fd4'
        },
        [pscustomobject]@{
            Id = 'hma'
            Version = 'oss-161'
            AssetName = 'HMA-OSS-oss-161-release.apk'
            Url = 'https://github.com/frknkrc44/HMA-OSS/releases/download/oss-161/HMA-OSS-oss-161-release.apk'
            Size = [long]3094974
            Sha256 = '059f9fa4a2ccdef83f281d9434c852d29a0728d5e0e4e0f1e13d96fade6947cd'
        },
        [pscustomobject]@{
            Id = 'vector'
            Version = 'v2.0'
            AssetName = 'Vector-v2.0-3021-Release.zip'
            Url = 'https://github.com/JingMatrix/Vector/releases/download/v2.0/Vector-v2.0-3021-Release.zip'
            Size = [long]8434264
            Sha256 = 'd5e39669c02c2c699ab948eb8f3639b348eefb7749553224a9c62fa4a2f2dc18'
        },
        [pscustomobject]@{
            Id = 'neozygisk'
            Version = 'v2.3'
            AssetName = 'NeoZygisk-v2.3-275-release.zip'
            Url = 'https://github.com/JingMatrix/NeoZygisk/releases/download/v2.3/NeoZygisk-v2.3-275-release.zip'
            Size = [long]3208704
            Sha256 = '5c84df9f962c04855b3523a3a75022cf5e4f3ad3dfd94794ed92b43e911f3b9a'
        },
        [pscustomobject]@{
            Id = 'corepatch'
            Version = '4.9'
            AssetName = 'app-release.apk'
            Url = 'https://github.com/LSPosed/CorePatch/releases/download/4.9/app-release.apk'
            Size = [long]64416
            Sha256 = '1bdc47d5b48afffd37948a9f5638ae6a5f3d4d02ca01ae36143588284b979996'
        }
    )

    $dependencies = @($manifest.dependencies)
    if ($dependencies.Count -ne $expectedAssets.Count) {
        throw 'Manifest dependency count is invalid.'
    }

    for ($index = 0; $index -lt $dependencies.Count; $index++) {
        $dependency = $dependencies[$index]
        $expected = $expectedAssets[$index]
        if ($null -eq $dependency) {
            throw "Manifest dependency is invalid at index $index."
        }
        foreach ($propertyName in @('id', 'version', 'assetName', 'url', 'size', 'sha256')) {
            if ($null -eq $dependency.PSObject.Properties[$propertyName]) {
                throw "Manifest dependency $index is missing $propertyName."
            }
        }
        if ($dependency.size -isnot [int] -and $dependency.size -isnot [long]) {
            throw "Manifest dependency $index size is not an integer."
        }
        foreach ($propertyName in @('id', 'version', 'assetName', 'url', 'sha256')) {
            if ($dependency.PSObject.Properties[$propertyName].Value -isnot [string]) {
                throw "Manifest dependency $index $propertyName is not a string."
            }
        }
        if ([string]$dependency.id -match '(?i)debug' -or
            [string]$dependency.assetName -match '(?i)debug' -or
            [string]$dependency.url -match '(?i)debug') {
            throw "Manifest dependency $index is a debug asset."
        }
        if ([string]$dependency.url -notmatch '^https://github\.com/') {
            throw "Manifest dependency URL is not official: $($dependency.id)"
        }
        if ([string]$dependency.id -cne $expected.Id -or
            [string]$dependency.version -cne $expected.Version -or
            [string]$dependency.assetName -cne $expected.AssetName -or
            [string]$dependency.url -cne $expected.Url -or
            [long]$dependency.size -ne $expected.Size -or
            [string]$dependency.sha256 -cne $expected.Sha256) {
            throw "Manifest dependency does not match its release pin: $($dependency.id)"
        }
    }

    return $manifest
}

function Get-VerifiedAsset {
    param(
        [object]$Manifest,
        [string]$Id,
        [string]$CacheRoot
    )

    if ($null -eq $Manifest -or
        $null -eq $Manifest.PSObject.Properties['dependencies'] -or
        [string]::IsNullOrWhiteSpace($Id) -or
        $Id -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$' -or
        [string]::IsNullOrWhiteSpace($CacheRoot)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Asset verification input is invalid.'
    }

    $matches = @($Manifest.dependencies | Where-Object {
        $null -ne $_ -and
        $null -ne $_.PSObject.Properties['id'] -and
        [string]$_.id -eq $Id
    })
    if ($matches.Count -ne 1) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Asset is not uniquely defined in the manifest.'
    }

    $dependency = $matches[0]
    foreach ($propertyName in @('assetName', 'size', 'sha256')) {
        if ($null -eq $dependency.PSObject.Properties[$propertyName]) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'Asset verification input is invalid.'
        }
    }

    $assetName = [string]$dependency.assetName
    $expectedHash = [string]$dependency.sha256
    if (($dependency.size -isnot [int] -and $dependency.size -isnot [long]) -or
        [string]::IsNullOrWhiteSpace($assetName) -or
        $assetName -ne [IO.Path]::GetFileName($assetName) -or
        $expectedHash -notmatch '^[0-9a-fA-F]{64}$') {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Asset verification input is invalid.'
    }

    try {
        $cacheRootPath = [IO.Path]::GetFullPath($CacheRoot)
        $dependencyCacheRoot = Join-Path $cacheRootPath $Id
        $path = [IO.Path]::GetFullPath((Join-Path $dependencyCacheRoot $assetName))
        $rootSeparators = [char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        $cachePrefix = $cacheRootPath.TrimEnd($rootSeparators) + [IO.Path]::DirectorySeparatorChar
        if (-not $path.StartsWith($cachePrefix, [StringComparison]::OrdinalIgnoreCase)) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'Asset path is outside the cache root.'
        }
        $expectedSize = [long]$dependency.size
    }
    catch {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Asset verification input is invalid.'
    }

    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Asset is not available locally.'
    }

    try {
        $item = Get-Item -LiteralPath $path -ErrorAction Stop
    }
    catch {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Asset verification failed.'
    }

    if ($item.Length -ne $expectedSize) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Asset verification failed.'
    }

    try {
        $actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    }
    catch {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Asset verification failed.'
    }

    if ($actualHash -ne $expectedHash.ToLowerInvariant()) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Asset verification failed.'
    }

    return Get-ToolkitResult -Status 'Success' -Message 'Asset verified.' -Data $path
}

function Get-ToolkitAssetCacheRoot {
    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        throw 'LOCALAPPDATA is not available.'
    }

    return [IO.Path]::Combine(
        $env:LOCALAPPDATA,
        'mumu-root-hide-toolkit',
        'assets'
    )
}

function Invoke-ToolkitAssetDownload {
    param(
        [string]$Url,
        [string]$Path,
        [long]$MaximumBytes
    )

    if (-not ([Net.ServicePointManager]::SecurityProtocol -band [Net.SecurityProtocolType]::Tls12)) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }
    $webClient = New-Object Net.WebClient
    try {
        $webClient.Headers.Add('User-Agent', 'mumu-root-hide-toolkit')
        $webClient.DownloadFile($Url, $Path)
    }
    finally {
        $webClient.Dispose()
    }

    $length = 0
    try {
        $length = (New-Object IO.FileInfo($Path)).Length
    }
    catch {
        throw 'The downloaded asset is unavailable.'
    }
    if ([long]$length -gt $MaximumBytes) {
        throw 'The downloaded asset exceeded its pinned size.'
    }
}

function Save-ToolkitAsset {
    param(
        [object]$Manifest,
        [string]$Id,
        [string]$CacheRoot,
        [scriptblock]$Fetch = $null,
        [switch]$RequireCached
    )

    if ($null -eq $Manifest -or $null -eq $Manifest.PSObject.Properties['dependencies'] -or
        [string]::IsNullOrWhiteSpace($Id) -or [string]::IsNullOrWhiteSpace($CacheRoot)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Asset download input is invalid.'
    }

    $verified = Get-VerifiedAsset -Manifest $Manifest -Id $Id -CacheRoot $CacheRoot
    if ($verified.Status -eq 'Success') {
        return $verified
    }
    if ($verified.Message -cne 'Asset is not available locally.') {
        return $verified
    }
    if ($RequireCached) {
        return $verified
    }

    $matches = @($Manifest.dependencies | Where-Object {
        $null -ne $_ -and
        $null -ne $_.PSObject.Properties['id'] -and
        [string]$_.id -ceq $Id
    })
    if ($matches.Count -ne 1) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Asset is not uniquely defined in the manifest.'
    }
    $dependency = $matches[0]
    $urlProperty = $dependency.PSObject.Properties['url']
    $nameProperty = $dependency.PSObject.Properties['assetName']
    $sizeProperty = $dependency.PSObject.Properties['size']
    if ($null -eq $urlProperty -or $urlProperty.Value -isnot [string] -or
        $null -eq $nameProperty -or $nameProperty.Value -isnot [string] -or
        $null -eq $sizeProperty -or ($sizeProperty.Value -isnot [int] -and $sizeProperty.Value -isnot [long])) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Asset download input is invalid.'
    }
    $url = [string]$urlProperty.Value
    $assetName = [string]$nameProperty.Value
    $expectedSize = [long]$sizeProperty.Value
    if ($url -cnotmatch '^https://github\.com/[\x21-\x7e]+$' -or $expectedSize -le 0 -or
        $assetName -ne [IO.Path]::GetFileName($assetName)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Asset download input is invalid.'
    }

    try {
        $cacheRootPath = [IO.Path]::GetFullPath($CacheRoot)
        $directory = Join-Path $cacheRootPath $Id
        [void][IO.Directory]::CreateDirectory($directory)
        $path = [IO.Path]::GetFullPath((Join-Path $directory $assetName))
        $cachePrefix = $cacheRootPath.TrimEnd([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)) + [IO.Path]::DirectorySeparatorChar
        if (-not $path.StartsWith($cachePrefix, [StringComparison]::OrdinalIgnoreCase)) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'Asset path is outside the cache root.'
        }
    }
    catch {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The asset cache directory is unavailable.'
    }

    $partialPath = $path + '.' + [Guid]::NewGuid().ToString('N') + '.part'
    $downloaded = $false
    $failure = $null
    try {
        if ($null -ne $Fetch) {
            & $Fetch $url $partialPath
        }
        else {
            Invoke-ToolkitAssetDownload -Url $url -Path $partialPath -MaximumBytes $expectedSize
        }
        if (-not [IO.File]::Exists($partialPath)) {
            throw 'The download produced no asset.'
        }
        [IO.File]::Move($partialPath, $path)
        $downloaded = $true
    }
    catch {
        $failure = Protect-ToolkitText ([string]$_.Exception.Message)
    }
    finally {
        if ([IO.File]::Exists($partialPath)) {
            try {
                [IO.File]::Delete($partialPath)
            }
            catch {
            }
        }
    }
    if (-not $downloaded) {
        if ([string]::IsNullOrWhiteSpace($failure)) {
            $failure = 'The pinned asset could not be downloaded.'
        }
        return Get-ToolkitResult -Status 'CriticalError' -Message "The pinned asset could not be downloaded: $failure"
    }

    $verified = Get-VerifiedAsset -Manifest $Manifest -Id $Id -CacheRoot $CacheRoot
    if ($verified.Status -ne 'Success' -and $downloaded) {
        try {
            [IO.File]::Delete($path)
        }
        catch {
        }
    }
    return $verified
}
