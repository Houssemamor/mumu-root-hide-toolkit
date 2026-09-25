[CmdletBinding()]
param(
    [ValidateSet('Manifest', 'Process', 'Result', 'Journal', 'Discovery', 'Safety', 'Ads', 'All')]
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

    $restore = Restore-MuMuAds -BackupRoot $adsBackupRoot -Journal $adsJournal
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
    $readOnlyRestore = Restore-MuMuAds -BackupRoot $readOnlyBackupRoot -Journal $readOnlyJournal
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
    $noDisplayRestore = Restore-MuMuAds -BackupRoot $noDisplayBackupRoot -Journal $noDisplayJournal
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
        @{ Label = 'nonobject records'; Json = '{"campaigns":["alpha"]}' }
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
    $multiRestore = Restore-MuMuAds -BackupRoot $multiBackupRoot -Journal $multiJournal
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
    $secondInstallRestore = Restore-MuMuAds -BackupRoot $secondInstallBackupRoot -Journal $secondInstallJournal
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
    $sharedRestore = Restore-MuMuAds -BackupRoot $sharedBackupRoot -Journal $sharedJournal
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
    $tamperRestore = Restore-MuMuAds -BackupRoot $tamperBackupRoot -Journal $tamperJournal
    Assert-Equal 'CriticalError' $tamperRestore.Status 'A tampered campaign restore point was restored.'
    Assert-True ($tamperRestore.Message -match '(?i)hash|length') "The tampered restore point failure did not name the verification: $($tamperRestore.Message)"
    Assert-AdsUnchanged -Path $tamperCampaign -Expected $tamperSuppressedJson -Message 'A failed restore changed the campaign bytes.'
    Assert-True ([IO.File]::Exists($tamperBackupPath)) 'A failed restore deleted the tampered backup.'
    Assert-True ([IO.File]::Exists($tamperManifestPath)) 'A failed restore deleted the restore point manifest.'
    [IO.File]::WriteAllText($tamperBackupPath, $tamperCampaignJson)
    $repairedJournal = New-AdsJournal -Name 'journal tamper repaired'
    $repairedRestore = Restore-MuMuAds -BackupRoot $tamperBackupRoot -Journal $repairedJournal
    Assert-Equal 'Success' $repairedRestore.Status 'A repaired campaign restore point could not be restored.'
    Assert-AdsUnchanged -Path $tamperCampaign -Expected $tamperCampaignJson -Message 'A repaired restore did not return the original bytes.'

    [IO.File]::Delete($tamperBackupPath)
    $missingBackupJournal = New-AdsJournal -Name 'journal missing backup'
    $missingBackupRestore = Restore-MuMuAds -BackupRoot $tamperBackupRoot -Journal $missingBackupJournal
    Assert-Equal 'CriticalError' $missingBackupRestore.Status 'A restore point with a missing backup file was restored.'
    Assert-True ($missingBackupRestore.Message -match '(?i)missing') 'The missing restore point file failure did not name the missing file.'
    Assert-AdsUnchanged -Path $tamperCampaign -Expected $tamperCampaignJson -Message 'A failed restore with a missing backup changed the campaign bytes.'

    $restorePointCases = @(
        @{ Label = 'missing manifest'; Manifest = $null },
        @{ Label = 'malformed manifest'; Manifest = '{not-json' },
        @{ Label = 'array manifest'; Manifest = '[]' },
        @{ Label = 'wrong schema version'; Manifest = '{"SchemaVersion":2,"Records":[]}' },
        @{ Label = 'string schema version'; Manifest = '{"SchemaVersion":"1","Records":[]}' },
        @{ Label = 'missing records'; Manifest = '{"SchemaVersion":1}' },
        @{ Label = 'empty records'; Manifest = '{"SchemaVersion":1,"Records":[]}' },
        @{ Label = 'string records'; Manifest = '{"SchemaVersion":1,"Records":"alpha"}' },
        @{ Label = 'missing record property'; Manifest = '{"SchemaVersion":1,"Records":[{"Source":"C:\\fixture\\campaign.json","Backup":"C:\\fixture\\backup\\campaign.json","Sha256":"0000000000000000000000000000000000000000000000000000000000000000","ReadOnly":false}]}' },
        @{ Label = 'extra record property'; Manifest = '{"SchemaVersion":1,"Records":[{"Source":"C:\\fixture\\campaign.json","Backup":"C:\\fixture\\backup\\campaign.json","Sha256":"0000000000000000000000000000000000000000000000000000000000000000","ReadOnly":false,"Length":1,"Extra":true}]}' },
        @{ Label = 'invalid record hash'; Manifest = '{"SchemaVersion":1,"Records":[{"Source":"C:\\fixture\\campaign.json","Backup":"C:\\fixture\\backup\\campaign.json","Sha256":"not-a-hash","ReadOnly":false,"Length":1}]}' }
    )
    foreach ($restorePointCase in $restorePointCases) {
        $restorePointRoot = New-AdsBackupRoot -Name ('restore point ' + $restorePointCase.Label)
        if ($null -ne $restorePointCase.Manifest) {
            [IO.File]::WriteAllText((Join-Path $restorePointRoot 'restore-point.json'), $restorePointCase.Manifest)
        }
        $restorePointJournal = New-AdsJournal -Name ('restore point journal ' + $restorePointCase.Label)
        $restorePointResult = Restore-MuMuAds -BackupRoot $restorePointRoot -Journal $restorePointJournal
        Assert-Equal 'CriticalError' $restorePointResult.Status "An incomplete campaign restore point was accepted: $($restorePointCase.Label)"
        Assert-True (-not [string]::IsNullOrWhiteSpace($restorePointResult.Message)) "An incomplete campaign restore point returned no reason: $($restorePointCase.Label)"
        Assert-Equal 'Failed' $restorePointJournal.State "An incomplete campaign restore point did not journal the failure: $($restorePointCase.Label)"
    }

    $outsideAdsBackupPath = Join-Path $script:adsFixtureRoot 'outside campaign.json'
    [IO.File]::WriteAllText($outsideAdsBackupPath, $tamperCampaignJson)
    $outsideAdsBackupItem = New-Object IO.FileInfo($outsideAdsBackupPath)
    $escapedRecordRoot = New-AdsBackupRoot -Name 'restore point escaped record'
    $escapedRecordJson = [ordered]@{
        SchemaVersion = 1
        Records = @([ordered]@{
            Source   = $tamperCampaign
            Backup   = $outsideAdsBackupPath
            Sha256   = (Get-FileHash -LiteralPath $outsideAdsBackupPath -Algorithm SHA256).Hash
            ReadOnly = $false
            Length   = [long]$outsideAdsBackupItem.Length
        })
    }
    [IO.File]::WriteAllText((Join-Path $escapedRecordRoot 'restore-point.json'), ($escapedRecordJson | ConvertTo-Json -Depth 6))
    $escapedRecordJournal = New-AdsJournal -Name 'restore point escaped record journal'
    $escapedRecordRestore = Restore-MuMuAds -BackupRoot $escapedRecordRoot -Journal $escapedRecordJournal
    Assert-Equal 'CriticalError' $escapedRecordRestore.Status 'A restore point record outside the backup root was restored.'
    Assert-True ($escapedRecordRestore.Message -match '(?i)backup root|outside') 'The escaped restore point record failure did not name the backup root boundary.'
    Assert-AdsUnchanged -Path $tamperCampaign -Expected $tamperCampaignJson -Message 'An escaped restore point record changed the campaign bytes.'

    $missingRecordRoot = New-AdsBackupRoot -Name 'restore point missing record file'
    $missingRecordJson = [ordered]@{
        SchemaVersion = 1
        Records = @([ordered]@{
            Source   = $tamperCampaign
            Backup   = (Join-Path $missingRecordRoot 'missing campaign.json')
            Sha256   = (Get-ToolkitFileSha256 -Path $outsideAdsBackupPath)
            ReadOnly = $false
            Length   = [long]$outsideAdsBackupItem.Length
        })
    }
    [IO.File]::WriteAllText((Join-Path $missingRecordRoot 'restore-point.json'), ($missingRecordJson | ConvertTo-Json -Depth 6))
    $missingRecordJournal = New-AdsJournal -Name 'restore point missing record file journal'
    $missingRecordRestore = Restore-MuMuAds -BackupRoot $missingRecordRoot -Journal $missingRecordJournal
    Assert-Equal 'CriticalError' $missingRecordRestore.Status 'A restore point record with a missing backup file was restored.'
    Assert-True ($missingRecordRestore.Message -match '(?i)missing') 'The missing restore point backup file failure did not name the missing file.'

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
    $relinkedRestore = Restore-MuMuAds -BackupRoot $relinkedAdsBackupRoot -Journal $relinkedRestoreJournal
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
    Assert-Equal 'CriticalError' (Restore-MuMuAds -BackupRoot $validRequestBackupRoot -Journal $null).Status 'A campaign restore without a journal was accepted.'
    Assert-Equal 0 @(Get-AdsRestorePointFile -BackupRoot $validRequestBackupRoot).Count 'A refused campaign request created a restore point.'
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
        'All' {
            Invoke-ManifestTests
            Invoke-AssetTests
            Invoke-ResultTests
            Invoke-ProcessTests
            Invoke-JournalTests
            Invoke-DiscoveryTests
            Invoke-SafetyTests
            Invoke-AdsTests
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
