[CmdletBinding()]
param(
    [ValidateSet('Manifest', 'Process', 'Result', 'Journal', 'Discovery', 'All')]
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
    Assert-Equal 'Chinese' $parsedSnapshot.Edition 'Registry snapshot parser changed Edition.'
    Assert-Equal 'NetEase' $parsedSnapshot.Publisher 'Registry snapshot parser changed Publisher.'

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
    $env:APPDATA = $previousAppData

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
        'All' {
            Invoke-ManifestTests
            Invoke-AssetTests
            Invoke-ResultTests
            Invoke-ProcessTests
            Invoke-JournalTests
            Invoke-DiscoveryTests
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
