[CmdletBinding()]
param(
    [ValidateSet('Manifest', 'All')]
    [string]$Suite = 'All'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$commonPath = Join-Path $repoRoot 'src\Common.ps1'
$manifestScriptPath = Join-Path $repoRoot 'src\Manifest.ps1'
$manifestPath = Join-Path $repoRoot 'src\Manifest.json'

if (Test-Path -LiteralPath $commonPath -PathType Leaf) {
    . $commonPath
}
if (Test-Path -LiteralPath $manifestScriptPath -PathType Leaf) {
    . $manifestScriptPath
}

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Equal {
    param(
        [object]$Expected,
        [object]$Actual,
        [string]$Message
    )
    if ($Expected -ne $Actual) {
        throw "$Message Expected [$Expected] but received [$Actual]."
    }
}

function Assert-Throws {
    param(
        [scriptblock]$Action,
        [string]$Message
    )
    $thrown = $false
    try {
        & $Action | Out-Null
    }
    catch {
        $thrown = $true
    }
    Assert-True $thrown $Message
}

function Invoke-ManifestTests {
    Assert-True (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'src/Manifest.json does not exist.'

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

    $manifest = Get-ToolkitManifest -Path $manifestPath
    Assert-True ($manifest.schemaVersion -eq 1) 'Manifest schema version is invalid.'
    Assert-Equal '6.8.0.0' $manifest.mumu.testedVersion 'Manifest MuMu version is invalid.'
    Assert-True (@($manifest.dependencies | Where-Object { $_.assetName -match '(?i)debug' }).Count -eq 0) 'Debug assets are not allowed.'
    Assert-Equal $expectedAssets.Count @($manifest.dependencies).Count 'Manifest dependency count is invalid.'

    for ($index = 0; $index -lt $expectedAssets.Count; $index++) {
        $expected = $expectedAssets[$index]
        $actual = @($manifest.dependencies)[$index]
        Assert-Equal $expected.Id $actual.id "Manifest ID is invalid at index $index."
        Assert-Equal $expected.Version $actual.version "Manifest version is invalid for $($expected.Id)."
        Assert-Equal $expected.AssetName $actual.assetName "Manifest asset name is invalid for $($expected.Id)."
        Assert-Equal $expected.Url $actual.url "Manifest URL is invalid for $($expected.Id)."
        Assert-Equal $expected.Size ([long]$actual.size) "Manifest size is invalid for $($expected.Id)."
        Assert-Equal $expected.Sha256 $actual.sha256 "Manifest hash is invalid for $($expected.Id)."
        Assert-True ($actual.sha256 -match '^[0-9a-f]{64}$') "Manifest hash format is invalid for $($expected.Id)."
    }

    $missingHashPath = Join-Path $testRoot 'missing-hash.json'
    $missingHashManifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $missingHashManifest.dependencies[0].PSObject.Properties.Remove('sha256')
    [IO.File]::WriteAllText($missingHashPath, ($missingHashManifest | ConvertTo-Json -Depth 10))
    Assert-Throws { Get-ToolkitManifest -Path $missingHashPath } 'Manifest with a missing hash was accepted.'

    $debugAssetPath = Join-Path $testRoot 'debug-asset.json'
    $debugAssetManifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $debugAssetManifest.dependencies[0].assetName = 'app-debug.apk'
    [IO.File]::WriteAllText($debugAssetPath, ($debugAssetManifest | ConvertTo-Json -Depth 10))
    Assert-Throws { Get-ToolkitManifest -Path $debugAssetPath } 'Manifest with a debug asset was accepted.'
}

function Invoke-CommonTests {
    Assert-True ($null -ne (Get-Command Get-ToolkitResult -CommandType Function -ErrorAction SilentlyContinue)) 'Get-ToolkitResult is unavailable.'
    foreach ($status in @('Success', 'AlreadyApplied', 'Warning', 'RecoverableError', 'CriticalError')) {
        $result = Get-ToolkitResult -Status $status -Message 'fixture' -Data @{ Value = 1 }
        Assert-Equal $status $result.Status "Result status is invalid for $status."
        Assert-Equal 'fixture' $result.Message "Result message is invalid for $status."
        Assert-Equal 1 $result.Data.Value "Result data is invalid for $status."
    }
    Assert-Throws { Get-ToolkitResult -Status 'Invalid' -Message 'fixture' } 'Invalid result status was accepted.'

    Assert-True ($null -ne (Get-Command Get-ToolkitLogPath -CommandType Function -ErrorAction SilentlyContinue)) 'Get-ToolkitLogPath is unavailable.'
    $logRoot = Join-Path $env:LOCALAPPDATA 'mumu-root-hide-toolkit\logs'
    $logPath = Get-ToolkitLogPath
    Assert-True ($logPath.StartsWith($logRoot, [StringComparison]::OrdinalIgnoreCase)) 'Log path is outside the per-user log directory.'

    Assert-True ($null -ne (Get-Command Invoke-CheckedProcess -CommandType Function -ErrorAction SilentlyContinue)) 'Invoke-CheckedProcess is unavailable.'
    $fakeRunner = {
        param($ActualFilePath, $ActualArgumentList)
        $parts = @($ActualFilePath) + @($ActualArgumentList)
        [pscustomobject]@{
            ExitCode = 5
            Text = $parts -join '|'
        }
    }
    $injected = Invoke-CheckedProcess -FilePath 'C:\Program Files\Fixture Tool.exe' -ArgumentList @('alpha', 'argument with spaces') -Runner $fakeRunner
    Assert-Equal 5 $injected.ExitCode 'Injected process exit code was not preserved.'
    Assert-Equal 'C:\Program Files\Fixture Tool.exe|alpha|argument with spaces' $injected.Text 'Process arguments were interpolated or changed.'

    $powershellPath = Join-Path $PSHOME 'powershell.exe'
    $native = Invoke-CheckedProcess -FilePath $powershellPath -ArgumentList @('-NoProfile', '-NonInteractive', '-Command', "[Console]::Out.WriteLine('fixture output')")
    Assert-Equal 0 $native.ExitCode 'Native fixture process did not succeed.'
    Assert-True ($native.Text -match 'fixture output') 'Native fixture output was not captured.'
    $nativeFailure = Invoke-CheckedProcess -FilePath $powershellPath -ArgumentList @('-NoProfile', '-NonInteractive', '-Command', 'exit 7')
    Assert-Equal 7 $nativeFailure.ExitCode 'Native fixture exit code was not captured.'

    Assert-True ($null -ne (Get-Command Get-VerifiedAsset -CommandType Function -ErrorAction SilentlyContinue)) 'Get-VerifiedAsset is unavailable.'
    $assetPath = Join-Path $testRoot 'verified-asset.bin'
    [IO.File]::WriteAllText($assetPath, 'verified asset fixture')
    $assetItem = Get-Item -LiteralPath $assetPath
    $assetHash = (Get-FileHash -LiteralPath $assetPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $assetManifest = [pscustomobject]@{
        dependencies = @(
            [pscustomobject]@{
                id = 'fixture'
                assetName = 'verified-asset.bin'
                size = [long]$assetItem.Length
                sha256 = $assetHash
            }
        )
    }

    $verified = Get-VerifiedAsset -Manifest $assetManifest -Id 'fixture' -CacheRoot $testRoot
    Assert-Equal 'Success' $verified.Status 'Verified fixture asset was rejected.'
    Assert-Equal $assetPath $verified.Data 'Verified fixture asset path is invalid.'

    $sizeMismatch = Get-VerifiedAsset -Manifest ([pscustomobject]@{ dependencies = @([pscustomobject]@{ id = 'fixture'; assetName = 'verified-asset.bin'; size = [long]($assetItem.Length + 1); sha256 = $assetHash }) }) -Id 'fixture' -CacheRoot $testRoot
    Assert-Equal 'CriticalError' $sizeMismatch.Status 'Asset size mismatch was accepted.'

    $hashMismatch = Get-VerifiedAsset -Manifest ([pscustomobject]@{ dependencies = @([pscustomobject]@{ id = 'fixture'; assetName = 'verified-asset.bin'; size = [long]$assetItem.Length; sha256 = ('0' * 64) }) }) -Id 'fixture' -CacheRoot $testRoot
    Assert-Equal 'CriticalError' $hashMismatch.Status 'Asset hash mismatch was accepted.'

    $missing = Get-VerifiedAsset -Manifest $assetManifest -Id 'missing' -CacheRoot $testRoot
    Assert-Equal 'CriticalError' $missing.Status 'Missing manifest asset was accepted.'

    $malformedManifest = [pscustomobject]@{
        dependencies = @([pscustomobject]@{ assetName = 'verified-asset.bin'; size = [long]$assetItem.Length; sha256 = $assetHash })
    }
    $malformed = Get-VerifiedAsset -Manifest $malformedManifest -Id 'fixture' -CacheRoot $testRoot
    Assert-Equal 'CriticalError' $malformed.Status 'Malformed manifest asset was accepted.'
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('mumu-toolkit-tests-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$exitCode = 0
try {
    switch ($Suite) {
        'Manifest' {
            Invoke-ManifestTests
            Invoke-CommonTests
        }
        'All' {
            Invoke-ManifestTests
            Invoke-CommonTests
        }
    }
}
catch {
    Write-Output "FAIL ${Suite}: $($_.Exception.Message)"
    $exitCode = 1
}
finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
if ($exitCode -eq 0) {
    Write-Output 'ALL TESTS PASSED'
}
exit $exitCode
