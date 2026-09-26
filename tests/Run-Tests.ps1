[CmdletBinding()]
param(
    [ValidateSet('Manifest', 'Process', 'Result', 'Journal', 'Discovery', 'Safety', 'Ads', 'Root12', 'Root15', 'Verification', 'Concealment', 'All')]
    [string]$Suite = 'All'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$commonPath = Join-Path $repoRoot 'src\Common.ps1'
$manifestScriptPath = Join-Path $repoRoot 'src\Manifest.ps1'
$manifestPath = Join-Path $repoRoot 'src\Manifest.json'
$journalScriptPath = Join-Path $repoRoot 'src\Journal.ps1'
$discoveryScriptPath = Join-Path $repoRoot 'src\Discovery.ps1'
$elevationScriptPath = Join-Path $repoRoot 'src\Elevation.ps1'
$backupScriptPath = Join-Path $repoRoot 'src\Backup.ps1'
$adsScriptPath = Join-Path $repoRoot 'src\Ads.ps1'
$verificationScriptPath = Join-Path $repoRoot 'src\Verification.ps1'
$root12ScriptPath = Join-Path $repoRoot 'src\Root12.ps1'
$root15ScriptPath = Join-Path $repoRoot 'src\Root15.ps1'
$concealmentScriptPath = Join-Path $repoRoot 'src\Concealment.ps1'

if (Test-Path -LiteralPath $commonPath -PathType Leaf) {
    . $commonPath
}
if (Test-Path -LiteralPath $manifestScriptPath -PathType Leaf) {
    . $manifestScriptPath
}
if (Test-Path -LiteralPath $journalScriptPath -PathType Leaf) {
    . $journalScriptPath
}
if (Test-Path -LiteralPath $discoveryScriptPath -PathType Leaf) {
    . $discoveryScriptPath
}
if (Test-Path -LiteralPath $elevationScriptPath -PathType Leaf) {
    . $elevationScriptPath
}
if (Test-Path -LiteralPath $backupScriptPath -PathType Leaf) {
    . $backupScriptPath
}
if (Test-Path -LiteralPath $adsScriptPath -PathType Leaf) {
    . $adsScriptPath
}
if (Test-Path -LiteralPath $verificationScriptPath -PathType Leaf) {
    . $verificationScriptPath
}
if (Test-Path -LiteralPath $root12ScriptPath -PathType Leaf) {
    . $root12ScriptPath
}
if (Test-Path -LiteralPath $root15ScriptPath -PathType Leaf) {
    . $root15ScriptPath
}
if (Test-Path -LiteralPath $concealmentScriptPath -PathType Leaf) {
    . $concealmentScriptPath
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

    $stringSchemaPath = Join-Path $testRoot 'string-schema.json'
    $stringSchemaManifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $stringSchemaManifest.schemaVersion = '1'
    [IO.File]::WriteAllText($stringSchemaPath, ($stringSchemaManifest | ConvertTo-Json -Depth 10))
    Assert-Throws { Get-ToolkitManifest -Path $stringSchemaPath } 'Manifest string schemaVersion was accepted.'

    $stringSizePath = Join-Path $testRoot 'string-size.json'
    $stringSizeManifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $stringSizeManifest.dependencies[0].size = '12574128'
    [IO.File]::WriteAllText($stringSizePath, ($stringSizeManifest | ConvertTo-Json -Depth 10))
    Assert-Throws { Get-ToolkitManifest -Path $stringSizePath } 'Manifest string dependency size was accepted.'

    $arrayMumuPath = Join-Path $testRoot 'array-mumu.json'
    $arrayMumuManifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $arrayMumuManifest.mumu.testedVersion = @('6.8.0.0')
    [IO.File]::WriteAllText($arrayMumuPath, ($arrayMumuManifest | ConvertTo-Json -Depth 10))
    Assert-Throws { Get-ToolkitManifest -Path $arrayMumuPath } 'Manifest array MuMu version was accepted.'

    $numericVersionPath = Join-Path $testRoot 'numeric-version.json'
    $numericVersionManifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $numericVersionManifest.dependencies[4].version = 4.9
    [IO.File]::WriteAllText($numericVersionPath, ($numericVersionManifest | ConvertTo-Json -Depth 10))
    Assert-Throws { Get-ToolkitManifest -Path $numericVersionPath } 'Manifest numeric dependency version was accepted.'
}

function Invoke-ResultTests {
    Assert-True ($null -ne (Get-Command Get-ToolkitResult -CommandType Function -ErrorAction SilentlyContinue)) 'Get-ToolkitResult is unavailable.'
    $resultCommand = Get-Command Get-ToolkitResult -CommandType Function
    foreach ($parameterName in @('Status', 'Message')) {
        $parameterAttributes = @($resultCommand.Parameters[$parameterName].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] })
        Assert-Equal 1 $parameterAttributes.Count "Result parameter metadata is invalid for $parameterName."
        Assert-True ([bool]$parameterAttributes[0].Mandatory) "Result parameter is not required: $parameterName"
    }
    Assert-Throws { Get-ToolkitResult -Status '' -Message 'fixture' } 'Empty result status was accepted.'
    Assert-Throws { Get-ToolkitResult -Status 'Success' -Message '' } 'Empty result message was accepted.'
    Assert-Throws { Get-ToolkitResult -Status 'Success' -Message '   ' } 'Whitespace result message was accepted.'
    Assert-Throws { Get-ToolkitResult -Status 'success' -Message 'fixture' } 'Noncanonical result status was accepted.'
    foreach ($status in @('Success', 'AlreadyApplied', 'Warning', 'RecoverableError', 'CriticalError')) {
        $result = Get-ToolkitResult -Status $status -Message 'fixture' -Data @{ Value = 1 }
        Assert-Equal $status $result.Status "Result status is invalid for $status."
        Assert-Equal 'fixture' $result.Message "Result message is invalid for $status."
        Assert-Equal 1 $result.Data.Value "Result data is invalid for $status."
    }
    Assert-Throws { Get-ToolkitResult -Status 'Invalid' -Message 'fixture' } 'Invalid result status was accepted.'
}

function New-ProcessArgumentFixture {
    $path = Join-Path $testRoot 'argument-fixture.exe'
    $code = 'using System; using System.Text; public static class ArgumentFixture { public static int Main(string[] args) { string[] encoded = new string[args.Length]; for (int index = 0; index < args.Length; index++) { encoded[index] = Convert.ToBase64String(Encoding.UTF8.GetBytes(args[index])); } Console.WriteLine(args.Length + "|" + string.Join("|", encoded)); return 0; } }'
    Add-Type -TypeDefinition $code -OutputAssembly $path -OutputType ConsoleApplication | Out-Null
    return $path
}

function Invoke-ProcessTests {
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

    $argumentFixture = New-ProcessArgumentFixture
    $argumentVector = @(
        'plain',
        'argument with spaces',
        'embedded"double"quotes',
        'backslash\"quote"',
        '',
        'trailing\',
        'line' + [Environment]::NewLine + 'break',
        '$(Write-Output unsafe);&|<>'
    )
    $expectedArguments = @($argumentVector | ForEach-Object {
        [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($_))
    })
    $argumentResult = Invoke-CheckedProcess -FilePath $argumentFixture -ArgumentList $argumentVector
    $actualArguments = $argumentResult.Text.TrimEnd([char[]]"`r`n").Split([char]'|')
    Assert-Equal 0 $argumentResult.ExitCode 'Native argument fixture did not succeed.'
    Assert-Equal $argumentVector.Count $actualArguments[0] 'Native process received the wrong argument count.'
    for ($index = 0; $index -lt $argumentVector.Count; $index++) {
        Assert-Equal $expectedArguments[$index] $actualArguments[$index + 1] "Native process changed argument $index."
    }

    $powershellPath = Join-Path $PSHOME 'powershell.exe'
    $native = Invoke-CheckedProcess -FilePath $powershellPath -ArgumentList @('-NoProfile', '-NonInteractive', '-Command', "[Console]::Out.WriteLine('fixture output')")
    Assert-Equal 0 $native.ExitCode 'Native fixture process did not succeed.'
    Assert-True ($native.Text -match 'fixture output') 'Native fixture output was not captured.'
    $nativeFailure = Invoke-CheckedProcess -FilePath $powershellPath -ArgumentList @('-NoProfile', '-NonInteractive', '-Command', 'exit 7')
    Assert-Equal 7 $nativeFailure.ExitCode 'Native fixture exit code was not captured.'

    $global:LASTEXITCODE = 0
    $missingExecutablePath = Join-Path $testRoot 'missing-process.exe'
    try {
        $missingExecutable = Invoke-CheckedProcess -FilePath $missingExecutablePath -ArgumentList @('argument')
    }
    catch {
        $missingExecutable = [pscustomobject]@{ ExitCode = 0; Text = $_.Exception.Message }
    }
    Assert-True ($missingExecutable.ExitCode -ne 0) 'Missing executable launch returned success.'
    Assert-True ($missingExecutable.Text -match 'Process launch failed') 'Missing executable launch did not report a launch failure.'
}

function Invoke-AssetTests {
    Assert-True ($null -ne (Get-Command Get-VerifiedAsset -CommandType Function -ErrorAction SilentlyContinue)) 'Get-VerifiedAsset is unavailable.'

    $kitsuneDirectory = Join-Path $testRoot 'kitsune'
    $corePatchDirectory = Join-Path $testRoot 'corepatch'
    New-Item -ItemType Directory -Path $kitsuneDirectory | Out-Null
    New-Item -ItemType Directory -Path $corePatchDirectory | Out-Null
    $kitsunePath = Join-Path $kitsuneDirectory 'app-release.apk'
    $corePatchPath = Join-Path $corePatchDirectory 'app-release.apk'
    [IO.File]::WriteAllText($kitsunePath, 'kitsune fixture')
    [IO.File]::WriteAllText($corePatchPath, 'corepatch fixture')
    $kitsuneItem = Get-Item -LiteralPath $kitsunePath
    $corePatchItem = Get-Item -LiteralPath $corePatchPath
    $collisionManifest = [pscustomobject]@{
        dependencies = @(
            [pscustomobject]@{
                id = 'kitsune'
                assetName = 'app-release.apk'
                size = [long]$kitsuneItem.Length
                sha256 = (Get-FileHash -LiteralPath $kitsunePath -Algorithm SHA256).Hash.ToLowerInvariant()
            },
            [pscustomobject]@{
                id = 'corepatch'
                assetName = 'app-release.apk'
                size = [long]$corePatchItem.Length
                sha256 = (Get-FileHash -LiteralPath $corePatchPath -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        )
    }
    $kitsuneAsset = Get-VerifiedAsset -Manifest $collisionManifest -Id 'kitsune' -CacheRoot $testRoot
    $corePatchAsset = Get-VerifiedAsset -Manifest $collisionManifest -Id 'corepatch' -CacheRoot $testRoot
    Assert-Equal 'Success' $kitsuneAsset.Status 'Kitsune namespaced asset was rejected.'
    Assert-Equal 'Success' $corePatchAsset.Status 'CorePatch namespaced asset was rejected.'
    Assert-Equal $kitsunePath $kitsuneAsset.Data 'Kitsune namespaced asset path is invalid.'
    Assert-Equal $corePatchPath $corePatchAsset.Data 'CorePatch namespaced asset path is invalid.'

    $escapeCacheRoot = Join-Path $testRoot 'cache'
    New-Item -ItemType Directory -Path $escapeCacheRoot | Out-Null
    $outsideAssetPath = Join-Path $testRoot 'outside.bin'
    [IO.File]::WriteAllText($outsideAssetPath, 'outside fixture')
    $outsideAssetItem = Get-Item -LiteralPath $outsideAssetPath
    $outsideAssetHash = (Get-FileHash -LiteralPath $outsideAssetPath -Algorithm SHA256).Hash.ToLowerInvariant()
    foreach ($unsafeId in @('..', '.', 'child\asset', '..\outside', '../outside', 'C:\outside', 'C:outside')) {
        $unsafeManifest = [pscustomobject]@{
            dependencies = @(
                [pscustomobject]@{
                    id = $unsafeId
                    assetName = 'outside.bin'
                    size = [long]$outsideAssetItem.Length
                    sha256 = $outsideAssetHash
                }
            )
        }
        $unsafeResult = Get-VerifiedAsset -Manifest $unsafeManifest -Id $unsafeId -CacheRoot $escapeCacheRoot
        Assert-Equal 'CriticalError' $unsafeResult.Status "Unsafe asset ID was accepted: $unsafeId"
        Assert-True ($null -eq $unsafeResult.Data) "Unsafe asset ID returned a path: $unsafeId"
    }

    $assetDirectory = Join-Path $testRoot 'fixture'
    New-Item -ItemType Directory -Path $assetDirectory | Out-Null
    $assetPath = Join-Path $assetDirectory 'verified-asset.bin'
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

    $numericStringSizeManifest = [pscustomobject]@{
        dependencies = @(
            [pscustomobject]@{
                id = 'fixture'
                assetName = 'verified-asset.bin'
                size = [string]$assetItem.Length
                sha256 = $assetHash
            }
        )
    }
    $numericStringSize = Get-VerifiedAsset -Manifest $numericStringSizeManifest -Id 'fixture' -CacheRoot $testRoot
    Assert-Equal 'CriticalError' $numericStringSize.Status 'Verifier numeric string size was accepted.'
    Assert-True ($null -eq $numericStringSize.Data) 'Verifier numeric string size returned a path.'

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

function Invoke-JournalTests {
    foreach ($commandName in @('New-OperationJournal', 'Get-OperationJournal', 'Write-JournalEvent', 'Complete-OperationJournal', 'Fail-OperationJournal', 'Invoke-WithRetry', 'Install-OperationJournalFile')) {
        Assert-True ($null -ne (Get-Command $commandName -CommandType Function -ErrorAction SilentlyContinue)) "Journal command is unavailable: $commandName"
    }

    $journalRoot = Join-Path $testRoot 'journal root with spaces'
    New-Item -ItemType Directory -Path $journalRoot | Out-Null

    $atomicDirectory = Join-Path $journalRoot 'atomic'
    New-Item -ItemType Directory -Path $atomicDirectory | Out-Null
    $atomicDestination = Join-Path $atomicDirectory 'journal.json'
    $atomicTemporary = Join-Path $atomicDirectory 'journal.tmp'
    [IO.File]::WriteAllText($atomicDestination, 'old-journal')
    [IO.File]::WriteAllText($atomicTemporary, 'new-journal')
    $destinationLock = [IO.File]::Open($atomicDestination, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $replacementFailure = $null
    try {
        try {
            Install-OperationJournalFile -TemporaryPath $atomicTemporary -JournalPath $atomicDestination
        }
        catch {
            $replacementFailure = $_.Exception.Message
        }
    }
    finally {
        $destinationLock.Dispose()
    }
    Assert-True ($null -ne $replacementFailure -and $replacementFailure -match '^Journal atomic replacement failed: .+') 'Locked atomic replacement did not retain its native reason.'
    Assert-Equal 'old-journal' ([IO.File]::ReadAllText($atomicDestination)) 'Failed replacement did not preserve the old journal.'
    Assert-True (-not [IO.File]::Exists($atomicTemporary)) 'Failed replacement left its temporary file.'

    [IO.File]::WriteAllText($atomicTemporary, 'new-journal')
    $temporaryLock = [IO.File]::Open($atomicTemporary, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $cleanupFailure = $null
    try {
        try {
            Install-OperationJournalFile -TemporaryPath $atomicTemporary -JournalPath $atomicDestination
        }
        catch {
            $cleanupFailure = $_.Exception.Message
        }
    }
    finally {
        $temporaryLock.Dispose()
    }
    try {
        Assert-True ($null -ne $cleanupFailure -and $cleanupFailure -match '(?i)cleanup') 'Cleanup failure was not surfaced.'
        Assert-Equal 'old-journal' ([IO.File]::ReadAllText($atomicDestination)) 'Cleanup failure changed the old journal.'
        Assert-True ([IO.File]::Exists($atomicTemporary)) 'Cleanup-failure fixture did not retain its locked temporary file.'
    }
    finally {
        if ([IO.File]::Exists($atomicTemporary)) {
            [IO.File]::Delete($atomicTemporary)
        }
    }

    Add-Type -TypeDefinition 'public sealed class JournalSecretFixture { public string Password { get; set; } public string Token { get; set; } }'
    Add-Type -TypeDefinition 'public sealed class JournalSecretException : System.Exception { public string Password { get; set; } public string Token { get; set; } }'
    Add-Type -TypeDefinition 'public sealed class ghp_exception_type_secret : System.Exception { public string Fixture { get; set; } }'
    Add-Type -TypeDefinition 'public enum ghp_retry_type_secret { Fixture }'
    $fixtureInstance = New-Object JournalSecretFixture
    $fixtureInstance.Password = 'instance_password_secret'
    $fixtureInstance.Token = 'instance_token_secret'
    $exceptionFixture = New-Object JournalSecretException
    $exceptionFixture.Password = 'exception_password_secret'
    $exceptionFixture.Token = 'exception_token_secret'
    $protectedFixture = Protect-JournalValue $fixtureInstance
    Assert-Equal '[REDACTED]' $protectedFixture.Password 'Direct .NET Password property was not redacted.'
    Assert-Equal '[REDACTED]' $protectedFixture.Token 'Direct .NET Token property was not redacted.'
    try {
        throw 'base exception fixture'
    }
    catch {
        $baseException = $_.Exception
    }
    $protectedBaseException = Protect-JournalValue $baseException
    Assert-Equal 'System.Management.Automation.PSCustomObject' $protectedBaseException.GetType().FullName 'Arbitrary .NET object was not converted to a safe property record.'

    $realExceptionJournal = New-OperationJournal -Root $journalRoot -Operation 'Root12' -Instance $fixtureInstance
    try {
        [void][int]::Parse('token=real_exception_secret')
    }
    catch {
        $realException = $_.Exception
    }
    Assert-True ($realException.TargetSite -is [System.Reflection.MemberInfo]) 'Real .NET exception did not expose reflection metadata.'
    Write-JournalEvent -Journal $realExceptionJournal -Level 'Error' -Message 'method failure' -Data @{ Exception = $realException }
    $reopenedRealException = Get-OperationJournal -Path $realExceptionJournal.JournalPath
    $persistedException = @($reopenedRealException.Checkpoints)[0].Data.Exception
    Assert-Equal '[OMITTED]' $persistedException.TargetSite 'Reflection metadata was not omitted.'
    $realExceptionJson = [IO.File]::ReadAllText($realExceptionJournal.JournalPath)
    Assert-True ($realExceptionJson -notmatch 'real_exception_secret') 'Journal leaked raw .NET exception text.'
    Assert-True ($realExceptionJson -notmatch 'ErrorRecord|InvocationInfo|ReflectedType|ModuleVersionId|"TargetSite"\s*:\s*\{') 'Journal serialized the reflection graph.'
    Write-JournalEvent -Journal $reopenedRealException -Level 'Info' -Message 'still usable' -Data @{ Value = 1 }

    $typedException = New-Object ghp_exception_type_secret
    $typedExceptionJournal = New-OperationJournal -Root $journalRoot -Operation 'Root12' -Instance $fixtureInstance
    Write-JournalEvent -Journal $typedExceptionJournal -Level 'Error' -Message 'typed failure' -Data @{ Exception = $typedException }
    $typedExceptionJson = [IO.File]::ReadAllText($typedExceptionJournal.JournalPath)
    Assert-True ($typedExceptionJson -notmatch 'ghp_exception_type_secret') 'Journal leaked secret-shaped exception type metadata.'
    $reopenedTypedException = Get-OperationJournal -Path $typedExceptionJournal.JournalPath
    Assert-True ((@($reopenedTypedException.Checkpoints)[0].Data.Exception.Type) -notmatch 'ghp_exception_type_secret') 'Reopened exception type metadata was not sanitized.'
    Write-JournalEvent -Journal $reopenedTypedException -Level 'Info' -Message 'still usable' -Data @{ Value = 2 }

    $readOnlyDictionary = New-Object 'System.Collections.Generic.Dictionary[string,string]'
    $readOnlyDictionary['Password'] = 'readonly_password_secret'
    $readOnlyDictionary['Token'] = 'readonly_token_secret'
    $readOnlySecretData = [System.Collections.ObjectModel.ReadOnlyDictionary[string,string]]::new($readOnlyDictionary)
    $cmdletString = Join-Path (Join-Path $testRoot 'journal cmdlet') 'campaign.json'
    $protectedCmdletString = Protect-JournalValue $cmdletString
    Assert-Equal 'System.String' $protectedCmdletString.GetType().FullName 'A cmdlet-produced string was adapted as a PS object.'
    Assert-Equal $cmdletString $protectedCmdletString 'A cmdlet-produced string was not preserved by Protect-JournalValue.'
    Assert-True (Test-JournalValueRedacted $cmdletString) 'A cmdlet-produced string was not recognized as already redacted.'
    $cmdletStringJournal = New-OperationJournal -Root $journalRoot -Operation 'Root12' -Instance $fixtureInstance
    Write-JournalEvent -Journal $cmdletStringJournal -Level 'Info' -Message 'cmdlet path checkpoint' -Data ([pscustomobject]@{ Campaign = $cmdletString; Backup = $cmdletString })
    $reopenedCmdletString = Get-OperationJournal -Path $cmdletStringJournal.JournalPath
    $cmdletCheckpoint = @($reopenedCmdletString.Checkpoints)[-1]
    Assert-Equal 'System.String' $cmdletCheckpoint.Data.Campaign.GetType().FullName 'A cmdlet-produced string reloaded from a journal was adapted as a PS object.'
    Assert-Equal $cmdletString $cmdletCheckpoint.Data.Campaign 'A cmdlet-produced string was corrupted in the journal.'
    Assert-Equal $cmdletString $cmdletCheckpoint.Data.Backup 'A cmdlet-produced backup path was corrupted in the journal.'
    $cmdletStringJson = [IO.File]::ReadAllText($cmdletStringJournal.JournalPath)
    Assert-True ($cmdletStringJson -notmatch '"Length"') 'A cmdlet-produced string was journaled as a Length property.'
    $journal = New-OperationJournal -Root $journalRoot -Operation 'Root12' -Instance $fixtureInstance
    Assert-True (-not [string]::IsNullOrWhiteSpace($journal.Id)) 'Journal ID is empty.'
    Assert-Equal 'Running' $journal.State 'New journal state is invalid.'
    Assert-Equal 0 @($journal.Checkpoints).Count 'New journal contains checkpoints.'
    Assert-True (Test-Path -LiteralPath $journal.JournalPath -PathType Leaf) 'New journal was not persisted.'
    Assert-True ($journal.JournalPath.StartsWith($journalRoot, [StringComparison]::OrdinalIgnoreCase)) 'Journal path is outside the requested root.'

    $sensitiveValues = @(
        'ghp_example_secret',
        'password_secret',
        'secret_secret',
        'authorization_secret',
        'cookie_secret',
        'key_secret',
        'nested_secret',
        'result_password_secret',
        'instance_password_secret',
        'instance_token_secret',
        'readonly_password_secret',
        'readonly_token_secret',
        'exception_password_secret',
        'exception_token_secret',
        'event_token_secret',
        'event_password_secret',
        'event_secret_secret',
        'event_authorization_secret',
        'event_cookie_secret',
        'event_key_secret',
        'ghp_message_token_secret',
        'json_password_secret',
        'result_message_secret'
    )
    $eventData = @{
        Path = 'C:\Program Files\MuMu\config.json'
        Token = $sensitiveValues[0]
        password = $sensitiveValues[1]
        Secret = $sensitiveValues[2]
        Authorization = $sensitiveValues[3]
        Cookie = $sensitiveValues[4]
        ApiKey = $sensitiveValues[5]
        Nested = [pscustomobject]@{
            Items = @([pscustomobject]@{ Secret = $sensitiveValues[6] })
        }
        ReadOnly = $readOnlySecretData
        DotNetException = $exceptionFixture
    }
    $eventMessage = 'checkpoint ghp_message_token_secret token=event_token_secret password=event_password_secret secret=event_secret_secret Authorization=Bearer event_authorization_secret Cookie=event_cookie_secret Key=event_key_secret payload={"password":"json_password_secret"}'
    Write-JournalEvent -Journal $journal -Level 'Info' -Message $eventMessage -Data $eventData
    Fail-OperationJournal -Journal $journal -Result (Get-ToolkitResult -Status 'CriticalError' -Message 'hash mismatch password=result_message_secret' -Data @{ Password = $sensitiveValues[7] })

    $reopened = Get-OperationJournal -Path $journal.JournalPath
    Assert-Equal 'Failed' $reopened.State 'Failed journal state was not persisted.'
    Assert-True (@($reopened.Checkpoints).Count -ge 1) 'Journal checkpoint was lost.'
    Assert-Equal 'C:\Program Files\MuMu\config.json' @($reopened.Checkpoints)[0].Data.Path 'Journal path checkpoint was changed.'
    Assert-Equal $journal.JournalPath $reopened.JournalPath 'Reopened journal path is invalid.'
    $journalJson = [IO.File]::ReadAllText($journal.JournalPath)
    foreach ($sensitiveValue in $sensitiveValues) {
        Assert-True ($journalJson -notmatch [regex]::Escape($sensitiveValue)) "Journal leaked a sensitive value: $sensitiveValue"
    }
    Assert-True ($journalJson -match '\[REDACTED\]') 'Journal did not record a redaction marker.'
    $journalBytes = [IO.File]::ReadAllBytes($journal.JournalPath)
    $hasBom = $journalBytes.Length -ge 3 -and $journalBytes[0] -eq 0xef -and $journalBytes[1] -eq 0xbb -and $journalBytes[2] -eq 0xbf
    Assert-True (-not $hasBom) 'Journal JSON contains a UTF-8 byte order mark.'
    Assert-True ($null -ne ($journalJson | ConvertFrom-Json -ErrorAction Stop)) 'Journal JSON is invalid.'

    $completedJournal = New-OperationJournal -Root $journalRoot -Operation 'Root12' -Instance $fixtureInstance
    Complete-OperationJournal -Journal $completedJournal -Result (Get-ToolkitResult -Status 'Success' -Message 'completed')
    $reopenedCompleted = Get-OperationJournal -Path $completedJournal.JournalPath
    Assert-Equal 'Completed' $reopenedCompleted.State 'Completed journal state was not persisted.'
    Assert-Equal 'Success' $reopenedCompleted.Result.Status 'Completed journal result was not persisted.'

    $sanitizedOperationJournal = New-OperationJournal -Root $journalRoot -Operation 'Root12 token=new_operation_secret' -Instance $fixtureInstance
    Assert-Equal 'Root12 token=[REDACTED]' $sanitizedOperationJournal.Operation 'Journal operation was not sanitized at creation.'
    Assert-Equal 'Root12 token=[REDACTED]' (Get-OperationJournal -Path $sanitizedOperationJournal.JournalPath).Operation 'Sanitized journal operation changed after reopen.'
    Assert-True (([IO.File]::ReadAllText($sanitizedOperationJournal.JournalPath)) -notmatch 'new_operation_secret') 'Journal persisted raw operation text.'

    $tamperedJournal = New-OperationJournal -Root $journalRoot -Operation 'Root12' -Instance $fixtureInstance
    Write-JournalEvent -Journal $tamperedJournal -Level 'Info' -Message 'safe' -Data @{ Value = 1 }
    try {
        throw 'token=tampered_exception_secret'
    }
    catch {
        @($tamperedJournal.Checkpoints)[0].Data = $_.Exception
    }
    Write-JournalEvent -Journal $tamperedJournal -Level 'Info' -Message 'persist' -Data @{ Value = 2 }
    $tamperedJson = [IO.File]::ReadAllText($tamperedJournal.JournalPath)
    Assert-True ($tamperedJson -notmatch 'tampered_exception_secret') 'Tampered checkpoint persisted raw exception text.'

    $invalidCompleteJournal = New-OperationJournal -Root $journalRoot -Operation 'Root12' -Instance $fixtureInstance
    Assert-Throws { Complete-OperationJournal -Journal $invalidCompleteJournal -Result (Get-ToolkitResult -Status 'CriticalError' -Message 'invalid completion') } 'Completed journal accepted a failure result.'
    Assert-Equal 'Running' $invalidCompleteJournal.State 'Rejected completion changed journal state.'
    Assert-True ($null -eq $invalidCompleteJournal.Result) 'Rejected completion changed journal result.'
    Assert-Equal 'Running' (Get-OperationJournal -Path $invalidCompleteJournal.JournalPath).State 'Rejected completion changed persisted state.'
    $invalidFailureJournal = New-OperationJournal -Root $journalRoot -Operation 'Root12' -Instance $fixtureInstance
    Assert-Throws { Fail-OperationJournal -Journal $invalidFailureJournal -Result (Get-ToolkitResult -Status 'Success' -Message 'invalid failure') } 'Failed journal accepted a success result.'
    Assert-Equal 'Running' $invalidFailureJournal.State 'Rejected failure changed journal state.'
    Assert-True ($null -eq $invalidFailureJournal.Result) 'Rejected failure changed journal result.'

    $extraPropertyJournal = New-OperationJournal -Root $journalRoot -Operation 'Root12' -Instance $fixtureInstance
    $extraPropertyJournal | Add-Member -NotePropertyName Extra -NotePropertyValue 'invalid'
    Assert-Throws { Write-JournalEvent -Journal $extraPropertyJournal -Level 'Info' -Message 'invalid' -Data @{ Value = 1 } } 'In-memory journal with an extra root property was accepted.'

    $detailedFailureJournal = New-OperationJournal -Root $journalRoot -Operation 'Root12' -Instance $fixtureInstance
    $detailedFailureJournal.Instance = [scriptblock] { 'unsupported value' }
    $writeFailureMessage = $null
    try {
        Write-JournalEvent -Journal $detailedFailureJournal -Level 'Info' -Message 'invalid' -Data @{ Value = 1 }
    }
    catch {
        $writeFailureMessage = $_.Exception.Message
    }
    Assert-True ($writeFailureMessage -match '(?i)unsupported') 'Journal write failure discarded the underlying reason.'
    Assert-Equal 0 @($detailedFailureJournal.Checkpoints).Count 'Detailed write failure did not roll back checkpoints.'
    Assert-Equal 0 @((Get-OperationJournal -Path $detailedFailureJournal.JournalPath).Checkpoints).Count 'Detailed write failure changed persisted checkpoints.'

    $cleanupJournal = New-OperationJournal -Root $journalRoot -Operation 'Root15' -Instance $fixtureInstance
    $cleanupDirectory = [IO.Path]::GetDirectoryName($cleanupJournal.JournalPath)
    $filesBefore = @([IO.Directory]::GetFiles($cleanupDirectory))
    $journalLock = [IO.File]::Open($cleanupJournal.JournalPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        Assert-Throws { Write-JournalEvent -Journal $cleanupJournal -Level 'Info' -Message 'must fail' -Data @{ Value = 1 } } 'Locked journal write did not fail.'
    }
    finally {
        $journalLock.Dispose()
    }
    $filesAfter = @([IO.Directory]::GetFiles($cleanupDirectory))
    Assert-Equal $filesBefore.Count $filesAfter.Count 'Failed journal write left a temporary file.'
    $unchangedJournal = Get-OperationJournal -Path $cleanupJournal.JournalPath
    Assert-Equal 'Running' $unchangedJournal.State 'Failed journal write changed persisted state.'
    Assert-Equal 0 @($unchangedJournal.Checkpoints).Count 'Failed journal write changed persisted checkpoints.'
    Assert-Equal 'Running' $cleanupJournal.State 'Failed journal write changed in-memory state.'
    Assert-Equal 0 @($cleanupJournal.Checkpoints).Count 'Failed journal write changed in-memory checkpoints.'

    $stateRollbackJournal = New-OperationJournal -Root $journalRoot -Operation 'Root15' -Instance $fixtureInstance
    $stateRollbackLock = [IO.File]::Open($stateRollbackJournal.JournalPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        Assert-Throws { Fail-OperationJournal -Journal $stateRollbackJournal -Result (Get-ToolkitResult -Status 'CriticalError' -Message 'rollback') } 'Locked final-state write did not fail.'
    }
    finally {
        $stateRollbackLock.Dispose()
    }
    Assert-Equal 'Running' $stateRollbackJournal.State 'Failed final-state write did not restore in-memory state.'
    Assert-True ($null -eq $stateRollbackJournal.Result) 'Failed final-state write did not restore in-memory result.'
    Assert-Equal 'Running' (Get-OperationJournal -Path $stateRollbackJournal.JournalPath).State 'Failed final-state write changed persisted state.'

    $malformedPath = Join-Path $journalRoot 'malformed.json'
    [IO.File]::WriteAllText($malformedPath, '{not-json')
    Assert-Throws { Get-OperationJournal -Path $malformedPath } 'Malformed journal JSON was accepted.'
    $arrayJournalPath = Join-Path $journalRoot 'array.json'
    [IO.File]::WriteAllText($arrayJournalPath, '[]')
    Assert-Throws { Get-OperationJournal -Path $arrayJournalPath } 'Array journal root was accepted.'
    $duplicatePropertyPath = Join-Path $journalRoot 'duplicate-property.json'
    $duplicateId = [Guid]::NewGuid().ToString('N')
    $duplicateStartedAt = [DateTime]::UtcNow.ToString('o')
    $duplicateJson = '{"SchemaVersion":1,"Id":"' + $duplicateId + '","StartedAt":"' + $duplicateStartedAt + '","Operation":"Root12","Instance":{"Token":"[REDACTED]","Token":"[REDACTED]"},"State":"Running","Checkpoints":[],"Result":null}'
    [IO.File]::WriteAllText($duplicatePropertyPath, $duplicateJson)
    Assert-Throws { Get-OperationJournal -Path $duplicatePropertyPath } 'Duplicate JSON property was accepted.'
    $caseVariantDuplicatePath = Join-Path $journalRoot 'case-variant-duplicate.json'
    $caseVariantStartedAt = [DateTime]::UtcNow.ToString('o')
    $caseVariantDuplicateJson = '{"SchemaVersion":1,"Id":"' + [Guid]::NewGuid().ToString('N') + '","StartedAt":"' + $caseVariantStartedAt + '","Operation":"Root12","Instance":{"Token":"[REDACTED]","token":"[REDACTED]"},"State":"Running","Checkpoints":[],"Result":null}'
    [IO.File]::WriteAllText($caseVariantDuplicatePath, $caseVariantDuplicateJson)
    Assert-Throws { Get-OperationJournal -Path $caseVariantDuplicatePath } 'Case-variant duplicate JSON property was accepted.'

    $unknownCheckpointPath = Join-Path $journalRoot 'unknown-checkpoint.json'
    $unknownCheckpoint = [ordered]@{
        SchemaVersion = 1
        Id = [Guid]::NewGuid().ToString('N')
        StartedAt = [DateTime]::UtcNow.ToString('o')
        Operation = 'Root12'
        Instance = $null
        State = 'Running'
        Checkpoints = @([ordered]@{
            Timestamp = [DateTime]::UtcNow.ToString('o')
            Level = 'Info'
            Message = 'checkpoint'
            Data = $null
            Extra = 'invalid'
        })
        Result = $null
    }
    [IO.File]::WriteAllText($unknownCheckpointPath, ($unknownCheckpoint | ConvertTo-Json -Depth 10))
    Assert-Throws { Get-OperationJournal -Path $unknownCheckpointPath } 'Checkpoint with an unknown property was accepted.'
    $unknownResultPath = Join-Path $journalRoot 'unknown-result.json'
    $unknownResult = [ordered]@{
        SchemaVersion = 1
        Id = [Guid]::NewGuid().ToString('N')
        StartedAt = [DateTime]::UtcNow.ToString('o')
        Operation = 'Root12'
        Instance = $null
        State = 'Completed'
        Checkpoints = @()
        Result = [ordered]@{ Status = 'Success'; Message = 'completed'; Data = $null; Extra = 'invalid' }
    }
    [IO.File]::WriteAllText($unknownResultPath, ($unknownResult | ConvertTo-Json -Depth 10))
    Assert-Throws { Get-OperationJournal -Path $unknownResultPath } 'Result with an unknown property was accepted.'
    $unsupportedScriptJournal = New-OperationJournal -Root $journalRoot -Operation 'Root12' -Instance $fixtureInstance
    Assert-Throws { Write-JournalEvent -Journal $unsupportedScriptJournal -Level 'Info' -Message 'unsupported' -Data ([scriptblock] { 'value' }) } 'Scriptblock journal data was accepted.'
    $unsupportedStreamJournal = New-OperationJournal -Root $journalRoot -Operation 'Root12' -Instance $fixtureInstance
    Assert-Throws { Write-JournalEvent -Journal $unsupportedStreamJournal -Level 'Info' -Message 'unsupported' -Data ([IO.MemoryStream]::new()) } 'Stream journal data was accepted.'

    $newJournalRecord = {
        param(
            [string]$State = 'Running',
            [object]$Result = $null,
            [object]$Checkpoints = @()
        )

        [pscustomobject]@{
            SchemaVersion = 1
            Id = [Guid]::NewGuid().ToString('N')
            StartedAt = [DateTime]::UtcNow.ToString('o')
            Operation = 'Root12'
            Instance = $null
            State = $State
            Checkpoints = $Checkpoints
            Result = $Result
        }
    }
    $writeJournalRecord = {
        param(
            [string]$Name,
            [object]$Record
        )

        $path = Join-Path $journalRoot ($Name + '.json')
        $utf8 = [Text.UTF8Encoding]::new($false)
        [IO.File]::WriteAllText($path, ($Record | ConvertTo-Json -Depth 20), $utf8)
        return $path
    }
    $assertInvalidRecord = {
        param(
            [string]$Name,
            [object]$Record,
            [string]$Reason
        )

        $path = & $writeJournalRecord $Name $Record
        Assert-Throws { Get-OperationJournal -Path $path } $Reason
    }

    $record = & $newJournalRecord
    $record.SchemaVersion = 2
    & $assertInvalidRecord 'wrong-schema-version' $record 'Wrong schema version was accepted.'
    $record = & $newJournalRecord
    $record.SchemaVersion = '1'
    & $assertInvalidRecord 'string-schema-version' $record 'String schema version was accepted.'
    $record = & $newJournalRecord
    $record | Add-Member -NotePropertyName Extra -NotePropertyValue 'invalid'
    & $assertInvalidRecord 'extra-root-property' $record 'Extra root property was accepted.'
    $record = & $newJournalRecord
    [void]$record.PSObject.Properties.Remove('Operation')
    & $assertInvalidRecord 'missing-root-property' $record 'Missing root property was accepted.'
    $record = & $newJournalRecord
    $record.Id = 'invalid-id'
    & $assertInvalidRecord 'invalid-id' $record 'Invalid journal ID was accepted.'
    $record = & $newJournalRecord
    $record.StartedAt = 'not-a-timestamp'
    & $assertInvalidRecord 'invalid-timestamp' $record 'Invalid journal timestamp was accepted.'
    $record = & $newJournalRecord
    $record.Operation = 'token=loaded_operation_secret'
    & $assertInvalidRecord 'unsanitized-operation' $record 'Unsanitized persisted operation was accepted.'
    $record = & $newJournalRecord
    $record.Checkpoints = [pscustomobject]@{ Value = 'invalid' }
    & $assertInvalidRecord 'invalid-checkpoints' $record 'Non-array checkpoints were accepted.'
    $record = & $newJournalRecord
    $record.Checkpoints = @([pscustomobject]@{ Timestamp = [DateTime]::UtcNow.ToString('o'); Level = 'Info'; Data = $null })
    & $assertInvalidRecord 'missing-checkpoint-property' $record 'Checkpoint missing Message was accepted.'
    $record = & $newJournalRecord 'Running' $null @([pscustomobject]@{ Timestamp = 'invalid'; Level = 'Info'; Message = 'checkpoint'; Data = $null })
    & $assertInvalidRecord 'invalid-checkpoint-timestamp' $record 'Invalid checkpoint timestamp was accepted.'
    $record = & $newJournalRecord 'Running' $null @([pscustomobject]@{ Timestamp = [DateTime]::UtcNow.ToString('o'); Level = 1; Message = 'checkpoint'; Data = $null })
    & $assertInvalidRecord 'invalid-checkpoint-level' $record 'Invalid checkpoint level was accepted.'
    $record = & $newJournalRecord 'Failed' 'invalid'
    & $assertInvalidRecord 'invalid-result-type' $record 'Non-object result was accepted.'
    $record = & $newJournalRecord 'Completed' ([pscustomobject]@{ Status = 'Success'; Message = 'completed' })
    & $assertInvalidRecord 'missing-result-property' $record 'Result missing Data was accepted.'
    $record = & $newJournalRecord 'Completed' ([pscustomobject]@{ Status = 'Invalid'; Message = 'completed'; Data = $null })
    & $assertInvalidRecord 'invalid-result-status' $record 'Noncanonical result status was accepted.'
    $record = & $newJournalRecord 'Completed' ([pscustomobject]@{ Status = 'Success'; Message = '   '; Data = $null })
    & $assertInvalidRecord 'invalid-result-message' $record 'Empty result message was accepted.'
    $record = & $newJournalRecord 'Running' (Get-ToolkitResult -Status 'Success' -Message 'mismatch')
    & $assertInvalidRecord 'running-result-mismatch' $record 'Running journal with a result was accepted.'
    $record = & $newJournalRecord 'Completed' (Get-ToolkitResult -Status 'CriticalError' -Message 'mismatch')
    & $assertInvalidRecord 'completed-result-mismatch' $record 'Completed journal with a failure result was accepted.'
    $record = & $newJournalRecord 'Failed' (Get-ToolkitResult -Status 'Success' -Message 'mismatch')
    & $assertInvalidRecord 'failed-result-mismatch' $record 'Failed journal with a success result was accepted.'
    $record = & $newJournalRecord 'Running' $null @([pscustomobject]@{
        Timestamp = [DateTime]::UtcNow.ToString('o')
        Level = 'Info'
        Message = 'password=loaded_checkpoint_secret'
        Data = $null
    })
    & $assertInvalidRecord 'checkpoint-free-text-secret' $record 'Unsanitized checkpoint message was accepted.'
    $record = & $newJournalRecord 'Completed' (Get-ToolkitResult -Status 'Success' -Message 'token=loaded_result_secret')
    & $assertInvalidRecord 'result-free-text-secret' $record 'Unsanitized result message was accepted.'

    $validJson = (& $newJournalRecord | ConvertTo-Json -Depth 10)
    $wrongCaseJson = $validJson.Replace('"SchemaVersion"', '"schemaVersion"')
    $wrongCasePath = Join-Path $journalRoot 'wrong-case-root-property.json'
    [IO.File]::WriteAllText($wrongCasePath, $wrongCaseJson)
    Assert-Throws { Get-OperationJournal -Path $wrongCasePath } 'Incorrect root property casing was accepted.'

    $invalidStatePath = Join-Path $journalRoot 'invalid-state.json'
    $invalidState = [ordered]@{
        SchemaVersion = 1
        Id = [Guid]::NewGuid().ToString('N')
        StartedAt = [DateTime]::UtcNow.ToString('o')
        Operation = 'Root12'
        Instance = $null
        State = 'Trusted'
        Checkpoints = @()
        Result = $null
    }
    [IO.File]::WriteAllText($invalidStatePath, ($invalidState | ConvertTo-Json -Depth 10))
    Assert-Throws { Get-OperationJournal -Path $invalidStatePath } 'Unrecognized journal state was accepted.'
    $unredactedPath = Join-Path $journalRoot 'unredacted.json'
    $unredacted = [ordered]@{
        SchemaVersion = 1
        Id = [Guid]::NewGuid().ToString('N')
        StartedAt = [DateTime]::UtcNow.ToString('o')
        Operation = 'Root12'
        Instance = @{ Token = 'untrusted_plain_secret' }
        State = 'Failed'
        Checkpoints = @()
        Result = [pscustomobject]@{ Status = 'CriticalError'; Message = 'failed'; Data = $null }
    }
    [IO.File]::WriteAllText($unredactedPath, ($unredacted | ConvertTo-Json -Depth 10))
    Assert-Throws { Get-OperationJournal -Path $unredactedPath } 'Unredacted journal data was accepted.'

    $retryState = @{ Count = 0 }
    $recoveringOperation = {
        $retryState.Count++
        if ($retryState.Count -lt 3) {
            throw 'transient failure'
        }
        Get-ToolkitResult -Status 'Success' -Message 'recovered'
    }.GetNewClosure()
    $recovered = Invoke-WithRetry -Operation $recoveringOperation -Attempts 3 -DelaySeconds 0
    Assert-Equal 3 $retryState.Count 'Retry attempt count is invalid.'
    Assert-Equal 'Success' $recovered.Status 'Recoverable operation did not return success.'
    Assert-Equal 'recovered' $recovered.Message 'Recoverable operation result was changed.'

    $nullOutput = Invoke-WithRetry -Operation { $null } -Attempts 1 -DelaySeconds 0
    Assert-Equal 'RecoverableError' $nullOutput.Status 'Retry accepted no output.'
    Assert-True (-not [string]::IsNullOrWhiteSpace($nullOutput.Message)) 'Retry no-output error has no message.'
    $arrayOutput = Invoke-WithRetry -Operation {
        Write-Output -NoEnumerate -InputObject @(
            [pscustomobject]@{ Status = 'Success'; Message = 'one'; Data = $null },
            [pscustomobject]@{ Status = 'Success'; Message = 'two'; Data = $null }
        )
    } -Attempts 1 -DelaySeconds 0
    Assert-Equal 'RecoverableError' $arrayOutput.Status 'Retry accepted an array result.'
    $typedRetryOutput = Invoke-WithRetry -Operation { [ghp_retry_type_secret]::Fixture } -Attempts 1 -DelaySeconds 0
    Assert-Equal 'RecoverableError' $typedRetryOutput.Status 'Retry accepted a non-toolkit enum result.'
    Assert-True ($typedRetryOutput.Message -notmatch 'ghp_retry_type_secret') 'Retry diagnostic leaked secret-shaped runtime type metadata.'
    Assert-True ($typedRetryOutput.Message -match '\[REDACTED\]') 'Retry diagnostic did not sanitize runtime type metadata.'
    $wrongStatusOutput = Invoke-WithRetry -Operation {
        [pscustomobject]@{ Status = 'Invalid'; Message = 'wrong status'; Data = $null }
    } -Attempts 1 -DelaySeconds 0
    Assert-Equal 'RecoverableError' $wrongStatusOutput.Status 'Retry accepted a noncanonical result status.'
    Assert-True ($wrongStatusOutput.Message -match '(?i)status') 'Retry diagnostic did not identify the invalid status.'
    Assert-True ($wrongStatusOutput.Message -notmatch '(?i)properties') 'Retry diagnostic mislabeled an invalid status as a property-count mismatch.'
    $emptyMessageOutput = Invoke-WithRetry -Operation {
        [pscustomobject]@{ Status = 'Success'; Message = '   '; Data = $null }
    } -Attempts 1 -DelaySeconds 0
    Assert-Equal 'RecoverableError' $emptyMessageOutput.Status 'Retry accepted an empty result message.'
    Assert-True ($emptyMessageOutput.Message -match '(?i)message') 'Retry diagnostic did not identify the invalid message.'
    Assert-True ($emptyMessageOutput.Message -notmatch '(?i)properties') 'Retry diagnostic mislabeled an invalid message as a property-count mismatch.'
    $extraPropertyOutput = Invoke-WithRetry -Operation {
        [pscustomobject]@{ Status = 'Success'; Message = 'valid'; Data = $null; Extra = 'invalid' }
    } -Attempts 1 -DelaySeconds 0
    Assert-Equal 'RecoverableError' $extraPropertyOutput.Status 'Retry accepted an unknown result property.'
    Assert-True ($extraPropertyOutput.Message -match '(?i)one object.*4 properties') 'Retry message did not describe the extra-property output shape.'
    $wrongCaseOutput = Invoke-WithRetry -Operation {
        [pscustomobject]@{ status = 'Success'; Message = 'valid'; Data = $null }
    } -Attempts 1 -DelaySeconds 0
    Assert-Equal 'RecoverableError' $wrongCaseOutput.Status 'Retry accepted incorrect result property casing.'
    Assert-True ($wrongCaseOutput.Message -match '(?i)property names|casing') 'Retry diagnostic did not identify invalid property names or casing.'
    Assert-True ($wrongCaseOutput.Message -notmatch '(?i)properties') 'Retry diagnostic mislabeled invalid casing as a property-count mismatch.'

    $exhaustedState = @{ Count = 0 }
    $failingOperation = {
        $exhaustedState.Count++
        throw 'bounded token=exception_message_secret'
    }.GetNewClosure()
    $exhausted = Invoke-WithRetry -Operation $failingOperation -Attempts 3 -DelaySeconds 0
    Assert-Equal 3 $exhaustedState.Count 'Retry exceeded its attempt bound.'
    Assert-Equal 'RecoverableError' $exhausted.Status 'Retry exhaustion did not return RecoverableError.'
    Assert-Equal 'bounded token=[REDACTED]' $exhausted.Message 'Retry persisted the raw exception message.'
    Assert-Throws { Invoke-WithRetry -Operation { 1 } -Attempts 0 -DelaySeconds 0 } 'Zero retry attempts were accepted.'
    Assert-Throws { Invoke-WithRetry -Operation { 1 } -Attempts 11 -DelaySeconds 0 } 'Excessive retry attempts were accepted.'
    Assert-Throws { Invoke-WithRetry -Operation { 1 } -Attempts 1 -DelaySeconds -1 } 'Negative retry delay was accepted.'
    Assert-Throws { Invoke-WithRetry -Operation { 1 } -Attempts 1 -DelaySeconds 61 } 'Excessive retry delay was accepted.'
}

function New-DiscoveryInstallFixture {
    param(
        [string]$InstallRoot,
        [string]$VmsPath
    )

    $root = [IO.Path]::GetFullPath($InstallRoot)
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    $managerPath = Join-Path $root 'shell\MuMuManager.exe'
    $managerDirectory = Split-Path -Parent $managerPath
    New-Item -ItemType Directory -Path $managerDirectory -Force | Out-Null
    [IO.File]::WriteAllText($managerPath, 'discovery fixture')
    $vms = [IO.Path]::GetFullPath($VmsPath)
    New-Item -ItemType Directory -Path $vms -Force | Out-Null
    [pscustomobject]@{
        InstallRoot = $root
        VmsPath = $vms
        ManagerPath = [IO.Path]::GetFullPath($managerPath)
    }
}

function New-DiscoveryManagerFixture {
    param(
        [string]$InstallRoot,
        [string]$InfoJson,
        [string]$SettingJson = '{"root_permission":"false"}'
    )

    if ($null -eq ('DiscoveryManagerFixture' -as [type])) {
        $script:discoveryManagerTemplatePath = Join-Path $testRoot 'discovery-manager-template.exe'
        $code = 'using System; using System.IO; using System.Text; public static class DiscoveryManagerFixture { public static int Main(string[] args) { string root = AppDomain.CurrentDomain.BaseDirectory; File.AppendAllText(Path.Combine(root, "args.log"), String.Join("|", args) + Environment.NewLine, new UTF8Encoding(false)); string name = args.Length > 0 && args[0] == "setting" ? "setting.json" : "info.json"; Console.Write(File.ReadAllText(Path.Combine(root, name))); return 0; } }'
        Add-Type -TypeDefinition $code -OutputAssembly $script:discoveryManagerTemplatePath -OutputType ConsoleApplication | Out-Null
    }

    $managerDirectory = Join-Path ([IO.Path]::GetFullPath($InstallRoot)) 'shell'
    New-Item -ItemType Directory -Path $managerDirectory -Force | Out-Null
    $managerPath = Join-Path $managerDirectory 'MuMuManager.exe'
    [IO.File]::Copy($script:discoveryManagerTemplatePath, $managerPath, $true)
    $utf8 = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText((Join-Path $managerDirectory 'info.json'), $InfoJson, $utf8)
    [IO.File]::WriteAllText((Join-Path $managerDirectory 'setting.json'), $SettingJson, $utf8)
    return [IO.Path]::GetFullPath($managerPath)
}

function Get-DiscoveryResultStatus {
    param([object]$Result)

    if ($null -ne $Result -and $null -ne $Result.PSObject.Properties['Status']) {
        return [string]$Result.Status
    }
    return 'Accepted'
}

function Invoke-DiscoveryCall {
    param([scriptblock]$Action)

    try {
        return & $Action
    }
    catch {
        return [pscustomobject]@{
            Status = 'Thrown'
            Message = $_.Exception.Message
        }
    }
}

function Assert-DiscoveryInstallRejected {
    param(
        [object]$Install,
        [string]$ManagerPath,
        [string]$ArgumentsPath,
        [string]$Label
    )

    if ([IO.File]::Exists($ArgumentsPath)) {
        [IO.File]::Delete($ArgumentsPath)
    }
    $result = Invoke-DiscoveryCall { Get-MuMuInstances -Install $Install -ManagerPath $ManagerPath }
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $result) "Malformed Install field was accepted: $Label"
    Assert-True (-not [IO.File]::Exists($ArgumentsPath)) "Malformed Install field reached the process runner: $Label"
}

function Invoke-DiscoveryManagerCase {
    param(
        [string]$Name,
        [string]$InfoJson,
        [string]$SettingJson = '{"root_permission":"false"}',
        [string]$Edition = 'Global'
    )

    $root = Join-Path $testRoot ('discovery negative\' + $Name)
    $vms = Join-Path $root 'vms'
    New-Item -ItemType Directory -Path $vms -Force | Out-Null
    $manager = New-DiscoveryManagerFixture -InstallRoot $root -InfoJson $InfoJson -SettingJson $SettingJson
    $install = [pscustomobject]@{
        Edition = $Edition
        InstallRoot = [IO.Path]::GetFullPath($root)
        VmsPath = [IO.Path]::GetFullPath($vms)
        ManagerPath = $manager
        Source = 'Process'
    }
    $result = @(Get-MuMuInstances -Install $install -ManagerPath $manager)
    [pscustomobject]@{
        Result = $result
        Install = $install
        ManagerPath = $manager
        ArgumentsPath = Join-Path (Split-Path -Parent $manager) 'args.log'
    }
}

function Invoke-DiscoveryTests {
    foreach ($commandName in @('Find-MuMuInstallations', 'Get-MuMuInstances', 'Resolve-SelectedInstance')) {
        Assert-True ($null -ne (Get-Command $commandName -CommandType Function -ErrorAction SilentlyContinue)) "Discovery command is unavailable: $commandName"
    }

    $discoveryRoot = Join-Path $testRoot 'discovery fixtures'
    New-Item -ItemType Directory -Path $discoveryRoot | Out-Null
    $previousAppData = $env:APPDATA
    $fixtureProfileRoot = Join-Path $testRoot 'fixture profile'
    $env:APPDATA = Join-Path $fixtureProfileRoot 'empty'
    New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
    $globalRoot = Join-Path $discoveryRoot 'Odd Path\MuMu Global'
    $globalVms = Join-Path $globalRoot 'vms'
    $globalFixture = New-DiscoveryInstallFixture -InstallRoot $globalRoot -VmsPath $globalVms
    $registryChineseRoot = Join-Path $discoveryRoot 'Registry Chinese\MuMuPlayer'
    $registryChineseVms = Join-Path $registryChineseRoot 'vms'
    $registryChineseFixture = New-DiscoveryInstallFixture -InstallRoot $registryChineseRoot -VmsPath $registryChineseVms
    $unrelatedRegistryRoot = Join-Path $discoveryRoot 'Unrelated Product'
    $unrelatedRegistryVms = Join-Path $unrelatedRegistryRoot 'vms'
    New-Item -ItemType Directory -Path $unrelatedRegistryRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $unrelatedRegistryVms -Force | Out-Null
    $unrelatedRegistryManager = Join-Path $unrelatedRegistryRoot 'helper.exe'
    [IO.File]::WriteAllText($unrelatedRegistryManager, 'unrelated registry fixture')
    $missingManagerRegistryRoot = Join-Path $discoveryRoot 'Missing Manager\MuMu Global'
    $missingManagerRegistryVms = Join-Path $missingManagerRegistryRoot 'vms'
    New-Item -ItemType Directory -Path $missingManagerRegistryVms -Force | Out-Null
    $missingEditionRegistryRoot = Join-Path $discoveryRoot 'Missing Edition\MuMu Global'
    $missingEditionRegistryVms = Join-Path $missingEditionRegistryRoot 'vms'
    $missingEditionRegistryManager = Join-Path $missingEditionRegistryRoot 'shell\MuMuManager.exe'
    New-Item -ItemType Directory -Path $missingEditionRegistryVms -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path -Parent $missingEditionRegistryManager) -Force | Out-Null
    [IO.File]::WriteAllText($missingEditionRegistryManager, 'missing edition registry fixture')
    $genericRegistryRoot = Join-Path $discoveryRoot 'Generic Registry\MuMu'
    $genericRegistryVms = Join-Path $genericRegistryRoot 'vms'
    $genericRegistryManager = Join-Path $genericRegistryRoot 'shell\MuMuManager.exe'
    New-Item -ItemType Directory -Path $genericRegistryVms -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path -Parent $genericRegistryManager) -Force | Out-Null
    [IO.File]::WriteAllText($genericRegistryManager, 'generic registry manager fixture')
    $genericProcessRoot = Join-Path $discoveryRoot 'Generic Process\MuMu'
    $genericProcessVms = Join-Path $genericProcessRoot 'vms'
    $genericProcessManager = Join-Path $genericProcessRoot 'shell\MuMuManager.exe'
    New-Item -ItemType Directory -Path $genericProcessVms -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path -Parent $genericProcessManager) -Force | Out-Null
    [IO.File]::WriteAllText($genericProcessManager, 'generic process manager fixture')
    $genericMissingRoot = Join-Path $discoveryRoot 'Generic Missing\MuMu'
    $genericMissingVms = Join-Path $genericMissingRoot 'vms'
    $genericMissingPlayer = Join-Path $genericMissingRoot 'shell\MuMuPlayer.exe'
    New-Item -ItemType Directory -Path $genericMissingVms -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path -Parent $genericMissingPlayer) -Force | Out-Null
    [IO.File]::WriteAllText($genericMissingPlayer, 'generic missing manager fixture')
    $globalRelocatedVms = Join-Path $discoveryRoot 'relocated global\vms'
    New-Item -ItemType Directory -Path $globalRelocatedVms -Force | Out-Null
    $globalRelocatedManager = Join-Path $globalRoot 'nx_main\MuMuManager.exe'
    New-Item -ItemType Directory -Path (Split-Path -Parent $globalRelocatedManager) -Force | Out-Null
    [IO.File]::WriteAllText($globalRelocatedManager, 'relocated discovery fixture')
    [IO.File]::Delete($globalFixture.ManagerPath)
    $unicodeFolder = ([string][char]0x5B89) + ([string][char]0x88C5)
    $processRoot = Join-Path $discoveryRoot (Join-Path 'Relocated' (Join-Path $unicodeFolder 'MuMu'))
    $processVmsTarget = Join-Path $discoveryRoot 'user data\MuMuPlayer\vms'
    $processFixture = New-DiscoveryInstallFixture -InstallRoot $processRoot -VmsPath $processVmsTarget
    $processVmsLink = Join-Path $discoveryRoot 'vms-junction'
    New-Item -ItemType Junction -Path $processVmsLink -Target $processFixture.VmsPath | Out-Null
    $fallbackRoot = Join-Path $discoveryRoot 'Fallback\MuMuPlayer'
    $fallbackVms = Join-Path $fallbackRoot 'nx_device\12.0\vms'
    $fallbackFixture = New-DiscoveryInstallFixture -InstallRoot $fallbackRoot -VmsPath $fallbackVms
    $outsideRoot = Join-Path $discoveryRoot 'outside'
    $outsideFixture = New-DiscoveryInstallFixture -InstallRoot $outsideRoot -VmsPath (Join-Path $outsideRoot 'vms')
    $staleVmsPath = Join-Path $globalRoot 'missing-vms'
    $registryInstallLocation = Join-Path $globalFixture.InstallRoot 'stale\..'
    $script:discoveryRegistryEntries = @(
        [pscustomobject]@{
            Root = 'FixtureRegistry:\Global'
            DisplayName = 'MuMu Global'
            Publisher = 'NetEase'
            InstallLocation = $registryInstallLocation
            Edition = 'Global'
            VmsPath = $globalFixture.VmsPath
        },
        [pscustomobject]@{
            Root = 'FixtureRegistry:\Chinese'
            DisplayName = 'MuMuPlayer'
            Publisher = 'NetEase'
            InstallLocation = $registryChineseFixture.InstallRoot
            Edition = 'Chinese'
            VmsPath = $registryChineseVms
        },
        [pscustomobject]@{
            Root = 'FixtureRegistry:\Unrelated'
            DisplayName = 'Unrelated Product'
            Publisher = 'Unrelated Publisher'
            InstallLocation = $unrelatedRegistryRoot
            Edition = ''
            VmsPath = $unrelatedRegistryVms
        },
        [pscustomobject]@{
            Root = 'FixtureRegistry:\EditionConflict'
            DisplayName = 'MuMu Global'
            Publisher = 'NetEase'
            InstallLocation = $globalFixture.InstallRoot
            Edition = 'Chinese'
            VmsPath = $globalFixture.VmsPath
        },
        [pscustomobject]@{
            Root = 'FixtureRegistry:\InvalidEdition'
            DisplayName = 'MuMu Global'
            Publisher = 'NetEase'
            InstallLocation = $globalFixture.InstallRoot
            Edition = 'global'
            VmsPath = $globalFixture.VmsPath
        },
        [pscustomobject]@{
            Root = 'FixtureRegistry:\StaleVms'
            DisplayName = 'MuMu Global'
            Publisher = 'NetEase'
            InstallLocation = $globalFixture.InstallRoot
            Edition = 'Global'
            VmsPath = $staleVmsPath
        },
        [pscustomobject]@{
            Root = 'FixtureRegistry:\SameSourceA'
            DisplayName = 'MuMu Global'
            Publisher = 'NetEase'
            InstallLocation = $globalFixture.InstallRoot
            Edition = 'Global'
            VmsPath = $globalFixture.VmsPath
        },
        [pscustomobject]@{
            Root = 'FixtureRegistry:\SameSourceB'
            DisplayName = 'MuMu Global'
            Publisher = 'NetEase'
            InstallLocation = $globalFixture.InstallRoot
            Edition = 'Global'
            VmsPath = $globalRelocatedVms
        },
        [pscustomobject]@{
            Root = 'FixtureRegistry:\MalformedUnrelated'
            DisplayName = 'Unrelated Product'
            Publisher = 'Unrelated Publisher'
            InstallLocation = $unrelatedRegistryRoot
            Edition = 17
            VmsPath = $unrelatedRegistryVms
        },
        [pscustomobject]@{
            Root = 'FixtureRegistry:\MissingManager'
            DisplayName = 'MuMu Global'
            Publisher = 'NetEase'
            InstallLocation = $missingManagerRegistryRoot
            Edition = 'Global'
            VmsPath = $missingManagerRegistryVms
        },
        [pscustomobject]@{
            Root = 'FixtureRegistry:\MissingEdition'
            DisplayName = 'MuMu Global'
            Publisher = 'NetEase'
            InstallLocation = $missingEditionRegistryRoot
            Edition = ''
            VmsPath = $missingEditionRegistryVms
        },
        [pscustomobject]@{
            Root = 'FixtureRegistry:\Generic'
            DisplayName = 'MuMu'
            Publisher = 'NetEase'
            InstallLocation = $genericRegistryRoot
            Edition = ''
            VmsPath = $genericRegistryVms
        },
        [pscustomobject]@{
            Root = 'FixtureRegistry:\GenericMissing'
            DisplayName = 'MuMu'
            Publisher = 'NetEase'
            InstallLocation = $genericMissingRoot
            Edition = ''
            VmsPath = $genericMissingVms
        },
        [pscustomobject]@{
            Root = 'FixtureRegistry:\MissingLocation'
            DisplayName = 'MuMu Global'
            Publisher = 'NetEase'
            InstallLocation = ''
            Edition = 'Global'
            VmsPath = $globalFixture.VmsPath
        },
        [pscustomobject]@{
            Root = 'FixtureRegistry:\UnrelatedMissingLocation'
            DisplayName = 'Unrelated Product'
            Publisher = 'Unrelated Publisher'
            InstallLocation = ''
            Edition = ''
            VmsPath = $unrelatedRegistryVms
        }
    )

    function Get-ToolkitUninstallEntries {
        param([string]$Root)

        return @($script:discoveryRegistryEntries | Where-Object { $_.Root -eq $Root })
    }

    $registryRoots = @('FixtureRegistry:\Global')
    $processSnapshot = @(
        [pscustomobject]@{
            ExecutablePath = $globalRelocatedManager
            CommandLine = '"' + $globalRelocatedManager + '"'
            InstallRoot = $globalFixture.InstallRoot
            ManagerPath = $globalRelocatedManager
            VmsPath = $globalRelocatedVms
        },
        [pscustomobject]@{
            ExecutablePath = $processFixture.ManagerPath
            CommandLine = '"' + $processFixture.ManagerPath + '" --vms_path "' + $processVmsLink + '"'
            InstallRoot = $processFixture.InstallRoot
            Edition = 'Chinese'
        }
    )
    $fallbackRoots = @($fallbackFixture.InstallRoot)
    $installs = @(Find-MuMuInstallations -Edition 'All' -RegistryRoots $registryRoots -ProcessSnapshot $processSnapshot -FallbackRoots $fallbackRoots)
    $installFailure = Get-DiscoveryResultStatus $installs[0]
    if ($installFailure -eq 'CriticalError') {
        $installFailure += ': ' + $installs[0].Message
    }
    Assert-Equal 3 $installs.Count "Discovery did not deduplicate installation sources. $installFailure"
    $globalInstall = @($installs | Where-Object { $_.InstallRoot -eq $globalFixture.InstallRoot })
    $processInstall = @($installs | Where-Object { $_.InstallRoot -eq $processFixture.InstallRoot })
    $fallbackInstall = @($installs | Where-Object { $_.InstallRoot -eq $fallbackFixture.InstallRoot })
    Assert-Equal 1 $globalInstall.Count 'Spaced Global install was not discovered.'
    Assert-Equal 1 $processInstall.Count 'Unicode Chinese install was not discovered.'
    Assert-Equal 1 $fallbackInstall.Count 'Fallback install was not discovered.'
    Assert-Equal 'Registry' $globalInstall[0].Source 'Registry source precedence was not preserved.'
    Assert-Equal $globalRelocatedVms $globalInstall[0].VmsPath 'Process-reported relocated VMS path did not override stale fallback metadata.'
    Assert-Equal $globalRelocatedManager $globalInstall[0].ManagerPath 'Process-reported relocated manager path did not override stale fallback metadata.'
    Assert-Equal 'Process' $processInstall[0].Source 'Process installation source was not recorded.'
    Assert-Equal 'Chinese' $processInstall[0].Edition 'Unicode Chinese edition was not detected.'
    Assert-Equal $processVmsLink $processInstall[0].VmsPath 'Junction VMS path was not preserved.'
    Assert-Equal 'Fallback' $fallbackInstall[0].Source 'Fallback installation source was not recorded.'
    Assert-Equal $fallbackVms $fallbackInstall[0].VmsPath 'Versioned VMS fallback was not discovered.'
    Assert-True (@($installs | Where-Object { $_.InstallRoot -eq $outsideFixture.InstallRoot }).Count -eq 0) 'Process outside the discovered install was accepted.'
    $globalOnly = @(Find-MuMuInstallations -Edition 'Global' -RegistryRoots $registryRoots -ProcessSnapshot $processSnapshot -FallbackRoots $fallbackRoots)
    $chineseOnly = @(Find-MuMuInstallations -Edition 'Chinese' -RegistryRoots $registryRoots -ProcessSnapshot $processSnapshot -FallbackRoots $fallbackRoots)
    Assert-Equal 1 $globalOnly.Count 'Global edition filter returned the wrong count.'
    Assert-Equal 'Global' $globalOnly[0].Edition 'Global edition filter returned the wrong edition.'
    Assert-Equal 2 $chineseOnly.Count 'Chinese edition filter returned the wrong count.'
    Assert-True (@($chineseOnly | Where-Object { $_.Edition -eq 'Chinese' }).Count -eq 2) 'Chinese edition filter returned another edition.'

    $parsedSnapshot = ConvertFrom-ToolkitUninstallSnapshot -Snapshot ([pscustomobject]@{
        InstallLocation = $registryChineseFixture.InstallRoot
        DisplayName = 'MuMuPlayer'
        Publisher = 'NetEase'
        Edition = 'Chinese'
        VmsPath = $registryChineseVms
    })
    Assert-Equal $registryChineseFixture.InstallRoot $parsedSnapshot.InstallLocation 'Registry snapshot parser changed InstallLocation.'
    Assert-Equal 'MuMuPlayer' $parsedSnapshot.DisplayName 'Registry snapshot parser changed DisplayName.'
    Assert-Equal 'NetEase' $parsedSnapshot.Publisher 'Registry snapshot parser changed Publisher.'
    Assert-Equal 'Chinese' $parsedSnapshot.Edition 'Registry snapshot parser changed Edition.'
    Assert-Equal $registryChineseVms $parsedSnapshot.VmsPath 'Registry snapshot parser changed VmsPath.'
    $wrappedSnapshot = ConvertFrom-ToolkitUninstallSnapshot -Snapshot ([pscustomobject]@{
        Properties = [pscustomobject]@{
            InstallLocation = $registryChineseFixture.InstallRoot
            DisplayName = 'MuMuPlayer'
            Publisher = 'NetEase'
            Edition = 'Chinese'
            VmsPath = $registryChineseVms
        }
    })
    Assert-Equal $registryChineseFixture.InstallRoot $wrappedSnapshot.InstallLocation 'Wrapped registry snapshot parser changed InstallLocation.'
    $blankSnapshot = ConvertFrom-ToolkitUninstallSnapshot -Snapshot ([pscustomobject]@{ DisplayName = 'MuMu Global'; Publisher = 'NetEase' })
    Assert-Equal '' $blankSnapshot.InstallLocation 'Blank registry snapshot did not preserve missing InstallLocation.'
    Assert-Throws { ConvertFrom-ToolkitUninstallSnapshot -Snapshot @('invalid') } 'Invalid registry snapshot was accepted.'

    $registryResult = @(Find-MuMuInstallations -Edition 'All' -RegistryRoots @('FixtureRegistry:\Global', 'FixtureRegistry:\Chinese', 'FixtureRegistry:\Unrelated') -ProcessSnapshot @() -FallbackRoots @())
    $globalManagers = @(Get-ToolkitManagerPaths -InstallRoot $globalFixture.InstallRoot)
    $chineseManagers = @(Get-ToolkitManagerPaths -InstallRoot $registryChineseFixture.InstallRoot)
    Assert-Equal 1 $globalManagers.Count 'Global registry manager fixture was not recognized.'
    Assert-Equal 1 $chineseManagers.Count 'Chinese registry manager fixture was not recognized.'
    $registryFailure = Get-DiscoveryResultStatus $registryResult[0]
    if ($registryFailure -eq 'CriticalError') {
        $registryFailure += ': ' + $registryResult[0].Message
    }
    elseif ($registryResult.Count -ne 2) {
        $registryFailure += ': ' + (@($registryResult | ForEach-Object { $_.InstallRoot }) -join '|')
    }
    Assert-Equal 2 $registryResult.Count "Registry discovery did not filter unrelated products. $registryFailure"
    Assert-Equal 1 @($registryResult | Where-Object { $_.InstallRoot -eq $globalFixture.InstallRoot }).Count 'Global registry installation was not discovered.'
    Assert-Equal 1 @($registryResult | Where-Object { $_.InstallRoot -eq $registryChineseFixture.InstallRoot }).Count 'Chinese registry installation was not discovered.'
    Assert-Equal 0 @($registryResult | Where-Object { $_.InstallRoot -eq $unrelatedRegistryRoot }).Count 'Unrelated registry installation was accepted.'
    $malformedUnrelatedResult = @(Find-MuMuInstallations -Edition 'All' -RegistryRoots @('FixtureRegistry:\Global', 'FixtureRegistry:\Chinese', 'FixtureRegistry:\MalformedUnrelated') -ProcessSnapshot @() -FallbackRoots @())
    Assert-Equal 2 $malformedUnrelatedResult.Count 'Malformed unrelated registry row aborted discovery.'
    $missingManagerRegistryResult = Find-MuMuInstallations -Edition 'All' -RegistryRoots @('FixtureRegistry:\MissingManager') -ProcessSnapshot @() -FallbackRoots @()
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $missingManagerRegistryResult) 'Genuine registry row missing a manager was silently skipped.'
    $missingEditionRegistryResult = @(Find-MuMuInstallations -Edition 'All' -RegistryRoots @('FixtureRegistry:\MissingEdition') -ProcessSnapshot @() -FallbackRoots @())
    Assert-Equal 1 $missingEditionRegistryResult.Count 'Genuine registry row missing edition metadata was silently skipped.'
    Assert-Equal 'Global' $missingEditionRegistryResult[0].Edition 'Missing registry edition was not surfaced conservatively.'
    $genericRegistryResult = @(Find-MuMuInstallations -Edition 'All' -RegistryRoots @('FixtureRegistry:\Generic') -ProcessSnapshot @() -FallbackRoots @())
    $genericRegistryStatus = Get-DiscoveryResultStatus $genericRegistryResult[0]
    Assert-Equal 1 $genericRegistryResult.Count "Generic Chinese registry root was not discovered. $genericRegistryStatus"
    Assert-Equal 'Accepted' $genericRegistryStatus "Generic Chinese registry root returned $genericRegistryStatus."
    Assert-Equal 'Chinese' $genericRegistryResult[0].Edition 'Generic Chinese registry root was not classified conservatively.'
    $genericManagerRegistryResult = Find-MuMuInstallations -Edition 'All' -RegistryRoots @('FixtureRegistry:\GenericMissing') -ProcessSnapshot @() -FallbackRoots @()
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $genericManagerRegistryResult) 'Generic root without a valid manager was accepted.'
    $genericProcessResult = @(Find-MuMuInstallations -Edition 'All' -RegistryRoots @() -ProcessSnapshot @([pscustomobject]@{ ExecutablePath = $genericProcessManager; CommandLine = '"' + $genericProcessManager + '"'; InstallRoot = $genericProcessRoot }) -FallbackRoots @())
    $genericProcessStatus = Get-DiscoveryResultStatus $genericProcessResult[0]
    Assert-Equal 1 $genericProcessResult.Count "Generic Chinese process root was not discovered. $genericProcessStatus"
    Assert-Equal 'Accepted' $genericProcessStatus "Generic Chinese process root returned $genericProcessStatus."
    Assert-Equal 'Chinese' $genericProcessResult[0].Edition 'Generic Chinese process root was not classified conservatively.'
    $genericProcessMissingResult = Find-MuMuInstallations -Edition 'All' -RegistryRoots @() -ProcessSnapshot @([pscustomobject]@{ ExecutablePath = $genericMissingPlayer; CommandLine = '"' + $genericMissingPlayer + '"'; InstallRoot = $genericMissingRoot }) -FallbackRoots @()
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $genericProcessMissingResult) 'Generic process root without a valid manager was accepted.'
    $missingLocationRegistryResult = Find-MuMuInstallations -Edition 'All' -RegistryRoots @('FixtureRegistry:\MissingLocation') -ProcessSnapshot @() -FallbackRoots @()
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $missingLocationRegistryResult) 'Genuine registry row missing InstallLocation was silently skipped.'
    $unrelatedMissingLocationResult = @(Find-MuMuInstallations -Edition 'All' -RegistryRoots @('FixtureRegistry:\Global', 'FixtureRegistry:\UnrelatedMissingLocation') -ProcessSnapshot @() -FallbackRoots @())
    Assert-Equal 1 $unrelatedMissingLocationResult.Count 'Unrelated registry row missing InstallLocation aborted discovery.'

    $registryEditionConflict = Find-MuMuInstallations -Edition 'All' -RegistryRoots @('FixtureRegistry:\EditionConflict') -ProcessSnapshot @() -FallbackRoots @()
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $registryEditionConflict) 'Registry path and explicit edition conflict was accepted.'

    $invalidRegistryEdition = Find-MuMuInstallations -Edition 'All' -RegistryRoots @('FixtureRegistry:\InvalidEdition') -ProcessSnapshot @() -FallbackRoots @()
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $invalidRegistryEdition) 'Noncanonical registry edition was accepted.'

    $processEditionConflict = Find-MuMuInstallations -Edition 'All' -RegistryRoots @() -ProcessSnapshot @([pscustomobject]@{ ExecutablePath = $globalFixture.ManagerPath; CommandLine = '"' + $globalFixture.ManagerPath + '"'; InstallRoot = $globalFixture.InstallRoot; Edition = 'Chinese' }) -FallbackRoots @()
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $processEditionConflict) 'Process path and explicit edition conflict was accepted.'

    $crossSourceEditionConflict = Find-MuMuInstallations -Edition 'All' -RegistryRoots @('FixtureRegistry:\Global') -ProcessSnapshot @([pscustomobject]@{ ExecutablePath = $globalFixture.ManagerPath; CommandLine = '"' + $globalFixture.ManagerPath + '"'; InstallRoot = $globalFixture.InstallRoot; Edition = 'Chinese' }) -FallbackRoots @()
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $crossSourceEditionConflict) 'Cross-source editions were merged into a hybrid record.'

    $sameRegistryConflict = Find-MuMuInstallations -Edition 'All' -RegistryRoots @('FixtureRegistry:\SameSourceA', 'FixtureRegistry:\SameSourceB') -ProcessSnapshot @() -FallbackRoots @()
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $sameRegistryConflict) 'Same-source registry paths were merged silently.'
    $sameProcessConflict = Find-MuMuInstallations -Edition 'All' -RegistryRoots @() -ProcessSnapshot @(
        [pscustomobject]@{ ExecutablePath = $globalRelocatedManager; CommandLine = '"' + $globalRelocatedManager + '"'; InstallRoot = $globalFixture.InstallRoot; Edition = 'Global' },
        [pscustomobject]@{ ExecutablePath = $globalRelocatedManager; CommandLine = '"' + $globalRelocatedManager + '"'; InstallRoot = $globalFixture.InstallRoot; Edition = 'Global'; VmsPath = $globalRelocatedVms }
    ) -FallbackRoots @()
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $sameProcessConflict) 'Same-source process VMS paths were merged silently.'

    $multipleManagerRoot = Join-Path $discoveryRoot 'Multiple Manager Layout\MuMu Global'
    $multipleManagerVms = Join-Path $multipleManagerRoot 'vms'
    $multipleManagerShell = Join-Path $multipleManagerRoot 'shell\MuMuManager.exe'
    $multipleManagerNested = Join-Path $multipleManagerRoot 'nx_main\shell\MuMuManager.exe'
    New-Item -ItemType Directory -Path $multipleManagerVms -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path -Parent $multipleManagerShell) -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path -Parent $multipleManagerNested) -Force | Out-Null
    [IO.File]::WriteAllText($multipleManagerShell, 'manager fixture')
    [IO.File]::WriteAllText($multipleManagerNested, 'manager fixture')
    $multipleManagerResult = Find-MuMuInstallations -Edition 'All' -RegistryRoots @() -ProcessSnapshot @([pscustomobject]@{ ExecutablePath = $multipleManagerNested; CommandLine = '"' + $multipleManagerNested + '"'; InstallRoot = $multipleManagerRoot; Edition = 'Global' }) -FallbackRoots @()
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $multipleManagerResult) 'Multiple valid manager layouts were selected silently.'
    $explicitMultipleManagerResult = Find-MuMuInstallations -Edition 'All' -RegistryRoots @() -ProcessSnapshot @([pscustomobject]@{ ExecutablePath = $multipleManagerNested; CommandLine = '"' + $multipleManagerNested + '"'; InstallRoot = $multipleManagerRoot; Edition = 'Global'; ManagerPath = $multipleManagerNested }) -FallbackRoots @()
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $explicitMultipleManagerResult) 'Explicit process manager bypassed multiple-layout validation.'

    $getMultipleRoot = Join-Path $discoveryRoot 'Get Multiple Manager Layout\MuMu Global'
    $getMultipleVms = Join-Path $getMultipleRoot 'vms'
    New-Item -ItemType Directory -Path $getMultipleVms -Force | Out-Null
    $getMultipleInfo = [pscustomobject]@{ index = '1'; name = 'Multiple Manager'; is_main = $false; is_process_started = $false; android_version = '12.0' } | ConvertTo-Json -Compress
    $getMultipleShellManager = New-DiscoveryManagerFixture -InstallRoot $getMultipleRoot -InfoJson $getMultipleInfo
    $getMultipleNestedManager = Join-Path $getMultipleRoot 'nx_main\shell\MuMuManager.exe'
    New-Item -ItemType Directory -Path (Split-Path -Parent $getMultipleNestedManager) -Force | Out-Null
    [IO.File]::Copy($script:discoveryManagerTemplatePath, $getMultipleNestedManager, $true)
    $getMultipleUtf8 = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText((Join-Path (Split-Path -Parent $getMultipleNestedManager) 'info.json'), $getMultipleInfo, $getMultipleUtf8)
    [IO.File]::WriteAllText((Join-Path (Split-Path -Parent $getMultipleNestedManager) 'setting.json'), '{"root_permission":"false"}', $getMultipleUtf8)
    $getMultipleInstall = [pscustomobject]@{ Edition = 'Global'; InstallRoot = [IO.Path]::GetFullPath($getMultipleRoot); VmsPath = [IO.Path]::GetFullPath($getMultipleVms); ManagerPath = $getMultipleShellManager; Source = 'Process' }
    $getMultipleResult = Invoke-DiscoveryCall { Get-MuMuInstances -Install $getMultipleInstall -ManagerPath $getMultipleShellManager }
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $getMultipleResult) 'Get bypassed multiple manager layout validation.'
    Assert-True (-not [IO.File]::Exists((Join-Path (Split-Path -Parent $getMultipleShellManager) 'args.log'))) 'Get executed before multiple manager validation.'

    $invalidEditionThrew = $false
    $invalidEditionResult = $null
    try {
        $invalidEditionResult = Find-MuMuInstallations -Edition 'Unsupported' -RegistryRoots @() -ProcessSnapshot @() -FallbackRoots @()
    }
    catch {
        $invalidEditionThrew = $true
    }
    Assert-True (-not $invalidEditionThrew) 'Invalid public Edition threw instead of returning CriticalError.'
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $invalidEditionResult) 'Invalid public Edition was accepted.'

    $env:APPDATA = $fixtureProfileRoot
    $globalUserVms = Join-Path $fixtureProfileRoot 'Netease\MuMuPlayerGlobal\vms'
    $chineseUserVms = Join-Path $fixtureProfileRoot 'Netease\MuMuPlayer\vms'
    New-Item -ItemType Directory -Path $globalUserVms -Force | Out-Null
    New-Item -ItemType Directory -Path $chineseUserVms -Force | Out-Null
    $globalUserRoot = Join-Path $discoveryRoot 'Global User Layout\MuMu Global'
    $globalUserManager = Join-Path $globalUserRoot 'shell\MuMuManager.exe'
    New-Item -ItemType Directory -Path (Split-Path -Parent $globalUserManager) -Force | Out-Null
    [IO.File]::WriteAllText($globalUserManager, 'global user layout fixture')
    $chineseUserRoot = Join-Path $discoveryRoot 'Chinese User Layout\MuMuPlayer'
    $chineseUserManager = Join-Path $chineseUserRoot 'shell\MuMuManager.exe'
    New-Item -ItemType Directory -Path (Split-Path -Parent $chineseUserManager) -Force | Out-Null
    [IO.File]::WriteAllText($chineseUserManager, 'chinese user layout fixture')

    $globalUserResult = @(Find-MuMuInstallations -Edition 'Global' -RegistryRoots @() -ProcessSnapshot @() -FallbackRoots @($globalUserRoot))
    Assert-Equal 1 $globalUserResult.Count 'Global user-data layout was not discovered.'
    Assert-Equal $globalUserVms $globalUserResult[0].VmsPath 'Global user-data VMS path was not selected independently.'
    $chineseUserResult = @(Find-MuMuInstallations -Edition 'Chinese' -RegistryRoots @() -ProcessSnapshot @([pscustomobject]@{ ExecutablePath = $chineseUserManager; CommandLine = '"' + $chineseUserManager + '"'; InstallRoot = $chineseUserRoot; Edition = 'Chinese' }) -FallbackRoots @())
    Assert-Equal 1 $chineseUserResult.Count 'Chinese user-data layout was not discovered.'
    Assert-Equal $chineseUserVms $chineseUserResult[0].VmsPath 'Chinese user-data VMS path was not selected independently.'

    $multipleVmsRoot = Join-Path $discoveryRoot 'Multiple VMS\MuMuPlayer'
    $multipleVmsManager = Join-Path $multipleVmsRoot 'shell\MuMuManager.exe'
    New-Item -ItemType Directory -Path (Split-Path -Parent $multipleVmsManager) -Force | Out-Null
    [IO.File]::WriteAllText($multipleVmsManager, 'multiple VMS fixture')
    New-Item -ItemType Directory -Path (Join-Path $multipleVmsRoot 'vms') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $multipleVmsRoot 'nx_device\15.0\vms') -Force | Out-Null
    $multipleVmsResult = Find-MuMuInstallations -Edition 'Chinese' -RegistryRoots @() -ProcessSnapshot @() -FallbackRoots @($multipleVmsRoot)
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $multipleVmsResult) 'Multiple inferred VMS paths were selected silently.'

    $env:APPDATA = Join-Path $fixtureProfileRoot 'empty'
    $unicodeFallbackRoot = Join-Path $discoveryRoot (Join-Path 'Unicode Fallback' (Join-Path $unicodeFolder 'MuMu'))
    $unicodeFallbackVms = Join-Path $unicodeFallbackRoot 'nx_device\12.0\vms'
    $unicodeFallbackManager = Join-Path $unicodeFallbackRoot 'shell\MuMuManager.exe'
    New-Item -ItemType Directory -Path $unicodeFallbackVms -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path -Parent $unicodeFallbackManager) -Force | Out-Null
    [IO.File]::WriteAllText($unicodeFallbackManager, 'unicode fallback fixture')
    $unicodeFallbackResult = @(Find-MuMuInstallations -Edition 'All' -RegistryRoots @() -ProcessSnapshot @() -FallbackRoots @($unicodeFallbackRoot))
    $unicodeFallbackStatus = Get-DiscoveryResultStatus $unicodeFallbackResult[0]
    $unicodeFallbackMessage = ''
    if ($unicodeFallbackStatus -eq 'CriticalError') {
        $unicodeFallbackMessage = ': ' + $unicodeFallbackResult[0].Message
    }
    Assert-Equal 1 $unicodeFallbackResult.Count "Generic Unicode MuMu fallback was not discovered. $unicodeFallbackStatus$unicodeFallbackMessage"
    Assert-Equal 'Accepted' $unicodeFallbackStatus "Generic Unicode MuMu fallback returned $unicodeFallbackStatus$unicodeFallbackMessage"
    Assert-Equal 'Chinese' $unicodeFallbackResult[0].Edition 'Generic Unicode MuMu fallback was not classified conservatively.'
    Assert-Equal $unicodeFallbackVms $unicodeFallbackResult[0].VmsPath 'Generic Unicode MuMu fallback selected the wrong VMS path.'
    $env:APPDATA = $fixtureProfileRoot

    $unknownEditionRoot = Join-Path $discoveryRoot 'Unknown Edition\Application'
    $unknownEditionVms = Join-Path $unknownEditionRoot 'vms'
    $unknownEditionManager = Join-Path $unknownEditionRoot 'shell\MuMuManager.exe'
    New-Item -ItemType Directory -Path $unknownEditionVms -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path -Parent $unknownEditionManager) -Force | Out-Null
    [IO.File]::WriteAllText($unknownEditionManager, 'unknown edition fixture')
    $unknownEditionResult = Find-MuMuInstallations -Edition 'All' -RegistryRoots @() -ProcessSnapshot @() -FallbackRoots @($unknownEditionRoot)
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $unknownEditionResult) 'Unknown fallback edition defaulted to Chinese.'

    $staleRegistryVms = Find-MuMuInstallations -Edition 'All' -RegistryRoots @('FixtureRegistry:\StaleVms') -ProcessSnapshot @() -FallbackRoots @()
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $staleRegistryVms) 'Stale explicit registry VMS path was ignored.'
    $staleProcessVms = Find-MuMuInstallations -Edition 'Global' -RegistryRoots @() -ProcessSnapshot @([pscustomobject]@{ ExecutablePath = $globalRelocatedManager; CommandLine = '"' + $globalRelocatedManager + '"'; InstallRoot = $globalFixture.InstallRoot; Edition = 'Global'; VmsPath = $staleVmsPath }) -FallbackRoots @()
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $staleProcessVms) 'Stale explicit process VMS path was ignored.'

    $conflictingVmsRoot = Join-Path $discoveryRoot 'Conflicting VMS\MuMu Global'
    $conflictingVmsManager = Join-Path $conflictingVmsRoot 'shell\MuMuManager.exe'
    New-Item -ItemType Directory -Path (Split-Path -Parent $conflictingVmsManager) -Force | Out-Null
    [IO.File]::WriteAllText($conflictingVmsManager, 'conflicting VMS fixture')
    $conflictingVmsA = Join-Path $conflictingVmsRoot 'relocated-a\vms'
    $conflictingVmsB = Join-Path $conflictingVmsRoot 'relocated-b\vms'
    New-Item -ItemType Directory -Path $conflictingVmsA -Force | Out-Null
    New-Item -ItemType Directory -Path $conflictingVmsB -Force | Out-Null
    $conflictingVmsResult = Find-MuMuInstallations -Edition 'Global' -RegistryRoots @() -ProcessSnapshot @([pscustomobject]@{ ExecutablePath = $conflictingVmsManager; CommandLine = '"' + $conflictingVmsManager + '" --vms_path "' + $conflictingVmsB + '"'; InstallRoot = $conflictingVmsRoot; Edition = 'Global'; VmsPath = $conflictingVmsA }) -FallbackRoots @()
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $conflictingVmsResult) 'Conflicting explicit VMS paths were merged silently.'
    $env:APPDATA = Join-Path $fixtureProfileRoot 'empty'
    $repeatedVmsRoot = Join-Path $discoveryRoot 'Repeated VMS\MuMu Global'
    $repeatedVmsManager = Join-Path $repeatedVmsRoot 'shell\MuMuManager.exe'
    New-Item -ItemType Directory -Path (Split-Path -Parent $repeatedVmsManager) -Force | Out-Null
    [IO.File]::WriteAllText($repeatedVmsManager, 'repeated VMS fixture')
    $repeatedVmsPath = Join-Path $repeatedVmsRoot 'vms'
    New-Item -ItemType Directory -Path $repeatedVmsPath -Force | Out-Null
    $repeatedVmsCommand = '"' + $repeatedVmsManager + '" --vms_path "' + $repeatedVmsPath + '" --vms_path "' + $repeatedVmsPath + '"'
    $repeatedVmsResult = Find-MuMuInstallations -Edition 'Global' -RegistryRoots @() -ProcessSnapshot @([pscustomobject]@{ CommandLine = $repeatedVmsCommand }) -FallbackRoots @()
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $repeatedVmsResult) 'Repeated identical VMS arguments were accepted.'
    $repeatedConflictCommand = '"' + $repeatedVmsManager + '" --vms_path "' + $repeatedVmsPath + '" --vms_path "' + $globalRelocatedVms + '"'
    $repeatedConflictResult = Find-MuMuInstallations -Edition 'Global' -RegistryRoots @() -ProcessSnapshot @([pscustomobject]@{ CommandLine = $repeatedConflictCommand }) -FallbackRoots @()
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $repeatedConflictResult) 'Repeated conflicting VMS arguments were accepted.'
    $unsupportedVmsCommand = '"' + $repeatedVmsManager + '" --vms-path-extra "' + $repeatedVmsPath + '"'
    $unsupportedVmsResult = Find-MuMuInstallations -Edition 'Global' -RegistryRoots @() -ProcessSnapshot @([pscustomobject]@{ CommandLine = $unsupportedVmsCommand }) -FallbackRoots @()
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $unsupportedVmsResult) 'Unsupported VMS flag spelling was ignored.'

    $instanceRoot = Join-Path $discoveryRoot 'instances\MuMu Global'
    $instanceVms = Join-Path $discoveryRoot 'relocated instances\vms'
    New-Item -ItemType Directory -Path $instanceVms -Force | Out-Null
    $instanceInfo = @(
        [pscustomobject]@{ index = '10'; name = 'Android 12'; is_main = $false; is_process_started = $false; android_version = '12.0' },
        [pscustomobject]@{ index = '0'; name = 'Base'; is_main = $true; is_process_started = $false; android_version = '12.0' },
        [pscustomobject]@{ index = '2'; name = 'Android 15'; is_main = $false; is_process_started = $true; android_version = '15.0'; vms_path = $instanceVms }
    ) | ConvertTo-Json -Compress
    $instanceManager = New-DiscoveryManagerFixture -InstallRoot $instanceRoot -InfoJson $instanceInfo -SettingJson '{"root_permission":"true"}'
    $instanceInstall = [pscustomobject]@{
        Edition = 'Global'
        InstallRoot = [IO.Path]::GetFullPath($instanceRoot)
        VmsPath = [IO.Path]::GetFullPath($instanceVms)
        ManagerPath = $instanceManager
        Source = 'Process'
    }
    $instances = @(Get-MuMuInstances -Install $instanceInstall -ManagerPath $instanceManager)
    Assert-Equal 3 $instances.Count 'Instance discovery lost manager records.'
    Assert-True ((@($instances | ForEach-Object { $_.Index }) -join ',') -eq '0,2,10') 'Instances were not sorted by numeric index.'
    Assert-Equal 'Android 15' $instances[1].Name 'Numeric instance ordering changed the selected record.'
    Assert-Equal '15.0' $instances[1].AndroidVersion 'Android version was not parsed.'
    Assert-Equal $true $instances[1].Running 'Running state was not parsed.'
    Assert-Equal $true $instances[1].RootSetting 'Root setting was not queried through the manager.'
    Assert-Equal $instanceManager $instances[1].Install.ManagerPath 'Relocated manager path was not resolved.'
    Assert-Equal $instanceVms $instances[1].Install.VmsPath 'Manager-reported VMS path was not resolved.'
    Assert-Equal $false $instances[0].Eligible 'Base instance was marked eligible.'
    Assert-Equal $true $instances[1].Eligible 'Android 15 instance was not eligible.'
    $managerArguments = [IO.File]::ReadAllLines((Join-Path (Split-Path -Parent $instanceManager) 'args.log'))
    Assert-Equal 'info|-v|all' $managerArguments[0] 'Manager info arguments were not structured.'
    Assert-True (@($managerArguments | Where-Object { $_ -eq 'setting|-v|0|-k|root_permission' }).Count -eq 0) 'Base instance invoked a per-instance manager process.'
    Assert-True (@($managerArguments | Where-Object { $_ -eq 'setting|-v|2|-k|root_permission' }).Count -eq 1) 'Instance root setting arguments were changed.'
    Assert-True (@($managerArguments | Where-Object { $_ -eq 'setting|-v|10|-k|root_permission' }).Count -eq 1) 'Android 12 root setting arguments were changed.'

    $eligibleZero = [pscustomobject]@{ Index = 0; Eligible = $false }
    $eligibleOne = [pscustomobject]@{ Index = 1; Eligible = $true }
    $eligibleTwo = [pscustomobject]@{ Index = 2; Eligible = $true }
    $zeroResult = Resolve-SelectedInstance -Instances @($eligibleZero) -Selection $null
    $ambiguousResult = Resolve-SelectedInstance -Instances @($eligibleOne, $eligibleTwo) -Selection $null
    $selectedResult = Resolve-SelectedInstance -Instances @($eligibleOne, $eligibleTwo) -Selection ([pscustomobject]@{ Index = 2 })
    $invalidSelectionResult = Resolve-SelectedInstance -Instances @($eligibleOne) -Selection ([pscustomobject]@{ Index = 9 })
    $singleResult = Resolve-SelectedInstance -Instances @($eligibleZero, $eligibleOne) -Selection $null
    Assert-Equal 'CriticalError' $zeroResult.Status 'Zero eligible instances were accepted.'
    Assert-Equal 'CriticalError' $ambiguousResult.Status 'Ambiguous instance selection was accepted.'
    Assert-Equal 2 $selectedResult.Index 'Explicit instance selection failed.'
    Assert-Equal 'CriticalError' $invalidSelectionResult.Status 'Invalid explicit instance selection was accepted.'
    Assert-Equal 1 $singleResult.Index 'Single eligible instance was not resolved.'

    $baseRoot = Join-Path $discoveryRoot 'base-only'
    $baseVms = Join-Path $baseRoot 'vms'
    New-Item -ItemType Directory -Path $baseVms -Force | Out-Null
    $baseInfo = [pscustomobject]@{ index = '0'; name = 'Base'; is_main = $true; is_process_started = $false; android_version = '12.0' } | ConvertTo-Json -Compress
    $baseManager = New-DiscoveryManagerFixture -InstallRoot $baseRoot -InfoJson $baseInfo
    $baseInstall = [pscustomobject]@{ Edition = 'Global'; InstallRoot = [IO.Path]::GetFullPath($baseRoot); VmsPath = [IO.Path]::GetFullPath($baseVms); ManagerPath = $baseManager; Source = 'Process' }
    $baseInstances = @(Get-MuMuInstances -Install $baseInstall -ManagerPath $baseManager)
    $baseResult = Resolve-SelectedInstance -Instances $baseInstances -Selection $null
    $baseArguments = [IO.File]::ReadAllLines((Join-Path (Split-Path -Parent $baseManager) 'args.log'))
    Assert-Equal 1 $baseInstances.Count 'Base instance was not returned for display.'
    Assert-Equal $false $baseInstances[0].Eligible 'Base instance was eligible.'
    Assert-True ($null -eq $baseInstances[0].RootSetting) 'Base instance unexpectedly reported a queried root setting.'
    Assert-Equal 1 $baseArguments.Count 'Base instance invoked a per-instance manager process.'
    Assert-Equal 'info|-v|all' $baseArguments[0] 'Base instance manager arguments changed.'
    Assert-Equal 'CriticalError' $baseResult.Status 'Base-only instance selection was accepted.'

    $unsupportedRoot = Join-Path $discoveryRoot 'unsupported'
    $unsupportedVms = Join-Path $unsupportedRoot 'vms'
    New-Item -ItemType Directory -Path $unsupportedVms -Force | Out-Null
    $unsupportedInfo = [pscustomobject]@{ index = '4'; name = 'Unsupported'; is_main = $false; is_process_started = $false; android_version = '11.0' } | ConvertTo-Json -Compress
    $unsupportedManager = New-DiscoveryManagerFixture -InstallRoot $unsupportedRoot -InfoJson $unsupportedInfo
    $unsupportedInstall = [pscustomobject]@{ Edition = 'Global'; InstallRoot = [IO.Path]::GetFullPath($unsupportedRoot); VmsPath = [IO.Path]::GetFullPath($unsupportedVms); ManagerPath = $unsupportedManager; Source = 'Process' }
    $unsupportedInstances = @(Get-MuMuInstances -Install $unsupportedInstall -ManagerPath $unsupportedManager)
    $unsupportedResult = Resolve-SelectedInstance -Instances $unsupportedInstances -Selection $null
    $unsupportedArguments = [IO.File]::ReadAllLines((Join-Path (Split-Path -Parent $unsupportedManager) 'args.log'))
    Assert-Equal $false $unsupportedInstances[0].Eligible 'Unsupported Android version was eligible.'
    Assert-True ($null -eq $unsupportedInstances[0].RootSetting) 'Unsupported instance unexpectedly reported a queried root setting.'
    Assert-Equal 1 $unsupportedArguments.Count 'Unsupported instance invoked a per-instance manager process.'
    Assert-Equal 'info|-v|all' $unsupportedArguments[0] 'Unsupported instance manager arguments changed.'
    Assert-Equal 'CriticalError' $unsupportedResult.Status 'Unsupported Android version was accepted.'

    $unknownMainRoot = Join-Path $discoveryRoot 'unknown-main'
    $unknownMainVms = Join-Path $unknownMainRoot 'vms'
    New-Item -ItemType Directory -Path $unknownMainVms -Force | Out-Null
    $unknownMainInfo = [pscustomobject]@{ index = '0'; name = 'Unknown main state'; is_process_started = $false; android_version = '12.0' } | ConvertTo-Json -Compress
    $unknownMainManager = New-DiscoveryManagerFixture -InstallRoot $unknownMainRoot -InfoJson $unknownMainInfo
    $unknownMainInstall = [pscustomobject]@{ Edition = 'Global'; InstallRoot = [IO.Path]::GetFullPath($unknownMainRoot); VmsPath = [IO.Path]::GetFullPath($unknownMainVms); ManagerPath = $unknownMainManager; Source = 'Process' }
    $unknownMainInstances = @(Get-MuMuInstances -Install $unknownMainInstall -ManagerPath $unknownMainManager)
    $unknownMainResult = Resolve-SelectedInstance -Instances $unknownMainInstances -Selection $null
    $unknownMainArguments = [IO.File]::ReadAllLines((Join-Path (Split-Path -Parent $unknownMainManager) 'args.log'))
    Assert-Equal $false $unknownMainInstances[0].Eligible 'Missing is_main was treated as an eligible non-base instance.'
    Assert-Equal 'CriticalError' $unknownMainResult.Status 'Missing is_main instance was selected.'
    Assert-Equal 1 $unknownMainArguments.Count 'Missing is_main instance invoked a per-instance manager process.'

    $unknownRunningRoot = Join-Path $discoveryRoot 'unknown-running'
    $unknownRunningVms = Join-Path $unknownRunningRoot 'vms'
    New-Item -ItemType Directory -Path $unknownRunningVms -Force | Out-Null
    $unknownRunningInfo = [pscustomobject]@{ index = '1'; name = 'Unknown running state'; is_main = $false; android_version = '12.0' } | ConvertTo-Json -Compress
    $unknownRunningManager = New-DiscoveryManagerFixture -InstallRoot $unknownRunningRoot -InfoJson $unknownRunningInfo
    $unknownRunningInstall = [pscustomobject]@{ Edition = 'Global'; InstallRoot = [IO.Path]::GetFullPath($unknownRunningRoot); VmsPath = [IO.Path]::GetFullPath($unknownRunningVms); ManagerPath = $unknownRunningManager; Source = 'Process' }
    $unknownRunningInstances = @(Get-MuMuInstances -Install $unknownRunningInstall -ManagerPath $unknownRunningManager)
    $unknownRunningResult = Resolve-SelectedInstance -Instances $unknownRunningInstances -Selection $null
    $unknownRunningArguments = [IO.File]::ReadAllLines((Join-Path (Split-Path -Parent $unknownRunningManager) 'args.log'))
    Assert-Equal $false $unknownRunningInstances[0].Eligible 'Missing running state was treated as selectable stopped state.'
    Assert-True ($null -eq $unknownRunningInstances[0].Running) 'Missing running state was reported as false.'
    Assert-Equal 1 $unknownRunningArguments.Count 'Missing running state invoked a per-instance manager process.'
    Assert-Equal 'CriticalError' $unknownRunningResult.Status 'Missing running state instance was selected.'

    $invalidJsonCase = Invoke-DiscoveryManagerCase -Name 'invalid-json' -InfoJson '{not-json'
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus @($invalidJsonCase.Result)[0]) 'Invalid manager JSON was accepted.'
    Assert-True (@($invalidJsonCase.Result)[0].Message -match '(?i)json') 'Invalid manager JSON error omitted field context.'

    $duplicateIndexInfo = @(
        [pscustomobject]@{ index = '1'; name = 'First'; is_main = $false; is_process_started = $false; android_version = '12.0' },
        [pscustomobject]@{ index = 1; name = 'Duplicate'; is_main = $false; is_process_started = $false; android_version = '12.0' }
    ) | ConvertTo-Json -Compress
    $duplicateIndexCase = Invoke-DiscoveryManagerCase -Name 'duplicate-index' -InfoJson $duplicateIndexInfo
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus @($duplicateIndexCase.Result)[0]) 'Duplicate manager indexes were accepted.'
    Assert-True (@($duplicateIndexCase.Result)[0].Message -match '(?i)index') 'Duplicate index error omitted field context.'

    $invalidMainInfo = [pscustomobject]@{ index = '1'; name = 'Invalid main'; is_main = 'unknown'; is_process_started = $false; android_version = '12.0' } | ConvertTo-Json -Compress
    $invalidMainCase = Invoke-DiscoveryManagerCase -Name 'invalid-main' -InfoJson $invalidMainInfo
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus @($invalidMainCase.Result)[0]) 'Invalid is_main was accepted.'
    Assert-True (@($invalidMainCase.Result)[0].Message -match '(?i)is_main') 'Invalid is_main error omitted field context.'

    $invalidRunningInfo = [pscustomobject]@{ index = '1'; name = 'Invalid running'; is_main = $false; is_process_started = 'unknown'; android_version = '12.0' } | ConvertTo-Json -Compress
    $invalidRunningCase = Invoke-DiscoveryManagerCase -Name 'invalid-running' -InfoJson $invalidRunningInfo
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus @($invalidRunningCase.Result)[0]) 'Invalid running state was accepted.'
    Assert-True (@($invalidRunningCase.Result)[0].Message -match '(?i)running') 'Invalid running state error omitted field context.'

    $invalidNameInfo = [pscustomobject]@{ index = '1'; name = ''; is_main = $false; is_process_started = $false; android_version = '12.0' } | ConvertTo-Json -Compress
    $invalidNameCase = Invoke-DiscoveryManagerCase -Name 'invalid-name' -InfoJson $invalidNameInfo
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus @($invalidNameCase.Result)[0]) 'Invalid instance name was accepted.'
    Assert-True (@($invalidNameCase.Result)[0].Message -match '(?i)name') 'Invalid name error omitted field context.'

    $invalidReportedRootInfo = [pscustomobject]@{ index = '1'; name = 'Invalid root'; is_main = $false; is_process_started = $false; android_version = '12.0'; root_permission = 'unknown' } | ConvertTo-Json -Compress
    $invalidReportedRootCase = Invoke-DiscoveryManagerCase -Name 'invalid-reported-root' -InfoJson $invalidReportedRootInfo
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus @($invalidReportedRootCase.Result)[0]) 'Invalid reported root setting was accepted.'
    Assert-True (@($invalidReportedRootCase.Result)[0].Message -match '(?i)root') 'Invalid root setting error omitted field context.'

    $validRootInfo = [pscustomobject]@{ index = '1'; name = 'Invalid queried root'; is_main = $false; is_process_started = $false; android_version = '12.0' } | ConvertTo-Json -Compress
    $staleExplicitCase = Invoke-DiscoveryManagerCase -Name 'stale-install-explicit' -InfoJson $validRootInfo
    $staleExplicitRoot = $staleExplicitCase.Install.InstallRoot
    $staleUnsafeManager = Join-Path $staleExplicitRoot 'tools\unsafe.exe'
    New-Item -ItemType Directory -Path (Split-Path -Parent $staleUnsafeManager) -Force | Out-Null
    [IO.File]::Copy($script:discoveryManagerTemplatePath, $staleUnsafeManager, $true)
    if ([IO.File]::Exists($staleExplicitCase.ArgumentsPath)) {
        [IO.File]::Delete($staleExplicitCase.ArgumentsPath)
    }
    $staleExplicitInstall = [pscustomobject]@{ Edition = $staleExplicitCase.Install.Edition; InstallRoot = $staleExplicitRoot; VmsPath = $staleExplicitCase.Install.VmsPath; ManagerPath = $staleUnsafeManager; Source = $staleExplicitCase.Install.Source }
    $staleExplicitResult = Invoke-DiscoveryCall { Get-MuMuInstances -Install $staleExplicitInstall -ManagerPath $staleExplicitCase.ManagerPath }
    $staleExplicitStatus = Get-DiscoveryResultStatus @($staleExplicitResult)[0]
    $staleExplicitMessage = ''
    if ($staleExplicitStatus -eq 'CriticalError') {
        $staleExplicitMessage = ': ' + @($staleExplicitResult)[0].Message
    }
    Assert-True (@($staleExplicitResult).Count -eq 1 -and $null -eq @($staleExplicitResult)[0].PSObject.Properties['Status']) "Valid explicit manager did not replace stale Install.ManagerPath. $staleExplicitStatus$staleExplicitMessage"
    Assert-Equal $staleExplicitCase.ManagerPath @($staleExplicitResult)[0].Install.ManagerPath 'Explicit manager was not retained after stale Install.ManagerPath.'
    Assert-True (-not [IO.File]::Exists((Join-Path (Split-Path -Parent $staleUnsafeManager) 'args.log'))) 'Stale Install.ManagerPath reached the process runner.'

    $invalidQueriedRootCase = Invoke-DiscoveryManagerCase -Name 'invalid-queried-root' -InfoJson $validRootInfo -SettingJson '{"root_permission":"unknown"}'
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus @($invalidQueriedRootCase.Result)[0]) 'Invalid queried root setting was accepted.'
    Assert-True (@($invalidQueriedRootCase.Result)[0].Message -match '(?i)root') 'Invalid queried root setting error omitted field context.'

    $malformedInstallCase = Invoke-DiscoveryManagerCase -Name 'malformed-install' -InfoJson $validRootInfo
    $validInstall = $malformedInstallCase.Install
    $malformedInstalls = @(
        [pscustomobject]@{ Label = 'Edition'; Value = [pscustomobject]@{ Edition = 'Other'; InstallRoot = $validInstall.InstallRoot; VmsPath = $validInstall.VmsPath; ManagerPath = $validInstall.ManagerPath; Source = $validInstall.Source } },
        [pscustomobject]@{ Label = 'Source'; Value = [pscustomobject]@{ Edition = $validInstall.Edition; InstallRoot = $validInstall.InstallRoot; VmsPath = $validInstall.VmsPath; ManagerPath = $validInstall.ManagerPath; Source = 'Other' } },
        [pscustomobject]@{ Label = 'VmsPath'; Value = [pscustomobject]@{ Edition = $validInstall.Edition; InstallRoot = $validInstall.InstallRoot; VmsPath = 17; ManagerPath = $validInstall.ManagerPath; Source = $validInstall.Source } }
    )
    foreach ($malformedInstall in $malformedInstalls) {
        Assert-DiscoveryInstallRejected -Install $malformedInstall.Value -ManagerPath $malformedInstallCase.ManagerPath -ArgumentsPath $malformedInstallCase.ArgumentsPath -Label $malformedInstall.Label
    }
    $invalidStoredManagerInstall = [pscustomobject]@{ Edition = $validInstall.Edition; InstallRoot = $validInstall.InstallRoot; VmsPath = $validInstall.VmsPath; ManagerPath = $unrelatedRegistryManager; Source = $validInstall.Source }
    Assert-DiscoveryInstallRejected -Install $invalidStoredManagerInstall -ManagerPath $unrelatedRegistryManager -ArgumentsPath $malformedInstallCase.ArgumentsPath -Label 'invalid stored ManagerPath'
    $invalidStoredManagerResult = Get-MuMuInstances -Install $invalidStoredManagerInstall
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus @($invalidStoredManagerResult)[0]) 'Invalid stored ManagerPath without an explicit manager was accepted.'
    Assert-True (@($invalidStoredManagerResult)[0].Message -match '(?i)invalid') 'Invalid stored ManagerPath error did not report the value as invalid.'
    $missingStoredManagerInstall = [pscustomobject]@{ Edition = $validInstall.Edition; InstallRoot = $validInstall.InstallRoot; VmsPath = $validInstall.VmsPath; Source = $validInstall.Source }
    $missingStoredManagerResult = Get-MuMuInstances -Install $missingStoredManagerInstall
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus @($missingStoredManagerResult)[0]) 'Missing stored ManagerPath was accepted.'
    Assert-True (@($missingStoredManagerResult)[0].Message -match '(?i)missing') 'Missing stored ManagerPath error did not distinguish the missing property from an invalid value.'
    $missingEditionInstall = [pscustomobject]@{ InstallRoot = $validInstall.InstallRoot; VmsPath = $validInstall.VmsPath; ManagerPath = $validInstall.ManagerPath; Source = $validInstall.Source }
    Assert-DiscoveryInstallRejected -Install $missingEditionInstall -ManagerPath $malformedInstallCase.ManagerPath -ArgumentsPath $malformedInstallCase.ArgumentsPath -Label 'missing Edition'
    $missingSourceInstall = [pscustomobject]@{ Edition = $validInstall.Edition; InstallRoot = $validInstall.InstallRoot; VmsPath = $validInstall.VmsPath; ManagerPath = $validInstall.ManagerPath }
    Assert-DiscoveryInstallRejected -Install $missingSourceInstall -ManagerPath $malformedInstallCase.ManagerPath -ArgumentsPath $malformedInstallCase.ArgumentsPath -Label 'missing Source'
    $missingInstallManager = [pscustomobject]@{ Edition = $validInstall.Edition; InstallRoot = $validInstall.InstallRoot; VmsPath = $validInstall.VmsPath; Source = $validInstall.Source }
    $missingStoredWithExplicit = Invoke-DiscoveryCall { Get-MuMuInstances -Install $missingInstallManager -ManagerPath $malformedInstallCase.ManagerPath }
    Assert-True (@($missingStoredWithExplicit).Count -eq 1 -and $null -eq @($missingStoredWithExplicit)[0].PSObject.Properties['Status']) 'Missing Install.ManagerPath did not accept a valid explicit manager.'
    $missingStoredWithoutExplicit = Invoke-DiscoveryCall { Get-MuMuInstances -Install $missingInstallManager -ManagerPath '' }
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $missingStoredWithoutExplicit) 'Missing Install.ManagerPath was accepted without an explicit manager.'

    $invalidEligible = [pscustomobject]@{ Index = 1; Eligible = 'maybe' }
    $invalidIndex = [pscustomobject]@{ Index = 'not-an-index'; Eligible = $true }
    $invalidEligibleResult = Resolve-SelectedInstance -Instances @($invalidEligible) -Selection $null
    $invalidIndexResult = Resolve-SelectedInstance -Instances @($invalidIndex) -Selection $null
    Assert-Equal 'CriticalError' $invalidEligibleResult.Status 'Invalid Eligible value was accepted.'
    Assert-True ($invalidEligibleResult.Message -match '(?i)eligible') 'Invalid Eligible error omitted field context.'
    Assert-Equal 'CriticalError' $invalidIndexResult.Status 'Invalid instance Index was accepted.'
    Assert-True ($invalidIndexResult.Message -match '(?i)index') 'Invalid Index error omitted field context.'

    $invalidAndroidInfo = [pscustomobject]@{ index = '1'; name = 'Invalid Android'; is_main = $false; is_process_started = $false; android_version = @('12.0') } | ConvertTo-Json -Compress
    $invalidAndroidCase = Invoke-DiscoveryManagerCase -Name 'invalid-android' -InfoJson $invalidAndroidInfo
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus @($invalidAndroidCase.Result)[0]) 'Invalid AndroidVersion was accepted.'
    Assert-True (@($invalidAndroidCase.Result)[0].Message -match '(?i)android') 'Invalid AndroidVersion error omitted field context.'

    $metadataConflictRoot = Join-Path $testRoot 'discovery negative\instance-vms-conflict'
    $metadataConflictVmsA = Join-Path $metadataConflictRoot 'vms-a'
    $metadataConflictVmsB = Join-Path $metadataConflictRoot 'vms-b'
    New-Item -ItemType Directory -Path $metadataConflictVmsA -Force | Out-Null
    New-Item -ItemType Directory -Path $metadataConflictVmsB -Force | Out-Null
    $metadataConflictInfo = [pscustomobject]@{ index = '1'; name = 'VMS conflict'; is_main = $false; is_process_started = $false; android_version = '12.0'; vms_path = $metadataConflictVmsA; vmsPath = $metadataConflictVmsB } | ConvertTo-Json -Compress
    $metadataConflictCase = Invoke-DiscoveryManagerCase -Name 'instance-vms-conflict' -InfoJson $metadataConflictInfo
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus @($metadataConflictCase.Result)[0]) 'Conflicting manager VMS fields were merged silently.'

    $missingManagerRoot = Join-Path $discoveryRoot 'missing-manager'
    $missingManagerVms = Join-Path $missingManagerRoot 'vms'
    New-Item -ItemType Directory -Path $missingManagerVms -Force | Out-Null
    $missingManager = Join-Path $missingManagerRoot 'shell\MuMuManager.exe'
    $missingManagerInstall = [pscustomobject]@{ Edition = 'Global'; InstallRoot = [IO.Path]::GetFullPath($missingManagerRoot); VmsPath = [IO.Path]::GetFullPath($missingManagerVms); ManagerPath = [IO.Path]::GetFullPath($missingManager); Source = 'Registry' }
    $missingManagerResult = Get-MuMuInstances -Install $missingManagerInstall -ManagerPath $missingManager
    Assert-Equal 'CriticalError' $missingManagerResult.Status 'Missing manager was accepted.'

    $missingVmsRoot = Join-Path $discoveryRoot 'missing-vms'
    New-Item -ItemType Directory -Path $missingVmsRoot -Force | Out-Null
    $missingVmsPath = Join-Path $missingVmsRoot 'missing\vms'
    $missingVmsInfo = [pscustomobject]@{ index = '1'; name = 'Fixture'; is_main = $false; is_process_started = $false; android_version = '12.0' } | ConvertTo-Json -Compress
    $missingVmsManager = New-DiscoveryManagerFixture -InstallRoot $missingVmsRoot -InfoJson $missingVmsInfo
    $missingVmsInstall = [pscustomobject]@{ Edition = 'Global'; InstallRoot = [IO.Path]::GetFullPath($missingVmsRoot); VmsPath = [IO.Path]::GetFullPath($missingVmsPath); ManagerPath = $missingVmsManager; Source = 'Process' }
    $missingVmsResult = Get-MuMuInstances -Install $missingVmsInstall -ManagerPath $missingVmsManager
    Assert-Equal 'CriticalError' $missingVmsResult.Status 'Missing VMS path was accepted.'
    Assert-True (-not [IO.File]::Exists((Join-Path (Split-Path -Parent $missingVmsManager) 'args.log'))) 'Missing VMS path reached the process runner.'

    $outsideManagerRoot = Join-Path $discoveryRoot 'outside-manager-install'
    $outsideManagerVms = Join-Path $outsideManagerRoot 'vms'
    New-Item -ItemType Directory -Path $outsideManagerVms -Force | Out-Null
    $outsideManager = New-DiscoveryManagerFixture -InstallRoot $outsideRoot -InfoJson $missingVmsInfo
    $outsideManagerInstall = [pscustomobject]@{ Edition = 'Global'; InstallRoot = [IO.Path]::GetFullPath($outsideManagerRoot); VmsPath = [IO.Path]::GetFullPath($outsideManagerVms); ManagerPath = $outsideManager; Source = 'Process' }
    $outsideManagerResult = Get-MuMuInstances -Install $outsideManagerInstall -ManagerPath $outsideManager
    Assert-Equal 'CriticalError' $outsideManagerResult.Status 'Process path outside the discovered install was accepted.'
    Assert-True (-not [IO.File]::Exists((Join-Path (Split-Path -Parent $outsideManager) 'args.log'))) 'Outside process path reached the process runner.'

    $linkedOutsideManagerRoot = Join-Path $discoveryRoot 'linked-outside-manager-install'
    $linkedOutsideManagerVms = Join-Path $linkedOutsideManagerRoot 'vms'
    New-Item -ItemType Directory -Path $linkedOutsideManagerVms -Force | Out-Null
    $linkedManagerDirectory = Join-Path $linkedOutsideManagerRoot 'linked-manager'
    New-Item -ItemType Junction -Path $linkedManagerDirectory -Target (Split-Path -Parent $outsideManager) | Out-Null
    $linkedOutsideManager = Join-Path $linkedManagerDirectory 'MuMuManager.exe'
    $linkedOutsideManagerInstall = [pscustomobject]@{ Edition = 'Global'; InstallRoot = [IO.Path]::GetFullPath($linkedOutsideManagerRoot); VmsPath = [IO.Path]::GetFullPath($linkedOutsideManagerVms); ManagerPath = [IO.Path]::GetFullPath($linkedOutsideManager); Source = 'Process' }
    $linkedOutsideManagerResult = Get-MuMuInstances -Install $linkedOutsideManagerInstall -ManagerPath $linkedOutsideManager
    $linkedOutsideManagerStatus = 'Accepted'
    if ($null -ne $linkedOutsideManagerResult.PSObject.Properties['Status']) {
        $linkedOutsideManagerStatus = $linkedOutsideManagerResult.Status
    }
    Assert-Equal 'CriticalError' $linkedOutsideManagerStatus 'Junction-resolved process path outside the discovered install was accepted.'
    Assert-True (-not [IO.File]::Exists((Join-Path (Split-Path -Parent $outsideManager) 'args.log'))) 'Junction-resolved outside process path reached the process runner.'

    $staleRoot = Join-Path $discoveryRoot 'stale-metadata'
    $staleSharedVms = Join-Path $staleRoot 'vms'
    New-Item -ItemType Directory -Path $staleSharedVms -Force | Out-Null
    $staleMissingVms = Join-Path $staleRoot 'missing-vms'
    $staleInfo = ([pscustomobject]@{ index = '3'; name = 'Stale'; is_main = $false; is_process_started = $false; android_version = '12.0'; vms_path = $staleMissingVms }) | ConvertTo-Json -Compress
    $staleManager = New-DiscoveryManagerFixture -InstallRoot $staleRoot -InfoJson $staleInfo
    $staleInstall = [pscustomobject]@{ Edition = 'Global'; InstallRoot = [IO.Path]::GetFullPath($staleRoot); VmsPath = [IO.Path]::GetFullPath($staleSharedVms); ManagerPath = $staleManager; Source = 'Process' }
    $staleResult = Get-MuMuInstances -Install $staleInstall -ManagerPath $staleManager
    Assert-Equal 'CriticalError' $staleResult.Status 'Stale manager VMS metadata was accepted.'

    $unrelatedHelperPath = Join-Path $outsideRoot 'tools\helper.exe'
    $unrelatedHelperDirectory = Split-Path -Parent $unrelatedHelperPath
    New-Item -ItemType Directory -Path $unrelatedHelperDirectory -Force | Out-Null
    [IO.File]::Copy($script:discoveryManagerTemplatePath, $unrelatedHelperPath, $true)
    $unrelatedHelperInstallRoot = Join-Path $discoveryRoot 'unrelated-helper-install'
    $unrelatedHelperVms = Join-Path $unrelatedHelperInstallRoot 'vms'
    New-Item -ItemType Directory -Path $unrelatedHelperVms -Force | Out-Null
    $insideUnrelatedHelperPath = Join-Path $unrelatedHelperInstallRoot 'tools\helper.exe'
    $insideUnrelatedHelperDirectory = Split-Path -Parent $insideUnrelatedHelperPath
    New-Item -ItemType Directory -Path $insideUnrelatedHelperDirectory -Force | Out-Null
    [IO.File]::Copy($script:discoveryManagerTemplatePath, $insideUnrelatedHelperPath, $true)
    $unrelatedHelperInstall = [pscustomobject]@{ Edition = 'Global'; InstallRoot = [IO.Path]::GetFullPath($unrelatedHelperInstallRoot); VmsPath = [IO.Path]::GetFullPath($unrelatedHelperVms); ManagerPath = [IO.Path]::GetFullPath($insideUnrelatedHelperPath); Source = 'Process' }
    $unrelatedHelperResult = Get-MuMuInstances -Install $unrelatedHelperInstall -ManagerPath $insideUnrelatedHelperPath
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $unrelatedHelperResult) 'Unrelated executable was accepted as MuMuManager.exe.'
    Assert-True (-not [IO.File]::Exists((Join-Path $insideUnrelatedHelperDirectory 'args.log'))) 'Unrelated executable reached the process runner.'

    $unrelatedProcessResult = @(Find-MuMuInstallations -Edition 'All' -RegistryRoots @() -ProcessSnapshot @([pscustomobject]@{ ExecutablePath = $unrelatedHelperPath; CommandLine = '"' + $unrelatedHelperPath + '"' }) -FallbackRoots @())
    Assert-Equal 0 $unrelatedProcessResult.Count 'Unrelated process record created a MuMu installation.'

    $missingProcessRoot = Join-Path $discoveryRoot 'missing-process-manager'
    $missingProcessVms = Join-Path $missingProcessRoot 'vms'
    New-Item -ItemType Directory -Path $missingProcessVms -Force | Out-Null
    $missingProcessManager = Join-Path $missingProcessRoot 'shell\MuMuManager.exe'
    $missingProcessResult = Find-MuMuInstallations -Edition 'All' -RegistryRoots @() -ProcessSnapshot @([pscustomobject]@{ ExecutablePath = $missingProcessManager; CommandLine = '"' + $missingProcessManager + '"'; InstallRoot = $missingProcessRoot }) -FallbackRoots @()
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $missingProcessResult) 'Missing candidate manager process was silently ignored.'
    Assert-True (-not [IO.File]::Exists((Join-Path (Split-Path -Parent $missingProcessManager) 'args.log'))) 'Missing candidate manager reached the process runner.'

    $outsideProcessResult = Find-MuMuInstallations -Edition 'All' -RegistryRoots @() -ProcessSnapshot @([pscustomobject]@{ ExecutablePath = $outsideFixture.ManagerPath; CommandLine = '"' + $outsideFixture.ManagerPath + '"'; InstallRoot = $globalFixture.InstallRoot }) -FallbackRoots @()
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $outsideProcessResult) 'Outside candidate manager process was silently ignored.'
    Assert-True (-not [IO.File]::Exists((Join-Path (Split-Path -Parent $outsideFixture.ManagerPath) 'args.log'))) 'Outside candidate manager reached the process runner.'

    $playerRoot = Join-Path $discoveryRoot 'Player Process\MuMu Global'
    $playerVms = Join-Path $playerRoot 'vms'
    $playerShell = Join-Path $playerRoot 'shell'
    New-Item -ItemType Directory -Path $playerVms -Force | Out-Null
    New-Item -ItemType Directory -Path $playerShell -Force | Out-Null
    $playerManager = Join-Path $playerShell 'MuMuManager.exe'
    $playerExecutable = Join-Path $playerShell 'MuMuPlayer.exe'
    [IO.File]::WriteAllText($playerManager, 'player layout manager fixture')
    [IO.File]::WriteAllText($playerExecutable, 'player layout fixture')
    $playerProcessResult = @(Find-MuMuInstallations -Edition 'All' -RegistryRoots @() -ProcessSnapshot @([pscustomobject]@{ ExecutablePath = $playerExecutable; CommandLine = '"' + $playerExecutable + '"' }) -FallbackRoots @())
    Assert-Equal 1 @($playerProcessResult | Where-Object { $_.InstallRoot -eq $playerRoot }).Count 'MuMuPlayer.exe process was not discovered.'
    Assert-Equal $playerManager @($playerProcessResult | Where-Object { $_.InstallRoot -eq $playerRoot })[0].ManagerPath 'MuMuPlayer.exe process did not locate its manager.'

    $commandPlayerRoot = Join-Path $discoveryRoot 'Command Player\MuMu Global'
    $commandPlayerVms = Join-Path $commandPlayerRoot 'vms'
    $commandPlayerShell = Join-Path $commandPlayerRoot 'shell'
    New-Item -ItemType Directory -Path $commandPlayerVms -Force | Out-Null
    New-Item -ItemType Directory -Path $commandPlayerShell -Force | Out-Null
    $commandPlayerManager = Join-Path $commandPlayerShell 'MuMuManager.exe'
    $commandPlayerExecutable = Join-Path $commandPlayerShell 'MuMuPlayer.exe'
    [IO.File]::WriteAllText($commandPlayerManager, 'command player manager fixture')
    [IO.File]::WriteAllText($commandPlayerExecutable, 'command player fixture')
    $commandPlayerResult = @(Find-MuMuInstallations -Edition 'All' -RegistryRoots @() -ProcessSnapshot @([pscustomobject]@{ CommandLine = '"' + $commandPlayerExecutable + '" --vms_path "' + $commandPlayerVms + '"' }) -FallbackRoots @())
    Assert-Equal 1 @($commandPlayerResult | Where-Object { $_.InstallRoot -eq $commandPlayerRoot }).Count 'Command-line-only MuMuPlayer.exe process was not discovered.'

    $outsidePlayerResult = Find-MuMuInstallations -Edition 'All' -RegistryRoots @() -ProcessSnapshot @([pscustomobject]@{ ExecutablePath = $playerExecutable; CommandLine = '"' + $playerExecutable + '"'; InstallRoot = $commandPlayerRoot }) -FallbackRoots @()
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $outsidePlayerResult) 'Out-of-root MuMuPlayer.exe process was accepted.'
    $outsideHelperWithManagerResult = Find-MuMuInstallations -Edition 'All' -RegistryRoots @() -ProcessSnapshot @([pscustomobject]@{ ExecutablePath = $unrelatedHelperPath; CommandLine = '"' + $unrelatedHelperPath + '"'; InstallRoot = $playerRoot; ManagerPath = $playerManager; Edition = 'Global' }) -FallbackRoots @()
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $outsideHelperWithManagerResult) 'Non-manager outside path paired with a valid manager was accepted.'

    $nestedRoot = Join-Path $discoveryRoot 'nested-layout\MuMu Global'
    $nestedVms = Join-Path $nestedRoot 'vms'
    $nestedManager = Join-Path $nestedRoot 'nx_main\shell\MuMuManager.exe'
    New-Item -ItemType Directory -Path $nestedVms -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path -Parent $nestedManager) -Force | Out-Null
    [IO.File]::WriteAllText($nestedManager, 'nested manager fixture')
    $nestedResult = @(Find-MuMuInstallations -Edition 'All' -RegistryRoots @() -ProcessSnapshot @([pscustomobject]@{ ExecutablePath = $nestedManager; CommandLine = '"' + $nestedManager + '"'; Edition = 'Global' }) -FallbackRoots @())
    Assert-Equal 1 @($nestedResult | Where-Object { $_.InstallRoot -eq $nestedRoot }).Count 'Nested manager layout did not preserve the installation root.'

    $managerDirectoryFixture = Join-Path $unrelatedHelperInstallRoot 'shell\MuMuManager.exe'
    New-Item -ItemType Directory -Path $managerDirectoryFixture -Force | Out-Null
    $managerDirectoryInstall = [pscustomobject]@{ Edition = 'Global'; InstallRoot = [IO.Path]::GetFullPath($unrelatedHelperInstallRoot); VmsPath = [IO.Path]::GetFullPath($unrelatedHelperVms); ManagerPath = [IO.Path]::GetFullPath($managerDirectoryFixture); Source = 'Process' }
    $managerDirectoryResult = Get-MuMuInstances -Install $managerDirectoryInstall -ManagerPath $managerDirectoryFixture
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $managerDirectoryResult) 'Directory named MuMuManager.exe was accepted as a manager file.'

    $cycleRoot = Join-Path $discoveryRoot 'Reparse Loop'
    $cycleA = Join-Path $cycleRoot 'loop-a'
    $cycleB = Join-Path $cycleRoot 'loop-b'
    New-Item -ItemType Directory -Path $cycleB -Force | Out-Null
    New-Item -ItemType Junction -Path $cycleA -Target $cycleB | Out-Null
    Remove-Item -LiteralPath $cycleB -Recurse -Force
    New-Item -ItemType Junction -Path $cycleB -Target $cycleA | Out-Null
    $cycleManagerPath = Join-Path $cycleA 'MuMuManager.exe'
    Assert-True ($null -eq (Get-ToolkitResolvedPath -Path $cycleManagerPath)) 'Reparse loop did not fail closed.'
    $isolatedProfileRoot = [IO.Path]::GetFullPath($testRoot)
    Assert-True ($env:APPDATA.StartsWith($isolatedProfileRoot, [StringComparison]::OrdinalIgnoreCase)) 'Discovery tests restored the real APPDATA profile before completion.'
    if (-not [string]::IsNullOrWhiteSpace($previousAppData)) {
        Assert-True (-not $env:APPDATA.Equals($previousAppData, [StringComparison]::OrdinalIgnoreCase)) 'Discovery tests used the host APPDATA profile.'
    }
}

function New-SafetyInstallFixture {
    param(
        [string]$InstallRoot,
        [int[]]$InstanceIndexes
    )

    $root = [IO.Path]::GetFullPath($InstallRoot)
    $vms = Join-Path $root 'vms'
    New-Item -ItemType Directory -Path $vms -Force | Out-Null
    foreach ($instanceIndex in $InstanceIndexes) {
        $instanceRoot = Join-Path $vms ([string]$instanceIndex)
        New-Item -ItemType Directory -Path $instanceRoot -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $instanceRoot 'system.img'), ('instance ' + $instanceIndex + ' disk payload'))
    }
    $managerDirectory = Join-Path $root 'shell'
    New-Item -ItemType Directory -Path $managerDirectory -Force | Out-Null
    $managerPath = Join-Path $managerDirectory 'MuMuManager.exe'
    [IO.File]::WriteAllText($managerPath, 'safety clone manager fixture')
    return [pscustomobject]@{
        InstallRoot = $root
        VmsPath = [IO.Path]::GetFullPath($vms)
        ManagerPath = [IO.Path]::GetFullPath($managerPath)
    }
}

function Get-SafetyResultStatus {
    param([object]$Result)

    if ($null -ne $Result -and $null -ne $Result.PSObject -and $null -ne $Result.PSObject.Properties['Status']) {
        return [string]$Result.Status
    }
    return 'Thrown'
}

function Invoke-SafetyCall {
    param([scriptblock]$Action)

    try {
        return & $Action
    }
    catch {
        return [pscustomobject]@{
            Status = 'Thrown'
            Message = $_.Exception.Message
        }
    }
}

function Test-SafetyNotElevated {
    param([object]$Result)

    if ($null -eq $Result.PSObject -or $null -eq $Result.PSObject.Properties['Data']) {
        return $true
    }
    $data = $Result.Data
    if ($null -eq $data -or $null -eq $data.PSObject.Properties['Elevated']) {
        return $true
    }
    return ($data.Elevated -ne $true)
}

function New-SafetyManagerState {
    param(
        [string]$VmsPath,
        [bool]$Running = $true
    )

    return @{
        VmsPath = $VmsPath
        Calls = @()
        Instances = @(
            [pscustomobject]@{ Index = 0; Name = 'Base'; IsMain = $true; Running = $false; Android = '12.0'; VmsPath = '' },
            [pscustomobject]@{ Index = 2; Name = 'Other'; IsMain = $false; Running = $false; Android = '12.0'; VmsPath = '' },
            [pscustomobject]@{ Index = 3; Name = 'Target'; IsMain = $false; Running = $Running; Android = '12.0'; VmsPath = '' }
        )
        InfoExitCode = 0
        InfoIndexExitCode = 0
        InfoIndexText = ''
        ControlExitCode = 0
        CloneExitCode = 0
        ShutdownSettles = $true
        CloneIndex = 4
        CloneName = 'Target clone'
        CloneAndroid = '12.0'
        CloneCreatesDisk = $true
        CloneVmsPath = ''
    }
}

function New-SafetyManagerRunner {
    param([hashtable]$State)

    return {
        param($ActualFilePath, $ActualArgumentList)
        $State.Calls += ,@($ActualArgumentList)
        $command = [string]$ActualArgumentList[0]
        if ($command -eq 'info') {
            $requested = [string]$ActualArgumentList[2]
            if ($requested -ne 'all') {
                if ($State.InfoIndexExitCode -ne 0) {
                    return [pscustomobject]@{ ExitCode = $State.InfoIndexExitCode; Text = '{"error_code":1}' }
                }
                if (-not [string]::IsNullOrWhiteSpace($State.InfoIndexText)) {
                    return [pscustomobject]@{ ExitCode = 0; Text = $State.InfoIndexText }
                }
            }
            if ($State.InfoExitCode -ne 0) {
                return [pscustomobject]@{ ExitCode = $State.InfoExitCode; Text = '{"error_code":1}' }
            }
            $selected = @($State.Instances | Where-Object { $requested -eq 'all' -or [string]$_.Index -ceq $requested })
            if ($selected.Count -eq 0) {
                return [pscustomobject]@{ ExitCode = 1; Text = '{"error_code":1}' }
            }
            $records = @()
            foreach ($selectedInstance in $selected) {
                $record = [ordered]@{
                    index              = [string]$selectedInstance.Index
                    name               = $selectedInstance.Name
                    is_main            = [string]$selectedInstance.IsMain
                    is_process_started = [string]$selectedInstance.Running
                    android_version    = $selectedInstance.Android
                }
                if (-not [string]::IsNullOrWhiteSpace($selectedInstance.VmsPath)) {
                    $record['vms_path'] = [string]$selectedInstance.VmsPath
                }
                $records += [pscustomobject]$record
            }
            return [pscustomobject]@{ ExitCode = 0; Text = (ConvertTo-Json -InputObject @($records) -Depth 4 -Compress) }
        }
        if ($command -eq 'control') {
            if ($State.ControlExitCode -ne 0) {
                return [pscustomobject]@{ ExitCode = $State.ControlExitCode; Text = '{"error_code":1}' }
            }
            if ($State.ShutdownSettles) {
                foreach ($controlInstance in $State.Instances) {
                    if ([string]$controlInstance.Index -ceq [string]$ActualArgumentList[2]) {
                        $controlInstance.Running = $false
                    }
                }
            }
            return [pscustomobject]@{ ExitCode = 0; Text = '{"error_code":0}' }
        }
        if ($command -eq 'clone') {
            if ($State.CloneExitCode -ne 0) {
                return [pscustomobject]@{ ExitCode = $State.CloneExitCode; Text = '{"error_code":1}' }
            }
            $cloneVmsPath = [string]$State.CloneVmsPath
            if ([string]::IsNullOrWhiteSpace($cloneVmsPath)) {
                $cloneVmsPath = [string]$State.VmsPath
            }
            $cloneRoot = Join-Path $cloneVmsPath ([string]$State.CloneIndex)
            New-Item -ItemType Directory -Path $cloneRoot -Force | Out-Null
            if ($State.CloneCreatesDisk) {
                [IO.File]::WriteAllText((Join-Path $cloneRoot 'system.img'), 'clone disk payload')
            }
            $State.Instances = @($State.Instances) + [pscustomobject]@{
                Index = [int]$State.CloneIndex
                Name = $State.CloneName
                IsMain = $false
                Running = $false
                Android = $State.CloneAndroid
                VmsPath = [string]$State.CloneVmsPath
            }
            return [pscustomobject]@{ ExitCode = 0; Text = '{"error_code":0}' }
        }
        return [pscustomobject]@{ ExitCode = 1; Text = '{"error_code":1}' }
    }.GetNewClosure()
}

function New-SafetyCloneJournal {
    param(
        [string]$Root,
        [object]$Instance
    )

    return New-OperationJournal -Root $Root -Operation 'Root12' -Instance $Instance
}

function Assert-SafetyFailedClone {
    param(
        [object]$Result,
        [object]$Journal,
        [string]$Message
    )

    Assert-Equal 'CriticalError' $Result.Status $Message
    Assert-Equal 'Failed' $Journal.State "$Message The failure was not journaled."
    $reopened = Get-OperationJournal -Path $Journal.JournalPath
    Assert-Equal 'Failed' $reopened.State "$Message The failure was not persisted."
    Assert-Equal 'CriticalError' $reopened.Result.Status "$Message The persisted result status is invalid."
    Assert-True ($reopened.Result.Message -ceq $Result.Message) "$Message The persisted message changed."
    Assert-True (@($reopened.Checkpoints).Count -ge 1) "$Message No failure checkpoint was recorded."
}

function Invoke-SafetyTests {
    foreach ($commandName in @('Test-ToolkitAdministrator', 'Invoke-ElevatedToolkitAction', 'New-InstanceClone', 'Backup-ChangedFile', 'Restore-BackupFile')) {
        Assert-True ($null -ne (Get-Command $commandName -CommandType Function -ErrorAction SilentlyContinue)) "Safety command is unavailable: $commandName"
    }
    Assert-True (Test-Path -LiteralPath $elevationScriptPath -PathType Leaf) 'src/Elevation.ps1 does not exist.'
    Assert-True (Test-Path -LiteralPath $backupScriptPath -PathType Leaf) 'src/Backup.ps1 does not exist.'

    $preflight = Test-ToolkitAdministrator
    Assert-True ($preflight -is [bool]) 'Administrator preflight did not return a boolean.'

    $elevationSource = [IO.File]::ReadAllText($elevationScriptPath)
    $backupSource = [IO.File]::ReadAllText($backupScriptPath)
    Assert-True ($elevationSource -match 'Start-Process') 'Elevation does not launch a direct child process.'
    Assert-True ($elevationSource -match "'RunAs'") 'Elevation does not use the runas shell verb.'
    foreach ($forbidden in @(
            'schtasks',
            'ScheduledTask',
            'Unregister-ScheduledTask',
            'EnableLUA',
            'ConsentPromptBehavior',
            'Set-MpPreference',
            'takeown',
            'icacls',
            'Set-Acl',
            'Get-Acl',
            'Set-ItemProperty',
            'Set-ExecutionPolicy',
            'ExecutionPolicy Bypass',
            'Invoke-Expression',
            'ScriptBlock]::Create',
            'Add-Type',
            'DownloadString',
            'Invoke-WebRequest',
            'Invoke-RestMethod',
            'New-Service'
        )) {
        Assert-True ($elevationSource -notmatch [regex]::Escape($forbidden)) "Elevation source uses a forbidden construct: $forbidden"
    }
    foreach ($forbidden in @('icacls', 'Set-Acl', 'Get-Acl', 'takeown', 'Set-ItemProperty', 'Set-ExecutionPolicy', 'Invoke-Expression', 'ScriptBlock]::Create', 'Add-Type', 'DownloadString', 'Invoke-WebRequest')) {
        Assert-True ($backupSource -notmatch [regex]::Escape($forbidden)) "Backup source uses a forbidden construct: $forbidden"
    }

    $fakeScript = Join-Path $testRoot 'elevated child action.ps1'
    [IO.File]::WriteAllText($fakeScript, 'exit 0')
    $elevationState = @{ Calls = @() }
    $fakeDeniedRunner = {
        param($ActualFilePath, $ActualArgumentList, $ActualVerb)
        $elevationState.Calls += ,@([pscustomobject]@{
                FilePath = $ActualFilePath
                Arguments = $ActualArgumentList
                Verb = $ActualVerb
            })
        throw (New-Object ComponentModel.Win32Exception 1223)
    }.GetNewClosure()

    $denied = Invoke-ElevatedToolkitAction -ScriptPath $fakeScript -Arguments @('-Fixture', 'Denied') -Runner $fakeDeniedRunner
    Assert-True ($denied.Status -eq 'CriticalError') 'Denied UAC elevation was treated as success.'
    Assert-True ($denied.Message -match '(?i)denied|cancelled') 'Denied UAC elevation did not report a permission error.'

    $elevationCall = @($elevationState.Calls)[0]
    Assert-Equal 'powershell.exe' ([IO.Path]::GetFileName($elevationCall.FilePath)) 'Elevation did not launch PowerShell directly.'
    Assert-Equal 'RunAs' $elevationCall.Verb 'Elevation did not request the direct UAC runas verb.'
    $elevationArguments = [string[]]@($elevationCall.Arguments)
    Assert-True ($elevationArguments -ccontains '-NoProfile') 'Elevated child was launched without -NoProfile.'
    $executionPolicyIndex = [array]::IndexOf($elevationArguments, '-ExecutionPolicy')
    Assert-True ($executionPolicyIndex -ge 0) 'Elevated child was launched without -ExecutionPolicy.'
    Assert-Equal 'RemoteSigned' $elevationArguments[$executionPolicyIndex + 1] 'Elevated child execution policy is invalid.'
    $entryIndex = [array]::IndexOf($elevationArguments, '-File')
    Assert-True ($entryIndex -ge 0) 'Elevated child was launched without a file entry point.'
    Assert-True ([string]::Equals($elevationArguments[$entryIndex + 1], [IO.Path]::GetFullPath($elevationScriptPath), [StringComparison]::OrdinalIgnoreCase)) 'Elevated child did not use the toolkit elevation entry point.'
    $payloadIndex = [array]::IndexOf($elevationArguments, '-ChildAction')
    Assert-True ($payloadIndex -ge 0) 'Elevated child did not receive a structured child action payload.'
    $payloadJson = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($elevationArguments[$payloadIndex + 1]))
    $payload = $payloadJson | ConvertFrom-Json
    Assert-Equal $fakeScript $payload.Action 'Elevated child payload changed the action path.'
    Assert-Equal '-Fixture|Denied' (@($payload.Arguments) -join '|') 'Elevated child payload changed the argument array.'

    $nonElevatedRunner = {
        param($ActualFilePath, $ActualArgumentList, $ActualVerb)
        [pscustomobject]@{ ExitCode = 1223; Text = '' }
    }
    $nonElevated = Invoke-ElevatedToolkitAction -ScriptPath $fakeScript -Arguments @('-Fixture', 'NotElevated') -Runner $nonElevatedRunner
    Assert-Equal 'CriticalError' $nonElevated.Status 'A non-elevated child was treated as success.'
    Assert-True ($nonElevated.Message -match '(?i)administrator') 'Non-elevated child did not report an elevation verification failure.'
    Assert-Equal $false $nonElevated.Data.Elevated 'Non-elevated child was reported as elevated.'

    $successRunner = {
        param($ActualFilePath, $ActualArgumentList, $ActualVerb)
        [pscustomobject]@{ ExitCode = 0; Text = '' }
    }
    $elevated = Invoke-ElevatedToolkitAction -ScriptPath $fakeScript -Arguments @('-Fixture', 'Granted') -Runner $successRunner
    Assert-Equal 'Success' $elevated.Status 'A verified elevated child action was rejected.'
    Assert-Equal 0 $elevated.Data.ExitCode 'Elevated child exit code was not preserved.'
    Assert-Equal $true $elevated.Data.Elevated 'Verified elevated child was not reported as elevated.'
    Assert-Equal ($preflight) $elevated.Data.AlreadyElevated 'The caller token preflight was not reported.'

    $failureRunner = {
        param($ActualFilePath, $ActualArgumentList, $ActualVerb)
        [pscustomobject]@{ ExitCode = 3; Text = '' }
    }
    $failedAction = Invoke-ElevatedToolkitAction -ScriptPath $fakeScript -Arguments @('-Fixture', 'Failed') -Runner $failureRunner
    Assert-Equal 'CriticalError' $failedAction.Status 'A failed elevated child action was treated as success.'
    Assert-Equal 3 $failedAction.Data.ExitCode 'Failed elevated child exit code was not preserved.'
    Assert-Equal $false $failedAction.Data.Elevated 'A failed elevated child action was reported as elevated.'

    $noExitCodeRunner = {
        param($ActualFilePath, $ActualArgumentList, $ActualVerb)
        [pscustomobject]@{ Text = 'no exit code' }
    }
    $noExitCode = Invoke-SafetyCall { Invoke-ElevatedToolkitAction -ScriptPath $fakeScript -Arguments @('-Fixture', 'NoExitCode') -Runner $noExitCodeRunner }
    Assert-Equal 'CriticalError' (Get-SafetyResultStatus $noExitCode) 'An elevated child without an exit code was accepted.'
    Assert-True (Test-SafetyNotElevated -Result $noExitCode) 'An elevated child without an exit code was reported as elevated.'

    $textExitCodeRunner = {
        param($ActualFilePath, $ActualArgumentList, $ActualVerb)
        [pscustomobject]@{ ExitCode = 'not-a-number'; Text = '' }
    }
    $textExitCode = Invoke-SafetyCall { Invoke-ElevatedToolkitAction -ScriptPath $fakeScript -Arguments @('-Fixture', 'TextExitCode') -Runner $textExitCodeRunner }
    Assert-Equal 'CriticalError' (Get-SafetyResultStatus $textExitCode) 'A nonnumeric elevated child exit code was accepted.'
    Assert-True (Test-SafetyNotElevated -Result $textExitCode) 'A nonnumeric elevated child exit code was reported as elevated.'

    $nullOutcomeRunner = {
        param($ActualFilePath, $ActualArgumentList, $ActualVerb)
        $null
    }
    $nullOutcome = Invoke-SafetyCall { Invoke-ElevatedToolkitAction -ScriptPath $fakeScript -Arguments @('-Fixture', 'NullOutcome') -Runner $nullOutcomeRunner }
    Assert-Equal 'CriticalError' (Get-SafetyResultStatus $nullOutcome) 'An empty elevated child outcome was accepted.'

    foreach ($elevationCase in @($nonElevated, $failedAction, $noExitCode, $textExitCode, $nullOutcome, $denied)) {
        Assert-True (Test-SafetyNotElevated -Result $elevationCase) 'A failed or unverified elevation reported Elevated true.'
    }

    $emptyRunnerState = @{ Count = 0 }
    $unreachableRunner = {
        param($ActualFilePath, $ActualArgumentList, $ActualVerb)
        $emptyRunnerState.Count++
        [pscustomobject]@{ ExitCode = 0; Text = '' }
    }.GetNewClosure()
    $blankScript = Invoke-ElevatedToolkitAction -ScriptPath '   ' -Arguments @() -Runner $unreachableRunner
    Assert-Equal 'CriticalError' $blankScript.Status 'A blank elevated action path was accepted.'
    $missingScript = Invoke-ElevatedToolkitAction -ScriptPath (Join-Path $testRoot 'missing action.ps1') -Arguments @() -Runner $unreachableRunner
    Assert-Equal 'CriticalError' $missingScript.Status 'A missing elevated action path was accepted.'
    $nonScriptAction = Join-Path $testRoot 'not-a-script.txt'
    [IO.File]::WriteAllText($nonScriptAction, 'fixture')
    $wrongTypeScript = Invoke-ElevatedToolkitAction -ScriptPath $nonScriptAction -Arguments @() -Runner $unreachableRunner
    Assert-Equal 'CriticalError' $wrongTypeScript.Status 'A non-PowerShell elevated action was accepted.'
    $actionDirectory = Join-Path $testRoot 'action directory.ps1'
    New-Item -ItemType Directory -Path $actionDirectory -Force | Out-Null
    $directoryScript = Invoke-ElevatedToolkitAction -ScriptPath $actionDirectory -Arguments @() -Runner $unreachableRunner
    Assert-Equal 'CriticalError' $directoryScript.Status 'An elevated action directory was accepted.'
    Assert-Equal 0 $emptyRunnerState.Count 'An invalid elevated action request reached the process runner.'

    $childActionScript = Join-Path $testRoot 'child gate action.ps1'
    $childMarkerPath = Join-Path $testRoot 'child gate marker.txt'
    [IO.File]::WriteAllText($childActionScript, ("[IO.File]::WriteAllText('" + $childMarkerPath.Replace("'", "''") + "', 'ran')"))
    $childArgumentList = @(New-ToolkitElevatedArgumentList -ScriptPath $childActionScript -Arguments @('-Fixture', 'Child'))
    $childResult = Invoke-CheckedProcess -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $childArgumentList
    if ($preflight) {
        Assert-Equal 0 $childResult.ExitCode 'The elevated child gate rejected an elevated parent.'
        Assert-True ([IO.File]::Exists($childMarkerPath)) 'The elevated child did not run the action script.'
    }
    else {
        Assert-Equal 1223 $childResult.ExitCode 'The non-elevated child gate did not return the elevation failure code.'
        Assert-True (-not [IO.File]::Exists($childMarkerPath)) 'The non-elevated child gate ran the action script.'
    }
    if ([IO.File]::Exists($childMarkerPath)) {
        [IO.File]::Delete($childMarkerPath)
    }
    $childArgumentList = @(New-ToolkitElevatedArgumentList -ScriptPath $childActionScript -Arguments @('-Fixture', 'Child'))
    $childTextArgumentList = [string[]]@($childArgumentList)
    $childTextArgumentList[$childTextArgumentList.Length - 1] = 'not-base64'
    $childCorrupt = Invoke-CheckedProcess -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $childTextArgumentList
    Assert-True ($childCorrupt.ExitCode -ne 0) 'A corrupt child payload returned success.'
    Assert-True (-not [IO.File]::Exists($childMarkerPath)) 'A corrupt child payload ran the action script.'

    $cloneRoot = Join-Path $testRoot 'clone fixtures'
    $cloneFixture = New-SafetyInstallFixture -InstallRoot (Join-Path $cloneRoot 'MuMu Global') -InstanceIndexes @(0, 2, 3)
    $cloneJournalRoot = Join-Path $cloneRoot 'journal'
    New-Item -ItemType Directory -Path $cloneJournalRoot -Force | Out-Null
    $fixtureInstance = [pscustomobject]@{
        Index = 3
        Name = 'Target'
        AndroidVersion = '12.0'
        Install = [pscustomobject]@{
            Edition = 'Global'
            InstallRoot = $cloneFixture.InstallRoot
            VmsPath = $cloneFixture.VmsPath
            ManagerPath = $cloneFixture.ManagerPath
            Source = 'Process'
        }
        Running = $true
        RootSetting = $false
        Eligible = $true
        IneligibleReason = $null
    }
    $fixtureManager = $cloneFixture.ManagerPath

    $cloneState = New-SafetyManagerState -VmsPath $cloneFixture.VmsPath
    $fakeFailingCloneRunner = New-SafetyManagerRunner -State $cloneState
    $cloneState.CloneCreatesDisk = $false
    $fixtureJournal = New-SafetyCloneJournal -Root $cloneJournalRoot -Instance $fixtureInstance
    $clone = New-InstanceClone -ManagerPath $fixtureManager -Instance $fixtureInstance -Journal $fixtureJournal -Runner $fakeFailingCloneRunner
    Assert-True ($clone.Status -eq 'CriticalError') 'Unverified clone was accepted.'
    Assert-SafetyFailedClone -Result $clone -Journal $fixtureJournal -Message 'A clone that does not boot was accepted.'

    $runningState = New-SafetyManagerState -VmsPath $cloneFixture.VmsPath
    $runningRunner = New-SafetyManagerRunner -State $runningState
    $runningJournal = New-SafetyCloneJournal -Root $cloneJournalRoot -Instance $fixtureInstance
    $runningClone = New-InstanceClone -ManagerPath $fixtureManager -Instance $fixtureInstance -Journal $runningJournal -Runner $runningRunner
    $cloneCommands = @($runningState.Calls | ForEach-Object { @($_) -join '|' })
    Assert-Equal 'Success' $runningClone.Status 'A verified clone of a running instance was rejected.'
    Assert-True ($cloneCommands -contains 'control|-v|3|shutdown') 'A running instance was not stopped before the clone.'
    Assert-True ((@($cloneCommands).IndexOf('control|-v|3|shutdown')) -lt (@($cloneCommands).IndexOf('clone|-v|3|-n|1'))) 'The clone was invoked before the shutdown request.'
    Assert-True ($cloneCommands -contains 'clone|-v|3|-n|1') 'The clone command was not issued with structured arguments.'
    Assert-Equal 4 $runningClone.Data.CloneIndex 'The clone index was not identified.'
    Assert-Equal 3 $runningClone.Data.SourceIndex 'The source instance index changed.'
    Assert-Equal 'Target clone' $runningClone.Data.CloneName 'The verified clone name is invalid.'
    Assert-Equal '12.0' $runningClone.Data.AndroidVersion 'The verified clone Android version is invalid.'
    Assert-True ($runningClone.Data.DiskBytes -gt 0) 'The verified clone disk size is invalid.'
    Assert-Equal ([IO.Path]::GetFullPath((Join-Path $cloneFixture.VmsPath '4'))) $runningClone.Data.VmsPath 'The verified clone VMS root is invalid.'
    $cloneDataProperties = @($runningClone.Data.PSObject.Properties | ForEach-Object { $_.Name })
    Assert-True ($cloneDataProperties -cnotcontains 'BootReady') 'The clone record still exposes a BootReady field.'
    Assert-Equal $true $runningClone.Data.StaticReady 'The clone static-readiness field is invalid.'
    Assert-Equal $false $runningClone.Data.ColdBootVerified 'The clone record claimed a cold boot was verified.'
    Assert-True ($runningClone.Message -match '(?i)static|verif') 'The clone success message did not describe static verification.'
    $reopenedCloneJournal = Get-OperationJournal -Path $runningJournal.JournalPath
    Assert-Equal 'Running' $reopenedCloneJournal.State 'A verified clone closed the operation journal.'
    $cloneCheckpoint = @($reopenedCloneJournal.Checkpoints)[-1]
    Assert-Equal 4 $cloneCheckpoint.Data.CloneIndex 'The clone index was not recorded in the journal.'
    Assert-Equal $false $cloneCheckpoint.Data.ColdBootVerified 'The journal checkpoint claimed a verified cold boot.'
    $checkpointProperties = @($cloneCheckpoint.Data.PSObject.Properties | ForEach-Object { $_.Name })
    Assert-True ($checkpointProperties -cnotcontains 'BootReady') 'The journal checkpoint still exposes a BootReady field.'
    Assert-Equal $false $runningState.Instances[2].Running 'The source instance was not left stopped after the clone.'
    $cloneInstanceState = @($runningState.Instances | Where-Object { $_.Index -eq 4 })
    Assert-Equal 1 $cloneInstanceState.Count 'The fake manager did not report the clone instance.'
    Assert-Equal $false $cloneInstanceState[0].Running 'The clone was not left in a stopped state.'

    $stoppedState = New-SafetyManagerState -VmsPath $cloneFixture.VmsPath -Running $false
    $stoppedRunner = New-SafetyManagerRunner -State $stoppedState
    $stoppedJournal = New-SafetyCloneJournal -Root $cloneJournalRoot -Instance $fixtureInstance
    $stoppedClone = New-InstanceClone -ManagerPath $fixtureManager -Instance $fixtureInstance -Journal $stoppedJournal -Runner $stoppedRunner
    $stoppedCommands = @($stoppedState.Calls | ForEach-Object { @($_) -join '|' })
    Assert-Equal 'Success' $stoppedClone.Status 'A verified clone of a stopped instance was rejected.'
    Assert-True (-not ($stoppedCommands -contains 'control|-v|3|shutdown')) 'A stopped instance issued a redundant shutdown request.'

    $unstableState = New-SafetyManagerState -VmsPath $cloneFixture.VmsPath
    $unstableState.ShutdownSettles = $false
    $unstableRunner = New-SafetyManagerRunner -State $unstableState
    $unstableJournal = New-SafetyCloneJournal -Root $cloneJournalRoot -Instance $fixtureInstance
    $unstableClone = New-InstanceClone -ManagerPath $fixtureManager -Instance $fixtureInstance -Journal $unstableJournal -Runner $unstableRunner
    $unstableCommands = @($unstableState.Calls | ForEach-Object { @($_) -join '|' })
    Assert-True ($unstableClone.Status -eq 'CriticalError') 'A clone of an instance that never stopped was accepted.'
    Assert-True (-not ($unstableCommands -contains 'clone|-v|3|-n|1')) 'The clone ran without a stable stopped state.'
    Assert-SafetyFailedClone -Result $unstableClone -Journal $unstableJournal -Message 'An instance without a stable stopped state was cloned.'

    $androidState = New-SafetyManagerState -VmsPath $cloneFixture.VmsPath
    $androidState.CloneAndroid = '15.0'
    $androidRunner = New-SafetyManagerRunner -State $androidState
    $androidJournal = New-SafetyCloneJournal -Root $cloneJournalRoot -Instance $fixtureInstance
    $androidClone = New-InstanceClone -ManagerPath $fixtureManager -Instance $fixtureInstance -Journal $androidJournal -Runner $androidRunner
    Assert-True ($androidClone.Status -eq 'CriticalError') 'A clone with the wrong Android version was accepted.'
    Assert-True ($androidClone.Message -match '(?i)android') 'The Android version failure did not name the field.'
    Assert-SafetyFailedClone -Result $androidClone -Journal $androidJournal -Message 'A clone with the wrong Android version was accepted.'

    $collisionState = New-SafetyManagerState -VmsPath $cloneFixture.VmsPath
    $collisionState.CloneName = 'Other'
    $collisionRunner = New-SafetyManagerRunner -State $collisionState
    $collisionJournal = New-SafetyCloneJournal -Root $cloneJournalRoot -Instance $fixtureInstance
    $collisionClone = New-InstanceClone -ManagerPath $fixtureManager -Instance $fixtureInstance -Journal $collisionJournal -Runner $collisionRunner
    Assert-True ($collisionClone.Status -eq 'CriticalError') 'A clone with a colliding name was accepted.'
    Assert-True ($collisionClone.Message -match '(?i)name') 'The clone name collision failure did not name the field.'
    Assert-SafetyFailedClone -Result $collisionClone -Journal $collisionJournal -Message 'A clone with a colliding name was accepted.'

    $noIndexState = New-SafetyManagerState -VmsPath $cloneFixture.VmsPath
    $noIndexState.CloneIndex = 3
    $noIndexRunner = New-SafetyManagerRunner -State $noIndexState
    $noIndexJournal = New-SafetyCloneJournal -Root $cloneJournalRoot -Instance $fixtureInstance
    $noIndexClone = New-InstanceClone -ManagerPath $fixtureManager -Instance $fixtureInstance -Journal $noIndexJournal -Runner $noIndexRunner
    Assert-True ($noIndexClone.Status -eq 'CriticalError') 'A clone that reused the source index was accepted.'
    Assert-SafetyFailedClone -Result $noIndexClone -Journal $noIndexJournal -Message 'A clone that reused the source index was accepted.'

    $cloneFailureState = New-SafetyManagerState -VmsPath $cloneFixture.VmsPath
    $cloneFailureState.CloneExitCode = 1
    $cloneFailureRunner = New-SafetyManagerRunner -State $cloneFailureState
    $cloneFailureJournal = New-SafetyCloneJournal -Root $cloneJournalRoot -Instance $fixtureInstance
    $cloneFailure = New-InstanceClone -ManagerPath $fixtureManager -Instance $fixtureInstance -Journal $cloneFailureJournal -Runner $cloneFailureRunner
    Assert-True ($cloneFailure.Status -eq 'CriticalError') 'A failed manager clone command was treated as success.'
    Assert-SafetyFailedClone -Result $cloneFailure -Journal $cloneFailureJournal -Message 'A failed manager clone command was treated as success.'

    $unknownState = New-SafetyManagerState -VmsPath $cloneFixture.VmsPath
    $unknownState.Instances[2].Running = 'unknown'
    $unknownRunner = New-SafetyManagerRunner -State $unknownState
    $unknownJournal = New-SafetyCloneJournal -Root $cloneJournalRoot -Instance $fixtureInstance
    $unknownClone = New-InstanceClone -ManagerPath $fixtureManager -Instance $fixtureInstance -Journal $unknownJournal -Runner $unknownRunner
    Assert-True ($unknownClone.Status -eq 'CriticalError') 'An unknown source running state was cloned.'
    Assert-True ($unknownClone.Message -match '(?i)running') 'The unknown running state failure did not name the field.'

    $indexFailureState = New-SafetyManagerState -VmsPath $cloneFixture.VmsPath
    $indexFailureState.InfoIndexExitCode = 1
    $indexFailureRunner = New-SafetyManagerRunner -State $indexFailureState
    $indexFailureJournal = New-SafetyCloneJournal -Root $cloneJournalRoot -Instance $fixtureInstance
    $indexFailureClone = Invoke-SafetyCall { New-InstanceClone -ManagerPath $fixtureManager -Instance $fixtureInstance -Journal $indexFailureJournal -Runner $indexFailureRunner }
    $indexFailureStatus = Get-SafetyResultStatus $indexFailureClone
    Assert-Equal 'CriticalError' $indexFailureStatus 'A failing per-index manager query was accepted.'
    Assert-SafetyFailedClone -Result $indexFailureClone -Journal $indexFailureJournal -Message 'A failing per-index manager query was accepted.'

    $indexMalformedState = New-SafetyManagerState -VmsPath $cloneFixture.VmsPath
    $indexMalformedState.InfoIndexText = '{not-json'
    $indexMalformedRunner = New-SafetyManagerRunner -State $indexMalformedState
    $indexMalformedJournal = New-SafetyCloneJournal -Root $cloneJournalRoot -Instance $fixtureInstance
    $indexMalformedClone = Invoke-SafetyCall { New-InstanceClone -ManagerPath $fixtureManager -Instance $fixtureInstance -Journal $indexMalformedJournal -Runner $indexMalformedRunner }
    $indexMalformedStatus = Get-SafetyResultStatus $indexMalformedClone
    Assert-Equal 'CriticalError' $indexMalformedStatus 'A malformed per-index manager query was accepted.'
    Assert-SafetyFailedClone -Result $indexMalformedClone -Journal $indexMalformedJournal -Message 'A malformed per-index manager query was accepted.'

    $indexMissingState = New-SafetyManagerState -VmsPath $cloneFixture.VmsPath
    $indexMissingState.InfoIndexText = '[]'
    $indexMissingRunner = New-SafetyManagerRunner -State $indexMissingState
    $indexMissingJournal = New-SafetyCloneJournal -Root $cloneJournalRoot -Instance $fixtureInstance
    $indexMissingClone = Invoke-SafetyCall { New-InstanceClone -ManagerPath $fixtureManager -Instance $fixtureInstance -Journal $indexMissingJournal -Runner $indexMissingRunner }
    $indexMissingStatus = Get-SafetyResultStatus $indexMissingClone
    Assert-Equal 'CriticalError' $indexMissingStatus 'An empty per-index manager query was accepted.'
    Assert-SafetyFailedClone -Result $indexMissingClone -Journal $indexMissingJournal -Message 'An empty per-index manager query was accepted.'

    $outsideVmsRoot = Join-Path $cloneRoot 'outside vms'
    $outsideVmsInstance = Join-Path $outsideVmsRoot '4'
    New-Item -ItemType Directory -Path $outsideVmsInstance -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $outsideVmsInstance 'system.img'), 'outside clone disk payload')
    $relinkedVms = Join-Path $cloneFixture.VmsPath 'relinked'
    New-Item -ItemType Junction -Path $relinkedVms -Target $outsideVmsRoot | Out-Null
    $relinkState = New-SafetyManagerState -VmsPath $cloneFixture.VmsPath
    $relinkState.CloneVmsPath = $relinkedVms
    $relinkRunner = New-SafetyManagerRunner -State $relinkState
    $relinkJournal = New-SafetyCloneJournal -Root $cloneJournalRoot -Instance $fixtureInstance
    $relinkClone = Invoke-SafetyCall { New-InstanceClone -ManagerPath $fixtureManager -Instance $fixtureInstance -Journal $relinkJournal -Runner $relinkRunner }
    $relinkStatus = Get-SafetyResultStatus $relinkClone
    Assert-Equal 'CriticalError' $relinkStatus 'A clone VMS path relinked outside the install boundary was accepted.'
    Assert-True ($relinkClone.Message -match '(?i)boundary|outside|within') 'The relocated VMS failure did not name the boundary.'
    Assert-SafetyFailedClone -Result $relinkClone -Journal $relinkJournal -Message 'A clone VMS path relinked outside the install boundary was accepted.'

    $inBoundaryVmsRoot = Join-Path $cloneFixture.VmsPath 'nested'
    $inBoundaryVmsInstance = Join-Path $inBoundaryVmsRoot '4'
    New-Item -ItemType Directory -Path $inBoundaryVmsInstance -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $inBoundaryVmsInstance 'system.img'), 'nested clone disk payload')
    $inBoundaryState = New-SafetyManagerState -VmsPath $cloneFixture.VmsPath
    $inBoundaryState.CloneVmsPath = $inBoundaryVmsRoot
    $inBoundaryRunner = New-SafetyManagerRunner -State $inBoundaryState
    $inBoundaryJournal = New-SafetyCloneJournal -Root $cloneJournalRoot -Instance $fixtureInstance
    $inBoundaryClone = New-InstanceClone -ManagerPath $fixtureManager -Instance $fixtureInstance -Journal $inBoundaryJournal -Runner $inBoundaryRunner
    Assert-Equal 'Success' $inBoundaryClone.Status 'A clone VMS path inside the install boundary was rejected.'
    Assert-Equal ([IO.Path]::GetFullPath($inBoundaryVmsInstance)) $inBoundaryClone.Data.VmsPath 'An in-boundary clone VMS root was resolved incorrectly.'

    $relocatedVmsTarget = Join-Path $cloneRoot 'relocated vms'
    New-Item -ItemType Directory -Path $relocatedVmsTarget -Force | Out-Null
    $relocatedVmsJunction = Join-Path $cloneRoot 'relocated vms junction'
    New-Item -ItemType Junction -Path $relocatedVmsJunction -Target $relocatedVmsTarget | Out-Null
    $relinkedSourceInstance = [pscustomobject]@{
        Index = 3
        Name = 'Target'
        AndroidVersion = '12.0'
        Install = [pscustomobject]@{
            Edition = 'Global'
            InstallRoot = $cloneFixture.InstallRoot
            VmsPath = $relocatedVmsJunction
            ManagerPath = $fixtureManager
            Source = 'Process'
        }
        Running = $false
        RootSetting = $false
        Eligible = $true
        IneligibleReason = $null
    }
    $relinkedSourceState = New-SafetyManagerState -VmsPath $relocatedVmsTarget -Running $false
    $relinkedSourceRunner = New-SafetyManagerRunner -State $relinkedSourceState
    $relinkedSourceJournal = New-SafetyCloneJournal -Root $cloneJournalRoot -Instance $relinkedSourceInstance
    $relinkedSourceClone = New-InstanceClone -ManagerPath $fixtureManager -Instance $relinkedSourceInstance -Journal $relinkedSourceJournal -Runner $relinkedSourceRunner
    Assert-Equal 'Success' $relinkedSourceClone.Status 'A legitimately junction-relocated source VMS path was rejected.'
    Assert-Equal ([IO.Path]::GetFullPath((Join-Path $relocatedVmsJunction '4'))) $relinkedSourceClone.Data.VmsPath 'A relocated source VMS path resolved the clone root incorrectly.'

    $unreachableCloneState = @{ Count = 0 }
    $unreachableCloneRunner = {
        param($ActualFilePath, $ActualArgumentList)
        $unreachableCloneState.Count++
        [pscustomobject]@{ ExitCode = 0; Text = '' }
    }.GetNewClosure()
    $unreachableJournal = New-SafetyCloneJournal -Root $cloneJournalRoot -Instance $fixtureInstance
    $unrelatedManager = Join-Path $cloneRoot 'unrelated tool.exe'
    [IO.File]::WriteAllText($unrelatedManager, 'unrelated fixture')
    $unrelatedManagerClone = New-InstanceClone -ManagerPath $unrelatedManager -Instance $fixtureInstance -Journal $unreachableJournal -Runner $unreachableCloneRunner
    Assert-Equal 'CriticalError' $unrelatedManagerClone.Status 'An unrelated executable was accepted as the clone manager.'
    $missingManagerClone = New-InstanceClone -ManagerPath (Join-Path $cloneRoot 'shell\MuMuManager.exe') -Instance $fixtureInstance -Journal $unreachableJournal -Runner $unreachableCloneRunner
    Assert-Equal 'CriticalError' $missingManagerClone.Status 'A missing clone manager was accepted.'
    $invalidInstance = [pscustomobject]@{ Index = 'not-an-index'; Name = 'Target'; AndroidVersion = '12.0'; Install = $fixtureInstance.Install }
    $invalidInstanceClone = New-InstanceClone -ManagerPath $fixtureManager -Instance $invalidInstance -Journal $unreachableJournal -Runner $unreachableCloneRunner
    Assert-Equal 'CriticalError' $invalidInstanceClone.Status 'An invalid source instance was accepted.'
    $missingVmsInstance = [pscustomobject]@{ Index = 3; Name = 'Target'; AndroidVersion = '12.0'; Install = [pscustomobject]@{ Edition = 'Global'; InstallRoot = $fixtureInstance.Install.InstallRoot; ManagerPath = $fixtureManager; Source = 'Process' } }
    $missingVmsClone = New-InstanceClone -ManagerPath $fixtureManager -Instance $missingVmsInstance -Journal $unreachableJournal -Runner $unreachableCloneRunner
    Assert-Equal 'CriticalError' $missingVmsClone.Status 'A source instance without a VMS path was accepted.'
    $missingInstallRootInstance = [pscustomobject]@{ Index = 3; Name = 'Target'; AndroidVersion = '12.0'; Install = [pscustomobject]@{ Edition = 'Global'; VmsPath = $fixtureInstance.Install.VmsPath; ManagerPath = $fixtureManager; Source = 'Process' } }
    $missingInstallRootClone = New-InstanceClone -ManagerPath $fixtureManager -Instance $missingInstallRootInstance -Journal $unreachableJournal -Runner $unreachableCloneRunner
    Assert-Equal 'CriticalError' $missingInstallRootClone.Status 'A source instance without an install root was accepted.'
    $nullJournalClone = New-InstanceClone -ManagerPath $fixtureManager -Instance $fixtureInstance -Journal $null -Runner $unreachableCloneRunner
    Assert-Equal 'CriticalError' $nullJournalClone.Status 'A clone without a journal was accepted.'
    $outsideManagerRoot = Join-Path $cloneRoot 'outside manager install'
    New-Item -ItemType Directory -Path (Join-Path $outsideManagerRoot 'shell') -Force | Out-Null
    $outsideManager = Join-Path $outsideManagerRoot 'shell\MuMuManager.exe'
    [IO.File]::WriteAllText($outsideManager, 'outside manager fixture')
    $outsideManagerClone = New-InstanceClone -ManagerPath $outsideManager -Instance $fixtureInstance -Journal $unreachableJournal -Runner $unreachableCloneRunner
    Assert-Equal 'CriticalError' $outsideManagerClone.Status 'A clone manager outside the install root was accepted.'
    $relinkedManagerDirectory = Join-Path $cloneFixture.InstallRoot 'relinked manager'
    New-Item -ItemType Junction -Path $relinkedManagerDirectory -Target (Split-Path -Parent $outsideManager) | Out-Null
    $relinkedManager = Join-Path $relinkedManagerDirectory 'MuMuManager.exe'
    $relinkedManagerClone = New-InstanceClone -ManagerPath $relinkedManager -Instance $fixtureInstance -Journal $unreachableJournal -Runner $unreachableCloneRunner
    Assert-Equal 'CriticalError' $relinkedManagerClone.Status 'A clone manager relinked outside the install root was accepted.'
    Assert-Equal 0 $unreachableCloneState.Count 'An invalid clone request reached the process runner.'

    $backupBase = Join-Path $testRoot 'backups'
    New-Item -ItemType Directory -Path $backupBase -Force | Out-Null
    $backupRoot = Join-Path $backupBase ([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffffffZ') + '-root12')
    New-Item -ItemType Directory -Path $backupRoot | Out-Null
    $mutatedDirectory = Join-Path $testRoot 'mutated files'
    New-Item -ItemType Directory -Path $mutatedDirectory -Force | Out-Null
    $configPath = Join-Path $mutatedDirectory 'campaign.json'
    [IO.File]::WriteAllText($configPath, '{"ad":true}')
    $backup = Backup-ChangedFile -Path $configPath -BackupRoot $backupRoot
    Assert-Equal 'Success' $backup.Status 'A changed file was not backed up.'
    $backupRecord = $backup.Data
    $recordProperties = @($backupRecord.PSObject.Properties | ForEach-Object { $_.Name })
    Assert-Equal 5 $recordProperties.Count 'Backup record property count is invalid.'
    foreach ($recordProperty in @('Source', 'Backup', 'Sha256', 'ReadOnly', 'Length')) {
        Assert-True ($recordProperties -ccontains $recordProperty) "Backup record is missing a property: $recordProperty"
    }
    Assert-Equal $configPath $backupRecord.Source 'Backup record source is invalid.'
    Assert-Equal 'campaign.json' ([IO.Path]::GetFileName($backupRecord.Backup)) 'Backup file name is invalid.'
    Assert-True ($backupRecord.Backup.StartsWith($backupRoot, [StringComparison]::OrdinalIgnoreCase)) 'Backup escaped the per-operation backup root.'
    Assert-Equal (Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash $backupRecord.Sha256 'Backup record hash does not match the source.'
    Assert-Equal (Get-Item -LiteralPath $configPath).Length $backupRecord.Length 'Backup record length does not match the source.'
    Assert-Equal $false $backupRecord.ReadOnly 'A writable source was recorded as read-only.'
    Assert-Equal '{"ad":true}' ([IO.File]::ReadAllText($backupRecord.Backup)) 'Backup bytes do not match the source.'

    $readOnlyPath = Join-Path $mutatedDirectory 'locked.json'
    [IO.File]::WriteAllText($readOnlyPath, '{"locked":true}')
    $readOnlyItem = Get-Item -LiteralPath $readOnlyPath
    $readOnlyItem.IsReadOnly = $true
    $readOnlyBackup = Backup-ChangedFile -Path $readOnlyPath -BackupRoot $backupRoot
    Assert-Equal 'Success' $readOnlyBackup.Status 'A read-only file was not backed up.'
    Assert-Equal $true $readOnlyBackup.Data.ReadOnly 'The original read-only state was not recorded.'
    Assert-Equal $false (Get-Item -LiteralPath $readOnlyBackup.Data.Backup).IsReadOnly 'The backup copy is not owner-readable.'
    Assert-Equal $true (Get-Item -LiteralPath $readOnlyPath).IsReadOnly 'Backing up a read-only source changed its read-only state.'

    $duplicateBackup = Backup-ChangedFile -Path $configPath -BackupRoot $backupRoot
    Assert-Equal 'CriticalError' $duplicateBackup.Status 'A duplicate backup record was accepted.'
    Assert-True ($duplicateBackup.Message -match '(?i)exists|duplicate') 'The duplicate backup failure did not explain the collision.'
    Assert-Equal '{"ad":true}' ([IO.File]::ReadAllText($backupRecord.Backup)) 'A refused duplicate backup overwrote the existing backup.'

    $missingSourceBackup = Backup-ChangedFile -Path (Join-Path $mutatedDirectory 'missing.json') -BackupRoot $backupRoot
    Assert-Equal 'CriticalError' $missingSourceBackup.Status 'A missing backup source was accepted.'
    $directorySourceBackup = Backup-ChangedFile -Path $mutatedDirectory -BackupRoot $backupRoot
    Assert-Equal 'CriticalError' $directorySourceBackup.Status 'A directory backup source was accepted.'
    $vmsRootSourceBackup = Backup-ChangedFile -Path $cloneFixture.VmsPath -BackupRoot $backupRoot
    Assert-Equal 'CriticalError' $vmsRootSourceBackup.Status 'A VMS instance directory was accepted as a backup source.'
    $missingRootBackup = Backup-ChangedFile -Path $configPath -BackupRoot (Join-Path $backupBase 'missing root')
    Assert-Equal 'CriticalError' $missingRootBackup.Status 'A missing backup root was accepted.'
    $blankRootBackup = Backup-ChangedFile -Path $configPath -BackupRoot '   '
    Assert-Equal 'CriticalError' $blankRootBackup.Status 'A blank backup root was accepted.'
    $blankSourceBackup = Backup-ChangedFile -Path '   ' -BackupRoot $backupRoot
    Assert-Equal 'CriticalError' $blankSourceBackup.Status 'A blank backup source was accepted.'
    $rootFileBackup = Backup-ChangedFile -Path $configPath -BackupRoot $configPath
    Assert-Equal 'CriticalError' $rootFileBackup.Status 'A file was accepted as the backup root.'
    $realBackupRoot = Join-Path $backupBase 'relinked root'
    New-Item -ItemType Directory -Path $realBackupRoot -Force | Out-Null
    $relinkedBackupRoot = Join-Path $backupBase 'relinked root junction'
    New-Item -ItemType Junction -Path $relinkedBackupRoot -Target $realBackupRoot | Out-Null
    $relinkedRootBackup = Backup-ChangedFile -Path $configPath -BackupRoot $relinkedBackupRoot
    Assert-Equal 'CriticalError' $relinkedRootBackup.Status 'A junctioned backup root was accepted.'
    Assert-True ($relinkedRootBackup.Message -match '(?i)reparse|link|junction') 'The junctioned backup root failure did not name the reparse point.'
    Assert-Equal 0 @([IO.Directory]::GetFiles($realBackupRoot)).Count 'A junctioned backup root received a file.'
    Assert-Equal 2 @([IO.Directory]::GetFiles($backupRoot)).Count 'A refused backup request created a file.'

    $readOnlyTarget = Get-Item -LiteralPath $readOnlyPath
    $readOnlyTarget.IsReadOnly = $false
    [IO.File]::WriteAllText($readOnlyPath, '{"locked":false}')
    $readOnlyRestore = Restore-BackupFile -BackupRecord $readOnlyBackup.Data
    Assert-Equal 'Success' $readOnlyRestore.Status 'A read-only backup was not restored.'
    Assert-Equal '{"locked":true}' ([IO.File]::ReadAllText($readOnlyPath)) 'The read-only restore changed the file bytes.'
    Assert-Equal $true (Get-Item -LiteralPath $readOnlyPath).IsReadOnly 'The original read-only state was not preserved.'
    Assert-True ([IO.File]::Exists($readOnlyBackup.Data.Backup)) 'The restore deleted the only original backup.'

    [IO.File]::WriteAllText($configPath, '{"ad":false}')
    $restore = Restore-BackupFile -BackupRecord $backupRecord
    Assert-Equal 'Success' $restore.Status 'A changed file was not restored.'
    Assert-Equal '{"ad":true}' ([IO.File]::ReadAllText($configPath)) 'The restored bytes do not match the backup.'
    Assert-True ([IO.File]::Exists($backupRecord.Backup)) 'The restore deleted the only original backup.'

    $tamperedRoot = Join-Path $backupBase ([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffffffZ') + '-tampered')
    New-Item -ItemType Directory -Path $tamperedRoot | Out-Null
    $tamperedSource = Join-Path $mutatedDirectory 'tampered.json'
    [IO.File]::WriteAllText($tamperedSource, 'original bytes')
    $tamperedBackup = Backup-ChangedFile -Path $tamperedSource -BackupRoot $tamperedRoot
    Assert-Equal 'Success' $tamperedBackup.Status 'The tamper fixture was not backed up.'
    [IO.File]::WriteAllText($tamperedSource, 'mutated bytes')
    [IO.File]::WriteAllText($tamperedBackup.Data.Backup, 'ORIGINAL bytes')
    Assert-Equal $tamperedBackup.Data.Length ([IO.FileInfo]$tamperedBackup.Data.Backup).Length 'The tamper fixture is not the same length as the source.'
    $hashMismatch = Restore-BackupFile -BackupRecord $tamperedBackup.Data
    Assert-Equal 'CriticalError' $hashMismatch.Status 'A backup hash mismatch was accepted.'
    Assert-True ($hashMismatch.Message -match '(?i)hash') 'The backup hash failure did not name the hash.'
    Assert-Equal 'mutated bytes' ([IO.File]::ReadAllText($tamperedSource)) 'A failed hash verification changed the source file.'

    $lengthSource = Join-Path $mutatedDirectory 'length.json'
    [IO.File]::WriteAllText($lengthSource, 'twelve bytes')
    $lengthBackup = Backup-ChangedFile -Path $lengthSource -BackupRoot $tamperedRoot
    Assert-Equal 'Success' $lengthBackup.Status 'The length fixture was not backed up.'
    [IO.File]::WriteAllText($lengthSource, 'mutated now!')
    [IO.File]::WriteAllText($lengthBackup.Data.Backup, 'short')
    $lengthMismatch = Restore-BackupFile -BackupRecord $lengthBackup.Data
    Assert-Equal 'CriticalError' $lengthMismatch.Status 'A backup length mismatch was accepted.'
    Assert-True ($lengthMismatch.Message -match '(?i)length') 'The backup length failure did not name the length.'
    Assert-Equal 'mutated now!' ([IO.File]::ReadAllText($lengthSource)) 'A failed length verification changed the source file.'
    [IO.File]::Delete($lengthBackup.Data.Backup)
    $missingBackupRestore = Restore-BackupFile -BackupRecord $lengthBackup.Data
    Assert-Equal 'CriticalError' $missingBackupRestore.Status 'A missing backup file was accepted.'
    Assert-Equal 'mutated now!' ([IO.File]::ReadAllText($lengthSource)) 'A missing backup file changed the source file.'

    $deletedSource = Join-Path $mutatedDirectory 'deleted.json'
    [IO.File]::WriteAllText($deletedSource, 'recover me')
    $deletedBackup = Backup-ChangedFile -Path $deletedSource -BackupRoot $backupRoot
    Assert-Equal 'Success' $deletedBackup.Status 'The deletion fixture was not backed up.'
    [IO.File]::Delete($deletedSource)
    $deletedRestore = Restore-BackupFile -BackupRecord $deletedBackup.Data
    Assert-Equal 'Success' $deletedRestore.Status 'A deleted file was not recovered from its backup.'
    Assert-Equal 'recover me' ([IO.File]::ReadAllText($deletedSource)) 'The recovered bytes do not match the backup.'

    $invalidRecords = @(
        [pscustomobject]@{ Label = 'null'; Record = $null },
        [pscustomobject]@{ Label = 'array'; Record = @($backupRecord) },
        [pscustomobject]@{ Label = 'string'; Record = 'invalid' },
        [pscustomobject]@{ Label = 'missing property'; Record = [pscustomobject]@{ Source = $configPath; Backup = $backupRecord.Backup; Sha256 = $backupRecord.Sha256; ReadOnly = $false } },
        [pscustomobject]@{ Label = 'extra property'; Record = [pscustomobject]@{ Source = $configPath; Backup = $backupRecord.Backup; Sha256 = $backupRecord.Sha256; ReadOnly = $false; Length = $backupRecord.Length; Extra = 'invalid' } },
        [pscustomobject]@{ Label = 'bad hash'; Record = [pscustomobject]@{ Source = $configPath; Backup = $backupRecord.Backup; Sha256 = 'not-a-hash'; ReadOnly = $false; Length = $backupRecord.Length } },
        [pscustomobject]@{ Label = 'bad read-only'; Record = [pscustomobject]@{ Source = $configPath; Backup = $backupRecord.Backup; Sha256 = $backupRecord.Sha256; ReadOnly = 'maybe'; Length = $backupRecord.Length } },
        [pscustomobject]@{ Label = 'bad length'; Record = [pscustomobject]@{ Source = $configPath; Backup = $backupRecord.Backup; Sha256 = $backupRecord.Sha256; ReadOnly = $false; Length = 'twelve' } },
        [pscustomobject]@{ Label = 'blank source'; Record = [pscustomobject]@{ Source = '   '; Backup = $backupRecord.Backup; Sha256 = $backupRecord.Sha256; ReadOnly = $false; Length = $backupRecord.Length } },
        [pscustomobject]@{ Label = 'blank backup'; Record = [pscustomobject]@{ Source = $configPath; Backup = '   '; Sha256 = $backupRecord.Sha256; ReadOnly = $false; Length = $backupRecord.Length } }
    )
    foreach ($invalidRecord in $invalidRecords) {
        $invalidRestore = Restore-BackupFile -BackupRecord $invalidRecord.Record
        Assert-Equal 'CriticalError' $invalidRestore.Status "An invalid backup record was accepted: $($invalidRecord.Label)"
    }
    $directoryTarget = Join-Path $mutatedDirectory 'target dir'
    New-Item -ItemType Directory -Path $directoryTarget -Force | Out-Null
    $directoryTargetRecord = [pscustomobject]@{
        Source = $directoryTarget
        Backup = $backupRecord.Backup
        Sha256 = $backupRecord.Sha256
        ReadOnly = $false
        Length = $backupRecord.Length
    }
    $directoryTargetRestore = Restore-BackupFile -BackupRecord $directoryTargetRecord
    Assert-Equal 'CriticalError' $directoryTargetRestore.Status 'A restore over a directory was accepted.'
    Assert-True (Test-Path -LiteralPath $directoryTarget -PathType Container) 'A refused restore replaced a directory with a file.'

    $illegalSourceRecord = [pscustomobject]@{
        Source = 'C:\fixture"illegal\campaign.json'
        Backup = $backupRecord.Backup
        Sha256 = $backupRecord.Sha256
        ReadOnly = $false
        Length = $backupRecord.Length
    }
    $illegalSourceRestore = Invoke-SafetyCall { Restore-BackupFile -BackupRecord $illegalSourceRecord }
    $illegalSourceStatus = Get-SafetyResultStatus $illegalSourceRestore
    Assert-Equal 'CriticalError' $illegalSourceStatus 'An illegal-character restore source was accepted.'
    Assert-True ($illegalSourceRestore.Message -match '(?i)source') 'The illegal source failure did not name the field.'

    $longSourceRecord = [pscustomobject]@{
        Source = ('C:\fixture\' + ('a' * 400) + '\campaign.json')
        Backup = $backupRecord.Backup
        Sha256 = $backupRecord.Sha256
        ReadOnly = $false
        Length = $backupRecord.Length
    }
    $longSourceRestore = Invoke-SafetyCall { Restore-BackupFile -BackupRecord $longSourceRecord }
    $longSourceStatus = Get-SafetyResultStatus $longSourceRestore
    Assert-Equal 'CriticalError' $longSourceStatus 'An overlong restore source was accepted.'
    Assert-True ($longSourceRestore.Message -match '(?i)source') 'The overlong source failure did not name the field.'

    $illegalBackupRecord = [pscustomobject]@{
        Source = $configPath
        Backup = 'C:\fixture"illegal\campaign.json'
        Sha256 = $backupRecord.Sha256
        ReadOnly = $false
        Length = $backupRecord.Length
    }
    $illegalBackupRestore = Invoke-SafetyCall { Restore-BackupFile -BackupRecord $illegalBackupRecord }
    $illegalBackupStatus = Get-SafetyResultStatus $illegalBackupRestore
    Assert-Equal 'CriticalError' $illegalBackupStatus 'An illegal-character backup path was accepted.'
    Assert-True ($illegalBackupRestore.Message -match '(?i)backup') 'The illegal backup path failure did not name the field.'

    $lockedSource = Join-Path $mutatedDirectory 'locked restore.json'
    [IO.File]::WriteAllText($lockedSource, 'locked original bytes')
    $lockedBackup = Backup-ChangedFile -Path $lockedSource -BackupRoot $backupRoot
    Assert-Equal 'Success' $lockedBackup.Status 'The locked restore fixture was not backed up.'
    Assert-Equal $false $lockedBackup.Data.ReadOnly 'The locked restore fixture was recorded as read-only.'
    [IO.File]::WriteAllText($lockedSource, 'locked current bytes')
    $lockedItem = Get-Item -LiteralPath $lockedSource
    $lockedItem.IsReadOnly = $true
    $lockedAttributes = $lockedItem.Attributes
    $lockedHandle = [IO.File]::Open($lockedSource, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
    try {
        $lockedRestore = Invoke-SafetyCall { Restore-BackupFile -BackupRecord $lockedBackup.Data }
    }
    finally {
        $lockedHandle.Dispose()
    }
    $lockedStatus = Get-SafetyResultStatus $lockedRestore
    Assert-Equal 'CriticalError' $lockedStatus 'A restore over a locked target returned success.'
    $lockedAfter = Get-Item -LiteralPath $lockedSource
    Assert-Equal $lockedAttributes $lockedAfter.Attributes 'A failed restore did not restore the target original attributes.'
    Assert-Equal $true $lockedAfter.IsReadOnly 'A failed restore left a read-only target writable.'
    Assert-Equal 'locked current bytes' ([IO.File]::ReadAllText($lockedSource)) 'A failed restore changed the target bytes.'
    $lockedRestoreAfter = Restore-BackupFile -BackupRecord $lockedBackup.Data
    Assert-Equal 'Success' $lockedRestoreAfter.Status 'The locked restore fixture could not be restored after the lock was released.'
    Assert-Equal 'locked original bytes' ([IO.File]::ReadAllText($lockedSource)) 'The recovered bytes do not match the backup.'
}

function New-AdsCampaignFixture {
    param(
        [string]$Path,
        [string]$Json,
        [bool]$ReadOnly = $false
    )

    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path))
    [IO.File]::WriteAllText($Path, $Json, (New-Object Text.UTF8Encoding($false)))
    if ($ReadOnly) {
        (Get-Item -LiteralPath $Path).IsReadOnly = $true
    }
}

function New-AdsInstallFixture {
    param(
        [string]$Name,
        [string]$Edition = 'Global'
    )

    $root = Join-Path $script:adsFixtureRoot $Name
    [void][IO.Directory]::CreateDirectory($root)
    return [pscustomobject]@{
        Edition = $Edition
        InstallRoot = $root
        VmsPath = (Join-Path $root 'vms')
        ManagerPath = ''
        Source = 'Fallback'
    }
}

function New-AdsJournal {
    param([string]$Name)

    $root = Join-Path $script:adsFixtureRoot $Name
    [void][IO.Directory]::CreateDirectory($root)
    return New-OperationJournal -Root $root -Operation 'Ads' -Instance ([pscustomobject]@{ Edition = 'Global' })
}

function New-AdsBackupRoot {
    param([string]$Name)

    $root = Join-Path $script:adsFixtureRoot $Name
    [void][IO.Directory]::CreateDirectory($root)
    return $root
}

function Get-AdsRestorePointFile {
    param([string]$BackupRoot)

    return @([IO.Directory]::GetFiles($BackupRoot, '*', [IO.SearchOption]::AllDirectories) |
        Where-Object { [IO.Path]::GetFileName($_) -ne 'restore-point.json' })
}

function Get-AdsManifest {
    param([string]$BackupRoot)

    return [IO.File]::ReadAllText([IO.Path]::Combine($BackupRoot, 'restore-point.json')) | ConvertFrom-Json
}

function Write-AdsManifest {
    param(
        [string]$BackupRoot,
        [object]$Manifest
    )

    [IO.File]::WriteAllText([IO.Path]::Combine($BackupRoot, 'restore-point.json'), ($Manifest | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false)))
}

function New-AdsManifestRecord {
    param(
        [string]$Source,
        [string]$Backup
    )

    $item = New-Object IO.FileInfo($Backup)
    return [pscustomobject]@{
        Source   = $Source
        Backup   = $Backup
        Sha256   = (Get-FileHash -LiteralPath $Backup -Algorithm SHA256).Hash
        ReadOnly = [bool]$item.IsReadOnly
        Length   = [long]$item.Length
    }
}

function Assert-AdsUnchanged {
    param(
        [string]$Path,
        [string]$Expected,
        [string]$Message
    )

    Assert-Equal $Expected ([IO.File]::ReadAllText($Path)) $Message
}

function Invoke-AdsTests {
    foreach ($commandName in @('Get-MuMuCampaignPaths', 'Suppress-MuMuAds', 'Restore-MuMuAds')) {
        Assert-True ($null -ne (Get-Command $commandName -CommandType Function -ErrorAction SilentlyContinue)) "Ads command is unavailable: $commandName"
    }
    Assert-True (Test-Path -LiteralPath $adsScriptPath -PathType Leaf) 'src/Ads.ps1 does not exist.'

    $adsSource = [IO.File]::ReadAllText($adsScriptPath)
    foreach ($forbidden in @(
            'icacls',
            'Set-Acl',
            'Get-Acl',
            'takeown',
            'Set-ItemProperty',
            'Get-ItemProperty',
            'Remove-Item',
            'Set-ExecutionPolicy',
            'Invoke-Expression',
            'ScriptBlock]::Create',
            'Add-Type',
            'DownloadString',
            'Invoke-WebRequest',
            'Invoke-RestMethod',
            'New-NetFirewallRule',
            'Set-NetFirewallProfile',
            'Set-DnsClientServerAddress',
            'New-NetFirewallRule',
            'drivers\etc\hosts'
        )) {
        Assert-True ($adsSource -notmatch [regex]::Escape($forbidden)) "Ads source uses a forbidden construct: $forbidden"
    }
    Assert-True ($adsSource -match '\[IO\.File\]::Replace') 'Campaign files are not replaced with a single atomic filesystem operation.'

    $script:adsFixtureRoot = Join-Path $testRoot 'ads fixtures'
    [void][IO.Directory]::CreateDirectory($script:adsFixtureRoot)

    $globalAdsInstall = New-AdsInstallFixture -Name 'MuMu Global' -Edition 'Global'
    $chineseAdsInstall = New-AdsInstallFixture -Name 'MuMuPlayer' -Edition 'Chinese'
    $globalCampaign = Join-Path $globalAdsInstall.InstallRoot 'shell\ad\campaign.json'
    $globalConfigCampaign = Join-Path $globalAdsInstall.InstallRoot 'nx_device\configs\campaign.json'
    $chineseCampaign = Join-Path $chineseAdsInstall.InstallRoot 'MuMuPlayer\ad\campaign.json'
    $globalCampaignJson = '{"version":3,"campaigns":[{"id":"alpha","display":true,"order":1,"image":"a.png"},{"id":"beta","order":2}]}'
    $globalConfigCampaignJson = '{"campaigns":[{"id":"gamma","display":true,"weight":0.5}]}'
    $chineseCampaignJson = '[{"id":"delta","display":true,"name":"cn"}]'
    New-AdsCampaignFixture -Path $globalCampaign -Json $globalCampaignJson
    New-AdsCampaignFixture -Path $globalConfigCampaign -Json $globalConfigCampaignJson
    New-AdsCampaignFixture -Path $chineseCampaign -Json $chineseCampaignJson

    $globalCampaignPaths = Get-MuMuCampaignPaths -Install $globalAdsInstall
    Assert-Equal 'Success' $globalCampaignPaths.Status 'Global campaign discovery failed.'
    Assert-Equal 2 @($globalCampaignPaths.Data).Count 'Global campaign discovery returned the wrong count.'
    Assert-True (@($globalCampaignPaths.Data) -contains $globalCampaign) 'The Global shell campaign path was not discovered.'
    Assert-True (@($globalCampaignPaths.Data) -contains $globalConfigCampaign) 'The Global nx_device campaign path was not discovered.'
    $chineseCampaignPaths = Get-MuMuCampaignPaths -Install $chineseAdsInstall
    Assert-Equal 'Success' $chineseCampaignPaths.Status 'Chinese campaign discovery failed.'
    Assert-Equal 1 @($chineseCampaignPaths.Data).Count 'Chinese campaign discovery returned the wrong count.'
    Assert-Equal $chineseCampaign @($chineseCampaignPaths.Data)[0] 'The Chinese campaign path was not discovered.'
    Assert-True (@($globalCampaignPaths.Data) -notcontains $chineseCampaign) 'A Chinese campaign path leaked into Global discovery.'
    Assert-True (@($chineseCampaignPaths.Data) -notcontains $globalCampaign) 'A Global campaign path leaked into Chinese discovery.'

    $emptyAdsInstall = New-AdsInstallFixture -Name 'Empty\MuMu Global' -Edition 'Global'
    $emptyCampaignPaths = Get-MuMuCampaignPaths -Install $emptyAdsInstall
    Assert-Equal 'Success' $emptyCampaignPaths.Status 'An install without a campaign file was refused.'
    Assert-Equal 0 @($emptyCampaignPaths.Data).Count 'An install without a campaign file reported a path.'

    $invalidInstalls = @(
        @{ Label = 'null'; Value = $null },
        @{ Label = 'array'; Value = @('invalid') },
        @{ Label = 'missing edition'; Value = [pscustomobject]@{ InstallRoot = $emptyAdsInstall.InstallRoot } },
        @{ Label = 'unknown edition'; Value = [pscustomobject]@{ Edition = 'Other'; InstallRoot = $emptyAdsInstall.InstallRoot } },
        @{ Label = 'noncanonical edition'; Value = [pscustomobject]@{ Edition = 'global'; InstallRoot = $emptyAdsInstall.InstallRoot } },
        @{ Label = 'nonstring edition'; Value = [pscustomobject]@{ Edition = 17; InstallRoot = $emptyAdsInstall.InstallRoot } },
        @{ Label = 'missing install root'; Value = [pscustomobject]@{ Edition = 'Global' } },
        @{ Label = 'blank install root'; Value = [pscustomobject]@{ Edition = 'Global'; InstallRoot = '   ' } },
        @{ Label = 'nonstring install root'; Value = [pscustomobject]@{ Edition = 'Global'; InstallRoot = 17 } },
        @{ Label = 'unavailable install root'; Value = [pscustomobject]@{ Edition = 'Global'; InstallRoot = (Join-Path $script:adsFixtureRoot 'missing install root') } }
    )
    foreach ($invalidInstall in $invalidInstalls) {
        $invalidPaths = Get-MuMuCampaignPaths -Install $invalidInstall.Value
        Assert-Equal 'CriticalError' $invalidPaths.Status "An invalid install was accepted: $($invalidInstall.Label)"
        Assert-True ($null -eq $invalidPaths.Data) "An invalid install returned a campaign path: $($invalidInstall.Label)"
    }

    $escapedAdsInstall = New-AdsInstallFixture -Name 'Escaped\MuMu Global' -Edition 'Global'
    $outsideAdsRoot = Join-Path $script:adsFixtureRoot 'outside ads'
    [void][IO.Directory]::CreateDirectory($escapedAdsInstall.InstallRoot + '\shell')
    [void][IO.Directory]::CreateDirectory($outsideAdsRoot)
    New-AdsCampaignFixture -Path (Join-Path $outsideAdsRoot 'campaign.json') -Json $globalConfigCampaignJson
    New-Item -ItemType Junction -Path (Join-Path $escapedAdsInstall.InstallRoot 'shell\ad') -Target $outsideAdsRoot | Out-Null
    $escapedCampaignPaths = Get-MuMuCampaignPaths -Install $escapedAdsInstall
    Assert-Equal 'Success' $escapedCampaignPaths.Status 'A junctioned campaign directory aborted discovery.'
    Assert-Equal 0 @($escapedCampaignPaths.Data).Count 'A campaign file reached through a junction outside the install root was discovered.'

    $directoryAdsInstall = New-AdsInstallFixture -Name 'Directory\MuMu Global' -Edition 'Global'
    New-Item -ItemType Directory -Path (Join-Path $directoryAdsInstall.InstallRoot 'shell\ad\campaign.json') -Force | Out-Null
    $directoryCampaignPaths = Get-MuMuCampaignPaths -Install $directoryAdsInstall
    Assert-Equal 0 @($directoryCampaignPaths.Data).Count 'A directory named campaign.json was discovered.'

    $adsJournal = New-AdsJournal -Name 'journal main'
    $adsBackupRoot = New-AdsBackupRoot -Name 'backup main'
    $suppress = Suppress-MuMuAds -Paths @($globalCampaign) -BackupRoot $adsBackupRoot -Journal $adsJournal
    Assert-Equal 'Success' $suppress.Status "Valid campaign suppression failed. $($suppress.Message)"
    Assert-Equal 1 $suppress.Data.Changed 'Suppression reported the wrong changed count.'
    Assert-Equal 0 $suppress.Data.Skipped 'Suppression reported the wrong skipped count.'
    Assert-Equal 1 @($suppress.Data.Backups).Count 'Suppression reported the wrong backup count.'
    $suppressedDocument = [IO.File]::ReadAllText($globalCampaign) | ConvertFrom-Json
    Assert-Equal 3 $suppressedDocument.version 'Suppression changed an unrelated root property.'
    Assert-Equal 2 @($suppressedDocument.campaigns).Count 'Suppression changed the campaign record count.'
    Assert-Equal 'alpha' $suppressedDocument.campaigns[0].id 'Suppression changed the campaign identity.'
    Assert-Equal 1 $suppressedDocument.campaigns[0].order 'Suppression changed an unrelated campaign field.'
    Assert-Equal 'a.png' $suppressedDocument.campaigns[0].image 'Suppression changed an unrelated campaign field.'
    Assert-True ($suppressedDocument.campaigns[0].display -is [bool]) 'The suppressed display flag is not a boolean.'
    Assert-Equal $false $suppressedDocument.campaigns[0].display 'The display flag was not set to boolean false.'
    Assert-True ($null -eq $suppressedDocument.campaigns[1].PSObject.Properties['display']) 'Suppression added a display flag to a record that had none.'
    Assert-Equal 2 $suppressedDocument.campaigns[1].order 'Suppression changed a record without a display flag.'
    $suppressedBytes = [IO.File]::ReadAllBytes($globalCampaign)
    Assert-True (-not ($suppressedBytes.Length -ge 3 -and $suppressedBytes[0] -eq 0xef -and $suppressedBytes[1] -eq 0xbb -and $suppressedBytes[2] -eq 0xbf)) 'The suppressed campaign file contains a UTF-8 byte order mark.'
    Assert-Equal $globalCampaignJson ([IO.File]::ReadAllText($suppress.Data.Backups[0].Backup)) 'The campaign backup does not match the original bytes.'
    Assert-Equal $false (Get-Item -LiteralPath $suppress.Data.Backups[0].Backup).IsReadOnly 'The campaign backup is not owner-readable.'
    Assert-Equal 'Running' $adsJournal.State 'Campaign suppression closed the journal.'
    $repressedJournal = Get-OperationJournal -Path $adsJournal.JournalPath
    Assert-Equal 'Running' $repressedJournal.State 'Campaign suppression closed the persisted journal.'
    Assert-True (@($repressedJournal.Checkpoints).Count -ge 1) 'Campaign suppression recorded no journal checkpoint.'
    Assert-True (@($repressedJournal.Checkpoints)[-1].Data.Backup -eq $suppress.Data.Backups[0].Backup) 'The journal checkpoint does not record the campaign restore point.'

    $campaignBeforeDuplicate = [IO.File]::ReadAllText($globalCampaign)
    $backupBeforeDuplicate = [IO.File]::ReadAllBytes($suppress.Data.Backups[0].Backup)
    $duplicateJournal = New-AdsJournal -Name 'journal duplicate'
    $duplicate = Suppress-MuMuAds -Paths @($globalCampaign) -BackupRoot $adsBackupRoot -Journal $duplicateJournal
    Assert-Equal 'CriticalError' $duplicate.Status 'Duplicate suppression overwrote a backup.'
    Assert-True ($duplicate.Message -match '(?i)exists|restore point|already') 'The duplicate suppression failure did not explain the collision.'
    Assert-AdsUnchanged -Path $globalCampaign -Expected $campaignBeforeDuplicate -Message 'Duplicate suppression changed the campaign file.'
    Assert-Equal ([Convert]::ToBase64String($backupBeforeDuplicate)) ([Convert]::ToBase64String([IO.File]::ReadAllBytes($suppress.Data.Backups[0].Backup))) 'Duplicate suppression changed the existing campaign backup.'
    Assert-Equal 'Failed' $duplicateJournal.State 'A refused duplicate suppression did not journal the failure.'
    Assert-Equal 'CriticalError' (Get-OperationJournal -Path $duplicateJournal.JournalPath).Result.Status 'The duplicate suppression failure was not persisted.'
    Assert-Equal 'Running' $adsJournal.State 'A refused duplicate suppression closed an unrelated journal.'

    $restore = Restore-MuMuAds -BackupRoot $adsBackupRoot -AllowedRoot $globalAdsInstall.InstallRoot -Journal $adsJournal
    Assert-Equal 'Success' $restore.Status "Campaign restore failed. $($restore.Message)"
    Assert-Equal 1 $restore.Data.Restored 'Campaign restore reported the wrong count.'
    Assert-AdsUnchanged -Path $globalCampaign -Expected $globalCampaignJson -Message 'Campaign bytes were not restored exactly.'
    Assert-Equal $false (Get-Item -LiteralPath $globalCampaign).IsReadOnly 'Restore changed the campaign read-only state.'
    Assert-True ([IO.File]::Exists($suppress.Data.Backups[0].Backup)) 'The restore deleted the campaign backup.'
    Assert-True ([IO.File]::Exists((Join-Path $adsBackupRoot 'restore-point.json'))) 'The restore deleted the restore point manifest.'

    $readOnlyAdsInstall = New-AdsInstallFixture -Name 'ReadOnly\MuMu Global' -Edition 'Global'
    $readOnlyCampaign = Join-Path $readOnlyAdsInstall.InstallRoot 'shell\ad\campaign.json'
    $readOnlyCampaignJson = '{"campaigns":[{"id":"ro","display":true}]}'
    New-AdsCampaignFixture -Path $readOnlyCampaign -Json $readOnlyCampaignJson -ReadOnly $true
    $readOnlyBackupRoot = New-AdsBackupRoot -Name 'backup read only'
    $readOnlyJournal = New-AdsJournal -Name 'journal read only'
    $readOnlySuppress = Suppress-MuMuAds -Paths @($readOnlyCampaign) -BackupRoot $readOnlyBackupRoot -Journal $readOnlyJournal
    Assert-Equal 'Success' $readOnlySuppress.Status "Read-only campaign suppression failed. $($readOnlySuppress.Message)"
    Assert-True ((Get-Item -LiteralPath $readOnlyCampaign).IsReadOnly) 'Campaign read-only state was not preserved.'
    Assert-Equal $false ((([IO.File]::ReadAllText($readOnlyCampaign) | ConvertFrom-Json).campaigns[0]).display) 'A read-only campaign was not suppressed.'
    $readOnlyRestore = Restore-MuMuAds -BackupRoot $readOnlyBackupRoot -AllowedRoot $readOnlyAdsInstall.InstallRoot -Journal $readOnlyJournal
    Assert-Equal 'Success' $readOnlyRestore.Status "Read-only campaign restore failed. $($readOnlyRestore.Message)"
    Assert-AdsUnchanged -Path $readOnlyCampaign -Expected $readOnlyCampaignJson -Message 'Read-only campaign bytes were not restored exactly.'
    Assert-True ((Get-Item -LiteralPath $readOnlyCampaign).IsReadOnly) 'Restore did not preserve the read-only state.'

    $noDisplayAdsInstall = New-AdsInstallFixture -Name 'NoDisplay\MuMu Global' -Edition 'Global'
    $noDisplayCampaign = Join-Path $noDisplayAdsInstall.InstallRoot 'shell\ad\campaign.json'
    $noDisplayCampaignJson = '{"campaigns":[{"id":"none","order":1}]}'
    New-AdsCampaignFixture -Path $noDisplayCampaign -Json $noDisplayCampaignJson
    $noDisplayBackupRoot = New-AdsBackupRoot -Name 'backup no display'
    $noDisplayJournal = New-AdsJournal -Name 'journal no display'
    $noDisplaySuppress = Suppress-MuMuAds -Paths @($noDisplayCampaign) -BackupRoot $noDisplayBackupRoot -Journal $noDisplayJournal
    Assert-Equal 'AlreadyApplied' $noDisplaySuppress.Status 'A campaign without display flags was reported as a change.'
    Assert-Equal 0 $noDisplaySuppress.Data.Changed 'A campaign without display flags was counted as changed.'
    Assert-Equal 1 $noDisplaySuppress.Data.Skipped 'A campaign without display flags was not counted as skipped.'
    Assert-AdsUnchanged -Path $noDisplayCampaign -Expected $noDisplayCampaignJson -Message 'A campaign without display flags was rewritten.'
    Assert-Equal 0 @(Get-AdsRestorePointFile -BackupRoot $noDisplayBackupRoot).Count 'A skipped campaign created a backup.'
    $noDisplayRestore = Restore-MuMuAds -BackupRoot $noDisplayBackupRoot -AllowedRoot $noDisplayAdsInstall.InstallRoot -Journal $noDisplayJournal
    Assert-Equal 'CriticalError' $noDisplayRestore.Status 'A skipped campaign produced a restorable restore point.'

    $malformedCampaignCases = @(
        @{ Label = 'truncated'; Json = '{"campaigns":[{' },
        @{ Label = 'not json'; Json = 'not json at all' },
        @{ Label = 'empty object'; Json = '{}' },
        @{ Label = 'missing list'; Json = '{"version":1}' },
        @{ Label = 'string list'; Json = '{"campaigns":"alpha"}' },
        @{ Label = 'empty list'; Json = '{"campaigns":[]}' },
        @{ Label = 'empty array root'; Json = '[]' },
        @{ Label = 'scalar root'; Json = '17' },
        @{ Label = 'string root'; Json = '"alpha"' },
        @{ Label = 'nonobject records'; Json = '{"campaigns":["alpha"]}' },
        @{ Label = 'single-quoted pseudo json'; Json = "{'campaigns':[{'id':'alpha','display':true}]}" },
        @{ Label = 'single-quoted pseudo json object'; Json = "{'campaigns':'alpha'}" },
        @{ Label = 'duplicate campaigns key'; Json = '{"campaigns":[{"id":"alpha","display":true}],"campaigns":[{"id":"beta","display":true}]}' },
        @{ Label = 'duplicate case-variant key'; Json = '{"campaigns":[],"CAMPAIGNS":[]}' },
        @{ Label = 'duplicate record key'; Json = '{"campaigns":[{"id":"alpha","display":true,"display":false}]}' },
        @{ Label = 'trailing comma'; Json = '{"campaigns":[{"id":"alpha","display":true}],}' }
    )
    foreach ($malformedCase in $malformedCampaignCases) {
        $malformedAdsInstall = New-AdsInstallFixture -Name ('malformed ' + $malformedCase.Label + '\MuMu Global') -Edition 'Global'
        $malformedCampaign = Join-Path $malformedAdsInstall.InstallRoot 'shell\ad\campaign.json'
        New-AdsCampaignFixture -Path $malformedCampaign -Json $malformedCase.Json
        $malformedBackupRoot = New-AdsBackupRoot -Name ('malformed backup ' + $malformedCase.Label)
        $malformedJournal = New-AdsJournal -Name ('malformed journal ' + $malformedCase.Label)
        $malformedSuppress = Suppress-MuMuAds -Paths @($malformedCampaign) -BackupRoot $malformedBackupRoot -Journal $malformedJournal
        Assert-Equal 'CriticalError' $malformedSuppress.Status "A campaign document that is not a complete campaign list was accepted: $($malformedCase.Label)"
        Assert-True ($malformedSuppress.Message -match '(?i)json') "The campaign validation failure did not name JSON: $($malformedCase.Label)"
        Assert-AdsUnchanged -Path $malformedCampaign -Expected $malformedCase.Json -Message "A refused campaign document was modified: $($malformedCase.Label)"
        Assert-Equal 0 @(Get-AdsRestorePointFile -BackupRoot $malformedBackupRoot).Count "A refused campaign document created a backup: $($malformedCase.Label)"
        Assert-Equal 'Failed' $malformedJournal.State "A refused campaign document did not journal the failure: $($malformedCase.Label)"
        Assert-Equal 'CriticalError' (Get-OperationJournal -Path $malformedJournal.JournalPath).Result.Status "The refused campaign document failure was not persisted: $($malformedCase.Label)"
    }

    $equivalentLeft = '{"campaigns":[{"id":"a","display":true,"ratio":0.25,"tags":["x","y"]}],"version":3}' | ConvertFrom-Json
    $equivalentRight = '{"campaigns":[{"id":"a","display":true,"ratio":0.25,"tags":["x","y"]}],"version":3}' | ConvertFrom-Json
    Assert-True (Test-CampaignEquivalent -Left $equivalentLeft -Right $equivalentRight) 'Two equal campaign documents were reported as different.'
    $truncatedTail = '1'
    for ($level = 0; $level -lt 30; $level++) { $truncatedTail = '{"n":' + $truncatedTail + '}' }
    $truncatedLeft = '{"campaigns":[{"id":"a","meta":' + $truncatedTail + '}]}' | ConvertFrom-Json
    $truncatedRight = '{"campaigns":[{"id":"a","meta":' + $truncatedTail + '}]}' | ConvertFrom-Json
    $shallowText = ConvertTo-Json -InputObject $truncatedRight -Depth 20
    $shallowRight = $shallowText | ConvertFrom-Json
    Assert-True (-not (Test-CampaignEquivalent -Left $truncatedLeft -Right $shallowRight)) 'A depth-truncated round trip was reported as equivalent.'
    $typeLeft = '{"campaigns":[{"id":"a","ratio":1}]}' | ConvertFrom-Json
    $typeRight = '{"campaigns":[{"id":"a","ratio":"1"}]}' | ConvertFrom-Json
    Assert-True (-not (Test-CampaignEquivalent -Left $typeLeft -Right $typeRight)) 'A type-changed campaign value was reported as equivalent.'
    $countLeft = '{"campaigns":[{"id":"a","tags":["x"]}]}' | ConvertFrom-Json
    $countRight = '{"campaigns":[{"id":"a","tags":["x","y"]}]}' | ConvertFrom-Json
    Assert-True (-not (Test-CampaignEquivalent -Left $countLeft -Right $countRight)) 'A different campaign array length was reported as equivalent.'
    $nameLeft = '{"campaigns":[{"id":"a","display":true}]}' | ConvertFrom-Json
    $nameRight = '{"campaigns":[{"ident":"a","display":true}]}' | ConvertFrom-Json
    Assert-True (-not (Test-CampaignEquivalent -Left $nameLeft -Right $nameRight)) 'A renamed campaign property was reported as equivalent.'
    $extraLeft = '{"campaigns":[{"id":"a","display":true}]}' | ConvertFrom-Json
    $extraRight = '{"campaigns":[{"id":"a","display":true,"extra":1}],"version":1}' | ConvertFrom-Json
    Assert-True (-not (Test-CampaignEquivalent -Left $extraLeft -Right $extraRight)) 'A campaign document with extra properties was reported as equivalent.'
    $nullLeft = '{"campaigns":[{"id":"a","ratio":null}]}' | ConvertFrom-Json
    $nullRight = '{"campaigns":[{"id":"a","ratio":0}]}' | ConvertFrom-Json
    Assert-True (-not (Test-CampaignEquivalent -Left $nullLeft -Right $nullRight)) 'A null campaign value was reported as equivalent to a number.'
    Assert-True (Test-CampaignEquivalent -Left $null -Right $null) 'Two null campaign values were reported as different.'

    $deepAdsInstall = New-AdsInstallFixture -Name 'Deep\MuMu Global' -Edition 'Global'
    $deepCampaign = Join-Path $deepAdsInstall.InstallRoot 'shell\ad\campaign.json'
    $deepTail = '1'
    for ($level = 0; $level -lt 30; $level++) {
        $deepTail = '{"n":' + $deepTail + '}'
    }
    $deepCampaignJson = '{"campaigns":[{"id":"deep","display":true,"meta":' + $deepTail + '}]}'
    New-AdsCampaignFixture -Path $deepCampaign -Json $deepCampaignJson
    $deepBackupRoot = New-AdsBackupRoot -Name 'backup deep'
    $deepJournal = New-AdsJournal -Name 'journal deep'
    $deepSuppress = Suppress-MuMuAds -Paths @($deepCampaign) -BackupRoot $deepBackupRoot -Journal $deepJournal
    Assert-Equal 'Success' $deepSuppress.Status "A deeply nested campaign was refused. $($deepSuppress.Message)"
    $deepDocument = [IO.File]::ReadAllText($deepCampaign) | ConvertFrom-Json
    Assert-Equal $false $deepDocument.campaigns[0].display 'The deeply nested campaign was not suppressed.'
    $deepNode = $deepDocument.campaigns[0].meta
    for ($level = 0; $level -lt 30; $level++) {
        $deepNode = $deepNode.n
    }
    Assert-Equal 1 $deepNode 'A deeply nested campaign value was truncated.'
    $deepRestoreJournal = New-AdsJournal -Name 'journal deep restore'
    $deepRestore = Restore-MuMuAds -BackupRoot $deepBackupRoot -AllowedRoot $deepAdsInstall.InstallRoot -Journal $deepRestoreJournal
    Assert-Equal 'Success' $deepRestore.Status "The deeply nested campaign was not restored. $($deepRestore.Message)"
    Assert-AdsUnchanged -Path $deepCampaign -Expected $deepCampaignJson -Message 'The deeply nested campaign was not restored exactly.'

    $alreadyAdsInstall = New-AdsInstallFixture -Name 'AlreadyFalse\MuMu Global' -Edition 'Global'
    $alreadyCampaign = Join-Path $alreadyAdsInstall.InstallRoot 'shell\ad\campaign.json'
    $alreadyCampaignJson = '{"campaigns":[{"id":"already","display":false}]}'
    New-AdsCampaignFixture -Path $alreadyCampaign -Json $alreadyCampaignJson
    $alreadyBackupRoot = New-AdsBackupRoot -Name 'backup already false'
    $alreadyJournal = New-AdsJournal -Name 'journal already false'
    $alreadySuppress = Suppress-MuMuAds -Paths @($alreadyCampaign) -BackupRoot $alreadyBackupRoot -Journal $alreadyJournal
    Assert-Equal 'AlreadyApplied' $alreadySuppress.Status 'A campaign whose display flags were already false was reported as a change.'
    Assert-Equal 0 $alreadySuppress.Data.Changed 'A no-op campaign rewrite was counted as a change.'
    Assert-Equal 1 $alreadySuppress.Data.Skipped 'A no-op campaign rewrite was not counted as skipped.'
    Assert-Equal 0 @($alreadySuppress.Data.Backups).Count 'A no-op campaign rewrite reported a backup.'
    Assert-Equal 0 @(Get-AdsRestorePointFile -BackupRoot $alreadyBackupRoot).Count 'A no-op campaign rewrite created a backup file.'
    Assert-True (-not [IO.File]::Exists([IO.Path]::Combine($alreadyBackupRoot, 'restore-point.json'))) 'A no-op campaign rewrite created a restore point manifest.'
    Assert-AdsUnchanged -Path $alreadyCampaign -Expected $alreadyCampaignJson -Message 'A no-op campaign rewrite changed the file.'

    $lockedAdsInstall = New-AdsInstallFixture -Name 'Locked\MuMu Global' -Edition 'Global'
    $lockedCampaign = Join-Path $lockedAdsInstall.InstallRoot 'shell\ad\campaign.json'
    $lockedCampaignJson = '{"campaigns":[{"id":"locked","display":true}]}'
    New-AdsCampaignFixture -Path $lockedCampaign -Json $lockedCampaignJson -ReadOnly $true
    $lockedBackupRoot = New-AdsBackupRoot -Name 'backup locked'
    $lockedJournal = New-AdsJournal -Name 'journal locked'
    $lockedHandle = [IO.File]::Open($lockedCampaign, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $lockedSuppress = Suppress-MuMuAds -Paths @($lockedCampaign) -BackupRoot $lockedBackupRoot -Journal $lockedJournal
    }
    finally {
        $lockedHandle.Dispose()
    }
    Assert-Equal 'CriticalError' $lockedSuppress.Status 'A campaign replacement that could not complete was accepted.'
    Assert-True ($lockedSuppress.Message -match '(?i)replacement') "The failed campaign replacement did not name the replacement: $($lockedSuppress.Message)"
    Assert-AdsUnchanged -Path $lockedCampaign -Expected $lockedCampaignJson -Message 'A failed campaign replacement changed the original bytes.'
    Assert-True ((Get-Item -LiteralPath $lockedCampaign).IsReadOnly) 'A failed campaign replacement changed the read-only state.'
    $lockedBackupPath = @(Get-AdsRestorePointFile -BackupRoot $lockedBackupRoot)[0]
    Assert-True ([IO.File]::Exists($lockedBackupPath)) 'A failed campaign replacement destroyed the backup.'
    Assert-AdsUnchanged -Path $lockedBackupPath -Expected $lockedCampaignJson -Message 'A failed campaign replacement changed the backup.'
    Assert-Equal 1 @(Get-AdsRestorePointFile -BackupRoot $lockedBackupRoot).Count 'A failed campaign replacement left an unexpected backup file.'
    $lockedTemporaryFiles = @([IO.Directory]::GetFiles($lockedAdsInstall.InstallRoot, '.*', [IO.SearchOption]::AllDirectories) | Where-Object { $_.Contains('.tmp') -or $_.Contains('.bak') })
    Assert-Equal 0 $lockedTemporaryFiles.Count 'A failed campaign replacement left a temporary file in the campaign directory.'
    Assert-Equal 'Failed' $lockedJournal.State 'A failed campaign replacement did not journal the failure.'
    $lockedManifestPath = [IO.Path]::Combine($lockedBackupRoot, 'restore-point.json')
    Assert-True ([IO.File]::Exists($lockedManifestPath)) 'A prepared restore point was not persisted before the campaign replacement was attempted.'
    $lockedManifest = Get-AdsManifest -BackupRoot $lockedBackupRoot
    Assert-Equal 0 $lockedManifest.Applied 'A prepared restore point claimed a completed replacement.'
    Assert-Equal 1 @($lockedManifest.Records).Count 'A prepared restore point did not record the in-flight campaign file.'
    $lockedManifestRecord = @($lockedManifest.Records)[0]
    Assert-Equal $lockedCampaign $lockedManifestRecord.Source 'A prepared restore point recorded the wrong campaign path.'
    $lockedRestoreJournal = New-AdsJournal -Name 'journal locked restore'
    $lockedRestore = Restore-MuMuAds -BackupRoot $lockedBackupRoot -AllowedRoot $lockedAdsInstall.InstallRoot -Journal $lockedRestoreJournal
    Assert-Equal 'Success' $lockedRestore.Status "A prepared restore point from a failed replacement could not be restored. $($lockedRestore.Message)"
    Assert-Equal 1 $lockedRestore.Data.Prepared 'The prepared restore point did not report the prepared count.'
    Assert-Equal 0 $lockedRestore.Data.Applied 'The prepared restore point reported a completed replacement.'
    Assert-Equal 1 $lockedRestore.Data.Restored 'The prepared restore point did not restore the in-flight file.'
    Assert-AdsUnchanged -Path $lockedCampaign -Expected $lockedCampaignJson -Message 'Restoring a prepared record changed the campaign bytes.'
    Assert-True ((Get-Item -LiteralPath $lockedCampaign).IsReadOnly) 'Restoring a prepared record changed the read-only state.'

    $partialAdsInstall = New-AdsInstallFixture -Name 'Partial\MuMu Global' -Edition 'Global'
    $partialCampaign = Join-Path $partialAdsInstall.InstallRoot 'shell\ad\campaign.json'
    $partialCampaignJson = '{"campaigns":[{"id":"partial","display":true}]}'
    $partialBadCampaign = Join-Path $partialAdsInstall.InstallRoot 'nx_device\configs\campaign.json'
    $partialBadCampaignJson = '{"campaigns":[{"id":"bad"'
    New-AdsCampaignFixture -Path $partialCampaign -Json $partialCampaignJson
    New-AdsCampaignFixture -Path $partialBadCampaign -Json $partialBadCampaignJson
    $partialBackupRoot = New-AdsBackupRoot -Name 'backup partial'
    $partialJournal = New-AdsJournal -Name 'journal partial'
    $partialSuppress = Suppress-MuMuAds -Paths @($partialCampaign, $partialBadCampaign) -BackupRoot $partialBackupRoot -Journal $partialJournal
    Assert-Equal 'CriticalError' $partialSuppress.Status 'A campaign operation with a valid first file and a malformed second file reported success.'
    $partialManifest = Get-AdsManifest -BackupRoot $partialBackupRoot
    Assert-Equal 1 $partialManifest.Applied 'The partial restore point did not report one applied replacement.'
    Assert-Equal 1 @($partialManifest.Records).Count 'The partial restore point did not record the completed campaign file.'
    Assert-Equal $partialCampaign @($partialManifest.Records)[0].Source 'The partial restore point recorded the wrong campaign path.'
    $partialSuppressed = [IO.File]::ReadAllText($partialCampaign) | ConvertFrom-Json
    Assert-Equal $false $partialSuppressed.campaigns[0].display 'The first campaign was not suppressed before the later failure.'
    Assert-AdsUnchanged -Path $partialBadCampaign -Expected $partialBadCampaignJson -Message 'The malformed campaign was modified by a partial failure.'
    $partialRestoreJournal = New-AdsJournal -Name 'journal partial restore'
    $partialRestore = Restore-MuMuAds -BackupRoot $partialBackupRoot -AllowedRoot $partialAdsInstall.InstallRoot -Journal $partialRestoreJournal
    Assert-Equal 'Success' $partialRestore.Status "The partially completed campaign operation was not reversible. $($partialRestore.Message)"
    Assert-Equal 1 $partialRestore.Data.Restored 'The partial restore reported the wrong restored count.'
    Assert-AdsUnchanged -Path $partialCampaign -Expected $partialCampaignJson -Message 'The partially suppressed campaign was not restored exactly.'
    $partialRetryRoot = New-AdsBackupRoot -Name 'backup partial retry'
    $partialRetryJournal = New-AdsJournal -Name 'journal partial retry'
    $partialRetry = Suppress-MuMuAds -Paths @($partialCampaign) -BackupRoot $partialRetryRoot -Journal $partialRetryJournal
    Assert-Equal 'Success' $partialRetry.Status "The campaign operation was not retryable after a partial failure. $($partialRetry.Message)"
    Assert-Equal 1 $partialRetry.Data.Changed 'The retry did not change the campaign file.'
    Assert-Equal $false (([IO.File]::ReadAllText($partialCampaign) | ConvertFrom-Json).campaigns[0].display) 'The retry did not suppress the campaign.'

    $ownershipRoot = New-AdsBackupRoot -Name 'restore point ownership'
    $ownershipPath = [IO.Path]::Combine($ownershipRoot, 'restore-point.json')
    $ownershipCreate = Set-CampaignRestorePoint -Path $ownershipPath -Text '{"SchemaVersion":1,"Applied":0,"Records":[]}' -ExpectedText ''
    Assert-Equal 'Success' $ownershipCreate.Status "A restore point manifest could not be created. $($ownershipCreate.Message)"
    $ownershipDuplicate = Set-CampaignRestorePoint -Path $ownershipPath -Text '{"SchemaVersion":1,"Applied":9,"Records":[]}' -ExpectedText ''
    Assert-Equal 'CriticalError' $ownershipDuplicate.Status 'A create over an existing restore point manifest was accepted.'
    $ownershipStale = Set-CampaignRestorePoint -Path $ownershipPath -Text '{"SchemaVersion":1,"Applied":9,"Records":[]}' -ExpectedText '{"SchemaVersion":1,"Applied":5,"Records":[]}'
    Assert-Equal 'CriticalError' $ownershipStale.Status 'A restore point manifest was refreshed without proof of ownership.'
    Assert-True ($ownershipStale.Message -match '(?i)never overwritten') 'The unowned refresh failure did not explain the no-overwrite rule.'
    Assert-Equal '{"SchemaVersion":1,"Applied":0,"Records":[]}' ([IO.File]::ReadAllText($ownershipPath)) 'A refused refresh changed the restore point manifest.'
    $ownershipRefresh = Set-CampaignRestorePoint -Path $ownershipPath -Text '{"SchemaVersion":1,"Applied":1,"Records":[]}' -ExpectedText '{"SchemaVersion":1,"Applied":0,"Records":[]}'
    Assert-Equal 'Success' $ownershipRefresh.Status "An owned refresh of a restore point manifest failed. $($ownershipRefresh.Message)"
    Assert-Equal 1 (Get-AdsManifest -BackupRoot $ownershipRoot).Applied 'An owned refresh did not update the manifest.'
    Assert-Equal 0 @(Get-AdsRestorePointFile -BackupRoot $ownershipRoot).Count 'A manifest refresh left a temporary file behind.'

    $multiAdsInstall = New-AdsInstallFixture -Name 'Multi\MuMu Global' -Edition 'Global'
    $multiHostPath = Join-Path $multiAdsInstall.InstallRoot 'shell\ad\hosts'
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($multiHostPath))
    [IO.File]::WriteAllText($multiHostPath, '127.0.0.1 mumu fixture')
    $multiDataPath = Join-Path $multiAdsInstall.InstallRoot 'shell\ad\userdata.json'
    [IO.File]::WriteAllText($multiDataPath, '{"app":"fixture"}')
    $multiCampaign = Join-Path $multiAdsInstall.InstallRoot 'shell\ad\campaign.json'
    $multiConfigCampaign = Join-Path $multiAdsInstall.InstallRoot 'nx_device\configs\campaign.json'
    $multiCampaignJson = '{"campaigns":[{"id":"m1","display":true}]}'
    $multiConfigCampaignJson = '{"campaigns":[{"id":"m2","display":1,"ratio":0.25}]}'
    New-AdsCampaignFixture -Path $multiCampaign -Json $multiCampaignJson
    New-AdsCampaignFixture -Path $multiConfigCampaign -Json $multiConfigCampaignJson
    $multiBackupRoot = New-AdsBackupRoot -Name 'backup multi'
    $multiJournal = New-AdsJournal -Name 'journal multi'
    $multiSuppress = Suppress-MuMuAds -Paths @($multiCampaign, $multiConfigCampaign) -BackupRoot $multiBackupRoot -Journal $multiJournal
    Assert-Equal 'Success' $multiSuppress.Status "Multi-file campaign suppression failed. $($multiSuppress.Message)"
    Assert-Equal 2 $multiSuppress.Data.Changed 'Multi-file suppression reported the wrong changed count.'
    Assert-Equal 2 @($multiSuppress.Data.Backups).Count 'Multi-file suppression reported the wrong backup count.'
    $multiConfigDocument = [IO.File]::ReadAllText($multiConfigCampaign) | ConvertFrom-Json
    Assert-True ($multiConfigDocument.campaigns[0].display -is [bool]) 'A numeric display flag was not replaced with a boolean.'
    Assert-Equal $false $multiConfigDocument.campaigns[0].display 'A numeric display flag was not suppressed.'
    Assert-Equal 0.25 $multiConfigDocument.campaigns[0].ratio 'Suppression changed an unrelated numeric field.'
    Assert-Equal 2 @(Get-AdsRestorePointFile -BackupRoot $multiBackupRoot).Count 'Multi-file suppression did not write one restore point record per file.'
    Assert-AdsUnchanged -Path $multiHostPath -Expected '127.0.0.1 mumu fixture' -Message 'Campaign suppression modified an unrelated hosts-like file.'
    Assert-AdsUnchanged -Path $multiDataPath -Expected '{"app":"fixture"}' -Message 'Campaign suppression modified an unrelated JSON file.'
    $multiRestore = Restore-MuMuAds -BackupRoot $multiBackupRoot -AllowedRoot $multiAdsInstall.InstallRoot -Journal $multiJournal
    Assert-Equal 'Success' $multiRestore.Status "Multi-file campaign restore failed. $($multiRestore.Message)"
    Assert-Equal 2 $multiRestore.Data.Restored 'Multi-file restore reported the wrong count.'
    Assert-AdsUnchanged -Path $multiCampaign -Expected $multiCampaignJson -Message 'Multi-file restore did not restore the first campaign exactly.'
    Assert-AdsUnchanged -Path $multiConfigCampaign -Expected $multiConfigCampaignJson -Message 'Multi-file restore did not restore the second campaign exactly.'

    $secondInstallBackupRoot = New-AdsBackupRoot -Name 'backup second install'
    $secondInstallJournal = New-AdsJournal -Name 'journal second install'
    $secondInstallSuppress = Suppress-MuMuAds -Paths @($chineseCampaign) -BackupRoot $secondInstallBackupRoot -Journal $secondInstallJournal
    Assert-Equal 'Success' $secondInstallSuppress.Status "Chinese campaign suppression failed. $($secondInstallSuppress.Message)"
    $secondManifestBefore = [IO.File]::ReadAllText((Join-Path $secondInstallBackupRoot 'restore-point.json'))
    Assert-Equal $false (([IO.File]::ReadAllText($chineseCampaign) | ConvertFrom-Json)[0].display) 'The Chinese campaign was not suppressed.'
    $chineseSuppressed = [IO.File]::ReadAllText($chineseCampaign) | ConvertFrom-Json
    Assert-Equal 1 @($chineseSuppressed).Count 'An array-root campaign document was not rewritten as a JSON array.'
    Assert-Equal 'delta' @($chineseSuppressed)[0].id 'The array-root campaign document lost its record identity.'
    Assert-Equal 'cn' @($chineseSuppressed)[0].name 'The array-root campaign document lost an unrelated field.'
    $secondInstallRestore = Restore-MuMuAds -BackupRoot $secondInstallBackupRoot -AllowedRoot $chineseAdsInstall.InstallRoot -Journal $secondInstallJournal
    Assert-Equal 'Success' $secondInstallRestore.Status "Chinese campaign restore failed. $($secondInstallRestore.Message)"
    Assert-AdsUnchanged -Path $chineseCampaign -Expected $chineseCampaignJson -Message 'The array-root campaign document was not restored exactly.'

    $sharedAdsInstall = New-AdsInstallFixture -Name 'Shared\MuMu Global' -Edition 'Global'
    $sharedCampaign = Join-Path $sharedAdsInstall.InstallRoot 'shell\ad\campaign.json'
    $sharedCampaignJson = '{"campaigns":[{"id":"shared","display":true}]}'
    New-AdsCampaignFixture -Path $sharedCampaign -Json $sharedCampaignJson
    $otherAdsInstall = New-AdsInstallFixture -Name 'Shared Other\MuMu Global' -Edition 'Global'
    $otherCampaign = Join-Path $otherAdsInstall.InstallRoot 'shell\ad\campaign.json'
    $otherCampaignJson = '{"campaigns":[{"id":"other","display":true}]}'
    New-AdsCampaignFixture -Path $otherCampaign -Json $otherCampaignJson
    $sharedBackupRoot = New-AdsBackupRoot -Name 'backup shared restore point'
    $sharedJournal = New-AdsJournal -Name 'journal shared restore point'
    $sharedSuppress = Suppress-MuMuAds -Paths @($sharedCampaign) -BackupRoot $sharedBackupRoot -Journal $sharedJournal
    Assert-Equal 'Success' $sharedSuppress.Status "The first operation of a shared restore point failed. $($sharedSuppress.Message)"
    Assert-Equal 1 @($sharedSuppress.Data.Backups).Count 'The first operation did not record exactly one restore point.'
    $sharedManifestBefore = [IO.File]::ReadAllText((Join-Path $sharedBackupRoot 'restore-point.json'))
    $sharedJournalDuplicate = New-AdsJournal -Name 'journal shared restore point duplicate'
    $sharedDuplicate = Suppress-MuMuAds -Paths @($otherCampaign) -BackupRoot $sharedBackupRoot -Journal $sharedJournalDuplicate
    Assert-Equal 'CriticalError' $sharedDuplicate.Status 'A second operation overwrote an existing campaign restore point manifest.'
    Assert-Equal $sharedManifestBefore ([IO.File]::ReadAllText((Join-Path $sharedBackupRoot 'restore-point.json'))) 'A second operation overwrote the restore point manifest.'
    Assert-Equal $secondManifestBefore ([IO.File]::ReadAllText((Join-Path $secondInstallBackupRoot 'restore-point.json'))) 'A second operation changed an unrelated restore point manifest.'
    Assert-Equal 1 @(Get-AdsRestorePointFile -BackupRoot $sharedBackupRoot).Count 'A refused second operation added a restore point file.'
    Assert-AdsUnchanged -Path $otherCampaign -Expected $otherCampaignJson -Message 'A refused second operation changed the new campaign file.'
    Assert-Equal 'Failed' $sharedJournalDuplicate.State 'A refused second operation did not journal the failure.'
    $sharedRestore = Restore-MuMuAds -BackupRoot $sharedBackupRoot -AllowedRoot $sharedAdsInstall.InstallRoot -Journal $sharedJournal
    Assert-Equal 'Success' $sharedRestore.Status 'A shared restore point could not be restored after a refused second operation.'
    Assert-AdsUnchanged -Path $sharedCampaign -Expected $sharedCampaignJson -Message 'A shared restore point did not restore the first campaign exactly.'

    $duplicatePathBackupRoot = New-AdsBackupRoot -Name 'backup duplicate path'
    $duplicatePathJournal = New-AdsJournal -Name 'journal duplicate path'
    $duplicatePathSuppress = Suppress-MuMuAds -Paths @($multiCampaign, $multiCampaign) -BackupRoot $duplicatePathBackupRoot -Journal $duplicatePathJournal
    Assert-Equal 'Success' $duplicatePathSuppress.Status "A repeated campaign path failed. $($duplicatePathSuppress.Message)"
    Assert-Equal 1 $duplicatePathSuppress.Data.Changed 'A repeated campaign path was suppressed twice.'
    Assert-Equal 1 @(Get-AdsRestorePointFile -BackupRoot $duplicatePathBackupRoot).Count 'A repeated campaign path created two restore point records.'

    $tamperAdsInstall = New-AdsInstallFixture -Name 'Tamper\MuMu Global' -Edition 'Global'
    $tamperCampaign = Join-Path $tamperAdsInstall.InstallRoot 'shell\ad\campaign.json'
    $tamperCampaignJson = '{"campaigns":[{"id":"tamper","display":true}]}'
    New-AdsCampaignFixture -Path $tamperCampaign -Json $tamperCampaignJson
    $tamperBackupRoot = New-AdsBackupRoot -Name 'backup tamper'
    $tamperJournal = New-AdsJournal -Name 'journal tamper'
    $tamperSuppress = Suppress-MuMuAds -Paths @($tamperCampaign) -BackupRoot $tamperBackupRoot -Journal $tamperJournal
    Assert-Equal 'Success' $tamperSuppress.Status "The tamper fixture was not suppressed. $($tamperSuppress.Message)"
    $tamperSuppressedJson = [IO.File]::ReadAllText($tamperCampaign)
    $tamperBackupPath = @(Get-AdsRestorePointFile -BackupRoot $tamperBackupRoot)[0]
    $tamperManifestPath = Join-Path $tamperBackupRoot 'restore-point.json'
    $tamperBackupLength = [IO.File]::ReadAllBytes($tamperBackupPath).Length
    [IO.File]::WriteAllText($tamperBackupPath, ('X' * $tamperBackupLength))
    $tamperRestore = Restore-MuMuAds -BackupRoot $tamperBackupRoot -AllowedRoot $tamperAdsInstall.InstallRoot -Journal $tamperJournal
    Assert-Equal 'CriticalError' $tamperRestore.Status 'A tampered campaign restore point was restored.'
    Assert-True ($tamperRestore.Message -match '(?i)hash|length') "The tampered restore point failure did not name the verification: $($tamperRestore.Message)"
    Assert-AdsUnchanged -Path $tamperCampaign -Expected $tamperSuppressedJson -Message 'A failed restore changed the campaign bytes.'
    Assert-True ([IO.File]::Exists($tamperBackupPath)) 'A failed restore deleted the tampered backup.'
    Assert-True ([IO.File]::Exists($tamperManifestPath)) 'A failed restore deleted the restore point manifest.'
    [IO.File]::WriteAllText($tamperBackupPath, $tamperCampaignJson)
    $repairedJournal = New-AdsJournal -Name 'journal tamper repaired'
    $repairedRestore = Restore-MuMuAds -BackupRoot $tamperBackupRoot -AllowedRoot $tamperAdsInstall.InstallRoot -Journal $repairedJournal
    Assert-Equal 'Success' $repairedRestore.Status 'A repaired campaign restore point could not be restored.'
    Assert-AdsUnchanged -Path $tamperCampaign -Expected $tamperCampaignJson -Message 'A repaired restore did not return the original bytes.'

    [IO.File]::Delete($tamperBackupPath)
    $missingBackupJournal = New-AdsJournal -Name 'journal missing backup'
    $missingBackupRestore = Restore-MuMuAds -BackupRoot $tamperBackupRoot -AllowedRoot $tamperAdsInstall.InstallRoot -Journal $missingBackupJournal
    Assert-Equal 'CriticalError' $missingBackupRestore.Status 'A restore point with a missing backup file was restored.'
    Assert-True ($missingBackupRestore.Message -match '(?i)missing') 'The missing restore point file failure did not name the missing file.'
    Assert-AdsUnchanged -Path $tamperCampaign -Expected $tamperCampaignJson -Message 'A failed restore with a missing backup changed the campaign bytes.'

    $restorePointCases = @(
        @{ Label = 'missing manifest'; Manifest = $null },
        @{ Label = 'malformed manifest'; Manifest = '{not-json' },
        @{ Label = 'array manifest'; Manifest = '[]' },
        @{ Label = 'wrong schema version'; Manifest = '{"SchemaVersion":2,"Applied":1,"Records":[]}' },
        @{ Label = 'string schema version'; Manifest = '{"SchemaVersion":"1","Applied":1,"Records":[]}' },
        @{ Label = 'missing applied'; Manifest = '{"SchemaVersion":1,"Records":[]}' },
        @{ Label = 'string applied'; Manifest = '{"SchemaVersion":1,"Applied":"1","Records":[]}' },
        @{ Label = 'negative applied'; Manifest = '{"SchemaVersion":1,"Applied":-1,"Records":[]}' },
        @{ Label = 'applied beyond records'; Manifest = '{"SchemaVersion":1,"Applied":3,"Records":[]}' },
        @{ Label = 'missing records'; Manifest = '{"SchemaVersion":1,"Applied":0}' },
        @{ Label = 'empty records'; Manifest = '{"SchemaVersion":1,"Applied":0,"Records":[]}' },
        @{ Label = 'string records'; Manifest = '{"SchemaVersion":1,"Applied":0,"Records":"alpha"}' },
        @{ Label = 'missing record property'; Manifest = '{"SchemaVersion":1,"Applied":1,"Records":[{"Source":"C:\\fixture\\campaign.json","Backup":"C:\\fixture\\backup\\campaign.json","Sha256":"0000000000000000000000000000000000000000000000000000000000000000","ReadOnly":false}]}' },
        @{ Label = 'extra record property'; Manifest = '{"SchemaVersion":1,"Applied":1,"Records":[{"Source":"C:\\fixture\\campaign.json","Backup":"C:\\fixture\\backup\\campaign.json","Sha256":"0000000000000000000000000000000000000000000000000000000000000000","ReadOnly":false,"Length":1,"Extra":true}]}' },
        @{ Label = 'invalid record hash'; Manifest = '{"SchemaVersion":1,"Applied":1,"Records":[{"Source":"C:\\fixture\\campaign.json","Backup":"C:\\fixture\\backup\\campaign.json","Sha256":"not-a-hash","ReadOnly":false,"Length":1}]}' }
    )
    foreach ($restorePointCase in $restorePointCases) {
        $restorePointRoot = New-AdsBackupRoot -Name ('restore point ' + $restorePointCase.Label)
        if ($null -ne $restorePointCase.Manifest) {
            [IO.File]::WriteAllText((Join-Path $restorePointRoot 'restore-point.json'), $restorePointCase.Manifest)
        }
        $restorePointJournal = New-AdsJournal -Name ('restore point journal ' + $restorePointCase.Label)
        $restorePointResult = Restore-MuMuAds -BackupRoot $restorePointRoot -AllowedRoot $tamperAdsInstall.InstallRoot -Journal $restorePointJournal
        Assert-Equal 'CriticalError' $restorePointResult.Status "An incomplete campaign restore point was accepted: $($restorePointCase.Label)"
        Assert-True (-not [string]::IsNullOrWhiteSpace($restorePointResult.Message)) "An incomplete campaign restore point returned no reason: $($restorePointCase.Label)"
        Assert-Equal 'Failed' $restorePointJournal.State "An incomplete campaign restore point did not journal the failure: $($restorePointCase.Label)"
    }

    $outsideAdsBackupPath = Join-Path $script:adsFixtureRoot 'outside campaign.json'
    [IO.File]::WriteAllText($outsideAdsBackupPath, $tamperCampaignJson)
    $escapedRecordRoot = New-AdsBackupRoot -Name 'restore point escaped record'
    Write-AdsManifest -BackupRoot $escapedRecordRoot -Manifest ([ordered]@{
            SchemaVersion = 1
            Applied       = 1
            Records       = @([ordered]@{ Source = $tamperCampaign; Backup = $outsideAdsBackupPath; Sha256 = (Get-FileHash -LiteralPath $outsideAdsBackupPath -Algorithm SHA256).Hash; ReadOnly = $false; Length = [long](New-Object IO.FileInfo($outsideAdsBackupPath)).Length })
        })
    $escapedRecordJournal = New-AdsJournal -Name 'restore point escaped record journal'
    $escapedRecordRestore = Restore-MuMuAds -BackupRoot $escapedRecordRoot -AllowedRoot $tamperAdsInstall.InstallRoot -Journal $escapedRecordJournal
    Assert-Equal 'CriticalError' $escapedRecordRestore.Status 'A restore point record outside the backup root was restored.'
    Assert-True ($escapedRecordRestore.Message -match '(?i)backup root|outside') 'The escaped restore point record failure did not name the backup root boundary.'
    Assert-AdsUnchanged -Path $tamperCampaign -Expected $tamperCampaignJson -Message 'An escaped restore point record changed the campaign bytes.'

    $missingRecordRoot = New-AdsBackupRoot -Name 'restore point missing record file'
    Write-AdsManifest -BackupRoot $missingRecordRoot -Manifest ([ordered]@{
            SchemaVersion = 1
            Applied       = 1
            Records       = @([ordered]@{ Source = $tamperCampaign; Backup = [IO.Path]::Combine($missingRecordRoot, 'missing campaign.json'); Sha256 = (Get-ToolkitFileSha256 -Path $outsideAdsBackupPath); ReadOnly = $false; Length = [long](New-Object IO.FileInfo($outsideAdsBackupPath)).Length })
        })
    $missingRecordJournal = New-AdsJournal -Name 'restore point missing record file journal'
    $missingRecordRestore = Restore-MuMuAds -BackupRoot $missingRecordRoot -AllowedRoot $tamperAdsInstall.InstallRoot -Journal $missingRecordJournal
    Assert-Equal 'CriticalError' $missingRecordRestore.Status 'A restore point record with a missing backup file was restored.'
    Assert-True ($missingRecordRestore.Message -match '(?i)missing') 'The missing restore point backup file failure did not name the missing file.'

    $boundaryAdsInstall = New-AdsInstallFixture -Name 'Boundary\MuMu Global' -Edition 'Global'
    $boundaryCampaign = Join-Path $boundaryAdsInstall.InstallRoot 'shell\ad\campaign.json'
    $boundaryCampaignJson = '{"campaigns":[{"id":"boundary","display":true}]}'
    New-AdsCampaignFixture -Path $boundaryCampaign -Json $boundaryCampaignJson
    $boundaryBackupRoot = New-AdsBackupRoot -Name 'backup boundary'
    $boundaryJournal = New-AdsJournal -Name 'journal boundary'
    $boundarySuppress = Suppress-MuMuAds -Paths @($boundaryCampaign) -BackupRoot $boundaryBackupRoot -Journal $boundaryJournal
    Assert-Equal 'Success' $boundarySuppress.Status "The boundary fixture was not suppressed. $($boundarySuppress.Message)"
    $boundaryBackupPath = @(Get-AdsRestorePointFile -BackupRoot $boundaryBackupRoot)[0]
    $boundaryVictimPath = Join-Path $script:adsFixtureRoot 'outside restore target.json'
    $boundaryVictimJson = '{"campaigns":[{"id":"victim","display":true}]}'
    [IO.File]::WriteAllText($boundaryVictimPath, $boundaryVictimJson)
    $boundaryCases = @(
        @{ Label = 'outside the allowed root'; Source = $boundaryVictimPath; AllowedRoot = $boundaryAdsInstall.InstallRoot; Pattern = '(?i)boundary|outside' },
        @{ Label = 'blank allowed root'; Source = $boundaryVictimPath; AllowedRoot = '   '; Pattern = '(?i)boundary' },
        @{ Label = 'unavailable allowed root'; Source = $boundaryVictimPath; AllowedRoot = (Join-Path $script:adsFixtureRoot 'missing boundary root'); Pattern = '(?i)boundary' },
        @{ Label = 'missing source'; Source = [IO.Path]::Combine($boundaryAdsInstall.InstallRoot, 'shell\ad\missing campaign.json'); AllowedRoot = $boundaryAdsInstall.InstallRoot; Pattern = '(?i)does not exist' },
        @{ Label = 'source is a directory'; Source = (Join-Path $boundaryAdsInstall.InstallRoot 'shell\ad'); AllowedRoot = $boundaryAdsInstall.InstallRoot; Pattern = '(?i)not a regular file' }
    )
    foreach ($boundaryCase in $boundaryCases) {
        $boundaryCaseRoot = New-AdsBackupRoot -Name ('backup boundary ' + $boundaryCase.Label)
        $boundaryCaseBackup = [IO.Path]::Combine($boundaryCaseRoot, 'campaign.json')
        Copy-Item -LiteralPath $boundaryBackupPath -Destination $boundaryCaseBackup -Force
        Write-AdsManifest -BackupRoot $boundaryCaseRoot -Manifest ([ordered]@{
                SchemaVersion = 1
                Applied       = 1
                Records       = @(New-AdsManifestRecord -Source $boundaryCase.Source -Backup $boundaryCaseBackup)
            })
        $boundaryCaseJournal = New-AdsJournal -Name ('journal boundary ' + $boundaryCase.Label)
        $boundaryCaseRestore = Restore-MuMuAds -BackupRoot $boundaryCaseRoot -AllowedRoot $boundaryCase.AllowedRoot -Journal $boundaryCaseJournal
        Assert-Equal 'CriticalError' $boundaryCaseRestore.Status "An out-of-policy campaign restore target was accepted: $($boundaryCase.Label)"
        Assert-True ($boundaryCaseRestore.Message -match $boundaryCase.Pattern) "The out-of-policy restore failure did not explain the boundary: $($boundaryCase.Label) -> $($boundaryCaseRestore.Message)"
        Assert-AdsUnchanged -Path $boundaryVictimPath -Expected $boundaryVictimJson -Message "An out-of-policy restore target was overwritten: $($boundaryCase.Label)"
        Assert-True ([IO.File]::Exists($boundaryCaseBackup)) "A refused restore deleted the restore point: $($boundaryCase.Label)"
        Assert-Equal 'Failed' $boundaryCaseJournal.State "A refused restore did not journal the failure: $($boundaryCase.Label)"
    }
    $boundaryLinkedRoot = Join-Path $boundaryAdsInstall.InstallRoot 'linked ad'
    $boundaryLinkedTarget = Join-Path $script:adsFixtureRoot 'outside linked ad'
    [void][IO.Directory]::CreateDirectory($boundaryLinkedTarget)
    New-AdsCampaignFixture -Path ([IO.Path]::Combine($boundaryLinkedTarget, 'campaign.json')) -Json $boundaryVictimJson
    New-Item -ItemType Junction -Path $boundaryLinkedRoot -Target $boundaryLinkedTarget | Out-Null
    $boundaryLinkedBackupRoot = New-AdsBackupRoot -Name 'backup boundary linked source'
    $boundaryLinkedBackup = [IO.Path]::Combine($boundaryLinkedBackupRoot, 'campaign.json')
    Copy-Item -LiteralPath $boundaryBackupPath -Destination $boundaryLinkedBackup -Force
    Write-AdsManifest -BackupRoot $boundaryLinkedBackupRoot -Manifest ([ordered]@{
            SchemaVersion = 1
            Applied       = 1
            Records       = @(New-AdsManifestRecord -Source ([IO.Path]::Combine($boundaryLinkedRoot, 'campaign.json')) -Backup $boundaryLinkedBackup)
        })
    $boundaryLinkedJournal = New-AdsJournal -Name 'journal boundary linked source'
    $boundaryLinkedRestore = Restore-MuMuAds -BackupRoot $boundaryLinkedBackupRoot -AllowedRoot $boundaryAdsInstall.InstallRoot -Journal $boundaryLinkedJournal
    Assert-Equal 'CriticalError' $boundaryLinkedRestore.Status 'A campaign restore target reached through a junction outside the boundary was accepted.'
    Assert-True ($boundaryLinkedRestore.Message -match '(?i)boundary|outside') 'The junctioned restore target failure did not name the boundary.'
    Assert-AdsUnchanged -Path ([IO.Path]::Combine($boundaryLinkedTarget, 'campaign.json')) -Expected $boundaryVictimJson -Message 'A junctioned out-of-boundary restore target was overwritten.'

    $boundaryPartialRoot = New-AdsBackupRoot -Name 'backup boundary partial'
    $boundaryPartialBackup = [IO.Path]::Combine($boundaryPartialRoot, 'campaign.json')
    Copy-Item -LiteralPath $boundaryBackupPath -Destination $boundaryPartialBackup -Force
    Write-AdsManifest -BackupRoot $boundaryPartialRoot -Manifest ([ordered]@{
            SchemaVersion = 1
            Applied       = 1
            Records       = @(
                (New-AdsManifestRecord -Source $boundaryCampaign -Backup $boundaryPartialBackup),
                (New-AdsManifestRecord -Source (Join-Path $boundaryAdsInstall.InstallRoot 'shell\ad') -Backup $boundaryPartialBackup)
            )
        })
    $boundaryPartialJournal = New-AdsJournal -Name 'journal boundary partial'
    $boundaryPartialRestore = Restore-MuMuAds -BackupRoot $boundaryPartialRoot -AllowedRoot $boundaryAdsInstall.InstallRoot -Journal $boundaryPartialJournal
    Assert-Equal 'CriticalError' $boundaryPartialRestore.Status 'A restore point with an invalid second record was restored.'
    Assert-Equal $false (([IO.File]::ReadAllText($boundaryCampaign) | ConvertFrom-Json).campaigns[0].display) 'An invalid record in a later position still wrote an earlier campaign file.'

    $relinkedAdsBackupTarget = New-AdsBackupRoot -Name 'relinked backup target'
    $relinkedAdsBackupRoot = Join-Path $script:adsFixtureRoot 'relinked backup root junction'
    [void][IO.Directory]::CreateDirectory($relinkedAdsBackupRoot)
    New-Item -ItemType Junction -Path $relinkedAdsBackupRoot -Target $relinkedAdsBackupTarget | Out-Null
    $relinkedSuppressJournal = New-AdsJournal -Name 'journal relinked backup root'
    $relinkedSuppress = Suppress-MuMuAds -Paths @($tamperCampaign) -BackupRoot $relinkedAdsBackupRoot -Journal $relinkedSuppressJournal
    Assert-Equal 'CriticalError' $relinkedSuppress.Status 'A junctioned campaign backup root was accepted.'
    Assert-True ($relinkedSuppress.Message -match '(?i)reparse|junction|link') 'The junctioned campaign backup root failure did not name the reparse point.'
    Assert-Equal 0 @([IO.Directory]::GetFiles($relinkedAdsBackupTarget, '*', [IO.SearchOption]::AllDirectories)).Count 'A junctioned campaign backup root received a file.'
    $relinkedRestoreJournal = New-AdsJournal -Name 'journal relinked restore root'
    $relinkedRestore = Restore-MuMuAds -BackupRoot $relinkedAdsBackupRoot -AllowedRoot $tamperAdsInstall.InstallRoot -Journal $relinkedRestoreJournal
    Assert-Equal 'CriticalError' $relinkedRestore.Status 'A junctioned campaign restore root was accepted.'
    Assert-Equal 0 @([IO.Directory]::GetFiles($relinkedAdsBackupTarget, '*', [IO.SearchOption]::AllDirectories)).Count 'A junctioned campaign restore root received a file.'

    $missingBackupRootJournal = New-AdsJournal -Name 'journal missing backup root'
    $missingBackupRoot = Suppress-MuMuAds -Paths @($tamperCampaign) -BackupRoot (Join-Path $script:adsFixtureRoot 'missing backup root') -Journal $missingBackupRootJournal
    Assert-Equal 'CriticalError' $missingBackupRoot.Status 'A missing campaign backup root was accepted.'
    $blankBackupRootJournal = New-AdsJournal -Name 'journal blank backup root'
    $blankBackupRoot = Suppress-MuMuAds -Paths @($tamperCampaign) -BackupRoot '   ' -Journal $blankBackupRootJournal
    Assert-Equal 'CriticalError' $blankBackupRoot.Status 'A blank campaign backup root was accepted.'
    $fileBackupRootJournal = New-AdsJournal -Name 'journal file backup root'
    $fileBackupRoot = Suppress-MuMuAds -Paths @($tamperCampaign) -BackupRoot $tamperCampaign -Journal $fileBackupRootJournal
    Assert-Equal 'CriticalError' $fileBackupRoot.Status 'A campaign file was accepted as the campaign backup root.'

    $emptyPathJournal = New-AdsJournal -Name 'journal empty paths'
    $emptyPathBackupRoot = New-AdsBackupRoot -Name 'backup empty paths'
    $emptyPathSuppress = Suppress-MuMuAds -Paths @() -BackupRoot $emptyPathBackupRoot -Journal $emptyPathJournal
    Assert-Equal 'AlreadyApplied' $emptyPathSuppress.Status 'An empty campaign path list was reported as a change.'
    Assert-Equal 0 $emptyPathSuppress.Data.Changed 'An empty campaign path list reported changes.'
    Assert-Equal 0 @(Get-AdsRestorePointFile -BackupRoot $emptyPathBackupRoot).Count 'An empty campaign path list created a restore point.'

    $invalidRequestJournal = New-AdsJournal -Name 'journal invalid requests'
    $validRequestBackupRoot = New-AdsBackupRoot -Name 'backup invalid requests'
    Assert-Equal 'CriticalError' (Suppress-MuMuAds -Paths @($tamperCampaign) -BackupRoot $validRequestBackupRoot -Journal $null).Status 'A campaign suppression without a journal was accepted.'
    Assert-Equal 'CriticalError' (Suppress-MuMuAds -Paths @((Join-Path $script:adsFixtureRoot 'missing campaign.json')) -BackupRoot $validRequestBackupRoot -Journal $invalidRequestJournal).Status 'A missing campaign file was accepted.'
    Assert-Equal 'CriticalError' (Suppress-MuMuAds -Paths @($tamperAdsInstall.InstallRoot) -BackupRoot $validRequestBackupRoot -Journal $invalidRequestJournal).Status 'A campaign directory was accepted.'
    Assert-Equal 'CriticalError' (Suppress-MuMuAds -Paths @('   ') -BackupRoot $validRequestBackupRoot -Journal $invalidRequestJournal).Status 'A blank campaign path was accepted.'
    Assert-Equal 'CriticalError' (Restore-MuMuAds -BackupRoot $validRequestBackupRoot -AllowedRoot $tamperAdsInstall.InstallRoot -Journal $null).Status 'A campaign restore without a journal was accepted.'
    Assert-Equal 0 @(Get-AdsRestorePointFile -BackupRoot $validRequestBackupRoot).Count 'A refused campaign request created a restore point.'
}

$script:Root12Codes = @(
    'ANDROID_VERSION_UNSUPPORTED',
    'INSTANCE_INVALID',
    'JOURNAL_INVALID',
    'JOURNAL_WRITE_FAILED',
    'MANAGER_UNAVAILABLE',
    'CACHE_UNAVAILABLE',
    'ASSET_VERIFICATION_FAILED',
    'ASSET_PATH_INVALID',
    'USER_CONFIRMATION_REQUIRED',
    'CLONE_UNVERIFIED',
    'CLONE_INVALID',
    'RESUME_RECORD_INVALID',
    'RESUME_CLONE_MISSING',
    'RESUME_CLONE_IDENTITY',
    'RESUME_CLONE_VERSION',
    'RESUME_CLONE_CONTAINMENT',
    'RESUME_CLONE_DISK',
    'VENDOR_ROOT_ENABLE_FAILED',
    'VENDOR_ROOT_NOT_ENABLED',
    'VENDOR_ROOT_SETTING_UNREADABLE',
    'VENDOR_ROOT_DISABLE_FAILED',
    'VENDOR_ROOT_NOT_DISABLED',
    'APK_INSTALL_FAILED',
    'APK_LAUNCH_FAILED',
    'BOOT_CONTROL_FAILED',
    'STOP_TIMEOUT',
    'BOOT_TIMEOUT',
    'PACKAGE_MISSING',
    'PACKAGE_VERSION_MISMATCH',
    'DAEMON_ABSENT',
    'DAEMON_DUPLICATE',
    'ROOT_DENIED',
    'ADB_FAILED'
)

function New-Root12InstallFixture {
    param(
        [string]$InstallRoot,
        [int]$SourceIndex
    )

    $root = [IO.Path]::GetFullPath($InstallRoot)
    $vms = Join-Path $root 'vms'
    $instanceRoot = Join-Path $vms ([string]$SourceIndex)
    New-Item -ItemType Directory -Path $instanceRoot -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $instanceRoot 'system.img'), 'source instance disk payload')
    $managerDirectory = Join-Path $root 'shell'
    New-Item -ItemType Directory -Path $managerDirectory -Force | Out-Null
    $managerPath = Join-Path $managerDirectory 'MuMuManager.exe'
    [IO.File]::WriteAllText($managerPath, 'android 12 manager fixture')
    [pscustomobject]@{
        InstallRoot = $root
        VmsPath = [IO.Path]::GetFullPath($vms)
        ManagerPath = [IO.Path]::GetFullPath($managerPath)
        SourceIndex = $SourceIndex
    }
}

function New-Root12InstanceFixture {
    param(
        [object]$Install,
        [string]$AndroidVersion
    )

    [pscustomobject]@{
        Index = $Install.SourceIndex
        Name = 'Android 12 target'
        AndroidVersion = $AndroidVersion
        Install = [pscustomobject]@{
            Edition = 'Global'
            InstallRoot = $Install.InstallRoot
            VmsPath = $Install.VmsPath
            ManagerPath = $Install.ManagerPath
            Source = 'Process'
        }
        Running = $true
        RootSetting = $false
        Eligible = $true
        IneligibleReason = $null
    }
}

function New-Root12FixtureManifest {
    param(
        [string]$AssetPath,
        [string]$Sha256 = '',
        [long]$Size = 0,
        [string]$Url = '',
        [switch]$OmitSha256
    )

    $item = Get-Item -LiteralPath $AssetPath
    $dependency = [ordered]@{
        id = 'kitsune'
        version = 'v31.0-25fa2159'
        assetName = 'app-release.apk'
        url = 'https://github.com/Jordan231111/KitsuneMagisk/releases/download/v31.0-25fa2159/app-release.apk'
        size = if ($Size -gt 0) { [long]$Size } else { [long]$item.Length }
        sha256 = if ([string]::IsNullOrWhiteSpace($Sha256)) { (Get-FileHash -LiteralPath $AssetPath -Algorithm SHA256).Hash.ToLowerInvariant() } else { $Sha256 }
    }
    if (-not [string]::IsNullOrWhiteSpace($Url)) {
        $dependency['url'] = $Url
    }
    if ($OmitSha256) {
        $dependency.Remove('sha256')
    }
    return [pscustomobject]@{ dependencies = @([pscustomobject]$dependency) }
}

function New-Root12Journal {
    param(
        [string]$Root,
        [object]$Instance
    )

    return New-OperationJournal -Root $Root -Operation 'Root12' -Instance $Instance
}

function New-Root12ManagerState {
    param([object]$Install)

    return @{
        VmsPath = $Install.VmsPath
        SourceIndex = $Install.SourceIndex
        CloneIndex = 5
        CloneName = 'Target clone'
        CloneExitCode = 0
        CloneCreatesRecord = $true
        CloneCreatesDisk = $true
        CloneVmsPath = ''
        CloneAndroid = '12.0'
        Calls = @()
        Instances = @(
            [pscustomobject]@{ Index = 0; Name = 'Base'; IsMain = $true; Running = $false; Android = '12.0'; VmsPath = '' }
            [pscustomobject]@{ Index = $Install.SourceIndex; Name = 'Target'; IsMain = $false; Running = $true; Android = '12.0'; VmsPath = '' }
        )
        RootSettings = @{}
        IgnoreRootEnable = $false
        IgnoreRootDisable = $false
        RootSettingExitCode = 0
        RootSettingQueryExitCode = 0
        RootSettingQueryFailCount = 0
        RootSettingQueries = 0
        RootSettingFailValue = ''
        RootSettingText = ''
        AdbFailPattern = ''
        AdbThrowPattern = ''
        AdbFailExitCode = 1
        ControlFailPattern = ''
        ControlFailExitCode = 1
        ApkInstallExitCode = 0
        InstalledPath = ''
        BootPolls = @{}
        BootReadyPolls = 1
        PackageInstalled = $true
        PackageName = 'io.github.huskydg.magisk'
        PackageHeaderName = ''
        PackageExtraBlock = ''
        LaunchCommand = 'shell monkey -p io.github.huskydg.magisk -c android.intent.category.LAUNCHER 1'
        VersionName = '31.0-kitsune'
        VersionCode = '31000'
        DaemonPids = '4242'
        RootAllowed = $true
        RootShellText = 'uid=0(root) gid=0(root) groups=0(root)'
        JournalLockPath = ''
        JournalLockPattern = ''
        JournalLock = $null
    }
}

function Release-Root12JournalLock {
    param([hashtable]$State)

    if ($null -ne $State.JournalLock) {
        $State.JournalLock.Dispose()
        $State.JournalLock = $null
    }
}

function New-Root12ManagerRunner {
    param([hashtable]$State)

    return {
        param($ActualFilePath, $ActualArgumentList)
        $State.Calls += ,@($ActualArgumentList)
        $arguments = @($ActualArgumentList | ForEach-Object { [string]$_ })
        $command = $arguments[0]
        $commandText = @($arguments) -join ' '
        if ($null -eq $State.JournalLock -and -not [string]::IsNullOrWhiteSpace([string]$State.JournalLockPath) -and
            $commandText -like $State.JournalLockPattern) {
            $State.JournalLock = [IO.File]::Open([string]$State.JournalLockPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        }
        if ($command -eq 'info') {
            $requested = $arguments[2]
            $selected = @($State.Instances | Where-Object { $requested -eq 'all' -or [string]$_.Index -ceq $requested })
            if ($selected.Count -eq 0) {
                return [pscustomobject]@{ ExitCode = 1; Text = '{"error_code":1}' }
            }
            $records = @()
            foreach ($selectedInstance in $selected) {
                $record = [ordered]@{
                    index = [string]$selectedInstance.Index
                    name = $selectedInstance.Name
                    is_main = [string]$selectedInstance.IsMain
                    is_process_started = [string]$selectedInstance.Running
                    android_version = $selectedInstance.Android
                }
                if (-not [string]::IsNullOrWhiteSpace([string]$selectedInstance.VmsPath)) {
                    $record['vms_path'] = [string]$selectedInstance.VmsPath
                }
                $records += [pscustomobject]$record
            }
            return [pscustomobject]@{ ExitCode = 0; Text = (ConvertTo-Json -InputObject @($records) -Depth 4 -Compress) }
        }
        if ($command -eq 'control') {
            if (-not [string]::IsNullOrWhiteSpace([string]$State.ControlFailPattern) -and $commandText -like $State.ControlFailPattern) {
                return [pscustomobject]@{ ExitCode = $State.ControlFailExitCode; Text = '{"error_code":1}' }
            }
            if ($arguments[3] -eq 'shutdown') {
                foreach ($controlInstance in $State.Instances) {
                    if ([string]$controlInstance.Index -ceq $arguments[2]) {
                        $controlInstance.Running = $false
                    }
                }
            }
            return [pscustomobject]@{ ExitCode = 0; Text = '{"error_code":0}' }
        }
        if ($command -eq 'clone') {
            if ($State.CloneExitCode -ne 0) {
                return [pscustomobject]@{ ExitCode = $State.CloneExitCode; Text = '{"error_code":1}' }
            }
            $cloneVmsPath = [string]$State.CloneVmsPath
            if ([string]::IsNullOrWhiteSpace($cloneVmsPath)) {
                $cloneVmsPath = [string]$State.VmsPath
            }
            if ($State.CloneCreatesRecord) {
                $cloneRoot = Join-Path $cloneVmsPath ([string]$State.CloneIndex)
                New-Item -ItemType Directory -Path $cloneRoot -Force | Out-Null
                if ($State.CloneCreatesDisk) {
                    [IO.File]::WriteAllText((Join-Path $cloneRoot 'system.img'), 'clone disk payload')
                }
                $State.Instances = @($State.Instances) + [pscustomobject]@{
                    Index = [int]$State.CloneIndex
                    Name = $State.CloneName
                    IsMain = $false
                    Running = $false
                    Android = [string]$State.CloneAndroid
                    VmsPath = [string]$State.CloneVmsPath
                }
            }
            return [pscustomobject]@{ ExitCode = 0; Text = '{"error_code":0}' }
        }
        if ($command -eq 'setting') {
            $index = $arguments[2]
            $valueIndex = [array]::IndexOf($arguments, '-val')
            if ($valueIndex -ge 0) {
                $requestedValue = $arguments[$valueIndex + 1] -ceq 'true'
                if ($State.RootSettingExitCode -ne 0 -and
                    (([string]$State.RootSettingFailValue).Length -eq 0 -or [string]$State.RootSettingFailValue -ceq $arguments[$valueIndex + 1])) {
                    return [pscustomobject]@{ ExitCode = $State.RootSettingExitCode; Text = '{"error_code":1}' }
                }
                $ignored = ($requestedValue -and $State.IgnoreRootEnable) -or ((-not $requestedValue) -and $State.IgnoreRootDisable)
                if (-not $ignored) {
                    $State.RootSettings[$index] = $requestedValue
                }
            }
            if ($State.RootSettingQueryExitCode -ne 0 -or
                ($State.RootSettingQueryFailCount -gt 0 -and $State.RootSettingQueries -lt $State.RootSettingQueryFailCount)) {
                $State.RootSettingQueries++
                $queryExitCode = $State.RootSettingQueryExitCode
                if ($queryExitCode -eq 0) {
                    $queryExitCode = 1
                }
                return [pscustomobject]@{ ExitCode = $queryExitCode; Text = '{"error_code":1}' }
            }
            $State.RootSettingQueries++
            if (-not [string]::IsNullOrEmpty([string]$State.RootSettingText)) {
                return [pscustomobject]@{ ExitCode = 0; Text = $State.RootSettingText }
            }
            $current = $false
            if ($State.RootSettings.ContainsKey($index)) {
                $current = [bool]$State.RootSettings[$index]
            }
            return [pscustomobject]@{ ExitCode = 0; Text = ('{"root_permission":"' + $(if ($current) { 'true' } else { 'false' }) + '"}') }
        }
        if ($command -eq 'adb') {
            $index = $arguments[2]
            $request = [string]$arguments[4]
            if (-not [string]::IsNullOrWhiteSpace([string]$State.AdbThrowPattern) -and $request -like $State.AdbThrowPattern) {
                throw 'adb transport failure'
            }
            if (-not [string]::IsNullOrWhiteSpace([string]$State.AdbFailPattern) -and $request -like $State.AdbFailPattern) {
                return [pscustomobject]@{ ExitCode = $State.AdbFailExitCode; Text = 'adb: fixture failure' }
            }
            if ($request -like 'install *') {
                if ($State.ApkInstallExitCode -ne 0) {
                    return [pscustomobject]@{ ExitCode = $State.ApkInstallExitCode; Text = 'adb: failed to install' }
                }
                $State.InstalledCommand = [string]$request
                if ([string]$request -match '^install -r "(.+)"$') {
                    $State.InstalledPath = [string]$Matches[1]
                }
                return [pscustomobject]@{ ExitCode = 0; Text = 'Success' }
            }
            if ($request -ceq 'shell getprop sys.boot_completed') {
                $polls = 0
                if ($State.BootPolls.ContainsKey($index)) {
                    $polls = [int]$State.BootPolls[$index]
                }
                $polls++
                $State.BootPolls[$index] = $polls
                if ($polls -ge $State.BootReadyPolls) {
                    return [pscustomobject]@{ ExitCode = 0; Text = '1' }
                }
                return [pscustomobject]@{ ExitCode = 0; Text = '0' }
            }
            if ($request -ceq ('shell dumpsys package ' + $State.PackageName)) {
                if (-not $State.PackageInstalled) {
                    return [pscustomobject]@{ ExitCode = 0; Text = ('Unable to find package: ' + $State.PackageName + '.') }
                }
                $headerName = if ([string]::IsNullOrWhiteSpace([string]$State.PackageHeaderName)) { [string]$State.PackageName } else { [string]$State.PackageHeaderName }
                $extraBlock = ''
                if (-not [string]::IsNullOrWhiteSpace([string]$State.PackageExtraBlock)) {
                    $extraBlock = [string]$State.PackageExtraBlock + [Environment]::NewLine
                }
                return [pscustomobject]@{
                    ExitCode = 0
                    Text = ($extraBlock + 'Package [' + $headerName + '] (a1b2c3):' + [Environment]::NewLine + '    versionCode=' + $State.VersionCode + ' minSdk=26' + [Environment]::NewLine + '    versionName=' + $State.VersionName)
                }
            }
            if ($request -ceq 'shell pidof magiskd') {
                return [pscustomobject]@{ ExitCode = 0; Text = $State.DaemonPids }
            }
            if ($request -ceq 'shell su -c id') {
                if (-not $State.RootAllowed) {
                    return [pscustomobject]@{ ExitCode = 1; Text = '/system/bin/sh: su: not found' }
                }
                return [pscustomobject]@{ ExitCode = 0; Text = $State.RootShellText }
            }
            if ($request -ceq $State.LaunchCommand) {
                return [pscustomobject]@{ ExitCode = 0; Text = 'Events injected: 1' }
            }
            return [pscustomobject]@{ ExitCode = 1; Text = 'unsupported adb request' }
        }
        return [pscustomobject]@{ ExitCode = 1; Text = '{"error_code":1}' }
    }.GetNewClosure()
}

function Invoke-Root12Case {
    param(
        [hashtable]$State,
        [object]$Instance,
        [object]$Manifest,
        [string]$JournalRoot,
        [string]$CacheRoot,
        [bool]$Interactive = $true,
        [string]$Confirmation = '',
        [scriptblock]$Prompt = $null,
        [object]$ResumeClone = $null,
        [switch]$RequireCachedAsset
    )

    $journal = New-Root12Journal -Root $JournalRoot -Instance $Instance
    $parameters = @{
        Instance = $Instance
        Manifest = $Manifest
        Journal = $journal
        Interactive = $Interactive
        Confirmation = $Confirmation
        CacheRoot = $CacheRoot
        Runner = (New-Root12ManagerRunner -State $State)
    }
    if ($null -ne $Prompt) {
        $parameters['Prompt'] = $Prompt
    }
    if ($null -ne $ResumeClone) {
        $parameters['ResumeClone'] = $ResumeClone
    }
    if ($RequireCachedAsset) {
        $parameters['RequireCachedAsset'] = $true
    }
    $result = Install-Android12Root @parameters
    [pscustomobject]@{
        Result = $result
        Journal = $journal
        State = $State
    }
}

function New-Root12VerifiedCloneState {
    param(
        [object]$Install,
        [object]$Instance,
        [object]$Manifest,
        [string]$JournalRoot,
        [string]$CacheRoot
    )

    $state = New-Root12ManagerState -Install $Install
    $null = Invoke-Root12Case -State $state -Instance $Instance -Manifest $Manifest -JournalRoot $JournalRoot -CacheRoot $CacheRoot -Interactive $true -Prompt { 'decline' }
    return $state
}

function Get-Root12CallIndex {
    param(
        [object[]]$Calls,
        [string]$Pattern
    )

    for ($index = 0; $index -lt $Calls.Count; $index++) {
        if ((@($Calls[$index]) -join ' ') -like $Pattern) {
            return $index
        }
    }
    return -1
}

function Assert-Root12Failure {
    param(
        [object]$Result,
        [object]$Journal,
        [string]$Code,
        [string]$Message
    )

    Assert-Equal 'CriticalError' $Result.Status $Message
    Assert-True ($null -ne $Result.Data) "$Message The failure carried no recovery data."
    Assert-True ($script:Root12Codes -ccontains [string]$Result.Data.Code) "$Message The failure reported an undocumented code: $($Result.Data.Code)"
    Assert-True ([string]$Result.Data.Code -cne 'UNKNOWN') "$Message The failure reported an unknown code."
    Assert-Equal $Code $Result.Data.Code "$Message The failure code is invalid."
    Assert-Equal 'Failed' $Journal.State "$Message The failure was not journaled."
    $reopened = Get-OperationJournal -Path $Journal.JournalPath
    Assert-Equal 'Failed' $reopened.State "$Message The failure was not persisted."
    Assert-Equal 'CriticalError' $reopened.Result.Status "$Message The persisted result status is invalid."
    Assert-Equal $Code $reopened.Result.Data.Code "$Message The persisted recovery code changed."
    Assert-True (@($reopened.Checkpoints).Count -ge 1) "$Message No failure checkpoint was recorded."
}

function Invoke-Root12Tests {
    foreach ($commandName in @('Install-Android12Root', 'Get-Android12KitsunePrompt', 'Test-KitsuneConfirmation', 'Test-Android12Root', 'Read-Android12KitsuneConfirmation', 'Prepare-Android12Asset', 'Resolve-Android12Clone', 'Assert-Android12ResumeClone', 'Get-ToolkitRootSetting', 'Format-Android12InstallCommand')) {
        Assert-True ($null -ne (Get-Command $commandName -CommandType Function -ErrorAction SilentlyContinue)) "Android 12 command is unavailable: $commandName"
    }
    Assert-True (Test-Path -LiteralPath $root12ScriptPath -PathType Leaf) 'src/Root12.ps1 does not exist.'
    Assert-True ($null -ne (Get-Command 'Get-ToolkitAssetCacheRoot' -CommandType Function -ErrorAction SilentlyContinue)) 'Get-ToolkitAssetCacheRoot is unavailable.'
    Assert-True ($null -ne (Get-Command 'Save-ToolkitAsset' -CommandType Function -ErrorAction SilentlyContinue)) 'Save-ToolkitAsset is unavailable.'
    Assert-True ($null -ne (Get-Command 'New-Android12Recovery' -CommandType Function -ErrorAction SilentlyContinue)) 'New-Android12Recovery is unavailable.'
    Assert-Throws { New-Android12Recovery -Step 'confirmation' -SourceIndex 3 } 'An Android 12 recovery record was built without a code.'
    Assert-Throws { New-Android12Recovery -Code '' -Step 'confirmation' -SourceIndex 3 } 'An Android 12 recovery record was built with an empty code.'
    Assert-Throws { New-Android12Recovery -Code '   ' -Step 'confirmation' -SourceIndex 3 } 'An Android 12 recovery record was built with a whitespace code.'
    foreach ($codeCase in @('OK', 'USER_CONFIRMATION_REQUIRED', 'JOURNAL_WRITE_FAILED', 'VENDOR_ROOT_SETTING_UNREADABLE')) {
        $codeRecord = New-Android12Recovery -Code $codeCase -Step 'verification' -SourceIndex 3 -CloneIndex 5 -CloneName 'Target clone'
        Assert-Equal $codeCase $codeRecord.Code 'An Android 12 recovery record changed its code.'
        Assert-True ($script:Root12Codes -ccontains $codeRecord.Code -or $codeRecord.Code -ceq 'OK') "An Android 12 recovery record used an undocumented code: $codeCase"
    }

    $root12Source = [IO.File]::ReadAllText($root12ScriptPath)
    Assert-True ($root12Source -notmatch "'UNKNOWN'") 'The Android 12 source reports an UNKNOWN failure code.'
    foreach ($forbidden in @(
            'Invoke-Expression',
            'ScriptBlock]::Create',
            'Add-Type',
            'Start-Process',
            'Invoke-WebRequest',
            'Invoke-RestMethod',
            'schtasks',
            'Set-ExecutionPolicy',
            'icacls',
            'Set-Acl',
            'New-NetFirewallRule',
            'Set-NetFirewallProfile',
            'EnableLUA',
            'Set-MpPreference'
        )) {
        Assert-True ($root12Source -notmatch [regex]::Escape($forbidden)) "Android 12 source uses a forbidden construct: $forbidden"
    }
    $defaultPrompt = (Get-Command Read-Android12KitsuneConfirmation -CommandType Function).Definition
    Assert-True ($defaultPrompt -match 'Read-Host') 'The default Kitsune prompt does not read the operator answer.'

    $bootAttemptsVariable = Get-Variable -Name 'ToolkitBootPollAttempts' -Scope Script -ErrorAction SilentlyContinue
    $bootDelayVariable = Get-Variable -Name 'ToolkitBootPollDelaySeconds' -Scope Script -ErrorAction SilentlyContinue
    $defaultPromptVariable = Get-Variable -Name 'ToolkitKitsuneDefaultPrompt' -Scope Script -ErrorAction SilentlyContinue
    $script:ToolkitBootPollAttempts = 2
    $script:ToolkitBootPollDelaySeconds = 0
    try {
        $prompt = Get-Android12KitsunePrompt
        Assert-Equal 'Install -> Direct Install into system partition' $prompt 'The Kitsune prompt is not the exact system-partition instruction.'
        Assert-True ($prompt -match 'Direct Install into system partition') 'Kitsune prompt is ambiguous.'

        Assert-True (Test-KitsuneConfirmation -Confirmation 'Direct Install into system partition') 'The exact system-partition confirmation was rejected.'
        Assert-True (-not (Test-KitsuneConfirmation -Confirmation $null)) 'A missing Kitsune confirmation was accepted.'
        foreach ($ambiguous in @(
                'Direct Install',
                'Select and Patch a File',
                'direct install into system partition',
                'Direct Install into system partition ',
                'Direct Install into system partition;',
                'Install -> Direct Install into system partition',
                ' Install -> Direct Install into system partition',
                '',
                '   ',
                'yes'
            )) {
            Assert-True (-not (Test-KitsuneConfirmation -Confirmation $ambiguous)) "An ambiguous Kitsune confirmation was accepted: $ambiguous"
        }

        Assert-Equal ([IO.Path]::Combine($env:LOCALAPPDATA, 'mumu-root-hide-toolkit', 'assets')) (Get-ToolkitAssetCacheRoot) 'The asset cache root is not the per-user dependency cache.'

        $installCommand = Format-Android12InstallCommand -Path 'C:\parent dir\app-release.apk'
        Assert-Equal 'Success' $installCommand.Status 'A spaced asset path was refused.'
        Assert-Equal 'install -r "C:\parent dir\app-release.apk"' $installCommand.Data 'The install command is not one quoted structured element.'
        foreach ($unsafePath in @('   ', 'C:\bad"path\app-release.apk', ('C:\bad' + [Environment]::NewLine + 'path\app-release.apk'))) {
            $unsafeCommand = Format-Android12InstallCommand -Path $unsafePath
            Assert-Equal 'CriticalError' $unsafeCommand.Status "An unsafe asset path was accepted: $unsafePath"
            Assert-Equal 'ASSET_PATH_INVALID' $unsafeCommand.Data.Code "An unsafe asset path reported the wrong code: $unsafePath"
        }

        $root12Root = Join-Path $testRoot 'root12 fixtures'
        $assetCacheRoot = Join-Path $root12Root 'asset cache with spaces'
        New-Item -ItemType Directory -Path (Join-Path $assetCacheRoot 'kitsune') -Force | Out-Null
        $kitsuneAssetPath = Join-Path (Join-Path $assetCacheRoot 'kitsune') 'app-release.apk'
        [IO.File]::WriteAllText($kitsuneAssetPath, 'kitsune apk fixture payload')
        $manifest = New-Root12FixtureManifest -AssetPath $kitsuneAssetPath
        $journalRoot = Join-Path $root12Root 'journals'
        $install = New-Root12InstallFixture -InstallRoot (Join-Path $root12Root 'MuMu Global') -SourceIndex 3
        $outsideVms = Join-Path $root12Root 'outside vms'
        New-Item -ItemType Directory -Path $outsideVms -Force | Out-Null
        $android12 = New-Root12InstanceFixture -Install $install -AndroidVersion '12.0'
        $android15 = New-Root12InstanceFixture -Install $install -AndroidVersion '15.0'
        $blockedCacheFile = Join-Path $root12Root 'blocked cache'
        [IO.File]::WriteAllText($blockedCacheFile, 'this path is a file')
        $blockedCacheRoot = Join-Path $blockedCacheFile 'assets'

        $android15State = New-Root12ManagerState -Install $install
        $android15Journal = New-Root12Journal -Root $journalRoot -Instance $android15
        $wrongVersion = Install-Android12Root -Instance $android15 -Manifest $manifest -Journal $android15Journal `
            -Interactive $false -CacheRoot $assetCacheRoot -Runner (New-Root12ManagerRunner -State $android15State)
        Assert-True ($wrongVersion.Status -eq 'CriticalError') 'Android 15 was sent to the Android 12 workflow.'
        Assert-Equal 'ANDROID_VERSION_UNSUPPORTED' $wrongVersion.Data.Code 'Android 15 was not rejected as an unsupported Android version.'
        Assert-Equal 0 @($android15State.Calls).Count 'An unsupported Android version reached the MuMu manager.'
        Assert-Equal 'Failed' $android15Journal.State 'The Android 15 rejection was not journaled.'

        $unsupportedState = New-Root12ManagerState -Install $install
        $unsupportedVersion = Install-Android12Root -Instance (New-Root12InstanceFixture -Install $install -AndroidVersion '11.0') `
            -Manifest $manifest -Journal (New-Root12Journal -Root $journalRoot -Instance $android12) `
            -Interactive $true -Confirmation 'Direct Install into system partition' -CacheRoot $assetCacheRoot `
            -Runner (New-Root12ManagerRunner -State $unsupportedState)
        Assert-Equal 'CriticalError' $unsupportedVersion.Status 'An unsupported Android 11 instance was accepted.'
        Assert-Equal 'ANDROID_VERSION_UNSUPPORTED' $unsupportedVersion.Data.Code 'Android 11 was not rejected as an unsupported Android version.'
        Assert-Equal 0 @($unsupportedState.Calls).Count 'An unsupported Android version reached the MuMu manager.'

        $foreignInstall = New-Root12InstallFixture -InstallRoot (Join-Path $root12Root 'Foreign MuMu') -SourceIndex 3
        $foreignInstance = New-Root12InstanceFixture -Install $install -AndroidVersion '12.0'
        $foreignInstance.Install.ManagerPath = $foreignInstall.ManagerPath
        $foreignState = New-Root12ManagerState -Install $install
        $foreignCase = Invoke-Root12Case -State $foreignState -Instance $foreignInstance `
            -Manifest $manifest -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-Root12Failure -Result $foreignCase.Result -Journal $foreignCase.Journal -Code 'MANAGER_UNAVAILABLE' -Message 'A manager outside its own install root was accepted.'
        Assert-Equal 0 @($foreignState.Calls).Count 'A manager outside its own install root was executed.'

        $nullInstanceState = New-Root12ManagerState -Install $install
        $nullInstanceJournal = New-Root12Journal -Root $journalRoot -Instance $android12
        $nullInstance = Install-Android12Root -Instance $null -Manifest $manifest -Journal $nullInstanceJournal `
            -Interactive $false -CacheRoot $assetCacheRoot -Runner (New-Root12ManagerRunner -State $nullInstanceState)
        Assert-Root12Failure -Result $nullInstance -Journal $nullInstanceJournal -Code 'INSTANCE_INVALID' -Message 'A missing instance was accepted.'
        Assert-Equal 0 @($nullInstanceState.Calls).Count 'A missing instance reached the MuMu manager.'

        $missingJournalState = New-Root12ManagerState -Install $install
        $missingJournal = Install-Android12Root -Instance $android12 -Manifest $manifest -Journal $null `
            -Interactive $false -CacheRoot $assetCacheRoot -Runner (New-Root12ManagerRunner -State $missingJournalState)
        Assert-Equal 'CriticalError' $missingJournal.Status 'A missing journal was accepted.'
        Assert-Equal 'JOURNAL_INVALID' $missingJournal.Data.Code 'A missing journal was not rejected as an invalid journal.'
        Assert-Equal 0 @($missingJournalState.Calls).Count 'A missing journal reached the MuMu manager.'

        $invalidJournalState = New-Root12ManagerState -Install $install
        $invalidJournal = New-Root12Journal -Root $journalRoot -Instance $android12
        $invalidJournal | Add-Member -NotePropertyName Extra -NotePropertyValue 'invalid'
        $rejectedJournal = Install-Android12Root -Instance $android12 -Manifest $manifest -Journal $invalidJournal `
            -Interactive $false -CacheRoot $assetCacheRoot -Runner (New-Root12ManagerRunner -State $invalidJournalState)
        Assert-Equal 'CriticalError' $rejectedJournal.Status 'An invalid journal was accepted.'
        Assert-Equal 'JOURNAL_INVALID' $rejectedJournal.Data.Code 'An invalid journal was not rejected as an invalid journal.'
        Assert-Equal 0 @($invalidJournalState.Calls).Count 'An invalid journal reached the MuMu manager.'

        $blockedCacheState = New-Root12ManagerState -Install $install
        $blockedCacheJournal = New-Root12Journal -Root $journalRoot -Instance $android12
        $blockedCache = Install-Android12Root -Instance $android12 -Manifest $manifest -Journal $blockedCacheJournal `
            -Interactive $true -Confirmation 'Direct Install into system partition' -CacheRoot $blockedCacheRoot `
            -Runner (New-Root12ManagerRunner -State $blockedCacheState)
        Assert-Equal 'CriticalError' $blockedCache.Status 'An unusable dependency cache root was accepted.'
        Assert-Equal 'CACHE_UNAVAILABLE' $blockedCache.Data.Code 'An unusable dependency cache root reported the wrong code.'
        Assert-Equal 0 @($blockedCacheState.Calls).Count 'An unusable dependency cache root reached the MuMu manager.'

        $tamperedManifest = New-Root12FixtureManifest -AssetPath $kitsuneAssetPath -Sha256 ('0' * 64)
        foreach ($unverified in @(
                [pscustomobject]@{ Manifest = $tamperedManifest; Label = 'wrong hash' },
                [pscustomobject]@{ Manifest = (New-Root12FixtureManifest -AssetPath $kitsuneAssetPath -Size 12574128L); Label = 'wrong size' },
                [pscustomobject]@{ Manifest = (New-Root12FixtureManifest -AssetPath $kitsuneAssetPath -OmitSha256); Label = 'missing hash' }
            )) {
            $unverifiedState = New-Root12ManagerState -Install $install
            $unverifiedCase = Invoke-Root12Case -State $unverifiedState -Instance $android12 -Manifest $unverified.Manifest `
                -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
            Assert-Root12Failure -Result $unverifiedCase.Result -Journal $unverifiedCase.Journal -Code 'ASSET_VERIFICATION_FAILED' -Message "An unverified Kitsune asset was accepted: $($unverified.Label)."
            Assert-Equal 0 @($unverifiedState.Calls).Count "An unverified Kitsune asset reached the MuMu manager: $($unverified.Label)."
        }

        $nonInteractiveState = New-Root12ManagerState -Install $install
        $nonInteractiveCase = Invoke-Root12Case -State $nonInteractiveState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $false
        Assert-Root12Failure -Result $nonInteractiveCase.Result -Journal $nonInteractiveCase.Journal -Code 'USER_CONFIRMATION_REQUIRED' -Message 'A non-interactive request did not require operator confirmation.'
        Assert-True ($nonInteractiveCase.Result.Message -match 'USER_CONFIRMATION_REQUIRED') 'The non-interactive failure did not report USER_CONFIRMATION_REQUIRED.'
        Assert-Equal 0 @($nonInteractiveState.Calls).Count 'A non-interactive request mutated the instance.'

        $decliningState = New-Root12ManagerState -Install $install
        $decliningCase = Invoke-Root12Case -State $decliningState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Prompt { 'no' }
        Assert-Root12Failure -Result $decliningCase.Result -Journal $decliningCase.Journal -Code 'USER_CONFIRMATION_REQUIRED' -Message 'A declined Kitsune confirmation was accepted.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $decliningState.Calls -Pattern 'control*-v*launch*') 'A declined confirmation cold-booted the instance.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $decliningState.Calls -Pattern '*getprop sys.boot_completed*') 'A declined confirmation waited for the boot.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $decliningState.Calls -Pattern '*pidof magiskd*') 'A declined confirmation verified the root daemon.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $decliningState.Calls -Pattern '*root_permission*-val*false*') 'A declined confirmation disabled the vendor root.'
        Assert-Equal $decliningState.CloneIndex $decliningCase.Result.Data.CloneIndex 'A declined confirmation did not report the recoverable clone.'
        $decliningJournal = Get-OperationJournal -Path $decliningCase.Journal.JournalPath
        $decliningText = ([string](@($decliningJournal.Checkpoints) | ForEach-Object { $_.Message }) -join ' ')
        Assert-True ($decliningText -match 'Direct Install into system partition') 'A declined confirmation did not journal the exact Kitsune instruction.'
        Assert-True ($decliningText -match 'Select and Patch a File') 'A declined confirmation did not journal the rejected Kitsune alternatives.'

        $interruptedState = New-Root12ManagerState -Install $install
        $interruptedCase = Invoke-Root12Case -State $interruptedState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Prompt { '   ' }
        Assert-Root12Failure -Result $interruptedCase.Result -Journal $interruptedCase.Journal -Code 'USER_CONFIRMATION_REQUIRED' -Message 'An interrupted Kitsune confirmation was accepted.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $interruptedState.Calls -Pattern '*pidof magiskd*') 'An interrupted confirmation verified the root daemon.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $interruptedState.Calls -Pattern '*root_permission*-val*false*') 'An interrupted confirmation disabled the vendor root.'

        $throwingState = New-Root12ManagerState -Install $install
        $throwingCase = Invoke-Root12Case -State $throwingState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Prompt { throw 'console unavailable' }
        Assert-Root12Failure -Result $throwingCase.Result -Journal $throwingCase.Journal -Code 'USER_CONFIRMATION_REQUIRED' -Message 'An unavailable console prompt was accepted.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $throwingState.Calls -Pattern '*pidof magiskd*') 'An unavailable console prompt verified the root daemon.'

        $ordinaryState = New-Root12ManagerState -Install $install
        $ordinaryCase = Invoke-Root12Case -State $ordinaryState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install'
        Assert-Root12Failure -Result $ordinaryCase.Result -Journal $ordinaryCase.Journal -Code 'USER_CONFIRMATION_REQUIRED' -Message 'An ordinary Direct Install confirmation was accepted.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $ordinaryState.Calls -Pattern 'control*-v*launch*') 'An ordinary Direct Install confirmation cold-booted the instance.'

        $promptState = @{ Text = ''; Calls = 0 }
        $answeringPrompt = {
            param($PromptText)
            $promptState.Text = [string]$PromptText
            $promptState.Calls++
            'Direct Install into system partition'
        }.GetNewClosure()
        $promptedState = New-Root12ManagerState -Install $install
        $promptedCase = Invoke-Root12Case -State $promptedState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Prompt $answeringPrompt
        Assert-Equal 'Success' $promptedCase.Result.Status "An interactive Kitsune run could not be completed by the operator. $($promptedCase.Result.Message)"
        Assert-Equal 1 $promptState.Calls 'The operator was not asked exactly once for the Kitsune confirmation.'
        Assert-True ($promptState.Text -match 'Install -> Direct Install into system partition') 'The prompt did not show the exact Kitsune instruction.'
        Assert-True ($promptState.Text -match 'Select and Patch a File') 'The prompt did not warn about the rejected Kitsune options.'
        Assert-Equal $true $promptedCase.Result.Data.RootVerified 'A prompted Kitsune run did not verify the root shell.'

        $defaultPromptState = @{ Text = ''; Calls = 0 }
        $script:ToolkitKitsuneDefaultPrompt = {
            param($PromptText)
            $defaultPromptState.Text = [string]$PromptText
            $defaultPromptState.Calls++
            'Direct Install into system partition'
        }
        try {
            $defaultPromptedState = New-Root12ManagerState -Install $install
            $defaultPromptedCase = Invoke-Root12Case -State $defaultPromptedState -Instance $android12 -Manifest $manifest `
                -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true
            Assert-Equal 'Success' $defaultPromptedCase.Result.Status 'The default operator prompt did not complete the workflow.'
            Assert-Equal 1 $defaultPromptState.Calls 'The default operator prompt was not used.'
            Assert-True ($defaultPromptState.Text -match 'Install -> Direct Install into system partition') 'The default prompt did not show the exact Kitsune instruction.'
        }
        finally {
            if ($null -ne $defaultPromptVariable) {
                $script:ToolkitKitsuneDefaultPrompt = $defaultPromptVariable.Value
            }
        }

        $confirmedState = New-Root12ManagerState -Install $install
        $confirmedCase = Invoke-Root12Case -State $confirmedState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        $confirmed = $confirmedCase.Result
        Assert-True ($confirmed.Status -eq 'Success') "Confirmed Android 12 root workflow failed. $($confirmed.Message)"
        Assert-Equal 'Completed' $confirmedCase.Journal.State 'The confirmed workflow did not complete its journal.'
        $reopenedConfirmed = Get-OperationJournal -Path $confirmedCase.Journal.JournalPath
        Assert-Equal 'Completed' $reopenedConfirmed.State 'The confirmed workflow did not persist its journal state.'
        Assert-Equal 'Success' $reopenedConfirmed.Result.Status 'The confirmed workflow did not persist its result.'
        Assert-Equal 'OK' $confirmed.Data.Code 'The confirmed workflow reported an invalid result code.'
        Assert-Equal $install.SourceIndex $confirmed.Data.SourceIndex 'The confirmed workflow reported the wrong source instance.'
        Assert-Equal $confirmedState.CloneIndex $confirmed.Data.CloneIndex 'The confirmed workflow did not report the clone it rooted.'
        Assert-Equal '31.0-kitsune' $confirmed.Data.VersionName 'The confirmed workflow did not verify the Kitsune version name.'
        Assert-Equal '31000' $confirmed.Data.VersionCode 'The confirmed workflow did not verify the Kitsune version code.'
        Assert-Equal 1 $confirmed.Data.DaemonCount 'The confirmed workflow did not verify exactly one root daemon.'
        Assert-Equal $true $confirmed.Data.RootVerified 'The confirmed workflow did not verify the root shell.'
        Assert-Equal $kitsuneAssetPath $confirmedState.InstalledPath 'The verified asset was not the APK that was installed.'
        Assert-Equal $false $confirmedState.RootSettings[[string]$confirmedState.CloneIndex] 'The temporary vendor root was not disabled after verification.'
        $daemonCall = Get-Root12CallIndex -Calls $confirmedState.Calls -Pattern '*pidof magiskd*'
        $rootCall = Get-Root12CallIndex -Calls $confirmedState.Calls -Pattern '*su -c id*'
        $disableCall = Get-Root12CallIndex -Calls $confirmedState.Calls -Pattern '*root_permission*-val*false*'
        Assert-True ($daemonCall -ge 0) 'The confirmed workflow did not query the root daemon.'
        Assert-True ($rootCall -ge 0) 'The confirmed workflow did not verify the root shell.'
        Assert-True ($disableCall -gt $rootCall) 'The temporary vendor root was disabled before root verification completed.'
        foreach ($sourceCall in $confirmedState.Calls) {
            $sourceArguments = @($sourceCall)
            if ($sourceArguments[0] -ceq 'setting' -or $sourceArguments[0] -ceq 'adb') {
                Assert-True ([string]$sourceArguments[2] -cne [string]$install.SourceIndex) 'A setting or ADB request reconfigured the selected source instance instead of the clone.'
            }
        }
        $expectedInstallCommand = 'install -r "' + $kitsuneAssetPath + '"'
        $installCalls = @($confirmedState.Calls | Where-Object { @($_)[0] -ceq 'adb' -and @($_)[4] -ceq $expectedInstallCommand })
        Assert-Equal 1 $installCalls.Count 'The verified APK was not installed as one quoted structured ADB command element.'
        $installArguments = [string[]]@($installCalls[0])
        Assert-Equal 5 $installArguments.Count 'The APK install request carried an unexpected argument count.'
        Assert-Equal 'adb' $installArguments[0] 'The APK install request is not an ADB request.'
        Assert-Equal ([string]$confirmedState.CloneIndex) $installArguments[2] 'The APK was not installed on the clone.'
        Assert-Equal '-c' $installArguments[3] 'The APK install request lost its ADB command flag.'
        Assert-Equal $expectedInstallCommand $installArguments[4] 'The APK install command element is not one quoted install command.'
        $launchCalls = @($confirmedState.Calls | Where-Object { @($_)[0] -ceq 'adb' -and @($_)[4] -ceq $confirmedState.LaunchCommand })
        Assert-Equal 1 $launchCalls.Count 'The installed Kitsune APK was not launched through a structured ADB command.'
        Assert-True ((@($launchCalls[0]) -join ' ') -match 'io\.github\.huskydg\.magisk') 'The Kitsune launch was not targeted at the Kitsune package.'
        $installCallIndex = Get-Root12CallIndex -Calls $confirmedState.Calls -Pattern ('*' + $expectedInstallCommand + '*')
        $launchCallIndex = Get-Root12CallIndex -Calls $confirmedState.Calls -Pattern ('*' + $confirmedState.LaunchCommand + '*')
        $bootCallIndex = Get-Root12CallIndex -Calls $confirmedState.Calls -Pattern 'control*-v*launch*'
        Assert-True ($installCallIndex -lt $launchCallIndex) 'The Kitsune APK was launched before it was installed.'
        Assert-True ($launchCallIndex -lt $bootCallIndex) 'The Kitsune APK was launched after the confirmation gate.'

        $launchFailureState = New-Root12ManagerState -Install $install
        $launchFailureState.AdbFailPattern = '*monkey*'
        $launchPromptState = @{ Calls = 0 }
        $launchFailurePrompt = { param($PromptText) $launchPromptState.Calls++; 'Direct Install into system partition' }.GetNewClosure()
        $launchFailureCase = Invoke-Root12Case -State $launchFailureState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Prompt $launchFailurePrompt
        Assert-Root12Failure -Result $launchFailureCase.Result -Journal $launchFailureCase.Journal -Code 'APK_LAUNCH_FAILED' -Message 'A failed Kitsune launch was accepted.'
        Assert-Equal 0 $launchPromptState.Calls 'A failed Kitsune launch still asked the operator to confirm.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $launchFailureState.Calls -Pattern 'control*-v*launch*') 'A failed Kitsune launch cold-booted the instance.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $launchFailureState.Calls -Pattern '*root_permission*-val*false*') 'A failed Kitsune launch disabled the vendor root.'

        $resumeState = New-Root12VerifiedCloneState -Install $install -Instance $android12 -Manifest $manifest -JournalRoot $journalRoot -CacheRoot $assetCacheRoot
        $declinedRecord = [pscustomobject]@{ CloneIndex = $resumeState.CloneIndex; CloneName = $resumeState.CloneName; SourceIndex = $install.SourceIndex }
        $resumedCase = Invoke-Root12Case -State $resumeState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition' -ResumeClone $declinedRecord
        Assert-Equal 'Success' $resumedCase.Result.Status "A resume of the recorded clone did not complete. $($resumedCase.Result.Message)"
        Assert-Equal $resumeState.CloneIndex $resumedCase.Result.Data.CloneIndex 'The resume reported the wrong clone.'
        Assert-Equal 1 @($resumeState.Calls | Where-Object { @($_)[0] -ceq 'clone' }).Count 'The resume created a second clone.'

        $declinedFlow = New-Root12ManagerState -Install $install
        $declinedFlowCase = Invoke-Root12Case -State $declinedFlow -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Prompt { 'no' }
        Assert-Root12Failure -Result $declinedFlowCase.Result -Journal $declinedFlowCase.Journal -Code 'USER_CONFIRMATION_REQUIRED' -Message 'The declined interactive run was not reported as needing confirmation.'
        Assert-True ($declinedFlowCase.Result.Data -is [Collections.IDictionary]) 'The failed result did not return the recovery record a caller holds.'
        $resumedFlowCase = Invoke-Root12Case -State $declinedFlow -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition' `
            -ResumeClone $declinedFlowCase.Result.Data
        Assert-Equal 'Success' $resumedFlowCase.Result.Status "A resume with the recovery record of the declined call did not complete. $($resumedFlowCase.Result.Message)"
        Assert-Equal $declinedFlow.CloneIndex $resumedFlowCase.Result.Data.CloneIndex 'The resume of a returned recovery record reported the wrong clone.'
        Assert-Equal 1 @($declinedFlow.Calls | Where-Object { @($_)[0] -ceq 'clone' }).Count 'The resume of a returned recovery record created a second clone.'

        $dictionaryRecordState = New-Root12VerifiedCloneState -Install $install -Instance $android12 -Manifest $manifest -JournalRoot $journalRoot -CacheRoot $assetCacheRoot
        $dictionaryRecordCheck = Assert-Android12ResumeClone -ManagerPath $install.ManagerPath -VmsPath $install.VmsPath `
            -Record (@{ CloneIndex = [int]$dictionaryRecordState.CloneIndex; CloneName = [string]$dictionaryRecordState.CloneName }) `
            -Runner (New-Root12ManagerRunner -State $dictionaryRecordState)
        Assert-Equal 'Success' $dictionaryRecordCheck.Status 'A recovery record expressed as a dictionary was refused.'
        Assert-Equal $dictionaryRecordState.CloneIndex $dictionaryRecordCheck.Data.CloneIndex 'A dictionary recovery record resolved the wrong clone.'
        $dictionaryMissingIndexCheck = Assert-Android12ResumeClone -ManagerPath $install.ManagerPath -VmsPath $install.VmsPath `
            -Record (@{ CloneName = 'Target clone' }) -Runner (New-Root12ManagerRunner -State $dictionaryRecordState)
        Assert-Equal 'CriticalError' $dictionaryMissingIndexCheck.Status 'A dictionary recovery record without an index was accepted.'
        Assert-Equal 'RESUME_RECORD_INVALID' $dictionaryMissingIndexCheck.Data.Code 'A dictionary recovery record without an index reported the wrong code.'
        $resumeJournal = Get-OperationJournal -Path $resumedCase.Journal.JournalPath
        $resumeText = ([string](@($resumeJournal.Checkpoints) | ForEach-Object { $_.Message }) -join ' ')
        Assert-True ($resumeText -match 'resumed') 'The resume was not recorded in the journal.'

        $resumeFailureState = New-Root12VerifiedCloneState -Install $install -Instance $android12 -Manifest $manifest -JournalRoot $journalRoot -CacheRoot $assetCacheRoot
        $resumeFailureState.BootReadyPolls = 99
        $resumeFailureCase = Invoke-Root12Case -State $resumeFailureState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition' `
            -ResumeClone ([pscustomobject]@{ CloneIndex = $resumeFailureState.CloneIndex })
        Assert-Root12Failure -Result $resumeFailureCase.Result -Journal $resumeFailureCase.Journal -Code 'BOOT_TIMEOUT' -Message 'A failed resume did not report a structured failure.'
        Assert-Equal $resumeFailureState.CloneIndex $resumeFailureCase.Result.Data.CloneIndex 'A failed resume did not report the recoverable clone.'
        Assert-Equal 1 @($resumeFailureState.Calls | Where-Object { @($_)[0] -ceq 'clone' }).Count 'A failed resume created a second clone.'

        $emptyState = New-Root12ManagerState -Install $install
        $missingCloneCheck = Assert-Android12ResumeClone -ManagerPath $install.ManagerPath -VmsPath $install.VmsPath `
            -Record ([pscustomobject]@{ CloneIndex = $emptyState.CloneIndex }) -Runner (New-Root12ManagerRunner -State $emptyState)
        Assert-Equal 'CriticalError' $missingCloneCheck.Status 'A resume against a missing clone was accepted.'
        Assert-Equal 'RESUME_CLONE_MISSING' $missingCloneCheck.Data.Code 'A resume against a missing clone reported the wrong code.'

        foreach ($invalidRecord in @(
                [pscustomobject]@{ Record = 'invalid'; Label = 'string' },
                [pscustomobject]@{ Record = @([pscustomobject]@{ CloneIndex = 5 }); Label = 'array' },
                [pscustomobject]@{ Record = ([pscustomobject]@{ CloneIndex = 'abc' }); Label = 'non-numeric index' },
                [pscustomobject]@{ Record = ([pscustomobject]@{ CloneIndex = -1 }); Label = 'negative index' },
                [pscustomobject]@{ Record = ([pscustomobject]@{ CloneIndex = $null }); Label = 'missing index' },
                [pscustomobject]@{ Record = ([pscustomobject]@{ CloneIndex = 5; CloneName = '   ' }); Label = 'blank name' }
            )) {
            $invalidRecordState = New-Root12ManagerState -Install $install
            $invalidRecordCheck = Assert-Android12ResumeClone -ManagerPath $install.ManagerPath -VmsPath $install.VmsPath `
                -Record $invalidRecord.Record -Runner (New-Root12ManagerRunner -State $invalidRecordState)
            Assert-Equal 'CriticalError' $invalidRecordCheck.Status "An invalid resume record was accepted: $($invalidRecord.Label)"
            Assert-Equal 'RESUME_RECORD_INVALID' $invalidRecordCheck.Data.Code "An invalid resume record reported the wrong code: $($invalidRecord.Label)"
            Assert-Equal 0 @($invalidRecordState.Calls).Count "An invalid resume record reached the MuMu manager: $($invalidRecord.Label)"
        }

        foreach ($resumeDefect in @('identity', 'version', 'containment', 'disk', 'base')) {
            $defectState = New-Root12VerifiedCloneState -Install $install -Instance $android12 -Manifest $manifest -JournalRoot $journalRoot -CacheRoot $assetCacheRoot
            $defectRecord = @($defectState.Instances | Where-Object { $_.Index -eq $defectState.CloneIndex })[0]
            $expectedName = $defectState.CloneName
            switch ($resumeDefect) {
                'identity' { $expectedName = 'Some other clone' }
                'version' { $defectRecord.Android = '15.0' }
                'containment' { $defectRecord.VmsPath = $outsideVms }
                'disk' { [IO.File]::Delete((Join-Path (Join-Path $install.VmsPath ([string]$defectState.CloneIndex)) 'system.img')) }
                'base' { $defectRecord.IsMain = $true }
            }
            $defectCode = switch ($resumeDefect) {
                'identity' { 'RESUME_CLONE_IDENTITY' }
                'version' { 'RESUME_CLONE_VERSION' }
                'containment' { 'RESUME_CLONE_CONTAINMENT' }
                'disk' { 'RESUME_CLONE_DISK' }
                'base' { 'RESUME_CLONE_IDENTITY' }
            }
            $defectCheck = Assert-Android12ResumeClone -ManagerPath $install.ManagerPath -VmsPath $install.VmsPath `
                -Record ([pscustomobject]@{ CloneIndex = $defectState.CloneIndex; CloneName = $expectedName }) `
                -Runner (New-Root12ManagerRunner -State $defectState)
            Assert-Equal 'CriticalError' $defectCheck.Status "A defective clone was accepted for resume: $resumeDefect"
            Assert-Equal $defectCode $defectCheck.Data.Code "A defective clone reported the wrong resume code: $resumeDefect"
        }

        $brokenResumeState = New-Root12VerifiedCloneState -Install $install -Instance $android12 -Manifest $manifest -JournalRoot $journalRoot -CacheRoot $assetCacheRoot
        $brokenCloneRecord = @($brokenResumeState.Instances | Where-Object { $_.Index -eq $brokenResumeState.CloneIndex })[0]
        $brokenCloneRecord.Name = 'Some other clone'
        $brokenCallsBefore = @($brokenResumeState.Calls).Count
        $brokenResumeCase = Invoke-Root12Case -State $brokenResumeState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition' `
            -ResumeClone ([pscustomobject]@{ CloneIndex = $brokenResumeState.CloneIndex; CloneName = $brokenResumeState.CloneName })
        $brokenResumeCalls = @(@($brokenResumeState.Calls)[$brokenCallsBefore..(@($brokenResumeState.Calls).Count - 1)])
        Assert-Root12Failure -Result $brokenResumeCase.Result -Journal $brokenResumeCase.Journal -Code 'RESUME_CLONE_IDENTITY' -Message 'A resume against a clone that no longer matches its recorded identity was accepted.'
        Assert-Equal 0 (@($brokenResumeCalls | Where-Object { @($_)[0] -ceq 'setting' -or @($_)[0] -ceq 'adb' }).Count) 'A resume against a defective clone still reconfigured the clone.'
        Assert-Equal 0 (@($brokenResumeCalls | Where-Object { @($_)[0] -ceq 'control' }).Count) 'A resume against a defective clone still controlled the instance.'
        Assert-Equal 1 @($brokenResumeState.Calls | Where-Object { @($_)[0] -ceq 'clone' }).Count 'A resume against a defective clone created a second clone.'

        $nullCloneResult = Resolve-Android12Clone -CloneResult (Get-ToolkitResult -Status 'Success' -Message 'clone' -Data $null) -Journal (New-Root12Journal -Root $journalRoot -Instance $android12)
        Assert-Equal 'CriticalError' $nullCloneResult.Status 'A successful clone result without data was accepted as a root result.'
        Assert-Equal 'CLONE_UNVERIFIED' $nullCloneResult.Data.Code 'A successful clone result without data reported the wrong code.'
        foreach ($invalidClone in @(
                [pscustomobject]@{ Data = @{ CloneIndex = 'abc' }; Label = 'non-numeric index' },
                [pscustomobject]@{ Data = @{ CloneIndex = -1 }; Label = 'negative index' },
                [pscustomobject]@{ Data = @{ CloneIndex = 5; CloneName = '   ' }; Label = 'blank name' }
            )) {
            $invalidCloneResult = Resolve-Android12Clone -CloneResult (Get-ToolkitResult -Status 'Success' -Message 'clone' -Data $invalidClone.Data) -Journal (New-Root12Journal -Root $journalRoot -Instance $android12)
            Assert-Equal 'CriticalError' $invalidCloneResult.Status "An invalid clone result was accepted: $($invalidClone.Label)"
            Assert-Equal 'CLONE_INVALID' $invalidCloneResult.Data.Code "An invalid clone result reported the wrong code: $($invalidClone.Label)"
        }

        $cloneState = New-Root12ManagerState -Install $install
        $cloneState.CloneExitCode = 3
        $cloneCase = Invoke-Root12Case -State $cloneState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-Equal 'CriticalError' $cloneCase.Result.Status 'A failed instance clone was accepted.'
        Assert-True ($cloneCase.Result.Message -match '(?i)clone') 'A failed instance clone did not report the clone failure.'
        Assert-Equal 'Failed' $cloneCase.Journal.State 'A failed instance clone was not journaled.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $cloneState.Calls -Pattern '*adb*') 'A failed instance clone reached the instance.'

        $bootTimeoutState = New-Root12ManagerState -Install $install
        $bootTimeoutState.BootReadyPolls = 99
        $bootTimeoutCase = Invoke-Root12Case -State $bootTimeoutState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-Root12Failure -Result $bootTimeoutCase.Result -Journal $bootTimeoutCase.Journal -Code 'BOOT_TIMEOUT' -Message 'A boot timeout was accepted.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $bootTimeoutState.Calls -Pattern '*pidof magiskd*') 'A boot timeout still verified the root daemon.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $bootTimeoutState.Calls -Pattern '*root_permission*-val*false*') 'A boot timeout disabled the temporary vendor root.'
        Assert-Equal $bootTimeoutState.CloneIndex $bootTimeoutCase.Result.Data.CloneIndex 'A boot timeout did not report the recoverable clone.'

        $bootControlState = New-Root12ManagerState -Install $install
        $bootControlState.ControlFailPattern = '*launch*'
        $bootControlCase = Invoke-Root12Case -State $bootControlState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-Root12Failure -Result $bootControlCase.Result -Journal $bootControlCase.Journal -Code 'BOOT_CONTROL_FAILED' -Message 'A failed cold-boot launch was accepted.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $bootControlState.Calls -Pattern '*getprop sys.boot_completed*') 'A failed cold-boot launch still waited for the boot.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $bootControlState.Calls -Pattern '*root_permission*-val*false*') 'A failed cold-boot launch disabled the temporary vendor root.'

        $stopControlState = New-Root12ManagerState -Install $install
        $stopControlState.Instances[1].Running = $false
        $stopControlState.ControlFailPattern = '*shutdown*'
        $stopControlCase = Invoke-Root12Case -State $stopControlState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-Root12Failure -Result $stopControlCase.Result -Journal $stopControlCase.Journal -Code 'BOOT_CONTROL_FAILED' -Message 'A failed cold-boot shutdown was accepted.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $stopControlState.Calls -Pattern '*getprop sys.boot_completed*') 'A failed cold-boot shutdown still waited for the boot.'

        $missingPackageState = New-Root12ManagerState -Install $install
        $missingPackageState.PackageInstalled = $false
        $missingPackageCase = Invoke-Root12Case -State $missingPackageState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-Root12Failure -Result $missingPackageCase.Result -Journal $missingPackageCase.Journal -Code 'PACKAGE_MISSING' -Message 'A missing Kitsune package was accepted.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $missingPackageState.Calls -Pattern '*root_permission*-val*false*') 'A missing Kitsune package disabled the temporary vendor root.'

        foreach ($versionCase in @(
                [pscustomobject]@{ Name = '30.0'; Code = '28000'; Label = 'name' },
                [pscustomobject]@{ Name = '31.0-kitsune'; Code = '27000'; Label = 'code' },
                [pscustomobject]@{ Name = '31.0-kitsune-beta'; Code = '31000'; Label = 'name suffix' },
                [pscustomobject]@{ Name = '31.0-kitsune'; Code = '310001'; Label = 'code suffix' }
            )) {
            $versionState = New-Root12ManagerState -Install $install
            $versionState.VersionName = $versionCase.Name
            $versionState.VersionCode = $versionCase.Code
            $versionFailure = Invoke-Root12Case -State $versionState -Instance $android12 -Manifest $manifest `
                -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
            Assert-Root12Failure -Result $versionFailure.Result -Journal $versionFailure.Journal -Code 'PACKAGE_VERSION_MISMATCH' -Message "An unpinned Kitsune version was accepted: $($versionCase.Label)."
            Assert-Equal -1 (Get-Root12CallIndex -Calls $versionState.Calls -Pattern '*root_permission*-val*false*') "An unpinned Kitsune version disabled the temporary vendor root: $($versionCase.Label)."
        }

        foreach ($nearNameCase in @(
                [pscustomobject]@{ Header = 'io.github.huskydg.magisk.beta'; Label = 'a near-name package' },
                [pscustomobject]@{ Header = 'io.github.huskydg.magiskx'; Label = 'a longer package name' },
                [pscustomobject]@{ Header = 'io.github.huskydg'; Label = 'a shorter package name' }
            )) {
            $nearNameState = New-Root12ManagerState -Install $install
            $nearNameState.PackageHeaderName = $nearNameCase.Header
            $nearNameFailure = Invoke-Root12Case -State $nearNameState -Instance $android12 -Manifest $manifest `
                -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
            Assert-Root12Failure -Result $nearNameFailure.Result -Journal $nearNameFailure.Journal -Code 'PACKAGE_MISSING' -Message "The Android 12 package check accepted $($nearNameCase.Label) as the Kitsune package."
            Assert-Equal '' $nearNameFailure.Result.Data.VersionName "The Android 12 package check recorded a version from $($nearNameCase.Label)."
            Assert-Equal -1 (Get-Root12CallIndex -Calls $nearNameState.Calls -Pattern '*root_permission*-val*false*') "A near-name package disabled the temporary vendor root: $($nearNameCase.Label)."
        }

        foreach ($multiBlock in @(
                [pscustomobject]@{ ExtraName = '31.0-kitsune'; ExtraCode = '31000'; RealName = '30.0'; RealCode = '28000'; Code = 'PACKAGE_VERSION_MISMATCH'; Status = 'CriticalError'; Label = 'a near-name block with the pinned version before an unpinned real package' },
                [pscustomobject]@{ ExtraName = '9.9.9'; ExtraCode = '99999'; RealName = '31.0-kitsune'; RealCode = '31000'; Code = 'OK'; Status = 'Success'; Label = 'a near-name block with an unpinned version before the pinned real package' }
            )) {
            $multiBlockState = New-Root12ManagerState -Install $install
            $multiBlockState.VersionName = $multiBlock.RealName
            $multiBlockState.VersionCode = $multiBlock.RealCode
            $multiBlockState.PackageExtraBlock = ('Package [io.github.huskydg.magisk.beta] (ff00ff):' + [Environment]::NewLine + '    versionCode=' + $multiBlock.ExtraCode + ' minSdk=26' + [Environment]::NewLine + '    versionName=' + $multiBlock.ExtraName)
            $multiBlockCase = Invoke-Root12Case -State $multiBlockState -Instance $android12 -Manifest $manifest `
                -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
            Assert-Equal $multiBlock.Status $multiBlockCase.Result.Status "The Android 12 package check accepted $($multiBlock.Label)."
            if ($multiBlock.Status -eq 'CriticalError') {
                Assert-Equal $multiBlock.Code $multiBlockCase.Result.Data.Code "The Android 12 package check reported the wrong code for $($multiBlock.Label)."
                Assert-Equal $multiBlock.RealName $multiBlockCase.Result.Data.VersionName "The Android 12 package check recorded a version from the wrong block: $($multiBlock.Label)."
                Assert-Equal $multiBlock.RealCode $multiBlockCase.Result.Data.VersionCode "The Android 12 package check recorded a version code from the wrong block: $($multiBlock.Label)."
                Assert-Equal -1 (Get-Root12CallIndex -Calls $multiBlockState.Calls -Pattern '*root_permission*-val*false*') "A wrong block version disabled the temporary vendor root: $($multiBlock.Label)."
            }
            else {
                Assert-Equal $multiBlock.RealName $multiBlockCase.Result.Data.VersionName "The Android 12 package check recorded a version from the wrong block: $($multiBlock.Label)."
            }
        }

        foreach ($daemonCase in @(
                [pscustomobject]@{ Pids = ''; Code = 'DAEMON_ABSENT' },
                [pscustomobject]@{ Pids = '   '; Code = 'DAEMON_ABSENT' },
                [pscustomobject]@{ Pids = "11`n22"; Code = 'DAEMON_DUPLICATE' }
            )) {
            $daemonState = New-Root12ManagerState -Install $install
            $daemonState.DaemonPids = $daemonCase.Pids
            $daemonFailure = Invoke-Root12Case -State $daemonState -Instance $android12 -Manifest $manifest `
                -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
            Assert-Root12Failure -Result $daemonFailure.Result -Journal $daemonFailure.Journal -Code $daemonCase.Code -Message "An unexpected root daemon count was accepted: $($daemonCase.Code)."
            Assert-Equal -1 (Get-Root12CallIndex -Calls $daemonState.Calls -Pattern '*root_permission*-val*false*') "An unexpected root daemon count disabled the temporary vendor root: $($daemonCase.Code)."
        }

        foreach ($rootCase in @(
                [pscustomobject]@{ Allowed = $false; Label = 'denied' },
                [pscustomobject]@{ Allowed = $true; Text = 'uid=2000(shell) gid=2000(shell)'; Label = 'non-root identity' },
                [pscustomobject]@{ Allowed = $true; Text = ''; Label = 'empty identity' }
            )) {
            $rootDeniedState = New-Root12ManagerState -Install $install
            $rootDeniedState.RootAllowed = [bool]$rootCase.Allowed
            if ($rootCase.PSObject.Properties['Text']) {
                $rootDeniedState.RootShellText = [string]$rootCase.Text
            }
            $rootDeniedCase = Invoke-Root12Case -State $rootDeniedState -Instance $android12 -Manifest $manifest `
                -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
            Assert-Root12Failure -Result $rootDeniedCase.Result -Journal $rootDeniedCase.Journal -Code 'ROOT_DENIED' -Message "A root shell without root identity was accepted: $($rootCase.Label)."
            Assert-Equal -1 (Get-Root12CallIndex -Calls $rootDeniedState.Calls -Pattern '*root_permission*-val*false*') "A root shell without root identity disabled the temporary vendor root: $($rootCase.Label)."
        }

        foreach ($adbCase in @(
                [pscustomobject]@{ Pattern = '*dumpsys*'; Label = 'package query' },
                [pscustomobject]@{ Pattern = '*pidof*'; Label = 'daemon query' }
            )) {
            $adbState = New-Root12ManagerState -Install $install
            $adbState.AdbFailPattern = $adbCase.Pattern
            $adbFailure = Invoke-Root12Case -State $adbState -Instance $android12 -Manifest $manifest `
                -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
            Assert-Root12Failure -Result $adbFailure.Result -Journal $adbFailure.Journal -Code 'ADB_FAILED' -Message "A failed $($adbCase.Label) was accepted."
            Assert-Equal -1 (Get-Root12CallIndex -Calls $adbState.Calls -Pattern '*root_permission*-val*false*') "A failed $($adbCase.Label) disabled the temporary vendor root."
        }

        $bootAdbState = New-Root12ManagerState -Install $install
        $bootAdbState.AdbFailPattern = '*getprop*'
        $bootAdbCase = Invoke-Root12Case -State $bootAdbState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-Root12Failure -Result $bootAdbCase.Result -Journal $bootAdbCase.Journal -Code 'BOOT_TIMEOUT' -Message 'A failed boot readiness query was accepted.'

        $apkFailureState = New-Root12ManagerState -Install $install
        $apkFailureState.ApkInstallExitCode = 1
        $apkFailureCase = Invoke-Root12Case -State $apkFailureState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-Root12Failure -Result $apkFailureCase.Result -Journal $apkFailureCase.Journal -Code 'APK_INSTALL_FAILED' -Message 'A failed APK install was accepted.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $apkFailureState.Calls -Pattern '*monkey*') 'A failed APK install still launched the Kitsune app.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $apkFailureState.Calls -Pattern '*pidof magiskd*') 'A failed APK install still verified the root daemon.'

        $firstQueryState = New-Root12ManagerState -Install $install
        $firstQueryState.RootSettingQueryFailCount = 1
        $firstQueryCase = Invoke-Root12Case -State $firstQueryState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-Root12Failure -Result $firstQueryCase.Result -Journal $firstQueryCase.Journal -Code 'VENDOR_ROOT_SETTING_UNREADABLE' -Message 'An unreadable first vendor root readback was accepted.'
        Assert-Equal $firstQueryState.CloneIndex $firstQueryCase.Result.Data.CloneIndex 'An unreadable first vendor root readback did not expose the clone.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $firstQueryState.Calls -Pattern '*root_permission*-val*true*') 'An unreadable first vendor root readback still enabled the vendor root.'
        $firstQueryReopened = Get-OperationJournal -Path $firstQueryCase.Journal.JournalPath
        Assert-True (@($firstQueryReopened.Checkpoints | Where-Object { $_.Level -ceq 'Error' }).Count -ge 1) 'An unreadable first vendor root readback recorded no Error checkpoint.'

        $ignoredEnableState = New-Root12ManagerState -Install $install
        $ignoredEnableState.IgnoreRootEnable = $true
        $ignoredEnableCase = Invoke-Root12Case -State $ignoredEnableState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-Root12Failure -Result $ignoredEnableCase.Result -Journal $ignoredEnableCase.Journal -Code 'VENDOR_ROOT_NOT_ENABLED' -Message 'A vendor root change the clone did not report was accepted.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $ignoredEnableState.Calls -Pattern '*install -r*') 'An unreported vendor root change still installed the Kitsune APK.'

        $ignoredDisableState = New-Root12ManagerState -Install $install
        $ignoredDisableState.IgnoreRootDisable = $true
        $ignoredDisableCase = Invoke-Root12Case -State $ignoredDisableState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-Root12Failure -Result $ignoredDisableCase.Result -Journal $ignoredDisableCase.Journal -Code 'VENDOR_ROOT_NOT_DISABLED' -Message 'A verified root with a vendor root the clone still reports was accepted.'
        Assert-Equal $true $ignoredDisableState.RootSettings[[string]$ignoredDisableState.CloneIndex] 'A vendor root the clone still reports was not preserved for recovery.'
        Assert-Equal $true $ignoredDisableCase.Result.Data.RootVerified 'The reported failure did not state that root verification had passed.'

        $rootEnableFailureState = New-Root12ManagerState -Install $install
        $rootEnableFailureState.RootSettingExitCode = 1
        $rootEnableFailureCase = Invoke-Root12Case -State $rootEnableFailureState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-Root12Failure -Result $rootEnableFailureCase.Result -Journal $rootEnableFailureCase.Journal -Code 'VENDOR_ROOT_ENABLE_FAILED' -Message 'A failed vendor root enable was accepted.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $rootEnableFailureState.Calls -Pattern '*install -r*') 'A failed vendor root enable still installed the Kitsune APK.'

        $rootDisableFailureState = New-Root12ManagerState -Install $install
        $rootDisableFailureState.RootSettingExitCode = 1
        $rootDisableFailureState.RootSettingFailValue = 'false'
        $rootDisableFailureCase = Invoke-Root12Case -State $rootDisableFailureState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-Root12Failure -Result $rootDisableFailureCase.Result -Journal $rootDisableFailureCase.Journal -Code 'VENDOR_ROOT_DISABLE_FAILED' -Message 'A failed vendor root disable was accepted.'
        Assert-Equal $true $rootDisableFailureCase.Result.Data.RootVerified 'A failed vendor root disable did not report that verification had passed.'

        $rootUnreadableState = New-Root12ManagerState -Install $install
        $rootUnreadableState.RootSettingText = '{"unexpected":true}'
        $rootUnreadableCase = Invoke-Root12Case -State $rootUnreadableState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-Root12Failure -Result $rootUnreadableCase.Result -Journal $rootUnreadableCase.Journal -Code 'VENDOR_ROOT_SETTING_UNREADABLE' -Message 'An unreadable vendor root setting was accepted.'

        foreach ($settingShape in @(
                [pscustomobject]@{ Text = '{"root_permission":"true"}'; Value = $true; Label = 'object' },
                [pscustomobject]@{ Text = '[{"root_permission":"true"}]'; Value = $true; Label = 'array' },
                [pscustomobject]@{ Text = '{"value":true}'; Value = $true; Label = 'value record' },
                [pscustomobject]@{ Text = '{"index":"7","value":"true"}'; Value = $true; Label = 'indexed record' },
                [pscustomobject]@{ Text = '{"root_setting":"false"}'; Value = $false; Label = 'underscore field' }
            )) {
            $shapeState = New-Root12ManagerState -Install $install
            $shapeState.RootSettingText = $settingShape.Text
            $shapeCheck = Get-ToolkitRootSetting -ManagerPath $install.ManagerPath -Index 7 -Runner (New-Root12ManagerRunner -State $shapeState)
            Assert-Equal 'Success' $shapeCheck.Status "A documented manager setting shape was refused: $($settingShape.Label)"
            Assert-Equal $settingShape.Value $shapeCheck.Data.Value "A documented manager setting shape returned the wrong value: $($settingShape.Label)"
        }

        foreach ($settingDefect in @(
                [pscustomobject]@{ Text = '{"error_code":1}'; Code = 'MANAGER_ERROR' },
                [pscustomobject]@{ Text = 'not json'; Code = 'MANAGER_JSON_INVALID' },
                [pscustomobject]@{ Text = '   '; Code = 'MANAGER_JSON_INVALID' },
                [pscustomobject]@{ Text = '[]'; Code = 'SHAPE_UNSUPPORTED' },
                [pscustomobject]@{ Text = '{"unexpected":true}'; Code = 'SHAPE_UNSUPPORTED' },
                [pscustomobject]@{ Text = '[{"unexpected":true}]'; Code = 'SHAPE_UNSUPPORTED' },
                [pscustomobject]@{ Text = '[{"value":"true"},{"value":"false"}]'; Code = 'SHAPE_UNSUPPORTED' },
                [pscustomobject]@{ Text = '{"index":"9","value":"true"}'; Code = 'INDEX_MISMATCH' },
                [pscustomobject]@{ Text = '{"value":"maybe"}'; Code = 'VALUE_INVALID' }
            )) {
            $defectState = New-Root12ManagerState -Install $install
            $defectState.RootSettingText = $settingDefect.Text
            $defectCheck = Get-ToolkitRootSetting -ManagerPath $install.ManagerPath -Index 7 -Runner (New-Root12ManagerRunner -State $defectState)
            Assert-Equal 'CriticalError' $defectCheck.Status "A defective manager setting response was accepted: $($settingDefect.Code)"
            Assert-Equal $settingDefect.Code $defectCheck.Data.Code "A defective manager setting response reported the wrong code: $($settingDefect.Code)"
        }
        $settingManagerFailureState = New-Root12ManagerState -Install $install
        $settingManagerFailureState.RootSettingQueryExitCode = 1
        $settingManagerFailureCheck = Get-ToolkitRootSetting -ManagerPath $install.ManagerPath -Index 7 -Runner (New-Root12ManagerRunner -State $settingManagerFailureState)
        Assert-Equal 'CriticalError' $settingManagerFailureCheck.Status 'A failed manager setting query was accepted.'
        Assert-Equal 'MANAGER_FAILED' $settingManagerFailureCheck.Data.Code 'A failed manager setting query reported the wrong code.'
        $blankSettingManager = Get-ToolkitRootSetting -ManagerPath '   ' -Index 7 -Runner (New-Root12ManagerRunner -State (New-Root12ManagerState -Install $install))
        Assert-Equal 'CriticalError' $blankSettingManager.Status 'A blank manager was accepted for a setting query.'
        Assert-Equal 'MANAGER_UNAVAILABLE' $blankSettingManager.Data.Code 'A blank manager reported the wrong setting code.'

        foreach ($journalCase in @(
                [pscustomobject]@{ Pattern = '*install -r*'; Label = 'APK installed checkpoint' },
                [pscustomobject]@{ Pattern = '*monkey*'; Label = 'Kitsune instruction checkpoint' },
                [pscustomobject]@{ Pattern = '*su -c id*'; Label = 'root check checkpoint' }
            )) {
            $journalState = New-Root12ManagerState -Install $install
            $journalCaseJournal = New-Root12Journal -Root $journalRoot -Instance $android12
            $journalState.JournalLockPath = $journalCaseJournal.JournalPath
            $journalState.JournalLockPattern = $journalCase.Pattern
            try {
                $journalFailure = Install-Android12Root -Instance $android12 -Manifest $manifest -Journal $journalCaseJournal `
                    -Interactive $true -Confirmation 'Direct Install into system partition' -CacheRoot $assetCacheRoot `
                    -Runner (New-Root12ManagerRunner -State $journalState)
            }
            finally {
                Release-Root12JournalLock -State $journalState
            }
            Assert-Equal 'CriticalError' $journalFailure.Status "A journal write failure was not reported: $($journalCase.Label)"
            Assert-Equal 'JOURNAL_WRITE_FAILED' $journalFailure.Data.Code "A journal write failure reported the wrong code: $($journalCase.Label)"
            Assert-True ($journalFailure.Message -match '(?i)journal') "A journal write failure did not mention the journal: $($journalCase.Label)"
        }

        $preLockedState = New-Root12ManagerState -Install $install
        $preLockedJournal = New-Root12Journal -Root $journalRoot -Instance $android12
        $preLockedState.JournalLock = [IO.File]::Open($preLockedJournal.JournalPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        try {
            $preLocked = Install-Android12Root -Instance $android12 -Manifest $manifest -Journal $preLockedJournal `
                -Interactive $true -Confirmation 'Direct Install into system partition' -CacheRoot $assetCacheRoot `
                -Runner (New-Root12ManagerRunner -State $preLockedState)
        }
        finally {
            Release-Root12JournalLock -State $preLockedState
        }
        Assert-Equal 'CriticalError' $preLocked.Status 'A locked journal did not fail the workflow.'
        Assert-Equal 'JOURNAL_WRITE_FAILED' $preLocked.Data.Code 'A locked journal reported the wrong code.'
        Assert-Equal 0 @($preLockedState.Calls).Count 'A locked journal still reached the MuMu manager.'
        Assert-Equal 'Running' $preLockedJournal.State 'An unjournalable failure changed the in-memory journal state.'

        $cachedState = New-Root12ManagerState -Install $install
        $cachedCase = Invoke-Root12Case -State $cachedState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition' -RequireCachedAsset
        Assert-Equal 'Success' $cachedCase.Result.Status 'A cached verified asset was refused in the cached-only contract.'

        $uncachedState = New-Root12ManagerState -Install $install
        $uncachedCase = Invoke-Root12Case -State $uncachedState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot (Join-Path $root12Root 'empty cache') -Interactive $true `
            -Confirmation 'Direct Install into system partition' -RequireCachedAsset
        Assert-Root12Failure -Result $uncachedCase.Result -Journal $uncachedCase.Journal -Code 'ASSET_VERIFICATION_FAILED' -Message 'The cached-only contract downloaded a missing asset.'
        Assert-Equal 0 @($uncachedState.Calls).Count 'The cached-only contract reached the MuMu manager without a verified asset.'
        Assert-Equal $kitsuneAssetPath (Prepare-Android12Asset -Manifest $manifest -CacheRoot $assetCacheRoot).Data 'Prepare-Android12Asset did not return the verified cache path.'

        $downloadCacheRoot = Join-Path $root12Root 'download cache'
        $fetchState = @{ Calls = @() }
        $goodFetch = {
            param($Url, $Path)
            $fetchState.Calls += ,@($Url, $Path)
            [IO.File]::WriteAllText($Path, 'kitsune apk fixture payload')
        }.GetNewClosure()
        $downloaded = Save-ToolkitAsset -Manifest $manifest -Id 'kitsune' -CacheRoot $downloadCacheRoot -Fetch $goodFetch
        Assert-Equal 'Success' $downloaded.Status "The pinned asset was not downloaded and verified. $($downloaded.Message)"
        Assert-Equal (Join-Path (Join-Path $downloadCacheRoot 'kitsune') 'app-release.apk') $downloaded.Data 'The verified download path is invalid.'
        Assert-Equal 1 @($fetchState.Calls).Count 'The pinned asset download was not attempted exactly once.'
        Assert-Equal 'https://github.com/Jordan231111/KitsuneMagisk/releases/download/v31.0-25fa2159/app-release.apk' @($fetchState.Calls)[0][0] 'The pinned download URL is invalid.'
        Assert-True ([IO.File]::Exists([string]$downloaded.Data)) 'The verified download is missing from the cache.'

        $reusedFetchState = @{ Calls = 0 }
        $reusedFetch = {
            param($Url, $Path)
            $reusedFetchState.Calls++
            [IO.File]::WriteAllText($Path, 'kitsune apk fixture payload')
        }.GetNewClosure()
        $reused = Save-ToolkitAsset -Manifest $manifest -Id 'kitsune' -CacheRoot $downloadCacheRoot -Fetch $reusedFetch
        Assert-Equal 'Success' $reused.Status 'A verified cached asset was rejected.'
        Assert-Equal 0 $reusedFetchState.Calls 'A verified cached asset was downloaded again.'

        $cachedOnlyState = @{ Calls = 0 }
        $cachedOnlyFetch = {
            param($Url, $Path)
            $cachedOnlyState.Calls++
            [IO.File]::WriteAllText($Path, 'kitsune apk fixture payload')
        }.GetNewClosure()
        $cachedOnly = Save-ToolkitAsset -Manifest $manifest -Id 'kitsune' -CacheRoot (Join-Path $root12Root 'empty cache') -Fetch $cachedOnlyFetch -RequireCached
        Assert-Equal 'CriticalError' $cachedOnly.Status 'The cached-only asset contract downloaded a missing asset.'
        Assert-Equal 0 $cachedOnlyState.Calls 'The cached-only asset contract reached the network fetch.'

        $partialState = @{ Paths = @() }
        $partialFetch = {
            param($Url, $Path)
            $partialState.Paths += ,([string]$Path)
            [IO.File]::WriteAllText($Path, 'partial')
        }.GetNewClosure()
        $partialRoot = Join-Path $root12Root 'partial download cache'
        $partialDownload = Save-ToolkitAsset -Manifest $manifest -Id 'kitsune' -CacheRoot $partialRoot -Fetch $partialFetch
        Assert-Equal 'CriticalError' $partialDownload.Status 'A partial download was verified.'
        Assert-Equal 1 @($partialState.Paths).Count 'A partial download was not attempted exactly once.'
        Assert-True (-not [IO.File]::Exists([string]$partialState.Paths[0])) 'A failed download left its partial file behind.'
        Assert-Equal 0 @(Get-ChildItem -LiteralPath (Join-Path $partialRoot 'kitsune') -File -ErrorAction SilentlyContinue).Count 'A failed download left a file in the cache directory.'

        $throwFetch = {
            param($Url, $Path)
            throw 'network unavailable'
        }.GetNewClosure()
        $throwRoot = Join-Path $root12Root 'failing download cache'
        $throwDownload = Save-ToolkitAsset -Manifest $manifest -Id 'kitsune' -CacheRoot $throwRoot -Fetch $throwFetch
        Assert-Equal 'CriticalError' $throwDownload.Status 'A failed fetch was reported as verified.'
        Assert-True ($throwDownload.Message -match 'network unavailable') 'A failed fetch lost its reason.'
        Assert-Equal 0 @(Get-ChildItem -LiteralPath (Join-Path $throwRoot 'kitsune') -File -ErrorAction SilentlyContinue).Count 'A failed fetch left a file in the cache directory.'

        $tamperedDownloadCacheRoot = Join-Path $root12Root 'tampered download cache'
        $tamperedFetch = {
            param($Url, $Path)
            [IO.File]::WriteAllText($Path, 'kitsune apk fixture payloaD')
        }.GetNewClosure()
        $tamperedDownload = Save-ToolkitAsset -Manifest $manifest -Id 'kitsune' -CacheRoot $tamperedDownloadCacheRoot -Fetch $tamperedFetch
        Assert-Equal 'CriticalError' $tamperedDownload.Status 'A tampered download of the pinned size was verified.'
        Assert-Equal 'Asset verification failed.' $tamperedDownload.Message 'A tampered download did not report the verification failure.'
        Assert-True (-not [IO.File]::Exists((Join-Path (Join-Path $tamperedDownloadCacheRoot 'kitsune') 'app-release.apk'))) 'A tampered download was kept in the cache.'

        $oversizeDownloadCacheRoot = Join-Path $root12Root 'oversize download cache'
        $oversizeManifest = New-Root12FixtureManifest -AssetPath $kitsuneAssetPath -Size 5
        $oversizeDownload = Save-ToolkitAsset -Manifest $oversizeManifest -Id 'kitsune' -CacheRoot $oversizeDownloadCacheRoot -Fetch $goodFetch
        Assert-Equal 'CriticalError' $oversizeDownload.Status 'A download larger than its pinned size was verified.'
        Assert-True (-not [IO.File]::Exists((Join-Path (Join-Path $oversizeDownloadCacheRoot 'kitsune') 'app-release.apk'))) 'An oversized download was kept in the cache.'

        $foreignUrlCacheRoot = Join-Path $root12Root 'foreign url cache'
        $foreignUrlState = @{ Calls = 0 }
        $foreignUrlFetch = {
            param($Url, $Path)
            $foreignUrlState.Calls++
            [IO.File]::WriteAllText($Path, 'kitsune apk fixture payload')
        }.GetNewClosure()
        $foreignUrlManifest = New-Root12FixtureManifest -AssetPath $kitsuneAssetPath -Url 'https://example.invalid/app-release.apk'
        $foreignUrl = Save-ToolkitAsset -Manifest $foreignUrlManifest -Id 'kitsune' -CacheRoot $foreignUrlCacheRoot -Fetch $foreignUrlFetch
        Assert-Equal 'CriticalError' $foreignUrl.Status 'An unpinned download URL was accepted.'
        Assert-Equal 0 $foreignUrlState.Calls 'An unpinned download URL reached the network fetch.'

        $missingAsset = Save-ToolkitAsset -Manifest $manifest -Id 'hma' -CacheRoot $downloadCacheRoot -Fetch $goodFetch
        Assert-Equal 'CriticalError' $missingAsset.Status 'An asset outside the manifest was downloaded.'

        $verifyState = New-Root12ManagerState -Install $install
        $verifyChecks = Test-Android12Root -ManagerPath $install.ManagerPath -InstanceIndex 7 -Runner (New-Root12ManagerRunner -State $verifyState)
        Assert-Equal 'Success' $verifyChecks.Status "The Android 12 root checks failed. $($verifyChecks.Message)"
        Assert-Equal 'OK' $verifyChecks.Data.Code 'The Android 12 root checks reported an invalid code.'
        Assert-Equal 'io.github.huskydg.magisk' $verifyChecks.Data.PackageName 'The Android 12 root checks reported the wrong package.'
        Assert-Equal '31.0-kitsune' $verifyChecks.Data.VersionName 'The Android 12 root checks reported the wrong version name.'
        Assert-Equal '31000' $verifyChecks.Data.VersionCode 'The Android 12 root checks reported the wrong version code.'
        Assert-Equal 1 $verifyChecks.Data.DaemonCount 'The Android 12 root checks did not count exactly one daemon.'
        Assert-Equal $true $verifyChecks.Data.RootVerified 'The Android 12 root checks did not verify the root shell.'
        Assert-Equal 3 @($verifyState.Calls).Count 'The Android 12 root checks made an unexpected number of ADB requests.'
        foreach ($verifyCall in $verifyState.Calls) {
            $verifyArguments = [string[]]@($verifyCall)
            Assert-Equal 5 $verifyArguments.Count 'A verification request carried more than one command element.'
            Assert-Equal 'adb' $verifyArguments[0] 'A verification request is not an ADB request.'
            Assert-Equal '-c' $verifyArguments[3] 'A verification request lost its ADB command flag.'
            Assert-True (($verifyArguments -join ' ') -notmatch '&') 'An Android 12 ADB request was shell-interpolated.'
        }
        $verifyCommands = @($verifyState.Calls | ForEach-Object { [string]@($_)[4] })
        Assert-True ($verifyCommands -ccontains ('shell dumpsys package ' + $verifyState.PackageName)) 'The package check is not one structured ADB command element.'
        Assert-True ($verifyCommands -ccontains 'shell pidof magiskd') 'The daemon check is not one structured ADB command element.'
        Assert-True ($verifyCommands -ccontains 'shell su -c id') 'The root check is not one structured ADB command element.'

        $blankManagerState = New-Root12ManagerState -Install $install
        $blankManagerChecks = Test-Android12Root -ManagerPath '   ' -InstanceIndex 7 -Runner (New-Root12ManagerRunner -State $blankManagerState)
        Assert-Equal 'CriticalError' $blankManagerChecks.Status 'A blank manager was accepted for root verification.'
        Assert-Equal 'MANAGER_UNAVAILABLE' $blankManagerChecks.Data.Code 'A blank manager was not reported as unavailable.'
        Assert-Equal 0 @($blankManagerState.Calls).Count 'A blank manager reached the process runner.'

        $negativeIndexState = New-Root12ManagerState -Install $install
        $negativeIndexChecks = Test-Android12Root -ManagerPath $install.ManagerPath -InstanceIndex -1 -Runner (New-Root12ManagerRunner -State $negativeIndexState)
        Assert-Equal 'CriticalError' $negativeIndexChecks.Status 'A negative instance index was accepted for root verification.'
        Assert-Equal 0 @($negativeIndexState.Calls).Count 'A negative instance index reached the process runner.'

        $deniedVerifyState = New-Root12ManagerState -Install $install
        $deniedVerifyState.RootAllowed = $false
        $deniedVerifyChecks = Test-Android12Root -ManagerPath $install.ManagerPath -InstanceIndex 7 -Runner (New-Root12ManagerRunner -State $deniedVerifyState)
        Assert-Equal 'CriticalError' $deniedVerifyChecks.Status 'A denied root shell was accepted by the root checks.'
        Assert-Equal 'ROOT_DENIED' $deniedVerifyChecks.Data.Code 'A denied root shell was not reported as a denial.'
        $transportVerifyState = New-Root12ManagerState -Install $install
        $transportVerifyState.AdbThrowPattern = '*su -c id*'
        $transportVerifyChecks = Test-Android12Root -ManagerPath $install.ManagerPath -InstanceIndex 7 -Runner (New-Root12ManagerRunner -State $transportVerifyState)
        Assert-Equal 'CriticalError' $transportVerifyChecks.Status 'A root shell query that could not be executed was accepted.'
        Assert-Equal 'ADB_FAILED' $transportVerifyChecks.Data.Code 'A root shell query that could not be executed was reported as a root denial.'
        Assert-Equal $false $transportVerifyChecks.Data.RootVerified 'A root shell query that could not be executed was reported as verified.'
    }
    finally {
        if ($null -ne $bootAttemptsVariable) {
            $script:ToolkitBootPollAttempts = $bootAttemptsVariable.Value
        }
        if ($null -ne $bootDelayVariable) {
            $script:ToolkitBootPollDelaySeconds = $bootDelayVariable.Value
        }
    }
}

$script:Root15Codes = @(
    'ANDROID_VERSION_UNSUPPORTED',
    'INSTANCE_INVALID',
    'JOURNAL_INVALID',
    'JOURNAL_WRITE_FAILED',
    'MANAGER_UNAVAILABLE',
    'USER_CONFIRMATION_REQUIRED',
    'CLONE_UNVERIFIED',
    'ROOT_SETTING_UNREADABLE',
    'ROOT_TOGGLE_FAILED',
    'ROOT_NOT_ENABLED',
    'BOOT_CONTROL_FAILED',
    'BOOT_TIMEOUT',
    'KERNELSU_ABSENT',
    'ROOT_DENIED',
    'KITSUNE_PRESENT',
    'ADB_FAILED'
)

function New-Root15InstanceFixture {
    param(
        [object]$Install,
        [string]$AndroidVersion
    )

    [pscustomobject]@{
        Index = $Install.SourceIndex
        Name = 'Android 15 target'
        AndroidVersion = $AndroidVersion
        Install = [pscustomobject]@{
            Edition = 'Global'
            InstallRoot = $Install.InstallRoot
            VmsPath = $Install.VmsPath
            ManagerPath = $Install.ManagerPath
            Source = 'Process'
        }
        Running = $true
        RootSetting = $false
        Eligible = $true
        IneligibleReason = $null
    }
}

function New-Root15Journal {
    param(
        [string]$Root,
        [object]$Instance
    )

    return New-OperationJournal -Root $Root -Operation 'Root15' -Instance $Instance
}

function New-Root15ManagerState {
    param([object]$Install)

    return @{
        VmsPath = $Install.VmsPath
        SourceIndex = $Install.SourceIndex
        CloneIndex = 5
        CloneName = 'Root15 target clone'
        CloneRootSetting = $false
        CloneExitCode = 0
        CloneCreatesRecord = $true
        CloneCreatesDisk = $true
        Calls = @()
        Instances = @(
            [pscustomobject]@{ Index = 0; Name = 'Base'; IsMain = $true; Running = $false; Android = '15.0'; VmsPath = '' }
            [pscustomobject]@{ Index = $Install.SourceIndex; Name = 'Target'; IsMain = $false; Running = $true; Android = '15.0'; VmsPath = '' }
        )
        RootSettings = @{}
        RootSettingExitCode = 0
        RootSettingQueryExitCode = 0
        RootSettingText = ''
        RootSettingIndex = ''
        IgnoreRootEnable = $false
        ControlFailPattern = ''
        AdbFailPattern = ''
        AdbThrowPattern = ''
        AdbBlankFailPattern = ''
        BootPolls = @{}
        BootReadyPolls = 1
        KernelSUPackage = $script:Root15KernelSUPackage
        KitsunePackage = $script:Root15KitsunePackage
        KernelSUInstalled = $true
        KernelSUHeaderName = ''
        KernelSUExtraBlock = ''
        KernelSUVersionName = '3.2.5'
        KernelSUVersionCode = '30205'
        KitsuneInstalled = $false
        PackageListText = ''
        RelatedPackageName = ''
        RootAllowed = $true
        RootShellText = 'uid=0(root) gid=0(root) groups=0(root)'
        JournalLockPath = ''
        JournalLockPattern = ''
        JournalLock = $null
    }
}

function Release-Root15JournalLock {
    param([hashtable]$State)

    if ($null -ne $State.JournalLock) {
        $State.JournalLock.Dispose()
        $State.JournalLock = $null
    }
}

function New-Root15ManagerRunner {
    param([hashtable]$State)

    return {
        param($ActualFilePath, $ActualArgumentList)
        $State.Calls += ,@($ActualArgumentList)
        $arguments = @($ActualArgumentList | ForEach-Object { [string]$_ })
        $command = $arguments[0]
        $commandText = @($arguments) -join ' '
        if ($null -eq $State.JournalLock -and -not [string]::IsNullOrWhiteSpace([string]$State.JournalLockPath) -and
            $commandText -like $State.JournalLockPattern) {
            $State.JournalLock = [IO.File]::Open([string]$State.JournalLockPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        }
        if ($command -eq 'info') {
            $requested = $arguments[2]
            $selected = @($State.Instances | Where-Object { $requested -eq 'all' -or [string]$_.Index -ceq $requested })
            if ($selected.Count -eq 0) {
                return [pscustomobject]@{ ExitCode = 1; Text = '{"error_code":1}' }
            }
            $records = @()
            foreach ($selectedInstance in $selected) {
                $records += [pscustomobject][ordered]@{
                    index = [string]$selectedInstance.Index
                    name = $selectedInstance.Name
                    is_main = [string]$selectedInstance.IsMain
                    is_process_started = [string]$selectedInstance.Running
                    android_version = $selectedInstance.Android
                }
            }
            return [pscustomobject]@{ ExitCode = 0; Text = (ConvertTo-Json -InputObject @($records) -Depth 4 -Compress) }
        }
        if ($command -eq 'control') {
            if (-not [string]::IsNullOrWhiteSpace([string]$State.ControlFailPattern) -and $commandText -like $State.ControlFailPattern) {
                return [pscustomobject]@{ ExitCode = 1; Text = '{"error_code":1}' }
            }
            if ($arguments[3] -eq 'shutdown') {
                foreach ($controlInstance in $State.Instances) {
                    if ([string]$controlInstance.Index -ceq $arguments[2]) {
                        $controlInstance.Running = $false
                    }
                }
            }
            return [pscustomobject]@{ ExitCode = 0; Text = '{"error_code":0}' }
        }
        if ($command -eq 'clone') {
            if ($State.CloneExitCode -ne 0) {
                return [pscustomobject]@{ ExitCode = $State.CloneExitCode; Text = '{"error_code":1}' }
            }
            if ($State.CloneCreatesRecord) {
                $cloneRoot = Join-Path ([string]$State.VmsPath) ([string]$State.CloneIndex)
                New-Item -ItemType Directory -Path $cloneRoot -Force | Out-Null
                if ($State.CloneCreatesDisk) {
                    [IO.File]::WriteAllText((Join-Path $cloneRoot 'system.img'), 'clone disk payload')
                }
                $State.Instances = @($State.Instances) + [pscustomobject]@{
                    Index = [int]$State.CloneIndex
                    Name = [string]$State.CloneName
                    IsMain = $false
                    Running = $false
                    Android = '15.0'
                    VmsPath = ''
                }
                $State.RootSettings[[string]$State.CloneIndex] = [bool]$State.CloneRootSetting
            }
            return [pscustomobject]@{ ExitCode = 0; Text = '{"error_code":0}' }
        }
        if ($command -eq 'setting') {
            $index = $arguments[2]
            $valueIndex = [array]::IndexOf($arguments, '-val')
            if ($valueIndex -ge 0) {
                $requestedValue = $arguments[$valueIndex + 1] -ceq 'true'
                if ($State.RootSettingExitCode -ne 0) {
                    return [pscustomobject]@{ ExitCode = $State.RootSettingExitCode; Text = '{"error_code":1}' }
                }
                if (-not ($requestedValue -and $State.IgnoreRootEnable)) {
                    $State.RootSettings[$index] = $requestedValue
                }
            }
            if ($State.RootSettingQueryExitCode -ne 0) {
                return [pscustomobject]@{ ExitCode = $State.RootSettingQueryExitCode; Text = '{"error_code":1}' }
            }
            if (-not [string]::IsNullOrEmpty([string]$State.RootSettingText)) {
                return [pscustomobject]@{ ExitCode = 0; Text = $State.RootSettingText }
            }
            if (-not [string]::IsNullOrWhiteSpace([string]$State.RootSettingIndex)) {
                $current = $false
                if ($State.RootSettings.ContainsKey($index)) {
                    $current = [bool]$State.RootSettings[$index]
                }
                return [pscustomobject]@{ ExitCode = 0; Text = ('{"index":"' + [string]$State.RootSettingIndex + '","root_permission":"' + $(if ($current) { 'true' } else { 'false' }) + '"}') }
            }
            $current = $false
            if ($State.RootSettings.ContainsKey($index)) {
                $current = [bool]$State.RootSettings[$index]
            }
            return [pscustomobject]@{ ExitCode = 0; Text = ('{"root_permission":"' + $(if ($current) { 'true' } else { 'false' }) + '"}') }
        }
        if ($command -eq 'adb') {
            $index = $arguments[2]
            $request = [string]$arguments[4]
            if (-not [string]::IsNullOrWhiteSpace([string]$State.AdbThrowPattern) -and $request -like $State.AdbThrowPattern) {
                throw 'adb transport failure'
            }
            if (-not [string]::IsNullOrWhiteSpace([string]$State.AdbBlankFailPattern) -and $request -like $State.AdbBlankFailPattern) {
                return [pscustomobject]@{ ExitCode = 1; Text = '' }
            }
            if (-not [string]::IsNullOrWhiteSpace([string]$State.AdbFailPattern) -and $request -like $State.AdbFailPattern) {
                return [pscustomobject]@{ ExitCode = 1; Text = 'adb: fixture failure' }
            }
            if ($request -ceq 'shell getprop sys.boot_completed') {
                $polls = 0
                if ($State.BootPolls.ContainsKey($index)) {
                    $polls = [int]$State.BootPolls[$index]
                }
                $polls++
                $State.BootPolls[$index] = $polls
                if ($polls -ge $State.BootReadyPolls) {
                    return [pscustomobject]@{ ExitCode = 0; Text = '1' }
                }
                return [pscustomobject]@{ ExitCode = 0; Text = '0' }
            }
            if ($request -ceq ('shell dumpsys package ' + $State.KernelSUPackage)) {
                if (-not $State.KernelSUInstalled) {
                    return [pscustomobject]@{ ExitCode = 0; Text = ('Unable to find package: ' + $State.KernelSUPackage + '.') }
                }
                $headerName = if ([string]::IsNullOrWhiteSpace([string]$State.KernelSUHeaderName)) { [string]$State.KernelSUPackage } else { [string]$State.KernelSUHeaderName }
                $extraBlock = ''
                if (-not [string]::IsNullOrWhiteSpace([string]$State.KernelSUExtraBlock)) {
                    $extraBlock = [string]$State.KernelSUExtraBlock + [Environment]::NewLine
                }
                return [pscustomobject]@{
                    ExitCode = 0
                    Text = ($extraBlock + 'Package [' + $headerName + '] (a1b2c3):' + [Environment]::NewLine + '    versionCode=' + $State.KernelSUVersionCode + ' minSdk=28' + [Environment]::NewLine + '    versionName=' + $State.KernelSUVersionName)
                }
            }
            if ($request -ceq 'shell pm list packages') {
                if (-not [string]::IsNullOrEmpty([string]$State.PackageListText)) {
                    return [pscustomobject]@{ ExitCode = 0; Text = $State.PackageListText }
                }
                $lines = @()
                if ($State.KitsuneInstalled) {
                    $lines += ('package:' + $State.KitsunePackage)
                }
                if (-not [string]::IsNullOrWhiteSpace([string]$State.RelatedPackageName)) {
                    $lines += ('package:' + $State.RelatedPackageName)
                }
                return [pscustomobject]@{ ExitCode = 0; Text = ($lines -join [Environment]::NewLine) }
            }
            if ($request -ceq 'shell su -c id') {
                if (-not $State.RootAllowed) {
                    return [pscustomobject]@{ ExitCode = 1; Text = '/system/bin/sh: su: not found' }
                }
                return [pscustomobject]@{ ExitCode = 0; Text = $State.RootShellText }
            }
            return [pscustomobject]@{ ExitCode = 1; Text = 'unsupported adb request' }
        }
        return [pscustomobject]@{ ExitCode = 1; Text = '{"error_code":1}' }
    }.GetNewClosure()
}

function Invoke-Root15Case {
    param(
        [hashtable]$State,
        [object]$Instance,
        [string]$JournalRoot,
        [bool]$Confirmed = $true
    )

    $journal = New-Root15Journal -Root $JournalRoot -Instance $Instance
    $result = Enable-Android15Root -Instance $Instance -Journal $journal -Confirmed:$Confirmed -Runner (New-Root15ManagerRunner -State $State)
    [pscustomobject]@{
        Result = $result
        Journal = $journal
        State = $State
    }
}

function Get-Root15CallIndex {
    param(
        [object[]]$Calls,
        [string]$Pattern
    )

    for ($index = 0; $index -lt $Calls.Count; $index++) {
        if ((@($Calls[$index]) -join ' ') -like $Pattern) {
            return $index
        }
    }
    return -1
}

function Get-Root15Calls {
    param(
        [object]$State,
        [string]$Pattern
    )

    return @($State.Calls | Where-Object { ((@($_) -join ' ')) -like $Pattern })
}

function Assert-Root15Failure {
    param(
        [object]$Result,
        [object]$Journal,
        [string]$Code,
        [string]$Message
    )

    Assert-Equal 'CriticalError' $Result.Status $Message
    Assert-True ($null -ne $Result.Data) "$Message The failure carried no recovery data."
    Assert-True ($script:Root15Codes -ccontains [string]$Result.Data.Code) "$Message The failure reported an undocumented code: $($Result.Data.Code)"
    Assert-True ([string]$Result.Data.Code -cne 'UNKNOWN') "$Message The failure reported an unknown code."
    Assert-Equal $Code $Result.Data.Code "$Message The failure code is invalid."
    Assert-Equal 'Failed' $Journal.State "$Message The failure was not journaled."
    $reopened = Get-OperationJournal -Path $Journal.JournalPath
    Assert-Equal 'Failed' $reopened.State "$Message The failure was not persisted."
    Assert-Equal 'CriticalError' $reopened.Result.Status "$Message The persisted result status is invalid."
    Assert-Equal $Code $reopened.Result.Data.Code "$Message The persisted recovery code changed."
    Assert-True (@($reopened.Checkpoints).Count -ge 1) "$Message No failure checkpoint was recorded."
}

function Invoke-Root15Tests {
    foreach ($commandName in @('Enable-Android15Root', 'Test-Android15Root')) {
        Assert-True ($null -ne (Get-Command $commandName -CommandType Function -ErrorAction SilentlyContinue)) "Android 15 command is unavailable: $commandName"
    }
    Assert-True (Test-Path -LiteralPath $root15ScriptPath -PathType Leaf) 'src/Root15.ps1 does not exist.'
    Assert-Equal $script:ToolkitKitsunePackageName $script:Root15KitsunePackage 'The Android 15 flow does not use the same Kitsune package name as the Android 12 flow.'
    Assert-Equal 'me.weishu.kernelsu' $script:Root15KernelSUPackage 'The Android 15 flow does not verify the built-in KernelSU package.'

    $enableCommand = Get-Command Enable-Android15Root -CommandType Function
    Assert-True ($enableCommand.Parameters.ContainsKey('Confirmed')) 'Enable-Android15Root has no explicit confirmation parameter.'
    $confirmedParameter = @($enableCommand.Parameters['Confirmed'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] })
    Assert-Equal 1 $confirmedParameter.Count 'The confirmation parameter metadata is invalid.'
    Assert-True ($enableCommand.Parameters['Confirmed'].ParameterType -eq [switch]) 'The confirmation parameter is not an explicit switch.'

    $root15Source = [IO.File]::ReadAllText($root15ScriptPath)
    Assert-True ($root15Source -notmatch "'UNKNOWN'") 'The Android 15 source reports an UNKNOWN failure code.'
    foreach ($forbidden in @(
            'Invoke-Expression',
            'ScriptBlock]::Create',
            'Add-Type',
            'Start-Process',
            'Invoke-WebRequest',
            'Invoke-RestMethod',
            'WebClient',
            'schtasks',
            'Set-ExecutionPolicy',
            'icacls',
            'Set-Acl',
            'New-NetFirewallRule',
            'Set-NetFirewallProfile',
            'EnableLUA',
            'Set-MpPreference',
            'Disable-WindowsOptionalFeature',
            'Enable-WindowsOptionalFeature',
            'bcdedit',
            'vmmservice',
            'hypervisorlaunchtype',
            'Save-ToolkitAsset',
            'Get-VerifiedAsset',
            'Get-ToolkitAssetCacheRoot',
            'Install-Android12Root',
            'Get-ToolkitManifest',
            'pm list packages io',
            'function Invoke-Android15Adb',
            'function Wait-Android15BootCompleted',
            'function Get-Android15RootSetting',
            'function New-Android15RootFailure'
        )) {
        Assert-True ($root15Source -notmatch [regex]::Escape($forbidden)) "Android 15 source uses a forbidden construct: $forbidden"
    }
    foreach ($sharedPrimitive in @('Invoke-ToolkitManagerAdb', 'Wait-ToolkitBootCompleted', 'Get-ToolkitRootSetting', 'Get-ToolkitPackageVersion', 'New-ToolkitRootFailure')) {
        Assert-True ($root15Source -match [regex]::Escape($sharedPrimitive)) "The Android 15 flow does not use the shared primitive: $sharedPrimitive"
    }
    $hypervisorPattern = '(?i)hyper-?v|virtual\s*machine\s*platform|vmmservice|memory\s*integrity|credential\s*guard|device\s*guard|exploit\s*protection'
    Assert-True ($root15Source -notmatch $hypervisorPattern) 'The Android 15 source mentions a Hyper-V, VBS, or memory integrity control.'

    $bootAttemptsVariable = Get-Variable -Name 'ToolkitBootPollAttempts' -Scope Script -ErrorAction SilentlyContinue
    $bootDelayVariable = Get-Variable -Name 'ToolkitBootPollDelaySeconds' -Scope Script -ErrorAction SilentlyContinue
    $script:ToolkitBootPollAttempts = 2
    $script:ToolkitBootPollDelaySeconds = 0
    try {
        $root15Root = Join-Path $testRoot 'root15 fixtures'
        $journalRoot = Join-Path $root15Root 'journals'
        $install = New-Root12InstallFixture -InstallRoot (Join-Path $root15Root 'MuMu Global') -SourceIndex 3
        $android12 = New-Root15InstanceFixture -Install $install -AndroidVersion '12.0'
        $android15 = New-Root15InstanceFixture -Install $install -AndroidVersion '15.0'

        foreach ($unsupportedVersion in @('11.0', '12.0', '13.0', '14.0', '15.1')) {
            $unsupportedVersionState = New-Root15ManagerState -Install $install
            $unsupportedVersionCase = Invoke-Root15Case -State $unsupportedVersionState `
                -Instance (New-Root15InstanceFixture -Install $install -AndroidVersion $unsupportedVersion) -JournalRoot $journalRoot
            Assert-Equal 'CriticalError' $unsupportedVersionCase.Result.Status "An Android $unsupportedVersion instance was accepted by the Android 15 workflow."
            Assert-True ($null -ne $unsupportedVersionCase.Result.Data) "The Android $unsupportedVersion rejection carried no recovery data."
            Assert-Equal 'ANDROID_VERSION_UNSUPPORTED' $unsupportedVersionCase.Result.Data.Code "Android $unsupportedVersion was not rejected as an unsupported Android version."
            Assert-Equal 0 @($unsupportedVersionState.Calls).Count "An Android $unsupportedVersion instance reached the MuMu manager."
            Assert-Equal 'Failed' $unsupportedVersionCase.Journal.State "The Android $unsupportedVersion rejection was not journaled."
            Assert-True ($unsupportedVersionCase.Result.Message -notmatch '(?i)android 12|kitsune|magisk') "The Android $unsupportedVersion rejection pointed the operator at another workflow."
        }

        $missingVersionState = New-Root15ManagerState -Install $install
        $missingVersionInstance = New-Root15InstanceFixture -Install $install -AndroidVersion '15.0'
        $missingVersionInstance.PSObject.Properties.Remove('AndroidVersion')
        $missingVersionCase = Invoke-Root15Case -State $missingVersionState -Instance $missingVersionInstance -JournalRoot $journalRoot
        Assert-Equal 'CriticalError' $missingVersionCase.Result.Status 'An instance without an Android version was accepted.'
        Assert-True ($null -ne $missingVersionCase.Result.Data) 'The missing Android version rejection carried no recovery data.'
        Assert-Equal 'ANDROID_VERSION_UNSUPPORTED' $missingVersionCase.Result.Data.Code 'An instance without an Android version was not rejected.'
        Assert-Equal 0 @($missingVersionState.Calls).Count 'An instance without an Android version reached the MuMu manager.'
        Assert-True ($missingVersionCase.Result.Message -notmatch '(?i)android 12|kitsune|magisk') 'The missing Android version rejection pointed the operator at another workflow.'

        $unconfirmedState = New-Root15ManagerState -Install $install
        $unconfirmedCase = Invoke-Root15Case -State $unconfirmedState -Instance $android15 -JournalRoot $journalRoot -Confirmed $false
        Assert-Root15Failure -Result $unconfirmedCase.Result -Journal $unconfirmedCase.Journal -Code 'USER_CONFIRMATION_REQUIRED' -Message 'An unconfirmed Android 15 root request was accepted.'
        Assert-True ($unconfirmedCase.Result.Message -match 'USER_CONFIRMATION_REQUIRED') 'The unconfirmed failure did not report USER_CONFIRMATION_REQUIRED.'
        Assert-Equal 0 @($unconfirmedState.Calls).Count 'An unconfirmed Android 15 root request reached the MuMu manager.'
        $unconfirmedDirectState = New-Root15ManagerState -Install $install
        $unconfirmedDirectJournal = New-Root15Journal -Root $journalRoot -Instance $android15
        $unconfirmedDirect = Enable-Android15Root -Instance $android15 -Journal $unconfirmedDirectJournal -Runner (New-Root15ManagerRunner -State $unconfirmedDirectState)
        Assert-Equal 'CriticalError' $unconfirmedDirect.Status 'An Android 15 root request without the confirmation parameter was accepted.'
        Assert-Equal 'USER_CONFIRMATION_REQUIRED' $unconfirmedDirect.Data.Code 'An absent confirmation parameter reported the wrong code.'
        Assert-Equal 0 @($unconfirmedDirectState.Calls).Count 'An absent confirmation parameter reached the MuMu manager.'
        $confirmedButInvalidState = New-Root15ManagerState -Install $install
        $confirmedButInvalid = Enable-Android15Root -Instance $android12 -Journal (New-Root15Journal -Root $journalRoot -Instance $android12) -Confirmed -Runner (New-Root15ManagerRunner -State $confirmedButInvalidState)
        Assert-Equal 'ANDROID_VERSION_UNSUPPORTED' $confirmedButInvalid.Data.Code 'A confirmed Android 12 request skipped the Android version check.'
        Assert-Equal 0 @($confirmedButInvalidState.Calls).Count 'A confirmed Android 12 request reached the MuMu manager.'

        $nullInstanceState = New-Root15ManagerState -Install $install
        $nullInstance = Enable-Android15Root -Instance $null -Journal (New-Root15Journal -Root $journalRoot -Instance $android15) -Runner (New-Root15ManagerRunner -State $nullInstanceState)
        Assert-Equal 'CriticalError' $nullInstance.Status 'A missing instance was accepted.'
        Assert-Equal 'INSTANCE_INVALID' $nullInstance.Data.Code 'A missing instance reported the wrong code.'
        Assert-Equal 0 @($nullInstanceState.Calls).Count 'A missing instance reached the MuMu manager.'

        $nullJournalState = New-Root15ManagerState -Install $install
        $nullJournal = Enable-Android15Root -Instance $android15 -Journal $null -Runner (New-Root15ManagerRunner -State $nullJournalState)
        Assert-Equal 'CriticalError' $nullJournal.Status 'A missing journal was accepted.'
        Assert-Equal 'JOURNAL_INVALID' $nullJournal.Data.Code 'A missing journal reported the wrong code.'
        Assert-Equal 0 @($nullJournalState.Calls).Count 'A missing journal reached the MuMu manager.'

        $invalidJournalState = New-Root15ManagerState -Install $install
        $invalidJournal = New-Root15Journal -Root $journalRoot -Instance $android15
        $invalidJournal | Add-Member -NotePropertyName Extra -NotePropertyValue 'invalid'
        $rejectedJournal = Enable-Android15Root -Instance $android15 -Journal $invalidJournal -Runner (New-Root15ManagerRunner -State $invalidJournalState)
        Assert-Equal 'CriticalError' $rejectedJournal.Status 'An invalid journal was accepted.'
        Assert-Equal 'JOURNAL_INVALID' $rejectedJournal.Data.Code 'An invalid journal reported the wrong code.'
        Assert-Equal 0 @($invalidJournalState.Calls).Count 'An invalid journal reached the MuMu manager.'

        $foreignInstall = New-Root12InstallFixture -InstallRoot (Join-Path $root15Root 'Foreign MuMu') -SourceIndex 3
        $foreignInstance = New-Root15InstanceFixture -Install $install -AndroidVersion '15.0'
        $foreignInstance.Install.ManagerPath = $foreignInstall.ManagerPath
        $foreignState = New-Root15ManagerState -Install $install
        $foreignCase = Invoke-Root15Case -State $foreignState -Instance $foreignInstance -JournalRoot $journalRoot
        Assert-Root15Failure -Result $foreignCase.Result -Journal $foreignCase.Journal -Code 'MANAGER_UNAVAILABLE' -Message 'A manager outside its own install root was accepted.'
        Assert-Equal 0 @($foreignState.Calls).Count 'A manager outside its own install root was executed.'

        foreach ($cloneDefect in @(
                [pscustomobject]@{ Knob = 'CloneExitCode'; Value = 1; Label = 'a failed clone command' },
                [pscustomobject]@{ Knob = 'CloneCreatesDisk'; Value = $false; Label = 'a clone without a usable disk' },
                [pscustomobject]@{ Knob = 'CloneCreatesRecord'; Value = $false; Label = 'a clone the manager does not report' }
            )) {
            $cloneDefectState = New-Root15ManagerState -Install $install
            $cloneDefectState.($cloneDefect.Knob) = $cloneDefect.Value
            $cloneDefectCase = Invoke-Root15Case -State $cloneDefectState -Instance $android15 -JournalRoot $journalRoot
            Assert-Equal 'CriticalError' $cloneDefectCase.Result.Status "An unverified clone was accepted: $($cloneDefect.Label)."
            Assert-True (-not [string]::IsNullOrWhiteSpace([string]$cloneDefectCase.Result.Message)) "An unverified clone returned no reason: $($cloneDefect.Label)."
            Assert-Equal 'Failed' $cloneDefectCase.Journal.State "An unverified clone did not close the journal: $($cloneDefect.Label)."
            $reopenedCloneDefect = Get-OperationJournal -Path $cloneDefectCase.Journal.JournalPath
            Assert-Equal 'Failed' $reopenedCloneDefect.State "An unverified clone did not persist the failure: $($cloneDefect.Label)."
            Assert-Equal $cloneDefectCase.Result.Message $reopenedCloneDefect.Result.Message "An unverified clone returned a reason the journal does not hold: $($cloneDefect.Label)."
            Assert-Equal -1 (Get-Root15CallIndex -Calls $cloneDefectState.Calls -Pattern 'setting*') "An unverified clone still changed a setting: $($cloneDefect.Label)."
            Assert-Equal -1 (Get-Root15CallIndex -Calls $cloneDefectState.Calls -Pattern 'adb*') "An unverified clone still issued an ADB request: $($cloneDefect.Label)."
        }

        $successState = New-Root15ManagerState -Install $install
        $successCase = Invoke-Root15Case -State $successState -Instance $android15 -JournalRoot $journalRoot
        $success = $successCase.Result
        Assert-True ($success.Status -eq 'Success') "Android 15 root flow failed. $($success.Message)"
        Assert-Equal 'Completed' $successCase.Journal.State 'The Android 15 workflow did not complete its journal.'
        $reopenedSuccess = Get-OperationJournal -Path $successCase.Journal.JournalPath
        Assert-Equal 'Completed' $reopenedSuccess.State 'The Android 15 workflow did not persist its journal state.'
        Assert-Equal 'Success' $reopenedSuccess.Result.Status 'The Android 15 workflow did not persist its result.'
        Assert-Equal 'OK' $success.Data.Code 'The Android 15 workflow reported an invalid result code.'
        Assert-Equal $install.SourceIndex $success.Data.SourceIndex 'The Android 15 workflow reported the wrong source instance.'
        Assert-Equal $successState.CloneIndex $success.Data.CloneIndex 'The Android 15 workflow did not report the clone it rooted.'
        Assert-Equal $true $success.Data.RootPermission 'The Android 15 workflow did not verify the vendor root setting.'
        Assert-Equal $true $success.Data.KernelSU 'The Android 15 workflow did not verify the built-in KernelSU.'
        Assert-Equal $true $success.Data.RootShell 'The Android 15 workflow did not verify the root shell.'
        Assert-Equal $true $success.Data.KitsuneAbsent 'The Android 15 workflow did not verify that Kitsune is absent.'
        Assert-Equal '3.2.5' $success.Data.KernelSUVersion 'The Android 15 workflow did not record the built-in KernelSU version.'
        Assert-Equal $true $successState.RootSettings[[string]$successState.CloneIndex] 'The Android 15 workflow did not enable the vendor root on the clone.'

        $enableCalls = @(Get-Root15Calls -State $successState -Pattern 'setting*-v*-k*root_permission*-val*true*')
        Assert-Equal 1 $enableCalls.Count 'The Android 15 workflow did not enable root_permission exactly once.'
        $enableArguments = [string[]]@($enableCalls[0])
        Assert-Equal 7 $enableArguments.Count 'The root toggle request carried an unexpected argument count.'
        Assert-Equal ([string]$successState.CloneIndex) $enableArguments[2] 'The root toggle did not target the clone.'
        Assert-Equal 'root_permission' $enableArguments[4] 'The root toggle did not set root_permission.'
        Assert-Equal 'true' $enableArguments[6] 'The root toggle did not set the root value to true.'

        $launchCall = Get-Root15CallIndex -Calls $successState.Calls -Pattern 'control*-v*launch*'
        $enableCall = Get-Root15CallIndex -Calls $successState.Calls -Pattern 'setting*-val*true*'
        $bootCall = Get-Root15CallIndex -Calls $successState.Calls -Pattern '*getprop sys.boot_completed*'
        $kernelCall = Get-Root15CallIndex -Calls $successState.Calls -Pattern ('*dumpsys package ' + $script:Root15KernelSUPackage + '*')
        $rootShellCall = Get-Root15CallIndex -Calls $successState.Calls -Pattern '*su -c id*'
        $kitsuneCall = Get-Root15CallIndex -Calls $successState.Calls -Pattern '*pm list packages*'
        Assert-True ($enableCall -ge 0) 'The Android 15 workflow did not enable the vendor root.'
        Assert-True ($launchCall -gt $enableCall) 'The Android 15 workflow did not cold-boot after enabling the vendor root.'
        Assert-True ($bootCall -gt $launchCall) 'The Android 15 workflow did not wait for Android readiness after the cold boot.'
        Assert-True ($kernelCall -gt $bootCall) 'The Android 15 workflow verified KernelSU before Android was ready.'
        Assert-True ($rootShellCall -gt $kernelCall) 'The Android 15 workflow verified the root shell before the KernelSU package.'
        Assert-True ($kitsuneCall -gt $rootShellCall) 'The Android 15 workflow did not check for a Kitsune package after the root shell.'
        Assert-Equal 1 @(Get-Root15Calls -State $successState -Pattern 'clone*').Count 'The Android 15 workflow did not create exactly one clone.'
        Assert-Equal 0 @(Get-Root15Calls -State $successState -Pattern '*install*').Count 'The Android 15 workflow installed a package.'
        foreach ($verificationCall in @(Get-Root15Calls -State $successState -Pattern 'adb*')) {
            $verificationArguments = [string[]]@($verificationCall)
            Assert-Equal 5 $verificationArguments.Count 'An Android 15 ADB request carried more than one command element.'
            Assert-Equal 'adb' $verificationArguments[0] 'An Android 15 verification request is not an ADB request.'
            Assert-Equal ([string]$successState.CloneIndex) $verificationArguments[2] 'An Android 15 verification request did not target the clone.'
            Assert-Equal '-c' $verificationArguments[3] 'An Android 15 verification request lost its ADB command flag.'
            Assert-True ($verificationArguments[4] -notmatch '&') 'An Android 15 ADB request was shell-interpolated.'
        }
        foreach ($stateCall in $successState.Calls) {
            $stateArguments = @($stateCall)
            if ($stateArguments[0] -ceq 'setting' -or $stateArguments[0] -ceq 'adb') {
                Assert-True ([string]$stateArguments[2] -cne [string]$install.SourceIndex) 'A setting or ADB request acted on the selected source instance instead of the clone.'
            }
            if ($stateArguments[0] -ceq 'control' -and [string]$stateArguments[2] -ceq [string]$install.SourceIndex) {
                Assert-Equal 'shutdown' $stateArguments[3] 'A control request other than the clone shutdown acted on the selected source instance.'
            }
        }
        Assert-Equal 1 @(Get-Root15Calls -State $successState -Pattern ('control*-v*' + [string]$install.SourceIndex + ' shutdown*')).Count 'The Android 15 workflow did not stop the selected source instance exactly once for the clone.'
        Assert-Equal 1 @(Get-Root15Calls -State $successState -Pattern ('control*-v*' + [string]$successState.CloneIndex + ' launch*')).Count 'The Android 15 workflow did not cold-boot the clone exactly once.'
        Assert-Equal 0 @(Get-Root15Calls -State $successState -Pattern ('control*-v*' + [string]$install.SourceIndex + ' launch*')).Count 'The Android 15 workflow cold-booted the selected source instance.'

        $hypervisorPattern = '(?i)hyper-?v|vmmservice|bcdedit|windowsoptionalfeature|set-mppreference|memory\s*integrity|exploit\s*protection|virtual\s*machine\s*platform'
        $recordedCallText = (@($successState.Calls) | ForEach-Object { @($_) -join ' ' }) -join ' '
        Assert-Equal 0 @(Get-Root15Calls -State $successState -Pattern ('*' + $hypervisorPattern + '*')).Count 'Android 15 flow changed Hyper-V or VBS.'
        Assert-True ($recordedCallText -notmatch $hypervisorPattern) 'Android 15 flow issued a Hyper-V or VBS command.'

        Assert-True ($recordedCallText -notmatch '(?i)kitsune') 'Android 15 flow downloaded Kitsune.'
        Assert-Equal 0 @(Get-Root15Calls -State $successState -Pattern '*install -r*').Count 'Android 15 flow installed Kitsune.'
        Assert-Equal 0 @(Get-Root15Calls -State $successState -Pattern '*monkey*').Count 'Android 15 flow launched a root manager application.'
        $packageListCalls = @(Get-Root15Calls -State $successState -Pattern 'adb*-c shell pm list packages*')
        Assert-Equal 1 $packageListCalls.Count 'The Android 15 flow did not issue exactly one bare package list request.'
        $packageListArguments = [string[]]@($packageListCalls[0])
        Assert-Equal 5 $packageListArguments.Count 'The package list request carried an unexpected argument count.'
        Assert-Equal 'shell pm list packages' $packageListArguments[4] 'The package list request is not the bare unfiltered command.'

        $alreadyState = New-Root15ManagerState -Install $install
        $alreadyState.CloneRootSetting = $true
        $alreadyCase = Invoke-Root15Case -State $alreadyState -Instance $android15 -JournalRoot $journalRoot
        Assert-Equal 'AlreadyApplied' $alreadyCase.Result.Status "An already enabled vendor root was not reported as already applied. $($alreadyCase.Result.Message)"
        Assert-Equal 0 @(Get-Root15Calls -State $alreadyState -Pattern 'setting*-val*').Count 'An already enabled vendor root was written again.'
        Assert-True ((Get-Root15CallIndex -Calls $alreadyState.Calls -Pattern '*su -c id*') -ge 0) 'An already applied root was not verified.'
        Assert-Equal 'Completed' $alreadyCase.Journal.State 'The already applied root did not complete its journal.'
        $reopenedAlready = Get-OperationJournal -Path $alreadyCase.Journal.JournalPath
        Assert-Equal 'AlreadyApplied' $reopenedAlready.Result.Status 'The already applied root did not persist its status.'
        Assert-Equal $true $reopenedAlready.Result.Data.RootShell 'The already applied root did not persist the verified root shell.'

        $unverifiedAlreadyState = New-Root15ManagerState -Install $install
        $unverifiedAlreadyState.CloneRootSetting = $true
        $unverifiedAlreadyState.RootAllowed = $false
        $unverifiedAlreadyCase = Invoke-Root15Case -State $unverifiedAlreadyState -Instance $android15 -JournalRoot $journalRoot
        Assert-Root15Failure -Result $unverifiedAlreadyCase.Result -Journal $unverifiedAlreadyCase.Journal -Code 'ROOT_DENIED' -Message 'An already enabled vendor root with a denied root shell was reported as already applied.'
        Assert-Equal $false $unverifiedAlreadyCase.Result.Data.RootShell 'A denied root shell was reported as verified.'

        $unreportedAlreadyState = New-Root15ManagerState -Install $install
        $unreportedAlreadyState.CloneRootSetting = $true
        $unreportedAlreadyState.KernelSUInstalled = $false
        $unreportedAlreadyCase = Invoke-Root15Case -State $unreportedAlreadyState -Instance $android15 -JournalRoot $journalRoot
        Assert-Root15Failure -Result $unreportedAlreadyCase.Result -Journal $unreportedAlreadyCase.Journal -Code 'KERNELSU_ABSENT' -Message 'An already enabled vendor root without KernelSU was reported as already applied.'

        $unreadableSettingState = New-Root15ManagerState -Install $install
        $unreadableSettingState.RootSettingQueryExitCode = 1
        $unreadableSettingCase = Invoke-Root15Case -State $unreadableSettingState -Instance $android15 -JournalRoot $journalRoot
        Assert-Root15Failure -Result $unreadableSettingCase.Result -Journal $unreadableSettingCase.Journal -Code 'ROOT_SETTING_UNREADABLE' -Message 'An unreadable vendor root setting was accepted.'
        Assert-Equal -1 (Get-Root15CallIndex -Calls $unreadableSettingState.Calls -Pattern 'control*-v*launch*') 'An unreadable vendor root setting cold-booted the clone.'

        $blankSettingState = New-Root15ManagerState -Install $install
        $blankSettingState.RootSettingText = '   '
        $blankSettingCase = Invoke-Root15Case -State $blankSettingState -Instance $android15 -JournalRoot $journalRoot
        Assert-Root15Failure -Result $blankSettingCase.Result -Journal $blankSettingCase.Journal -Code 'ROOT_SETTING_UNREADABLE' -Message 'A blank vendor root setting response was accepted.'

        $unsupportedSettingState = New-Root15ManagerState -Install $install
        $unsupportedSettingState.RootSettingText = '{"error_code":0,"unexpected":"value"}'
        $unsupportedSettingCase = Invoke-Root15Case -State $unsupportedSettingState -Instance $android15 -JournalRoot $journalRoot
        Assert-Root15Failure -Result $unsupportedSettingCase.Result -Journal $unsupportedSettingCase.Journal -Code 'ROOT_SETTING_UNREADABLE' -Message 'A vendor root setting response with no supported field was accepted.'

        $failedSettingState = New-Root15ManagerState -Install $install
        $failedSettingState.RootSettingText = '{"error_code":1}'
        $failedSettingCase = Invoke-Root15Case -State $failedSettingState -Instance $android15 -JournalRoot $journalRoot
        Assert-Root15Failure -Result $failedSettingCase.Result -Journal $failedSettingCase.Journal -Code 'ROOT_SETTING_UNREADABLE' -Message 'A manager error for the vendor root setting was accepted.'

        $invalidSettingState = New-Root15ManagerState -Install $install
        $invalidSettingState.RootSettingText = '{"root_permission":"maybe"}'
        $invalidSettingCase = Invoke-Root15Case -State $invalidSettingState -Instance $android15 -JournalRoot $journalRoot
        Assert-Root15Failure -Result $invalidSettingCase.Result -Journal $invalidSettingCase.Journal -Code 'ROOT_SETTING_UNREADABLE' -Message 'An unusable vendor root setting value was accepted.'

        $foreignSettingState = New-Root15ManagerState -Install $install
        $foreignSettingState.RootSettingIndex = '9'
        $foreignSettingCase = Invoke-Root15Case -State $foreignSettingState -Instance $android15 -JournalRoot $journalRoot
        Assert-Root15Failure -Result $foreignSettingCase.Result -Journal $foreignSettingCase.Journal -Code 'ROOT_SETTING_UNREADABLE' -Message 'A vendor root setting that described another instance was accepted.'
        Assert-Equal -1 (Get-Root15CallIndex -Calls $foreignSettingState.Calls -Pattern 'setting*-val*') 'A vendor root setting for another instance was trusted for a write.'
        Assert-Equal -1 (Get-Root15CallIndex -Calls $foreignSettingState.Calls -Pattern 'control*-v*launch*') 'A vendor root setting for another instance was trusted before a cold boot.'
        Assert-Equal -1 (Get-Root15CallIndex -Calls $foreignSettingState.Calls -Pattern 'adb*') 'A vendor root setting for another instance was trusted before a verification.'

        $foreignSettingVerifiedState = New-Root15ManagerState -Install $install
        $foreignSettingVerifiedState.RootSettings[[string]$foreignSettingVerifiedState.CloneIndex] = $true
        $foreignSettingVerifiedState.RootSettingIndex = '9'
        $foreignSettingVerified = Test-Android15Root -ManagerPath $install.ManagerPath -InstanceIndex 7 -Runner (New-Root15ManagerRunner -State $foreignSettingVerifiedState)
        Assert-Equal 'CriticalError' $foreignSettingVerified.Status 'The Android 15 root checks accepted a vendor root setting for another instance.'
        Assert-Equal 'ROOT_SETTING_UNREADABLE' $foreignSettingVerified.Data.Code 'A vendor root setting for another instance reported the wrong code.'
        Assert-Equal $false $foreignSettingVerified.Data.RootPermission 'A vendor root setting for another instance was reported as verified.'
        Assert-Equal 0 @(Get-Root15Calls -State $foreignSettingVerifiedState -Pattern 'adb*').Count 'A vendor root setting for another instance still issued an ADB request.'

        $matchingIndexState = New-Root15ManagerState -Install $install
        $matchingIndexState.RootSettings[[string]$matchingIndexState.CloneIndex] = $true
        $matchingIndexState.RootSettingIndex = [string]$matchingIndexState.CloneIndex
        $matchingIndex = Get-ToolkitRootSetting -ManagerPath $install.ManagerPath -Index $matchingIndexState.CloneIndex -Runner (New-Root15ManagerRunner -State $matchingIndexState)
        Assert-Equal 'Success' $matchingIndex.Status 'A vendor root setting that named the requested instance was refused.'
        Assert-Equal $true $matchingIndex.Data.Value 'A matching vendor root setting reported the wrong value.'

        $foreignIndexState = New-Root15ManagerState -Install $install
        $foreignIndexState.RootSettingIndex = '9'
        $foreignIndex = Get-ToolkitRootSetting -ManagerPath $install.ManagerPath -Index $foreignIndexState.CloneIndex -Runner (New-Root15ManagerRunner -State $foreignIndexState)
        Assert-Equal 'CriticalError' $foreignIndex.Status 'The shared vendor root reader accepted a response naming another instance.'
        Assert-Equal 'INDEX_MISMATCH' $foreignIndex.Data.Code 'The shared vendor root reader reported the wrong code for another instance.'

        $toggleFailureState = New-Root15ManagerState -Install $install
        $toggleFailureState.RootSettingExitCode = 1
        $toggleFailureCase = Invoke-Root15Case -State $toggleFailureState -Instance $android15 -JournalRoot $journalRoot
        Assert-Root15Failure -Result $toggleFailureCase.Result -Journal $toggleFailureCase.Journal -Code 'ROOT_TOGGLE_FAILED' -Message 'A missing root toggle was accepted.'
        Assert-Equal -1 (Get-Root15CallIndex -Calls $toggleFailureState.Calls -Pattern 'control*-v*launch*') 'A failed root toggle cold-booted the clone.'
        Assert-Equal -1 (Get-Root15CallIndex -Calls $toggleFailureState.Calls -Pattern 'adb*') 'A failed root toggle issued an ADB request.'

        $unreportedToggleState = New-Root15ManagerState -Install $install
        $unreportedToggleState.IgnoreRootEnable = $true
        $unreportedToggleCase = Invoke-Root15Case -State $unreportedToggleState -Instance $android15 -JournalRoot $journalRoot
        Assert-Root15Failure -Result $unreportedToggleCase.Result -Journal $unreportedToggleCase.Journal -Code 'ROOT_NOT_ENABLED' -Message 'A vendor root change the clone did not report was accepted.'
        Assert-Equal $false $unreportedToggleCase.Result.Data.RootPermission 'An unreported vendor root was reported as enabled.'
        Assert-Equal -1 (Get-Root15CallIndex -Calls $unreportedToggleState.Calls -Pattern 'control*-v*launch*') 'An unreported vendor root cold-booted the clone.'

        $controlFailureState = New-Root15ManagerState -Install $install
        $controlFailureState.ControlFailPattern = 'control*-v*launch*'
        $controlFailureCase = Invoke-Root15Case -State $controlFailureState -Instance $android15 -JournalRoot $journalRoot
        Assert-Root15Failure -Result $controlFailureCase.Result -Journal $controlFailureCase.Journal -Code 'BOOT_CONTROL_FAILED' -Message 'A failed cold-boot launch was accepted.'
        Assert-Equal -1 (Get-Root15CallIndex -Calls $controlFailureState.Calls -Pattern '*getprop sys.boot_completed*') 'A failed cold-boot launch waited for Android readiness.'
        Assert-Equal -1 (Get-Root15CallIndex -Calls $controlFailureState.Calls -Pattern 'adb*') 'A failed cold-boot launch issued an ADB request.'

        $bootTimeoutState = New-Root15ManagerState -Install $install
        $bootTimeoutState.BootReadyPolls = 99
        $bootTimeoutCase = Invoke-Root15Case -State $bootTimeoutState -Instance $android15 -JournalRoot $journalRoot
        Assert-Root15Failure -Result $bootTimeoutCase.Result -Journal $bootTimeoutCase.Journal -Code 'BOOT_TIMEOUT' -Message 'A failed boot was accepted.'
        Assert-True ($bootTimeoutCase.Result.Message -match '2 checks') 'The boot timeout did not report the number of checks.'
        Assert-Equal -1 (Get-Root15CallIndex -Calls $bootTimeoutState.Calls -Pattern '*dumpsys package*') 'A failed boot verified the KernelSU package.'
        Assert-Equal -1 (Get-Root15CallIndex -Calls $bootTimeoutState.Calls -Pattern '*su -c id*') 'A failed boot verified the root shell.'

        foreach ($missingRootCase in @(
                [pscustomobject]@{ Knob = 'KernelSUInstalled'; Value = $false; Code = 'KERNELSU_ABSENT'; Field = 'KernelSU'; Label = 'absent KernelSU' },
                [pscustomobject]@{ Knob = 'KernelSUVersionName'; Value = ''; Code = 'KERNELSU_ABSENT'; Field = 'KernelSU'; Label = 'a KernelSU package with no reported version' },
                [pscustomobject]@{ Knob = 'RootAllowed'; Value = $false; Code = 'ROOT_DENIED'; Field = 'RootShell'; Label = 'a denied root shell' },
                [pscustomobject]@{ Knob = 'RootShellText'; Value = 'uid=2000(shell) gid=2000(shell) groups=2000(shell)'; Code = 'ROOT_DENIED'; Field = 'RootShell'; Label = 'a non-root shell identity' },
                [pscustomobject]@{ Knob = 'KitsuneInstalled'; Value = $true; Code = 'KITSUNE_PRESENT'; Field = 'KitsuneAbsent'; Label = 'a pre-existing Kitsune package' }
            )) {
            $missingRootState = New-Root15ManagerState -Install $install
            $missingRootState.($missingRootCase.Knob) = $missingRootCase.Value
            $missingRootCase15 = Invoke-Root15Case -State $missingRootState -Instance $android15 -JournalRoot $journalRoot
            Assert-Root15Failure -Result $missingRootCase15.Result -Journal $missingRootCase15.Journal -Code $missingRootCase.Code -Message "An unverified Android 15 root was accepted: $($missingRootCase.Label)."
            Assert-Equal $false $missingRootCase15.Result.Data.($missingRootCase.Field) "An unverified Android 15 root reported a verified field: $($missingRootCase.Label)."
        }

        $relatedPackageState = New-Root15ManagerState -Install $install
        $relatedPackageState.RelatedPackageName = 'io.github.huskydg.magisk.beta'
        $relatedPackageCase = Invoke-Root15Case -State $relatedPackageState -Instance $android15 -JournalRoot $journalRoot
        Assert-Equal 'Success' $relatedPackageCase.Result.Status "An unrelated package name was reported as Kitsune. $($relatedPackageCase.Result.Message)"
        Assert-Equal $true $relatedPackageCase.Result.Data.KitsuneAbsent 'An unrelated package name was reported as an installed Kitsune package.'

        $relatedSuffixState = New-Root15ManagerState -Install $install
        $relatedSuffixState.RelatedPackageName = 'io.github.huskydg.magiskx'
        $relatedSuffixCase = Invoke-Root15Case -State $relatedSuffixState -Instance $android15 -JournalRoot $journalRoot
        Assert-Equal 'Success' $relatedSuffixCase.Result.Status 'A package name sharing the Kitsune prefix was reported as Kitsune.'
        $relatedPrefixState = New-Root15ManagerState -Install $install
        $relatedPrefixState.RelatedPackageName = 'io.github.huskydg'
        $relatedPrefixCase = Invoke-Root15Case -State $relatedPrefixState -Instance $android15 -JournalRoot $journalRoot
        Assert-Equal 'Success' $relatedPrefixCase.Result.Status 'A package name contained in the Kitsune package was reported as Kitsune.'

        foreach ($unusableList in @(
                [pscustomobject]@{ Text = 'Usage: pm list packages [FILTER]'; Label = 'a usage string' },
                [pscustomobject]@{ Text = 'Error: unknown command'; Label = 'an error string' },
                [pscustomobject]@{ Text = ('package:com.android.settings' + [Environment]::NewLine + 'Usage: pm list packages [FILTER]'); Label = 'a mixed list and usage string' },
                [pscustomobject]@{ Text = ('package:com.android.settings' + [Environment]::NewLine + 'package: ' + [char]0); Label = 'a malformed package line' }
            )) {
            $unusableListState = New-Root15ManagerState -Install $install
            $unusableListState.PackageListText = $unusableList.Text
            $unusableListCase = Invoke-Root15Case -State $unusableListState -Instance $android15 -JournalRoot $journalRoot
            Assert-Root15Failure -Result $unusableListCase.Result -Journal $unusableListCase.Journal -Code 'ADB_FAILED' -Message "A Kitsune absence check accepted $($unusableList.Label)."
            Assert-Equal $false $unusableListCase.Result.Data.KitsuneAbsent "A Kitsune absence check reported absence from $($unusableList.Label)."
        }

        foreach ($nearKernelSU in @(
                [pscustomobject]@{ Header = 'me.weishu.kernelsu.beta'; Label = 'a longer package name' },
                [pscustomobject]@{ Header = 'me.weishu.kernelsux'; Label = 'a longer package name suffix' },
                [pscustomobject]@{ Header = 'me.weishu'; Label = 'a shorter package name' }
            )) {
            $nearKernelSUState = New-Root15ManagerState -Install $install
            $nearKernelSUState.KernelSUHeaderName = $nearKernelSU.Header
            $nearKernelSUCase = Invoke-Root15Case -State $nearKernelSUState -Instance $android15 -JournalRoot $journalRoot
            Assert-Root15Failure -Result $nearKernelSUCase.Result -Journal $nearKernelSUCase.Journal -Code 'KERNELSU_ABSENT' -Message "The built-in KernelSU check accepted $($nearKernelSU.Label) as the KernelSU package."
            Assert-Equal $false $nearKernelSUCase.Result.Data.KernelSU "The built-in KernelSU check reported $($nearKernelSU.Label) as verified."
            Assert-Equal '' $nearKernelSUCase.Result.Data.KernelSUVersion "The built-in KernelSU check recorded a version from $($nearKernelSU.Label)."
        }

        $multiBlockKernelSUState = New-Root15ManagerState -Install $install
        $multiBlockKernelSUState.KernelSUExtraBlock = ('Package [me.weishu.kernelsu.beta] (ff00ff):' + [Environment]::NewLine + '    versionCode=99999 minSdk=28' + [Environment]::NewLine + '    versionName=9.9.9')
        $multiBlockKernelSUCase = Invoke-Root15Case -State $multiBlockKernelSUState -Instance $android15 -JournalRoot $journalRoot
        Assert-Equal 'Success' $multiBlockKernelSUCase.Result.Status "A multi-block package response failed the Android 15 flow. $($multiBlockKernelSUCase.Result.Message)"
        Assert-Equal $true $multiBlockKernelSUCase.Result.Data.KernelSU 'A multi-block package response hid the built-in KernelSU package.'
        Assert-Equal '3.2.5' $multiBlockKernelSUCase.Result.Data.KernelSUVersion 'The Android 15 flow recorded a KernelSU version from the near-name block.'

        $multiBlockKernelSUTrailingState = New-Root15ManagerState -Install $install
        $multiBlockKernelSUTrailingState.KernelSUVersionName = '4.0.0'
        $multiBlockKernelSUTrailingState.KernelSUExtraBlock = ('Package [me.weishu.kernelsu.beta] (ff00ff):' + [Environment]::NewLine + '    versionCode=99999 minSdk=28' + [Environment]::NewLine + '    versionName=9.9.9')
        $multiBlockKernelSUTrailingCase = Invoke-Root15Case -State $multiBlockKernelSUTrailingState -Instance $android15 -JournalRoot $journalRoot
        Assert-Equal 'Success' $multiBlockKernelSUTrailingCase.Result.Status "A multi-block package response failed the Android 15 flow. $($multiBlockKernelSUTrailingCase.Result.Message)"
        Assert-Equal '4.0.0' $multiBlockKernelSUTrailingCase.Result.Data.KernelSUVersion 'The Android 15 flow recorded a KernelSU version from the wrong block.'

        foreach ($adbFailureCase in @(
                [pscustomobject]@{ Pattern = '*dumpsys package*'; Code = 'ADB_FAILED'; Label = 'the KernelSU package query' },
                [pscustomobject]@{ Pattern = '*pm list packages*'; Code = 'ADB_FAILED'; Label = 'the Kitsune package query' },
                [pscustomobject]@{ Pattern = '*su -c id*'; Code = 'ROOT_DENIED'; Label = 'the root shell query' }
            )) {
            $adbFailureState = New-Root15ManagerState -Install $install
            $adbFailureState.AdbFailPattern = $adbFailureCase.Pattern
            $adbFailureCase15 = Invoke-Root15Case -State $adbFailureState -Instance $android15 -JournalRoot $journalRoot
            Assert-Root15Failure -Result $adbFailureCase15.Result -Journal $adbFailureCase15.Journal -Code $adbFailureCase.Code -Message "A failed ADB request was accepted: $($adbFailureCase.Label)."
        }

        foreach ($transportCase in @(
                [pscustomobject]@{ Knob = 'AdbThrowPattern'; Value = '*su -c id*'; Label = 'a root shell query that could not be executed' },
                [pscustomobject]@{ Knob = 'AdbThrowPattern'; Value = '*dumpsys package*'; Label = 'a KernelSU query that could not be executed' },
                [pscustomobject]@{ Knob = 'AdbThrowPattern'; Value = '*pm list packages*'; Label = 'a package list query that could not be executed' },
                [pscustomobject]@{ Knob = 'AdbBlankFailPattern'; Value = '*su -c id*'; Label = 'a root shell query that returned no guest output' }
            )) {
            $transportState = New-Root15ManagerState -Install $install
            $transportState.($transportCase.Knob) = $transportCase.Value
            $transportCase15 = Invoke-Root15Case -State $transportState -Instance $android15 -JournalRoot $journalRoot
            Assert-Root15Failure -Result $transportCase15.Result -Journal $transportCase15.Journal -Code 'ADB_FAILED' -Message "An ADB transport failure was misreported: $($transportCase.Label)."
        }

        $blankShellState = New-Root15ManagerState -Install $install
        $blankShellState.RootShellText = '   '
        $blankShellCase = Invoke-Root15Case -State $blankShellState -Instance $android15 -JournalRoot $journalRoot
        Assert-Root15Failure -Result $blankShellCase.Result -Journal $blankShellCase.Journal -Code 'ROOT_DENIED' -Message 'A root shell that reported nothing was accepted.'

        foreach ($journalCase in @(
                [pscustomobject]@{ Pattern = 'setting*-val*true*'; Label = 'vendor root checkpoint' },
                [pscustomobject]@{ Pattern = 'control*-v*launch*'; Label = 'cold boot checkpoint' },
                [pscustomobject]@{ Pattern = '*su -c id*'; Label = 'root check checkpoint' }
            )) {
            $journalState = New-Root15ManagerState -Install $install
            $journalCase15Journal = New-Root15Journal -Root $journalRoot -Instance $android15
            $journalState.JournalLockPath = $journalCase15Journal.JournalPath
            $journalState.JournalLockPattern = $journalCase.Pattern
            try {
                $journalCase15 = Enable-Android15Root -Instance $android15 -Journal $journalCase15Journal -Confirmed -Runner (New-Root15ManagerRunner -State $journalState)
            }
            finally {
                Release-Root15JournalLock -State $journalState
            }
            Assert-Equal 'CriticalError' $journalCase15.Status "A journal write failure was not reported: $($journalCase.Label)"
            Assert-Equal 'JOURNAL_WRITE_FAILED' $journalCase15.Data.Code "A journal write failure reported the wrong code: $($journalCase.Label)"
            Assert-True ($journalCase15.Message -match '(?i)journal') "A journal write failure did not mention the journal: $($journalCase.Label)"
        }

        $preLockedState = New-Root15ManagerState -Install $install
        $preLockedJournal = New-Root15Journal -Root $journalRoot -Instance $android15
        $preLockedState.JournalLock = [IO.File]::Open($preLockedJournal.JournalPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        try {
            $preLocked = Enable-Android15Root -Instance $android15 -Journal $preLockedJournal -Confirmed -Runner (New-Root15ManagerRunner -State $preLockedState)
        }
        finally {
            Release-Root15JournalLock -State $preLockedState
        }
        Assert-Equal 'CriticalError' $preLocked.Status 'A locked journal did not fail the workflow.'
        Assert-Equal 'JOURNAL_WRITE_FAILED' $preLocked.Data.Code 'A locked journal reported the wrong code.'
        Assert-Equal 0 @($preLockedState.Calls).Count 'A locked journal still reached the MuMu manager.'
        Assert-Equal 'Running' $preLockedJournal.State 'An unjournalable failure changed the in-memory journal state.'

        $verifyState = New-Root15ManagerState -Install $install
        $verifyState.RootSettings[[string]$successState.CloneIndex] = $true
        $verifyChecks = Test-Android15Root -ManagerPath $install.ManagerPath -InstanceIndex $successState.CloneIndex -Runner (New-Root15ManagerRunner -State $verifyState)
        Assert-Equal 'Success' $verifyChecks.Status "The Android 15 root checks failed. $($verifyChecks.Message)"
        Assert-Equal 'OK' $verifyChecks.Data.Code 'The Android 15 root checks reported an invalid code.'
        Assert-Equal $true $verifyChecks.Data.RootPermission 'The Android 15 root checks did not report the vendor root setting.'
        Assert-Equal $true $verifyChecks.Data.KernelSU 'The Android 15 root checks did not report the built-in KernelSU.'
        Assert-Equal $true $verifyChecks.Data.RootShell 'The Android 15 root checks did not report the root shell.'
        Assert-Equal $true $verifyChecks.Data.KitsuneAbsent 'The Android 15 root checks did not report the absent Kitsune package.'
        Assert-Equal '3.2.5' $verifyChecks.Data.KernelSUVersion 'The Android 15 root checks did not report the built-in KernelSU version.'
        Assert-Equal 3 @(Get-Root15Calls -State $verifyState -Pattern 'adb*').Count 'The Android 15 root checks made an unexpected number of ADB requests.'
        Assert-Equal 1 @(Get-Root15Calls -State $verifyState -Pattern 'setting*').Count 'The Android 15 root checks made an unexpected number of setting queries.'
        Assert-Equal 0 @(Get-Root15Calls -State $verifyState -Pattern 'control*').Count 'The Android 15 root checks controlled the instance.'

        $verifyFalseState = New-Root15ManagerState -Install $install
        $verifyFalseState.RootSettings[[string]$successState.CloneIndex] = $false
        $verifyFalseChecks = Test-Android15Root -ManagerPath $install.ManagerPath -InstanceIndex $successState.CloneIndex -Runner (New-Root15ManagerRunner -State $verifyFalseState)
        Assert-Equal 'CriticalError' $verifyFalseChecks.Status 'A disabled vendor root setting was accepted.'
        Assert-Equal 'ROOT_NOT_ENABLED' $verifyFalseChecks.Data.Code 'A disabled vendor root setting reported the wrong code.'
        Assert-Equal $false $verifyFalseChecks.Data.RootPermission 'A disabled vendor root setting was reported as enabled.'
        Assert-Equal 0 @(Get-Root15Calls -State $verifyFalseState -Pattern 'adb*').Count 'A disabled vendor root setting issued an ADB request.'

        $verifyUnreadableState = New-Root15ManagerState -Install $install
        $verifyUnreadableState.RootSettingQueryExitCode = 1
        $verifyUnreadableChecks = Test-Android15Root -ManagerPath $install.ManagerPath -InstanceIndex $successState.CloneIndex -Runner (New-Root15ManagerRunner -State $verifyUnreadableState)
        Assert-Equal 'CriticalError' $verifyUnreadableChecks.Status 'An unreadable vendor root setting was accepted by the checks.'
        Assert-Equal 'ROOT_SETTING_UNREADABLE' $verifyUnreadableChecks.Data.Code 'An unreadable vendor root setting reported the wrong code.'

        $blankManagerState = New-Root15ManagerState -Install $install
        $blankManagerChecks = Test-Android15Root -ManagerPath '   ' -InstanceIndex $successState.CloneIndex -Runner (New-Root15ManagerRunner -State $blankManagerState)
        Assert-Equal 'CriticalError' $blankManagerChecks.Status 'A blank manager was accepted for root verification.'
        Assert-Equal 'MANAGER_UNAVAILABLE' $blankManagerChecks.Data.Code 'A blank manager was not reported as unavailable.'
        Assert-Equal 0 @($blankManagerState.Calls).Count 'A blank manager reached the process runner.'

        $negativeIndexState = New-Root15ManagerState -Install $install
        $negativeIndexChecks = Test-Android15Root -ManagerPath $install.ManagerPath -InstanceIndex -1 -Runner (New-Root15ManagerRunner -State $negativeIndexState)
        Assert-Equal 'CriticalError' $negativeIndexChecks.Status 'A negative instance index was accepted for root verification.'
        Assert-Equal 'MANAGER_UNAVAILABLE' $negativeIndexChecks.Data.Code 'A negative instance index reported the wrong code.'
        Assert-Equal 0 @($negativeIndexState.Calls).Count 'A negative instance index reached the process runner.'

        $deniedVerifyState = New-Root15ManagerState -Install $install
        $deniedVerifyState.RootSettings[[string]$successState.CloneIndex] = $true
        $deniedVerifyState.RootAllowed = $false
        $deniedVerifyChecks = Test-Android15Root -ManagerPath $install.ManagerPath -InstanceIndex $successState.CloneIndex -Runner (New-Root15ManagerRunner -State $deniedVerifyState)
        Assert-Equal 'CriticalError' $deniedVerifyChecks.Status 'A denied root shell was accepted by the root checks.'
        Assert-Equal 'ROOT_DENIED' $deniedVerifyChecks.Data.Code 'A denied root shell was not reported as a denial.'
        Assert-Equal $false $deniedVerifyChecks.Data.RootShell 'A denied root shell was reported as verified.'
        Assert-Equal $true $deniedVerifyChecks.Data.KernelSU 'A denied root shell discarded the verified KernelSU result.'

        $versionDeniedState = New-Root15ManagerState -Install $install
        $versionDeniedState.RootSettings[[string]$successState.CloneIndex] = $true
        $versionDeniedState.KernelSUInstalled = $false
        $versionDeniedChecks = Test-Android15Root -ManagerPath $install.ManagerPath -InstanceIndex $successState.CloneIndex -Runner (New-Root15ManagerRunner -State $versionDeniedState)
        Assert-Equal 'CriticalError' $versionDeniedChecks.Status 'An absent KernelSU package was accepted by the root checks.'
        Assert-Equal 'KERNELSU_ABSENT' $versionDeniedChecks.Data.Code 'An absent KernelSU package reported the wrong code.'
        Assert-Equal $false $versionDeniedChecks.Data.KernelSU 'An absent KernelSU package was reported as verified.'

        $journalSuccessText = ([string](@($reopenedSuccess.Checkpoints) | ForEach-Object { $_.Message }) -join ' ')
        Assert-True ($journalSuccessText -match 'clone') 'The verified clone was not journaled.'
        Assert-True ($journalSuccessText -match 'root') 'The vendor root change was not journaled.'
        Assert-True ($journalSuccessText -match 'KernelSU') 'The built-in KernelSU verification was not journaled.'
        $persistedSuccessData = $reopenedSuccess.Result.Data
        Assert-Equal $true $persistedSuccessData.RootPermission 'The persisted result lost the vendor root setting field.'
        Assert-Equal $true $persistedSuccessData.KernelSU 'The persisted result lost the KernelSU field.'
        Assert-Equal $true $persistedSuccessData.RootShell 'The persisted result lost the root shell field.'
        Assert-Equal $true $persistedSuccessData.KitsuneAbsent 'The persisted result lost the absent Kitsune field.'
    }
    finally {
        if ($null -ne $bootAttemptsVariable) {
            $script:ToolkitBootPollAttempts = $bootAttemptsVariable.Value
        }
        if ($null -ne $bootDelayVariable) {
            $script:ToolkitBootPollDelaySeconds = $bootDelayVariable.Value
        }
    }
}

function Invoke-VerificationTests {
    foreach ($commandName in @('Invoke-ToolkitManagerAdb', 'Wait-ToolkitBootCompleted', 'Get-ToolkitRootSetting', 'Get-ToolkitPackageVersion', 'Get-ToolkitRootShellStatus', 'New-ToolkitRootFailure')) {
        Assert-True ($null -ne (Get-Command $commandName -CommandType Function -ErrorAction SilentlyContinue)) "Shared verification command is unavailable: $commandName"
    }
    Assert-True (Test-Path -LiteralPath $verificationScriptPath -PathType Leaf) 'src/Verification.ps1 does not exist.'
    Assert-True (Test-Path -LiteralPath $root12ScriptPath -PathType Leaf) 'src/Root12.ps1 does not exist.'
    Assert-True (Test-Path -LiteralPath $root15ScriptPath -PathType Leaf) 'src/Root15.ps1 does not exist.'

    $verificationSource = [IO.File]::ReadAllText($verificationScriptPath)
    Assert-True ($verificationSource -notmatch "'UNKNOWN'") 'The shared verification source reports an UNKNOWN failure code.'
    foreach ($forbidden in @(
            'Invoke-Expression',
            'ScriptBlock]::Create',
            'Add-Type',
            'Start-Process',
            'Invoke-WebRequest',
            'Invoke-RestMethod',
            'WebClient',
            'schtasks',
            'Set-ExecutionPolicy',
            'icacls',
            'Set-Acl',
            'New-NetFirewallRule',
            'Set-NetFirewallProfile',
            'EnableLUA',
            'Set-MpPreference',
            'Disable-WindowsOptionalFeature',
            'Enable-WindowsOptionalFeature',
            'bcdedit',
            'vmmservice',
            'hypervisorlaunchtype'
        )) {
        Assert-True ($verificationSource -notmatch [regex]::Escape($forbidden)) "Shared verification source uses a forbidden construct: $forbidden"
    }
    Assert-True ($verificationSource -notmatch '(?i)hyper-?v|memory\s*integrity|exploit\s*protection|credential\s*guard') 'The shared verification source mentions a Hyper-V, VBS, or memory integrity control.'

    $root12Source = [IO.File]::ReadAllText($root12ScriptPath)
    foreach ($removedHelper in @('function Invoke-Android12Adb', 'function Wait-Android12BootCompleted', 'function Get-Android12RootSetting', 'function New-Android12RootFailure', 'ToolkitBootPollAttempts =', 'ToolkitBootPollDelaySeconds =')) {
        Assert-True ($root12Source -notmatch [regex]::Escape($removedHelper)) "The Android 12 flow still defines its own copy: $removedHelper"
    }
    $root15Source = [IO.File]::ReadAllText($root15ScriptPath)
    foreach ($removedHelper in @('ToolkitBootPollAttempts =', 'ToolkitBootPollDelaySeconds =')) {
        Assert-True ($root15Source -notmatch [regex]::Escape($removedHelper)) "The Android 15 flow still defines its own copy: $removedHelper"
    }
    foreach ($sharedPrimitive in @('Invoke-ToolkitManagerAdb', 'Wait-ToolkitBootCompleted', 'Get-ToolkitRootSetting', 'Get-ToolkitPackageVersion', 'New-ToolkitRootFailure')) {
        Assert-True ($root12Source -match [regex]::Escape($sharedPrimitive)) "The Android 12 flow does not use the shared primitive: $sharedPrimitive"
    }

    $sharedState = @{
        Calls = @()
        Polls = 0
        SettingText = '{"root_permission":"true"}'
    }
    $recordingRunner = {
        param($ActualFilePath, $ActualArgumentList)
        $sharedState.Calls += ,@($ActualArgumentList)
        [pscustomobject]@{ ExitCode = 0; Text = 'ok' }
    }.GetNewClosure()
    $adbResult = Invoke-ToolkitManagerAdb -ManagerPath 'C:\MuMu\shell\MuMuManager.exe' -InstanceIndex 7 -Command 'shell getprop sys.boot_completed' -Runner $recordingRunner
    Assert-Equal 0 $adbResult.ExitCode 'The shared ADB helper did not return the runner result.'
    Assert-Equal 1 $sharedState.Calls.Count 'The shared ADB helper issued an unexpected number of requests.'
    $adbArguments = [string[]]@($sharedState.Calls[0])
    Assert-Equal 5 $adbArguments.Count 'The shared ADB helper carried an unexpected argument count.'
    Assert-Equal 'adb' $adbArguments[0] 'The shared ADB helper did not issue an ADB request.'
    Assert-Equal '-v' $adbArguments[1] 'The shared ADB helper lost the instance flag.'
    Assert-Equal '7' $adbArguments[2] 'The shared ADB helper lost the instance index.'
    Assert-Equal '-c' $adbArguments[3] 'The shared ADB helper lost its command flag.'
    Assert-Equal 'shell getprop sys.boot_completed' $adbArguments[4] 'The shared ADB helper changed the command element.'

    $bootAttemptsVariable = Get-Variable -Name 'ToolkitBootPollAttempts' -Scope Script -ErrorAction SilentlyContinue
    $bootDelayVariable = Get-Variable -Name 'ToolkitBootPollDelaySeconds' -Scope Script -ErrorAction SilentlyContinue
    $script:ToolkitBootPollAttempts = 2
    $script:ToolkitBootPollDelaySeconds = 0
    try {
        $readyRunner = {
            param($ActualFilePath, $ActualArgumentList)
            [pscustomobject]@{ ExitCode = 0; Text = '1' }
        }.GetNewClosure()
        Assert-True (Wait-ToolkitBootCompleted -ManagerPath 'C:\MuMu\shell\MuMuManager.exe' -InstanceIndex 7 -Runner $readyRunner) 'The shared boot wait did not report a ready instance.'
        $notReadyRunner = {
            param($ActualFilePath, $ActualArgumentList)
            $sharedState.Polls++
            [pscustomobject]@{ ExitCode = 0; Text = '0' }
        }.GetNewClosure()
        $sharedState.Polls = 0
        Assert-True (-not (Wait-ToolkitBootCompleted -ManagerPath 'C:\MuMu\shell\MuMuManager.exe' -InstanceIndex 7 -Runner $notReadyRunner)) 'The shared boot wait reported a ready instance that never booted.'
        Assert-Equal 2 $sharedState.Polls 'The shared boot wait did not stop at its poll bound.'
        $throwingRunner = { param($ActualFilePath, $ActualArgumentList) throw 'transport failure' }.GetNewClosure()
        Assert-True (-not (Wait-ToolkitBootCompleted -ManagerPath 'C:\MuMu\shell\MuMuManager.exe' -InstanceIndex 7 -Runner $throwingRunner)) 'The shared boot wait reported a ready instance whose transport failed.'
    }
    finally {
        if ($null -ne $bootAttemptsVariable) {
            $script:ToolkitBootPollAttempts = $bootAttemptsVariable.Value
        }
        if ($null -ne $bootDelayVariable) {
            $script:ToolkitBootPollDelaySeconds = $bootDelayVariable.Value
        }
    }

    $packageText = 'Package [me.weishu.kernelsu] (a1b2c3):' + [Environment]::NewLine + '    versionCode=30205 minSdk=28' + [Environment]::NewLine + '    versionName=3.2.5'
    $packageFields = Get-ToolkitPackageVersion -Text $packageText -PackageName 'me.weishu.kernelsu'
    Assert-True ($null -ne $packageFields) 'The shared package reader refused an exact package header.'
    Assert-Equal '3.2.5' $packageFields.VersionName 'The shared package reader reported the wrong version name.'
    Assert-Equal '30205' $packageFields.VersionCode 'The shared package reader reported the wrong version code.'
    foreach ($nearName in @('me.weishu.kernelsu.beta', 'me.weishu.kernelsux', 'me.weishu', 'io.github.huskydg.magisk', 'me.weishu.kernelsu2')) {
        Assert-True ($null -eq (Get-ToolkitPackageVersion -Text $packageText -PackageName $nearName)) "The shared package reader accepted a different package as $nearName."
    }
    Assert-True ($null -eq (Get-ToolkitPackageVersion -Text ('Unable to find package: me.weishu.kernelsu.') -PackageName 'me.weishu.kernelsu')) 'The shared package reader accepted an absent package.'
    Assert-True ($null -eq (Get-ToolkitPackageVersion -Text '' -PackageName 'me.weishu.kernelsu')) 'The shared package reader accepted empty output.'
    $headerlessText = 'Packages:' + [Environment]::NewLine + '    versionName=3.2.5'
    Assert-True ($null -eq (Get-ToolkitPackageVersion -Text $headerlessText -PackageName 'me.weishu.kernelsu')) 'The shared package reader accepted version fields with no package header.'
    $versionlessText = 'Package [me.weishu.kernelsu] (a1b2c3):' + [Environment]::NewLine + '    versionCode=30205 minSdk=28'
    $versionlessFields = Get-ToolkitPackageVersion -Text $versionlessText -PackageName 'me.weishu.kernelsu'
    Assert-True ($null -ne $versionlessFields) 'The shared package reader refused an installed package with no version name.'
    Assert-Equal '' $versionlessFields.VersionName 'The shared package reader invented a version name.'
    $nearNameBlockText = 'Package [me.weishu.kernelsu.beta] (ff00ff):' + [Environment]::NewLine + '    versionCode=99999 minSdk=28' + [Environment]::NewLine + '    versionName=9.9.9'
    Assert-True ($null -eq (Get-ToolkitPackageVersion -Text $nearNameBlockText -PackageName 'me.weishu.kernelsu')) 'The shared package reader matched a near-name header.'
    $multiBlockText = $nearNameBlockText + [Environment]::NewLine + $packageText
    $multiBlockFields = Get-ToolkitPackageVersion -Text $multiBlockText -PackageName 'me.weishu.kernelsu'
    Assert-True ($null -ne $multiBlockFields) 'The shared package reader refused a response holding the exact package block.'
    Assert-Equal '3.2.5' $multiBlockFields.VersionName 'The shared package reader took a version from a near-name block.'
    Assert-Equal '30205' $multiBlockFields.VersionCode 'The shared package reader took a version code from a near-name block.'
    $reversedBlockText = $packageText + [Environment]::NewLine + $nearNameBlockText
    $reversedBlockFields = Get-ToolkitPackageVersion -Text $reversedBlockText -PackageName 'me.weishu.kernelsu'
    Assert-True ($null -ne $reversedBlockFields) 'The shared package reader refused a response whose near-name block came second.'
    Assert-Equal '3.2.5' $reversedBlockFields.VersionName 'The shared package reader took a version from a later block.'
    Assert-Equal '30205' $reversedBlockFields.VersionCode 'The shared package reader took a version code from a later block.'
    $emptyBlockText = 'Package [me.weishu.kernelsu] (a1b2c3):' + [Environment]::NewLine + '  hiddenApi=land' + [Environment]::NewLine + $nearNameBlockText
    $emptyBlockFields = Get-ToolkitPackageVersion -Text $emptyBlockText -PackageName 'me.weishu.kernelsu'
    Assert-True ($null -ne $emptyBlockFields) 'The shared package reader refused a block that carries no version.'
    Assert-Equal '' $emptyBlockFields.VersionName 'The shared package reader borrowed a version from the following block.'
    Assert-Equal '' $emptyBlockFields.VersionCode 'The shared package reader borrowed a version code from the following block.'

    $rootShellCases = @(
        [pscustomobject]@{ Call = $null; Code = 'ADB_FAILED'; Status = 'CriticalError'; Label = 'no call at all' },
        [pscustomobject]@{ Call = ([pscustomobject]@{ ExitCode = -1; Text = 'Process launch failed: fixture' }); Code = 'ADB_FAILED'; Status = 'CriticalError'; Label = 'a call that could not be launched' },
        [pscustomobject]@{ Call = ([pscustomobject]@{ ExitCode = 1; Text = '   ' }); Code = 'ADB_FAILED'; Status = 'CriticalError'; Label = 'a failing call with no guest output' },
        [pscustomobject]@{ Call = ([pscustomobject]@{ ExitCode = 1; Text = '/system/bin/sh: su: not found' }); Code = 'ROOT_DENIED'; Status = 'CriticalError'; Label = 'a guest refusal' },
        [pscustomobject]@{ Call = ([pscustomobject]@{ ExitCode = 0; Text = 'uid=2000(shell) gid=2000(shell) groups=2000(shell)' }); Code = 'ROOT_DENIED'; Status = 'CriticalError'; Label = 'a non-root identity' },
        [pscustomobject]@{ Call = ([pscustomobject]@{ ExitCode = 0; Text = '   ' }); Code = 'ROOT_DENIED'; Status = 'CriticalError'; Label = 'a successful call with no identity' },
        [pscustomobject]@{ Call = ([pscustomobject]@{ ExitCode = 0; Text = 'uid=0(root) gid=0(root) groups=0(root)' }); Code = 'OK'; Status = 'Success'; Label = 'a root identity' }
    )
    foreach ($rootShellCase in $rootShellCases) {
        $rootShellResult = Get-ToolkitRootShellStatus -Call $rootShellCase.Call
        Assert-Equal $rootShellCase.Status $rootShellResult.Status "The shared root shell reader returned the wrong status for $($rootShellCase.Label)."
        Assert-Equal $rootShellCase.Code $rootShellResult.Data.Code "The shared root shell reader reported the wrong code for $($rootShellCase.Label)."
    }

    $root15Root = Join-Path $testRoot 'shared verification fixtures'
    $journalRoot = Join-Path $root15Root 'journals'
    $install = New-Root12InstallFixture -InstallRoot (Join-Path $root15Root 'MuMu Global') -SourceIndex 3

    $sharedState.SettingText = '{"root_permission":"true"}'
    $settingRunner = {
        param($ActualFilePath, $ActualArgumentList)
        [pscustomobject]@{ ExitCode = 0; Text = $sharedState.SettingText }
    }.GetNewClosure()
    foreach ($shape in @(
            [pscustomobject]@{ Text = '{"root_permission":"true"}'; Value = $true; Label = 'a string value' },
            [pscustomobject]@{ Text = '{"root_permission":true}'; Value = $true; Label = 'a boolean value' },
            [pscustomobject]@{ Text = '[{"root_permission":"true"}]'; Value = $true; Label = 'a one-element array' },
            [pscustomobject]@{ Text = '{"value":1}'; Value = $true; Label = 'a numeric value' },
            [pscustomobject]@{ Text = '{"root_setting":"false"}'; Value = $false; Label = 'a root_setting field' },
            [pscustomobject]@{ Text = '{"index":"7","value":"true"}'; Value = $true; Label = 'an index and a value' }
        )) {
        $sharedState.SettingText = $shape.Text
        $shapeResult = Get-ToolkitRootSetting -ManagerPath $install.ManagerPath -Index 7 -Runner $settingRunner
        Assert-Equal 'Success' $shapeResult.Status "The shared vendor root reader refused $($shape.Label)."
        Assert-Equal $shape.Value $shapeResult.Data.Value "The shared vendor root reader reported the wrong value for $($shape.Label)."
    }
    foreach ($defect in @(
            [pscustomobject]@{ Text = ''; Code = 'MANAGER_JSON_INVALID'; Label = 'empty output' },
            [pscustomobject]@{ Text = '   '; Code = 'MANAGER_JSON_INVALID'; Label = 'whitespace output' },
            [pscustomobject]@{ Text = 'not json'; Code = 'MANAGER_JSON_INVALID'; Label = 'non-JSON output' },
            [pscustomobject]@{ Text = '{"error_code":1}'; Code = 'MANAGER_ERROR'; Label = 'a manager error' },
            [pscustomobject]@{ Text = '[]'; Code = 'SHAPE_UNSUPPORTED'; Label = 'an empty array' },
            [pscustomobject]@{ Text = '[{"root_permission":"true"},{"root_permission":"false"}]'; Code = 'SHAPE_UNSUPPORTED'; Label = 'a two-element array' },
            [pscustomobject]@{ Text = '"true"'; Code = 'SHAPE_UNSUPPORTED'; Label = 'a scalar' },
            [pscustomobject]@{ Text = '{"error_code":0,"unexpected":"value"}'; Code = 'SHAPE_UNSUPPORTED'; Label = 'no supported field' },
            [pscustomobject]@{ Text = '{"root_permission":"maybe"}'; Code = 'VALUE_INVALID'; Label = 'an unusable value' },
            [pscustomobject]@{ Text = '{"index":"9","value":"true"}'; Code = 'INDEX_MISMATCH'; Label = 'another instance' }
        )) {
        $sharedState.SettingText = $defect.Text
        $defectResult = Get-ToolkitRootSetting -ManagerPath $install.ManagerPath -Index 7 -Runner $settingRunner
        Assert-Equal 'CriticalError' $defectResult.Status "The shared vendor root reader accepted $($defect.Label)."
        Assert-Equal $defect.Code $defectResult.Data.Code "The shared vendor root reader reported the wrong code for $($defect.Label)."
    }
    $blankManagerResult = Get-ToolkitRootSetting -ManagerPath '   ' -Index 7 -Runner $settingRunner
    Assert-Equal 'CriticalError' $blankManagerResult.Status 'The shared vendor root reader accepted a blank manager.'
    Assert-Equal 'MANAGER_UNAVAILABLE' $blankManagerResult.Data.Code 'The shared vendor root reader reported the wrong code for a blank manager.'
    $negativeIndexResult = Get-ToolkitRootSetting -ManagerPath $install.ManagerPath -Index -1 -Runner $settingRunner
    Assert-Equal 'CriticalError' $negativeIndexResult.Status 'The shared vendor root reader accepted a negative index.'
    Assert-Equal 'MANAGER_UNAVAILABLE' $negativeIndexResult.Data.Code 'The shared vendor root reader reported the wrong code for a negative index.'

    $failureJournalRoot = Join-Path $root15Root 'failure journals'
    $runningJournal = New-OperationJournal -Root $failureJournalRoot -Operation 'Shared' -Instance ([pscustomobject]@{ Index = 3 })
    $failedState = @{ Code = 'TEST'; Sequence = 0 }
    $failureResult = New-ToolkitRootFailure -Journal $runningJournal -Message 'shared failure fixture' -Data $failedState
    Assert-Equal 'CriticalError' $failureResult.Status 'The shared failure helper did not return a critical error.'
    Assert-Equal 'shared failure fixture' $failureResult.Message 'The shared failure helper changed the reason.'
    Assert-True ($failureResult.Data -is [Collections.IDictionary]) 'The shared failure helper dropped the recovery data.'
    Assert-Equal 'Failed' $runningJournal.State 'The shared failure helper did not close a running journal.'
    $reopenedFailure = Get-OperationJournal -Path $runningJournal.JournalPath
    Assert-Equal 'Failed' $reopenedFailure.State 'The shared failure helper did not persist the failed state.'
    Assert-Equal 'TEST' $reopenedFailure.Result.Data.Code 'The shared failure helper did not persist the recovery code.'
    Assert-True (@($reopenedFailure.Checkpoints).Count -ge 1) 'The shared failure helper recorded no checkpoint.'
    $secondFailure = New-ToolkitRootFailure -Journal $runningJournal -Message 'second shared failure fixture' -Data $failedState
    Assert-Equal 'second shared failure fixture' $secondFailure.Message 'The shared failure helper changed a reason for a closed journal.'
    Assert-Equal 'Failed' $runningJournal.State 'The shared failure helper reopened a closed journal.'
    $nullJournalFailure = New-ToolkitRootFailure -Journal $null -Message 'third shared failure fixture' -Data $failedState
    Assert-Equal 'CriticalError' $nullJournalFailure.Status 'The shared failure helper did not report a failure without a journal.'
    $blankFailure = New-ToolkitRootFailure -Journal $null -Message '   ' -Data $failedState
    Assert-Equal 'CriticalError' $blankFailure.Status 'The shared failure helper accepted a blank reason.'
    Assert-True (-not [string]::IsNullOrWhiteSpace($blankFailure.Message)) 'The shared failure helper returned no reason for a blank message.'
    $blankData = @{ Code = 'TEST'; Sequence = 1 }
    $blankDataFailure = New-ToolkitRootFailure -Journal $null -Message 'fourth shared failure fixture' -Data $blankData
    Assert-True ($blankDataFailure.Data -is [Collections.IDictionary]) 'The shared failure helper returned no recovery data.'
    Assert-Equal 'TEST' $blankDataFailure.Data.Code 'The shared failure helper changed the recovery code.'
    $nullDataFailure = New-ToolkitRootFailure -Journal $null -Message 'fifth shared failure fixture'
    Assert-True ($null -eq $nullDataFailure.Data) 'The shared failure helper invented recovery data for a failure without any.'
    Assert-Equal 0 $failedState.Sequence 'The shared failure helper shared a mutable recovery record between calls.'
}

$script:ConcealmentCodes = @(
    'OK',
    'JOURNAL_INVALID',
    'JOURNAL_WRITE_FAILED',
    'INSTANCE_INVALID',
    'MANAGER_UNAVAILABLE',
    'CACHE_UNAVAILABLE',
    'ASSET_ID_INVALID',
    'ASSET_VERIFICATION_FAILED',
    'ASSET_PATH_INVALID',
    'APK_INSTALL_FAILED',
    'MODULE_PUSH_FAILED',
    'MODULE_EXTRACT_FAILED',
    'MODULE_LAYOUT_UNSUPPORTED',
    'MODULE_INSTALL_FAILED',
    'HMA_CONFIG_UNREADABLE',
    'HMA_SCHEMA_UNSUPPORTED',
    'HMA_TEMPLATE_INVALID',
    'HMA_BACKUP_FAILED',
    'HMA_WRITE_FAILED',
    'GUEST_WRITE_FAILED',
    'PACKAGES_REQUIRED',
    'PACKAGE_NAME_INVALID',
    'PACKAGE_LIST_UNREADABLE',
    'PACKAGE_NOT_INSTALLED',
    'ALL_APPS_REFUSED'
)
$script:ConcealmentRootPackages = @(
    'org.frknkrc44.hma_oss',
    'io.github.huskydg.magisk',
    'com.coderstory.toolkit',
    'me.weishu.kernelsu'
)
$script:ConcealmentModuleRoot = '/data/adb/modules'
$script:ConcealmentSelectedPackage = 'jp.pokemon.pokemontcgp'
$script:ConcealmentUiHandoffSteps = @(
    'Open the Hide My Applist OSS app on the selected instance.',
    'Open Settings, then Create Template, then name the template Root and choose blacklist mode.',
    'Add the installed root packages to the Root template and apply it only to each selected app.',
    'Confirm the Root template is assigned to those apps and to no other app.'
)

function New-ConcealmentInstanceFixture {
    param([object]$Install)

    return [pscustomobject]@{
        Index = $Install.SourceIndex
        Name = 'Concealment target'
        AndroidVersion = '15.0'
        Install = [pscustomobject]@{
            Edition = 'Global'
            InstallRoot = $Install.InstallRoot
            VmsPath = $Install.VmsPath
            ManagerPath = $Install.ManagerPath
            Source = 'Process'
        }
        Running = $true
    }
}

function New-ConcealmentJournal {
    param(
        [string]$Root,
        [object]$Instance
    )

    return New-OperationJournal -Root $Root -Operation 'Concealment' -Instance $Instance
}

function New-ConcealmentAssetFixture {
    param([string]$CacheRoot)

    $records = @(
        [pscustomobject]@{ Id = 'hma'; Directory = 'hma'; AssetName = 'HMA-OSS-oss-161-release.apk'; Url = 'https://github.com/frknkrc44/HMA-OSS/releases/download/oss-161/HMA-OSS-oss-161-release.apk'; Payload = 'pinned hma apk payload' },
        [pscustomobject]@{ Id = 'vector'; Directory = 'vector'; AssetName = 'Vector-v2.0-3021-Release.zip'; Url = 'https://github.com/frknkrc44/Vector/releases/download/v2.0/Vector-v2.0-3021-Release.zip'; Payload = 'pinned vector module payload' }
    )
    $dependencies = @()
    foreach ($record in $records) {
        $directory = Join-Path $CacheRoot $record.Directory
        [void][IO.Directory]::CreateDirectory($directory)
        $path = Join-Path $directory $record.AssetName
        [IO.File]::WriteAllText($path, $record.Payload)
        $dependencies += [pscustomobject][ordered]@{
            id = $record.Id
            version = 'pinned'
            assetName = $record.AssetName
            url = $record.Url
            size = [long](New-Object IO.FileInfo($path)).Length
            sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    }
    return [pscustomobject]@{
        Manifest = [pscustomobject]@{ dependencies = @($dependencies) }
        Hma = (Join-Path (Join-Path $CacheRoot 'hma') 'HMA-OSS-oss-161-release.apk')
        Vector = (Join-Path (Join-Path $CacheRoot 'vector') 'Vector-v2.0-3021-Release.zip')
    }
}

function New-ConcealmentConfigText {
    param(
        [string[]]$RootPackages = $script:ConcealmentRootPackages,
        [hashtable]$Apps = @{},
        [int]$ConfigVersion = 93,
        [switch]$OmitConfigVersion
    )

    $document = [ordered]@{}
    if (-not $OmitConfigVersion) {
        $document['configVersion'] = $ConfigVersion
    }
    $document['templates'] = [ordered]@{
        Root = [ordered]@{
            isWhitelist = $false
            appList     = @($RootPackages)
        }
    }
    $applications = [ordered]@{}
    foreach ($key in @($Apps.Keys | Sort-Object)) {
        $applications[[string]$key] = [string]$Apps[$key]
    }
    $document['apps'] = $applications
    return (($document | ConvertTo-Json -Depth 8) + [Environment]::NewLine)
}

function New-ConcealmentGuestState {
    param([object]$Install)

    return @{
        Install = $Install
        Calls = @()
        Files = @{}
        ConfigPath = '/data/user/0/org.frknkrc44.hma_oss/files/config.json'
        ConfigText = ''
        Packages = @()
        Modules = @()
        HmaPackage = [string]$script:ConcealmentRootPackages[0]
        AdbFailPattern = ''
        PushExitCode = 0
        InstallExitCode = 0
        ExtractExitCode = 0
        MoveExitCode = 0
        WriteFailPattern = ''
    }
}

function Invoke-ConcealmentGuestShell {
    param(
        [hashtable]$State,
        [string]$Command
    )

    if ($Command -match '^cat (\S+)$') {
        $path = $Matches[1]
        if ($State.Files.ContainsKey($path)) {
            return [pscustomobject]@{ ExitCode = 0; Text = [string]$State.Files[$path] }
        }
        return [pscustomobject]@{ ExitCode = 1; Text = ('cat: ' + $path + ': No such file or directory') }
    }
    if ($Command -match '^ls -l (\S+)$') {
        $path = $Matches[1]
        if ($State.Files.ContainsKey($path)) {
            $length = [long](New-Object Text.UTF8Encoding($false)).GetByteCount([string]$State.Files[$path])
            return [pscustomobject]@{ ExitCode = 0; Text = ('-rw-r--r-- 1 root root ' + [string]$length + ' Jan 1 00:00 ' + $path) }
        }
        return [pscustomobject]@{ ExitCode = 1; Text = ('ls: cannot access ' + $path + ': No such file or directory') }
    }
    if ($Command -match '^ls (\S+)$') {
        $path = $Matches[1]
        if ($path.StartsWith($script:ConcealmentModuleRoot, [StringComparison]::Ordinal)) {
            $name = $path.Substring($script:ConcealmentModuleRoot.Length).TrimStart('/')
            if ($State.Modules -ccontains $name) {
                return [pscustomobject]@{ ExitCode = 0; Text = $path }
            }
            return [pscustomobject]@{ ExitCode = 1; Text = ('ls: cannot access ' + $path + ': No such file or directory') }
        }
        $children = @()
        foreach ($key in $State.Files.Keys) {
            if ($key.StartsWith(($path + '/'), [StringComparison]::Ordinal)) {
                $children += $key.Substring(($path + '/').Length)
            }
        }
        if ($children.Count -eq 0) {
            return [pscustomobject]@{ ExitCode = 1; Text = ('ls: cannot access ' + $path + ': No such file or directory') }
        }
        return [pscustomobject]@{ ExitCode = 0; Text = (@($children | Sort-Object) -join [Environment]::NewLine) }
    }
    if ($Command -match '^echo ([A-Za-z0-9+/=]+) \| base64 -d > (\S+) && mv (\S+) (\S+)$') {
        $payload = $Matches[1]
        $temporaryPath = $Matches[2]
        $movedFrom = $Matches[3]
        $movedTo = $Matches[4]
        if (-not [string]::IsNullOrWhiteSpace([string]$State.WriteFailPattern) -and $movedTo -like $State.WriteFailPattern) {
            return [pscustomobject]@{ ExitCode = 1; Text = ('mv: cannot create regular file ' + $movedTo) }
        }
        if ($temporaryPath -cne $movedFrom) {
            return [pscustomobject]@{ ExitCode = 1; Text = 'mv: the temporary and moved paths differ' }
        }
        try {
            $text = (New-Object Text.UTF8Encoding($false)).GetString([Convert]::FromBase64String($payload))
        }
        catch {
            return [pscustomobject]@{ ExitCode = 1; Text = 'base64: invalid input' }
        }
        $State.Files[$temporaryPath] = $text
        $State.Files[$movedTo] = [string]$State.Files[$temporaryPath]
        $State.Files.Remove($temporaryPath)
        return [pscustomobject]@{ ExitCode = 0; Text = '' }
    }
    if ($Command -match '^mkdir -p (\S+) && unzip -o (\S+) -d (\S+)$') {
        if ($State.ExtractExitCode -ne 0) {
            return [pscustomobject]@{ ExitCode = $State.ExtractExitCode; Text = 'unzip: cannot find the pushed asset' }
        }
        $extractPath = $Matches[1]
        $pushedPath = $Matches[2]
        if (-not $State.Files.ContainsKey($pushedPath)) {
            return [pscustomobject]@{ ExitCode = 1; Text = ('unzip: cannot find ' + $pushedPath) }
        }
        $State.Files[($extractPath + '/vector')] = 'vector module payload'
        return [pscustomobject]@{ ExitCode = 0; Text = 'inflating: vector/module.prop' }
    }
    if ($Command -match '^mv (\S+)/(\S+) ' + [regex]::Escape($script:ConcealmentModuleRoot) + '/(\S+) && rmdir (\S+)$') {
        if ($State.MoveExitCode -ne 0) {
            return [pscustomobject]@{ ExitCode = $State.MoveExitCode; Text = 'mv: cannot move the extracted module' }
        }
        $extractPath = $Matches[1]
        $child = $Matches[2]
        $target = $Matches[3]
        if ($target -cne $child) {
            return [pscustomobject]@{ ExitCode = 1; Text = 'mv: the module directory name differs' }
        }
        if (-not $State.Files.ContainsKey(($extractPath + '/' + $child))) {
            return [pscustomobject]@{ ExitCode = 1; Text = ('mv: cannot stat ' + $extractPath + '/' + $child) }
        }
        $State.Modules = @($State.Modules) + $target
        $State.Files[($script:ConcealmentModuleRoot + '/' + $child + '/module.prop')] = 'id=vector'
        return [pscustomobject]@{ ExitCode = 0; Text = '' }
    }
    return [pscustomobject]@{ ExitCode = 1; Text = 'unsupported guest command' }
}

function New-ConcealmentManagerRunner {
    param([hashtable]$State)

    return {
        param($ActualFilePath, $ActualArgumentList)
        $State.Calls += ,@($ActualArgumentList)
        $arguments = @($ActualArgumentList | ForEach-Object { [string]$_ })
        if ($arguments.Count -lt 5 -or $arguments[0] -cne 'adb' -or $arguments[1] -cne '-v' -or
            $arguments[2] -cne [string]$State.Install.SourceIndex -or $arguments[3] -cne '-c') {
            return [pscustomobject]@{ ExitCode = 1; Text = 'unsupported manager request' }
        }
        $request = [string]$arguments[4]
        if (-not [string]::IsNullOrWhiteSpace([string]$State.AdbFailPattern) -and $request -like $State.AdbFailPattern) {
            return [pscustomobject]@{ ExitCode = 1; Text = 'adb: fixture failure' }
        }
        if ($request -ceq 'shell pm list packages') {
            return [pscustomobject]@{ ExitCode = 0; Text = (@($State.Packages | ForEach-Object { 'package:' + [string]$_ }) -join [Environment]::NewLine) }
        }
        if ($request -match '^shell dumpsys package (\S+)$') {
            $name = $Matches[1]
            if ($State.Packages -cnotcontains $name) {
                return [pscustomobject]@{ ExitCode = 0; Text = ('Unable to find package: ' + $name + '.') }
            }
            return [pscustomobject]@{
                ExitCode = 0
                Text = ('Package [' + $name + '] (a1b2c3):' + [Environment]::NewLine + '    versionCode=1 minSdk=28' + [Environment]::NewLine + '    versionName=1.0')
            }
        }
        if ($request -match '^shell su -c "(.*)"$') {
            return Invoke-ConcealmentGuestShell -State $State -Command $Matches[1]
        }
        if ($request -match '^install -r "(.+)"$') {
            if ($State.InstallExitCode -ne 0) {
                return [pscustomobject]@{ ExitCode = $State.InstallExitCode; Text = 'adb: failed to install' }
            }
            $State.Packages = @($State.Packages) + @($State.HmaPackage)
            return [pscustomobject]@{ ExitCode = 0; Text = 'Success' }
        }
        if ($request -match '^push "(.+)" (\S+)$') {
            if ($State.PushExitCode -ne 0) {
                return [pscustomobject]@{ ExitCode = $State.PushExitCode; Text = 'adb: failed to push' }
            }
            $State.Files[[string]$Matches[2]] = 'pushed module payload'
            return [pscustomobject]@{ ExitCode = 0; Text = ('1 file pushed, 0 skipped.') }
        }
        return [pscustomobject]@{ ExitCode = 1; Text = 'unsupported adb request' }
    }.GetNewClosure()
}

function Get-ConcealmentCallIndex {
    param(
        [object[]]$Calls,
        [string]$Pattern
    )

    for ($index = 0; $index -lt $Calls.Count; $index++) {
        if ((@($Calls[$index]) -join ' ') -like $Pattern) {
            return $index
        }
    }
    return -1
}

function Get-ConcealmentCalls {
    param(
        [object]$State,
        [string]$Pattern
    )

    return @($State.Calls | Where-Object { ((@($_) -join ' ')) -like $Pattern })
}

function Assert-ConcealmentFailure {
    param(
        [object]$Result,
        [object]$Journal,
        [string]$Code,
        [string]$Message
    )

    Assert-Equal 'CriticalError' $Result.Status $Message
    Assert-True ($null -ne $Result.Data) "$Message The failure carried no recovery data."
    Assert-True ($script:ConcealmentCodes -ccontains [string]$Result.Data.Code) "$Message The failure reported an undocumented code: $($Result.Data.Code)"
    Assert-Equal $Code $Result.Data.Code "$Message The failure code is invalid."
    Assert-Equal 'Failed' $Journal.State "$Message The failure was not journaled."
    $reopened = Get-OperationJournal -Path $Journal.JournalPath
    Assert-Equal 'Failed' $reopened.State "$Message The failure was not persisted."
    Assert-Equal 'CriticalError' $reopened.Result.Status "$Message The persisted result status is invalid."
    Assert-Equal $Code $reopened.Result.Data.Code "$Message The persisted recovery code changed."
    Assert-True (@($reopened.Checkpoints).Count -ge 1) "$Message No failure checkpoint was recorded."
}

function Assert-ConcealmentHandoff {
    param(
        [object]$Result,
        [object]$Journal,
        [string]$Code,
        [string]$Message
    )

    Assert-Equal 'Warning' $Result.Status $Message
    Assert-True ($null -ne $Result.Data) "$Message The warning carried no data."
    Assert-Equal $Code $Result.Data.Code "$Message The warning reported the wrong code."
    $steps = @($Result.Data.Steps)
    foreach ($expectedStep in $script:ConcealmentUiHandoffSteps) {
        Assert-True (@($steps) -ccontains $expectedStep) "$Message The warning dropped the supported-UI step: $expectedStep"
    }
    if ($null -eq $Journal) {
        return
    }
    Assert-Equal 'Completed' $Journal.State "$Message The warning was not journaled."
    $reopened = Get-OperationJournal -Path $Journal.JournalPath
    Assert-Equal 'Completed' $reopened.State "$Message The warning was not persisted."
    Assert-Equal 'Warning' $reopened.Result.Status "$Message The persisted warning status is invalid."
}

function Invoke-ConcealmentTests {
    foreach ($commandName in @('Install-ConcealmentDependencies', 'Get-HmaConfig', 'New-ReusableRootTemplate', 'Set-AppConcealment', 'Test-Concealment', 'Get-KernelSUProfileSteps')) {
        Assert-True ($null -ne (Get-Command $commandName -CommandType Function -ErrorAction SilentlyContinue)) "Concealment command is unavailable: $commandName"
    }
    Assert-True (Test-Path -LiteralPath $concealmentScriptPath -PathType Leaf) 'src/Concealment.ps1 does not exist.'

    $concealmentSource = [IO.File]::ReadAllText($concealmentScriptPath)
    foreach ($forbidden in @(
            'Invoke-Expression',
            'ScriptBlock]::Create',
            'Add-Type',
            'Start-Process',
            'Invoke-WebRequest',
            'Invoke-RestMethod',
            'schtasks',
            'Set-ExecutionPolicy',
            'icacls',
            'Set-Acl',
            'Get-Acl',
            'New-NetFirewallRule',
            'Set-NetFirewallProfile',
            'Set-MpPreference',
            'bcdedit',
            'vmmservice',
            'hypervisorlaunchtype',
            'Remove-Item',
            'pm uninstall',
            'pm disable',
            'pm clear',
            'monkey',
            'rm -rf',
            'dd if=',
            'install-multiple',
            "'UNKNOWN'"
        )) {
        Assert-True ($concealmentSource -notmatch [regex]::Escape($forbidden)) "Concealment source uses a forbidden construct: $forbidden"
    }
    foreach ($sharedPrimitive in @('Invoke-ToolkitManagerAdb', 'Get-ToolkitPackageVersion', 'New-ToolkitRootFailure', 'Save-ToolkitManifestAsset', 'Format-Android12InstallCommand', 'Write-JournalEvent')) {
        Assert-True ($concealmentSource -match [regex]::Escape($sharedPrimitive)) "The concealment flow does not use the shared primitive: $sharedPrimitive"
    }
    Assert-Equal $script:ToolkitKitsunePackageName $script:ConcealmentKitsunePackage 'The concealment flow does not use the same Kitsune package name as the Android 12 flow.'
    Assert-Equal 'me.weishu.kernelsu' $script:ConcealmentKernelSUPackage 'The concealment flow does not name the built-in KernelSU package.'
    Assert-Equal 93 $script:ConcealmentConfigVersion 'The concealment flow does not accept only the supported HMA configuration version.'
    Assert-Equal 'Root' $script:ConcealmentTemplateName 'The concealment flow does not use the reusable Root template name.'
    foreach ($requiredPackage in $script:ConcealmentRootPackages) {
        Assert-True (@($script:ConcealmentTemplatePackages) -ccontains $requiredPackage) "The reusable Root template omits the required package: $requiredPackage"
    }
    Assert-Equal $script:ConcealmentRootPackages.Count @($script:ConcealmentTemplatePackages).Count 'The reusable Root template package set is not exactly the four required packages.'
    Assert-Equal ($script:ConcealmentModuleRoot + '/vector') $script:ConcealmentVectorModulePath 'The Vector module path is not the pinned module directory.'
    Assert-True ($concealmentSource -notmatch 'ToolkitKernelSUAllowlistPath[^\r\n]*WriteAllText') 'The concealment flow writes the KernelSU allowlist file.'

    $profileSteps = @(Get-KernelSUProfileSteps -PackageName $script:ConcealmentSelectedPackage)
    Assert-Equal 3 $profileSteps.Count 'The KernelSU handoff did not return exactly three steps.'
    Assert-Equal ('Open KernelSU Superuser and select ' + $script:ConcealmentSelectedPackage + '.') $profileSteps[0] 'The KernelSU handoff lost the package step.'
    Assert-Equal 'Keep Superuser disabled.' $profileSteps[1] 'The KernelSU handoff lost the disabled Superuser step.'
    Assert-Equal 'Choose Custom and enable Umount modules.' $profileSteps[2] 'The KernelSU handoff lost the Custom and Umount modules step.'
    Assert-True (@(Get-KernelSUProfileSteps -PackageName '   ').Count -eq 0) 'The KernelSU handoff produced steps for a blank package name.'

    $concealmentRoot = Join-Path $testRoot 'concealment fixtures'
    $journalRoot = Join-Path $concealmentRoot 'journals'
    $assetCacheRoot = Join-Path $concealmentRoot 'assets'
    $install = New-Root12InstallFixture -InstallRoot (Join-Path $concealmentRoot 'MuMu Global') -SourceIndex 3
    $instance = New-ConcealmentInstanceFixture -Install $install
    $assets = New-ConcealmentAssetFixture -CacheRoot $assetCacheRoot
    $runner = New-ConcealmentManagerRunner -State (New-ConcealmentGuestState -Install $install)

    $missingCacheRoot = Join-Path $concealmentRoot 'empty assets'
    [void][IO.Directory]::CreateDirectory($missingCacheRoot)
    $missingHma = Save-ToolkitManifestAsset -Manifest $assets.Manifest -Id 'hma' -CacheRoot $missingCacheRoot
    Assert-Equal 'CriticalError' $missingHma.Status 'A missing pinned asset was accepted.'
    Assert-Equal 'ASSET_VERIFICATION_FAILED' $missingHma.Data.Code 'A missing pinned asset did not report the verification gate.'
    $tamperedRoot = Join-Path $concealmentRoot 'tampered assets'
    $tampered = New-ConcealmentAssetFixture -CacheRoot $tamperedRoot
    [IO.File]::WriteAllText($tampered.Hma, 'tampered hma apk payload')
    $tamperedHma = Save-ToolkitManifestAsset -Manifest $assets.Manifest -Id 'hma' -CacheRoot $tamperedRoot
    Assert-Equal 'CriticalError' $tamperedHma.Status 'A tampered pinned asset was accepted.'
    Assert-Equal 'ASSET_VERIFICATION_FAILED' $tamperedHma.Data.Code 'A tampered pinned asset did not report the verification gate.'
    $wrongSizeManifest = [pscustomobject]@{
        dependencies = @([pscustomobject][ordered]@{
                    id        = 'hma'
                    version   = 'pinned'
                    assetName = 'HMA-OSS-oss-161-release.apk'
                    url       = 'https://github.com/frknkrc44/HMA-OSS/releases/download/oss-161/HMA-OSS-oss-161-release.apk'
                    size      = [long]1
                    sha256    = '0000000000000000000000000000000000000000000000000000000000000000'
                })
    }
    $wrongSizeAsset = Save-ToolkitManifestAsset -Manifest $wrongSizeManifest -Id 'hma' -CacheRoot $assetCacheRoot
    Assert-Equal 'CriticalError' $wrongSizeAsset.Status 'An asset with a substituted size and hash was accepted.'
    Assert-Equal 'ASSET_VERIFICATION_FAILED' $wrongSizeAsset.Data.Code 'A substituted asset did not report the verification gate.'
    foreach ($badId in @('   ', 'hma/../vector', '*')) {
        $badIdResult = Save-ToolkitManifestAsset -Manifest $assets.Manifest -Id $badId -CacheRoot $assetCacheRoot
        Assert-Equal 'CriticalError' $badIdResult.Status "The manifest helper accepted the asset id $badId."
        Assert-Equal 'ASSET_ID_INVALID' $badIdResult.Data.Code "The manifest helper reported the wrong code for the asset id $badId."
    }
    $verifiedAsset = Save-ToolkitManifestAsset -Manifest $assets.Manifest -Id 'hma' -CacheRoot $assetCacheRoot
    Assert-Equal 'Success' $verifiedAsset.Status 'The manifest helper refused a pinned verified asset.'
    Assert-Equal 'OK' $verifiedAsset.Data.Code 'The manifest helper reported the wrong success code.'
    Assert-Equal $assets.Hma $verifiedAsset.Data.Asset 'The manifest helper returned the wrong verified asset path.'

    $installState = New-ConcealmentGuestState -Install $install
    $installState.Packages = @($script:ConcealmentRootPackages[1], $script:ConcealmentRootPackages[3], $script:ConcealmentSelectedPackage)
    $installJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $dependencyResult = Install-ConcealmentDependencies -Instance $instance -Manifest $assets.Manifest -Journal $installJournal -CacheRoot $assetCacheRoot -Runner (New-ConcealmentManagerRunner -State $installState)
    Assert-True ($dependencyResult.Status -eq 'Success') "Concealment dependency installation failed. $($dependencyResult.Message) "
    Assert-Equal 'OK' $dependencyResult.Data.Code 'Concealment dependency installation reported an invalid code.'
    Assert-Equal 'Completed' $installJournal.State 'Concealment dependency installation did not complete its journal.'
    $reopenedInstall = Get-OperationJournal -Path $installJournal.JournalPath
    Assert-Equal 'Completed' $reopenedInstall.State 'Concealment dependency installation did not persist its journal state.'
    Assert-Equal 'Success' $reopenedInstall.Result.Status 'Concealment dependency installation did not persist its result.'
    Assert-True (@($dependencyResult.Data.Installed) -ccontains 'hma') 'The verified HMA APK was not reported as installed.'
    Assert-True (@($dependencyResult.Data.Installed) -ccontains 'vector') 'The verified Vector module was not reported as installed.'
    Assert-Equal 0 @($dependencyResult.Data.AlreadyPresent).Count 'Concealment dependency installation reported an absent dependency as already present.'
    Assert-True (@($installState.Packages) -ccontains $script:ConcealmentRootPackages[0]) 'The HMA package was not installed on the instance.'
    Assert-True (@($installState.Modules) -ccontains 'vector') 'The Vector module was not installed on the instance.'
    Assert-Equal 1 @(Get-ConcealmentCalls -State $installState -Pattern '*install -r*').Count 'The verified HMA APK was not installed exactly once.'
    Assert-Equal 1 @(Get-ConcealmentCalls -State $installState -Pattern '*push*').Count 'The verified Vector module was not pushed exactly once.'
    $installCallText = (@($installState.Calls) | ForEach-Object { @($_) -join ' ' }) -join ' '
    Assert-True ($installCallText -notmatch 'neozygisk|corepatch|kitsune') 'Concealment dependency installation used an asset outside its pinned pair.'
    Assert-True ($installCallText -match [regex]::Escape($assets.Vector)) 'The Vector module was not pushed from the verified cache path.'
    $moduleCall = Get-ConcealmentCallIndex -Calls $installState.Calls -Pattern ('*mv*' + $script:ConcealmentModuleRoot + '/vector*')
    Assert-True ($moduleCall -ge 0) 'The extracted Vector module was not moved into the module directory.'

    $presentState = New-ConcealmentGuestState -Install $install
    $presentState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentRootPackages[3])
    $presentState.Modules = @('vector')
    $presentJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $presentResult = Install-ConcealmentDependencies -Instance $instance -Manifest $assets.Manifest -Journal $presentJournal -CacheRoot $assetCacheRoot -Runner (New-ConcealmentManagerRunner -State $presentState)
    Assert-Equal 'AlreadyApplied' $presentResult.Status 'Present concealment dependencies were not reported as already applied.'
    Assert-Equal 2 @($presentResult.Data.AlreadyPresent).Count 'Present concealment dependencies were not reported as already present.'
    Assert-Equal 0 @($presentResult.Data.Installed).Count 'Present concealment dependencies were reported as installed.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $presentState -Pattern '*install -r*').Count 'An already installed HMA APK was installed again.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $presentState -Pattern '*push*').Count 'An already installed Vector module was pushed again.'

    foreach ($assetDefect in @(
            [pscustomobject]@{ Label = 'a missing HMA asset'; Asset = 'hma' },
            [pscustomobject]@{ Label = 'a missing Vector asset'; Asset = 'vector' }
        )) {
        $defectRoot = Join-Path $concealmentRoot ('defect assets ' + $assetDefect.Asset)
        [void][IO.Directory]::CreateDirectory($defectRoot)
        $defectFixture = New-ConcealmentAssetFixture -CacheRoot $defectRoot
        if ($assetDefect.Asset -ceq 'hma') {
            [IO.File]::Delete($defectFixture.Hma)
        }
        else {
            [IO.File]::Delete($defectFixture.Vector)
        }
        $defectState = New-ConcealmentGuestState -Install $install
        $defectState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
        $defectJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
        $defectResult = Install-ConcealmentDependencies -Instance $instance -Manifest $defectFixture.Manifest -Journal $defectJournal -CacheRoot $defectRoot -Runner (New-ConcealmentManagerRunner -State $defectState)
        Assert-ConcealmentFailure -Result $defectResult -Journal $defectJournal -Code 'ASSET_VERIFICATION_FAILED' -Message "An unverified dependency was substituted: $($assetDefect.Label)."
        Assert-Equal 0 @($defectState.Calls).Count "An unverified dependency still changed the instance: $($assetDefect.Label)."
        Assert-Equal 2 @($defectState.Packages).Count "An unverified dependency still changed the package list: $($assetDefect.Label)."
        Assert-True (@($defectState.Packages) -cnotcontains 'com.example.substituted') "An unverified dependency still installed a package: $($assetDefect.Label)."
    }

    $noJournalState = New-ConcealmentGuestState -Install $install
    $noJournalResult = Install-ConcealmentDependencies -Instance $instance -Manifest $assets.Manifest -Journal $null -CacheRoot $assetCacheRoot -Runner (New-ConcealmentManagerRunner -State $noJournalState)
    Assert-Equal 'CriticalError' $noJournalResult.Status 'Concealment dependency installation accepted a missing journal.'
    Assert-Equal 'JOURNAL_INVALID' $noJournalResult.Data.Code 'A missing journal reported the wrong code.'
    Assert-Equal 0 @($noJournalState.Calls).Count 'A missing journal still changed the instance.'
    $nullInstanceState = New-ConcealmentGuestState -Install $install
    $nullInstanceResult = Install-ConcealmentDependencies -Instance $null -Manifest $assets.Manifest -Journal (New-ConcealmentJournal -Root $journalRoot -Instance $instance) -CacheRoot $assetCacheRoot -Runner (New-ConcealmentManagerRunner -State $nullInstanceState)
    Assert-Equal 'CriticalError' $nullInstanceResult.Status 'Concealment dependency installation accepted a missing instance.'
    Assert-Equal 'INSTANCE_INVALID' $nullInstanceResult.Data.Code 'A missing instance reported the wrong code.'
    Assert-Equal 0 @($nullInstanceState.Calls).Count 'A missing instance still reached the manager.'
    $noManifestState = New-ConcealmentGuestState -Install $install
    $noManifestResult = Install-ConcealmentDependencies -Instance $instance -Manifest $null -Journal (New-ConcealmentJournal -Root $journalRoot -Instance $instance) -CacheRoot $assetCacheRoot -Runner (New-ConcealmentManagerRunner -State $noManifestState)
    Assert-Equal 'CriticalError' $noManifestResult.Status 'Concealment dependency installation accepted a missing manifest.'
    Assert-Equal 0 @($noManifestState.Calls).Count 'A missing manifest still reached the manager.'

    foreach ($installDefect in @(
            [pscustomobject]@{ Knob = 'InstallExitCode'; Value = 1; Code = 'APK_INSTALL_FAILED'; Label = 'a failed HMA APK install' },
            [pscustomobject]@{ Knob = 'PushExitCode'; Value = 1; Code = 'MODULE_PUSH_FAILED'; Label = 'a failed Vector module push' },
            [pscustomobject]@{ Knob = 'ExtractExitCode'; Value = 1; Code = 'MODULE_EXTRACT_FAILED'; Label = 'a failed Vector module extraction' },
            [pscustomobject]@{ Knob = 'MoveExitCode'; Value = 1; Code = 'MODULE_INSTALL_FAILED'; Label = 'a failed Vector module install' }
        )) {
        $defectState = New-ConcealmentGuestState -Install $install
        $defectState.Packages = @($script:ConcealmentRootPackages[1], $script:ConcealmentSelectedPackage)
        $defectState.($installDefect.Knob) = $installDefect.Value
        $defectJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
        $defectResult = Install-ConcealmentDependencies -Instance $instance -Manifest $assets.Manifest -Journal $defectJournal -CacheRoot $assetCacheRoot -Runner (New-ConcealmentManagerRunner -State $defectState)
        Assert-ConcealmentFailure -Result $defectResult -Journal $defectJournal -Code $installDefect.Code -Message "A concealment dependency defect was accepted: $($installDefect.Label)."
        if ($installDefect.Knob -ceq 'InstallExitCode') {
            Assert-Equal 0 @(Get-ConcealmentCalls -State $defectState -Pattern '*push*').Count 'A failed HMA APK install still pushed the Vector module.'
        }
        if ($installDefect.Knob -eq 'MoveExitCode' -or $installDefect.Knob -eq 'ExtractExitCode') {
            Assert-Equal 0 @($defectState.Modules).Count "A failed Vector module install was recorded as present: $($installDefect.Label)."
        }
    }

    $configState = New-ConcealmentGuestState -Install $install
    $configState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentRootPackages[1], $script:ConcealmentRootPackages[2], $script:ConcealmentRootPackages[3], $script:ConcealmentSelectedPackage)
    $configState.Files[$configState.ConfigPath] = (New-ConcealmentConfigText)
    $configRunner = New-ConcealmentManagerRunner -State $configState
    $readConfig = Get-HmaConfig -Instance $instance -Runner $configRunner
    Assert-Equal 'Success' $readConfig.Status "The supported HMA configuration was refused. $($readConfig.Message)"
    Assert-Equal 93 $readConfig.Data.HmaConfigVersion 'The HMA configuration reader reported the wrong version.'
    Assert-Equal $configState.ConfigPath $readConfig.Data.ConfigPath 'The HMA configuration reader reported the wrong path.'

    foreach ($schemaDefect in @(
            [pscustomobject]@{ Text = (New-ConcealmentConfigText -ConfigVersion 92); Code = 'HMA_SCHEMA_UNSUPPORTED'; Label = 'an older configuration version' },
            [pscustomobject]@{ Text = (New-ConcealmentConfigText -ConfigVersion 94); Code = 'HMA_SCHEMA_UNSUPPORTED'; Label = 'a newer configuration version' },
            [pscustomobject]@{ Text = (New-ConcealmentConfigText -OmitConfigVersion); Code = 'HMA_SCHEMA_UNSUPPORTED'; Label = 'a configuration with no version' },
            [pscustomobject]@{ Text = ('{"configVersion":"93"}'); Code = 'HMA_SCHEMA_UNSUPPORTED'; Label = 'a string configuration version' },
            [pscustomobject]@{ Text = ('{"configVersion":93,"templates":"Root"}'); Code = 'HMA_SCHEMA_UNSUPPORTED'; Label = 'a configuration with an unusable template map' },
            [pscustomobject]@{ Text = ('[{"configVersion":93}]'); Code = 'HMA_SCHEMA_UNSUPPORTED'; Label = 'an array configuration' },
            [pscustomobject]@{ Text = ('not json'); Code = 'HMA_SCHEMA_UNSUPPORTED'; Label = 'a malformed configuration' }
        )) {
        $defectState = New-ConcealmentGuestState -Install $install
        $defectState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
        $defectState.Files[$defectState.ConfigPath] = $schemaDefect.Text
        $defectConfig = Get-HmaConfig -Instance $instance -Runner (New-ConcealmentManagerRunner -State $defectState)
        Assert-ConcealmentHandoff -Result $defectConfig -Journal $null -Code $schemaDefect.Code -Message "An unknown HMA schema was accepted: $($schemaDefect.Label)."
        Assert-Equal 0 @(Get-ConcealmentCalls -State $defectState -Pattern '*base64*').Count "An unknown HMA schema still wrote a file: $($schemaDefect.Label)."
        $defectTemplateJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
        $defectTemplate = New-ReusableRootTemplate -Instance $instance -Journal $defectTemplateJournal -Runner (New-ConcealmentManagerRunner -State $defectState)
        Assert-ConcealmentHandoff -Result $defectTemplate -Journal $defectTemplateJournal -Code $schemaDefect.Code -Message "An unknown HMA schema still produced a template: $($schemaDefect.Label)."
        $defectSetJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
        $defectSet = Set-AppConcealment -Instance $instance -Packages @($script:ConcealmentSelectedPackage) -Journal $defectSetJournal -Runner (New-ConcealmentManagerRunner -State $defectState)
        Assert-ConcealmentHandoff -Result $defectSet -Journal $defectSetJournal -Code $schemaDefect.Code -Message "An unknown HMA schema still applied concealment: $($schemaDefect.Label)."
        Assert-Equal $schemaDefect.Text $defectState.Files[$defectState.ConfigPath] "An unknown HMA schema changed the configuration: $($schemaDefect.Label)."
    }

    $absentState = New-ConcealmentGuestState -Install $install
    $absentState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
    $absentConfig = Get-HmaConfig -Instance $instance -Runner (New-ConcealmentManagerRunner -State $absentState)
    Assert-ConcealmentHandoff -Result $absentConfig -Journal $null -Code 'HMA_CONFIG_UNREADABLE' -Message 'An unreadable HMA configuration was accepted.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $absentState -Pattern '*base64*').Count 'An unreadable HMA configuration still wrote a file.'
    $failingState = New-ConcealmentGuestState -Install $install
    $failingState.Packages = @($script:ConcealmentSelectedPackage)
    $failingState.AdbFailPattern = '*cat*'
    $failingConfig = Get-HmaConfig -Instance $instance -Runner (New-ConcealmentManagerRunner -State $failingState)
    Assert-ConcealmentHandoff -Result $failingConfig -Journal $null -Code 'HMA_CONFIG_UNREADABLE' -Message 'A failed HMA configuration read was accepted.'
    $absentTemplateJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $absentTemplate = New-ReusableRootTemplate -Instance $instance -Journal $absentTemplateJournal -Runner (New-ConcealmentManagerRunner -State $absentState)
    Assert-ConcealmentHandoff -Result $absentTemplate -Journal $absentTemplateJournal -Code 'HMA_CONFIG_UNREADABLE' -Message 'An unreadable HMA configuration still produced a template.'
    $noManagerConfig = Get-HmaConfig -Instance ([pscustomobject]@{ Index = $install.SourceIndex }) -Runner $runner
    Assert-Equal 'Warning' $noManagerConfig.Status 'A concealment read without a manager path was not reported as a safe handoff.'
    $nullConfig = Get-HmaConfig -Instance $null -Runner $runner
    Assert-Equal 'Warning' $nullConfig.Status 'A concealment read without an instance was not reported as a safe handoff.'

    $templateState = New-ConcealmentGuestState -Install $install
    $templateState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentRootPackages[1], $script:ConcealmentRootPackages[2], $script:ConcealmentRootPackages[3], $script:ConcealmentSelectedPackage)
    $templateState.Files[$templateState.ConfigPath] = (New-ConcealmentConfigText -RootPackages @('com.example.legacy'))
    $templateJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $templateResult = New-ReusableRootTemplate -Instance $instance -Journal $templateJournal -Runner (New-ConcealmentManagerRunner -State $templateState)
    Assert-Equal 'Success' $templateResult.Status "The reusable Root template could not be verified. $($templateResult.Message)"
    Assert-Equal 'Root' $templateResult.Data.TemplateName 'The reusable Root template reported the wrong name.'
    Assert-Equal $false $templateResult.Data.IsWhitelist 'The reusable Root template is not a blacklist template.'
    foreach ($requiredPackage in $script:ConcealmentRootPackages) {
        Assert-True (@($templateResult.Data.TemplatePackages) -ccontains $requiredPackage) "The reusable Root template omits the required package: $requiredPackage"
    }
    Assert-True (@($templateResult.Data.TemplatePackages) -ccontains 'com.example.legacy') 'The reusable Root template dropped an existing template entry.'
    Assert-True (@($templateResult.Data.TemplatePackages) -cnotcontains $script:ConcealmentSelectedPackage) 'The reusable Root template absorbed a selected app.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $templateState -Pattern '*base64*').Count 'Verifying the reusable Root template wrote the configuration.'

    $whitelistState = New-ConcealmentGuestState -Install $install
    $whitelistState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
    $whitelistState.Files[$whitelistState.ConfigPath] = ('{"configVersion":93,"templates":{"Root":{"isWhitelist":true,"appList":[]}},"apps":{}}')
    $whitelistJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $whitelistResult = Set-AppConcealment -Instance $instance -Packages @($script:ConcealmentSelectedPackage) -Journal $whitelistJournal -Runner (New-ConcealmentManagerRunner -State $whitelistState)
    Assert-ConcealmentFailure -Result $whitelistResult -Journal $whitelistJournal -Code 'HMA_TEMPLATE_INVALID' -Message 'An existing HMA Root whitelist template was flipped to a blacklist.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $whitelistState -Pattern '*base64*').Count 'An existing HMA Root whitelist template still wrote the configuration.'

    $globalState = New-ConcealmentGuestState -Install $install
    $globalState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage, 'com.example.other')
    $globalState.Files[$globalState.ConfigPath] = (New-ConcealmentConfigText -Apps @{'*' = 'Root'})
    $globalJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $globalResult = Set-AppConcealment -Instance $instance -Packages @($script:ConcealmentSelectedPackage) -Journal $globalJournal -Runner (New-ConcealmentManagerRunner -State $globalState)
    Assert-ConcealmentFailure -Result $globalResult -Journal $globalJournal -Code 'HMA_TEMPLATE_INVALID' -Message 'An existing global HMA template scope was rewritten.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $globalState -Pattern '*base64*').Count 'An existing global HMA template scope still wrote the configuration.'

    $partialState = New-ConcealmentGuestState -Install $install
    $partialState.Packages = @($script:ConcealmentRootPackages[3], $script:ConcealmentSelectedPackage)
    $partialState.Files[$partialState.ConfigPath] = (New-ConcealmentConfigText -RootPackages @())
    $partialTemplate = New-ReusableRootTemplate -Instance $instance -Journal (New-ConcealmentJournal -Root $journalRoot -Instance $instance) -Runner (New-ConcealmentManagerRunner -State $partialState)
    Assert-Equal @($script:ConcealmentRootPackages[3]) @($partialTemplate.Data.TemplatePackages) 'The reusable Root template added a root package that is not installed.'

    $applyState = New-ConcealmentGuestState -Install $install
    $applyState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentRootPackages[1], $script:ConcealmentRootPackages[2], $script:ConcealmentRootPackages[3], $script:ConcealmentSelectedPackage, 'com.example.other')
    $applyState.Files[$applyState.ConfigPath] = (New-ConcealmentConfigText -RootPackages @('com.example.legacy'))
    $applyJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $applyRunner = New-ConcealmentManagerRunner -State $applyState
    $applyResult = Set-AppConcealment -Instance $instance -Packages @($script:ConcealmentSelectedPackage) -Journal $applyJournal -Runner $applyRunner
    Assert-True ($applyResult.Status -eq 'Success') "Selected app concealment failed. $($applyResult.Message)"
    Assert-Equal 'OK' $applyResult.Data.Code 'Selected app concealment reported an invalid code.'
    Assert-True (@($applyResult.Data.Packages) -ccontains $script:ConcealmentSelectedPackage) 'The selected app is missing from the result.'
    Assert-Equal 1 @($applyResult.Data.Packages).Count 'Selected app concealment reported an unexpected package count.'
    Assert-Equal 'Completed' $applyJournal.State 'Selected app concealment did not complete its journal.'
    $reopenedApply = Get-OperationJournal -Path $applyJournal.JournalPath
    Assert-Equal 'Completed' $reopenedApply.State 'Selected app concealment did not persist its journal state.'
    Assert-True (@($reopenedApply.Result.Data.Packages) -ccontains $script:ConcealmentSelectedPackage) 'Selected app concealment did not persist its package scope.'
    Assert-Equal 3 @(@($applyResult.Data.Handoff) | ForEach-Object { @($_).Count } | Measure-Object -Sum).Sum 'Selected app concealment did not record the KernelSU handoff for the selected app.'
    $writtenConfig = $applyState.Files[$applyState.ConfigPath] | ConvertFrom-Json
    Assert-Equal 93 $writtenConfig.configVersion 'The written HMA configuration changed the supported version.'
    Assert-Equal $false $writtenConfig.templates.Root.isWhitelist 'The written HMA configuration turned the Root template into a whitelist.'
    Assert-True (@($writtenConfig.templates.Root.appList) -cnotcontains $script:ConcealmentSelectedPackage) 'The written HMA configuration leaked the selected app into the Root template.'
    Assert-True (@($writtenConfig.templates.Root.appList) -cnotcontains 'com.example.other') 'The written HMA configuration leaked an unselected app into the Root template.'
    Assert-Equal 'Root' $writtenConfig.apps.($script:ConcealmentSelectedPackage) 'The selected app was not assigned the Root template.'
    Assert-Equal 1 @($writtenConfig.apps.PSObject.Properties).Count 'The written HMA configuration assigned the template to another app.'
    Assert-Equal -1 (Get-ConcealmentCallIndex -Calls $applyState.Calls -Pattern '*pm uninstall*') 'Selected app concealment uninstalled a package.'
    Assert-Equal -1 (Get-ConcealmentCallIndex -Calls $applyState.Calls -Pattern '*pm disable*') 'Selected app concealment disabled a package.'
    $backupPath = [string]$applyResult.Data.BackupPath
    $writeCalls = @(Get-ConcealmentCalls -State $applyState -Pattern '*base64*')
    Assert-Equal 2 $writeCalls.Count 'Selected app concealment did not write exactly the configuration backup and the configuration.'
    Assert-True ((@($writeCalls[0]) -join ' ') -like ('*' + $backupPath + '*')) 'Selected app concealment did not write the configuration backup first.'
    Assert-True ((@($writeCalls[1]) -join ' ') -like ('*' + $applyState.ConfigPath + '*')) 'Selected app concealment did not write the configuration after its backup.'
    Assert-True ($backupPath.StartsWith($applyState.ConfigPath, [StringComparison]::Ordinal)) 'The recorded configuration backup is not beside the configuration.'
    Assert-Equal (New-ConcealmentConfigText -RootPackages @('com.example.legacy')) $applyState.Files[$backupPath] 'The configuration backup does not hold the original configuration.'

    $restoreResult = Set-ConcealmentGuestText -ManagerPath $install.ManagerPath -InstanceIndex $install.SourceIndex -Path $applyState.ConfigPath -Text $applyState.Files[$backupPath] -Runner (New-ConcealmentManagerRunner -State $applyState)
    Assert-Equal 'Success' $restoreResult.Status "The HMA configuration backup could not be restored. $($restoreResult.Message)"
    Assert-Equal (New-ConcealmentConfigText -RootPackages @('com.example.legacy')) $applyState.Files[$applyState.ConfigPath] 'The restored HMA configuration differs from the original configuration.'

    $multiState = New-ConcealmentGuestState -Install $install
    $multiState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentRootPackages[3], $script:ConcealmentSelectedPackage, 'com.example.other')
    $multiState.Files[$multiState.ConfigPath] = (New-ConcealmentConfigText)
    $multiResult = Set-AppConcealment -Instance $instance -Packages @($script:ConcealmentSelectedPackage, 'com.example.other', $script:ConcealmentSelectedPackage) -Journal (New-ConcealmentJournal -Root $journalRoot -Instance $instance) -Runner (New-ConcealmentManagerRunner -State $multiState)
    Assert-Equal 'Success' $multiResult.Status "Selected app concealment failed for two apps. $($multiResult.Message)"
    Assert-Equal 2 @($multiResult.Data.Packages).Count 'Duplicate selected packages were not collapsed.'
    $multiConfig = $multiState.Files[$multiState.ConfigPath] | ConvertFrom-Json
    Assert-Equal 2 @($multiConfig.apps.PSObject.Properties).Count 'Duplicate selected packages produced more than one assignment.'
    Assert-Equal 6 @(@($multiResult.Data.Handoff) | ForEach-Object { @($_).Count } | Measure-Object -Sum).Sum 'The KernelSU handoff did not cover every selected app once.'

    foreach ($defect in @(
            [pscustomobject]@{ Packages = @('*'); Label = 'a wildcard' },
            [pscustomobject]@{ Packages = @('.*'); Label = 'a dot wildcard' },
            [pscustomobject]@{ Packages = @('com.example.app;rm -rf /'); Label = 'a package with a shell fragment' },
            [pscustomobject]@{ Packages = @('com.example app'); Label = 'a package with a space' },
            [pscustomobject]@{ Packages = @('com..example'); Label = 'a package with an empty segment' },
            [pscustomobject]@{ Packages = @('comexample'); Label = 'a package with one segment' },
            [pscustomobject]@{ Packages = @('com.example.'); Label = 'a package with a trailing dot' },
            [pscustomobject]@{ Packages = @(''); Label = 'an empty package name' },
            [pscustomobject]@{ Packages = @('   '); Label = 'a blank package name' },
            [pscustomobject]@{ Packages = @('com.example.app', 'bad name'); Label = 'one invalid package among valid packages' }
        )) {
        $defectState = New-ConcealmentGuestState -Install $install
        $defectState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
        $defectState.Files[$defectState.ConfigPath] = (New-ConcealmentConfigText)
        $defectJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
        $defectResult = Set-AppConcealment -Instance $instance -Packages $defect.Packages -Journal $defectJournal -Runner (New-ConcealmentManagerRunner -State $defectState)
        Assert-ConcealmentFailure -Result $defectResult -Journal $defectJournal -Code 'PACKAGE_NAME_INVALID' -Message "An invalid package name was accepted: $($defect.Label)."
        Assert-Equal 0 @(Get-ConcealmentCalls -State $defectState -Pattern '*base64*').Count "An invalid package name still wrote the configuration: $($defect.Label)."
    }

    foreach ($emptySelection in @(@(), $null)) {
        $defectState = New-ConcealmentGuestState -Install $install
        $defectState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
        $defectState.Files[$defectState.ConfigPath] = (New-ConcealmentConfigText)
        $defectJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
        $defectResult = Set-AppConcealment -Instance $instance -Packages $emptySelection -Journal $defectJournal -Runner (New-ConcealmentManagerRunner -State $defectState)
        Assert-ConcealmentFailure -Result $defectResult -Journal $defectJournal -Code 'PACKAGES_REQUIRED' -Message 'An empty selected package list was accepted.'
        Assert-Equal 0 @(Get-ConcealmentCalls -State $defectState -Pattern '*base64*').Count 'An empty selected package list still wrote the configuration.'
    }

    $allState = New-ConcealmentGuestState -Install $install
    $allState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentRootPackages[3], $script:ConcealmentSelectedPackage)
    $allState.Files[$allState.ConfigPath] = (New-ConcealmentConfigText)
    $allJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $allResult = Set-AppConcealment -Instance $instance -Packages @($script:ConcealmentRootPackages[0], $script:ConcealmentRootPackages[3], $script:ConcealmentSelectedPackage) -Journal $allJournal -Runner (New-ConcealmentManagerRunner -State $allState)
    Assert-ConcealmentFailure -Result $allResult -Journal $allJournal -Code 'ALL_APPS_REFUSED' -Message 'A selection of every installed app was accepted.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $allState -Pattern '*base64*').Count 'A selection of every installed app still wrote the configuration.'

    $uninstalledState = New-ConcealmentGuestState -Install $install
    $uninstalledState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage, 'com.example.other')
    $uninstalledState.Files[$uninstalledState.ConfigPath] = (New-ConcealmentConfigText)
    $uninstalledJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $uninstalledResult = Set-AppConcealment -Instance $instance -Packages @($script:ConcealmentSelectedPackage, 'com.example.absent') -Journal $uninstalledJournal -Runner (New-ConcealmentManagerRunner -State $uninstalledState)
    Assert-ConcealmentFailure -Result $uninstalledResult -Journal $uninstalledJournal -Code 'PACKAGE_NOT_INSTALLED' -Message 'A package that is not installed was accepted.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $uninstalledState -Pattern '*base64*').Count 'A package that is not installed still wrote the configuration.'

    $unreadableState = New-ConcealmentGuestState -Install $install
    $unreadableState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
    $unreadableState.Files[$unreadableState.ConfigPath] = (New-ConcealmentConfigText)
    $unreadableState.AdbFailPattern = '*pm list packages*'
    $unreadableJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $unreadableResult = Set-AppConcealment -Instance $instance -Packages @($script:ConcealmentSelectedPackage) -Journal $unreadableJournal -Runner (New-ConcealmentManagerRunner -State $unreadableState)
    Assert-ConcealmentFailure -Result $unreadableResult -Journal $unreadableJournal -Code 'PACKAGE_LIST_UNREADABLE' -Message 'An unreadable package list was accepted.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $unreadableState -Pattern '*base64*').Count 'An unreadable package list still wrote the configuration.'

    $writeFailureState = New-ConcealmentGuestState -Install $install
    $writeFailureState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
    $writeFailureState.Files[$writeFailureState.ConfigPath] = (New-ConcealmentConfigText -RootPackages @('com.example.legacy'))
    $writeFailureState.WriteFailPattern = $writeFailureState.ConfigPath
    $writeFailureJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $writeFailureResult = Set-AppConcealment -Instance $instance -Packages @($script:ConcealmentSelectedPackage) -Journal $writeFailureJournal -Runner (New-ConcealmentManagerRunner -State $writeFailureState)
    Assert-ConcealmentFailure -Result $writeFailureResult -Journal $writeFailureJournal -Code 'GUEST_WRITE_FAILED' -Message 'A refused HMA configuration write was accepted.'
    Assert-Equal (New-ConcealmentConfigText -RootPackages @('com.example.legacy')) $writeFailureState.Files[$writeFailureState.ConfigPath] 'A refused HMA configuration write changed the configuration.'

    $guestWriteState = New-ConcealmentGuestState -Install $install
    $guestWriteState.WriteFailPattern = '*'
    $guestWriteJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $guestWriteResult = Set-ConcealmentGuestText -ManagerPath $install.ManagerPath -InstanceIndex $install.SourceIndex -Path $guestWriteState.ConfigPath -Text '{}' -Journal $guestWriteJournal -Runner (New-ConcealmentManagerRunner -State $guestWriteState)
    Assert-ConcealmentFailure -Result $guestWriteResult -Journal $guestWriteJournal -Code 'GUEST_WRITE_FAILED' -Message 'A refused guest file write was accepted.'
    $guestPathJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $guestPathResult = Set-ConcealmentGuestText -ManagerPath $install.ManagerPath -InstanceIndex $install.SourceIndex -Path 'not an absolute guest path' -Text '{}' -Journal $guestPathJournal -Runner (New-ConcealmentManagerRunner -State $guestWriteState)
    Assert-ConcealmentFailure -Result $guestPathResult -Journal $guestPathJournal -Code 'GUEST_WRITE_FAILED' -Message 'A guest file write accepted a path that is not absolute.'
    Assert-Equal 0 @($guestWriteState.Files.Keys).Count 'A refused guest file write stored a file.'

    $verificationState = New-ConcealmentGuestState -Install $install
    $verificationState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentRootPackages[1], $script:ConcealmentRootPackages[2], $script:ConcealmentRootPackages[3], $script:ConcealmentSelectedPackage)
    $verificationState.Files[$verificationState.ConfigPath] = (New-ConcealmentConfigText -Apps @{$script:ConcealmentSelectedPackage = 'Root'})
    $verificationState.Files[$script:ConcealmentKernelSUAllowlistPath] = 'kernel su allowlist bytes'
    $verificationResult = Test-Concealment -ManagerPath $install.ManagerPath -InstanceIndex $install.SourceIndex -Packages @($script:ConcealmentSelectedPackage) -Runner (New-ConcealmentManagerRunner -State $verificationState)
    Assert-Equal 'Success' $verificationResult.Status "Concealment verification failed. $($verificationResult.Message)"
    Assert-Equal 93 $verificationResult.Data.HmaConfigVersion 'Concealment verification reported the wrong HMA configuration version.'
    Assert-True (@($verificationResult.Data.InScope) -ccontains $script:ConcealmentSelectedPackage) 'Concealment verification did not report the selected app in HMA scope.'
    Assert-True (@($verificationResult.Data.TemplatePackages) -ccontains 'me.weishu.kernelsu') 'Concealment verification did not report the Root template contents.'
    Assert-Equal $true $verificationResult.Data.KernelSUInstalled 'Concealment verification did not report the KernelSU package.'
    Assert-Equal $true $verificationResult.Data.AllowlistPresent 'Concealment verification did not report the KernelSU allowlist file.'
    Assert-Equal $false $verificationResult.Data.ProfileStateObserved 'Concealment verification claimed to observe the KernelSU Superuser profile.'
    Assert-Equal 3 @(@($verificationResult.Data.Handoff) | ForEach-Object { @($_).Count } | Measure-Object -Sum).Sum 'Concealment verification did not report the KernelSU handoff steps.'
    Assert-True ($verificationResult.Message -match 'Umount modules') 'Concealment verification did not ask the operator to confirm Umount modules in the app.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $verificationState -Pattern '*base64*').Count 'Concealment verification wrote a file.'

    $outOfScopeState = New-ConcealmentGuestState -Install $install
    $outOfScopeState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
    $outOfScopeState.Files[$outOfScopeState.ConfigPath] = (New-ConcealmentConfigText)
    $outOfScopeResult = Test-Concealment -ManagerPath $install.ManagerPath -InstanceIndex $install.SourceIndex -Packages @($script:ConcealmentSelectedPackage) -Runner (New-ConcealmentManagerRunner -State $outOfScopeState)
    Assert-Equal 'Success' $outOfScopeResult.Status 'Concealment verification refused an unassigned app.'
    Assert-Equal 0 @($outOfScopeResult.Data.InScope).Count 'Concealment verification reported an unassigned app in HMA scope.'
    $absentAllowlistState = New-ConcealmentGuestState -Install $install
    $absentAllowlistState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
    $absentAllowlistState.Files[$absentAllowlistState.ConfigPath] = (New-ConcealmentConfigText -Apps @{$script:ConcealmentSelectedPackage = 'Root'})
    $absentAllowlistResult = Test-Concealment -ManagerPath $install.ManagerPath -InstanceIndex $install.SourceIndex -Packages @($script:ConcealmentSelectedPackage) -Runner (New-ConcealmentManagerRunner -State $absentAllowlistState)
    Assert-Equal 'Success' $absentAllowlistResult.Status 'Concealment verification refused a missing KernelSU allowlist file.'
    Assert-Equal $false $absentAllowlistResult.Data.AllowlistPresent 'Concealment verification reported a missing KernelSU allowlist file as present.'
    Assert-Equal $false $absentAllowlistResult.Data.KernelSUInstalled 'Concealment verification reported an absent KernelSU package as installed.'

    foreach ($verificationDefect in @(
            [pscustomobject]@{ ManagerPath = '   '; Packages = @($script:ConcealmentSelectedPackage); Label = 'a blank manager path' },
            [pscustomobject]@{ ManagerPath = 'C:\MuMu\shell\MuMuManager.exe'; Packages = @(); Label = 'an empty package list' },
            [pscustomobject]@{ ManagerPath = 'C:\MuMu\shell\MuMuManager.exe'; Packages = @('*'); Label = 'a wildcard package' }
        )) {
        $defectResult = Test-Concealment -ManagerPath $verificationDefect.ManagerPath -InstanceIndex $install.SourceIndex -Packages $verificationDefect.Packages -Runner $runner
        Assert-Equal 'CriticalError' $defectResult.Status "Concealment verification accepted $($verificationDefect.Label)."
        Assert-True ($script:ConcealmentCodes -ccontains [string]$defectResult.Data.Code) "Concealment verification reported an undocumented code for $($verificationDefect.Label)."
    }
    $negativeIndexResult = Test-Concealment -ManagerPath $install.ManagerPath -InstanceIndex -1 -Packages @($script:ConcealmentSelectedPackage) -Runner $runner
    Assert-Equal 'CriticalError' $negativeIndexResult.Status 'Concealment verification accepted a negative instance index.'
}

function Invoke-CommonTests {
    Assert-True ($null -ne (Get-Command Get-ToolkitLogPath -CommandType Function -ErrorAction SilentlyContinue)) 'Get-ToolkitLogPath is unavailable.'
    $logRoot = Join-Path $env:LOCALAPPDATA 'mumu-root-hide-toolkit\logs'
    $logPath = Get-ToolkitLogPath
    Assert-True ($logPath.StartsWith($logRoot, [StringComparison]::OrdinalIgnoreCase)) 'Log path is outside the per-user log directory.'
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('mumu-toolkit-tests-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$originalTestAppData = $env:APPDATA
$exitCode = 0
try {
    switch ($Suite) {
        'Manifest' {
            Invoke-ManifestTests
            Invoke-AssetTests
        }
        'Process' {
            Invoke-ProcessTests
        }
        'Result' {
            Invoke-ResultTests
        }
        'Journal' {
            Invoke-JournalTests
        }
        'Discovery' {
            Invoke-DiscoveryTests
        }
        'Safety' {
            Invoke-SafetyTests
        }
        'Ads' {
            Invoke-AdsTests
        }
        'Root12' {
            Invoke-Root12Tests
        }
        'Root15' {
            Invoke-Root15Tests
        }
        'Verification' {
            Invoke-VerificationTests
        }
        'Concealment' {
            Invoke-ConcealmentTests
        }
        'All' {
            Invoke-ManifestTests
            Invoke-AssetTests
            Invoke-ResultTests
            Invoke-ProcessTests
            Invoke-JournalTests
            Invoke-DiscoveryTests
            Invoke-SafetyTests
            Invoke-AdsTests
            Invoke-VerificationTests
            Invoke-ConcealmentTests
            Invoke-Root12Tests
            Invoke-Root15Tests
            Invoke-CommonTests
        }
    }
}
catch {
    Write-Output "FAIL ${Suite}: $($_.Exception.Message)"
    $exitCode = 1
}
finally {
    $env:APPDATA = $originalTestAppData
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
if ($exitCode -eq 0) {
    Write-Output 'ALL TESTS PASSED'
}
exit $exitCode
