[CmdletBinding()]
param(
    [ValidateSet('Manifest', 'Process', 'Result', 'Journal', 'Discovery', 'Safety', 'Transport', 'Ads', 'Root12', 'Root15', 'Verification', 'Concealment', 'Target', 'Menu', 'Docs', 'All')]
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
$targetScriptPath = Join-Path $repoRoot 'src\Target.ps1'
$controllerScriptPath = Join-Path $repoRoot 'src\Invoke-MumuToolkit.ps1'
$launcherPath = Join-Path $repoRoot 'Run-MumuToolkit.bat'

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
if (Test-Path -LiteralPath $targetScriptPath -PathType Leaf) {
    . $targetScriptPath
}
if (Test-Path -LiteralPath $controllerScriptPath -PathType Leaf) {
    . $controllerScriptPath
}

# A read-only retry pauses between attempts in production, so the suite overrides that pause the
# same way it overrides the boot poll pause. The bound itself is asserted in the transport suite.
$script:ToolkitReadOnlyDelaySeconds = 0

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
            Version = 'v2.2'
            AssetName = 'Vector-v2.2-3080-Release.zip'
            Url = 'https://github.com/JingMatrix/Vector/releases/download/v2.2/Vector-v2.2-3080-Release.zip'
            Size = [long]9316843
            Sha256 = '9ee8323575d615f7b3f1076ff60b2a63a49390ef11881b52632311a37f6f79cc'
        },
        [pscustomobject]@{
            Id = 'neozygisk'
            Version = 'v2.4'
            AssetName = 'NeoZygisk-v2.4-289-release.zip'
            Url = 'https://github.com/JingMatrix/NeoZygisk/releases/download/v2.4/NeoZygisk-v2.4-289-release.zip'
            Size = [long]2401208
            Sha256 = '93a1425c67bb89f58a0dcb9fc823ec93f6472214f221e667a70b67c6a6e061a1'
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

function Invoke-TransportTests {
    $timeoutConstant = Get-Variable -Name 'ToolkitProcessTimeoutSeconds' -Scope Script -ErrorAction SilentlyContinue
    Assert-True ($null -ne $timeoutConstant) 'The external process timeout constant is missing.'
    Assert-True ([int]$timeoutConstant.Value -ge 30 -and [int]$timeoutConstant.Value -le 600) "The external process timeout is not a defensible bound: $($timeoutConstant.Value)"
    Assert-True ([int]$script:ToolkitReadOnlyAttempts -ge 2) 'The read-only retry is not bounded above one attempt.'
    Assert-True ([int]$script:ToolkitReadOnlyAttempts -le 10) 'The read-only retry bound is not bounded.'
    # The suite overrides the pause to keep the run short, so the shipped default is asserted on
    # the source rather than on the overridden value.
    Assert-True ([IO.File]::ReadAllText($commonPath) -match 'ToolkitReadOnlyDelaySeconds\s*=\s*([1-9][0-9]*)\b') 'The read-only retry has no pause between attempts.'

    $powershellPath = Join-Path $PSHOME 'powershell.exe'
    $normalChild = Invoke-CheckedProcess -FilePath $powershellPath -ArgumentList @('-NoProfile', '-NonInteractive', '-Command', "[Console]::Out.WriteLine('fixture stdout'); [Console]::Error.WriteLine('fixture stderr'); exit 3")
    Assert-Equal 3 $normalChild.ExitCode 'A child that exited on its own did not report its real exit code.'
    Assert-True ($normalChild.Text -match 'fixture stdout') 'The success path lost the captured standard output.'
    Assert-True ($normalChild.Text -match 'fixture stderr') 'The success path lost the captured standard error.'

    # A payload far larger than any pipe buffer completes only when both streams are drained while
    # the child is still running, so this is the case that would hang on a naive bounded wait.
    $largeChild = Invoke-CheckedProcess -FilePath $powershellPath -TimeoutSeconds 120 -ArgumentList @('-NoProfile', '-NonInteractive', '-Command', "1..48 | ForEach-Object { [Console]::Out.Write('x' * 65536) }; 1..16 | ForEach-Object { [Console]::Error.Write('y' * 65536) }; exit 0")
    Assert-Equal 0 $largeChild.ExitCode 'A child with a large output did not exit instead of deadlocking.'
    Assert-True ($largeChild.Text.Length -ge (64 * 65536)) "A large output payload was truncated: $($largeChild.Text.Length)"

    $childPidPath = Join-Path $testRoot 'timeout child pid.txt'
    $childPidArgument = $childPidPath.Replace("'", "''")
    $wedgedChild = Invoke-CheckedProcess -FilePath $powershellPath -TimeoutSeconds 2 -ArgumentList @('-NoProfile', '-NonInteractive', '-Command', "[IO.File]::WriteAllText('$childPidArgument', [string]`$PID); Start-Sleep -Seconds 300; [IO.File]::WriteAllText('$childPidArgument', 'survived')")
    Assert-Equal -1 $wedgedChild.ExitCode 'A child that outlived the timeout was not reported as a transport failure.'
    Assert-True ($wedgedChild.Text -match 'timeout') "The timeout failure does not name the timeout: $($wedgedChild.Text)"
    Assert-True ($wedgedChild.Text -match '2 second') "The timeout failure does not name the timeout value: $($wedgedChild.Text)"
    $wedgedChildId = 0
    Assert-True ([int]::TryParse([IO.File]::ReadAllText($childPidPath), [ref]$wedgedChildId)) 'The timed-out child did not report its own process id.'
    $wedgedChildAlive = $true
    for ($poll = 0; $poll -lt 20 -and $wedgedChildAlive; $poll++) {
        $wedgedChildAlive = ($null -ne (Get-Process -Id $wedgedChildId -ErrorAction SilentlyContinue))
        if ($wedgedChildAlive) {
            Start-Sleep -Milliseconds 250
        }
    }
    Assert-True (-not $wedgedChildAlive) 'A child that outlived the timeout was not terminated.'

    $transientState = @{ Count = 0 }
    $transientRunner = {
        param($ActualFilePath, $ActualArgumentList)
        $transientState.Count++
        if ($transientState.Count -lt 3) {
            return [pscustomobject]@{ ExitCode = -1; Text = 'Process launch failed: the manager is busy' }
        }
        return [pscustomobject]@{ ExitCode = 0; Text = '1' }
    }.GetNewClosure()
    $retriedProbe = Invoke-ToolkitManagerAdb -ManagerPath 'C:\MuMu\shell\MuMuManager.exe' -InstanceIndex 0 -Command 'shell getprop sys.boot_completed' -Runner $transientRunner
    Assert-Equal 0 $retriedProbe.ExitCode 'A read-only guest command that failed transiently did not succeed on a later attempt.'
    Assert-Equal 3 $transientState.Count 'A read-only guest command was not retried to its bound.'

    $stoppedState = @{ Count = 0 }
    $stoppedRunner = {
        param($ActualFilePath, $ActualArgumentList)
        $stoppedState.Count++
        if ($stoppedState.Count -lt 2) {
            return [pscustomobject]@{ ExitCode = 201; Text = 'adb: no running instance' }
        }
        return [pscustomobject]@{ ExitCode = 0; Text = 'module' }
    }.GetNewClosure()
    $stoppedProbe = Invoke-ToolkitManagerAdb -ManagerPath 'C:\MuMu\shell\MuMuManager.exe' -InstanceIndex 0 -Command 'shell ls /data/adb/modules' -Runner $stoppedRunner
    Assert-Equal 0 $stoppedProbe.ExitCode 'A read-only guest command against a stopped instance did not succeed on a later attempt.'
    Assert-Equal 2 $stoppedState.Count 'A not-started transient was not retried.'

    $exhaustedState = @{ Count = 0 }
    $exhaustedRunner = {
        param($ActualFilePath, $ActualArgumentList)
        $exhaustedState.Count++
        [pscustomobject]@{ ExitCode = -1; Text = 'The process did not exit within the 120 second timeout and was terminated.' }
    }.GetNewClosure()
    $exhausted = Get-ToolkitRootSetting -ManagerPath 'C:\MuMu\shell\MuMuManager.exe' -Index 0 -Runner $exhaustedRunner
    Assert-Equal 3 $exhaustedState.Count 'An exhausted read-only manager query did not stop at its bound.'
    Assert-Equal 'RecoverableError' $exhausted.Status 'An exhausted read-only query did not report the recoverable path.'
    Assert-True ($exhausted.Message -match '120 second timeout') "The exhausted retry lost the underlying error: $($exhausted.Message)"
    Assert-Equal 2 (Get-ToolkitExitCode $exhausted) 'An exhausted read-only query did not map to the recoverable exit code.'

    $semanticState = @{ Count = 0 }
    $semanticRunner = {
        param($ActualFilePath, $ActualArgumentList)
        $semanticState.Count++
        [pscustomobject]@{ ExitCode = 1; Text = '{"error_code":1}' }
    }.GetNewClosure()
    $semantic = Get-ToolkitRootSetting -ManagerPath 'C:\MuMu\shell\MuMuManager.exe' -Index 0 -Runner $semanticRunner
    Assert-Equal 'CriticalError' $semantic.Status 'A semantic refusal was reported as a recoverable error.'
    Assert-Equal 1 $semanticState.Count 'A semantic refusal was retried.'

    foreach ($mutationCommand in @(
            'install -r /data/local/tmp/app.apk'
            'push /data/local/tmp/vector.zip /data/local/tmp/staged.zip'
            "su -c rm -rf /data/adb/modules/zygisk_vector"
            'shell monkey -p io.github.huskydg.magisk -c android.intent.category.LAUNCHER 1'
        )) {
        $mutationState = @{ Count = 0 }
        $mutationRunner = {
            param($ActualFilePath, $ActualArgumentList)
            $mutationState.Count++
            [pscustomobject]@{ ExitCode = -1; Text = 'Process launch failed: the manager is busy' }
        }.GetNewClosure()
        $mutation = Invoke-ToolkitManagerAdb -ManagerPath 'C:\MuMu\shell\MuMuManager.exe' -InstanceIndex 0 -Command $mutationCommand -Runner $mutationRunner
        Assert-Equal 1 $mutationState.Count "A mutation was retried: $mutationCommand"
        Assert-Equal -1 $mutation.ExitCode "A failed mutation did not report its own transport failure: $mutationCommand"
    }
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

function New-DiscoveryVmsChildren {
    param(
        [string]$VmsPath,
        [string[]]$ChildNames
    )

    [void][IO.Directory]::CreateDirectory($VmsPath)
    foreach ($childName in $ChildNames) {
        [void][IO.Directory]::CreateDirectory((Join-Path $VmsPath $childName))
    }
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

    # A real uninstall row can carry no VMS value at all; that means infer it, not reject the row.
    $liveRowRoot = Join-Path $discoveryRoot 'Live Row\MuMuPlayer'
    $liveRowVms = Join-Path $liveRowRoot 'vms'
    $liveRowFixture = New-DiscoveryInstallFixture -InstallRoot $liveRowRoot -VmsPath $liveRowVms
    $script:discoveryRegistryEntries = @($script:discoveryRegistryEntries) + @(
        [pscustomobject]@{
            Root = 'FixtureRegistry:\LiveNoVmsPath'
            DisplayName = 'MuMuPlayer'
            Publisher = 'NetEase'
            InstallLocation = $liveRowFixture.InstallRoot
            Edition = 'Chinese'
        },
        [pscustomobject]@{
            Root = 'FixtureRegistry:\LiveBlankVmsPath'
            DisplayName = 'MuMuPlayer'
            Publisher = 'NetEase'
            InstallLocation = $liveRowFixture.InstallRoot
            Edition = 'Chinese'
            VmsPath = ''
        },
        [pscustomobject]@{
            Root = 'FixtureRegistry:\LiveNonStringVmsPath'
            DisplayName = 'MuMuPlayer'
            Publisher = 'NetEase'
            InstallLocation = $liveRowFixture.InstallRoot
            Edition = 'Chinese'
            VmsPath = 42
        }
    )
    $absentPropertySnapshot = ConvertFrom-ToolkitUninstallSnapshot -Snapshot ([pscustomobject]@{
            InstallLocation = $liveRowFixture.InstallRoot
            DisplayName = 'MuMuPlayer'
            Publisher = 'NetEase'
            Edition = 'Chinese'
        })
    Assert-Equal '' $absentPropertySnapshot.VmsPath 'A snapshot without a VmsPath property did not normalize to an empty value.'
    $liveRowAppData = $env:APPDATA
    $env:APPDATA = Join-Path $fixtureProfileRoot 'empty'
    try {
        foreach ($absentVmsRoot in @('FixtureRegistry:\LiveNoVmsPath', 'FixtureRegistry:\LiveBlankVmsPath')) {
            $absentVmsResult = @(Find-MuMuInstallations -Edition 'All' -RegistryRoots @($absentVmsRoot) -ProcessSnapshot @() -FallbackRoots @())
            $absentVmsStatus = Get-DiscoveryResultStatus $absentVmsResult[0]
            $absentVmsMessage = ''
            if ($absentVmsStatus -eq 'CriticalError') {
                $absentVmsMessage = ': ' + $absentVmsResult[0].Message
            }
            Assert-Equal 1 $absentVmsResult.Count "A registry row without a usable VMS value was not discovered$absentVmsMessage"
            Assert-True ($absentVmsStatus -ne 'CriticalError') "A registry row without a usable VMS value was rejected$absentVmsMessage"
            Assert-Equal $liveRowVms $absentVmsResult[0].VmsPath "A registry row without a usable VMS value did not use the inferred VMS path$absentVmsMessage"
            Assert-Equal 'Chinese' $absentVmsResult[0].Edition "A registry row without a usable VMS value lost its edition$absentVmsMessage"
        }
    }
    finally {
        $env:APPDATA = $liveRowAppData
    }
    $nonStringVmsResult = Find-MuMuInstallations -Edition 'All' -RegistryRoots @('FixtureRegistry:\LiveNonStringVmsPath') -ProcessSnapshot @() -FallbackRoots @()
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $nonStringVmsResult) 'A non-string registry VMS value was accepted.'

    # A real Global layout keeps base-only staging roots next to the root that holds the instances.
    $layoutAppData = $env:APPDATA
    $env:APPDATA = Join-Path $fixtureProfileRoot 'empty'
    try {
        $layoutRoot = Join-Path $discoveryRoot 'Real Layout\MuMuPlayer'
        $layoutVms = Join-Path $layoutRoot 'vms'
        $layoutFixture = New-DiscoveryInstallFixture -InstallRoot $layoutRoot -VmsPath $layoutVms
        New-DiscoveryVmsChildren -VmsPath $layoutVms -ChildNames @(
            'MuMuPlayerGlobal-12.0-0',
            'MuMuPlayerGlobal-15.0-1',
            'MuMuPlayerGlobal-15.0-2',
            'MuMuPlayerGlobal-12.0-base'
        )
        New-DiscoveryVmsChildren -VmsPath (Join-Path $layoutRoot 'nx_device\12.0\vms') -ChildNames @('MuMuPlayerGlobal-12.0-base')
        New-DiscoveryVmsChildren -VmsPath (Join-Path $layoutRoot 'nx_device\15.0\vms') -ChildNames @('MuMuPlayerGlobal-15.0-base')
        $script:discoveryRegistryEntries = @($script:discoveryRegistryEntries) + @(
            [pscustomobject]@{
                Root = 'FixtureRegistry:\RealLayout'
                DisplayName = 'MuMuPlayer'
                Publisher = 'NetEase'
                InstallLocation = $layoutFixture.InstallRoot
                Edition = 'Chinese'
            }
        )
        $layoutResult = @(Find-MuMuInstallations -Edition 'All' -RegistryRoots @('FixtureRegistry:\RealLayout') -ProcessSnapshot @() -FallbackRoots @())
        $layoutStatus = Get-DiscoveryResultStatus $layoutResult[0]
        $layoutMessage = ''
        if ($layoutStatus -eq 'CriticalError') {
            $layoutMessage = ': ' + $layoutResult[0].Message
        }
        Assert-Equal 1 $layoutResult.Count "The real Global layout was not discovered$layoutMessage"
        Assert-True ($layoutStatus -ne 'CriticalError') "The real Global layout was rejected$layoutMessage"
        Assert-Equal $layoutVms $layoutResult[0].VmsPath "The real Global layout did not select the VMS root that holds the instances$layoutMessage"

        $twoRealRootsFixture = New-DiscoveryInstallFixture -InstallRoot (Join-Path $discoveryRoot 'Two Real Roots\MuMu Global') -VmsPath (Join-Path $discoveryRoot 'Two Real Roots\MuMu Global\vms')
        New-DiscoveryVmsChildren -VmsPath (Join-Path $twoRealRootsFixture.InstallRoot 'vms') -ChildNames @('MuMuPlayerGlobal-15.0-1')
        New-DiscoveryVmsChildren -VmsPath (Join-Path $twoRealRootsFixture.InstallRoot 'nx_device\15.0\vms') -ChildNames @('MuMuPlayerGlobal-15.0-2')
        $twoRealRootsResult = Find-MuMuInstallations -Edition 'All' -RegistryRoots @() -ProcessSnapshot @() -FallbackRoots @($twoRealRootsFixture.InstallRoot)
        Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus $twoRealRootsResult) 'Two VMS roots that both hold instances were merged silently.'

        $versionedOnlyFixture = New-DiscoveryInstallFixture -InstallRoot (Join-Path $discoveryRoot 'Versioned Only\MuMu Global') -VmsPath (Join-Path $discoveryRoot 'Versioned Only\MuMu Global\nx_device\12.0\vms')
        New-DiscoveryVmsChildren -VmsPath $versionedOnlyFixture.VmsPath -ChildNames @('MuMuPlayerGlobal-12.0-3', 'MuMuPlayerGlobal-12.0-base')
        $versionedOnlyResult = @(Find-MuMuInstallations -Edition 'All' -RegistryRoots @() -ProcessSnapshot @() -FallbackRoots @($versionedOnlyFixture.InstallRoot))
        $versionedOnlyStatus = Get-DiscoveryResultStatus $versionedOnlyResult[0]
        $versionedOnlyMessage = ''
        if ($versionedOnlyStatus -eq 'CriticalError') {
            $versionedOnlyMessage = ': ' + $versionedOnlyResult[0].Message
        }
        Assert-Equal 1 $versionedOnlyResult.Count "A versioned-only VMS root was not discovered$versionedOnlyMessage"
        Assert-True ($versionedOnlyStatus -ne 'CriticalError') "A versioned-only VMS root was rejected$versionedOnlyMessage"
        Assert-Equal $versionedOnlyFixture.VmsPath $versionedOnlyResult[0].VmsPath "A versioned-only VMS root was not selected$versionedOnlyMessage"
    }
    finally {
        $env:APPDATA = $layoutAppData
    }

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

    $numericKeyInfo = @'
{
  "0": { "index": "0", "name": "MuMuPlayerGlobal-12.0-0", "android_version": "12.0", "is_main": "true", "is_process_started": "false", "is_android_started": "false", "disk_size_bytes": 0, "error_code": 0, "hyperv_enabled": false },
  "1": { "index": "1", "name": "MuMuPlayerGlobal-15.0-1", "android_version": "15.0", "is_main": "false", "is_process_started": "true", "is_android_started": "true", "disk_size_bytes": 21474836480, "error_code": 0, "hyperv_enabled": true },
  "2": { "index": "2", "name": "MuMuPlayerGlobal-15.0-2", "android_version": "15.0", "is_main": "false", "is_process_started": "false", "is_android_started": "false", "disk_size_bytes": 21474836480, "error_code": 0, "hyperv_enabled": true }
}
'@
    $numericKeyCase = Invoke-DiscoveryManagerCase -Name 'numeric-key-map' -InfoJson $numericKeyInfo
    $numericKeyInstances = @($numericKeyCase.Result)
    $numericKeyStatus = Get-DiscoveryResultStatus $numericKeyInstances[0]
    $numericKeyMessage = ''
    if ($numericKeyStatus -eq 'CriticalError') {
        $numericKeyMessage = ': ' + $numericKeyInstances[0].Message
    }
    Assert-True ($numericKeyStatus -ne 'CriticalError') "A numeric-key manager map was rejected$numericKeyMessage"
    Assert-Equal 3 $numericKeyInstances.Count "A numeric-key manager map did not report every instance$numericKeyMessage"
    Assert-Equal 0 $numericKeyInstances[0].Index 'A numeric-key manager map reported the wrong first index.'
    Assert-Equal 'MuMuPlayerGlobal-12.0-0' $numericKeyInstances[0].Name 'A numeric-key manager map reported the wrong first name.'
    Assert-Equal '12.0' $numericKeyInstances[0].AndroidVersion 'A numeric-key manager map reported the wrong first Android version.'
    Assert-Equal 1 $numericKeyInstances[1].Index 'A numeric-key manager map reported the wrong second index.'
    Assert-Equal 'MuMuPlayerGlobal-15.0-1' $numericKeyInstances[1].Name 'A numeric-key manager map reported the wrong second name.'
    Assert-Equal 2 $numericKeyInstances[2].Index 'A numeric-key manager map reported the wrong third index.'
    Assert-Equal 'MuMuPlayerGlobal-15.0-2' $numericKeyInstances[2].Name 'A numeric-key manager map reported the wrong third name.'
    Assert-Equal '15.0' $numericKeyInstances[2].AndroidVersion 'A numeric-key manager map reported the wrong third Android version.'
    Assert-Equal $false $numericKeyInstances[0].Eligible 'A numeric-key manager map base instance is eligible.'
    Assert-Equal $true $numericKeyInstances[2].Eligible 'A numeric-key manager map supported instance is not eligible.'

    $numericKeyInvalidInfo = '{"0":{"index":"0","name":"MuMuPlayerGlobal-12.0-0","android_version":"12.0","is_main":"true","is_process_started":"false"},"1":"MuMuPlayerGlobal-15.0-1"}'
    $numericKeyInvalidCase = Invoke-DiscoveryManagerCase -Name 'numeric-key-invalid' -InfoJson $numericKeyInvalidInfo
    Assert-Equal 'CriticalError' (Get-DiscoveryResultStatus @($numericKeyInvalidCase.Result)[0]) 'A numeric-key manager map with a non-record value was accepted.'
    Assert-True (@($numericKeyInvalidCase.Result)[0].Message -match '(?i)json') 'A numeric-key manager map with a non-record value omitted field context.'
    $numericKeyInvalidArguments = @()
    if ([IO.File]::Exists($numericKeyInvalidCase.ArgumentsPath)) {
        $numericKeyInvalidArguments = @([IO.File]::ReadAllLines($numericKeyInvalidCase.ArgumentsPath))
    }
    Assert-Equal 1 $numericKeyInvalidArguments.Count "A rejected numeric-key manager map issued more than the single enumeration: $($numericKeyInvalidArguments -join '|')"
    Assert-Equal 'info|-v|all' $numericKeyInvalidArguments[0] "A rejected numeric-key manager map issued an unexpected manager command: $($numericKeyInvalidArguments -join '|')"

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
        RootPermission = 'false'
        ControlExitCode = 0
        CloneExitCode = 0
        ShutdownSettles = $true
        CloneIndex = 4
        CloneName = 'Target clone'
        CloneAndroid = '12.0'
        CloneCreatesDisk = $true
        CloneVmsPath = ''
        CreateExitCode = 0
        CreateIndexes = @()
        CreateName = 'Created instance'
        CreateAndroid = '12.0'
        CreateIsMain = $false
        CreateRootName = ''
        CreateCreatesRoot = $true
        CreateCreatesDisk = $true
        CreateVmsPath = ''
    }
}

function New-SafetyManagerRunner {
    param([hashtable]$State)

    return {
        param($ActualFilePath, $ActualArgumentList)
        $State.Calls += ,@($ActualArgumentList)
        $command = [string]$ActualArgumentList[0]
        if ($command -eq 'setting') {
            return [pscustomobject]@{ ExitCode = 0; Text = ('{"root_permission":"' + $State.RootPermission + '"}') }
        }
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
        if ($command -eq 'create') {
            if ($State.CreateExitCode -ne 0) {
                return [pscustomobject]@{ ExitCode = $State.CreateExitCode; Text = '{"error_code":1}' }
            }
            $createdInstances = @()
            foreach ($createdIndex in @($State.CreateIndexes)) {
                $createdVmsPath = [string]$State.CreateVmsPath
                if ([string]::IsNullOrWhiteSpace($createdVmsPath)) {
                    $createdVmsPath = [string]$State.VmsPath
                }
                $createdRootName = [string]$State.CreateRootName
                if ([string]::IsNullOrWhiteSpace($createdRootName)) {
                    $createdRootName = [string]$createdIndex
                }
                else {
                    $createdRootName = $createdRootName -f $createdIndex
                }
                $createdRoot = Join-Path $createdVmsPath $createdRootName
                if ($State.CreateCreatesRoot) {
                    New-Item -ItemType Directory -Path $createdRoot -Force | Out-Null
                    if ($State.CreateCreatesDisk) {
                        [IO.File]::WriteAllText((Join-Path $createdRoot 'system.img'), 'create disk payload')
                    }
                }
                $createdInstances += [pscustomobject]@{
                    Index = [string]$createdIndex
                    Name = [string]$State.CreateName
                    IsMain = $State.CreateIsMain
                    Running = $false
                    Android = [string]$State.CreateAndroid
                    VmsPath = [string]$State.CreateVmsPath
                }
            }
            $State.Instances = @($State.Instances) + $createdInstances
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

    # The elevated child may only run a script this toolkit ships, so the boundary is the directory
    # that holds the elevation module. The suite points that boundary at a fixture source root, and a
    # junction under it proves a reparse-point escape is refused rather than followed.
    $elevationSourceRoot = Join-Path $testRoot 'elevation source'
    New-Item -ItemType Directory -Path $elevationSourceRoot -Force | Out-Null
    $elevationEscapeRoot = Join-Path $testRoot 'elevation escape'
    New-Item -ItemType Directory -Path $elevationEscapeRoot -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $elevationEscapeRoot 'escaped action.ps1'), 'exit 0')
    New-Item -ItemType Junction -Path (Join-Path $elevationSourceRoot 'linked') -Target $elevationEscapeRoot | Out-Null
    $realSourceRoot = $script:ToolkitSourceRoot
    $script:ToolkitSourceRoot = [IO.Path]::GetFullPath($elevationSourceRoot)

    $fakeScript = Join-Path $elevationSourceRoot 'elevated child action.ps1'
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
    $missingScript = Invoke-ElevatedToolkitAction -ScriptPath (Join-Path $elevationSourceRoot 'missing action.ps1') -Arguments @() -Runner $unreachableRunner
    Assert-Equal 'CriticalError' $missingScript.Status 'A missing elevated action path was accepted.'
    $nonScriptAction = Join-Path $elevationSourceRoot 'not-a-script.txt'
    [IO.File]::WriteAllText($nonScriptAction, 'fixture')
    $wrongTypeScript = Invoke-ElevatedToolkitAction -ScriptPath $nonScriptAction -Arguments @() -Runner $unreachableRunner
    Assert-Equal 'CriticalError' $wrongTypeScript.Status 'A non-PowerShell elevated action was accepted.'
    $actionDirectory = Join-Path $elevationSourceRoot 'action directory.ps1'
    New-Item -ItemType Directory -Path $actionDirectory -Force | Out-Null
    $directoryScript = Invoke-ElevatedToolkitAction -ScriptPath $actionDirectory -Arguments @() -Runner $unreachableRunner
    Assert-Equal 'CriticalError' $directoryScript.Status 'An elevated action directory was accepted.'

    # An elevated child runs one script from a Base64 payload, so the payload must not be able to name
    # a script outside this toolkit's own source directory, directly or through a reparse point.
    $outsideScript = Join-Path $testRoot 'outside action.ps1'
    [IO.File]::WriteAllText($outsideScript, 'exit 0')
    $outsideRefused = Invoke-ElevatedToolkitAction -ScriptPath $outsideScript -Arguments @() -Runner $unreachableRunner
    Assert-Equal 'CriticalError' $outsideRefused.Status 'An elevated action outside the toolkit source directory was accepted.'
    $escapedScript = Join-Path $elevationSourceRoot 'linked\escaped action.ps1'
    $escapedRefused = Invoke-ElevatedToolkitAction -ScriptPath $escapedScript -Arguments @() -Runner $unreachableRunner
    Assert-Equal 'CriticalError' $escapedRefused.Status 'An elevated action reached through a reparse point outside the source directory was accepted.'
    $siblingScript = Join-Path (Split-Path -Parent $elevationSourceRoot) 'sibling action.ps1'
    [IO.File]::WriteAllText($siblingScript, 'exit 0')
    $siblingRefused = Invoke-ElevatedToolkitAction -ScriptPath $siblingScript -Arguments @() -Runner $unreachableRunner
    Assert-Equal 'CriticalError' $siblingRefused.Status 'An elevated action beside the source directory was accepted.'
    Assert-Throws { New-ToolkitElevatedArgumentList -ScriptPath $outsideScript -Arguments @() } 'An elevated child payload was built for a script outside the source directory.'
    Assert-Throws { New-ToolkitElevatedArgumentList -ScriptPath $escapedScript -Arguments @() } 'An elevated child payload was built for a reparse-point escape.'
    Assert-Equal 0 $emptyRunnerState.Count 'A refused elevated action request reached the process runner.'

    # A permission failure is the only outcome that may ask for rights, so it is recognized by an
    # explicit code or an access-denied message and by nothing else.
    Assert-True ($null -ne (Get-Command Test-ToolkitPermissionFailure -CommandType Function -ErrorAction SilentlyContinue)) 'Test-ToolkitPermissionFailure is unavailable.'
    $accessDeniedMessage = 'Campaign replacement failed: Access to the path ''D:\MuMu Global\shell\ad\campaign.json'' is denied.'
    Assert-Equal $true (Test-ToolkitPermissionFailure -Result (Get-ToolkitResult -Status 'CriticalError' -Message $accessDeniedMessage -Data (@{ Code = 'CAMPAIGN_REPLACE_FAILED' }))) 'An access-denied campaign write was not recognized as a permission failure.'
    Assert-Equal $true (Test-ToolkitPermissionFailure -Result (Get-ToolkitResult -Status 'CriticalError' -Message 'UnauthorizedAccessException: the file is locked by another process.')) 'An UnauthorizedAccessException was not recognized as a permission failure.'
    Assert-Equal $false (Test-ToolkitPermissionFailure -Result (Get-ToolkitResult -Status 'CriticalError' -Message 'The campaign backup root already contains a restore point. An existing backup is never overwritten.')) 'A semantic refusal was treated as a permission failure.'
    Assert-Equal $false (Test-ToolkitPermissionFailure -Result (Get-ToolkitResult -Status 'Success' -Message 'Suppressed 1 campaign file(s) and skipped 0.')) 'A success was treated as a permission failure.'
    Assert-Equal $false (Test-ToolkitPermissionFailure -Result $null) 'A missing result was treated as a permission failure.'

    # The elevated child repeats the caller's own request, so consent and every bound parameter
    # survive the relaunch and the child is told it must not ask for rights again.
    Assert-True ($null -ne (Get-Command New-ToolkitElevatedChildArguments -CommandType Function -ErrorAction SilentlyContinue)) 'New-ToolkitElevatedChildArguments is unavailable.'
    $boundChild = @(New-ToolkitElevatedChildArguments -Action 'RemoveAds' -InstallRoot 'C:\MuMu Global' -InstanceIndex 3 -StateRoot 'C:\toolkit state' -Confirmed)
    Assert-True ($boundChild -ccontains '-NonInteractive') 'The elevated child was not launched as a single noninteractive run.'
    Assert-True ($boundChild -ccontains '-ElevatedChild') 'The elevated child was not told that it is already the elevated run.'
    Assert-Equal 'RemoveAds' $boundChild[[array]::IndexOf($boundChild, '-Action') + 1] 'The elevated child lost the allowlisted action.'
    Assert-Equal 'C:\MuMu Global' $boundChild[[array]::IndexOf($boundChild, '-InstallRoot') + 1] 'The elevated child lost the bound installation.'
    Assert-Equal '3' $boundChild[[array]::IndexOf($boundChild, '-InstanceIndex') + 1] 'The elevated child lost the bound instance index.'
    Assert-Equal 'C:\toolkit state' $boundChild[[array]::IndexOf($boundChild, '-StateRoot') + 1] 'The elevated child lost the bound state root.'
    Assert-True ($boundChild -ccontains '-Confirmed') 'The elevated child lost the operator consent token.'
    Assert-True ($boundChild -cnotcontains '-FetchDependencies') 'The elevated child may fetch a dependency after rights were raised.'
    Assert-True ($boundChild -cnotcontains '-Packages') 'An action that takes no package selection bound one for the elevated child.'
    Assert-Equal 0 @($boundChild | Where-Object { [string]$_ -ceq '-Mode' -or [string]$_ -ceq '-StartIndex' -or [string]$_ -ceq '-SourceIndex' -or [string]$_ -ceq '-Packages' }).Count 'An action with no target parameters bound one for the elevated child.'
    $boundConceal = @(New-ToolkitElevatedChildArguments -Action 'Conceal' -Packages @('com.example.app') -StateRoot 'C:\toolkit state')
    Assert-Equal 'com.example.app' $boundConceal[[array]::IndexOf($boundConceal, '-Packages') + 1] 'The elevated child lost the bound package selection.'
    Assert-True ($boundConceal -cnotcontains '-Confirmed') 'The elevated child invented an operator confirmation that was never given.'
    foreach ($unelevatableAction in @('Detect', 'Verify', 'Q', 'Bogus', '   ')) {
        Assert-Throws { New-ToolkitElevatedChildArguments -Action $unelevatableAction -StateRoot 'C:\toolkit state' } "A read-only or unknown action was bound for an elevated relaunch: $unelevatableAction"
    }
    $script:ToolkitSourceRoot = $realSourceRoot

    # The child gate is proven in a fresh process, so the action it may run is a real toolkit script.
    $childActionScript = $commonPath
    $childArgumentList = @(New-ToolkitElevatedArgumentList -ScriptPath $childActionScript -Arguments @('-Fixture', 'Child'))
    $childResult = Invoke-CheckedProcess -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $childArgumentList
    if ($preflight) {
        Assert-Equal 0 $childResult.ExitCode 'The elevated child gate rejected an elevated parent.'
    }
    else {
        Assert-Equal 1223 $childResult.ExitCode 'The non-elevated child gate did not return the elevation failure code.'
    }
    $childArgumentList = @(New-ToolkitElevatedArgumentList -ScriptPath $childActionScript -Arguments @('-Fixture', 'Child'))
    $childTextArgumentList = [string[]]@($childArgumentList)
    $childTextArgumentList[$childTextArgumentList.Length - 1] = 'not-base64'
    $childCorrupt = Invoke-CheckedProcess -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $childTextArgumentList
    Assert-True ($childCorrupt.ExitCode -ne 0) 'A corrupt child payload returned success.'
    $childOutsideArgumentList = [string[]]@(New-ToolkitElevatedArgumentList -ScriptPath $commonPath -Arguments @())
    $childOutsideArgumentList[$childOutsideArgumentList.Length - 1] = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((@{ Action = $outsideScript; Arguments = @() } | ConvertTo-Json -Compress)))
    $childOutside = Invoke-CheckedProcess -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $childOutsideArgumentList
    Assert-True ($childOutside.ExitCode -ne 0) 'An elevated child ran a payload that named a script outside the source directory.'

    # The elevated child is launched with -File, so the elevation module has to stand up on its own.
    # This runs the same three-file composition the entry point builds, in a process that has loaded
    # nothing else, and proves the source-directory bound is available before the child gate is passed.
    $standaloneElevationScript = @'
$ErrorActionPreference = 'Stop'
. '__COMMON__'
. '__DISCOVERY__'
. '__ELEVATION__'
$refused = $false
try {
    Assert-ToolkitPowerShellAction -Path (Join-Path $env:SystemRoot 'System32\drivers\etc\hosts') -Label 'outside' | Out-Null
}
catch {
    $refused = $true
}
if (-not $refused) { throw 'A script outside the source directory was accepted without the controller.' }
$inside = Assert-ToolkitPowerShellAction -Path (Join-Path $script:ToolkitSourceRoot 'Common.ps1') -Label 'inside'
if ($inside -cne (Join-Path $script:ToolkitSourceRoot 'Common.ps1')) { throw 'A script inside the source directory was refused without the controller.' }
Write-Output 'STANDALONE_ELEVATION_OK'
'@
    $standaloneElevationScript = $standaloneElevationScript.Replace('__COMMON__', $commonPath).Replace('__DISCOVERY__', $discoveryScriptPath).Replace('__ELEVATION__', $elevationScriptPath)
    $standaloneElevation = Invoke-CheckedProcess -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'RemoteSigned', '-Command', $standaloneElevationScript)
    Assert-Equal 0 $standaloneElevation.ExitCode "The standalone elevation module could not hold the source-directory bound: $($standaloneElevation.Text)"
    Assert-True ($standaloneElevation.Text -match 'STANDALONE_ELEVATION_OK') "The standalone elevation module did not finish: $($standaloneElevation.Text)"

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
    'ROOT_AFTER_DISABLE',
    'ROOT_AFTER_DISABLE_ROLLED_BACK',
    'ROOT_RECOVERY_FAILED',
    'SYSTEM_DISK_ENABLE_FAILED',
    'SYSTEM_DISK_NOT_WRITABLE',
    'PREINSTALL_LAUNCH_FAILED',
    'PREINSTALL_BOOT_TIMEOUT',
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
    'ROOT_UNAVAILABLE',
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
        SystemDiskReadonly = $true
        SystemDiskWriteExitCode = 0
        SystemDiskQueryMode = 'normal'
        AdbFailPattern = ''
        AdbThrowPattern = ''
        AdbFailExitCode = 1
        AdbRequiresRunning = $false
        AdbStoppedExitCode = -201
        ControlFailPattern = ''
        ControlFailExitCode = 1
        LaunchCount = 0
        LaunchFailAfterCount = -1
        ApkInstallExitCode = 0
        InstalledPath = ''
        BootPolls = @{}
        BootReadyReported = @{}
        BootReadyPolls = 1
        BootFailAfterReady = -1
        PackageInstalled = $true
        PackageName = 'io.github.huskydg.magisk'
        PackageHeaderName = ''
        PackageExtraBlock = ''
        LaunchCommand = 'shell monkey -p io.github.huskydg.magisk -c android.intent.category.LAUNCHER 1'
        VersionName = '31.0-kitsune'
        VersionCode = '31000'
        DaemonPids = '4242'
        DaemonExitCode = 0
        DaemonPidSequence = @()
        DaemonSamples = @{}
        RootAllowedAfterDisable = $null
        RootAllowedAfterRollback = $null
        RootDisableCount = @{}
        RootEnableExitCodeAfterDisable = 0
        RootAllowed = $true
        RootShellMissing = $false
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
            if ($arguments[3] -eq 'launch') {
                $State.LaunchCount = [int]$State.LaunchCount + 1
                if ([int]$State.LaunchFailAfterCount -ge 0 -and $State.LaunchCount -gt [int]$State.LaunchFailAfterCount) {
                    return [pscustomobject]@{ ExitCode = $State.ControlFailExitCode; Text = '{"error_code":1}' }
                }
                foreach ($controlInstance in $State.Instances) {
                    if ([string]$controlInstance.Index -ceq $arguments[2]) {
                        $controlInstance.Running = $true
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
            $keyFlags = @()
            for ($flagIndex = 0; $flagIndex -lt $arguments.Count; $flagIndex++) {
                if ($arguments[$flagIndex] -eq '-k' -and ($flagIndex + 1) -lt $arguments.Count) {
                    $keyFlags += [string]$arguments[$flagIndex + 1]
                }
            }
            $valueIndex = [array]::IndexOf($arguments, '-val')
            if ($valueIndex -ge 0) {
                $requestedValue = $arguments[$valueIndex + 1] -ceq 'true'
                $requestedKey = ''
                if ($keyFlags.Count -gt 0) {
                    $requestedKey = $keyFlags[0]
                }
                if ($requestedKey -ceq 'system_disk_readonly') {
                    if ($State.SystemDiskWriteExitCode -ne 0) {
                        return [pscustomobject]@{ ExitCode = $State.SystemDiskWriteExitCode; Text = '{"error_code":1}' }
                    }
                    if ([string]$State.SystemDiskQueryMode -cne 'stuck') {
                        $State.SystemDiskReadonly = $requestedValue
                    }
                }
                else {
                    if ($State.RootSettingExitCode -ne 0 -and
                        (([string]$State.RootSettingFailValue).Length -eq 0 -or [string]$State.RootSettingFailValue -ceq $arguments[$valueIndex + 1])) {
                        return [pscustomobject]@{ ExitCode = $State.RootSettingExitCode; Text = '{"error_code":1}' }
                    }
                    $ignored = ($requestedValue -and $State.IgnoreRootEnable) -or ((-not $requestedValue) -and $State.IgnoreRootDisable)
                    if (-not $ignored) {
                        $State.RootSettings[$index] = $requestedValue
                    }
                    if ((-not $ignored) -and (-not $requestedValue)) {
                        $State.RootDisableCount[$index] = 1 + [int]$State.RootDisableCount[$index]
                    }
                    elseif ((-not $ignored) -and [int]$State.RootDisableCount[$index] -gt 0 -and $State.RootEnableExitCodeAfterDisable -ne 0) {
                        return [pscustomobject]@{ ExitCode = $State.RootEnableExitCodeAfterDisable; Text = '{"error_code":1}' }
                    }
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
            $reported = [ordered]@{}
            foreach ($reportedKey in $keyFlags) {
                if ($reportedKey -ceq 'system_disk_readonly') {
                    if ([string]$State.SystemDiskQueryMode -ceq 'omit') {
                        continue
                    }
                    if ([string]$State.SystemDiskQueryMode -ceq 'malformed') {
                        $reported['system_disk_readonly'] = 'unknown'
                        continue
                    }
                    $reported['system_disk_readonly'] = [string]$State.SystemDiskReadonly
                }
                else {
                    $reported[$reportedKey] = [string]$current
                }
            }
            return [pscustomobject]@{ ExitCode = 0; Text = (ConvertTo-Json -InputObject ([pscustomobject]$reported) -Compress) }
        }
        if ($command -eq 'adb') {
            $index = $arguments[2]
            $request = [string]$arguments[4]
            if ($State.AdbRequiresRunning) {
                $adbInstance = @($State.Instances | Where-Object { [string]$_.Index -ceq $index })
                if ($adbInstance.Count -ne 1 -or $adbInstance[0].Running -ne $true) {
                    return [pscustomobject]@{ ExitCode = $State.AdbStoppedExitCode; Text = 'adb: no running instance' }
                }
            }
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
                $readyReported = 0
                if ($State.BootReadyReported.ContainsKey($index)) {
                    $readyReported = [int]$State.BootReadyReported[$index]
                }
                if ([int]$State.BootFailAfterReady -ge 0 -and $readyReported -ge [int]$State.BootFailAfterReady) {
                    return [pscustomobject]@{ ExitCode = 0; Text = '0' }
                }
                if ($polls -ge $State.BootReadyPolls) {
                    if ([int]$State.BootFailAfterReady -ge 0) {
                        $State.BootReadyReported[$index] = $readyReported + 1
                    }
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
                $sampleIndex = [int]$State.DaemonSamples[$index]
                $State.DaemonSamples[$index] = $sampleIndex + 1
                if (@($State.DaemonPidSequence).Count -gt 0) {
                    $sequenceIndex = [Math]::Min($sampleIndex, @($State.DaemonPidSequence).Count - 1)
                    return [pscustomobject]@{ ExitCode = $State.DaemonExitCode; Text = [string]$State.DaemonPidSequence[$sequenceIndex] }
                }
                return [pscustomobject]@{ ExitCode = $State.DaemonExitCode; Text = $State.DaemonPids }
            }
            if ($request -ceq 'shell su -c id') {
                $rootAllowedNow = [bool]$State.RootAllowed
                $rootDisabledOnce = [int]$State.RootDisableCount[$index] -gt 0
                if ($rootDisabledOnce -and $State.RootSettings.ContainsKey($index) -and $State.RootSettings[$index] -eq $false) {
                    if ($null -ne $State.RootAllowedAfterDisable) {
                        $rootAllowedNow = [bool]$State.RootAllowedAfterDisable
                    }
                }
                elseif ($rootDisabledOnce -and $null -ne $State.RootAllowedAfterRollback) {
                    $rootAllowedNow = [bool]$State.RootAllowedAfterRollback
                }
                if (-not $rootAllowedNow) {
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

function Get-Root12LastCallIndex {
    param(
        [object[]]$Calls,
        [string]$Pattern
    )

    $lastIndex = -1
    for ($index = 0; $index -lt $Calls.Count; $index++) {
        if ((@($Calls[$index]) -join ' ') -like $Pattern) {
            $lastIndex = $index
        }
    }
    return $lastIndex
}

function Get-Root12LaunchCount {
    param([object[]]$Calls)

    $count = 0
    foreach ($call in @($Calls)) {
        if ((@($call) -join ' ') -like 'control*-v*launch*') {
            $count++
        }
    }
    return $count
}

function Assert-Root12Warning {
    param(
        [object]$Result,
        [object]$Journal,
        [string]$Code,
        [string]$Message
    )

    Assert-Equal 'Warning' $Result.Status $Message
    Assert-True ($null -ne $Result.Data) "$Message The warning carried no record data."
    Assert-True ($script:Root12Codes -ccontains [string]$Result.Data.Code) "$Message The warning reported an undocumented code: $($Result.Data.Code)"
    Assert-Equal $Code $Result.Data.Code "$Message The warning code is invalid."
    Assert-Equal 'Completed' $Journal.State "$Message The warning was not completed."
    $reopened = Get-OperationJournal -Path $Journal.JournalPath
    Assert-Equal 'Completed' $reopened.State "$Message The warning was not persisted as completed."
    Assert-Equal 'Warning' $reopened.Result.Status "$Message The persisted result is not a warning."
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
    $daemonDelayVariable = Get-Variable -Name 'ToolkitAndroid12DaemonSettleMilliseconds' -Scope Script -ErrorAction SilentlyContinue
    $script:ToolkitBootPollAttempts = 2
    $script:ToolkitBootPollDelaySeconds = 0
    $script:ToolkitAndroid12DaemonSettleMilliseconds = 0
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
        Assert-Equal 1 (Get-Root12LaunchCount -Calls $decliningState.Calls) 'A declined confirmation performed a step beyond the pre-install launch.'
        Assert-Equal 1 @($decliningState.Calls | Where-Object { (@($_) -join ' ') -like '*getprop sys.boot_completed*' }).Count 'A declined confirmation did not perform exactly the pre-install boot wait.'
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
        Assert-Equal 1 (Get-Root12LaunchCount -Calls $ordinaryState.Calls) 'An ordinary Direct Install confirmation performed a step beyond the pre-install launch.'

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
        $preInstallLaunchIndex = Get-Root12CallIndex -Calls $confirmedState.Calls -Pattern 'control*-v*launch*'
        $coldBootLaunchIndex = Get-Root12LastCallIndex -Calls $confirmedState.Calls -Pattern 'control*-v*launch*'
        Assert-Equal 2 (Get-Root12LaunchCount -Calls $confirmedState.Calls) 'The confirmed workflow did not perform exactly the pre-install and the cold-boot launch.'
        Assert-True ($preInstallLaunchIndex -lt $installCallIndex) 'The verified APK was installed before the pre-install launch.'
        Assert-True ($installCallIndex -lt $launchCallIndex) 'The Kitsune APK was launched before it was installed.'
        Assert-True ($launchCallIndex -lt $coldBootLaunchIndex) 'The Kitsune APK was launched after the confirmation gate.'

        $stoppedAdbState = New-Root12ManagerState -Install $install
        $stoppedAdbState.AdbRequiresRunning = $true
        $stoppedAdbCase = Invoke-Root12Case -State $stoppedAdbState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-True ($stoppedAdbCase.Result.Status -eq 'Success') "The Android 12 workflow failed against a manager that rejects ADB on a stopped instance. $($stoppedAdbCase.Result.Message)"
        $stoppedAdbInstallIndex = Get-Root12CallIndex -Calls $stoppedAdbState.Calls -Pattern ('*' + $expectedInstallCommand + '*')
        $stoppedAdbPreLaunchIndex = Get-Root12CallIndex -Calls $stoppedAdbState.Calls -Pattern 'control*-v*launch*'
        Assert-True ($stoppedAdbPreLaunchIndex -ge 0 -and $stoppedAdbPreLaunchIndex -lt $stoppedAdbInstallIndex) 'The manager rejected ADB on the stopped clone because the pre-install launch was missing.'
        $stoppedAdbPreLaunch = @($stoppedAdbState.Calls[$stoppedAdbPreLaunchIndex])
        Assert-Equal 'control' $stoppedAdbPreLaunch[0] 'The pre-install step is not a structured manager control command.'
        Assert-Equal ([string]$stoppedAdbState.CloneIndex) $stoppedAdbPreLaunch[2] 'The pre-install launch did not target the clone.'
        Assert-Equal 'launch' $stoppedAdbPreLaunch[3] 'The pre-install command is not a launch.'
        $stoppedAdbPreBootIndex = Get-Root12CallIndex -Calls $stoppedAdbState.Calls -Pattern '*getprop sys.boot_completed*'
        Assert-True ($stoppedAdbPreBootIndex -gt $stoppedAdbPreLaunchIndex -and $stoppedAdbPreBootIndex -lt $stoppedAdbInstallIndex) 'The pre-install step did not wait for sys.boot_completed=1 before the install.'
        Assert-Equal 2 (Get-Root12LaunchCount -Calls $stoppedAdbState.Calls) 'The stopped-instance run did not perform exactly the pre-install and the cold-boot launch.'
        Assert-Equal $false $stoppedAdbState.RootSettings[[string]$stoppedAdbState.CloneIndex] 'The temporary vendor root was not disabled after verification on the stopped-instance run.'
        $stoppedAdbPreInstallEvents = @((Get-OperationJournal -Path $stoppedAdbCase.Journal.JournalPath).Checkpoints | Where-Object { [string]$_.Message -match 'sys\.boot_completed=1 before the APK install' })
        Assert-Equal 1 $stoppedAdbPreInstallEvents.Count 'The pre-install launch was not journaled.'

        $preInstallLaunchFailureState = New-Root12ManagerState -Install $install
        $preInstallLaunchFailureState.LaunchFailAfterCount = 0
        $preInstallLaunchFailureCase = Invoke-Root12Case -State $preInstallLaunchFailureState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-Root12Failure -Result $preInstallLaunchFailureCase.Result -Journal $preInstallLaunchFailureCase.Journal -Code 'PREINSTALL_LAUNCH_FAILED' -Message 'A failed pre-install launch was accepted.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $preInstallLaunchFailureState.Calls -Pattern '*getprop sys.boot_completed*') 'A failed pre-install launch still waited for the boot.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $preInstallLaunchFailureState.Calls -Pattern 'adb*-v*-c*install*') 'A failed pre-install launch still installed the APK.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $preInstallLaunchFailureState.Calls -Pattern '*root_permission*-val*false*') 'A failed pre-install launch disabled the temporary vendor root.'
        Assert-Equal $true $preInstallLaunchFailureState.RootSettings[[string]$preInstallLaunchFailureState.CloneIndex] 'A failed pre-install launch did not leave the temporary vendor root enabled.'

        $preInstallBootFailureState = New-Root12ManagerState -Install $install
        $preInstallBootFailureState.BootReadyPolls = @{}
        $preInstallBootFailureState.BootReadyPolls[[string]$preInstallBootFailureState.CloneIndex] = 99
        $preInstallBootFailureCase = Invoke-Root12Case -State $preInstallBootFailureState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-Root12Failure -Result $preInstallBootFailureCase.Result -Journal $preInstallBootFailureCase.Journal -Code 'PREINSTALL_BOOT_TIMEOUT' -Message 'A pre-install boot timeout was accepted.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $preInstallBootFailureState.Calls -Pattern 'adb*-v*-c*install*') 'A pre-install boot timeout still installed the APK.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $preInstallBootFailureState.Calls -Pattern '*root_permission*-val*false*') 'A pre-install boot timeout disabled the temporary vendor root.'
        Assert-Equal $true $preInstallBootFailureState.RootSettings[[string]$preInstallBootFailureState.CloneIndex] 'A pre-install boot timeout did not leave the temporary vendor root enabled.'

        $launchFailureState = New-Root12ManagerState -Install $install
        $launchFailureState.AdbFailPattern = '*monkey*'
        $launchPromptState = @{ Calls = 0 }
        $launchFailurePrompt = { param($PromptText) $launchPromptState.Calls++; 'Direct Install into system partition' }.GetNewClosure()
        $launchFailureCase = Invoke-Root12Case -State $launchFailureState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Prompt $launchFailurePrompt
        Assert-Root12Failure -Result $launchFailureCase.Result -Journal $launchFailureCase.Journal -Code 'APK_LAUNCH_FAILED' -Message 'A failed Kitsune launch was accepted.'
        Assert-Equal 0 $launchPromptState.Calls 'A failed Kitsune launch still asked the operator to confirm.'
        Assert-Equal 1 (Get-Root12LaunchCount -Calls $launchFailureState.Calls) 'A failed Kitsune launch performed a step beyond the pre-install launch.'
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
        Assert-Root12Failure -Result $resumeFailureCase.Result -Journal $resumeFailureCase.Journal -Code 'PREINSTALL_BOOT_TIMEOUT' -Message 'A failed resume did not report a structured failure.'
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
        $bootTimeoutState.BootFailAfterReady = 1
        $bootTimeoutCase = Invoke-Root12Case -State $bootTimeoutState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-Root12Failure -Result $bootTimeoutCase.Result -Journal $bootTimeoutCase.Journal -Code 'BOOT_TIMEOUT' -Message 'A boot timeout was accepted.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $bootTimeoutState.Calls -Pattern '*pidof magiskd*') 'A boot timeout still verified the root daemon.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $bootTimeoutState.Calls -Pattern '*root_permission*-val*false*') 'A boot timeout disabled the temporary vendor root.'
        Assert-Equal $bootTimeoutState.CloneIndex $bootTimeoutCase.Result.Data.CloneIndex 'A boot timeout did not report the recoverable clone.'

        $bootControlState = New-Root12ManagerState -Install $install
        $bootControlState.LaunchFailAfterCount = 1
        $bootControlCase = Invoke-Root12Case -State $bootControlState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-Root12Failure -Result $bootControlCase.Result -Journal $bootControlCase.Journal -Code 'BOOT_CONTROL_FAILED' -Message 'A failed cold-boot launch was accepted.'
        Assert-Equal 1 @($bootControlState.Calls | Where-Object { (@($_) -join ' ') -like '*getprop sys.boot_completed*' }).Count 'A failed cold-boot launch still waited for the boot.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $bootControlState.Calls -Pattern '*root_permission*-val*false*') 'A failed cold-boot launch disabled the temporary vendor root.'

        $stopControlState = New-Root12ManagerState -Install $install
        $stopControlState.Instances[1].Running = $false
        $stopControlState.ControlFailPattern = '*shutdown*'
        $stopControlCase = Invoke-Root12Case -State $stopControlState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-Root12Failure -Result $stopControlCase.Result -Journal $stopControlCase.Journal -Code 'BOOT_CONTROL_FAILED' -Message 'A failed cold-boot shutdown was accepted.'
        Assert-Equal 1 @($stopControlState.Calls | Where-Object { (@($_) -join ' ') -like '*getprop sys.boot_completed*' }).Count 'A failed cold-boot shutdown did not perform exactly the pre-install boot wait.'

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
                [pscustomobject]@{ ExitCode = 0; Pids = ''; Code = 'DAEMON_ABSENT'; Label = 'exit 0 with no output'; Samples = 3 },
                [pscustomobject]@{ ExitCode = 0; Pids = '   '; Code = 'DAEMON_ABSENT'; Label = 'exit 0 with blank output'; Samples = 3 },
                [pscustomobject]@{ ExitCode = 1; Pids = ''; Code = 'DAEMON_ABSENT'; Label = 'exit 1 with empty output'; Samples = 3 },
                [pscustomobject]@{ ExitCode = 1; Pids = " `n "; Code = 'DAEMON_ABSENT'; Label = 'exit 1 with blank output'; Samples = 3 },
                [pscustomobject]@{ ExitCode = 0; Pids = '4242'; Code = 'OK'; Label = 'exit 0 with one daemon'; Samples = 1 },
                [pscustomobject]@{ ExitCode = 0; Pids = "11`n22"; Code = 'DAEMON_DUPLICATE'; Label = 'exit 0 with two daemons'; Samples = 3 },
                [pscustomobject]@{ ExitCode = 1; Pids = '4242'; Code = 'ADB_FAILED'; Label = 'exit 1 with output'; Samples = 1 },
                [pscustomobject]@{ ExitCode = -201; Pids = ''; Code = 'ADB_FAILED'; Label = 'exit -201'; Samples = 1 },
                [pscustomobject]@{ ExitCode = 3; Pids = ''; Code = 'ADB_FAILED'; Label = 'exit 3'; Samples = 1 }
            )) {
            $daemonState = New-Root12ManagerState -Install $install
            $daemonState.DaemonExitCode = [int]$daemonCase.ExitCode
            $daemonState.DaemonPids = [string]$daemonCase.Pids
            $daemonFailure = Invoke-Root12Case -State $daemonState -Instance $android12 -Manifest $manifest `
                -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
            Assert-Equal $daemonCase.Samples $daemonFailure.Result.Data.DaemonSamples "The final result dropped the settling sample count ($($daemonCase.Label))."
            if ([string]$daemonCase.Code -ceq 'OK') {
                Assert-True ($daemonFailure.Result.Status -eq 'Success') "A verified root daemon result was rejected ($($daemonCase.Label)): $($daemonFailure.Result.Message)"
                Assert-Equal 1 $daemonFailure.Result.Data.DaemonCount "A verified root daemon was not reported as exactly one ($($daemonCase.Label))."
                Assert-Equal $false $daemonState.RootSettings[[string]$daemonState.CloneIndex] "The temporary vendor root was not disabled after the verified daemon ($($daemonCase.Label))."
                continue
            }
            Assert-Root12Failure -Result $daemonFailure.Result -Journal $daemonFailure.Journal -Code $daemonCase.Code -Message "An unexpected root daemon result was accepted ($($daemonCase.Label))."
            Assert-True ($daemonFailure.Result.Message -match '(?i)daemon') "A root daemon result did not name the daemon ($($daemonCase.Label)): $($daemonFailure.Result.Message)"
            Assert-Equal -1 (Get-Root12CallIndex -Calls $daemonState.Calls -Pattern '*root_permission*-val*false*') "An unexpected root daemon result disabled the temporary vendor root ($($daemonCase.Label))."
        }

        $systemDiskState = New-Root12ManagerState -Install $install
        $systemDiskCase = Invoke-Root12Case -State $systemDiskState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-True ($systemDiskCase.Result.Status -eq 'Success') "The Android 12 workflow failed with a read-only system disk: $($systemDiskCase.Result.Message)"
        $systemDiskWriteCalls = @($systemDiskState.Calls | Where-Object { ((@($_) -join ' ') -like 'setting*-v*-k*system_disk_readonly*') -and ((@($_) -join ' ') -like '*-val*') })
        Assert-Equal 1 $systemDiskWriteCalls.Count "The workflow did not write the system disk setting exactly once: $(@(Get-Root12CallIndex -Calls $systemDiskState.Calls -Pattern '*system_disk_readonly*'))"
        $systemDiskWriteArguments = [string[]]@($systemDiskWriteCalls[0])
        Assert-Equal 7 $systemDiskWriteArguments.Count 'The system disk setting request carried an unexpected argument count.'
        Assert-Equal 'setting' $systemDiskWriteArguments[0] 'The system disk setting request is not a manager setting request.'
        Assert-Equal ([string]$systemDiskState.CloneIndex) $systemDiskWriteArguments[2] 'The system disk setting request did not target the clone.'
        Assert-Equal '-k' $systemDiskWriteArguments[3] 'The system disk setting request lost its key flag.'
        Assert-Equal 'system_disk_readonly' $systemDiskWriteArguments[4] 'The system disk setting request named the wrong key.'
        Assert-Equal '-val' $systemDiskWriteArguments[5] 'The system disk setting request lost its value flag.'
        Assert-Equal 'false' $systemDiskWriteArguments[6] 'The system disk setting request did not request a writable system disk.'
        Assert-Equal $false $systemDiskState.SystemDiskReadonly 'The system disk setting was left read-only.'
        foreach ($systemDiskCall in $systemDiskWriteCalls) {
            $systemDiskCallArguments = [string[]]@($systemDiskCall)
            Assert-True ($systemDiskCallArguments[2] -ceq [string]$systemDiskState.CloneIndex) 'The system disk setting was written on an instance other than the clone.'
        }
        $systemDiskReadIndex = Get-Root12CallIndex -Calls $systemDiskState.Calls -Pattern '*system_disk_readonly*'
        $systemDiskInstallIndex = Get-Root12CallIndex -Calls $systemDiskState.Calls -Pattern ('*' + $kitsuneAssetPath + '*')
        Assert-True ($systemDiskReadIndex -ge 0 -and $systemDiskReadIndex -lt $systemDiskInstallIndex) 'The workflow did not read back the system disk setting before the APK install.'
        $systemDiskEvents = @((Get-OperationJournal -Path $systemDiskCase.Journal.JournalPath).Checkpoints | Where-Object { [string]$_.Message -match 'system disk is writable' })
        Assert-Equal 1 $systemDiskEvents.Count 'The workflow did not journal both preparation settings.'
        $systemDiskEventText = [string](@($systemDiskEvents[0].Data.PSObject.Properties | ForEach-Object { $_.Name }) -join ',')
        Assert-True ($systemDiskEventText -match 'RootSetting') "The preparation journal event does not record the vendor root setting: $systemDiskEventText"
        Assert-True ($systemDiskEventText -match 'SystemDiskReadonly') "The preparation journal event does not record the system disk setting: $systemDiskEventText"
        Assert-True ((Get-Root12CallIndex -Calls $systemDiskState.Calls -Pattern 'setting*-k*root_permission*-k*system_disk_readonly*') -ge 0) 'The workflow did not read both preparation settings in one manager request.'

        foreach ($systemDiskCase in @(
                [pscustomobject]@{ QueryMode = 'omit'; Label = 'a missing system disk setting' },
                [pscustomobject]@{ QueryMode = 'malformed'; Label = 'a malformed system disk setting' }
            )) {
            $unreadableState = New-Root12ManagerState -Install $install
            $unreadableState.SystemDiskQueryMode = $systemDiskCase.QueryMode
            $unreadableCase = Invoke-Root12Case -State $unreadableState -Instance $android12 -Manifest $manifest `
                -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
            Assert-Root12Failure -Result $unreadableCase.Result -Journal $unreadableCase.Journal -Code 'VENDOR_ROOT_SETTING_UNREADABLE' -Message "An unreadable preparation setting was accepted ($($systemDiskCase.Label))."
            Assert-Equal -1 (Get-Root12CallIndex -Calls $unreadableState.Calls -Pattern 'adb*-v*-c*install*') "An unreadable preparation setting still reached the APK install ($($systemDiskCase.Label))."
            Assert-Equal 0 (Get-Root12LaunchCount -Calls $unreadableState.Calls) "An unreadable preparation setting still launched the clone ($($systemDiskCase.Label))."
            Assert-Equal $true $unreadableState.RootSettings[[string]$unreadableState.CloneIndex] "An unreadable preparation setting did not leave the temporary vendor root enabled ($($systemDiskCase.Label))."
        }

        $readOnlyWriteState = New-Root12ManagerState -Install $install
        $readOnlyWriteState.IgnoreRootEnable = $true
        $readOnlyWriteCase = Invoke-Root12Case -State $readOnlyWriteState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-Root12Failure -Result $readOnlyWriteCase.Result -Journal $readOnlyWriteCase.Journal -Code 'VENDOR_ROOT_NOT_ENABLED' -Message 'A wrong vendor root readback was accepted.'

        $stuckSystemDiskState = New-Root12ManagerState -Install $install
        $stuckSystemDiskState.SystemDiskQueryMode = 'stuck'
        $stuckSystemDiskCase = Invoke-Root12Case -State $stuckSystemDiskState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-Root12Failure -Result $stuckSystemDiskCase.Result -Journal $stuckSystemDiskCase.Journal -Code 'SYSTEM_DISK_NOT_WRITABLE' -Message 'A wrong system disk readback was accepted.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $stuckSystemDiskState.Calls -Pattern 'adb*-v*-c*install*') 'A wrong system disk readback still reached the APK install.'
        Assert-Equal 0 (Get-Root12LaunchCount -Calls $stuckSystemDiskState.Calls) 'A wrong system disk readback still launched the clone.'
        Assert-Equal $true $stuckSystemDiskState.RootSettings[[string]$stuckSystemDiskState.CloneIndex] 'A wrong system disk readback did not leave the temporary vendor root enabled.'

        $systemDiskWriteFailureState = New-Root12ManagerState -Install $install
        $systemDiskWriteFailureState.SystemDiskWriteExitCode = 1
        $systemDiskWriteFailureCase = Invoke-Root12Case -State $systemDiskWriteFailureState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-Root12Failure -Result $systemDiskWriteFailureCase.Result -Journal $systemDiskWriteFailureCase.Journal -Code 'SYSTEM_DISK_ENABLE_FAILED' -Message 'A failed system disk write was accepted.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $systemDiskWriteFailureState.Calls -Pattern 'adb*-v*-c*install*') 'A failed system disk write still reached the APK install.'
        Assert-Equal 0 (Get-Root12LaunchCount -Calls $systemDiskWriteFailureState.Calls) 'A failed system disk write still launched the clone.'
        Assert-Equal $true $systemDiskWriteFailureState.RootSettings[[string]$systemDiskWriteFailureState.CloneIndex] 'A failed system disk write did not leave the temporary vendor root enabled.'

        $postCleanupShellCalls = @($confirmedState.Calls | Where-Object { (@($_) -join ' ') -like '*su -c id*' })
        $postCleanupPackageCalls = @($confirmedState.Calls | Where-Object { (@($_) -join ' ') -like ('*dumpsys package io.github.huskydg.magisk*') })
        Assert-Equal 2 $postCleanupShellCalls.Count 'The confirmed workflow did not verify the root shell again after disabling the temporary vendor root.'
        Assert-Equal 2 $postCleanupPackageCalls.Count 'The confirmed workflow did not verify the Kitsune package again after disabling the temporary vendor root.'
        $disableRootIndex = Get-Root12CallIndex -Calls $confirmedState.Calls -Pattern '*root_permission*-val*false*'
        $postCleanupShellIndex = Get-Root12LastCallIndex -Calls $confirmedState.Calls -Pattern '*su -c id*'
        Assert-True ($postCleanupShellIndex -gt $disableRootIndex) 'The confirmed workflow did not check the root shell after disabling the temporary vendor root.'
        Assert-True ($confirmed.Message -match '(?i)again after the temporary vendor root was disabled') 'The success message does not state that the root was re-checked after the cleanup.'

        $rollbackState = New-Root12ManagerState -Install $install
        $rollbackState.RootAllowedAfterDisable = $false
        $rollback = Invoke-Root12Case -State $rollbackState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-Root12Warning -Result $rollback.Result -Journal $rollback.Journal -Code 'ROOT_AFTER_DISABLE_ROLLED_BACK' `
            -Message 'A root that did not survive the cleanup was not reported as a retained-vendor-root warning.'
        Assert-Equal $true $rollback.Result.Data.VendorRootRetained 'The retained-vendor-root warning does not report the retained vendor root.'
        Assert-Equal $false $rollback.Result.Data.SystemDiskReadonly 'The retained-vendor-root warning does not report the writable system disk.'
        Assert-Equal $true $rollback.Result.Data.RootVerified 'The retained-vendor-root warning does not report the re-verified root.'
        Assert-Equal 'vendor-root-restore' $rollback.Result.Data.Step 'The retained-vendor-root warning reported the wrong recovery step.'
        Assert-Equal $rollbackState.CloneIndex $rollback.Result.Data.CloneIndex 'The retained-vendor-root warning did not report the clone.'
        Assert-Equal $android12.Index $rollback.Result.Data.SourceIndex 'The retained-vendor-root warning did not report the source instance.'
        Assert-True ($rollback.Result.Message -match 'uid=2000') 'The retained-vendor-root warning does not state the observed adb shell identity.'
        Assert-True ($rollback.Result.Message -match '(?i)removes the /system/bin/su path') 'The retained-vendor-root warning does not say the cleanup removes the su path.'
        Assert-True ($rollback.Result.Message -match '(?i)Magisk su') 'The retained-vendor-root warning does not say root comes from the Magisk su.'
        Assert-True ($rollback.Result.Message -notmatch '(?i)requires the vendor root') 'The retained-vendor-root warning still claims Kitsune requires the vendor root.'
        Assert-True ($rollback.Result.Message -match 'MuMu 6\.8') 'The retained-vendor-root warning does not name the MuMu build the cleanup breaks on.'
        Assert-True ($rollback.Result.Message -match '(?i)not as a success') 'The retained-vendor-root warning does not say it is not a success.'
        Assert-Equal $true $rollbackState.RootSettings[[string]$rollbackState.CloneIndex] 'The rollback did not leave the vendor root enabled on the clone.'
        Assert-Equal $false $rollbackState.SystemDiskReadonly 'The rollback did not leave the system disk writable on the clone.'
        Assert-Equal 2 @($rollbackState.Calls | Where-Object { (@($_) -join ' ') -like '*root_permission*-val*true*' }).Count 'The rollback did not enable the vendor root exactly once more.'
        Assert-Equal 1 @($rollbackState.Calls | Where-Object { (@($_) -join ' ') -like '*root_permission*-val*false*' }).Count 'The rollback disabled the vendor root more than once.'
        Assert-Equal 3 @($rollbackState.Calls | Where-Object { (@($_) -join ' ') -like '*dumpsys package io.github.huskydg.magisk*' }).Count 'The rollback did not run all three root checks.'
        Assert-Equal 0 @($rollbackState.Calls | Where-Object {
                (@($_) -join ' ') -like 'setting*' -and (@($_) -join ' ') -notlike ('*-v ' + $rollbackState.CloneIndex + '*')
            }).Count 'The rollback changed a setting on an instance other than the clone.'
        $rollbackReopened = Get-OperationJournal -Path $rollback.Journal.JournalPath
        Assert-Equal 'Warning' $rollbackReopened.Result.Status 'The retained-vendor-root warning was persisted as a success.'
        Assert-Equal 'ROOT_AFTER_DISABLE_ROLLED_BACK' $rollbackReopened.Result.Data.Code 'The persisted warning reported the wrong code.'
        Assert-Equal $true $rollbackReopened.Result.Data.VendorRootRetained 'The persisted warning lost the retained vendor root field.'
        $rollbackRecords = @(Get-ToolkitJournalRecords -StateRoot $root12Root | Where-Object {
                $recordResult = Get-ToolkitRecordValue -Record $_ -PropertyNames @('Result')
                $recordData = Get-ToolkitRecordValue -Record $recordResult -PropertyNames @('Data')
                [string](Get-ToolkitRecordValue -Record $recordData -PropertyNames @('Code')) -ceq 'ROOT_AFTER_DISABLE_ROLLED_BACK'
            })
        Assert-Equal 1 $rollbackRecords.Count 'The completed warning record is not recoverable for the verified-clone lookup.'
        Assert-Equal 'Completed' $rollbackRecords[0].State 'The recoverable warning record is not a completed journal.'
        Assert-Equal $rollbackState.CloneIndex $rollbackRecords[0].Result.Data.CloneIndex 'The recoverable warning record lost the clone index.'

        foreach ($recoveryCase in @(
                [pscustomobject]@{ Kind = 'write'; Label = 'a refused rollback write'; Step = 'vendor-root-restore'; Retained = $false },
                [pscustomobject]@{ Kind = 'root'; Label = 'a root that still fails after the rollback'; Step = 'vendor-root-restore-verification'; Retained = $true }
            )) {
            $recoveryState = New-Root12ManagerState -Install $install
            $recoveryState.RootAllowedAfterDisable = $false
            if ($recoveryCase.Kind -ceq 'write') {
                $recoveryState.RootEnableExitCodeAfterDisable = 1
            }
            else {
                $recoveryState.RootAllowedAfterRollback = $false
            }
            $recovery = Invoke-Root12Case -State $recoveryState -Instance $android12 -Manifest $manifest `
                -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
            Assert-Root12Failure -Result $recovery.Result -Journal $recovery.Journal -Code 'ROOT_RECOVERY_FAILED' -Message "A failed rollback was reported as a success ($($recoveryCase.Label))."
            Assert-Equal $recoveryCase.Step $recovery.Result.Data.Step "A failed rollback reported the wrong recovery step ($($recoveryCase.Label))."
            Assert-Equal $recoveryCase.Retained ([bool](Get-ToolkitRecordValue -Record $recovery.Result.Data -PropertyNames @('VendorRootRetained'))) "A failed rollback reported a retained vendor root it cannot prove ($($recoveryCase.Label))."
            Assert-Equal $false $recovery.Result.Data.RootVerified "A failed rollback still claims a verified root ($($recoveryCase.Label))."
            Assert-Equal $recoveryState.CloneIndex $recovery.Result.Data.CloneIndex "A failed rollback did not report the clone ($($recoveryCase.Label))."
            Assert-Equal 2 @($recoveryState.Calls | Where-Object { (@($_) -join ' ') -like '*root_permission*-val*true*' }).Count "A failed rollback did not try the vendor root exactly once more ($($recoveryCase.Label))."
            Assert-Equal 1 @($recoveryState.Calls | Where-Object { (@($_) -join ' ') -like '*root_permission*-val*false*' }).Count "A failed rollback disabled the vendor root more than once ($($recoveryCase.Label))."
        }

        foreach ($daemonSampleCase in @(
                [pscustomobject]@{ Sequence = @('1118 3463', '1118'); Label = 'a duplicate that settles to one'; Code = 'OK'; Count = 1; Samples = 2; Status = 'Success' },
                [pscustomobject]@{ Sequence = @('1118 3463'); Label = 'a persistent duplicate'; Code = 'DAEMON_DUPLICATE'; Count = 2; Samples = 3; Status = 'CriticalError' },
                [pscustomobject]@{ Sequence = @('', '1118'); Label = 'a first read with no daemon'; Code = 'OK'; Count = 1; Samples = 2; Status = 'Success' },
                [pscustomobject]@{ Sequence = @(''); Label = 'a daemon that never appears'; Code = 'DAEMON_ABSENT'; Count = 0; Samples = 3; Status = 'CriticalError' }
            )) {
            $daemonSampleState = New-Root12ManagerState -Install $install
            $daemonSampleState.DaemonPidSequence = $daemonSampleCase.Sequence
            $daemonSampleRunner = New-Root12ManagerRunner -State $daemonSampleState
            $daemonSampleChecks = Test-Android12Root -ManagerPath $install.ManagerPath -InstanceIndex $install.SourceIndex -Runner $daemonSampleRunner
            Assert-Equal $daemonSampleCase.Status $daemonSampleChecks.Status "The daemon settling poll accepted $($daemonSampleCase.Label)."
            Assert-Equal $daemonSampleCase.Code $daemonSampleChecks.Data.Code "The daemon settling poll reported the wrong code for $($daemonSampleCase.Label)."
            Assert-Equal $daemonSampleCase.Count $daemonSampleChecks.Data.DaemonCount "The daemon settling poll reported the wrong final count for $($daemonSampleCase.Label)."
            Assert-Equal $daemonSampleCase.Samples $daemonSampleChecks.Data.DaemonSamples "The daemon settling poll took the wrong number of samples for $($daemonSampleCase.Label)."
            Assert-Equal $daemonSampleCase.Samples @($daemonSampleState.Calls | Where-Object { (@($_) -join ' ') -like '*pidof magiskd*' }).Count "The daemon settling poll issued the wrong number of daemon reads for $($daemonSampleCase.Label)."
            if ($daemonSampleCase.Status -ceq 'Success') {
                Assert-Equal 1 @($daemonSampleState.Calls | Where-Object { (@($_) -join ' ') -like '*su -c id*' }).Count "The daemon settling poll issued a root shell probe per sample for $($daemonSampleCase.Label)."
            }
            else {
                Assert-Equal -1 (Get-Root12CallIndex -Calls $daemonSampleState.Calls -Pattern '*su -c id*') "An unsettled daemon was accepted and probed for a root shell ($($daemonSampleCase.Label))."
            }
        }

        $settledDuplicateState = New-Root12ManagerState -Install $install
        $settledDuplicateState.DaemonPidSequence = @('1118 3463', '1118')
        $settledDuplicateChecks = Test-Android12Root -ManagerPath $install.ManagerPath -InstanceIndex $install.SourceIndex -Runner (New-Root12ManagerRunner -State $settledDuplicateState)
        Assert-True ((Get-Root12CallIndex -Calls $settledDuplicateState.Calls -Pattern '*su -c id*') -gt (Get-Root12LastCallIndex -Calls $settledDuplicateState.Calls -Pattern '*pidof magiskd*')) 'The root shell probe ran before the daemon settled.'
        $settledDuplicateRecord = New-Android12Recovery -Code 'OK' -Step 'verification' -SourceIndex $install.SourceIndex -CloneIndex $settledDuplicateState.CloneIndex -CloneName $settledDuplicateState.CloneName -Checks $settledDuplicateChecks.Data
        Assert-Equal 2 $settledDuplicateRecord.DaemonSamples 'The recovery record dropped the settling sample count.'

        $duplicateRollbackState = New-Root12ManagerState -Install $install
        $duplicateRollbackState.RootAllowedAfterDisable = $false
        $duplicateRollbackState.DaemonPidSequence = @('1118', '1118 3463', '1118')
        $duplicateRollback = Invoke-Root12Case -State $duplicateRollbackState -Instance $android12 -Manifest $manifest `
            -JournalRoot $journalRoot -CacheRoot $assetCacheRoot -Interactive $true -Confirmation 'Direct Install into system partition'
        Assert-Root12Warning -Result $duplicateRollback.Result -Journal $duplicateRollback.Journal -Code 'ROOT_AFTER_DISABLE_ROLLED_BACK' `
            -Message 'A transient duplicate daemon count poisoned the rollback re-verification.'
        Assert-Equal $true $duplicateRollback.Result.Data.VendorRootRetained 'A transient duplicate daemon count lost the retained vendor root record.'
        Assert-Equal 1 $duplicateRollback.Result.Data.DaemonCount 'The rollback re-verification reported the wrong daemon count after a transient duplicate.'
        Assert-Equal 1 $duplicateRollback.Result.Data.DaemonSamples 'The rollback re-verification dropped the settling sample count.'

        $callerState = New-Root12ManagerState -Install $install
        $callerState.DaemonExitCode = 1
        $callerState.DaemonPids = ''
        $callerCheck = Test-Android12Root -ManagerPath $install.ManagerPath -InstanceIndex $install.SourceIndex -Runner (New-Root12ManagerRunner -State $callerState)
        Assert-Equal 'CriticalError' $callerCheck.Status 'A pidof result that reported no running daemon was accepted by the shared root check.'
        Assert-Equal 'DAEMON_ABSENT' $callerCheck.Data.Code 'The shared root check did not report the daemon as absent.'
        Assert-Equal 0 $callerCheck.Data.DaemonCount 'The absent daemon result claimed a daemon count.'
        Assert-Equal $false $callerCheck.Data.RootVerified 'The absent daemon result claimed a verified root.'
        Assert-True ($callerCheck.Message -match '(?i)daemon') "The absent daemon result did not name the daemon: $($callerCheck.Message)"
        Assert-Equal 0 @($callerState.Calls | Where-Object { (@($_) -join ' ') -like 'setting*' }).Count 'The shared root check changed the vendor root instead of leaving that to the caller.'

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
        Assert-Root12Failure -Result $bootAdbCase.Result -Journal $bootAdbCase.Journal -Code 'PREINSTALL_BOOT_TIMEOUT' -Message 'A failed pre-install readiness query was accepted.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $bootAdbState.Calls -Pattern 'adb*-v*-c*install*') 'A failed pre-install readiness query still installed the APK.'
        Assert-Equal -1 (Get-Root12CallIndex -Calls $bootAdbState.Calls -Pattern '*root_permission*-val*false*') 'A failed pre-install readiness query disabled the temporary vendor root.'

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
        if ($null -ne $daemonDelayVariable) {
            $script:ToolkitAndroid12DaemonSettleMilliseconds = $daemonDelayVariable.Value
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
    'ROOT_UNAVAILABLE',
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
        RootShellMissing = $false
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
                if ($State.RootShellMissing) {
                    return [pscustomobject]@{ ExitCode = 127; Text = '/system/bin/sh: su: not found' }
                }
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
        Assert-True ($kitsuneCall -gt $kernelCall) 'The Android 15 workflow did not check for a Kitsune package after the KernelSU package.'
        Assert-True ($rootShellCall -gt $kitsuneCall) 'The Android 15 workflow verified the root shell before reporting an inherited Kitsune package.'
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

        foreach ($orderCase in @(
                [pscustomobject]@{ Kitsune = $true; Missing = $true; Code = 'KITSUNE_PRESENT'; Status = 'CriticalError'; KitsuneAbsent = $false; RootShell = $false; Label = 'an inherited Kitsune package and no su' },
                [pscustomobject]@{ Kitsune = $false; Missing = $true; Code = 'ROOT_UNAVAILABLE'; Status = 'CriticalError'; KitsuneAbsent = $true; RootShell = $false; Label = 'no Kitsune package and no su' },
                [pscustomobject]@{ Kitsune = $false; Missing = $false; Code = 'ROOT_DENIED'; Status = 'CriticalError'; KitsuneAbsent = $true; RootShell = $false; Label = 'no Kitsune package and a denied su' },
                [pscustomobject]@{ Kitsune = $false; Missing = $false; Code = 'OK'; Status = 'Success'; KitsuneAbsent = $true; RootShell = $true; Label = 'the verified built-in root' }
            )) {
            $orderState = New-Root15ManagerState -Install $install
            $orderState.RootSettings[[string]$orderState.CloneIndex] = $true
            $orderState.KitsuneInstalled = $orderCase.Kitsune
            $orderState.RootShellMissing = $orderCase.Missing
            if ($orderCase.Code -ceq 'ROOT_DENIED') {
                $orderState.RootShellText = 'uid=2000(shell) gid=2000(shell) groups=2000(shell)'
            }
            $orderChecks = Test-Android15Root -ManagerPath $install.ManagerPath -InstanceIndex $orderState.CloneIndex -Runner (New-Root15ManagerRunner -State $orderState)
            Assert-Equal $orderCase.Status $orderChecks.Status "The Android 15 check reported the wrong status for $($orderCase.Label)."
            Assert-Equal $orderCase.Code $orderChecks.Data.Code "The Android 15 check reported the wrong code for $($orderCase.Label)."
            Assert-Equal $orderCase.KitsuneAbsent $orderChecks.Data.KitsuneAbsent "The Android 15 check reported the wrong Kitsune absence for $($orderCase.Label)."
            Assert-Equal $orderCase.RootShell $orderChecks.Data.RootShell "The Android 15 check reported the wrong root shell state for $($orderCase.Label)."
            Assert-Equal $true $orderChecks.Data.RootPermission "The Android 15 check lost the vendor root state for $($orderCase.Label)."
            $orderKitSUCall = Get-Root15CallIndex -Calls $orderState.Calls -Pattern '*dumpsys package me.weishu.kernelsu*'
            $orderListCall = Get-Root15CallIndex -Calls $orderState.Calls -Pattern '*pm list packages*'
            $orderRootCall = Get-Root15CallIndex -Calls $orderState.Calls -Pattern '*su -c id*'
            Assert-True ($orderListCall -gt $orderKitSUCall) "The Android 15 check did not query the package list after the KernelSU check ($($orderCase.Label))."
            if ($orderCase.Code -ceq 'KITSUNE_PRESENT') {
                Assert-Equal -1 $orderRootCall "The Android 15 check probed the root shell before reporting the inherited Kitsune package ($($orderCase.Label))."
                Assert-True ($orderChecks.Message -match 'package:io\.github\.huskydg\.magisk') "The inherited Kitsune report does not carry the observed package evidence ($($orderCase.Label)): $($orderChecks.Message)"
                Assert-True ($orderChecks.Message -match '(?i)cannot account for') "The inherited Kitsune report does not explain itself ($($orderCase.Label))"
            }
            else {
                Assert-True ($orderRootCall -gt $orderListCall) "The Android 15 check did not probe the root shell after the package list ($($orderCase.Label))."
            }
            if ($orderCase.Code -ceq 'ROOT_UNAVAILABLE') {
                Assert-True ($orderChecks.Message -match '(?i)not available') "A missing su binary was reported as a policy denial ($($orderCase.Label)): $($orderChecks.Message)"
                Assert-True ($orderChecks.Message -match '(?i)unknown') "A missing su binary does not say the root state is unknown ($($orderCase.Label))"
            }
            if ($orderCase.Status -ceq 'Success') {
                Assert-Equal $true $orderChecks.Data.KernelSU "The verified built-in root does not report KernelSU ($($orderCase.Label))"
                Assert-Equal '3.2.5' $orderChecks.Data.KernelSUVersion "The verified built-in root does not report the KernelSU version ($($orderCase.Label))"
            }
        }

        $inheritedCloneState = New-Root15ManagerState -Install $install
        $inheritedCloneState.KitsuneInstalled = $true
        $inheritedCloneState.RootShellMissing = $true
        $inheritedCloneCase = Invoke-Root15Case -State $inheritedCloneState -Instance $android15 -JournalRoot $journalRoot
        Assert-Root15Failure -Result $inheritedCloneCase.Result -Journal $inheritedCloneCase.Journal -Code 'KITSUNE_PRESENT' -Message 'A clone that inherited Kitsune was reported as a built-in KernelSU root.'
        Assert-Equal $false $inheritedCloneCase.Result.Data.KitsuneAbsent 'A clone that inherited Kitsune was reported as free of the Kitsune package.'
        Assert-Equal -1 (Get-Root15CallIndex -Calls $inheritedCloneState.Calls -Pattern '*su -c id*') 'A clone that inherited Kitsune was probed for a root shell before the Kitsune report.'

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
    Assert-True ($verificationSource -notmatch "(?i)Code\s*=\s*'UNKNOWN'") 'The shared verification source reports an UNKNOWN failure code.'
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
    Assert-True ($verificationSource -notmatch '(?i)memory\s*integrity|exploit\s*protection|credential\s*guard') 'The shared verification source mentions a memory integrity, exploit protection, or credential guard control.'
    foreach ($mutatingPattern in @('(?i)set-?itemproperty|new-?itemproperty|remove-?itemproperty|reg\s+add|reg\s+delete|enablehypervisorlaunchtype|disablehypervisorlaunchtype|bcdedit\s+/set')) {
        Assert-True ($verificationSource -notmatch $mutatingPattern) "The shared verification source uses a mutating platform control: $mutatingPattern"
    }

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
    'CLONE_REQUIRED',
    'CLONE_RECORD_INVALID',
    'CLONE_UNVERIFIED',
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
    'GUEST_COMMAND_INVALID',
    'PACKAGES_REQUIRED',
    'PACKAGE_NAME_INVALID',
    'PACKAGE_LIST_UNREADABLE',
    'PACKAGE_NOT_INSTALLED',
    'ALL_APPS_REFUSED',
    'SCOPE_INCOMPLETE',
    'TEMPLATE_NOT_BLACKLIST',
    'TEMPLATE_MISSING',
    'KERNELSU_ABSENT'
)
$script:ConcealmentRootPackages = @(
    'org.frknkrc44.hma_oss',
    'io.github.huskydg.magisk',
    'com.coderstory.toolkit',
    'me.weishu.kernelsu'
)
$script:ConcealmentModuleRoot = '/data/adb/modules'
$script:ConcealmentSelectedPackage = 'jp.pokemon.pokemontcgp'
$script:ConcealmentSecondPackage = 'com.example.other'
$script:ConcealmentAllowlistBytes = 'kernel su allowlist bytes'
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

function New-ConcealmentCloneFixture {
    param(
        [object]$Install,
        [string]$Name = 'Concealment clone',
        [int]$CloneIndex = 5
    )

    $cloneRoot = Join-Path $Install.VmsPath ([string]$CloneIndex)
    [void][IO.Directory]::CreateDirectory($cloneRoot)
    [IO.File]::WriteAllText((Join-Path $cloneRoot 'system.img'), 'concealment clone disk payload')
    return [pscustomobject]@{
        Code = 'OK'
        Step = 'complete'
        SourceIndex = $Install.SourceIndex
        CloneIndex = $CloneIndex
        CloneName = $Name
        RootVerified = $true
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
    param(
        [string]$CacheRoot,
        [string]$HmaAssetName = 'HMA-OSS-oss-161-release.apk',
        [string]$VectorAssetName = 'Vector-v2.2-3080-Release.zip'
    )

    $records = @(
        [pscustomobject]@{ Id = 'hma'; Directory = 'hma'; AssetName = $HmaAssetName; Url = 'https://github.com/frknkrc44/HMA-OSS/releases/download/oss-161/HMA-OSS-oss-161-release.apk'; Payload = 'pinned hma apk payload' },
        [pscustomobject]@{ Id = 'vector'; Directory = 'vector'; AssetName = $VectorAssetName; Url = 'https://github.com/JingMatrix/Vector/releases/download/v2.2/Vector-v2.2-3080-Release.zip'; Payload = 'pinned vector module payload' }
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
        Hma = (Join-Path (Join-Path $CacheRoot 'hma') $HmaAssetName)
        Vector = (Join-Path (Join-Path $CacheRoot 'vector') $VectorAssetName)
    }
}

function New-ConcealmentConfigText {
    param(
        [string[]]$RootPackages = $script:ConcealmentRootPackages,
        [hashtable]$Scope = @{},
        [int]$ConfigVersion = 93,
        [switch]$OmitConfigVersion,
        [int]$DeepLevels = 0
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
    $document['settingsTemplates'] = [ordered]@{}
    $scopeMap = [ordered]@{}
    foreach ($key in @($Scope.Keys | Sort-Object)) {
        $scopeMap[[string]$key] = [string]$Scope[$key]
    }
    $document['scope'] = $scopeMap
    if ($DeepLevels -gt 0) {
        $deep = 'leaf'
        for ($level = $DeepLevels; $level -ge 1; $level--) {
            $deep = [pscustomobject]@{ level = $level; child = $deep }
        }
        $document['extra'] = $deep
    }
    return (($document | ConvertTo-Json -Depth 64) + [Environment]::NewLine)
}

function New-ConcealmentGuestState {
    param([object]$Install)

    return @{
        Install = $Install
        SourceIndex = [string]$Install.SourceIndex
        CloneIndex = '5'
        Calls = @()
        Files = @{}
        ConfigPath = '/data/user/0/org.frknkrc44.hma_oss/files/config.json'
        ConfigText = ''
        Packages = @()
        Modules = @()
        HmaPackage = [string]$script:ConcealmentRootPackages[0]
        AdbFailPattern = ''
        CatFailPattern = ''
        CatCorruptPattern = ''
        ExtractEntries = @('zygisk_vector')
        ExtractExtraFiles = @()
        ModulePropText = 'id=zygisk_vector
name=Vector
'
        PushExitCode = 0
        InstallExitCode = 0
        ExtractExitCode = 0
        MoveExitCode = 0
        WriteFailPattern = ''
        JournalLockPath = ''
        JournalLockPattern = ''
        JournalLock = $null
        Instances = @(
            [pscustomobject]@{ Index = 0; Name = 'Base'; IsMain = $true; Android = '15.0' },
            [pscustomobject]@{ Index = $Install.SourceIndex; Name = 'Concealment target'; IsMain = $false; Android = '15.0' },
            [pscustomobject]@{ Index = 5; Name = 'Concealment clone'; IsMain = $false; Android = '15.0' }
        )
    }
}

function Invoke-ConcealmentGuestShell {
    param(
        [hashtable]$State,
        [string]$Command
    )

    if ($Command -match '^cat (\S+)$') {
        $path = $Matches[1]
        if (-not [string]::IsNullOrWhiteSpace([string]$State.CatFailPattern) -and $path -like $State.CatFailPattern) {
            return [pscustomobject]@{ ExitCode = 1; Text = ('cat: ' + $path + ': No such file or directory') }
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$State.CatCorruptPattern) -and $path -like $State.CatCorruptPattern) {
            return [pscustomobject]@{ ExitCode = 0; Text = 'truncated backup bytes' }
        }
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
        foreach ($entry in @($State.ExtractEntries)) {
            $entryName = [string]$entry
            if ($entryName -ceq 'module.prop') {
                $State.Files[($extractPath + '/module.prop')] = [string]$State.ModulePropText
                continue
            }
            $State.Files[($extractPath + '/' + $entryName)] = 'vector module payload'
        }
        foreach ($extra in @($State.ExtractExtraFiles)) {
            $State.Files[($extractPath + '/' + [string]$extra)] = 'id=other'
        }
        return [pscustomobject]@{ ExitCode = 0; Text = ('inflating: ' + ((@($State.ExtractEntries) | ForEach-Object { [string]$_ + '/' })) -join '') }
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
        $State.Files[($script:ConcealmentModuleRoot + '/' + $child + '/module.prop')] = 'id=zygisk_vector'
        return [pscustomobject]@{ ExitCode = 0; Text = '' }
    }
    if ($Command -match '^rm -rf (.+)$') {
        foreach ($removable in @($Matches[1] -split ' ')) {
            foreach ($known in @([string[]]@($State.Files.Keys))) {
                if ($known.StartsWith(($removable + '/'), [StringComparison]::Ordinal)) {
                    $State.Files.Remove($known)
                }
            }
            $State.Files.Remove([string]$removable)
        }
        return [pscustomobject]@{ ExitCode = 0; Text = '' }
    }
    if ($Command -match '^mv (\S+) ' + [regex]::Escape($script:ConcealmentModuleRoot) + '/zygisk_vector$') {
        if ($State.MoveExitCode -ne 0) {
            return [pscustomobject]@{ ExitCode = $State.MoveExitCode; Text = 'mv: cannot move the extracted module' }
        }
        $stagedRoot = [string]$Matches[1]
        if (-not $State.Files.ContainsKey(($stagedRoot + '/module.prop'))) {
            return [pscustomobject]@{ ExitCode = 1; Text = ('mv: cannot stat ' + $stagedRoot + '/module.prop') }
        }
        $State.Modules = @($State.Modules) + 'zygisk_vector'
        return [pscustomobject]@{ ExitCode = 0; Text = '' }
    }
    return [pscustomobject]@{ ExitCode = 1; Text = 'unsupported guest command' }
}

function Release-ConcealmentJournalLock {
    param([hashtable]$State)

    if ($null -ne $State.JournalLock) {
        $State.JournalLock.Dispose()
        $State.JournalLock = $null
    }
}

function New-ConcealmentManagerRunner {
    param([hashtable]$State)

    return {
        param($ActualFilePath, $ActualArgumentList)
        $State.Calls += ,@($ActualArgumentList)
        $arguments = @($ActualArgumentList | ForEach-Object { [string]$_ })
        if ($null -eq $State.JournalLock -and -not [string]::IsNullOrWhiteSpace([string]$State.JournalLockPath) -and
            ((@($ActualArgumentList) -join ' ') -like $State.JournalLockPattern)) {
            $State.JournalLock = [IO.File]::Open([string]$State.JournalLockPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        }
        if ($arguments.Count -gt 0 -and $arguments[0] -ceq 'info') {
            if ($arguments.Count -lt 3 -or $arguments[1] -cne '-v') {
                return [pscustomobject]@{ ExitCode = 1; Text = '{"error_code":1}' }
            }
            $requested = [string]$arguments[2]
            $matched = @($State.Instances | Where-Object { [string]$_.Index -ceq $requested })
            if ($matched.Count -eq 0) {
                return [pscustomobject]@{ ExitCode = 1; Text = '{"error_code":1}' }
            }
            $reported = @()
            foreach ($reportedInstance in $matched) {
                $reported += [pscustomobject][ordered]@{
                    index           = [string]$reportedInstance.Index
                    name            = [string]$reportedInstance.Name
                    is_main         = [string]$reportedInstance.IsMain
                    android_version = [string]$reportedInstance.Android
                }
            }
            return [pscustomobject]@{ ExitCode = 0; Text = (ConvertTo-Json -InputObject @($reported) -Depth 4 -Compress) }
        }
        if ($arguments.Count -lt 5 -or $arguments[0] -cne 'adb' -or $arguments[1] -cne '-v' -or $arguments[3] -cne '-c') {
            return [pscustomobject]@{ ExitCode = 1; Text = 'unsupported manager request' }
        }
        if ($arguments[2] -cne [string]$State.CloneIndex -and $arguments[2] -cne [string]$State.SourceIndex) {
            return [pscustomobject]@{ ExitCode = 1; Text = 'the request did not target a fixture instance' }
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
        if ($request -match '^shell su -c ''(.*)''$') {
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

function Get-ConcealmentSourceInstanceCalls {
    param([object]$State)

    $sourceIndex = [string]$State.SourceIndex
    return @($State.Calls | Where-Object {
            $call = @($_)
            ($call.Count -ge 3 -and [string]$call[0] -ceq 'adb' -and [string]$call[2] -ceq $sourceIndex)
        })
}

function Assert-ConcealmentCloneOnly {
    param(
        [object]$State,
        [string]$Message
    )

    $sourceCalls = @(Get-ConcealmentSourceInstanceCalls -State $State)
    Assert-Equal 0 $sourceCalls.Count "$Message A request acted on the selected source instance instead of the verified clone."
    foreach ($call in @($State.Calls)) {
        $arguments = @($call)
        if ($arguments.Count -ge 3 -and [string]$arguments[0] -ceq 'adb') {
            Assert-Equal ([string]$State.CloneIndex) ([string]$arguments[2]) "$Message An ADB request did not target the verified clone."
        }
    }
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
        [string]$Message,
        [string]$ReasonPattern = ''
    )

    Assert-Equal 'Warning' $Result.Status $Message
    Assert-True ($null -ne $Result.Data) "$Message The warning carried no data."
    Assert-Equal $Code $Result.Data.Code "$Message The warning reported the wrong code."
    if (-not [string]::IsNullOrWhiteSpace($ReasonPattern)) {
        Assert-True ([string]$Result.Message -match $ReasonPattern) "$Message The warning did not preserve the reader reason. $($Result.Message)"
    }
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
    foreach ($commandName in @('Install-ConcealmentDependencies', 'Get-HmaConfig', 'New-ReusableRootTemplate', 'Set-AppConcealment', 'Test-Concealment', 'Get-KernelSUProfileSteps', 'Set-ConcealmentGuestText', 'New-ConcealmentGuestCommand')) {
        Assert-True ($null -ne (Get-Command $commandName -CommandType Function -ErrorAction SilentlyContinue)) "Concealment command is unavailable: $commandName"
    }
    Assert-True (Test-Path -LiteralPath $concealmentScriptPath -PathType Leaf) 'src/Concealment.ps1 does not exist.'

    $concealmentSource = [IO.File]::ReadAllText($concealmentScriptPath)
    # The MuMu manager strips double quotes, so no module may build its own double-quoted su -c form. One shared funnel in Common.ps1 does it.
    $modulePaths = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'src') -Filter '*.ps1' -File | Sort-Object Name)
    Assert-True ($modulePaths.Count -ge 1) 'No module files were found under src/.'
    foreach ($moduleFile in $modulePaths) {
        $moduleSource = [IO.File]::ReadAllText($moduleFile.FullName)
        Assert-Equal 0 ([regex]::Matches($moduleSource, 'su -c "')).Count "A nested double-quoted su -c command is still constructed in $($moduleFile.Name), which the MuMu manager strips."
    }
    $commonSource = [IO.File]::ReadAllText($commonPath)
    Assert-True ($commonSource -match 'function New-ToolkitGuestCommand') 'The shared guest command funnel does not live in the always-loaded Common module.'
    Assert-True ($concealmentSource -match 'New-ToolkitGuestCommand') 'The concealment flow does not use the shared guest command funnel.'
    Assert-True ([IO.File]::ReadAllText($verificationScriptPath) -match 'New-ToolkitGuestCommand') 'The read-only report does not use the shared guest command funnel.'
    $removalCompositions = @([regex]::Matches($concealmentSource, "'rm -rf ' \+"))
    Assert-Equal 1 $removalCompositions.Count 'A guest removal is not composed exactly once through the quoting helper with the validated staging paths.'
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
            'dd if=',
            'install-multiple',
            'New-InstanceClone',
            "'UNKNOWN'"
        )) {
        Assert-True ($concealmentSource -notmatch [regex]::Escape($forbidden)) "Concealment source uses a forbidden construct: $forbidden"
    }
    foreach ($sharedPrimitive in @('Invoke-ToolkitManagerAdb', 'Get-ToolkitPackageVersion', 'New-ToolkitRootFailure', 'Save-ToolkitManifestAsset', 'Format-ToolkitQuotedPath', 'Write-JournalEvent', 'Get-MuMuInstanceRecord', 'Get-MuMuInstanceRootPath', 'Measure-MuMuInstanceDiskBytes')) {
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
    Assert-Equal ($script:ConcealmentModuleRoot + '/zygisk_vector') $script:ConcealmentVectorModulePath 'The Vector module path is not the installed zygisk_vector module directory.'
    Assert-Equal 'zygisk_vector' $script:ConcealmentVectorModuleName 'The Vector module name is not the installed zygisk_vector module id.'
    Assert-Equal 2 ([regex]::Matches($concealmentSource, 'Save-ToolkitManifestAsset')).Count 'The concealment flow does not call the manifest asset helper exactly twice.'
    Assert-Equal 2 ([regex]::Matches($concealmentSource, 'Save-ToolkitManifestAsset[^\r\n]*-RequireCached')).Count 'A concealment asset call does not use the cached-only contract, so a mutating phase could reach the network.'
    Assert-True ($concealmentSource -notmatch 'Save-ToolkitManifestAsset[^\r\n]*-Fetch') 'A concealment asset call injects a downloader into a mutating phase.'
    $allowlistSourceLines = @()
    foreach ($sourceLine in @($concealmentSource -split "`r?`n")) {
        if ($sourceLine -match 'ConcealmentKernelSUAllowlistPath') {
            $allowlistSourceLines += $sourceLine
        }
    }
    Assert-True ($allowlistSourceLines.Count -ge 1) 'The concealment flow does not probe the KernelSU allowlist at all.'
    $allowlistProbes = 0
    foreach ($allowlistLine in $allowlistSourceLines) {
        if ($allowlistLine -match '^\$script:ConcealmentKernelSUAllowlistPath\s*=') {
            continue
        }
        $allowlistProbes++
        Assert-True ($allowlistLine -match 'ls -l') "The KernelSU allowlist path is used outside the read-only ls -l probe: $allowlistLine"
        Assert-True ($allowlistLine -notmatch 'base64 -d|\bmv\b|\brm\b|\bcp\b|WriteAllText|Set-ConcealmentGuestText') "The KernelSU allowlist path is used in a write: $allowlistLine"
    }
    Assert-Equal 1 $allowlistProbes 'The KernelSU allowlist path is used by more than the single read-only ls -l probe.'

    $profileSteps = @(Get-KernelSUProfileSteps -PackageName $script:ConcealmentSelectedPackage)
    Assert-Equal 3 $profileSteps.Count 'The KernelSU handoff did not return exactly three steps.'
    Assert-Equal ('Open KernelSU Superuser and select ' + $script:ConcealmentSelectedPackage + '.') $profileSteps[0] 'The KernelSU handoff lost the package step.'
    Assert-Equal 'Keep Superuser disabled.' $profileSteps[1] 'The KernelSU handoff lost the disabled Superuser step.'
    Assert-Equal 'Choose Custom and enable Umount modules.' $profileSteps[2] 'The KernelSU handoff lost the Custom and Umount modules step.'
    Assert-True (@(Get-KernelSUProfileSteps -PackageName '   ').Count -eq 0) 'The KernelSU handoff produced steps for a blank package name.'

    $safeGuestCommand = New-ConcealmentGuestCommand -Command ('cat ' + '/data/user/0/org.frknkrc44.hma_oss/files/config.json')
    Assert-Equal 'Success' $safeGuestCommand.Status 'The guest command guard refused a plain allowlisted path.'
    Assert-Equal "shell su -c 'cat /data/user/0/org.frknkrc44.hma_oss/files/config.json'" $safeGuestCommand.Data.Command 'The guest command is not single quoted for the MuMu manager.'
    foreach ($safeGuestCase in @(
            [pscustomobject]@{ Command = 'ls /data/adb/modules/zygisk_vector'; Label = 'a plain ls' },
            [pscustomobject]@{ Command = 'ls -l /data/adb/modules/ksu/.allowlist'; Label = 'a read-only ls -l' },
            [pscustomobject]@{ Command = 'mkdir -p /data/local/tmp/x && unzip -o /data/local/tmp/v.zip -d /data/local/tmp/x'; Label = 'a staged extraction' },
            [pscustomobject]@{ Command = 'echo QUJDRA== | base64 -d > /data/user/0/a/config.json.toolkit.tmp && mv /data/user/0/a/config.json.toolkit.tmp /data/user/0/a/config.json'; Label = 'a base64 write' },
            [pscustomobject]@{ Command = 'rm -rf /data/local/tmp/x /data/local/tmp/v.zip'; Label = 'a cleanup' }
        )) {
        $safeGuest = New-ConcealmentGuestCommand -Command $safeGuestCase.Command
        Assert-Equal 'Success' $safeGuest.Status "The guest command guard refused $($safeGuestCase.Label)."
    }
    foreach ($unsafeGuestCase in @(
            [pscustomobject]@{ Command = "cat /data/user/0/my app/config.json"; Reason = 'a path with a space' },
            [pscustomobject]@{ Command = 'cat /data/user/0/a''b/config.json'; Reason = 'a single quote in a path' },
            [pscustomobject]@{ Command = 'cat "/data/user/0/a/config.json"'; Reason = 'a nested double quote' },
            [pscustomobject]@{ Command = 'cat $(id)'; Reason = 'a command substitution' },
            [pscustomobject]@{ Command = 'cat /data/a`id`'; Reason = 'a backtick substitution' },
            [pscustomobject]@{ Command = "cat /data/a`nrm -rf /data"; Reason = 'a newline' },
            [pscustomobject]@{ Command = 'cat /data/a; rm -rf /data/b'; Reason = 'a command separator' },
            [pscustomobject]@{ Command = 'cat /data/a && curl http://host/'; Reason = 'a network command' },
            [pscustomobject]@{ Command = 'cat /data/a$(rm -rf /)'; Reason = 'an inline substitution' },
            [pscustomobject]@{ Command = '   '; Reason = 'a blank command' }
        )) {
        $unsafeGuest = New-ConcealmentGuestCommand -Command $unsafeGuestCase.Command
        Assert-Equal 'CriticalError' $unsafeGuest.Status "The guest command guard accepted $($unsafeGuestCase.Reason)."
        Assert-Equal 'GUEST_COMMAND_INVALID' $unsafeGuest.Data.Code "The guest command guard reported the wrong code for $($unsafeGuestCase.Reason)."
    }
    Assert-Equal 'CriticalError' (New-ConcealmentGuestCommand -Command '/data/local/tmp/x').Status 'The guest command guard accepted a bare path with no command.'

    # The shared funnel is the only place a su -c request is built, so it must refuse on its own and keep the reason the wrapper reports.
    Assert-Equal 'Success' (New-ToolkitGuestCommand -Command 'ls /data/adb/modules/zygisk_vector').Status 'The shared guest command funnel refused a plain read-only ls.'
    Assert-Equal 'CriticalError' (New-ToolkitGuestCommand -Command 'curl http://host/').Status 'The shared guest command funnel accepted an unsupported command word.'
    $refusedGuest = New-ConcealmentGuestCommand -Command 'cat /data/user/0/../0/config.json'
    Assert-True ($refusedGuest.Message -match 'not a plain absolute guest path') "The guest command guard lost the refusal reason: $($refusedGuest.Message)"

    $concealmentRoot = Join-Path $testRoot 'concealment fixtures'
    $journalRoot = Join-Path $concealmentRoot 'journals'
    $assetCacheRoot = Join-Path $concealmentRoot 'assets'
    $install = New-Root12InstallFixture -InstallRoot (Join-Path $concealmentRoot 'MuMu Global') -SourceIndex 3
    $instance = New-ConcealmentInstanceFixture -Install $install
    $clone = New-ConcealmentCloneFixture -Install $install
    $cloneIndex = [int]$clone.CloneIndex
    $assets = New-ConcealmentAssetFixture -CacheRoot $assetCacheRoot
    $runner = New-ConcealmentManagerRunner -State (New-ConcealmentGuestState -Install $install)

    foreach ($badQuotedPath in @('   ', 'a"b', ("a`nb"), 'a b/../c', ' C:\assets\app.apk', 'C:assets\app.apk', 'C:\assets\app.apk&calc', "/data/local/tmp/x")) {
        $badPath = Format-ToolkitQuotedPath -Path $badQuotedPath -Label 'asset path'
        Assert-Equal 'CriticalError' $badPath.Status "The quoted path guard accepted an unsafe path: $badQuotedPath"
        Assert-Equal 'ASSET_PATH_INVALID' $badPath.Data.Code 'The quoted path guard reported the wrong code.'
    }
    $goodPath = Format-ToolkitQuotedPath -Path 'C:\parent dir\app-release.apk' -Label 'asset path'
    Assert-Equal 'Success' $goodPath.Status 'The quoted path guard refused a valid asset path.'
    Assert-Equal '"C:\parent dir\app-release.apk"' $goodPath.Data 'The quoted path guard did not return one quoted element.'

    $acquisitionRoot = Join-Path $concealmentRoot 'acquisition'
    [void][IO.Directory]::CreateDirectory($acquisitionRoot)
    $fetchState = @{ Calls = 0 }
    $pinnedAsset = $assets.Hma
    $fetcher = {
        param($RequestedUrl, $RequestedPath)
        $fetchState.Calls++
        [IO.File]::Copy($pinnedAsset, $RequestedPath)
    }.GetNewClosure()
    $acquired = Save-ToolkitManifestAsset -Manifest $assets.Manifest -Id 'hma' -CacheRoot $acquisitionRoot -Fetch $fetcher
    Assert-Equal 'Success' $acquired.Status "The acquisition phase did not accept a fetched pinned asset. $($acquired.Message)"
    Assert-Equal 1 $fetchState.Calls 'The acquisition phase did not fetch the missing pinned asset exactly once.'
    Assert-Equal 'OK' $acquired.Data.Code 'The acquisition phase reported the wrong success code.'
    $expectedHma = @($assets.Manifest.dependencies | Where-Object { $_.id -eq 'hma' })[0]
    $fetchedFile = Get-Item -LiteralPath ([string]$acquired.Data.Asset)
    Assert-Equal ([long]$expectedHma.size) ([long]$fetchedFile.Length) 'The acquisition phase did not store the pinned asset at its pinned size.'
    Assert-Equal ([string]$expectedHma.sha256) (Get-FileHash -LiteralPath $fetchedFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant() 'The acquisition phase did not store the pinned asset at its pinned SHA-256.'
    $shortFetchRoot = Join-Path $concealmentRoot 'short fetch'
    [void][IO.Directory]::CreateDirectory($shortFetchRoot)
    $shortFetcher = { param($RequestedUrl, $RequestedPath) [IO.File]::WriteAllText($RequestedPath, 'short') }.GetNewClosure()
    $shortAsset = Save-ToolkitManifestAsset -Manifest $assets.Manifest -Id 'hma' -CacheRoot $shortFetchRoot -Fetch $shortFetcher
    Assert-Equal 'CriticalError' $shortAsset.Status 'The size and SHA-256 gate accepted a short downloaded asset.'
    Assert-Equal 'ASSET_VERIFICATION_FAILED' $shortAsset.Data.Code 'A short downloaded asset did not report the verification gate.'
    $wrongHashRoot = Join-Path $concealmentRoot 'wrong hash fetch'
    [void][IO.Directory]::CreateDirectory($wrongHashRoot)
    $wrongHashManifest = [pscustomobject]@{
        dependencies = @([pscustomobject][ordered]@{
                    id        = 'hma'
                    version   = 'pinned'
                    assetName = 'HMA-OSS-oss-161-release.apk'
                    url       = 'https://github.com/frknkrc44/HMA-OSS/releases/download/oss-161/HMA-OSS-oss-161-release.apk'
                    size      = [long]22
                    sha256    = '1111111111111111111111111111111111111111111111111111111111111111'
                })
    }
    $wrongHashFetcher = { param($RequestedUrl, $RequestedPath) [IO.File]::WriteAllText($RequestedPath, 'twenty two byte payload!') }.GetNewClosure()
    $wrongHashAsset = Save-ToolkitManifestAsset -Manifest $wrongHashManifest -Id 'hma' -CacheRoot $wrongHashRoot -Fetch $wrongHashFetcher
    Assert-Equal 'CriticalError' $wrongHashAsset.Status 'The size and SHA-256 gate accepted an asset with the wrong hash at the right size.'
    Assert-Equal 'ASSET_VERIFICATION_FAILED' $wrongHashAsset.Data.Code 'A wrong-hash asset did not report the verification gate.'
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
    $unusableCacheRoot = Join-Path $concealmentRoot 'unusable cache'
    [void][IO.Directory]::CreateDirectory($unusableCacheRoot)
    $unusableCacheFile = Join-Path $unusableCacheRoot 'blocker'
    [IO.File]::WriteAllText($unusableCacheFile, 'not a directory')
    $unusableCache = Save-ToolkitManifestAsset -Manifest $assets.Manifest -Id 'hma' -CacheRoot (Join-Path $unusableCacheFile 'nested')
    Assert-Equal 'CriticalError' $unusableCache.Status 'An unusable dependency cache root was accepted.'
    Assert-Equal 'CACHE_UNAVAILABLE' $unusableCache.Data.Code 'An unusable dependency cache root reported the wrong code.'
    $cachedOnlyRoot = Join-Path $concealmentRoot 'cached only'
    [void][IO.Directory]::CreateDirectory($cachedOnlyRoot)
    $forbiddenFetcher = { param($RequestedUrl, $RequestedPath) throw 'the cached-only contract must never fetch' }.GetNewClosure()
    $cachedOnly = Save-ToolkitManifestAsset -Manifest $assets.Manifest -Id 'hma' -CacheRoot $cachedOnlyRoot -Fetch $forbiddenFetcher -RequireCached
    Assert-Equal 'CriticalError' $cachedOnly.Status 'The cached-only contract accepted an absent asset.'
    Assert-Equal 'ASSET_VERIFICATION_FAILED' $cachedOnly.Data.Code 'The cached-only contract reported the wrong code for an absent asset.'

    $installState = New-ConcealmentGuestState -Install $install
    $installState.Packages = @($script:ConcealmentRootPackages[1], $script:ConcealmentRootPackages[3], $script:ConcealmentSelectedPackage)
    $installJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $dependencyResult = Install-ConcealmentDependencies -Instance $instance -VerifiedClone $clone -Manifest $assets.Manifest -Journal $installJournal -CacheRoot $assetCacheRoot -Runner (New-ConcealmentManagerRunner -State $installState)
    Assert-True ($dependencyResult.Status -eq 'Success') "Concealment dependency installation failed. $($dependencyResult.Message)"
    Assert-Equal 'OK' $dependencyResult.Data.Code 'Concealment dependency installation reported an invalid code.'
    Assert-Equal $cloneIndex $dependencyResult.Data.CloneIndex 'Concealment dependency installation reported the wrong target instance.'
    Assert-Equal $clone.CloneName $dependencyResult.Data.CloneName 'Concealment dependency installation reported the wrong target clone.'
    Assert-Equal 'Completed' $installJournal.State 'Concealment dependency installation did not complete its journal.'
    $reopenedInstall = Get-OperationJournal -Path $installJournal.JournalPath
    Assert-Equal 'Completed' $reopenedInstall.State 'Concealment dependency installation did not persist its journal state.'
    Assert-Equal 'Success' $reopenedInstall.Result.Status 'Concealment dependency installation did not persist its result.'
    Assert-True (@($dependencyResult.Data.Installed) -ccontains 'hma') 'The verified HMA APK was not reported as installed.'
    Assert-True (@($dependencyResult.Data.Installed) -ccontains 'vector') 'The verified Vector module was not reported as installed.'
    Assert-Equal 0 @($dependencyResult.Data.AlreadyPresent).Count 'Concealment dependency installation reported an absent dependency as already present.'
    Assert-True (@($installState.Packages) -ccontains $script:ConcealmentRootPackages[0]) 'The HMA package was not installed on the clone.'
    Assert-True (@($installState.Modules) -ccontains 'zygisk_vector') 'The Vector module was not installed on the clone.'
    Assert-ConcealmentCloneOnly -State $installState -Message 'Concealment dependency installation acted outside the verified clone.'
    Assert-Equal 1 @(Get-ConcealmentCalls -State $installState -Pattern '*install -r*').Count 'The verified HMA APK was not installed exactly once.'
    Assert-Equal 1 @(Get-ConcealmentCalls -State $installState -Pattern '*push*').Count 'The verified Vector module was not pushed exactly once.'
    $installCallText = (@($installState.Calls) | ForEach-Object { @($_) -join ' ' }) -join ' '
    Assert-True ($installCallText -notmatch 'neozygisk|corepatch|kitsune') 'Concealment dependency installation used an asset outside its pinned pair.'
    Assert-True ($installCallText -match [regex]::Escape($assets.Vector)) 'The Vector module was not pushed from the verified cache path.'
    $pushArguments = [string[]]@(@(Get-ConcealmentCalls -State $installState -Pattern '*push*')[0])
    Assert-Equal 5 $pushArguments.Count 'The Vector module push carried an unexpected argument count.'
    Assert-Equal ('push "' + $assets.Vector + '" /data/local/tmp/Vector-v2.2-3080-Release.zip') $pushArguments[4] 'The Vector module push was not one quoted structured element.'
    $apkArguments = [string[]]@(@(Get-ConcealmentCalls -State $installState -Pattern '*install -r*')[0])
    Assert-Equal ('install -r "' + $assets.Hma + '"') $apkArguments[4] 'The HMA APK install was not one quoted structured element.'
    $moduleCall = Get-ConcealmentCallIndex -Calls $installState.Calls -Pattern ('*mv*' + $script:ConcealmentModuleRoot + '/zygisk_vector*')
    Assert-True ($moduleCall -ge 0) 'The extracted Vector module was not moved into the module directory.'

    $presentState = New-ConcealmentGuestState -Install $install
    $presentState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentRootPackages[3])
    $presentState.Modules = @('zygisk_vector')
    $presentJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $presentResult = Install-ConcealmentDependencies -Instance $instance -VerifiedClone $clone -Manifest $assets.Manifest -Journal $presentJournal -CacheRoot $assetCacheRoot -Runner (New-ConcealmentManagerRunner -State $presentState)
    Assert-Equal 'AlreadyApplied' $presentResult.Status 'Present concealment dependencies were not reported as already applied.'
    Assert-Equal 2 @($presentResult.Data.AlreadyPresent).Count 'Present concealment dependencies were not reported as already present.'
    Assert-Equal 0 @($presentResult.Data.Installed).Count 'Present concealment dependencies were reported as installed.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $presentState -Pattern '*install -r*').Count 'An already installed HMA APK was installed again.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $presentState -Pattern '*push*').Count 'An already installed Vector module was pushed again.'

    $emptyCacheRoot = Join-Path $concealmentRoot 'empty assets'
    [void][IO.Directory]::CreateDirectory($emptyCacheRoot)
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
        $defectResult = Install-ConcealmentDependencies -Instance $instance -VerifiedClone $clone -Manifest $defectFixture.Manifest -Journal $defectJournal -CacheRoot $defectRoot -Runner (New-ConcealmentManagerRunner -State $defectState)
        Assert-ConcealmentFailure -Result $defectResult -Journal $defectJournal -Code 'ASSET_VERIFICATION_FAILED' -Message "An unverified dependency was substituted: $($assetDefect.Label)."
        Assert-Equal 0 @($defectState.Calls).Count "An unverified dependency still changed the instance: $($assetDefect.Label)."
        Assert-Equal 2 @($defectState.Packages).Count "An unverified dependency still changed the package list: $($assetDefect.Label)."
    }
    $offlineState = New-ConcealmentGuestState -Install $install
    $offlineJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $offlineResult = Install-ConcealmentDependencies -Instance $instance -VerifiedClone $clone -Manifest $assets.Manifest -Journal $offlineJournal -CacheRoot $emptyCacheRoot -Runner (New-ConcealmentManagerRunner -State $offlineState)
    Assert-ConcealmentFailure -Result $offlineResult -Journal $offlineJournal -Code 'ASSET_VERIFICATION_FAILED' -Message 'The mutating concealment phase accepted a dependency that was not already in the verified cache.'
    Assert-Equal 0 @($offlineState.Calls).Count 'The mutating concealment phase reached the guest without a verified cached asset.'

    $noCloneState = New-ConcealmentGuestState -Install $install
    $noCloneJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $noCloneResult = Install-ConcealmentDependencies -Instance $instance -VerifiedClone $null -Manifest $assets.Manifest -Journal $noCloneJournal -CacheRoot $assetCacheRoot -Runner (New-ConcealmentManagerRunner -State $noCloneState)
    Assert-ConcealmentFailure -Result $noCloneResult -Journal $noCloneJournal -Code 'CLONE_REQUIRED' -Message 'Concealment dependency installation mutated an instance without a verified clone record.'
    Assert-Equal 0 @($noCloneState.Calls).Count 'Concealment dependency installation reached the manager without a verified clone record.'
    $noCloneApplyState = New-ConcealmentGuestState -Install $install
    $noCloneApplyJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $noCloneApplyResult = Set-AppConcealment -Instance $instance -VerifiedClone $null -Packages @($script:ConcealmentSelectedPackage) -Journal $noCloneApplyJournal -Runner (New-ConcealmentManagerRunner -State $noCloneApplyState)
    Assert-ConcealmentFailure -Result $noCloneApplyResult -Journal $noCloneApplyJournal -Code 'CLONE_REQUIRED' -Message 'Selected app concealment mutated an instance without a verified clone record.'
    Assert-Equal 0 @($noCloneApplyState.Calls).Count 'Selected app concealment reached the guest without a verified clone record.'
    Assert-Equal 0 @($noCloneApplyState.Files.Keys).Count 'Selected app concealment wrote a file without a verified clone record.'
    $foreignCloneInstall = New-Root12InstallFixture -InstallRoot (Join-Path $concealmentRoot 'Foreign MuMu') -SourceIndex 3
    foreach ($cloneDefect in @(
            [pscustomobject]@{ Clone = $null; Code = 'CLONE_REQUIRED'; Calls = 0; Label = 'no clone record' },
            [pscustomobject]@{ Clone = 'not a record'; Code = 'CLONE_RECORD_INVALID'; Calls = 0; Label = 'a clone record that is not an object' },
            [pscustomobject]@{ Clone = ([pscustomobject]@{ CloneIndex = -1; CloneName = 'Concealment clone' }); Code = 'CLONE_RECORD_INVALID'; Calls = 0; Label = 'a negative clone index' },
            [pscustomobject]@{ Clone = ([pscustomobject]@{ CloneIndex = 'five'; CloneName = 'Concealment clone' }); Code = 'CLONE_RECORD_INVALID'; Calls = 0; Label = 'a clone index that is not a number' },
            [pscustomobject]@{ Clone = ([pscustomobject]@{ CloneIndex = 5; CloneName = '   ' }); Code = 'CLONE_RECORD_INVALID'; Calls = 0; Label = 'a blank clone name' },
            [pscustomobject]@{ Clone = ([pscustomobject]@{ CloneIndex = 5; CloneName = 'Some other name' }); Code = 'CLONE_UNVERIFIED'; Calls = 1; Label = 'a clone name the manager does not report' },
            [pscustomobject]@{ Clone = ([pscustomobject]@{ CloneIndex = 7; CloneName = 'Concealment clone' }); Code = 'CLONE_UNVERIFIED'; Calls = 1; Label = 'a clone index the manager does not report' },
            [pscustomobject]@{ Clone = ([pscustomobject]@{ CloneIndex = 0; CloneName = 'Base' }); Code = 'CLONE_UNVERIFIED'; Calls = 1; Label = 'the base instance' },
            [pscustomobject]@{ Clone = ([pscustomobject]@{ CloneIndex = 5; CloneName = 'Concealment clone'; SourceIndex = 9 }); Code = 'CLONE_RECORD_INVALID'; Calls = 0; Label = 'a record from another selected instance' }
        )) {
        foreach ($entryPoint in @('Install-ConcealmentDependencies', 'Set-AppConcealment')) {
            $defectState = New-ConcealmentGuestState -Install $install
            $defectState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
            $defectState.Files[$defectState.ConfigPath] = (New-ConcealmentConfigText)
            $defectJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
            if ($entryPoint -ceq 'Install-ConcealmentDependencies') {
                $defectResult = Install-ConcealmentDependencies -Instance $instance -VerifiedClone $cloneDefect.Clone -Manifest $assets.Manifest -Journal $defectJournal -CacheRoot $assetCacheRoot -Runner (New-ConcealmentManagerRunner -State $defectState)
            }
            else {
                $defectResult = Set-AppConcealment -Instance $instance -VerifiedClone $cloneDefect.Clone -Packages @($script:ConcealmentSelectedPackage) -Journal $defectJournal -Runner (New-ConcealmentManagerRunner -State $defectState)
            }
            Assert-ConcealmentFailure -Result $defectResult -Journal $defectJournal -Code $cloneDefect.Code -Message "$entryPoint accepted $($cloneDefect.Label)."
            Assert-Equal $cloneDefect.Calls @($defectState.Calls).Count "$entryPoint issued an unexpected number of requests for $($cloneDefect.Label)."
            Assert-Equal 0 @(Get-ConcealmentCalls -State $defectState -Pattern 'adb*').Count "$entryPoint issued a guest request with $($cloneDefect.Label)."
            Assert-Equal 0 @($defectState.Files.Keys | Where-Object { $_ -like '*.backup-*' }).Count "$entryPoint wrote a configuration backup with $($cloneDefect.Label)."
            Assert-Equal 0 @($defectState.Modules).Count "$entryPoint changed a module with $($cloneDefect.Label)."
        }
    }
    $versionDriftState = New-ConcealmentGuestState -Install $install
    $versionDriftState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
    $versionDriftState.Files[$versionDriftState.ConfigPath] = (New-ConcealmentConfigText)
    $versionDriftState.Instances = @($versionDriftState.Instances | Where-Object { [string]$_.Index -cne '5' })
    $versionDriftState.Instances = @($versionDriftState.Instances) + @([pscustomobject]@{ Index = 5; Name = 'Concealment clone'; IsMain = $false; Android = '12.0' })
    $versionDriftJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $versionDriftResult = Set-AppConcealment -Instance $instance -VerifiedClone $clone -Packages @($script:ConcealmentSelectedPackage) -Journal $versionDriftJournal -Runner (New-ConcealmentManagerRunner -State $versionDriftState)
    Assert-ConcealmentFailure -Result $versionDriftResult -Journal $versionDriftJournal -Code 'CLONE_UNVERIFIED' -Message 'A clone that reports a different Android version was accepted.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $versionDriftState -Pattern 'adb*').Count 'A clone with a different Android version issued a guest request.'
    $missingVersionInstance = New-ConcealmentInstanceFixture -Install $install
    $missingVersionInstance.PSObject.Properties.Remove('AndroidVersion')
    $missingVersionState = New-ConcealmentGuestState -Install $install
    $missingVersionState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
    $missingVersionState.Files[$missingVersionState.ConfigPath] = (New-ConcealmentConfigText)
    $missingVersionJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $missingVersionResult = Set-AppConcealment -Instance $missingVersionInstance -VerifiedClone $clone -Packages @($script:ConcealmentSelectedPackage) -Journal $missingVersionJournal -Runner (New-ConcealmentManagerRunner -State $missingVersionState)
    Assert-Equal 'CriticalError' $missingVersionResult.Status 'A selected instance without an Android version was accepted.'
    Assert-Equal 'CLONE_UNVERIFIED' $missingVersionResult.Data.Code 'A selected instance without an Android version reported the wrong code.'
    Assert-True ($missingVersionResult.Message -match 'Report the instance with a known Android version') 'A selected instance without an Android version did not produce an actionable reason.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $missingVersionState -Pattern 'adb*').Count 'A selected instance without an Android version issued a guest request.'
    $blankVersionState = New-ConcealmentGuestState -Install $install
    $blankVersionState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
    $blankVersionState.Files[$blankVersionState.ConfigPath] = (New-ConcealmentConfigText)
    $blankVersionState.Instances = @($blankVersionState.Instances | ForEach-Object {
            if ([string]$_.Index -ceq '5') { [pscustomobject]@{ Index = $_.Index; Name = $_.Name; IsMain = $_.IsMain; Android = '   ' } }
            else { $_ }
        })
    $blankVersionJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $blankVersionResult = Set-AppConcealment -Instance $instance -VerifiedClone $clone -Packages @($script:ConcealmentSelectedPackage) -Journal $blankVersionJournal -Runner (New-ConcealmentManagerRunner -State $blankVersionState)
    Assert-Equal 'CriticalError' $blankVersionResult.Status 'A clone that reports a blank Android version was accepted.'
    Assert-Equal 'CLONE_UNVERIFIED' $blankVersionResult.Data.Code 'A clone that reports a blank Android version reported the wrong code.'
    Assert-True ($blankVersionResult.Message -match 'clone at index 5 reports no Android version') 'A clone that reports a blank Android version did not name the missing clone version.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $blankVersionState -Pattern 'adb*').Count 'A clone that reports a blank Android version issued a guest request.'

    $foreignManagerInstance = New-ConcealmentInstanceFixture -Install $install
    $foreignManagerInstance.Install.ManagerPath = $foreignCloneInstall.ManagerPath
    $foreignManagerState = New-ConcealmentGuestState -Install $install
    $foreignManagerResult = Set-AppConcealment -Instance $foreignManagerInstance -VerifiedClone $clone -Packages @($script:ConcealmentSelectedPackage) -Journal (New-ConcealmentJournal -Root $journalRoot -Instance $instance) -Runner (New-ConcealmentManagerRunner -State $foreignManagerState)
    Assert-Equal 'CriticalError' $foreignManagerResult.Status 'Selected app concealment accepted a manager outside its own install root.'
    Assert-Equal 'MANAGER_UNAVAILABLE' $foreignManagerResult.Data.Code 'A manager outside its own install root reported the wrong code.'
    Assert-Equal 0 @($foreignManagerState.Calls).Count 'Selected app concealment reached a manager outside its own install root.'

    $noJournalState = New-ConcealmentGuestState -Install $install
    $noJournalResult = Install-ConcealmentDependencies -Instance $instance -VerifiedClone $clone -Manifest $assets.Manifest -Journal $null -CacheRoot $assetCacheRoot -Runner (New-ConcealmentManagerRunner -State $noJournalState)
    Assert-Equal 'CriticalError' $noJournalResult.Status 'Concealment dependency installation accepted a missing journal.'
    Assert-Equal 'JOURNAL_INVALID' $noJournalResult.Data.Code 'A missing journal reported the wrong code.'
    Assert-Equal 0 @($noJournalState.Calls).Count 'A missing journal still changed the instance.'
    $nullInstanceState = New-ConcealmentGuestState -Install $install
    $nullInstanceResult = Install-ConcealmentDependencies -Instance $null -VerifiedClone $clone -Manifest $assets.Manifest -Journal (New-ConcealmentJournal -Root $journalRoot -Instance $instance) -CacheRoot $assetCacheRoot -Runner (New-ConcealmentManagerRunner -State $nullInstanceState)
    Assert-Equal 'CriticalError' $nullInstanceResult.Status 'Concealment dependency installation accepted a missing instance.'
    Assert-Equal 'INSTANCE_INVALID' $nullInstanceResult.Data.Code 'A missing instance reported the wrong code.'
    Assert-Equal 0 @($nullInstanceState.Calls).Count 'A missing instance still reached the manager.'
    $noManifestState = New-ConcealmentGuestState -Install $install
    $noManifestResult = Install-ConcealmentDependencies -Instance $instance -VerifiedClone $clone -Manifest $null -Journal (New-ConcealmentJournal -Root $journalRoot -Instance $instance) -CacheRoot $assetCacheRoot -Runner (New-ConcealmentManagerRunner -State $noManifestState)
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
        $defectResult = Install-ConcealmentDependencies -Instance $instance -VerifiedClone $clone -Manifest $assets.Manifest -Journal $defectJournal -CacheRoot $assetCacheRoot -Runner (New-ConcealmentManagerRunner -State $defectState)
        Assert-ConcealmentFailure -Result $defectResult -Journal $defectJournal -Code $installDefect.Code -Message "A concealment dependency defect was accepted: $($installDefect.Label)."
        if ($installDefect.Knob -ceq 'InstallExitCode') {
            Assert-Equal 0 @(Get-ConcealmentCalls -State $defectState -Pattern '*push*').Count 'A failed HMA APK install still pushed the Vector module.'
        }
        if ($installDefect.Knob -eq 'MoveExitCode' -or $installDefect.Knob -eq 'ExtractExitCode') {
            Assert-Equal 0 @($defectState.Modules).Count "A failed Vector module install was recorded as present: $($installDefect.Label)."
        }
    }
    foreach ($layoutDefect in @(
            [pscustomobject]@{ Entries = @('zygisk_vector-inner'); Label = 'a nested module directory' },
            [pscustomobject]@{ Entries = @('Vector'); Label = 'a differently named module directory' },
            [pscustomobject]@{ Entries = @('vector'); Label = 'a legacy vector module directory' },
            [pscustomobject]@{ Entries = @('zygisk_vector.zip'); Label = 'a file instead of the module directory' }
        )) {
        $defectState = New-ConcealmentGuestState -Install $install
        $defectState.Packages = @($script:ConcealmentRootPackages[1], $script:ConcealmentSelectedPackage)
        $defectState.ExtractEntries = $layoutDefect.Entries
        $defectJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
        $defectResult = Install-ConcealmentDependencies -Instance $instance -VerifiedClone $clone -Manifest $assets.Manifest -Journal $defectJournal -CacheRoot $assetCacheRoot -Runner (New-ConcealmentManagerRunner -State $defectState)
        Assert-ConcealmentFailure -Result $defectResult -Journal $defectJournal -Code 'MODULE_LAYOUT_UNSUPPORTED' -Message "A wrong Vector archive layout was accepted: $($layoutDefect.Label)."
        Assert-Equal 0 @($defectState.Modules).Count "A wrong Vector archive layout was installed anyway: $($layoutDefect.Label)."
        Assert-Equal -1 (Get-ConcealmentCallIndex -Calls $defectState.Calls -Pattern '*mv *') "A wrong Vector archive layout still moved a directory: $($layoutDefect.Label)."
    }

    foreach ($assetNameDefect in @(
            [pscustomobject]@{ Name = 'Vector&payload.zip'; Code = 'ASSET_PATH_INVALID'; Label = 'a shell operator in the pinned asset name' },
            [pscustomobject]@{ Name = 'Vector;payload.zip'; Code = 'ASSET_PATH_INVALID'; Label = 'a command separator in the pinned asset name' }
        )) {
        $defectRoot = Join-Path $concealmentRoot ('unsafe asset name ' + ([Math]::Abs($assetNameDefect.Name.GetHashCode())))
        [void][IO.Directory]::CreateDirectory($defectRoot)
        $defectFixture = New-ConcealmentAssetFixture -CacheRoot $defectRoot -VectorAssetName $assetNameDefect.Name
        $defectState = New-ConcealmentGuestState -Install $install
        $defectState.Packages = @($script:ConcealmentRootPackages[1], $script:ConcealmentSelectedPackage)
        $defectJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
        $defectResult = Install-ConcealmentDependencies -Instance $instance -VerifiedClone $clone -Manifest $defectFixture.Manifest -Journal $defectJournal -CacheRoot $defectRoot -Runner (New-ConcealmentManagerRunner -State $defectState)
        Assert-ConcealmentFailure -Result $defectResult -Journal $defectJournal -Code $assetNameDefect.Code -Message "An unsafe pinned asset name was accepted: $($assetNameDefect.Label)."
        Assert-Equal 0 @(Get-ConcealmentCalls -State $defectState -Pattern '*push*').Count "An unsafe pinned asset name still staged the module: $($assetNameDefect.Label)."
        Assert-Equal 0 @(Get-ConcealmentCalls -State $defectState -Pattern '*install -r*').Count "An unsafe pinned asset name still installed the HMA APK: $($assetNameDefect.Label)."
    }
    $traversalManifest = [pscustomobject]@{
        dependencies = @(
            @($assets.Manifest.dependencies | Where-Object { [string]$_.id -ceq 'hma' })[0],
            [pscustomobject][ordered]@{
                id        = 'vector'
                version   = 'pinned'
                assetName = '..\evil.zip'
                url       = 'https://github.com/JingMatrix/Vector/releases/download/v2.2/Vector-v2.2-3080-Release.zip'
                size      = [long]28
                sha256    = '0000000000000000000000000000000000000000000000000000000000000000'
            }
        )
    }
    $traversalState = New-ConcealmentGuestState -Install $install
    $traversalState.Packages = @($script:ConcealmentRootPackages[1], $script:ConcealmentSelectedPackage)
    $traversalJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $traversalResult = Install-ConcealmentDependencies -Instance $instance -VerifiedClone $clone -Manifest $traversalManifest -Journal $traversalJournal -CacheRoot $assetCacheRoot -Runner (New-ConcealmentManagerRunner -State $traversalState)
    Assert-ConcealmentFailure -Result $traversalResult -Journal $traversalJournal -Code 'ASSET_VERIFICATION_FAILED' -Message 'A pinned asset name with a traversal was accepted.'
    Assert-Equal 0 @($traversalState.Calls).Count 'A pinned asset name with a traversal still changed the instance.'

    $configState = New-ConcealmentGuestState -Install $install
    $configState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentRootPackages[1], $script:ConcealmentRootPackages[2], $script:ConcealmentRootPackages[3], $script:ConcealmentSelectedPackage)
    $configState.Files[$configState.ConfigPath] = (New-ConcealmentConfigText)
    $configRunner = New-ConcealmentManagerRunner -State $configState
    $readConfig = Get-HmaConfig -Instance $instance -Runner $configRunner
    Assert-Equal 'Success' $readConfig.Status "The supported HMA configuration was refused. $($readConfig.Message)"
    Assert-Equal 93 $readConfig.Data.HmaConfigVersion 'The HMA configuration reader reported the wrong version.'
    Assert-Equal $configState.ConfigPath $readConfig.Data.ConfigPath 'The HMA configuration reader reported the wrong path.'
    $cloneTargetConfig = Get-HmaConfig -Instance $instance -TargetIndex $cloneIndex -Runner $configRunner
    Assert-Equal 'Success' $cloneTargetConfig.Status 'The HMA configuration reader refused an explicit target index.'
    Assert-Equal $cloneIndex $cloneTargetConfig.Data.InstanceIndex 'The HMA configuration reader reported the wrong target index.'
    $readSourceConfig = Get-HmaConfig -Instance $instance -Runner $configRunner
    Assert-Equal 3 $readSourceConfig.Data.InstanceIndex 'The HMA configuration reader did not default to the selected instance.'

    foreach ($schemaDefect in @(
            [pscustomobject]@{ Text = (New-ConcealmentConfigText -ConfigVersion 92); Code = 'HMA_SCHEMA_UNSUPPORTED'; Reason = 'version 92'; Label = 'an older configuration version' },
            [pscustomobject]@{ Text = (New-ConcealmentConfigText -ConfigVersion 94); Code = 'HMA_SCHEMA_UNSUPPORTED'; Reason = 'version 94'; Label = 'a newer configuration version' },
            [pscustomobject]@{ Text = (New-ConcealmentConfigText -OmitConfigVersion); Code = 'HMA_SCHEMA_UNSUPPORTED'; Reason = 'no usable configVersion'; Label = 'a configuration with no version' },
        [pscustomobject]@{ Text = ('{"configVersion":93,"templates":{},"settingsTemplates":{},"scope":[]}' + [Environment]::NewLine); Code = 'HMA_SCHEMA_UNSUPPORTED'; Reason = 'scope'; Label = 'a scope that is a list' },
        [pscustomobject]@{ Text = ('{"configVersion":93,"templates":{},"settingsTemplates":{},"scope":"Root"}' + [Environment]::NewLine); Code = 'HMA_SCHEMA_UNSUPPORTED'; Reason = 'scope'; Label = 'a scope that is a string' },
        [pscustomobject]@{ Text = ('{"configVersion":93,"templates":{},"settingsTemplates":{},"scope":{"com.example.app":1}}' + [Environment]::NewLine); Code = 'HMA_SCHEMA_UNSUPPORTED'; Reason = 'scope'; Label = 'a scope value that is not a template name' },
        [pscustomobject]@{ Text = ('{"configVersion":93,"templates":{},"settingsTemplates":{},"scope":{"com.example.app":""}}' + [Environment]::NewLine); Code = 'HMA_SCHEMA_UNSUPPORTED'; Reason = 'scope'; Label = 'a scope value that is empty' },
            [pscustomobject]@{ Text = ('{"configVersion":"93"}'); Code = 'HMA_SCHEMA_UNSUPPORTED'; Reason = 'no usable configVersion'; Label = 'a string configuration version' },
            [pscustomobject]@{ Text = ('{"configVersion":93,"templates":"Root"}'); Code = 'HMA_SCHEMA_UNSUPPORTED'; Reason = 'no usable template map'; Label = 'a configuration with an unusable template map' },
            [pscustomobject]@{ Text = ('[{"configVersion":93}]'); Code = 'HMA_SCHEMA_UNSUPPORTED'; Reason = 'not a supported document'; Label = 'an array configuration' },
            [pscustomobject]@{ Text = ('not json'); Code = 'HMA_SCHEMA_UNSUPPORTED'; Reason = 'not strict JSON'; Label = 'a malformed configuration' },
            [pscustomobject]@{ Text = ''; Code = 'HMA_CONFIG_UNREADABLE'; Reason = 'could not be read'; Label = 'an unreadable configuration' }
        )) {
        $defectState = New-ConcealmentGuestState -Install $install
        $defectState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
        if ($schemaDefect.Text) {
            $defectState.Files[$defectState.ConfigPath] = $schemaDefect.Text
        }
        $defectConfig = Get-HmaConfig -Instance $instance -Runner (New-ConcealmentManagerRunner -State $defectState)
        Assert-ConcealmentHandoff -Result $defectConfig -Journal $null -Code $schemaDefect.Code -ReasonPattern ([regex]::Escape($schemaDefect.Reason)) -Message "An unknown HMA schema was accepted: $($schemaDefect.Label)."
        Assert-Equal 0 @(Get-ConcealmentCalls -State $defectState -Pattern '*base64*').Count "An unknown HMA schema still wrote a file: $($schemaDefect.Label)."
        $defectTemplateJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
        $defectTemplate = New-ReusableRootTemplate -Instance $instance -Journal $defectTemplateJournal -Runner (New-ConcealmentManagerRunner -State $defectState)
        Assert-ConcealmentHandoff -Result $defectTemplate -Journal $defectTemplateJournal -Code $schemaDefect.Code -ReasonPattern ([regex]::Escape($schemaDefect.Reason)) -Message "An unknown HMA schema still produced a template: $($schemaDefect.Label)."
        $defectSetJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
        $defectSet = Set-AppConcealment -Instance $instance -VerifiedClone $clone -Packages @($script:ConcealmentSelectedPackage) -Journal $defectSetJournal -Runner (New-ConcealmentManagerRunner -State $defectState)
        Assert-ConcealmentHandoff -Result $defectSet -Journal $defectSetJournal -Code $schemaDefect.Code -ReasonPattern ([regex]::Escape($schemaDefect.Reason)) -Message "An unknown HMA schema still applied concealment: $($schemaDefect.Label)."
        if ($schemaDefect.Text) {
            Assert-Equal $schemaDefect.Text $defectState.Files[$defectState.ConfigPath] "An unknown HMA schema changed the configuration: $($schemaDefect.Label)."
        }
    }

    $nullConfig = Get-HmaConfig -Instance $null -Runner $runner
    Assert-Equal 'CriticalError' $nullConfig.Status 'A concealment read without an instance asked the operator to configure the UI.'
    Assert-Equal 'INSTANCE_INVALID' $nullConfig.Data.Code 'A concealment read without an instance reported the wrong code.'
    Assert-True ($nullConfig.Data -isnot [Collections.IDictionary] -or -not $nullConfig.Data.Contains('Steps')) 'An invalid instance was answered with a supported-UI handoff.'
    $noManagerConfig = Get-HmaConfig -Instance ([pscustomobject]@{ Index = $install.SourceIndex }) -Runner $runner
    Assert-Equal 'CriticalError' $noManagerConfig.Status 'A concealment read without a manager asked the operator to configure the UI.'
    Assert-Equal 'INSTANCE_INVALID' $noManagerConfig.Data.Code 'A concealment read without a manager install reported the wrong code.'
    $foreignManagerRead = Get-HmaConfig -Instance $foreignManagerInstance -Runner $runner
    Assert-Equal 'CriticalError' $foreignManagerRead.Status 'A concealment read with a foreign manager asked the operator to configure the UI.'
    Assert-Equal 'MANAGER_UNAVAILABLE' $foreignManagerRead.Data.Code 'A concealment read with a foreign manager reported the wrong code.'
    $failingState = New-ConcealmentGuestState -Install $install
    $failingState.Packages = @($script:ConcealmentSelectedPackage)
    $failingState.AdbFailPattern = '*cat*'
    $failingConfig = Get-HmaConfig -Instance $instance -Runner (New-ConcealmentManagerRunner -State $failingState)
    Assert-ConcealmentHandoff -Result $failingConfig -Journal $null -Code 'HMA_CONFIG_UNREADABLE' -ReasonPattern 'could not be read' -Message 'A failed HMA configuration read was accepted.'
    $absentState = New-ConcealmentGuestState -Install $install
    $absentState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
    $absentTemplateJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $absentTemplate = New-ReusableRootTemplate -Instance $instance -Journal $absentTemplateJournal -Runner (New-ConcealmentManagerRunner -State $absentState)
    Assert-ConcealmentHandoff -Result $absentTemplate -Journal $absentTemplateJournal -Code 'HMA_CONFIG_UNREADABLE' -ReasonPattern 'could not be read' -Message 'An unreadable HMA configuration still produced a template.'

    $templateState = New-ConcealmentGuestState -Install $install
    $templateState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentRootPackages[1], $script:ConcealmentRootPackages[2], $script:ConcealmentRootPackages[3], $script:ConcealmentSelectedPackage)
    $templateState.Files[$templateState.ConfigPath] = (New-ConcealmentConfigText -RootPackages @('com.example.legacy'))
    $templateJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $templateResult = New-ReusableRootTemplate -Instance $instance -TargetIndex $cloneIndex -Journal $templateJournal -Runner (New-ConcealmentManagerRunner -State $templateState)
    Assert-Equal 'Success' $templateResult.Status "The reusable Root template could not be verified. $($templateResult.Message)"
    Assert-Equal 'Root' $templateResult.Data.TemplateName 'The reusable Root template reported the wrong name.'
    Assert-Equal $false $templateResult.Data.IsWhitelist 'The reusable Root template is not a blacklist template.'
    Assert-Equal $cloneIndex $templateResult.Data.InstanceIndex 'The reusable Root template did not report the instance it inspected.'
    foreach ($requiredPackage in $script:ConcealmentRootPackages) {
        Assert-True (@($templateResult.Data.TemplatePackages) -ccontains $requiredPackage) "The reusable Root template omits the required package: $requiredPackage"
    }
    Assert-True (@($templateResult.Data.TemplatePackages) -ccontains 'com.example.legacy') 'The reusable Root template dropped an existing template entry.'
    Assert-True (@($templateResult.Data.TemplatePackages) -cnotcontains $script:ConcealmentSelectedPackage) 'The reusable Root template absorbed a selected app.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $templateState -Pattern '*base64*').Count 'Verifying the reusable Root template wrote the configuration.'
    Assert-ConcealmentCloneOnly -State $templateState -Message 'Verifying the reusable Root template acted outside the verified clone.'

    $partialState = New-ConcealmentGuestState -Install $install
    $partialState.Packages = @($script:ConcealmentRootPackages[3], $script:ConcealmentSelectedPackage)
    $partialState.Files[$partialState.ConfigPath] = (New-ConcealmentConfigText -RootPackages @())
    $partialTemplate = New-ReusableRootTemplate -Instance $instance -Journal (New-ConcealmentJournal -Root $journalRoot -Instance $instance) -Runner (New-ConcealmentManagerRunner -State $partialState)
    Assert-Equal @($script:ConcealmentRootPackages[3]) @($partialTemplate.Data.TemplatePackages) 'The reusable Root template added a root package that is not installed.'

    $whitelistState = New-ConcealmentGuestState -Install $install
    $whitelistState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
    $whitelistState.Files[$whitelistState.ConfigPath] = ('{"configVersion":93,"templates":{"Root":{"isWhitelist":true,"appList":[]}},"settingsTemplates":{},"scope":{}}')
    $whitelistJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $whitelistResult = Set-AppConcealment -Instance $instance -VerifiedClone $clone -Packages @($script:ConcealmentSelectedPackage) -Journal $whitelistJournal -Runner (New-ConcealmentManagerRunner -State $whitelistState)
    Assert-ConcealmentFailure -Result $whitelistResult -Journal $whitelistJournal -Code 'HMA_TEMPLATE_INVALID' -Message 'An existing HMA Root whitelist template was flipped to a blacklist.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $whitelistState -Pattern '*base64*').Count 'An existing HMA Root whitelist template still wrote the configuration.'

    $globalState = New-ConcealmentGuestState -Install $install
    $globalState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage, $script:ConcealmentSecondPackage)
    $globalState.Files[$globalState.ConfigPath] = (New-ConcealmentConfigText -Scope @{'*' = 'Root'})
    $globalJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $globalResult = Set-AppConcealment -Instance $instance -VerifiedClone $clone -Packages @($script:ConcealmentSelectedPackage) -Journal $globalJournal -Runner (New-ConcealmentManagerRunner -State $globalState)
    Assert-ConcealmentFailure -Result $globalResult -Journal $globalJournal -Code 'HMA_TEMPLATE_INVALID' -Message 'An existing global HMA template scope was rewritten.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $globalState -Pattern '*base64*').Count 'An existing global HMA template scope still wrote the configuration.'

    $deepState = New-ConcealmentGuestState -Install $install
    $deepState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
    $deepState.Files[$deepState.ConfigPath] = (New-ConcealmentConfigText -DeepLevels 20)
    $deepJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $deepConfigText = $deepState.Files[$deepState.ConfigPath]
    $deepResult = Set-AppConcealment -Instance $instance -VerifiedClone $clone -Packages @($script:ConcealmentSelectedPackage) -Journal $deepJournal -Runner (New-ConcealmentManagerRunner -State $deepState)
    Assert-ConcealmentFailure -Result $deepResult -Journal $deepJournal -Code 'HMA_WRITE_FAILED' -Message 'A configuration the serializer would truncate was written.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $deepState -Pattern '*base64*').Count 'A configuration the serializer would truncate still wrote a file.'
    Assert-Equal 0 @($deepState.Files.Keys | Where-Object { $_ -like '*.backup-*' }).Count 'A configuration the serializer would truncate created a backup.'
    Assert-Equal $deepConfigText $deepState.Files[$deepState.ConfigPath] 'A configuration the serializer would truncate changed the original configuration.'

    $applyState = New-ConcealmentGuestState -Install $install
    $applyState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentRootPackages[1], $script:ConcealmentRootPackages[2], $script:ConcealmentRootPackages[3], $script:ConcealmentSelectedPackage, $script:ConcealmentSecondPackage)
    $applyState.Files[$applyState.ConfigPath] = (New-ConcealmentConfigText -RootPackages @('com.example.legacy'))
    $applyState.Files[$script:ConcealmentKernelSUAllowlistPath] = $script:ConcealmentAllowlistBytes
    $applyJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $applyRunner = New-ConcealmentManagerRunner -State $applyState
    $applyResult = Set-AppConcealment -Instance $instance -VerifiedClone $clone -Packages @($script:ConcealmentSelectedPackage) -Journal $applyJournal -Runner $applyRunner
    Assert-True ($applyResult.Status -eq 'Success') "Selected app concealment failed. $($applyResult.Message)"
    Assert-Equal 'OK' $applyResult.Data.Code 'Selected app concealment reported an invalid code.'
    Assert-True (@($applyResult.Data.Packages) -ccontains $script:ConcealmentSelectedPackage) 'The selected app is missing from the result.'
    Assert-Equal 1 @($applyResult.Data.Packages).Count 'Selected app concealment reported an unexpected package count.'
    Assert-Equal $cloneIndex $applyResult.Data.CloneIndex 'Selected app concealment reported the wrong target instance.'
    Assert-Equal $clone.CloneName $applyResult.Data.CloneName 'Selected app concealment reported the wrong target clone.'
    Assert-Equal 'Completed' $applyJournal.State 'Selected app concealment did not complete its journal.'
    $reopenedApply = Get-OperationJournal -Path $applyJournal.JournalPath
    Assert-Equal 'Completed' $reopenedApply.State 'Selected app concealment did not persist its journal state.'
    Assert-True (@($reopenedApply.Result.Data.Packages) -ccontains $script:ConcealmentSelectedPackage) 'Selected app concealment did not persist its package scope.'
    Assert-Equal $cloneIndex $reopenedApply.Result.Data.CloneIndex 'Selected app concealment did not persist its target instance.'
    Assert-Equal 3 @(@($applyResult.Data.Handoff) | ForEach-Object { @($_).Count } | Measure-Object -Sum).Sum 'Selected app concealment did not record the KernelSU handoff for the selected app.'
    Assert-ConcealmentCloneOnly -State $applyState -Message 'Selected app concealment acted outside the verified clone.'
    $writtenConfig = $applyState.Files[$applyState.ConfigPath] | ConvertFrom-Json
    Assert-Equal 93 $writtenConfig.configVersion 'The written HMA configuration changed the supported version.'
    Assert-Equal $false $writtenConfig.templates.Root.isWhitelist 'The written HMA configuration turned the Root template into a whitelist.'
    Assert-True (@($writtenConfig.templates.Root.appList) -cnotcontains $script:ConcealmentSelectedPackage) 'The written HMA configuration leaked the selected app into the Root template.'
    Assert-True (@($writtenConfig.templates.Root.appList) -cnotcontains $script:ConcealmentSecondPackage) 'The written HMA configuration leaked an unselected app into the Root template.'
    Assert-Equal 'Root' $writtenConfig.scope.($script:ConcealmentSelectedPackage) 'The selected app was not assigned the Root template in the HMA scope map.'
    Assert-Equal 1 @($writtenConfig.scope.PSObject.Properties).Count 'The written HMA configuration assigned the template to another app.'
    Assert-Equal $null $writtenConfig.PSObject.Properties['apps'] 'The written HMA configuration created an unverified apps key.'
    Assert-True ($null -ne $writtenConfig.PSObject.Properties['settingsTemplates']) 'The written HMA configuration dropped the operator settingsTemplates field.'
    Assert-Equal -1 (Get-ConcealmentCallIndex -Calls $applyState.Calls -Pattern '*pm uninstall*') 'Selected app concealment uninstalled a package.'
    Assert-Equal -1 (Get-ConcealmentCallIndex -Calls $applyState.Calls -Pattern '*pm disable*') 'Selected app concealment disabled a package.'
    $backupPath = [string]$applyResult.Data.BackupPath
    $writeCalls = @(Get-ConcealmentCalls -State $applyState -Pattern '*base64*')
    Assert-Equal 2 $writeCalls.Count 'Selected app concealment did not write exactly the configuration backup and the configuration.'
    Assert-True ((@($writeCalls[0]) -join ' ') -like ('*' + $backupPath + '*')) 'Selected app concealment did not write the configuration backup first.'
    Assert-True ((@($writeCalls[1]) -join ' ') -like ('*' + $applyState.ConfigPath + '*')) 'Selected app concealment did not write the configuration after its backup.'
    Assert-True ($backupPath.StartsWith($applyState.ConfigPath, [StringComparison]::Ordinal)) 'The recorded configuration backup is not beside the configuration.'
    Assert-Equal (New-ConcealmentConfigText -RootPackages @('com.example.legacy')) $applyState.Files[$backupPath] 'The configuration backup does not hold the original configuration.'
    $backupWriteIndex = Get-ConcealmentCallIndex -Calls $applyState.Calls -Pattern ('*base64*' + $backupPath + '*')
    $backupReadIndex = Get-ConcealmentCallIndex -Calls $applyState.Calls -Pattern ('*cat ' + $backupPath + '*')
    Assert-True ($backupWriteIndex -ge 0) 'Selected app concealment did not write the configuration backup.'
    Assert-True ($backupReadIndex -gt $backupWriteIndex) 'Selected app concealment did not read the configuration backup back after writing it.'
    Assert-Equal $script:ConcealmentAllowlistBytes $applyState.Files[$script:ConcealmentKernelSUAllowlistPath] 'Selected app concealment changed the KernelSU allowlist bytes.'
    $applyCallText = (@($applyState.Calls) | ForEach-Object { @($_) -join ' ' }) -join ' '
    Assert-True ($applyCallText -notmatch [regex]::Escape($script:ConcealmentKernelSUAllowlistPath) + ' *(>|base64|mv|rm)') 'Selected app concealment issued a write against the KernelSU allowlist path.'
    Assert-True ($applyCallText -notmatch ('base64[^"]*' + [regex]::Escape($script:ConcealmentKernelSUAllowlistPath))) 'Selected app concealment wrote through the KernelSU allowlist path.'

    $restoreResult = Set-ConcealmentGuestText -ManagerPath $install.ManagerPath -InstanceIndex $cloneIndex -Path $applyState.ConfigPath -Text $applyState.Files[$backupPath] -Runner (New-ConcealmentManagerRunner -State $applyState)
    Assert-Equal 'Success' $restoreResult.Status "The HMA configuration backup could not be restored. $($restoreResult.Message)"
    Assert-Equal (New-ConcealmentConfigText -RootPackages @('com.example.legacy')) $applyState.Files[$applyState.ConfigPath] 'The restored HMA configuration differs from the original configuration.'

    foreach ($backupDefect in @(
            [pscustomobject]@{ Knob = 'CatCorruptPattern'; Value = '*.backup-*'; Label = 'a truncated backup read-back' },
            [pscustomobject]@{ Knob = 'CatFailPattern'; Value = '*.backup-*'; Label = 'a backup read-back that cannot be read' }
        )) {
        $defectState = New-ConcealmentGuestState -Install $install
        $defectState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
        $defectState.Files[$defectState.ConfigPath] = (New-ConcealmentConfigText -RootPackages @('com.example.legacy'))
        $defectState.($backupDefect.Knob) = $backupDefect.Value
        $defectJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
        $defectResult = Set-AppConcealment -Instance $instance -VerifiedClone $clone -Packages @($script:ConcealmentSelectedPackage) -Journal $defectJournal -Runner (New-ConcealmentManagerRunner -State $defectState)
        Assert-ConcealmentFailure -Result $defectResult -Journal $defectJournal -Code 'HMA_BACKUP_FAILED' -Message "An unverified configuration backup was accepted: $($backupDefect.Label)."
        Assert-Equal (New-ConcealmentConfigText -RootPackages @('com.example.legacy')) $defectState.Files[$defectState.ConfigPath] "An unverified configuration backup still changed the original configuration: $($backupDefect.Label)."
        Assert-Equal 1 @(Get-ConcealmentCalls -State $defectState -Pattern '*base64*').Count "An unverified configuration backup still wrote the configuration: $($backupDefect.Label)."
    }

    $lockedApplyState = New-ConcealmentGuestState -Install $install
    $lockedApplyState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
    $lockedApplyConfig = (New-ConcealmentConfigText -RootPackages @('com.example.legacy'))
    $lockedApplyState.Files[$lockedApplyState.ConfigPath] = $lockedApplyConfig
    $lockedApplyJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $lockedApplyState.JournalLockPath = $lockedApplyJournal.JournalPath
    $lockedApplyState.JournalLockPattern = '*base64*config.json.backup*'
    try {
        $lockedApplyResult = Set-AppConcealment -Instance $instance -VerifiedClone $clone -Packages @($script:ConcealmentSelectedPackage) -Journal $lockedApplyJournal -Runner (New-ConcealmentManagerRunner -State $lockedApplyState)
    }
    finally {
        Release-ConcealmentJournalLock -State $lockedApplyState
    }
    Assert-Equal 'CriticalError' $lockedApplyResult.Status 'A concealment write that could not be journaled was accepted.'
    Assert-Equal 'JOURNAL_WRITE_FAILED' $lockedApplyResult.Data.Code 'An unjournalable concealment write reported the wrong code.'
    Assert-True ($lockedApplyResult.Message -match '(?i)journal') 'An unjournalable concealment write did not mention the journal.'
    Assert-Equal 1 @(Get-ConcealmentCalls -State $lockedApplyState -Pattern '*base64*').Count 'An unjournalable concealment write continued to a later guest write.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $lockedApplyState -Pattern '*cat *backup*').Count 'An unjournalable concealment write still read the backup back.'
    Assert-Equal $lockedApplyConfig $lockedApplyState.Files[$lockedApplyState.ConfigPath] 'An unjournalable concealment write changed the original configuration.'
    Assert-Equal 'Running' $lockedApplyJournal.State 'An unjournalable concealment write changed the in-memory journal state.'
    $reopenedLockedApply = Get-OperationJournal -Path $lockedApplyJournal.JournalPath
    Assert-Equal 'Running' $reopenedLockedApply.State 'An unjournalable concealment write persisted a journal state it could not write.'

    $lockedDependencyState = New-ConcealmentGuestState -Install $install
    $lockedDependencyState.Packages = @($script:ConcealmentRootPackages[1], $script:ConcealmentSelectedPackage)
    $lockedDependencyJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $lockedDependencyState.JournalLockPath = $lockedDependencyJournal.JournalPath
    $lockedDependencyState.JournalLockPattern = ('info -v ' + [string]$cloneIndex)
    try {
        $lockedDependencyResult = Install-ConcealmentDependencies -Instance $instance -VerifiedClone $clone -Manifest $assets.Manifest -Journal $lockedDependencyJournal -CacheRoot $assetCacheRoot -Runner (New-ConcealmentManagerRunner -State $lockedDependencyState)
    }
    finally {
        Release-ConcealmentJournalLock -State $lockedDependencyState
    }
    Assert-Equal 'CriticalError' $lockedDependencyResult.Status 'A concealment dependency step that could not be journaled was accepted.'
    Assert-Equal 'JOURNAL_WRITE_FAILED' $lockedDependencyResult.Data.Code 'An unjournalable concealment dependency step reported the wrong code.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $lockedDependencyState -Pattern 'adb*').Count 'An unjournalable concealment dependency step still issued a guest request.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $lockedDependencyState -Pattern '*install -r*').Count 'An unjournalable concealment dependency step still installed the HMA APK.'
    Assert-Equal 'Running' $lockedDependencyJournal.State 'An unjournalable concealment dependency step changed the in-memory journal state.'
    Assert-Equal 'Running' (Get-OperationJournal -Path $lockedDependencyJournal.JournalPath).State 'An unjournalable concealment dependency step persisted a journal state it could not write.'

    $multiState = New-ConcealmentGuestState -Install $install
    $multiState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentRootPackages[3], $script:ConcealmentSelectedPackage, $script:ConcealmentSecondPackage)
    $multiState.Files[$multiState.ConfigPath] = (New-ConcealmentConfigText)
    $multiResult = Set-AppConcealment -Instance $instance -VerifiedClone $clone -Packages @($script:ConcealmentSelectedPackage, $script:ConcealmentSecondPackage, $script:ConcealmentSelectedPackage) -Journal (New-ConcealmentJournal -Root $journalRoot -Instance $instance) -Runner (New-ConcealmentManagerRunner -State $multiState)
    Assert-Equal 'Success' $multiResult.Status "Selected app concealment failed for two apps. $($multiResult.Message)"
    Assert-Equal 2 @($multiResult.Data.Packages).Count 'Duplicate selected packages were not collapsed.'
    $multiConfig = $multiState.Files[$multiState.ConfigPath] | ConvertFrom-Json
    Assert-Equal 2 @($multiConfig.scope.PSObject.Properties).Count 'Duplicate selected packages produced more than one assignment.'
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
        $defectResult = Set-AppConcealment -Instance $instance -VerifiedClone $clone -Packages $defect.Packages -Journal $defectJournal -Runner (New-ConcealmentManagerRunner -State $defectState)
        Assert-ConcealmentFailure -Result $defectResult -Journal $defectJournal -Code 'PACKAGE_NAME_INVALID' -Message "An invalid package name was accepted: $($defect.Label)."
        Assert-Equal 0 @(Get-ConcealmentCalls -State $defectState -Pattern '*base64*').Count "An invalid package name still wrote the configuration: $($defect.Label)."
    }

    foreach ($emptySelection in @(@(), $null)) {
        $defectState = New-ConcealmentGuestState -Install $install
        $defectState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
        $defectState.Files[$defectState.ConfigPath] = (New-ConcealmentConfigText)
        $defectJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
        $defectResult = Set-AppConcealment -Instance $instance -VerifiedClone $clone -Packages $emptySelection -Journal $defectJournal -Runner (New-ConcealmentManagerRunner -State $defectState)
        Assert-ConcealmentFailure -Result $defectResult -Journal $defectJournal -Code 'PACKAGES_REQUIRED' -Message 'An empty selected package list was accepted.'
        Assert-Equal 0 @(Get-ConcealmentCalls -State $defectState -Pattern '*base64*').Count 'An empty selected package list still wrote the configuration.'
    }

    $allState = New-ConcealmentGuestState -Install $install
    $allState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentRootPackages[3], $script:ConcealmentSelectedPackage)
    $allState.Files[$allState.ConfigPath] = (New-ConcealmentConfigText)
    $allJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $allResult = Set-AppConcealment -Instance $instance -VerifiedClone $clone -Packages @($script:ConcealmentRootPackages[0], $script:ConcealmentRootPackages[3], $script:ConcealmentSelectedPackage) -Journal $allJournal -Runner (New-ConcealmentManagerRunner -State $allState)
    Assert-ConcealmentFailure -Result $allResult -Journal $allJournal -Code 'ALL_APPS_REFUSED' -Message 'A selection of every installed app was accepted.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $allState -Pattern '*base64*').Count 'A selection of every installed app still wrote the configuration.'

    $uninstalledState = New-ConcealmentGuestState -Install $install
    $uninstalledState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage, $script:ConcealmentSecondPackage)
    $uninstalledState.Files[$uninstalledState.ConfigPath] = (New-ConcealmentConfigText)
    $uninstalledJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $uninstalledResult = Set-AppConcealment -Instance $instance -VerifiedClone $clone -Packages @($script:ConcealmentSelectedPackage, 'com.example.absent') -Journal $uninstalledJournal -Runner (New-ConcealmentManagerRunner -State $uninstalledState)
    Assert-ConcealmentFailure -Result $uninstalledResult -Journal $uninstalledJournal -Code 'PACKAGE_NOT_INSTALLED' -Message 'A package that is not installed was accepted.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $uninstalledState -Pattern '*base64*').Count 'A package that is not installed still wrote the configuration.'

    $unreadableState = New-ConcealmentGuestState -Install $install
    $unreadableState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
    $unreadableState.Files[$unreadableState.ConfigPath] = (New-ConcealmentConfigText)
    $unreadableState.AdbFailPattern = '*pm list packages*'
    $unreadableJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $unreadableResult = Set-AppConcealment -Instance $instance -VerifiedClone $clone -Packages @($script:ConcealmentSelectedPackage) -Journal $unreadableJournal -Runner (New-ConcealmentManagerRunner -State $unreadableState)
    Assert-ConcealmentFailure -Result $unreadableResult -Journal $unreadableJournal -Code 'PACKAGE_LIST_UNREADABLE' -Message 'An unreadable package list was accepted.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $unreadableState -Pattern '*base64*').Count 'An unreadable package list still wrote the configuration.'

    $writeFailureState = New-ConcealmentGuestState -Install $install
    $writeFailureState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
    $writeFailureState.Files[$writeFailureState.ConfigPath] = (New-ConcealmentConfigText -RootPackages @('com.example.legacy'))
    $writeFailureState.WriteFailPattern = $writeFailureState.ConfigPath
    $writeFailureJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $writeFailureResult = Set-AppConcealment -Instance $instance -VerifiedClone $clone -Packages @($script:ConcealmentSelectedPackage) -Journal $writeFailureJournal -Runner (New-ConcealmentManagerRunner -State $writeFailureState)
    Assert-ConcealmentFailure -Result $writeFailureResult -Journal $writeFailureJournal -Code 'GUEST_WRITE_FAILED' -Message 'A refused HMA configuration write was accepted.'
    Assert-Equal (New-ConcealmentConfigText -RootPackages @('com.example.legacy')) $writeFailureState.Files[$writeFailureState.ConfigPath] 'A refused HMA configuration write changed the configuration.'

    $guestWriteState = New-ConcealmentGuestState -Install $install
    $guestWriteState.WriteFailPattern = '*'
    $guestWriteJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $guestWriteResult = Set-ConcealmentGuestText -ManagerPath $install.ManagerPath -InstanceIndex $cloneIndex -Path $guestWriteState.ConfigPath -Text '{}' -Journal $guestWriteJournal -Runner (New-ConcealmentManagerRunner -State $guestWriteState)
    Assert-ConcealmentFailure -Result $guestWriteResult -Journal $guestWriteJournal -Code 'GUEST_WRITE_FAILED' -Message 'A refused guest file write was accepted.'
    $guestPathJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $guestPathResult = Set-ConcealmentGuestText -ManagerPath $install.ManagerPath -InstanceIndex $cloneIndex -Path 'not an absolute guest path' -Text '{}' -Journal $guestPathJournal -Runner (New-ConcealmentManagerRunner -State $guestWriteState)
    Assert-ConcealmentFailure -Result $guestPathResult -Journal $guestPathJournal -Code 'GUEST_WRITE_FAILED' -Message 'A guest file write accepted a path that is not absolute.'
    Assert-Equal 0 @($guestWriteState.Files.Keys).Count 'A refused guest file write stored a file.'

    $guestReadState = New-ConcealmentGuestState -Install $install
    foreach ($unsafeReadPath in @('   ', 'data/user/0/config.json', '/data/user/0/../0/config.json', '/data/user/0/config.json"; rm -rf /', ('/data/user/0/' + ('x' * 300)))) {
        $unsafeRead = Get-ConcealmentGuestFile -ManagerPath $install.ManagerPath -InstanceIndex $cloneIndex -Path $unsafeReadPath -Runner (New-ConcealmentManagerRunner -State $guestReadState)
        Assert-True ($null -eq $unsafeRead) "The guest read accepted an unsafe path: $unsafeReadPath"
    }
    Assert-Equal 0 @($guestReadState.Calls).Count 'A guest read issued a request for an unsafe path.'

    $verificationState = New-ConcealmentGuestState -Install $install
    $verificationState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentRootPackages[1], $script:ConcealmentRootPackages[2], $script:ConcealmentRootPackages[3], $script:ConcealmentSelectedPackage)
    $verificationState.Files[$verificationState.ConfigPath] = (New-ConcealmentConfigText -Scope @{$script:ConcealmentSelectedPackage = 'Root'})
    $verificationState.Files[$script:ConcealmentKernelSUAllowlistPath] = $script:ConcealmentAllowlistBytes
    $verificationResult = Test-Concealment -ManagerPath $install.ManagerPath -InstanceIndex $cloneIndex -Packages @($script:ConcealmentSelectedPackage) -Runner (New-ConcealmentManagerRunner -State $verificationState)
    Assert-Equal 'Success' $verificationResult.Status "Concealment verification failed. $($verificationResult.Message)"
    Assert-Equal 93 $verificationResult.Data.HmaConfigVersion 'Concealment verification reported the wrong HMA configuration version.'
    Assert-True (@($verificationResult.Data.InScope) -ccontains $script:ConcealmentSelectedPackage) 'Concealment verification did not report the selected app in HMA scope.'
    Assert-True (@($verificationResult.Data.TemplatePackages) -ccontains 'me.weishu.kernelsu') 'Concealment verification did not report the Root template contents.'
    Assert-Equal 0 @($verificationResult.Data.OutOfScope).Count 'Concealment verification reported an out-of-scope app for a fully applied scope.'
    Assert-Equal $true $verificationResult.Data.KernelSUInstalled 'Concealment verification did not report the KernelSU package.'
    Assert-Equal $true $verificationResult.Data.AllowlistPresent 'Concealment verification did not report the KernelSU allowlist file.'
    Assert-Equal $false $verificationResult.Data.ProfileStateObserved 'Concealment verification claimed to observe the KernelSU Superuser profile.'
    Assert-Equal 3 @(@($verificationResult.Data.Handoff) | ForEach-Object { @($_).Count } | Measure-Object -Sum).Sum 'Concealment verification did not report the KernelSU handoff steps.'
    Assert-True ($verificationResult.Message -match 'Umount modules') 'Concealment verification did not ask the operator to confirm Umount modules in the app.'
    Assert-Equal 0 @(Get-ConcealmentCalls -State $verificationState -Pattern '*base64*').Count 'Concealment verification wrote a file.'

    $kitsuneVerifyState = New-ConcealmentGuestState -Install $install
    $kitsuneVerifyState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentRootPackages[1], $script:ConcealmentSelectedPackage)
    $kitsuneVerifyState.Files[$kitsuneVerifyState.ConfigPath] = (New-ConcealmentConfigText -Scope @{$script:ConcealmentSelectedPackage = 'Root'})
    $kitsuneVerifyResult = Test-Concealment -ManagerPath $install.ManagerPath -InstanceIndex $cloneIndex -Packages @($script:ConcealmentSelectedPackage) -Runner (New-ConcealmentManagerRunner -State $kitsuneVerifyState)
    Assert-Equal 'Warning' $kitsuneVerifyResult.Status 'Concealment verification reported Success on an Android 12 Kitsune clone without KernelSU.'
    Assert-Equal 'KERNELSU_ABSENT' $kitsuneVerifyResult.Data.Code 'A Kitsune clone without KernelSU reported the wrong code.'
    Assert-Equal $false $kitsuneVerifyResult.Data.KernelSUInstalled 'A Kitsune clone without KernelSU reported the KernelSU package as installed.'
    Assert-Equal $false $kitsuneVerifyResult.Data.ProfileStateObserved 'A Kitsune clone without KernelSU claimed an observed KernelSU profile.'
    Assert-Equal $false $kitsuneVerifyResult.Data.AllowlistPresent 'A Kitsune clone without KernelSU reported a KernelSU allowlist.'
    Assert-True ($kitsuneVerifyResult.Message -match '(?i)no KernelSU profile state') "A Kitsune clone without KernelSU still claims a KernelSU profile state: $($kitsuneVerifyResult.Message)"
    Assert-True ($kitsuneVerifyResult.Message -match 'Umount modules') 'A Kitsune clone without KernelSU dropped the manual handoff.'

    $flatLayoutState = New-ConcealmentGuestState -Install $install
    $flatLayoutState.Packages = @($script:ConcealmentRootPackages[1], $script:ConcealmentSelectedPackage)
    $flatLayoutState.ExtractEntries = @('module.prop', 'service.sh', 'bin')
    $flatLayoutState.ModulePropText = 'id=zygisk_vector
name=Vector
'
    $flatLayoutJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
    $flatLayoutResult = Install-ConcealmentDependencies -Instance $instance -VerifiedClone $clone -Manifest $assets.Manifest -Journal $flatLayoutJournal -CacheRoot $assetCacheRoot -Runner (New-ConcealmentManagerRunner -State $flatLayoutState)
    Assert-Equal 'Success' $flatLayoutResult.Status "The pinned flat Vector module archive was refused. $($flatLayoutResult.Message)"
    Assert-Equal 1 @($flatLayoutState.Modules).Count 'The flat Vector module archive did not install exactly one module.'
    Assert-True (@($flatLayoutState.Modules) -ccontains 'zygisk_vector') 'The flat Vector module archive was not installed under the zygisk_vector module id.'
    Assert-Equal 1 @(Get-ConcealmentCalls -State $flatLayoutState -Pattern "*'mv /data/local/tmp/vector-extract-*'").Count 'The flat Vector module archive did not move the staging directory itself.'

    foreach ($flatLayoutDefect in @(
            [pscustomobject]@{ Entries = @('zygisk_vector', 'module.prop'); Prop = 'id=zygisk_vector'; Label = 'a layout that is both a module directory and a flat module' },
            [pscustomobject]@{ Entries = @('module.prop', 'service.sh'); Prop = 'id=other'; Label = 'a root module.prop for another module' },
            [pscustomobject]@{ Entries = @('module.prop', 'service.sh'); Prop = 'id=vector'; Label = 'a flat archive that declares the legacy vector module id' },
            [pscustomobject]@{ Entries = @('module.prop', 'readme.txt'); Prop = 'id=zygisk_vector'; Label = 'a flat archive with no module script' },
            [pscustomobject]@{ Entries = @('readme.txt', 'logo.png'); Prop = 'id=zygisk_vector'; Label = 'an archive that is not a module at all' }
        )) {
        $flatDefectState = New-ConcealmentGuestState -Install $install
        $flatDefectState.Packages = @($script:ConcealmentRootPackages[1], $script:ConcealmentSelectedPackage)
        $flatDefectState.ExtractEntries = $flatLayoutDefect.Entries
        $flatDefectState.ModulePropText = $flatLayoutDefect.Prop
        if ($flatLayoutDefect.Entries -ccontains 'module.prop') {
            $flatDefectState.ExtractExtraFiles = @('other/module.prop')
        }
        $flatDefectJournal = New-ConcealmentJournal -Root $journalRoot -Instance $instance
        $flatDefectResult = Install-ConcealmentDependencies -Instance $instance -VerifiedClone $clone -Manifest $assets.Manifest -Journal $flatDefectJournal -CacheRoot $assetCacheRoot -Runner (New-ConcealmentManagerRunner -State $flatDefectState)
        Assert-ConcealmentFailure -Result $flatDefectResult -Journal $flatDefectJournal -Code 'MODULE_LAYOUT_UNSUPPORTED' -Message "An unsupported Vector archive layout was accepted: $($flatLayoutDefect.Label)."
        Assert-Equal 0 @($flatDefectState.Modules).Count "An unsupported Vector archive layout was installed anyway: $($flatLayoutDefect.Label)."
        Assert-Equal -1 (Get-ConcealmentCallIndex -Calls $flatDefectState.Calls -Pattern '*mv *') "An unsupported Vector archive layout still moved a directory: $($flatLayoutDefect.Label)."
        Assert-Equal 0 @($flatDefectState.Files.Keys | Where-Object { [string]$_ -like '*vector-extract*' }).Count "A refused Vector archive left its staging directory behind: $($flatLayoutDefect.Label)."
    }

    $partialScopeState = New-ConcealmentGuestState -Install $install
    $partialScopeState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentRootPackages[3], $script:ConcealmentSelectedPackage, $script:ConcealmentSecondPackage)
    $partialScopeState.Files[$partialScopeState.ConfigPath] = (New-ConcealmentConfigText -Scope @{$script:ConcealmentSelectedPackage = 'Root'})
    $partialScopeResult = Test-Concealment -ManagerPath $install.ManagerPath -InstanceIndex $cloneIndex -Packages @($script:ConcealmentSelectedPackage, $script:ConcealmentSecondPackage) -Runner (New-ConcealmentManagerRunner -State $partialScopeState)
    Assert-Equal 'Warning' $partialScopeResult.Status 'Concealment verification reported Success for a partially applied scope.'
    Assert-Equal 'SCOPE_INCOMPLETE' $partialScopeResult.Data.Code 'A partially applied scope reported the wrong code.'
    Assert-Equal 1 @($partialScopeResult.Data.InScope).Count 'A partially applied scope reported the wrong in-scope count.'
    Assert-True (@($partialScopeResult.Data.OutOfScope) -ccontains $script:ConcealmentSecondPackage) 'A partially applied scope did not report the out-of-scope app.'

    $unscopedState = New-ConcealmentGuestState -Install $install
    $unscopedState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
    $unscopedState.Files[$unscopedState.ConfigPath] = (New-ConcealmentConfigText)
    $unscopedResult = Test-Concealment -ManagerPath $install.ManagerPath -InstanceIndex $cloneIndex -Packages @($script:ConcealmentSelectedPackage) -Runner (New-ConcealmentManagerRunner -State $unscopedState)
    Assert-Equal 'Warning' $unscopedResult.Status 'Concealment verification reported Success for an unapplied scope.'
    Assert-Equal 'SCOPE_INCOMPLETE' $unscopedResult.Data.Code 'An unapplied scope reported the wrong code.'
    Assert-Equal 0 @($unscopedResult.Data.InScope).Count 'An unapplied scope reported an in-scope app.'

    $uninstalledTemplateState = New-ConcealmentGuestState -Install $install
    $uninstalledTemplateState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentRootPackages[3], $script:ConcealmentSelectedPackage)
    $uninstalledTemplateState.Files[$uninstalledTemplateState.ConfigPath] = (New-ConcealmentConfigText -RootPackages @($script:ConcealmentRootPackages[0], $script:ConcealmentRootPackages[3]) -Scope @{$script:ConcealmentSelectedPackage = 'Root'})
    $uninstalledTemplateResult = Test-Concealment -ManagerPath $install.ManagerPath -InstanceIndex $cloneIndex -Packages @($script:ConcealmentSelectedPackage) -Runner (New-ConcealmentManagerRunner -State $uninstalledTemplateState)
    Assert-Equal 'Success' $uninstalledTemplateResult.Status 'Concealment verification refused an applied scope.'
    Assert-Equal 2 @($uninstalledTemplateResult.Data.TemplatePackages).Count 'Concealment verification reported a root package that is not installed.'
    Assert-True (@($uninstalledTemplateResult.Data.TemplatePackages) -cnotcontains 'com.coderstory.toolkit') 'Concealment verification reported an uninstalled root package in the template.'

    $whitelistVerifyState = New-ConcealmentGuestState -Install $install
    $whitelistVerifyState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
    $whitelistVerifyState.Files[$whitelistVerifyState.ConfigPath] = ('{"configVersion":93,"templates":{"Root":{"isWhitelist":true,"appList":["org.frknkrc44.hma_oss"]}},"settingsTemplates":{},"scope":{"jp.pokemon.pokemontcgp":"Root"}}')
    $whitelistVerifyResult = Test-Concealment -ManagerPath $install.ManagerPath -InstanceIndex $cloneIndex -Packages @($script:ConcealmentSelectedPackage) -Runner (New-ConcealmentManagerRunner -State $whitelistVerifyState)
    Assert-Equal 'Warning' $whitelistVerifyResult.Status 'Concealment verification reported Success for a stored whitelist Root template.'
    Assert-Equal 'TEMPLATE_NOT_BLACKLIST' $whitelistVerifyResult.Data.Code 'A stored whitelist Root template reported the wrong code.'
    Assert-Equal $true $whitelistVerifyResult.Data.IsWhitelist 'A stored whitelist Root template was not reported as a whitelist.'

    foreach ($templateDefect in @(
            [pscustomobject]@{ Text = ('{"configVersion":93,"settingsTemplates":{},"scope":{"jp.pokemon.pokemontcgp":"Root"}}'); Found = $false; Label = 'a configuration with no template map' },
            [pscustomobject]@{ Text = ('{"configVersion":93,"templates":{},"settingsTemplates":{},"scope":{"jp.pokemon.pokemontcgp":"Root"}}'); Found = $false; Label = 'a configuration with no Root template' },
            [pscustomobject]@{ Text = ('{"configVersion":93,"templates":{"Root":{"isWhitelist":false,"appList":[]}},"settingsTemplates":{},"scope":{"jp.pokemon.pokemontcgp":"Root"}}'); Found = $true; Label = 'a Root template with an empty app list' }
        )) {
        $defectState = New-ConcealmentGuestState -Install $install
        $defectState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
        $defectState.Files[$defectState.ConfigPath] = $templateDefect.Text
        $defectResult = Test-Concealment -ManagerPath $install.ManagerPath -InstanceIndex $cloneIndex -Packages @($script:ConcealmentSelectedPackage) -Runner (New-ConcealmentManagerRunner -State $defectState)
        Assert-Equal 'Warning' $defectResult.Status "Concealment verification reported Success without a usable Root template: $($templateDefect.Label)."
        Assert-Equal 'TEMPLATE_MISSING' $defectResult.Data.Code "A missing Root template reported the wrong code: $($templateDefect.Label)."
        Assert-Equal $templateDefect.Found $defectResult.Data.TemplateFound "Concealment verification misreported whether the Root template exists: $($templateDefect.Label)."
        Assert-Equal 0 @($defectResult.Data.TemplatePackages).Count "Concealment verification reported Root template contents that are not stored: $($templateDefect.Label)."
        Assert-True ($defectResult.Message -match 'Root template') "A missing Root template was not explained: $($templateDefect.Label)."
    }

    $unreadableVerifyState = New-ConcealmentGuestState -Install $install
    $unreadableVerifyState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentSelectedPackage)
    $unreadableVerifyState.Files[$unreadableVerifyState.ConfigPath] = (New-ConcealmentConfigText -Scope @{$script:ConcealmentSelectedPackage = 'Root'})
    $unreadableVerifyState.AdbFailPattern = '*pm list packages*'
    $unreadableVerifyResult = Test-Concealment -ManagerPath $install.ManagerPath -InstanceIndex $cloneIndex -Packages @($script:ConcealmentSelectedPackage) -Runner (New-ConcealmentManagerRunner -State $unreadableVerifyState)
    Assert-Equal 'CriticalError' $unreadableVerifyResult.Status 'Concealment verification claimed a Root template without observing the installed packages.'
    Assert-Equal 'PACKAGE_LIST_UNREADABLE' $unreadableVerifyResult.Data.Code 'An unreadable package list reported the wrong verification code.'

    $absentAllowlistState = New-ConcealmentGuestState -Install $install
    $absentAllowlistState.Packages = @($script:ConcealmentRootPackages[0], $script:ConcealmentRootPackages[3], $script:ConcealmentSelectedPackage)
    $absentAllowlistState.Files[$absentAllowlistState.ConfigPath] = (New-ConcealmentConfigText -Scope @{$script:ConcealmentSelectedPackage = 'Root'})
    $absentAllowlistResult = Test-Concealment -ManagerPath $install.ManagerPath -InstanceIndex $cloneIndex -Packages @($script:ConcealmentSelectedPackage) -Runner (New-ConcealmentManagerRunner -State $absentAllowlistState)
    Assert-Equal 'Success' $absentAllowlistResult.Status 'Concealment verification refused a missing KernelSU allowlist file.'
    Assert-Equal $false $absentAllowlistResult.Data.AllowlistPresent 'Concealment verification reported a missing KernelSU allowlist file as present.'
    Assert-Equal $true $absentAllowlistResult.Data.KernelSUInstalled 'Concealment verification reported an installed KernelSU package as absent.'

    foreach ($verificationDefect in @(
            [pscustomobject]@{ ManagerPath = '   '; Packages = @($script:ConcealmentSelectedPackage); Label = 'a blank manager path' },
            [pscustomobject]@{ ManagerPath = 'C:\MuMu\shell\MuMuManager.exe'; Packages = @(); Label = 'an empty package list' },
            [pscustomobject]@{ ManagerPath = 'C:\MuMu\shell\MuMuManager.exe'; Packages = @('*'); Label = 'a wildcard package' }
        )) {
        $defectResult = Test-Concealment -ManagerPath $verificationDefect.ManagerPath -InstanceIndex $cloneIndex -Packages $verificationDefect.Packages -Runner $runner
        Assert-Equal 'CriticalError' $defectResult.Status "Concealment verification accepted $($verificationDefect.Label)."
        Assert-True ($script:ConcealmentCodes -ccontains [string]$defectResult.Data.Code) "Concealment verification reported an undocumented code for $($verificationDefect.Label)."
    }
    $negativeIndexResult = Test-Concealment -ManagerPath $install.ManagerPath -InstanceIndex -1 -Packages @($script:ConcealmentSelectedPackage) -Runner $runner
    Assert-Equal 'CriticalError' $negativeIndexResult.Status 'Concealment verification accepted a negative instance index.'
}

$script:MenuActions = @('Detect', 'Verify', 'Target', 'Root12', 'Root15', 'Conceal', 'RemoveAds', 'Restore')
$script:MenuCampaignJson = '{"version":3,"campaigns":[{"id":"alpha","display":true,"order":1,"image":"a.png"},{"id":"beta","order":2}]}'
$script:MenuInfoJson12 = '[{"index":"0","name":"Base","is_main":true,"is_process_started":false,"android_version":"12.0"},{"index":"2","name":"Android 12","is_main":false,"is_process_started":true,"android_version":"12.0"}]'
$script:MenuInfoJson15 = '[{"index":"0","name":"Base","is_main":true,"is_process_started":false,"android_version":"15.0"},{"index":"3","name":"Android 15","is_main":false,"is_process_started":true,"android_version":"15.0"}]'
$script:MenuInfoJsonUnsupported = '[{"index":"0","name":"Base","is_main":true,"is_process_started":false,"android_version":"11.0"},{"index":"2","name":"Old","is_main":false,"is_process_started":true,"android_version":"11.0"}]'
$script:MenuFallbackRoots = @()

function New-MenuSnapshot {
    param([string]$Root)

    $snapshot = @{}
    if ([string]::IsNullOrWhiteSpace($Root) -or -not [IO.Directory]::Exists($Root)) {
        return $snapshot
    }
    foreach ($file in @([IO.Directory]::GetFiles($Root, '*', [IO.SearchOption]::AllDirectories))) {
        $snapshot[$file.ToUpperInvariant()] = [pscustomobject]@{
            Path = $file
            Hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
        }
    }
    return $snapshot
}

function Get-MenuSnapshotDelta {
    param(
        [object]$Before,
        [object]$After
    )

    $delta = @()
    foreach ($key in @($Before.Keys)) {
        if (-not $After.ContainsKey($key)) {
            $delta += $Before[$key].Path
        }
        elseif ($Before[$key].Hash -cne $After[$key].Hash) {
            $delta += $Before[$key].Path
        }
    }
    foreach ($key in @($After.Keys)) {
        if (-not $Before.ContainsKey($key)) {
            $delta += $After[$key].Path
        }
    }
    return @($delta)
}

function New-MenuInstallFixture {
    param(
        [string]$Name,
        [string]$Edition = 'Global',
        [string]$InfoJson = $script:MenuInfoJson12,
        [switch]$Campaign
    )

    $parentName = if ($Edition -ceq 'Chinese') { 'MuMuPlayer' } else { 'MuMu Global' }
    $root = Join-Path $testRoot (Join-Path 'menu fixtures' (Join-Path $parentName $Name))
    $vms = Join-Path $root 'vms'
    [void][IO.Directory]::CreateDirectory($vms)
    $manager = New-DiscoveryManagerFixture -InstallRoot $root -InfoJson $InfoJson -SettingJson '{"root_permission":"true"}'
    $campaignPath = ''
    if ($Campaign) {
        $relativePath = if ($Edition -eq 'Global') { 'shell\ad\campaign.json' } else { 'MuMuPlayer\ad\campaign.json' }
        $campaignPath = Join-Path $root $relativePath
        New-AdsCampaignFixture -Path $campaignPath -Json $script:MenuCampaignJson
    }
    return [pscustomobject]@{
        Install = [pscustomobject]@{
            Edition = $Edition
            InstallRoot = [IO.Path]::GetFullPath($root)
            VmsPath = [IO.Path]::GetFullPath($vms)
            ManagerPath = $manager
            Source = 'Fallback'
        }
        CampaignPath = $campaignPath
    }
}

function New-MenuGuestRunner {
    param(
        [hashtable]$Responses,
        [hashtable]$Log = $null
    )

    return {
        param($ActualFilePath, $ActualArgumentList)

        $command = (@($ActualArgumentList) -join ' ')
        if ($null -ne $Log) {
            $Log[$command] = $true
        }
        if (-not $command.StartsWith('adb')) {
            return Invoke-CheckedProcess -FilePath $ActualFilePath -ArgumentList $ActualArgumentList
        }
        foreach ($pattern in @($Responses.Keys)) {
            if ($command -like ('*' + $pattern + '*')) {
                return [pscustomobject]@{
                    ExitCode = [int]$Responses[$pattern][0]
                    Text = [string]$Responses[$pattern][1]
                }
            }
        }
        return [pscustomobject]@{ ExitCode = 1; Text = 'menu fixture: unsupported command' }
    }.GetNewClosure()
}

function Get-MenuGuestResponses {
    param(
        [switch]$NoKitsune,
        [switch]$NoRootShell,
        [switch]$NoVectorModule,
        [switch]$LegacyVectorModule,
        [switch]$NoPackageList,
        [switch]$Android15
    )

    $newline = [Environment]::NewLine
    $responses = @{
        'dumpsys package io.github.huskydg.magisk' = @(0, ('Package [io.github.huskydg.magisk] (a1b2c3):' + $newline + '    versionCode=31000 minSdk=28' + $newline + '    versionName=31.0-kitsune'))
        'dumpsys package me.weishu.kernelsu' = @(0, ('Package [me.weishu.kernelsu] (a1b2c3):' + $newline + '    versionCode=30205 minSdk=28' + $newline + '    versionName=3.2.5'))
        'pidof magiskd' = @(0, '1234')
        'su -c id' = @(0, 'uid=0(root) gid=0(root) groups=0(root)')
        'pm list packages' = @(0, ('package:me.weishu.kernelsu' + $newline + 'package:org.frknkrc44.hma_oss' + $newline + 'package:io.github.huskydg.magisk'))
        'ls /data/adb/modules/zygisk_vector' = @(0, 'zygisk_vector')
    }
    if ($Android15) {
        $responses['pm list packages'] = @(0, ('package:me.weishu.kernelsu' + $newline + 'package:org.frknkrc44.hma_oss'))
    }
    if ($NoKitsune) {
        $responses.Remove('dumpsys package io.github.huskydg.magisk')
    }
    if ($NoRootShell) {
        $responses['su -c id'] = @(0, 'uid=2000(shell) gid=2000(shell) groups=2000(shell)')
    }
    if ($NoVectorModule) {
        $responses.Remove('ls /data/adb/modules/zygisk_vector')
    }
    if ($LegacyVectorModule) {
        # A guest that still carries only the legacy module directory must not be read as the pinned module.
        $responses.Remove('ls /data/adb/modules/zygisk_vector')
        $responses['ls /data/adb/modules/vector'] = @(0, 'vector')
    }
    if ($NoPackageList) {
        $responses.Remove('pm list packages')
    }
    return $responses
}

function New-MenuReader {
    param([string[]]$Answers)

    $position = @{ Value = 0 }
    return {
        if ($position.Value -ge $Answers.Count) {
            return $null
        }
        $answer = $Answers[$position.Value]
        $position.Value++
        return $answer
    }.GetNewClosure()
}

function Get-MenuManagerCalls {
    param([object]$Fixture)

    $argumentsPath = Join-Path (Split-Path -Parent $Fixture.Install.ManagerPath) 'args.log'
    if (-not [IO.File]::Exists($argumentsPath)) {
        return @()
    }
    return @([IO.File]::ReadAllLines($argumentsPath))
}

function Invoke-MenuTests {
    foreach ($commandName in @('Get-ToolkitStateRoot', 'Write-ToolkitLogEntry', 'Get-ToolkitExitCode', 'Get-ToolkitReport', 'Get-ToolkitVerifiedClone', 'Get-ToolkitJournalRecords', 'Invoke-ToolkitAction', 'Invoke-MenuAction', 'Invoke-MenuLoop', 'Get-ToolkitActionCatalog')) {
        Assert-True ($null -ne (Get-Command $commandName -CommandType Function -ErrorAction SilentlyContinue)) "Menu command is unavailable: $commandName"
    }
    Assert-True (Test-Path -LiteralPath $controllerScriptPath -PathType Leaf) 'src/Invoke-MumuToolkit.ps1 does not exist.'
    Assert-True (Test-Path -LiteralPath $launcherPath -PathType Leaf) 'Run-MumuToolkit.bat does not exist.'

    $menuStateRoot = Join-Path $testRoot 'menu state'
    [void][IO.Directory]::CreateDirectory($menuStateRoot)
    $menuLogPath = Join-Path $menuStateRoot 'logs\menu.log'
    $menuJournalRoot = Join-Path $menuStateRoot 'journals'

    function Get-ToolkitDiscoverySources {
        return @{
            RegistryRoots = @('FixtureRegistry:\Menu')
            ProcessSnapshot = @()
            FallbackRoots = @($script:MenuFallbackRoots)
        }
    }
    function Get-ToolkitUninstallEntries {
        param([string]$Root)

        return @()
    }

    try {
        $stateRoot = Get-ToolkitStateRoot
        Assert-True ($stateRoot.StartsWith((Join-Path $env:LOCALAPPDATA 'mumu-root-hide-toolkit'), [StringComparison]::OrdinalIgnoreCase)) 'The state root is outside the per-user toolkit directory.'
        $blankAppData = $env:LOCALAPPDATA
        $env:LOCALAPPDATA = '   '
        Assert-Throws { Get-ToolkitStateRoot } 'A blank LOCALAPPDATA produced a state root.'
        $env:LOCALAPPDATA = $blankAppData

        foreach ($status in @('Success', 'AlreadyApplied', 'Warning')) {
            Assert-Equal 0 (Get-ToolkitExitCode (Get-ToolkitResult -Status $status -Message 'fixture')) "Exit code is invalid for $status."
        }
        Assert-Equal 2 (Get-ToolkitExitCode (Get-ToolkitResult -Status 'RecoverableError' -Message 'fixture')) 'A recoverable error did not map to exit code 2.'
        Assert-Equal 1 (Get-ToolkitExitCode (Get-ToolkitResult -Status 'CriticalError' -Message 'fixture')) 'A critical error did not map to exit code 1.'
        Assert-Equal 1 (Get-ToolkitExitCode $null) 'A missing result did not map to exit code 1.'
        Assert-Equal 1 (Get-ToolkitExitCode ([pscustomobject]@{ Status = 'Bogus'; Message = 'fixture' })) 'A noncanonical result did not map to exit code 1.'

        $menuLogPathResult = Write-ToolkitLogEntry -Level 'Error' -Message 'menu log fixture token=menu_log_secret' -LogPath $menuLogPath
        Assert-Equal $menuLogPath $menuLogPathResult 'The log entry returned the wrong path.'
        Assert-True (Test-Path -LiteralPath $menuLogPath -PathType Leaf) 'The log entry wrote no log file.'
        $menuLogText = [IO.File]::ReadAllText($menuLogPath)
        Assert-True ($menuLogText -match '\[REDACTED\]') 'The log entry did not redact a secret.'
        Assert-True ($menuLogText -notmatch 'menu_log_secret') 'The log entry persisted a raw secret.'
        Assert-True ($menuLogText -match '\[Error\]') 'The log entry did not record its level.'

        $catalog = @(Get-ToolkitActionCatalog)
        $catalogNames = @($catalog | ForEach-Object { [string]$_.Name })
        $expectedActions = @($script:MenuActions) + @('Q')
        Assert-Equal ($expectedActions -join ',') ($catalogNames -join ',') 'The menu catalog does not match the dispatchable actions and the quit action.'
        foreach ($required in $expectedActions) {
            Assert-True (@(@($catalog | Where-Object { [string]$_.Name -ceq $required } | ForEach-Object { [string]$_.Description }) | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -eq 0) "The menu catalog has no description for an action: $required"
        }

        $controllerSource = [IO.File]::ReadAllText($controllerScriptPath)
        Assert-True ($controllerSource -match 'while\s*\(\s*\$true\s*\)') 'The controller does not use a persistent while loop.'
        Assert-True ($controllerSource -notmatch "(?i)Code\s*=\s*'UNKNOWN'") 'The controller source reports an UNKNOWN failure code.'
        foreach ($forbidden in @(
                'Invoke-Expression',
                'ScriptBlock]::Create',
                'Add-Type',
                'Start-Process',
                'RunAs',
                'Set-ExecutionPolicy',
                'Invoke-WebRequest',
                'Invoke-RestMethod',
                'WebClient',
                'DownloadFile',
                'schtasks',
                'New-ItemProperty',
                'Set-ItemProperty',
                'Remove-ItemProperty',
                'New-NetFirewallRule',
                'Set-MpPreference',
                'bcdedit',
                'drivers\etc\hosts',
                'certutil',
                'bitsadmin'
            )) {
            Assert-True ($controllerSource -notmatch [regex]::Escape($forbidden)) "The controller source uses a forbidden construct: $forbidden"
        }

        $launcherSource = [IO.File]::ReadAllText($launcherPath)
        Assert-True ($launcherSource -match '@echo\s+off') 'The launcher does not suppress command echo.'
        Assert-True ($launcherSource -match 'setlocal') 'The launcher does not localize its environment.'
        Assert-True ($launcherSource -match '%~dp0') 'The launcher does not resolve its own directory.'
        Assert-True ($launcherSource -match 'powershell\.exe\s+-NoProfile\s+-ExecutionPolicy\s+RemoteSigned\s+-File\s+"%ROOT%src\\Invoke-MumuToolkit\.ps1"') 'The launcher does not invoke the controller with the required PowerShell options.'
        Assert-True ($launcherSource -match 'exit\s+/b\s+%CODE%') 'The launcher does not propagate the controller exit code.'
        Assert-Equal 1 ([regex]::Matches($launcherSource, '(?i)\bpause\b')).Count 'The launcher does not pause exactly once.'
        Assert-True ($launcherSource -match '(?i)if\s+not\s+"%CODE%"=="0"\s+if\s+"%~1"==""\s+pause') 'The launcher does not pause only after an interactive failure.'
        foreach ($forbidden in @(
                'runas',
                '-Verb',
                'Start-Process',
                'certutil',
                'bitsadmin',
                'mshta',
                'regsvr32',
                'schtasks',
                '-enc',
                '-EncodedCommand',
                'Set-ExecutionPolicy',
                'Invoke-WebRequest',
                'Invoke-RestMethod',
                'http://',
                'https://',
                'ftp://',
                'reg add',
                'reg delete',
                'net user',
                'net localgroup',
                'sc config',
                'wmic',
                'copy ',
                'move ',
                'del ',
                'rmdir',
                '>>',
                'Expand-Archive'
            )) {
            Assert-True ($launcherSource -notmatch [regex]::Escape($forbidden)) "The launcher uses a forbidden construct: $forbidden"
        }

        $reportInstall = New-MenuInstallFixture -Name 'report' -InfoJson $script:MenuInfoJson12 -Campaign
        $android15Install = New-MenuInstallFixture -Name 'android15' -InfoJson $script:MenuInfoJson15
        $unsupportedInstall = New-MenuInstallFixture -Name 'unsupported' -InfoJson $script:MenuInfoJsonUnsupported
        $concealInstall = New-MenuInstallFixture -Name 'conceal' -InfoJson $script:MenuInfoJson12
        $script:MenuFallbackRoots = @(
            $reportInstall.Install.InstallRoot
            $android15Install.Install.InstallRoot
            $unsupportedInstall.Install.InstallRoot
            $concealInstall.Install.InstallRoot
        )

        $reportJournalRoot = Join-Path $testRoot 'menu report journals'
        $reportJournal = New-OperationJournal -Root $reportJournalRoot -Operation 'Report' -Instance ([pscustomobject]@{ Index = 2 })
        $reportInstance = [pscustomobject]@{
            Index = 2
            Name = 'Android 12'
            AndroidVersion = '12.0'
            Running = $true
            Install = $reportInstall.Install
        }
        $reportManagerCallsBefore = @(Get-MenuManagerCalls -Fixture $reportInstall)
        $reportSnapshotBefore = New-MenuSnapshot -Root $reportInstall.Install.InstallRoot
        $reportStateBefore = New-MenuSnapshot -Root $menuStateRoot
        $reportGuestLog = @{}
        $report = Get-ToolkitReport -Install $reportInstall.Install -Instance $reportInstance -Journal $reportJournal -StateRoot $menuStateRoot -Runner (New-MenuGuestRunner -Responses (Get-MenuGuestResponses) -Log $reportGuestLog)
        $reportDelta = @(Get-MenuSnapshotDelta -Before $reportSnapshotBefore -After (New-MenuSnapshot -Root $reportInstall.Install.InstallRoot))
        $reportStateDelta = @(Get-MenuSnapshotDelta -Before $reportStateBefore -After (New-MenuSnapshot -Root $menuStateRoot))
        $reportMutation = @($reportDelta + $reportStateDelta | Where-Object { [IO.Path]::GetFileName($_) -ne 'args.log' })

        Assert-True ($report.Mutated -eq $false) 'The read-only report claims a mutation.'
        Assert-Equal 0 $reportMutation.Count "The read-only report changed files: $($reportMutation -join '|')"
        Assert-Equal 0 @($report.Failures).Count "The read-only report recorded failures: $(@($report.Failures) -join '|')"
        Assert-Equal 'Global' $report.Install.Edition 'The report did not report the installation edition.'
        Assert-Equal $reportInstall.Install.InstallRoot $report.Install.InstallRoot 'The report did not report the installation root.'
        Assert-Equal $reportInstall.Install.VmsPath $report.Install.VmsPath 'The report did not report the VMS path.'
        Assert-Equal $reportInstall.Install.ManagerPath $report.Install.ManagerPath 'The report did not report the manager path.'
        Assert-True ($report.ManagerVersion -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$report.ManagerVersion)) 'The report did not collect a manager version.'
        Assert-Equal 2 @($report.Instances).Count 'The report did not collect every instance.'
        Assert-Equal 2 $report.Instance.Index 'The report did not resolve the selected instance.'
        Assert-Equal '12.0' $report.Instance.AndroidVersion 'The report did not report the instance Android version.'
        Assert-Equal $true $report.Instance.Running 'The report did not report the running state.'
        Assert-Equal $true $report.Instance.RootSetting 'The report did not report the vendor root setting.'
        Assert-True (@('Enabled', 'Disabled', 'Unknown') -ccontains $report.Virtualization) "The report reported an invalid virtualization state: $($report.Virtualization)"
        Assert-Equal 'Verified' $report.Guest.Root 'The report did not report a verified root.'
        Assert-Equal '31.0-kitsune' $report.Guest.Kitsune 'The report did not report the Kitsune package version.'
        Assert-Equal 1 $report.Guest.DaemonCount 'The report did not report the root daemon count.'
        Assert-Equal $true $report.Guest.HmaInstalled 'The report did not report the HMA package state.'
        Assert-Equal $true $report.Guest.VectorModuleInstalled 'The report did not report the Vector module state.'
        Assert-Equal 'Running' $report.JournalState 'The report did not report the journal state.'
        Assert-True (@($report.Ads.CampaignFiles) -contains $reportInstall.CampaignPath) 'The report did not report the campaign file.'
        Assert-Equal 'Missing' $report.Ads.RestorePoint 'The report reported a restore point that does not exist.'
        Assert-Equal -1 $report.Backups.CloneIndex 'The report invented a verified clone record.'
        $reportManagerCalls = @(Get-MenuManagerCalls -Fixture $reportInstall)
        $reportManagerDelta = @($reportManagerCalls | Select-Object -Skip $reportManagerCallsBefore.Count)
        Assert-Equal ($reportManagerCallsBefore.Count + 2) $reportManagerCalls.Count 'The report issued an unexpected number of manager requests.'
        Assert-Equal (@('info|-v|all', 'setting|-v|2|-k|root_permission') -join '|') ($reportManagerDelta -join '|') "The report issued manager requests other than the two read-only ones: $($reportManagerDelta -join '|')"
        foreach ($call in $reportManagerDelta) {
            Assert-True ($call -notmatch '(?i)\|-val($|\|)|\|control\||\|clone\||\|delete\||\|uninstall\|') "The report issued a mutating manager request: $call"
        }
        $expectedGuestCommands = @(
            'adb -v 2 -c shell dumpsys package io.github.huskydg.magisk'
            'adb -v 2 -c shell pidof magiskd'
            'adb -v 2 -c shell su -c id'
            'adb -v 2 -c shell pm list packages'
            "adb -v 2 -c shell su -c 'ls /data/adb/modules/zygisk_vector'"
        )
        $actualGuestCommands = @(@($reportGuestLog.Keys) | Sort-Object)
        Assert-Equal (@($expectedGuestCommands | Sort-Object) -join '|') ($actualGuestCommands -join '|') "The report issued guest requests other than the expected read-only ones: $($actualGuestCommands -join '|')"
        foreach ($command in @($reportGuestLog.Keys)) {
            Assert-True ($command -notmatch '(?i)\bsu -c [''"].*(rm |chmod|chown|echo|mv |cp )|pm uninstall|pm install|pm clear|pm disable|monkey|-val|control ') "The report issued a mutating guest request: $command"
        }

        $unrootedReport = Get-ToolkitReport -Install $reportInstall.Install -Instance $reportInstance -Journal $null -StateRoot $menuStateRoot -Runner (New-MenuGuestRunner -Responses (Get-MenuGuestResponses -NoKitsune -NoRootShell -NoVectorModule -NoPackageList))
        Assert-Equal 'Unverified' $unrootedReport.Guest.Root 'The report did not report an unverified root.'
        Assert-Equal '' $unrootedReport.Guest.Kitsune 'The report invented a Kitsune package version.'
        Assert-Equal $false $unrootedReport.Guest.HmaInstalled 'The report invented an HMA package state.'
        Assert-Equal $false $unrootedReport.Guest.VectorModuleInstalled 'The report invented a Vector module state.'
        Assert-True (@($unrootedReport.Failures).Count -ge 1) 'The report did not record its unreadable guest sections.'
        Assert-Equal 'None' $unrootedReport.JournalState 'The report invented a journal state without a journal.'
        Assert-Equal 0 $unrootedReport.Mutated 'The unverified report claims a mutation.'

        # The installed Vector module id is zygisk_vector, so a guest that still carries only the legacy vector directory is not the pinned module.
        $legacyModuleReport = Get-ToolkitReport -Install $reportInstall.Install -Instance $reportInstance -Journal $null -StateRoot $menuStateRoot -Runner (New-MenuGuestRunner -Responses (Get-MenuGuestResponses -LegacyVectorModule))
        Assert-Equal $false $legacyModuleReport.Guest.VectorModuleInstalled 'A guest with only a legacy vector module directory was read as the pinned Vector module.'

        $unsupportedReport = Get-ToolkitReport -Install $unsupportedInstall.Install -Instance ([pscustomobject]@{ Index = 2; Install = $unsupportedInstall.Install }) -StateRoot $menuStateRoot -Runner (New-MenuGuestRunner -Responses (Get-MenuGuestResponses))
        Assert-Equal 'Unsupported' $unsupportedReport.Guest.Root 'The report probed an unsupported Android version.'
        Assert-True (@($unsupportedReport.Failures).Count -ge 1) 'The report did not record the unsupported Android version.'

        $android15Report = Get-ToolkitReport -Install $android15Install.Install -Instance ([pscustomobject]@{ Index = 3; AndroidVersion = '15.0'; Install = $android15Install.Install }) -StateRoot $menuStateRoot -Runner (New-MenuGuestRunner -Responses (Get-MenuGuestResponses -Android15))
        Assert-Equal 'Verified' $android15Report.Guest.Root 'The report did not verify the Android 15 root.'
        Assert-Equal '3.2.5' $android15Report.Guest.KernelSU 'The report did not report the KernelSU version.'
        Assert-Equal '' $android15Report.Guest.Kitsune 'The report invented a Kitsune package for an Android 15 instance.'
        Assert-True ($android15Report.Guest.RootPermission -eq $true) 'The report did not report the Android 15 vendor root setting.'

        $brokenReport = Get-ToolkitReport -Install ([pscustomobject]@{
                Edition = 'Global'
                InstallRoot = (Join-Path $testRoot 'menu fixtures\absent')
                VmsPath = ''
                ManagerPath = ''
                Source = 'Fallback'
            }) -Instance $null -StateRoot $menuStateRoot
        Assert-True (@($brokenReport.Failures).Count -ge 1) 'The report did not record an unreadable installation.'
        Assert-Equal 'Unknown' $brokenReport.ManagerVersion 'The report invented a manager version for an unreadable installation.'
        Assert-Equal 0 @($brokenReport.Instances).Count 'The report invented instances for an unreadable installation.'
        Assert-Equal $false $brokenReport.Mutated 'The unreadable report claims a mutation.'

        $completedJournal = New-OperationJournal -Root $menuJournalRoot -Operation 'Root12' -Instance $reportInstance
        Write-JournalEvent -Journal $completedJournal -Level 'Info' -Message 'clone verified' -Data $null
        $cloneRecord = [pscustomobject]@{
            Code         = 'OK'
            Step         = 'complete'
            SourceIndex  = 2
            CloneIndex   = 7
            CloneName    = 'Android 12 clone'
            RootVerified = $true
        }
        Complete-OperationJournal -Journal $completedJournal -Result (Get-ToolkitResult -Status 'Success' -Message 'Android 12 Kitsune root is verified.' -Data $cloneRecord)
        $verifiedClone = Get-ToolkitVerifiedClone -StateRoot $menuStateRoot -Install $reportInstall.Install -Index 2
        Assert-Equal 'Success' $verifiedClone.Status "The verified clone record was not recovered from the journal store. $($verifiedClone.Message)"
        Assert-Equal 7 $verifiedClone.Data.CloneIndex 'The recovered clone record has the wrong index.'
        Assert-Equal 'Android 12 clone' $verifiedClone.Data.CloneName 'The recovered clone record has the wrong name.'
        $wrongInstallClone = Get-ToolkitVerifiedClone -StateRoot $menuStateRoot -Install $android15Install.Install -Index 2
        Assert-Equal 'CriticalError' $wrongInstallClone.Status 'A clone record from another installation was accepted.'
        $wrongIndexClone = Get-ToolkitVerifiedClone -StateRoot $menuStateRoot -Install $reportInstall.Install -Index 9
        Assert-Equal 'CriticalError' $wrongIndexClone.Status 'A clone record for another instance was accepted.'
        $absentStoreClone = Get-ToolkitVerifiedClone -StateRoot (Join-Path $testRoot 'menu fixtures\absent state') -Install $reportInstall.Install -Index 2
        Assert-Equal 'CriticalError' $absentStoreClone.Status 'A missing journal store produced a clone record.'
        $journalRecords = @(Get-ToolkitJournalRecords -StateRoot $menuStateRoot)
        Assert-Equal 1 @($journalRecords | Where-Object { [string]$_.Operation -ceq 'Root12' }).Count 'The journal store did not report its records.'
        $cloneReport = Get-ToolkitReport -Install $reportInstall.Install -Instance $reportInstance -StateRoot $menuStateRoot -Runner (New-MenuGuestRunner -Responses (Get-MenuGuestResponses))
        Assert-Equal 7 $cloneReport.Backups.CloneIndex 'The report did not report the verified clone record.'
        Assert-Equal 'Android 12 clone' $cloneReport.Backups.CloneName 'The report reported the wrong verified clone name.'
        Assert-Equal 'Completed' $cloneReport.JournalState 'The report did not report the persisted journal state.'
        Assert-Equal 'Root12' $cloneReport.JournalOperation 'The report did not report the persisted journal operation.'

        $detectResult = Invoke-ToolkitAction -Action 'Detect' -InstallRoot $reportInstall.Install.InstallRoot -StateRoot $menuStateRoot
        Assert-Equal 'Success' $detectResult.Status "Detect action failed: $($detectResult.Message)"
        Assert-Equal $reportInstall.Install.InstallRoot $detectResult.Data.InstallRoot 'Detect reported the wrong installation root.'
        Assert-Equal 2 $detectResult.Data.InstanceCount 'Detect reported the wrong instance count.'
        Assert-Equal 2 $detectResult.Data.InstanceIndex 'Detect reported the wrong selected instance index.'
        Assert-Equal 0 @(Get-ToolkitJournalRecords -StateRoot $menuStateRoot | Where-Object { [string]$_.Operation -ceq 'Detect' }).Count 'Detect created a journal.'

        $secondInstall = New-MenuInstallFixture -Name 'ambiguous'
        $script:MenuFallbackRoots = @($reportInstall.Install.InstallRoot, $secondInstall.Install.InstallRoot)
        $ambiguousResult = Invoke-ToolkitAction -Action 'Detect' -StateRoot $menuStateRoot
        Assert-Equal 'CriticalError' $ambiguousResult.Status 'An ambiguous installation selection was accepted.'
        Assert-True ($ambiguousResult.Message -match '(?i)explicit|multiple|ambiguous') "An ambiguous installation selection did not explain itself: $($ambiguousResult.Message)"
        $ambiguousVerify = Invoke-ToolkitAction -Action 'Verify' -StateRoot $menuStateRoot
        Assert-Equal 'CriticalError' $ambiguousVerify.Status 'An ambiguous installation selection was accepted for a read-only report.'
        $promptedResult = Invoke-ToolkitAction -Action 'Detect' -StateRoot $menuStateRoot -Prompt ({ '1' }).GetNewClosure()
        Assert-Equal 'Success' $promptedResult.Status "A prompted installation selection failed: $($promptedResult.Message)"
        Assert-Equal $secondInstall.Install.InstallRoot $promptedResult.Data.InstallRoot 'A prompted installation selection chose the wrong installation.'
        $script:MenuFallbackRoots = @(
            $reportInstall.Install.InstallRoot
            $android15Install.Install.InstallRoot
            $unsupportedInstall.Install.InstallRoot
            $concealInstall.Install.InstallRoot
        )

        $unknownAction = Invoke-ToolkitAction -Action 'Bogus' -StateRoot $menuStateRoot
        Assert-Equal 'CriticalError' $unknownAction.Status 'An unknown action was accepted.'
        Assert-True ($unknownAction.Message -match '(?i)action') 'An unknown action did not report the action name.'
        $unknownMenuAction = Invoke-MenuAction -Action 'Bogus' -Runner { param($Action) Get-ToolkitResult -Status 'Success' -Message 'injected' } -StateRoot $menuStateRoot -LogPath $menuLogPath
        Assert-Equal 'CriticalError' $unknownMenuAction.Status 'An unknown action reached an injected runner.'
        $quitAction = Invoke-ToolkitAction -Action 'Q' -StateRoot $menuStateRoot
        Assert-Equal 'CriticalError' $quitAction.Status 'The quit action was dispatched as a toolkit action.'

        $successRunner = { param($Action) Get-ToolkitResult -Status 'Success' -Message "ran $Action" -Data @{ Value = 1 } }.GetNewClosure()
        $first = Invoke-MenuAction -Action 'Detect' -Runner $successRunner -StateRoot $menuStateRoot -LogPath $menuLogPath
        Assert-True ($first.Status -eq 'Success') 'Detect action failed.'
        Assert-Equal 'ran Detect' $first.Message 'The injected runner result was not returned.'
        Assert-True ($first.Data.Contains('Log') -eq $false) 'A successful action carried a log path.'
        $recoverableRunner = { param($Action) Get-ToolkitResult -Status 'RecoverableError' -Message 'injected recoverable failure' }.GetNewClosure()
        $error = Invoke-MenuAction -Action 'Root12' -Runner $recoverableRunner -StateRoot $menuStateRoot -LogPath $menuLogPath
        Assert-True ($error.Status -eq 'RecoverableError') 'Recoverable error was not returned to the menu.'
        Assert-True ([string]$error.Data.Log -eq $menuLogPath) 'A recoverable error did not carry a log path.'
        $throwingRunner = { param($Action) throw 'injected menu failure token=menu_runner_secret' }.GetNewClosure()
        $thrown = Invoke-MenuAction -Action 'Root12' -Runner $throwingRunner -StateRoot $menuStateRoot -LogPath $menuLogPath
        Assert-Equal 'CriticalError' $thrown.Status 'A thrown action failure was not converted.'
        Assert-True ($thrown.Message -notmatch 'menu_runner_secret') 'A converted failure leaked a raw secret.'
        Assert-True ($thrown.Message -match '\[REDACTED\]') 'A converted failure was not redacted.'
        Assert-True ([string]$thrown.Data.Log -eq $menuLogPath) 'A converted failure did not carry a log path.'
        $malformedRunner = { param($Action) 'not a toolkit result' }.GetNewClosure()
        $malformed = Invoke-MenuAction -Action 'Verify' -Runner $malformedRunner -StateRoot $menuStateRoot -LogPath $menuLogPath
        Assert-Equal 'CriticalError' $malformed.Status 'A malformed action result was returned to the menu.'
        $silentRunner = { param($Action) }.GetNewClosure()
        $silent = Invoke-MenuAction -Action 'Verify' -Runner $silentRunner -StateRoot $menuStateRoot -LogPath $menuLogPath
        Assert-Equal 'CriticalError' $silent.Status 'An action that returned no result was returned to the menu.'
        $menuLogAfterActions = [IO.File]::ReadAllText($menuLogPath)
        Assert-True ($menuLogAfterActions -match '\[REDACTED\]') 'The menu log did not record a redacted failure.'
        Assert-True ($menuLogAfterActions -notmatch 'menu_runner_secret') 'The menu log persisted a raw secret.'
        Assert-True ($menuLogAfterActions -match 'Root12') 'The menu log did not record the failed action.'

        $loopState = @{ Calls = @() ; Lines = @() }
        $loopCode = Invoke-MenuLoop -Reader (New-MenuReader -Answers @('Root12', 'Q')) -Writer ({ param($Line) $loopState.Lines += $Line }).GetNewClosure() -Runner ({ param($Action) $loopState.Calls += $Action; throw 'injected loop failure' }).GetNewClosure() -StateRoot $menuStateRoot -LogPath $menuLogPath
        Assert-Equal 1 $loopCode 'A critical error did not return a nonzero exit code.'
        Assert-Equal 1 $loopState.Calls.Count 'A critical error ran the next action.'
        Assert-True ((@($loopState.Lines) -join "`n") -match '\[CriticalError\]') 'A critical error was not displayed.'
        Assert-True ((@($loopState.Lines) -join "`n") -match 'Log:') 'A critical error was displayed without a log path.'
        Assert-True ((@($loopState.Lines) -join "`n") -match '(?i)recovery') 'A critical error was displayed without recovery guidance.'
        Assert-True ((@($loopState.Lines) -join "`n") -match '\[CriticalError\].*Root12|.*Root12') 'A critical error did not name the failed action.'

        $recoverableState = @{ Calls = @() }
        $recoverableLoopCode = Invoke-MenuLoop -Reader (New-MenuReader -Answers @('Verify', 'Q')) -Writer ({ param($Line) }).GetNewClosure() -Runner ({ param($Action) $recoverableState.Calls += $Action; Get-ToolkitResult -Status 'RecoverableError' -Message 'injected recoverable failure' }).GetNewClosure() -StateRoot $menuStateRoot -LogPath $menuLogPath
        Assert-Equal 2 $recoverableLoopCode 'A recoverable error did not return exit code 2.'
        Assert-Equal 1 $recoverableState.Calls.Count 'A recoverable error did not return to the menu.'
        $recoverableLogText = [IO.File]::ReadAllText($menuLogPath)
        Assert-True ($recoverableLogText -match '\[Warning\] Action Verify returned RecoverableError') 'A recoverable error was not logged on the Warning branch.'

        $quitState = @{ Calls = @() }
        $quitCode = Invoke-MenuLoop -Reader (New-MenuReader -Answers @('Q')) -Writer ({ param($Line) }).GetNewClosure() -Runner ({ param($Action) $quitState.Calls += $Action }).GetNewClosure() -StateRoot $menuStateRoot -LogPath $menuLogPath
        Assert-Equal 0 $quitCode 'Quitting did not return a zero exit code.'
        Assert-Equal 0 $quitState.Calls.Count 'Quitting ran an action.'

        $blankCode = Invoke-MenuLoop -Reader (New-MenuReader -Answers @('   ', 'Q')) -Writer ({ param($Line) }).GetNewClosure() -Runner ({ param($Action) }).GetNewClosure() -StateRoot $menuStateRoot -LogPath $menuLogPath
        Assert-Equal 0 $blankCode 'A blank menu answer did not return normally.'

        $eofCode = Invoke-MenuLoop -Reader (New-MenuReader -Answers @()) -Writer ({ param($Line) }).GetNewClosure() -Runner ({ param($Action) }).GetNewClosure() -StateRoot $menuStateRoot -LogPath $menuLogPath
        Assert-Equal 0 $eofCode 'An exhausted menu input did not return normally.'

        $readerState = @{ Lines = @() }
        $readerFailureCode = Invoke-MenuLoop -Reader ({ throw 'injected reader failure' }).GetNewClosure() -Writer ({ param($Line) $readerState.Lines += $Line }).GetNewClosure() -Runner ({ param($Action) }).GetNewClosure() -StateRoot $menuStateRoot -LogPath $menuLogPath
        Assert-Equal 1 $readerFailureCode 'A menu read failure did not return a nonzero exit code.'
        Assert-True ((@($readerState.Lines) -join "`n") -match '\[CriticalError\]') 'A menu read failure was not displayed as a critical error.'

        $verifyResult = Invoke-ToolkitAction -Action 'Verify' -InstallRoot $reportInstall.Install.InstallRoot -InstanceIndex 2 -StateRoot $menuStateRoot -Runner (New-MenuGuestRunner -Responses (Get-MenuGuestResponses))
        Assert-Equal 'Success' $verifyResult.Status "Verify action failed: $($verifyResult.Message)"
        Assert-Equal $false $verifyResult.Data.Report.Mutated 'The Verify action did not report a read-only report.'
        Assert-Equal 'Verified' $verifyResult.Data.Report.Guest.Root 'The Verify action did not report the guest root state.'
        Assert-Equal 0 @(Get-ToolkitJournalRecords -StateRoot $menuStateRoot | Where-Object { [string]$_.Operation -ceq 'Verify' }).Count 'The Verify action created a journal.'

        $verifyWarning = Invoke-ToolkitAction -Action 'Verify' -InstallRoot $reportInstall.Install.InstallRoot -InstanceIndex 2 -StateRoot $menuStateRoot -Runner (New-MenuGuestRunner -Responses (Get-MenuGuestResponses -NoKitsune -NoRootShell))
        Assert-Equal 'Warning' $verifyWarning.Status "A report with unreadable sections was not reported as a warning: $($verifyWarning.Message)"
        Assert-Equal 'Unverified' $verifyWarning.Data.Report.Guest.Root 'A warning report did not keep the guest root state.'
        Assert-True (@($verifyWarning.Data.Report.Failures).Count -ge 1) 'A warning report did not keep its failure list.'

        # The read-only report is computed for the operator, so it must reach standard output, not only the result object.
        $verifyWarningText = @(Format-ToolkitResult -Result $verifyWarning) -join "`n"
        Assert-True ($verifyWarningText -match '(?m)^\[Warning\] ') 'The rendered Verify result does not lead with its status and message.'
        foreach ($expectedLine in @(
                '  Install.Edition = Global',
                ('  Install.InstallRoot = ' + $reportInstall.Install.InstallRoot),
                ('  Install.VmsPath = ' + $reportInstall.Install.VmsPath),
                ('  Install.ManagerPath = ' + $reportInstall.Install.ManagerPath),
                '  Install.Source = Fallback',
                ('  ManagerVersion = ' + [string]$report.ManagerVersion),
                '  Instances:',
                '    Instance 0 | Base | Android 12.0 | Running False | RootSetting not-detected',
                '    Instance 2 | Android 12 | Android 12.0 | Running True | RootSetting True',
                '  Guest.Root = Unverified',
                '  Guest.Kitsune = none',
                '  Guest.HmaInstalled = True',
                '  Guest.VectorModuleInstalled = True',
                '  Ads.RestorePoint = Missing',
                ('  Backups.CloneIndex = ' + [string]$verifyWarning.Data.Report.Backups.CloneIndex),
                ('  Backups.CloneName = ' + [string]$verifyWarning.Data.Report.Backups.CloneName),
                ('  JournalState = ' + [string]$verifyWarning.Data.Report.JournalState),
                ('  JournalOperation = ' + [string]$verifyWarning.Data.Report.JournalOperation),
                '  Failures:',
                '    Failure 1 = '
            )) {
            Assert-True ($verifyWarningText.Contains($expectedLine)) "The rendered Verify report does not carry the documented line: $expectedLine"
        }
        foreach ($fieldLine in @('Virtualization', 'Guest.Code', 'Guest.DaemonCount', 'JournalId', 'Concealment.Target', 'Concealment.Status', 'Concealment.Code', 'Concealment.InScope', 'Concealment.KernelSUInstalled')) {
            Assert-True ($verifyWarningText -match ('(?m)^  ' + [regex]::Escape($fieldLine) + ' = \S')) "The rendered Verify report does not carry the reported field: $fieldLine"
        }

        # Every required field is rendered even when the report has no value for it, so no field is silently omitted.
        $syntheticReport = [pscustomobject]@{
            Install          = [pscustomobject]@{ Edition = 'Chinese'; InstallRoot = 'C:\MuMu\MuMuPlayer'; VmsPath = 'C:\MuMu\MuMuPlayer\vms'; ManagerPath = 'C:\MuMu\MuMuPlayer\shell\MuMuManager.exe'; Source = 'Registry' }
            ManagerVersion   = '6.8.0.0'
            Instances        = @([pscustomobject]@{ Index = 5; Name = 'Android 15'; AndroidVersion = '15.0'; Running = $false; RootSetting = $null; Eligible = $true })
            Instance         = $null
            Virtualization   = 'Disabled'
            Guest            = [pscustomobject]@{ Root = 'Unverified'; Code = 'ROOT_DENIED'; RootPermission = $null; Kitsune = ''; KernelSU = ''; DaemonCount = -1; HmaInstalled = $false; VectorModuleInstalled = $false; Failure = '' }
            Ads              = [pscustomobject]@{ CampaignFiles = @(); RestorePoint = 'Present' }
            Backups          = [pscustomobject]@{ CloneIndex = 6; CloneName = 'Clone of 5' }
            JournalState     = 'Completed'
            JournalOperation = 'Root15'
            JournalId        = 'fixture-journal'
            Failures         = @('the first failure', 'the second failure')
            Mutated          = $false
        }
        $syntheticResult = Get-ToolkitResult -Status 'Warning' -Message 'synthetic verify fixture' -Data ([pscustomobject]@{ Report = $syntheticReport })
        $syntheticText = @(Format-ToolkitResult -Result $syntheticResult) -join "`n"
        foreach ($expectedLine in @(
                '[Warning] synthetic verify fixture',
                '  Install.Edition = Chinese',
                '  Install.InstallRoot = C:\MuMu\MuMuPlayer',
                '  Install.VmsPath = C:\MuMu\MuMuPlayer\vms',
                '  Install.ManagerPath = C:\MuMu\MuMuPlayer\shell\MuMuManager.exe',
                '  Install.Source = Registry',
                '  ManagerVersion = 6.8.0.0',
                '  Instances:',
                '    Instance 5 | Android 15 | Android 15.0 | Running False | RootSetting not-detected',
                '  Virtualization = Disabled',
                '  Guest.Root = Unverified',
                '  Guest.Code = ROOT_DENIED',
                '  Guest.RootPermission = not-detected',
                '  Guest.Kitsune = none',
                '  Guest.KernelSU = none',
                '  Guest.DaemonCount = not-detected',
                '  Guest.HmaInstalled = False',
                '  Guest.VectorModuleInstalled = False',
                '  Ads.RestorePoint = Present',
                '  Backups.CloneIndex = 6',
                '  Backups.CloneName = Clone of 5',
                '  JournalState = Completed',
                '  JournalOperation = Root15',
                '  JournalId = fixture-journal',
                '  Failures:',
                '    Failure 1 = the first failure',
                '    Failure 2 = the second failure'
            )) {
            Assert-True ($syntheticText.Contains($expectedLine)) "The rendered Verify report does not carry the documented line: $expectedLine"
        }

        # A report with nothing to report still names every field instead of dropping the lines.
        $emptyReportText = @(Format-ToolkitResult -Result (Get-ToolkitResult -Status 'Warning' -Message 'empty report fixture' -Data ([pscustomobject]@{ Report = [pscustomobject]@{ Install = $null; Instances = @(); Guest = $null; Ads = $null; Backups = $null; JournalState = 'None'; JournalOperation = ''; JournalId = ''; Failures = @(); Mutated = $false } }))) -join "`n"
        foreach ($expectedLine in @('  Instances: none', '  Install.Edition = not-detected', '  Guest.Root = not-detected', '  Ads.RestorePoint = not-detected', '  Backups.CloneIndex = not-detected', '  JournalOperation = none', '  JournalId = none', '  Failures: none')) {
            Assert-True ($emptyReportText.Contains($expectedLine)) "An empty Verify report does not name the absent field: $expectedLine"
        }

        # A result that carries no report is rendered exactly as before, and an unexpected data shape never throws.
        $scalarResult = Get-ToolkitResult -Status 'Success' -Message 'scalar fixture' -Data (@{ Code = 'OK'; Index = 3 })
        $scalarRendered = @(Format-ToolkitResult -Result $scalarResult)
        Assert-Equal 3 $scalarRendered.Count 'A scalar result no longer renders exactly its status, message, and data lines.'
        Assert-Equal '[Success] scalar fixture' $scalarRendered[0] 'A scalar result changed its status line.'
        Assert-Equal '  Code = OK' $scalarRendered[1] 'A scalar result changed its first data line.'
        Assert-Equal '  Index = 3' $scalarRendered[2] 'A scalar result changed its second data line.'
        foreach ($unsafeResult in @(
                (Get-ToolkitResult -Status 'Warning' -Message 'no data' -Data $null),
                (Get-ToolkitResult -Status 'Warning' -Message 'text data' -Data 'not a report'),
                (Get-ToolkitResult -Status 'Warning' -Message 'text report' -Data (@{ Report = 'not a report' })),
                (Get-ToolkitResult -Status 'Warning' -Message 'absent report' -Data (@{ Report = $null }))
            )) {
            $unsafeRendered = @(Format-ToolkitResult -Result $unsafeResult)
            Assert-True ($unsafeRendered.Count -ge 1) 'A result with no read-only report rendered no status line.'
            Assert-Equal 0 @($unsafeRendered | Where-Object { $_ -match '(?i)^  (Guest|Install|Backups|Ads)\.|^  Instances|^  Failures' }).Count 'A result with no read-only report rendered report lines.'
        }

        # A menu or noninteractive run carries the report in a dictionary beside the log path, so both shapes must render it.
        $wrappedResult = Get-ToolkitResult -Status 'Warning' -Message 'wrapped verify fixture' -Data ([ordered]@{ Report = $syntheticReport; Log = 'C:\toolkit state\logs\mumu-root-hide-toolkit.log' })
        $wrappedText = @(Format-ToolkitResult -Result $wrappedResult) -join "`n"
        foreach ($expectedLine in @('  Guest.Root = Unverified', '  Guest.Kitsune = none', '  Ads.RestorePoint = Present', '  Backups.CloneName = Clone of 5', '  Failures:', '    Failure 1 = the first failure')) {
            Assert-True ($wrappedText.Contains($expectedLine)) "A dictionary-shaped Verify result did not carry the documented line: $expectedLine"
        }
        Assert-True ($wrappedText.Contains('  Log: C:\toolkit state\logs\mumu-root-hide-toolkit.log')) 'A dictionary-shaped Verify result lost its log line.'

        $root15Unconfirmed = Invoke-ToolkitAction -Action 'Root15' -InstallRoot $android15Install.Install.InstallRoot -InstanceIndex 3 -StateRoot $menuStateRoot
        Assert-Equal 'CriticalError' $root15Unconfirmed.Status "An unconfirmed Android 15 action returned $($root15Unconfirmed.Status)."
        Assert-True ($root15Unconfirmed.Message -match '(?i)confirm') 'An unconfirmed Android 15 action did not ask for an explicit confirmation.'
        Assert-Equal 0 @(Get-ToolkitJournalRecords -StateRoot $menuStateRoot | Where-Object { [string]$_.Operation -ceq 'Root15' }).Count 'An unconfirmed Android 15 action created a journal.'

        $concealWithoutClone = Invoke-ToolkitAction -Action 'Conceal' -InstallRoot $concealInstall.Install.InstallRoot -InstanceIndex 2 -Packages @('jp.pokemon.pokemontcgp') -StateRoot $menuStateRoot
        Assert-Equal 'CriticalError' $concealWithoutClone.Status 'Concealment was accepted without a verified clone record.'
        Assert-True ($concealWithoutClone.Message -match '(?i)clone|root') "Concealment without a clone record did not explain the missing record: $($concealWithoutClone.Message)"
        Assert-Equal 0 @(Get-ToolkitJournalRecords -StateRoot $menuStateRoot | Where-Object { [string]$_.Operation -ceq 'Conceal' }).Count 'Concealment without a clone record created a journal.'

        $concealNoPackages = Invoke-ToolkitAction -Action 'Conceal' -InstallRoot $concealInstall.Install.InstallRoot -InstanceIndex 2 -StateRoot $menuStateRoot
        Assert-Equal 'CriticalError' $concealNoPackages.Status 'Concealment was accepted without a package selection.'
        Assert-True ($concealNoPackages.Message -match '(?i)package') "Concealment without a package selection did not report the missing selection: $($concealNoPackages.Message)"
        Assert-Equal 0 @(Get-ToolkitJournalRecords -StateRoot $menuStateRoot | Where-Object { [string]$_.Operation -ceq 'Conceal' }).Count 'Concealment without a package selection created a journal.'

        $adsInstall = New-MenuInstallFixture -Name 'ads' -Campaign
        $adsOtherInstall = New-MenuInstallFixture -Name 'ads other' -Campaign
        $adsPlainInstall = New-MenuInstallFixture -Name 'ads plain'
        $adsStateRoot = Join-Path $testRoot 'menu ads state'
        $script:MenuFallbackRoots = @($adsInstall.Install.InstallRoot, $adsOtherInstall.Install.InstallRoot, $adsPlainInstall.Install.InstallRoot)
        $adsVictimPath = Join-Path $adsOtherInstall.Install.InstallRoot 'victim.txt'
        [IO.File]::WriteAllText($adsVictimPath, 'victim fixture')
        $adsOriginalCampaign = $script:MenuCampaignJson

        $removeResult = Invoke-ToolkitAction -Action 'RemoveAds' -InstallRoot $adsInstall.Install.InstallRoot -StateRoot $adsStateRoot
        Assert-Equal 'Success' $removeResult.Status "RemoveAds failed: $($removeResult.Message)"
        $suppressedCampaign = [IO.File]::ReadAllText($adsInstall.CampaignPath)
        Assert-Equal $false ($suppressedCampaign | ConvertFrom-Json).campaigns[0].display 'The first RemoveAds did not suppress the campaign file.'
        Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $adsStateRoot 'campaigns') -Recurse -Filter 'restore-point.json' -File).Count -eq 1) 'The first RemoveAds did not write exactly one restore point.'
        $secondRemove = Invoke-ToolkitAction -Action 'RemoveAds' -InstallRoot $adsInstall.Install.InstallRoot -StateRoot $adsStateRoot
        Assert-Equal 'Success' $secondRemove.Status "A repeated RemoveAds failed: $($secondRemove.Message)"
        $repeatedCampaign = [IO.File]::ReadAllText($adsInstall.CampaignPath)
        Assert-Equal $suppressedCampaign $repeatedCampaign 'A repeated RemoveAds did not leave the campaign file suppressed.'

        $wrongBoundary = Invoke-ToolkitAction -Action 'Restore' -InstallRoot $adsOtherInstall.Install.InstallRoot -StateRoot $adsStateRoot
        Assert-Equal 'CriticalError' $wrongBoundary.Status 'A campaign restore for an installation without its own restore point was accepted.'
        Assert-True ($wrongBoundary.Message -match '(?i)restore point|boundary') "A restore for an installation without its own restore point did not explain itself: $($wrongBoundary.Message)"
        Assert-Equal $repeatedCampaign ([IO.File]::ReadAllText($adsInstall.CampaignPath)) 'A refused cross-installation restore changed the campaign file.'
        Assert-Equal 'victim fixture' ([IO.File]::ReadAllText($adsVictimPath)) 'A refused cross-installation restore wrote a file outside the boundary.'

        $adsSnapshotBefore = New-MenuSnapshot -Root $adsInstall.Install.InstallRoot
        $unresolvedRestore = Invoke-ToolkitAction -Action 'Restore' -InstallRoot (Join-Path $testRoot 'menu fixtures\absent ads install') -StateRoot $adsStateRoot
        Assert-Equal 'CriticalError' $unresolvedRestore.Status 'A campaign restore without a resolvable boundary was accepted.'
        $missingInstallRemove = Invoke-ToolkitAction -Action 'RemoveAds' -InstallRoot '' -StateRoot $adsStateRoot
        Assert-Equal 'CriticalError' $missingInstallRemove.Status 'An advertisement suppression without a resolvable installation was accepted.'
        $unresolvedDelta = @(Get-MenuSnapshotDelta -Before $adsSnapshotBefore -After (New-MenuSnapshot -Root $adsInstall.Install.InstallRoot) | Where-Object { [IO.Path]::GetFileName($_) -ne 'args.log' })
        Assert-Equal 0 $unresolvedDelta.Count "A refused advertisement action changed files: $($unresolvedDelta -join '|')"

        $restoreResult = Invoke-ToolkitAction -Action 'Restore' -InstallRoot $adsInstall.Install.InstallRoot -StateRoot $adsStateRoot
        Assert-Equal 'Success' $restoreResult.Status "Restore failed: $($restoreResult.Message)"
        Assert-Equal $adsOriginalCampaign ([IO.File]::ReadAllText($adsInstall.CampaignPath)) 'The campaign restore did not restore the original campaign file.'
        Assert-Equal 'victim fixture' ([IO.File]::ReadAllText($adsVictimPath)) 'The campaign restore wrote a file outside the boundary.'
        $emptyStateRoot = Join-Path $testRoot 'menu ads empty state'
        $unpreparedRestore = Invoke-ToolkitAction -Action 'Restore' -InstallRoot $adsInstall.Install.InstallRoot -StateRoot $emptyStateRoot
        Assert-Equal 'CriticalError' $unpreparedRestore.Status 'A campaign restore without a restore point was accepted.'

        $plainStateRoot = Join-Path $testRoot 'menu ads plain state'
        $plainResult = Invoke-ToolkitAction -Action 'RemoveAds' -InstallRoot $adsPlainInstall.Install.InstallRoot -StateRoot $plainStateRoot
        Assert-Equal 'AlreadyApplied' $plainResult.Status "An advertisement suppression without a campaign file was not reported: $($plainResult.Message)"
        $plainJournals = @(Get-ToolkitJournalRecords -StateRoot $plainStateRoot | Where-Object { [string]$_.Operation -ceq 'RemoveAds' })
        Assert-Equal 1 $plainJournals.Count 'The advertisement action did not keep exactly one operation journal.'
        Assert-Equal 'Completed' $plainJournals[0].State 'The advertisement action left its operation journal open.'
        Assert-Equal 'AlreadyApplied' $plainJournals[0].Result.Status 'The advertisement journal did not persist the result.'

        $scopeGlobal = New-MenuInstallFixture -Name 'scope global' -Edition 'Global' -Campaign
        $scopeChinese = New-MenuInstallFixture -Name 'scope chinese' -Edition 'Chinese' -Campaign
        $scopeStateRoot = Join-Path $testRoot 'menu ads scope state'
        $script:MenuFallbackRoots = @($scopeGlobal.Install.InstallRoot, $scopeChinese.Install.InstallRoot)
        $scopeOriginal = $script:MenuCampaignJson

        $scopeGlobalRemove = Invoke-ToolkitAction -Action 'RemoveAds' -InstallRoot $scopeGlobal.Install.InstallRoot -StateRoot $scopeStateRoot
        Assert-Equal 'Success' $scopeGlobalRemove.Status "The Global suppression failed: $($scopeGlobalRemove.Message)"
        $scopeGlobalReport = Get-ToolkitReport -Install $scopeGlobal.Install -Instance ([pscustomobject]@{ Index = 2 }) -StateRoot $scopeStateRoot -Runner (New-MenuGuestRunner -Responses (Get-MenuGuestResponses))
        Assert-Equal 'Present' $scopeGlobalReport.Ads.RestorePoint 'The report did not find the restore point of the suppressed installation.'
        $scopeChineseReport = Get-ToolkitReport -Install $scopeChinese.Install -Instance ([pscustomobject]@{ Index = 2 }) -StateRoot $scopeStateRoot -Runner (New-MenuGuestRunner -Responses (Get-MenuGuestResponses))
        Assert-Equal 'Missing' $scopeChineseReport.Ads.RestorePoint 'The report reported another edition restore point for the selected installation.'

        $scopeChineseRemove = Invoke-ToolkitAction -Action 'RemoveAds' -InstallRoot $scopeChinese.Install.InstallRoot -StateRoot $scopeStateRoot
        Assert-Equal 'Success' $scopeChineseRemove.Status "The Chinese suppression failed: $($scopeChineseRemove.Message)"
        Assert-Equal 2 @(Get-ChildItem -LiteralPath (Join-Path $scopeStateRoot 'campaigns') -Recurse -Filter 'restore-point.json' -File).Count 'The two editions did not keep one restore point each.'

        $scopeChineseRestore = Invoke-ToolkitAction -Action 'Restore' -InstallRoot $scopeChinese.Install.InstallRoot -StateRoot $scopeStateRoot
        Assert-Equal 'Success' $scopeChineseRestore.Status "The Chinese restore failed: $($scopeChineseRestore.Message)"
        Assert-Equal $scopeOriginal ([IO.File]::ReadAllText($scopeChinese.CampaignPath)) 'The Chinese restore did not restore the Chinese campaign file.'
        Assert-Equal $false (([IO.File]::ReadAllText($scopeGlobal.CampaignPath) | ConvertFrom-Json).campaigns[0].display) 'The Chinese restore restored another edition campaign file.'

        $scopeGlobalRestore = Invoke-ToolkitAction -Action 'Restore' -InstallRoot $scopeGlobal.Install.InstallRoot -StateRoot $scopeStateRoot
        Assert-Equal 'Success' $scopeGlobalRestore.Status "The Global restore failed: $($scopeGlobalRestore.Message)"
        Assert-Equal $scopeOriginal ([IO.File]::ReadAllText($scopeGlobal.CampaignPath)) 'The Global restore did not restore the Global campaign file.'
        Assert-Equal $scopeOriginal ([IO.File]::ReadAllText($scopeChinese.CampaignPath)) 'The Global restore changed the Chinese campaign file.'

        $scopeRepeat = Invoke-ToolkitAction -Action 'RemoveAds' -InstallRoot $scopeGlobal.Install.InstallRoot -StateRoot $scopeStateRoot
        Assert-Equal 'Success' $scopeRepeat.Status "A repeated suppression after a restore was not recoverable: $($scopeRepeat.Message)"
        Assert-Equal $false (([IO.File]::ReadAllText($scopeGlobal.CampaignPath) | ConvertFrom-Json).campaigns[0].display) 'A repeated suppression did not suppress the campaign file again.'
        $scopeRepeatRestore = Invoke-ToolkitAction -Action 'Restore' -InstallRoot $scopeGlobal.Install.InstallRoot -StateRoot $scopeStateRoot
        Assert-Equal 'Success' $scopeRepeatRestore.Status "A repeated restore was not recoverable: $($scopeRepeatRestore.Message)"
        Assert-Equal $scopeOriginal ([IO.File]::ReadAllText($scopeGlobal.CampaignPath)) 'A repeated restore did not restore the campaign file again.'
        Assert-Equal $scopeOriginal ([IO.File]::ReadAllText($scopeChinese.CampaignPath)) 'A repeated restore changed the other edition campaign file.'
        $scopeKeyRecord = Get-ToolkitCampaignScopeKey -Install $scopeGlobal.Install
        $scopeKeyDictionary = Get-ToolkitCampaignScopeKey -Install @{ InstallRoot = $scopeGlobal.Install.InstallRoot }
        Assert-True ($scopeKeyRecord -match '^[0-9a-f]{16}$') 'The campaign scope key is invalid for a discovered installation.'
        Assert-Equal $scopeKeyRecord $scopeKeyDictionary 'A dictionary shaped install produced a different campaign scope key and would strand its campaign roots.'
        Assert-Equal '' (Get-ToolkitCampaignScopeKey -Install $null) 'A missing install produced a campaign scope key.'
        $script:MenuFallbackRoots = @($adsInstall.Install.InstallRoot, $adsOtherInstall.Install.InstallRoot, $adsPlainInstall.Install.InstallRoot)

        $childStateRoot = Join-Path $testRoot 'menu child state'
        $childRun = Invoke-CheckedProcess -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @(
            '-NoProfile'
            '-ExecutionPolicy'
            'RemoteSigned'
            '-File'
            $controllerScriptPath
            '-Action'
            'Bogus'
            '-NonInteractive'
            '-StateRoot'
            $childStateRoot
        )
        Assert-Equal 1 $childRun.ExitCode "A noninteractive unknown action returned $($childRun.ExitCode)."
        Assert-True ($childRun.Text -match '(?i)action') "A noninteractive unknown action printed no result: $($childRun.Text)"
        $childStateFiles = @((New-MenuSnapshot -Root $childStateRoot).Keys)
        Assert-Equal 1 $childStateFiles.Count "A refused noninteractive action wrote state other than its log: $($childStateFiles -join '|')"
        Assert-True ($childStateFiles[0] -match '\.log$') "A refused noninteractive action wrote state other than its log: $($childStateFiles[0])"

        $flowState = @{ Calls = @(); Confirmed = $null; Packages = @(); CloneIndex = -1; Fetches = @() }
        function Install-Android12Root {
            param([object]$Instance, [object]$Manifest, [object]$Journal, [bool]$Interactive = $false, [string]$Confirmation = '', [string]$CacheRoot = '', [scriptblock]$Runner = $null, [scriptblock]$Prompt = $null, [object]$ResumeClone = $null, [switch]$RequireCachedAsset)
            $flowState.Calls += 'Root12'
            return (Get-ToolkitResult -Status 'Success' -Message 'shadowed Android 12 flow.')
        }
        function Enable-Android15Root {
            param([object]$Instance, [object]$Journal, [switch]$Confirmed, [scriptblock]$Runner = $null)
            $flowState.Calls += 'Root15'
            $flowState.Confirmed = [bool]$Confirmed
            return (Get-ToolkitResult -Status 'Success' -Message 'shadowed Android 15 flow.')
        }
        function Install-ConcealmentDependencies {
            param([object]$Instance, [object]$VerifiedClone, [object]$Manifest, [object]$Journal, [string]$CacheRoot = '', [scriptblock]$Runner = $null)
            $flowState.Calls += 'ConcealDependencies'
            $flowState.CloneIndex = [int]$VerifiedClone.CloneIndex
            return (Get-ToolkitResult -Status 'Success' -Message 'shadowed dependency install.' -Data ([pscustomobject]@{ Code = 'OK' }))
        }
        function Set-AppConcealment {
            param([object]$Instance, [object]$VerifiedClone, [string[]]$Packages, [object]$Journal, [scriptblock]$Runner = $null)
            $flowState.Calls += 'Conceal'
            $flowState.Packages = @($Packages)
            return (Get-ToolkitResult -Status 'Success' -Message 'shadowed concealment flow.' -Data ([pscustomobject]@{ Code = 'OK' }))
        }
        function Suppress-MuMuAds {
            param([string[]]$Paths, [string]$BackupRoot, [object]$Journal)
            $flowState.Calls += 'RemoveAds'
            return (Get-ToolkitResult -Status 'Success' -Message 'shadowed advertisement suppression.')
        }
        function Restore-MuMuAds {
            param([string]$BackupRoot, [string]$AllowedRoot, [object]$Journal)
            $flowState.Calls += 'Restore'
            return (Get-ToolkitResult -Status 'Success' -Message 'shadowed advertisement restore.')
        }

        $unknownDispatch = Invoke-ToolkitAction -Action 'Bogus' -StateRoot $menuStateRoot
        Assert-Equal 'CriticalError' $unknownDispatch.Status 'An unknown action was accepted by the dispatcher.'
        Assert-Equal 'ACTION_UNKNOWN' $unknownDispatch.Data.Code 'An unknown action did not report the unknown action code.'
        $quitDispatch = Invoke-ToolkitAction -Action 'Q' -StateRoot $menuStateRoot
        Assert-Equal 'CriticalError' $quitDispatch.Status 'The quit action was dispatched as a toolkit action.'
        Assert-Equal 0 $flowState.Calls.Count "A refused action called a mutating flow: $($flowState.Calls -join '|')"

        $script:ToolkitActions = @($script:ToolkitActions) + @('FutureAction')
        Assert-True ($script:ToolkitDispatchedActions -cnotcontains 'FutureAction') 'The dispatcher reports an implementation for an action that has none.'
        try {
            $futureDispatch = Invoke-ToolkitAction -Action 'FutureAction' -InstallRoot $reportInstall.Install.InstallRoot -StateRoot $menuStateRoot
            Assert-Equal 'CriticalError' $futureDispatch.Status 'A catalog action with no implementation was dispatched.'
            Assert-Equal 'ACTION_UNKNOWN' $futureDispatch.Data.Code 'A catalog action with no implementation did not report the unknown action code.'
            Assert-Equal 0 $flowState.Calls.Count "A catalog action with no implementation called a mutating flow: $($flowState.Calls -join '|')"
            $futureMenu = Invoke-MenuAction -Action 'FutureAction' -Runner ({ param($Action) Get-ToolkitResult -Status 'Success' -Message 'injected' }) -StateRoot $menuStateRoot -LogPath $menuLogPath
            Assert-Equal 'CriticalError' $futureMenu.Status 'A catalog action with no implementation reached the menu.'
        }
        finally {
            $script:ToolkitActions = @(@($script:ToolkitActions) | Where-Object { $_ -cne 'FutureAction' })
        }

        $controllerStateRoot = Join-Path $testRoot 'menu controller state'
        $script:MenuFallbackRoots = @($reportInstall.Install.InstallRoot, $android15Install.Install.InstallRoot)
        $toolbarState = @{ Lines = @() ; Calls = @() ; Questions = @() ; Answers = @('   ', 'Q') }
        $toolbarWriter = { param($Line) $toolbarState.Lines += [string]$Line }.GetNewClosure()
        $toolbarPrompt = {
            param($Question)
            $toolbarState.Questions += [string]$Question
            if ($toolbarState.Answers.Count -eq 0) { return '' }
            return $toolbarState.Answers[0]
        }.GetNewClosure()
        $toolbarRunner = { param($Choice) $toolbarState.Calls += $Choice }.GetNewClosure()
        $toolbarCode = Start-ToolkitController -StateRoot $controllerStateRoot -Reader (New-MenuReader -Answers @('   ', 'Q')) -Writer $toolbarWriter -Prompt $toolbarPrompt -ActionRunner $toolbarRunner
        Assert-Equal 0 $toolbarCode 'The menu did not exit normally after a blank answer and Q.'
        Assert-Equal 0 $toolbarState.Calls.Count 'A blank answer or Q ran an action.'
        Assert-True ((@($toolbarState.Lines) -join "`n") -match 'MuMu Root Hide Toolkit') 'The interactive toolbar was not printed.'
        foreach ($catalogName in @($catalogNames)) {
            Assert-True ((@($toolbarState.Lines) -join "`n") -match ('\b' + [regex]::Escape($catalogName) + '\b')) "The toolbar does not list an action: $catalogName"
        }
        $toolbarText = @($toolbarState.Lines) -join "`n"
        Assert-True ($toolbarText -match '(?i)verified clone') 'The toolbar does not state the verified clone requirement.'
        Assert-True ($toolbarText -match '(?i)RemoveAds and Restore') 'The toolbar does not name the advertisement actions.'
        Assert-True ($toolbarText -match '(?i)campaign files inside the selected installation') 'The toolbar does not scope the advertisement actions to the selected installation.'
        Assert-True ($toolbarText -match '(?i)keeps an exact backup') 'The toolbar does not state the advertisement backup boundary.'
        Assert-True ($toolbarText -match '(?i)Root12 and Root15 stop the selected instance when needed, create and verify a clone, and change only that clone') 'The toolbar does not describe what Root12 and Root15 do to the selected instance.'
        Assert-True ($toolbarText -match '(?i)Conceal changes only the verified clone') 'The toolbar does not describe what Conceal changes.'
        Assert-True ($toolbarText -match '(?i)asks for administrator rights once') 'The toolbar does not state that a denied action asks for rights once.'
        Assert-True ($toolbarText -match '(?i)Detect and Verify never ask') 'The toolbar does not state that the read-only actions never ask for rights.'
        Assert-True ($toolbarText -match '(?i)Target identifies the instance to work on, or creates or clones one\. Identify changes nothing; Create and Clone ask for CONFIRM first') 'The toolbar does not describe the target selection modes.'
        Assert-True ($toolbarText -notmatch '(?i)change only a verified clone of the selected instance') 'The toolbar hides that Root12 and Root15 also stop the selected instance.'

        $skipState = @{ Lines = @() }
        $skipCode = Start-ToolkitController -StateRoot $controllerStateRoot -SkipToolbar -Reader (New-MenuReader -Answers @('Q')) -Writer ({ param($Line) $skipState.Lines += [string]$Line }).GetNewClosure() -Prompt $toolbarPrompt -ActionRunner ({ param($Choice) }).GetNewClosure()
        Assert-Equal 0 $skipCode 'The menu did not exit normally with a skipped toolbar.'
        Assert-Equal 0 $skipState.Lines.Count 'A skipped toolbar printed output.'

        $loopControllerState = @{ Lines = @(); Calls = @() }
        $criticalControllerRunner = {
            param($Choice)
            $loopControllerState.Calls += $Choice
            throw 'injected controller failure token=controller_runner_secret'
        }.GetNewClosure()
        $criticalControllerCode = Start-ToolkitController -StateRoot $controllerStateRoot -SkipToolbar -Reader (New-MenuReader -Answers @('Root12', 'Q')) -Writer ({ param($Line) $loopControllerState.Lines += [string]$Line }).GetNewClosure() -Prompt $toolbarPrompt -ActionRunner $criticalControllerRunner
        Assert-Equal 1 $criticalControllerCode 'A critical error did not return a nonzero controller exit code.'
        Assert-Equal 1 $loopControllerState.Calls.Count 'A critical error ran the next action.'
        Assert-True ((@($loopControllerState.Lines) -join "`n") -notmatch 'controller_runner_secret') 'The controller printed a raw secret.'

        $recoverableControllerState = @{ Lines = @(); Calls = @() }
        $recoverableControllerCode = Start-ToolkitController -StateRoot $controllerStateRoot -SkipToolbar -Reader (New-MenuReader -Answers @('Verify', 'Q')) -Writer ({ param($Line) $recoverableControllerState.Lines += [string]$Line }).GetNewClosure() -Prompt $toolbarPrompt -ActionRunner ({
                param($Choice)
                $recoverableControllerState.Calls += $Choice
                return (Get-ToolkitResult -Status 'RecoverableError' -Message 'injected recoverable failure')
            }).GetNewClosure()
        Assert-Equal 2 $recoverableControllerCode 'A recoverable error did not return controller exit code 2.'
        Assert-Equal 1 $recoverableControllerState.Calls.Count 'A recoverable error did not return to the menu.'

        $confirmState = @{ Questions = @(); Answers = @('CONFIRM') }
        $confirmPrompt = {
            param($Question)
            $confirmState.Questions += [string]$Question
            if ($confirmState.Answers.Count -eq 0) { return '' }
            $answer = $confirmState.Answers[0]
            $confirmState.Answers = @(@($confirmState.Answers) | Select-Object -Skip 1)
            return $answer
        }.GetNewClosure()
        $root15Controller = Start-ToolkitController -StateRoot $controllerStateRoot -SkipToolbar -InstallRoot $android15Install.Install.InstallRoot -InstanceIndex 3 -Reader (New-MenuReader -Answers @('Root15', 'Q')) -Writer ({ param($Line) }).GetNewClosure() -Prompt $confirmPrompt
        Assert-Equal 0 $root15Controller 'The menu did not exit normally after the Android 15 action.'
        Assert-True ((@($confirmState.Questions) -join '|') -match 'CONFIRM') 'The interactive Android 15 action did not ask for an explicit confirmation.'
        Assert-Equal 1 @($flowState.Calls | Where-Object { $_ -ceq 'Root15' }).Count 'The interactive Android 15 action did not reach the flow exactly once.'
        Assert-Equal $true $flowState.Confirmed 'The interactive Android 15 action did not pass the explicit confirmation.'

        $refuseState = @{ Questions = @(); Answers = @('no') }
        $refusePrompt = {
            param($Question)
            $refuseState.Questions += [string]$Question
            if ($refuseState.Answers.Count -eq 0) { return '' }
            $answer = $refuseState.Answers[0]
            $refuseState.Answers = @(@($refuseState.Answers) | Select-Object -Skip 1)
            return $answer
        }.GetNewClosure()
        $flowState.Confirmed = $null
        $flowState.Calls = @()
        $root15Refused = Start-ToolkitController -StateRoot $controllerStateRoot -SkipToolbar -InstallRoot $android15Install.Install.InstallRoot -InstanceIndex 3 -Reader (New-MenuReader -Answers @('Root15', 'Q')) -Writer ({ param($Line) }).GetNewClosure() -Prompt $refusePrompt
        Assert-Equal 1 $root15Refused 'A refused Android 15 action did not keep its failure exit code through the menu.'
        Assert-True ((@($refuseState.Questions) -join '|') -match 'CONFIRM') 'The refused Android 15 action did not ask for a confirmation.'
        Assert-Equal $null $flowState.Confirmed 'A refused Android 15 action reached the flow.'
        Assert-Equal 0 @($flowState.Calls | Where-Object { $_ -ceq 'Root15' }).Count 'A refused Android 15 action reached the flow.'

        $targetMenuState = @{ Lines = @(); Questions = @(); Answers = @('Identify') }
        $targetMenuPrompt = {
            param($Question)
            $targetMenuState.Questions += [string]$Question
            if ($targetMenuState.Answers.Count -eq 0) {
                return ''
            }
            $answer = $targetMenuState.Answers[0]
            $targetMenuState.Answers = @(@($targetMenuState.Answers) | Select-Object -Skip 1)
            return $answer
        }.GetNewClosure()
        $targetMenuCode = Start-ToolkitController -StateRoot $controllerStateRoot -SkipToolbar -InstallRoot $reportInstall.Install.InstallRoot -Reader (New-MenuReader -Answers @('Target', 'Q')) -Writer ({ param($Line) $targetMenuState.Lines += [string]$Line }).GetNewClosure() -Prompt $targetMenuPrompt
        Assert-Equal 0 $targetMenuCode "The menu did not exit normally after the target action. $(@($targetMenuState.Lines) -join ' ')"
        Assert-True ((@($targetMenuState.Questions) -join '|') -match 'Identify, Create, or Clone') 'The menu did not ask the operator for a target mode.'
        Assert-True ((@($targetMenuState.Questions) -join '|') -notmatch 'CONFIRM') 'A menu Identify target run asked for a mutation confirmation.'
        Assert-True ((@($targetMenuState.Lines) -join "`n") -match '\[Success\]') "The menu did not report the selected target: $(@($targetMenuState.Lines) -join ' ')"
        Assert-True ((@($targetMenuState.Lines) -join "`n") -match 'index 2') "The menu did not report the selected target index: $(@($targetMenuState.Lines) -join ' ')"
        Assert-Equal 0 $flowState.Calls.Count "A menu target run started a root or concealment flow: $($flowState.Calls -join '|')"

        $targetParameterState = @{ Lines = @() }
        $targetParameterCode = Start-ToolkitController -StateRoot $controllerStateRoot -SkipToolbar -InstallRoot $reportInstall.Install.InstallRoot -Mode 'Create' -StartIndex '9' -Reader (New-MenuReader -Answers @('Detect', 'Q')) -Writer ({ param($Line) $targetParameterState.Lines += [string]$Line }).GetNewClosure() -Prompt $targetMenuPrompt
        Assert-Equal 0 $targetParameterCode "A menu run that carried target parameters refused another action. $(@($targetParameterState.Lines) -join ' ')"
        Assert-True ((@($targetParameterState.Lines) -join "`n") -notmatch 'TARGET_PARAMETER_MISUSE|Target action') "A target parameter leaked into another menu action: $(@($targetParameterState.Lines) -join ' ')"

        $packageState = @{ Questions = @(); Answers = @(' jp.pokemon.pokemontcgp , com.example.other ') }
        $packagePrompt = {
            param($Question)
            $packageState.Questions += [string]$Question
            if ($packageState.Answers.Count -eq 0) { return '' }
            $answer = $packageState.Answers[0]
            $packageState.Answers = @(@($packageState.Answers) | Select-Object -Skip 1)
            return $answer
        }.GetNewClosure()
        $flowState.Packages = @()
        $concealController = Start-ToolkitController -StateRoot $menuStateRoot -SkipToolbar -InstallRoot $reportInstall.Install.InstallRoot -InstanceIndex 2 -Reader (New-MenuReader -Answers @('Conceal', 'Q')) -Writer ({ param($Line) }).GetNewClosure() -Prompt $packagePrompt
        Assert-Equal 0 $concealController 'The menu did not exit normally after the concealment action.'
        Assert-True ((@($packageState.Questions) -join '|') -match '(?i)package') 'The interactive concealment action did not ask for the selected applications.'
        Assert-Equal (@('jp.pokemon.pokemontcgp', 'com.example.other') -join '|') ($flowState.Packages -join '|') 'The interactive concealment action did not pass the trimmed package selection.'

        # Conceal must install or verify its declared dependencies before the scope write, because the
        # HMA scope it writes is unreadable without the HMA package and the Vector module.
        $flowState.Calls = @()
        $flowState.CloneIndex = -1
        $flowState.Fetches = @()
        function Save-ToolkitManifestAsset {
            param([object]$Manifest, [string]$Id, [string]$CacheRoot = '', [scriptblock]$Fetch = $null, [switch]$RequireCached)
            $flowState.Fetches += $Id
            return (Get-ToolkitResult -Status 'Success' -Message 'shadowed asset acquisition.' -Data ([pscustomobject]@{ Code = 'OK'; Asset = 'C:\assets\fixture' }))
        }
        $concealOrdered = Invoke-ToolkitAction -Action 'Conceal' -InstallRoot $reportInstall.Install.InstallRoot -InstanceIndex 2 -Packages @('jp.pokemon.pokemontcgp') -StateRoot $menuStateRoot
        Assert-Equal 'Success' $concealOrdered.Status "The concealment dispatch failed. $($concealOrdered.Message)"
        Assert-Equal 'ConcealDependencies|Conceal' ($flowState.Calls -join '|') 'Concealment did not install its declared dependencies before the scope write.'
        Assert-Equal 7 $flowState.CloneIndex 'The concealment dependency step was not given the verified clone record.'
        Assert-Equal 0 $flowState.Fetches.Count 'A concealment run without the explicit opt-in reached the network for a dependency.'

        $flowState.Calls = @()
        $flowState.Fetches = @()
        $concealFetching = Invoke-ToolkitAction -Action 'Conceal' -InstallRoot $reportInstall.Install.InstallRoot -InstanceIndex 2 -Packages @('jp.pokemon.pokemontcgp') -StateRoot $menuStateRoot -FetchDependencies
        Assert-Equal 'Success' $concealFetching.Status "The fetching concealment dispatch failed. $($concealFetching.Message)"
        Assert-Equal 'ConcealDependencies|Conceal' ($flowState.Calls -join '|') 'The opt-in concealment run did not install its dependencies before the scope write.'
        Assert-Equal 'hma|vector' ($flowState.Fetches -join '|') 'The opt-in concealment run did not ask for both pinned dependencies first.'

        $flowState.Calls = @()
        $flowState.Fetches = @()
        $concealElevated = Invoke-ToolkitAction -Action 'Conceal' -InstallRoot $reportInstall.Install.InstallRoot -InstanceIndex 2 -Packages @('jp.pokemon.pokemontcgp') -StateRoot $menuStateRoot -FetchDependencies -ElevatedChild
        Assert-Equal 'Success' $concealElevated.Status "The elevated concealment dispatch failed. $($concealElevated.Message)"
        Assert-Equal 0 $flowState.Fetches.Count 'An elevated child reached the network for a dependency after rights were raised.'

        # A run with no verified clone record changes nothing at all, so no dependency is installed.
        $flowState.Calls = @()
        $concealWithoutCloneFlow = Invoke-ToolkitAction -Action 'Conceal' -InstallRoot $concealInstall.Install.InstallRoot -InstanceIndex 2 -Packages @('jp.pokemon.pokemontcgp') -StateRoot (Join-Path $testRoot 'menu conceal unverified state')
        Assert-Equal 'CriticalError' $concealWithoutCloneFlow.Status 'Concealment was accepted without a verified clone record.'
        Assert-Equal 0 $flowState.Calls.Count "Concealment without a verified clone record ran a mutating flow: $($flowState.Calls -join '|')"

        # The read-only report carries concealment evidence for the verified clone, and a clone whose
        # root is Kitsune rather than KernelSU stays an honest Warning instead of a claimed success.
        $evidenceConfigText = '{"configVersion":93,"templates":{"Root":{"isWhitelist":false,"appList":["org.frknkrc44.hma_oss","me.weishu.kernelsu"]}},"settingsTemplates":{},"scope":{"jp.pokemon.pokemontcgp":"Root"}}'
        $evidenceResponses = Get-MenuGuestResponses
        $evidenceResponses['config.json'] = @(0, $evidenceConfigText)
        $evidenceReport = Get-ToolkitReport -Install $reportInstall.Install -Instance $reportInstance -StateRoot $menuStateRoot -Runner (New-MenuGuestRunner -Responses $evidenceResponses)
        Assert-Equal 7 $evidenceReport.Concealment.Target 'The report did not report the verified clone as the concealment target.'
        Assert-Equal 'jp.pokemon.pokemontcgp' (@($evidenceReport.Concealment.Packages) -join '|') 'The report did not report the packages the blacklist Root template is assigned to.'
        Assert-Equal 1 @($evidenceReport.Concealment.InScope).Count 'The report did not report the concealment scope it observed.'
        Assert-Equal 'OK' $evidenceReport.Concealment.Code 'The report did not report concealment evidence for an applied scope.'
        Assert-Equal 'Success' $evidenceReport.Concealment.Status 'The report did not report a verified concealment scope.'
        Assert-Equal $true $evidenceReport.Concealment.TemplateFound 'The report did not report the stored Root template.'
        Assert-Equal $false $evidenceReport.Concealment.IsWhitelist 'The report reported the stored Root template as a whitelist.'
        Assert-Equal 93 $evidenceReport.Concealment.HmaConfigVersion 'The report did not report the observed HMA configuration version.'

        $kitsuneEvidenceResponses = Get-MenuGuestResponses
        # An Android 12 Kitsune clone carries the Kitsune packages and no KernelSU package at all.
        $kitsuneEvidenceResponses.Remove('dumpsys package me.weishu.kernelsu')
        $kitsuneEvidenceResponses['pm list packages'] = @(0, ('package:org.frknkrc44.hma_oss' + [Environment]::NewLine + 'package:io.github.huskydg.magisk' + [Environment]::NewLine + 'package:jp.pokemon.pokemontcgp'))
        $kitsuneEvidenceResponses['config.json'] = @(0, $evidenceConfigText)
        $kitsuneEvidenceReport = Get-ToolkitReport -Install $reportInstall.Install -Instance $reportInstance -StateRoot $menuStateRoot -Runner (New-MenuGuestRunner -Responses $kitsuneEvidenceResponses)
        Assert-Equal 'Warning' $kitsuneEvidenceReport.Concealment.Status 'The report reported concealment as verified on a Kitsune clone that has no KernelSU package.'
        Assert-Equal 'KERNELSU_ABSENT' $kitsuneEvidenceReport.Concealment.Code 'The report did not report the absent KernelSU package on a Kitsune clone.'
        Assert-Equal $false $kitsuneEvidenceReport.Concealment.KernelSUInstalled 'The report reported a KernelSU package on a Kitsune clone that has none.'
        Assert-Equal 1 @($kitsuneEvidenceReport.Concealment.InScope).Count 'The report did not observe the concealment scope on a Kitsune clone.'

        $noCloneEvidenceReport = Get-ToolkitReport -Install $concealInstall.Install -Instance ([pscustomobject]@{ Index = 2; Name = 'Android 12'; AndroidVersion = '12.0'; Install = $concealInstall.Install }) -StateRoot (Join-Path $testRoot 'menu no clone evidence state') -Runner (New-MenuGuestRunner -Responses $evidenceResponses)
        Assert-Equal 'CLONE_UNVERIFIED' $noCloneEvidenceReport.Concealment.Code 'The report collected concealment evidence without a verified clone record.'
        Assert-Equal '' $noCloneEvidenceReport.Concealment.Target 'The report named a concealment target without a verified clone record.'
        Assert-Equal 0 @($noCloneEvidenceReport.Concealment.Packages).Count 'The report reported concealment packages without a verified clone record.'
        # A guest whose HMA scope map assigns the template to no app has nothing to claim, so the
        # evidence is an explicit empty scope rather than a reported success.
        $unscopedEvidenceResponses = Get-MenuGuestResponses
        $unscopedEvidenceResponses['config.json'] = @(0, (New-ConcealmentConfigText))
        $unscopedEvidenceReport = Get-ToolkitReport -Install $reportInstall.Install -Instance $reportInstance -StateRoot $menuStateRoot -Runner (New-MenuGuestRunner -Responses $unscopedEvidenceResponses)
        Assert-Equal 'SCOPE_EMPTY' $unscopedEvidenceReport.Concealment.Code 'The report claimed an applied concealment scope on a guest that assigns the template to no app.'
        Assert-Equal 0 @($unscopedEvidenceReport.Concealment.InScope).Count 'The report reported an in-scope app for an unapplied concealment scope.'
        Assert-Equal 0 @($unscopedEvidenceReport.Concealment.Packages).Count 'The report reported concealment packages for an unapplied concealment scope.'

        $standaloneRoot = Join-Path $testRoot 'standalone verification'
        $standaloneShell = Join-Path $standaloneRoot 'shell'
        [void][IO.Directory]::CreateDirectory($standaloneShell)
        $standaloneManager = Join-Path $standaloneShell 'MuMuManager.exe'
        [IO.File]::WriteAllText($standaloneManager, 'standalone manager fixture')
        $standaloneScript = @'
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
. '__COMMON__'
. '__VERIFICATION__'
$install = [pscustomobject]@{
    Edition = 'Global'
    InstallRoot = '__ROOT__'
    VmsPath = '__VMS__'
    ManagerPath = '__MANAGER__'
    Source = 'Fallback'
}
$report = Get-ToolkitReport -Install $install -Instance $null -Journal $null -StateRoot '__STATE__'
if ($report.Mutated -ne $false) { throw 'The report claims a mutation.' }
if (@($report.Install.Edition) -cne 'Global') { throw 'The report lost the installation.' }
$guest = Get-ToolkitGuestState -ManagerPath '__MANAGER__' -InstanceIndex 2 -AndroidVersion '12.0'
if ([string]::IsNullOrWhiteSpace([string]$guest.Failure)) { throw 'The guest state reported no reason for being unread.' }
if ($guest.HmaInstalled -ne $false) { throw 'The guest state invented an HMA package state.' }
$restorePoints = @(Get-ToolkitCampaignRestorePoints -StateRoot '__STATE__' -Install $install)
if ($restorePoints.Count -ne 0) { throw 'An empty state root reported a restore point.' }
        $unassigned = Get-ToolkitSharedValue -Name 'ConcealmentHmaPackage' -Default 'absent'
if ($unassigned -cne 'absent') { throw 'An unloaded module constant did not fall back to the default.' }
if ([string]$script:ToolkitCampaignRestorePointFile -cne 'restore-point.json') { throw 'The campaign restore point file name is not available without the advertisement module.' }
$scopeKey = Get-ToolkitCampaignScopeKey -Install $install
if ($scopeKey -notmatch '^[0-9a-f]{16}$') { throw 'The campaign scope key is invalid.' }
$scopeKeyFromRecord = Get-ToolkitCampaignScopeKey -Install ([pscustomobject]@{ InstallRoot = '__ROOT__' })
if ($scopeKeyFromRecord -cne $scopeKey) { throw 'The campaign scope key is not stable for an equivalent record.' }
$scopeKeyFromDictionary = Get-ToolkitCampaignScopeKey -Install @{ InstallRoot = '__ROOT__' }
if ($scopeKeyFromDictionary -cne $scopeKey) { throw 'A dictionary shaped install produced a different campaign scope key.' }
Write-Output ('FAILURES=' + @($report.Failures).Count)
Write-Output 'STANDALONE_OK'
'@
        $standaloneScript = $standaloneScript.Replace('__COMMON__', $commonPath).Replace('__VERIFICATION__', $verificationScriptPath).Replace('__ROOT__', $standaloneRoot).Replace('__VMS__', (Join-Path $standaloneRoot 'vms')).Replace('__MANAGER__', $standaloneManager).Replace('__STATE__', (Join-Path $testRoot 'standalone state'))
        $standaloneRun = Invoke-CheckedProcess -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'RemoteSigned', '-Command', $standaloneScript)
        Assert-Equal 0 $standaloneRun.ExitCode "The standalone verification run failed: $($standaloneRun.Text)"
        Assert-True ($standaloneRun.Text -match 'STANDALONE_OK') "The standalone verification run did not finish: $($standaloneRun.Text)"
        Assert-True ($standaloneRun.Text -notmatch 'not recognized|PropertyNotFound|is not defined|You cannot call a method on a null') "The standalone verification run dereferenced an unloaded module: $($standaloneRun.Text)"

        $launcherScriptedFixture = Join-Path $testRoot 'launcher scripted.cmd'
        [IO.File]::WriteAllText($launcherScriptedFixture, ('@echo off' + "`r`n" + 'set LOCALAPPDATA=' + "`r`n" + 'call "' + $launcherPath + '" -Action Bogus -NonInteractive < nul' + "`r`n"))
        $launcherInteractiveFixture = Join-Path $testRoot 'launcher interactive.cmd'
        [IO.File]::WriteAllText($launcherInteractiveFixture, ('@echo off' + "`r`n" + 'set LOCALAPPDATA=' + "`r`n" + 'call "' + $launcherPath + '" < nul' + "`r`n"))
        $cmdPath = Join-Path $env:SystemRoot 'System32\cmd.exe'
        $launcherScripted = Invoke-CheckedProcess -FilePath $cmdPath -ArgumentList @('/c', $launcherScriptedFixture)
        Assert-True ($launcherScripted.Text -notmatch 'Press any key') "A scripted launcher invocation paused for a key press: $($launcherScripted.Text)"
        Assert-Equal 1 $launcherScripted.ExitCode "A scripted launcher invocation did not propagate the controller exit code: $($launcherScripted.Text)"
        $launcherInteractive = Invoke-CheckedProcess -FilePath $cmdPath -ArgumentList @('/c', $launcherInteractiveFixture)
        Assert-True ($launcherInteractive.Text -match 'Press any key') "An interactive launcher failure did not pause for a key press: $($launcherInteractive.Text)"

        # The mutating dispatch must reach the elevation mechanism: one in-process attempt, then at
        # most one elevated relaunch that repeats the caller's own allowlisted request. The seam is
        # injected here, so no test can ever raise a real UAC prompt.
        Assert-True ($null -ne (Get-Command Invoke-ToolkitActionWithElevation -CommandType Function -ErrorAction SilentlyContinue)) 'Invoke-ToolkitActionWithElevation is unavailable.'
        Assert-True ($null -ne (Get-Command ConvertTo-ToolkitPackageSelection -CommandType Function -ErrorAction SilentlyContinue)) 'ConvertTo-ToolkitPackageSelection is unavailable.'
        # PowerShell -File hands "-Packages a,b" over as one string, so the documented form is split once.
        Assert-Equal 'a|b' ((ConvertTo-ToolkitPackageSelection -Packages @('a,b')) -join '|') 'A comma separated package selection was not split.'
        Assert-Equal 'a|b|jp.pokemon.pokemontcgp' ((ConvertTo-ToolkitPackageSelection -Packages @('a, b', ' jp.pokemon.pokemontcgp ')) -join '|') 'A comma separated package selection was not trimmed or joined.'
        Assert-Equal 0 (ConvertTo-ToolkitPackageSelection -Packages @('   ', ',', '')).Count 'A blank package selection produced a package name.'
        Assert-Equal 'a|b' ((ConvertTo-ToolkitPackageSelection -Packages @('a', 'b')) -join '|') 'A separate package list was not preserved.'
        Assert-Equal 0 (ConvertTo-ToolkitPackageSelection -Packages @()).Count 'An absent package selection did not stay empty.'
        Assert-True ($controllerSource -match 'ConvertTo-ToolkitPackageSelection -Packages \$Packages') 'The controller does not normalize the command-line package selection.'
        Assert-True ($controllerSource -match 'ToolkitProductionElevationRunner') 'The controller process entry point does not arm the elevation seam.'
        $controllerParameters = @((Get-Command Invoke-ToolkitAction -CommandType Function).Parameters.Keys)
        Assert-True ($controllerParameters -ccontains 'ElevatedChild') 'The dispatcher does not accept the internal elevated-child switch.'
        $controllerErrors = $null
        $controllerBlock = @([System.Management.Automation.Language.Parser]::ParseFile($controllerScriptPath, [ref]$null, [ref]$controllerErrors).ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
        Assert-Equal 0 @($controllerErrors).Count 'The controller script does not parse.'
        foreach ($controllerSwitch in @('ElevatedChild', 'FetchDependencies', 'Confirmed', 'Packages')) {
            Assert-True ($controllerBlock -ccontains $controllerSwitch) "The controller does not declare the parameter: $controllerSwitch"
        }
        $administratorPreflight = Test-ToolkitAdministrator
        $permissionFailureMessage = 'Campaign replacement failed: Access to the path ''C:\MuMu Global\shell\ad\campaign.json'' is denied.'
        $elevationAttempts = @{
            Attempts = 0
            Launches = @()
            Message  = $permissionFailureMessage
            Code     = 'CAMPAIGN_REPLACE_FAILED'
        }
        function Invoke-ToolkitAction {
            param([string]$Action, [string]$InstallRoot = '', [int]$InstanceIndex = -1, [int]$SourceIndex = -1, [string]$StateRoot = '', [string[]]$Packages = @(), [string]$Mode = '', [object]$StartIndex = $null, [switch]$Confirmed, [scriptblock]$Prompt = $null, [scriptblock]$Runner = $null, [switch]$ElevatedChild)
            $elevationAttempts.Attempts++
            return (Get-ToolkitResult -Status 'CriticalError' -Message $elevationAttempts.Message -Data (@{ Code = $elevationAttempts.Code }))
        }
        $grantedElevationRunner = {
            param($ActualFilePath, $ActualArgumentList, $ActualVerb)
            $elevationAttempts.Launches += ,@($ActualFilePath, $ActualArgumentList, $ActualVerb)
            return (Get-ToolkitResult -Status 'Success' -Message 'The elevated child action completed.' -Data (@{ ExitCode = 0; Elevated = $true }))
        }.GetNewClosure()
        $declinedElevationRunner = {
            param($ActualFilePath, $ActualArgumentList, $ActualVerb)
            $elevationAttempts.Launches += ,@($ActualFilePath, $ActualArgumentList, $ActualVerb)
            return (Get-ToolkitResult -Status 'CriticalError' -Message 'Elevation was denied or cancelled by Windows.' -Data (@{ ExitCode = 1; Elevated = $false }))
        }.GetNewClosure()
        $silentElevationRunner = {
            param($ActualFilePath, $ActualArgumentList, $ActualVerb)
            $elevationAttempts.Launches += ,@($ActualFilePath, $ActualArgumentList, $ActualVerb)
            return $null
        }.GetNewClosure()

        $elevatedOnce = Invoke-ToolkitActionWithElevation -Action 'RemoveAds' -InstallRoot 'C:\MuMu Global' -StateRoot 'C:\toolkit state' -ElevationRunner $grantedElevationRunner
        Assert-Equal 1 $elevationAttempts.Attempts 'The mutating action was not attempted exactly once before the elevated relaunch.'
        Assert-Equal 1 $elevationAttempts.Launches.Count 'A non-elevated permission failure did not trigger exactly one elevated relaunch.'
        Assert-Equal 'Success' $elevatedOnce.Status "The elevated relaunch did not report its outcome. $($elevatedOnce.Message)"
        Assert-Equal $true $elevatedOnce.Data.Elevated 'The elevated relaunch did not report the verified elevation state.'
        $launch = @($elevationAttempts.Launches)[0]
        Assert-Equal ([IO.Path]::GetFullPath($controllerScriptPath)) $launch[0] 'The elevated relaunch did not run the toolkit controller that owns the dispatcher.'
        $boundPayload = [string[]]@($launch[1])
        Assert-True ($boundPayload -ccontains '-NonInteractive') 'The elevated child was not launched as a single noninteractive run.'
        Assert-Equal 'RemoveAds' $boundPayload[[array]::IndexOf($boundPayload, '-Action') + 1] 'The elevated relaunch did not carry the allowlisted action.'
        Assert-Equal 'C:\MuMu Global' $boundPayload[[array]::IndexOf($boundPayload, '-InstallRoot') + 1] 'The elevated relaunch did not carry the bound installation path.'
        Assert-Equal 'C:\toolkit state' $boundPayload[[array]::IndexOf($boundPayload, '-StateRoot') + 1] 'The elevated relaunch did not carry the bound state path.'
        Assert-True ($boundPayload -ccontains '-ElevatedChild') 'The elevated relaunch did not mark the child as the already elevated run.'

        $elevationAttempts.Attempts = 0
        $elevationAttempts.Launches = @()
        $childRun = Invoke-ToolkitActionWithElevation -Action 'RemoveAds' -InstallRoot 'C:\MuMu Global' -StateRoot 'C:\toolkit state' -ElevatedChild -ElevationRunner $grantedElevationRunner
        Assert-Equal 1 $elevationAttempts.Attempts 'The elevated child did not attempt the action exactly once.'
        Assert-Equal 0 $elevationAttempts.Launches.Count 'The elevated child asked for rights a second time.'
        Assert-Equal 'CriticalError' $childRun.Status 'The elevated child hid a permission failure instead of reporting it.'
        Assert-Equal 'CAMPAIGN_REPLACE_FAILED' $childRun.Data.Code 'The elevated child changed the reported failure code.'

        $elevationAttempts.Attempts = 0
        $elevationAttempts.Launches = @()
        $declined = Invoke-ToolkitActionWithElevation -Action 'RemoveAds' -InstallRoot 'C:\MuMu Global' -StateRoot 'C:\toolkit state' -ElevationRunner $declinedElevationRunner
        Assert-Equal 'CriticalError' $declined.Status 'A declined elevation was treated as success.'
        Assert-True ($declined.Message -match '(?i)denied|cancelled') "A declined elevation did not report a permission error. $($declined.Message)"
        Assert-Equal 1 $elevationAttempts.Attempts 'A declined elevation repeated the in-process attempt instead of failing closed.'
        Assert-Equal 1 $elevationAttempts.Launches.Count 'A declined elevation asked for rights more than once.'

        $elevationAttempts.Attempts = 0
        $elevationAttempts.Launches = @()
        $silentElevation = Invoke-ToolkitActionWithElevation -Action 'RemoveAds' -InstallRoot 'C:\MuMu Global' -StateRoot 'C:\toolkit state' -ElevationRunner $silentElevationRunner
        Assert-Equal 'CriticalError' $silentElevation.Status 'An elevated relaunch that reported no outcome was treated as success.'
        Assert-Equal 'ELEVATION_OUTCOME_INVALID' $silentElevation.Data.Code 'An elevated relaunch without an outcome reported the wrong code.'
        Assert-Equal 1 $elevationAttempts.Attempts 'An elevated relaunch without an outcome repeated the in-process attempt.'

        $elevationAttempts.Attempts = 0
        $elevationAttempts.Launches = @()
        $elevationAttempts.Message = 'The campaign backup root already contains a restore point. An existing backup is never overwritten.'
        $elevationAttempts.Code = 'CAMPAIGN_RESTORE_POINT_MISSING'
        $semantic = Invoke-ToolkitActionWithElevation -Action 'Root12' -InstallRoot 'C:\MuMu Global' -StateRoot 'C:\toolkit state' -ElevationRunner $grantedElevationRunner
        Assert-Equal 1 $elevationAttempts.Attempts 'A semantic refusal was not reported from the in-process attempt.'
        Assert-Equal 0 $elevationAttempts.Launches.Count 'A semantic refusal forced a host that does not need rights through a UAC prompt.'
        Assert-Equal 'CAMPAIGN_RESTORE_POINT_MISSING' $semantic.Data.Code 'A semantic refusal was replaced by an elevation outcome.'

        $elevationAttempts.Message = $permissionFailureMessage
        $elevationAttempts.Code = 'ACCESS_DENIED'
        foreach ($readOnlyAction in @('Detect', 'Verify')) {
            $elevationAttempts.Attempts = 0
            $elevationAttempts.Launches = @()
            $readOnlyResult = Invoke-ToolkitActionWithElevation -Action $readOnlyAction -InstallRoot 'C:\MuMu Global' -StateRoot 'C:\toolkit state' -ElevationRunner $grantedElevationRunner
            Assert-Equal 1 $elevationAttempts.Attempts "A read-only action was not attempted in process: $readOnlyAction"
            Assert-Equal 0 $elevationAttempts.Launches.Count "A read-only action was relaunched elevated: $readOnlyAction"
            Assert-Equal 'CriticalError' $readOnlyResult.Status "A read-only action hid its own failure: $readOnlyAction"
        }

        $elevationAttempts.Attempts = 0
        $elevationAttempts.Launches = @()
        $unarmed = Invoke-ToolkitActionWithElevation -Action 'RemoveAds' -InstallRoot 'C:\MuMu Global' -StateRoot 'C:\toolkit state'
        Assert-Equal 1 $elevationAttempts.Attempts 'An unarmed process did not attempt the action in process.'
        Assert-Equal 'CriticalError' $unarmed.Status 'An unarmed process reported a permission failure as anything but a failure.'
        Assert-Equal 'ACCESS_DENIED' $unarmed.Data.Code 'An unarmed process changed the reported failure code.'

        $elevationAttempts.Attempts = 0
        $elevationAttempts.Launches = @()
        $alreadyElevated = Invoke-ToolkitActionWithElevation -Action 'RemoveAds' -InstallRoot 'C:\MuMu Global' -StateRoot 'C:\toolkit state' -ElevationRunner $grantedElevationRunner
        Assert-Equal 1 $elevationAttempts.Attempts 'The mutating action was not attempted exactly once.'
        if ($administratorPreflight) {
            Assert-Equal 0 $elevationAttempts.Launches.Count 'A process that already holds rights asked Windows for them again.'
            Assert-Equal 'CriticalError' $alreadyElevated.Status 'A process that already holds rights hid the permission failure.'
        }
        else {
            Assert-Equal 1 $elevationAttempts.Launches.Count 'A non-elevated permission failure did not reach the elevation seam.'
        }
        Remove-Item -LiteralPath 'function:Invoke-ToolkitAction' -ErrorAction SilentlyContinue
    }
    finally {
        $script:MenuFallbackRoots = @()
    }
}

function New-TargetFixture {
    param(
        [string]$Name,
        [int[]]$InstanceIndexes = @(0, 2, 3),
        [switch]$AmbiguousVms,
        [switch]$Running
    )

    $root = Join-Path $testRoot ('target fixtures\MuMu Global\' + $Name)
    $fixture = New-SafetyInstallFixture -InstallRoot $root -InstanceIndexes $InstanceIndexes
    if ($AmbiguousVms) {
        foreach ($versionedName in @('12.0', '15.0')) {
            $versionedVms = Join-Path $root ('nx_device\' + $versionedName + '\vms')
            [void][IO.Directory]::CreateDirectory((Join-Path $versionedVms ('MuMuPlayerGlobal-' + $versionedName + '-4')))
        }
    }
    return [pscustomobject]@{
        Install = [pscustomobject]@{
            Edition = 'Global'
            InstallRoot = $fixture.InstallRoot
            VmsPath = $fixture.VmsPath
            ManagerPath = $fixture.ManagerPath
            Source = 'Fallback'
        }
        VmsPath = $fixture.VmsPath
        State = (New-SafetyManagerState -VmsPath $fixture.VmsPath -Running ([bool]$Running))
    }
}

function New-TargetJournal {
    param([object]$Instance)

    return New-OperationJournal -Root (Join-Path $testRoot 'target journals') -Operation 'Target' -Instance $Instance
}

function Get-TargetManagerCommands {
    param([object]$State)

    return @(@($State.Calls) | ForEach-Object { (@($_) -join '|') })
}

function Get-TargetMutatingCommands {
    param([object]$State)

    return @(@(Get-TargetManagerCommands -State $State) | Where-Object { $_ -notmatch '^(info|setting)\|' })
}

function Assert-TargetManagerCommands {
    param(
        [object]$State,
        [string[]]$AllowedVerbs,
        [string]$Message
    )

    foreach ($command in @(Get-TargetManagerCommands -State $State)) {
        $verb = [string](@($command -split '\|')[0])
        Assert-True ($AllowedVerbs -ccontains $verb) "$Message The manager ran an unexpected command: $command"
        Assert-True ($command -notmatch '(?i)\b(delete|rename|uninstall|uninstall-multiple)\b') "$Message The manager ran a forbidden command: $command"
        Assert-True ($command -notmatch '(?i)-val') "$Message The manager ran a value-changing command: $command"
    }
}

function Assert-TargetFailedJournal {
    param(
        [object]$Result,
        [object]$Journal,
        [string]$Message
    )

    Assert-Equal 'CriticalError' $Result.Status $Message
    Assert-Equal 'Failed' $Journal.State "$Message The failure was not journaled."
    $reopened = Get-OperationJournal -Path $Journal.JournalPath
    Assert-Equal 'Failed' $reopened.State "$Message The failure was not persisted."
    Assert-True ($reopened.Result.Message -ceq $Result.Message) "$Message The persisted message changed."
    Assert-True (@($reopened.Checkpoints).Count -ge 1) "$Message No failure checkpoint was recorded."
}

function Get-TargetSourceInstanceDelta {
    param(
        [object]$Before,
        [object]$After,
        [int[]]$InstanceIndexes
    )

    $delta = @()
    foreach ($file in @(Get-MenuSnapshotDelta -Before $Before -After $After)) {
        $parentName = [IO.Path]::GetFileName((Split-Path -Parent $file))
        $parsedIndex = 0
        if ([int]::TryParse($parentName, [ref]$parsedIndex) -and $InstanceIndexes -contains $parsedIndex) {
            $delta += $file
        }
    }
    return $delta
}

function Invoke-TargetTests {
    foreach ($commandName in @('Get-ToolkitInstanceChoices', 'New-MuMuInstance', 'Select-ToolkitTarget', 'Resolve-ToolkitCloneSource', 'ConvertTo-ToolkitInstanceIndex')) {
        Assert-True ($null -ne (Get-Command $commandName -CommandType Function -ErrorAction SilentlyContinue)) "Target command is unavailable: $commandName"
    }
    Assert-True (Test-Path -LiteralPath $targetScriptPath -PathType Leaf) 'src/Target.ps1 does not exist.'

    $targetSource = [IO.File]::ReadAllText($targetScriptPath)
    foreach ($forbidden in @(
            'Invoke-Expression',
            'ScriptBlock]::Create',
            'Add-Type',
            'Start-Process',
            'RunAs',
            'Invoke-WebRequest',
            'Invoke-RestMethod',
            'WebClient',
            'Set-ExecutionPolicy',
            'Set-ItemProperty',
            'New-ItemProperty',
            'Remove-ItemProperty',
            'Set-MpPreference',
            'bcdedit',
            'schtasks',
            'rmdir',
            'Remove-Item',
            'bypass',
            'UNKNOWN'
        )) {
        Assert-True ($targetSource -notmatch [regex]::Escape($forbidden)) "The target source uses a forbidden construct: $forbidden"
    }
    foreach ($sharedPrimitive in @('Get-MuMuInstances', 'Resolve-SelectedInstance', 'New-InstanceClone', 'Get-MuMuInstanceRecord', 'Get-MuMuInstanceRootPath', 'Get-MuMuInstanceRunningState', 'Measure-MuMuInstanceDiskBytes', 'Test-ToolkitManagerFile', 'Test-ToolkitPathWithinRoot', 'Get-ToolkitMenuChoice', 'New-ToolkitInstanceFailure', 'ConvertTo-ToolkitInstanceIndex', 'Resolve-ToolkitCloneSource')) {
        Assert-True ($targetSource -match [regex]::Escape($sharedPrimitive)) "The target flow does not reuse the shared primitive: $sharedPrimitive"
    }
    Assert-True ($targetSource -match "'create',\s*'-n'") 'The target flow does not call the manager create command with structured arguments.'
    Assert-True ($targetSource -match "cnotcontains \`$Mode") 'The target flow does not reject an unsupported target mode.'
    Assert-True ($targetSource -notmatch 'Get-ToolkitVmsPath') 'The target flow re-derives an instance root instead of using the selected installation.'
    Assert-True ($targetSource -notmatch 'Get-ToolkitInstallRoot|Get-ToolkitEdition') 'The target flow re-derives installation metadata instead of using the selected installation.'
    Assert-True ($targetSource -match "\`$Install\.PSObject\.Properties\['VmsPath'\]") 'The target flow does not use the selected installation VMS path.'

    Assert-Equal 5 (ConvertTo-ToolkitInstanceIndex -Value '5') 'The instance index parser rejected a plain index.'
    Assert-Equal 0 (ConvertTo-ToolkitInstanceIndex -Value ' 0 ') 'The instance index parser rejected a padded zero index.'
    foreach ($rejectedIndex in @($null, '', '   ', 'abc', '-1', '5.5', @('5'), [pscustomobject]@{ Index = 5 })) {
        Assert-Equal $null (ConvertTo-ToolkitInstanceIndex -Value $rejectedIndex) "The instance index parser accepted [$rejectedIndex]."
    }

    $targetAppData = $env:APPDATA
    $targetProfileRoot = Join-Path $testRoot 'target profile'
    [void][IO.Directory]::CreateDirectory((Join-Path $targetProfileRoot 'empty'))
    $env:APPDATA = Join-Path $targetProfileRoot 'empty'
    try {
        $identify = New-TargetFixture -Name 'identify'
        $identifyChoices = Get-ToolkitInstanceChoices -Install $identify.Install -Runner (New-SafetyManagerRunner -State $identify.State)
        Assert-Equal 'Success' $identifyChoices.Status "The read-only instance listing failed: $($identifyChoices.Message)"
        $choiceRecords = @($identifyChoices.Data)
        Assert-Equal 3 $choiceRecords.Count 'The read-only instance listing did not report every discovered instance.'
        Assert-Equal (@('Index', 'Name', 'AndroidVersion', 'Running', 'Eligible') -join ',') (@($choiceRecords[0].PSObject.Properties | ForEach-Object { $_.Name }) -join ',') 'The instance choice does not report exactly the documented fields.'
        Assert-Equal 0 $choiceRecords[0].Index 'The base instance was not listed first.'
        Assert-Equal $false $choiceRecords[0].Eligible 'The base instance is eligible.'
        Assert-Equal 2 $choiceRecords[1].Index 'The instance listing reported the wrong index.'
        Assert-Equal 'Other' $choiceRecords[1].Name 'The instance listing reported the wrong name.'
        Assert-Equal '12.0' $choiceRecords[1].AndroidVersion 'The instance listing reported the wrong Android version.'
        Assert-Equal $false $choiceRecords[1].Running 'The instance listing reported the wrong running state.'
        Assert-Equal $true $choiceRecords[1].Eligible 'A supported non-base instance is not eligible.'
        Assert-TargetManagerCommands -State $identify.State -AllowedVerbs @('info', 'setting') -Message 'The read-only instance listing'
        Assert-True (@(Get-TargetManagerCommands -State $identify.State | Where-Object { $_ -ceq 'info|-v|all' }).Count -eq 1) 'The read-only instance listing did not enumerate every instance exactly once.'

        $identifyJournal = New-TargetJournal -Instance $identify.Install
        $identifyResult = Select-ToolkitTarget -Install $identify.Install -Journal $identifyJournal -Mode Identify -InstanceIndex 2 -Runner (New-SafetyManagerRunner -State $identify.State)
        Assert-Equal 'Success' $identifyResult.Status "The Identify target mode failed: $($identifyResult.Message)"
        Assert-Equal 'Identify' $identifyResult.Data.Mode 'The target result did not report its mode.'
        Assert-Equal 2 $identifyResult.Data.Index 'The Identify target mode did not report the selected index.'
        Assert-Equal 'Other' $identifyResult.Data.Name 'The Identify target mode did not report the selected name.'
        Assert-Equal '12.0' $identifyResult.Data.AndroidVersion 'The Identify target mode did not report the Android version.'
        Assert-Equal 'Global' $identifyResult.Data.Edition 'The Identify target mode did not report the installation edition.'
        Assert-Equal 3 $identifyResult.Data.InstanceCount 'The Identify target mode did not report the discovered instance count.'
        Assert-True ($identifyResult.Message -match 'Nothing was changed') 'The Identify target mode did not report that it changes nothing.'
        Assert-Equal 'Running' $identifyJournal.State 'The Identify target mode did not leave its journal open for the caller to close.'
        Assert-True (@((Get-OperationJournal -Path $identifyJournal.JournalPath).Checkpoints)).Count -ge 1 'The Identify target mode did not record the selected target in its journal.'
        Assert-TargetManagerCommands -State $identify.State -AllowedVerbs @('info', 'setting') -Message 'The Identify target mode'

        $identifyText = @(Format-ToolkitResult -Result $identifyResult) -join "`n"
        foreach ($expectedLine in @(
                'Instance 0 | Base | Android 12.0 | Running False | Eligible False',
                'Instance 2 | Other | Android 12.0 | Running False | Eligible True',
                'Instance 3 | Target | Android 12.0 | Running False | Eligible True'
            )) {
            Assert-True ($identifyText -match [regex]::Escape($expectedLine)) "The rendered Identify result does not list the instance fields: $expectedLine"
        }
        $overflowChoices = @()
        for ($overflowIndex = 0; $overflowIndex -lt ($script:ToolkitInstanceChoiceLimit + 4); $overflowIndex++) {
            $overflowChoices += [pscustomobject]@{ Index = $overflowIndex; Name = 'Filler'; AndroidVersion = '12.0'; Running = $false; Eligible = $true }
        }
        $overflowResult = Get-ToolkitResult -Status 'Success' -Message 'overflow fixture' -Data (@{ Mode = 'Identify'; Instances = $overflowChoices })
        $overflowText = @(Format-ToolkitResult -Result $overflowResult) -join "`n"
        Assert-Equal $script:ToolkitInstanceChoiceLimit @([regex]::Matches($overflowText, '(?m)^  Instance ')).Count 'The rendered instance listing is not bounded.'
        Assert-True ($overflowText -match 'more instance\(s\) were not listed') 'The rendered instance listing does not report the omitted instances.'

        $ambiguousJournal = New-TargetJournal -Instance $identify.Install
        $ambiguous = Select-ToolkitTarget -Install $identify.Install -Journal $ambiguousJournal -Mode Identify -Runner (New-SafetyManagerRunner -State $identify.State)
        Assert-TargetFailedJournal -Result $ambiguous -Journal $ambiguousJournal -Message 'An ambiguous target selection was accepted.'
        Assert-True ($ambiguous.Message -match '(?i)explicit|target') "An ambiguous target selection did not explain itself: $($ambiguous.Message)"

        $promptedJournal = New-TargetJournal -Instance $identify.Install
        $promptedTarget = Select-ToolkitTarget -Install $identify.Install -Journal $promptedJournal -Mode Identify -Prompt ({ '2' }).GetNewClosure() -Runner (New-SafetyManagerRunner -State $identify.State)
        Assert-Equal 'Success' $promptedTarget.Status "A prompted target selection failed: $($promptedTarget.Message)"
        Assert-Equal 3 $promptedTarget.Data.Index 'A prompted target selection chose the wrong instance.'
        $outOfRangeJournal = New-TargetJournal -Instance $identify.Install
        $outOfRange = Select-ToolkitTarget -Install $identify.Install -Journal $outOfRangeJournal -Mode Identify -Prompt ({ '9' }).GetNewClosure() -Runner (New-SafetyManagerRunner -State $identify.State)
        Assert-Equal 'CriticalError' $outOfRange.Status 'An out-of-range prompted target selection was accepted.'
        $ineligibleJournal = New-TargetJournal -Instance $identify.Install
        $ineligible = Select-ToolkitTarget -Install $identify.Install -Journal $ineligibleJournal -Mode Identify -InstanceIndex 0 -Runner (New-SafetyManagerRunner -State $identify.State)
        Assert-Equal 'CriticalError' $ineligible.Status 'A base instance was accepted as a target.'

        $emptyInstall = New-TargetFixture -Name 'empty' -InstanceIndexes @(0)
        $emptyJournal = New-TargetJournal -Instance $emptyInstall.Install
        $empty = Select-ToolkitTarget -Install $emptyInstall.Install -Journal $emptyJournal -Mode Identify -Runner (New-SafetyManagerRunner -State $emptyInstall.State)
        Assert-Equal 'CriticalError' $empty.Status 'An installation without an eligible instance selected a target.'

        $invalidModeJournal = New-TargetJournal -Instance $identify.Install
        $invalidMode = Select-ToolkitTarget -Install $identify.Install -Journal $invalidModeJournal -Mode 'Bogus' -Runner (New-SafetyManagerRunner -State $identify.State)
        Assert-TargetFailedJournal -Result $invalidMode -Journal $invalidModeJournal -Message 'An unsupported target mode was accepted.'
        Assert-True ($invalidMode.Message -match 'Identify, Create, or Clone') "An unsupported target mode did not explain itself: $($invalidMode.Message)"
        $nullJournal = Select-ToolkitTarget -Install $identify.Install -Journal $null -Mode Identify
        Assert-Equal 'CriticalError' $nullJournal.Status 'A target selection without a journal was accepted.'
        $invalidJournal = Select-ToolkitTarget -Install $identify.Install -Journal ([pscustomobject]@{ State = 'Running' }) -Mode Identify
        Assert-Equal 'CriticalError' $invalidJournal.Status 'A target selection with an invalid journal was accepted.'

        $unconfirmedCreate = New-TargetFixture -Name 'unconfirmed create'
        $unconfirmedJournal = New-TargetJournal -Instance $unconfirmedCreate.Install
        $unconfirmed = New-MuMuInstance -ManagerPath $unconfirmedCreate.Install.ManagerPath -Install $unconfirmedCreate.Install -Journal $unconfirmedJournal -Runner (New-SafetyManagerRunner -State $unconfirmedCreate.State)
        Assert-TargetFailedJournal -Result $unconfirmed -Journal $unconfirmedJournal -Message 'An unconfirmed instance creation was accepted.'
        Assert-True ($unconfirmed.Message -match '(?i)confirm') 'An unconfirmed instance creation did not ask for an explicit confirmation.'
        Assert-Equal 0 $unconfirmedCreate.State.Calls.Count "An unconfirmed instance creation reached the manager: $(@(Get-TargetManagerCommands -State $unconfirmedCreate.State) -join '|')"

        foreach ($badCount in @(0, 2)) {
            $countFixture = New-TargetFixture -Name "count $badCount"
            $countJournal = New-TargetJournal -Instance $countFixture.Install
            $count = New-MuMuInstance -ManagerPath $countFixture.Install.ManagerPath -Install $countFixture.Install -Journal $countJournal -Count $badCount -Confirmed -Runner (New-SafetyManagerRunner -State $countFixture.State)
            Assert-Equal 'CriticalError' $count.Status "A create count of $badCount was accepted."
            Assert-Equal 0 $countFixture.State.Calls.Count "A rejected create count of $badCount reached the manager."
        }

        foreach ($badIndex in @('', '   ', 'abc', '-1', '-7')) {
            $indexFixture = New-TargetFixture -Name 'invalid start index'
            $indexJournal = New-TargetJournal -Instance $indexFixture.Install
            $index = New-MuMuInstance -ManagerPath $indexFixture.Install.ManagerPath -Install $indexFixture.Install -Journal $indexJournal -StartIndex $badIndex -Confirmed -Runner (New-SafetyManagerRunner -State $indexFixture.State)
            Assert-Equal 'CriticalError' $index.Status "The start index [$badIndex] was accepted."
            Assert-Equal 0 $indexFixture.State.Calls.Count "The start index [$badIndex] reached the manager."
        }

        $inUseFixture = New-TargetFixture -Name 'index in use'
        $inUseJournal = New-TargetJournal -Instance $inUseFixture.Install
        $inUse = New-MuMuInstance -ManagerPath $inUseFixture.Install.ManagerPath -Install $inUseFixture.Install -Journal $inUseJournal -StartIndex '2' -Confirmed -Runner (New-SafetyManagerRunner -State $inUseFixture.State)
        Assert-Equal 'CriticalError' $inUse.Status 'A create request over an existing instance index was accepted.'
        Assert-True ($inUse.Message -match 'already in use') "A create request over an existing index did not explain itself: $($inUse.Message)"
        Assert-TargetManagerCommands -State $inUseFixture.State -AllowedVerbs @('info', 'setting') -Message 'A create request over an existing index'
        Assert-Equal 0 @(@(Get-TargetManagerCommands -State $inUseFixture.State) | Where-Object { $_ -like 'create|*' }).Count 'A create request over an existing index reached the manager create command.'

        $managerFixture = New-TargetFixture -Name 'invalid manager'
        $managerJournal = New-TargetJournal -Instance $managerFixture.Install
        $notManager = New-MuMuInstance -ManagerPath (Join-Path $managerFixture.Install.InstallRoot 'vms\2\system.img') -Install $managerFixture.Install -Journal $managerJournal -Confirmed -Runner (New-SafetyManagerRunner -State $managerFixture.State)
        Assert-Equal 'CriticalError' $notManager.Status 'A create request with a path that is not MuMuManager.exe was accepted.'
        Assert-Equal 0 $managerFixture.State.Calls.Count 'A create request with an invalid manager reached the process runner.'
        $outsideJournal = New-TargetJournal -Instance $managerFixture.Install
        $outsideManager = New-MuMuInstance -ManagerPath (Join-Path $testRoot 'target fixtures\MuMu Global\absent\shell\MuMuManager.exe') -Install $managerFixture.Install -Journal $outsideJournal -Confirmed -Runner (New-SafetyManagerRunner -State $managerFixture.State)
        Assert-Equal 'CriticalError' $outsideManager.Status 'A create request with a manager outside the install root was accepted.'
        $noInstallJournal = New-TargetJournal -Instance $managerFixture.Install
        $noInstall = New-MuMuInstance -ManagerPath $managerFixture.Install.ManagerPath -Install $null -Journal $noInstallJournal -Confirmed -Runner (New-SafetyManagerRunner -State $managerFixture.State)
        Assert-Equal 'CriticalError' $noInstall.Status 'A create request without the selected installation was accepted.'
        $conflictingInstall = [pscustomobject]@{
            Edition = 'Global'
            InstallRoot = $managerFixture.Install.InstallRoot
            VmsPath = $managerFixture.Install.VmsPath
            ManagerPath = (Join-Path $managerFixture.Install.InstallRoot 'nx_device\12.0\vms\MuMuManager.exe')
            Source = 'Fallback'
        }
        $conflictingJournal = New-TargetJournal -Instance $managerFixture.Install
        $conflicting = New-MuMuInstance -ManagerPath $managerFixture.Install.ManagerPath -Install $conflictingInstall -Journal $conflictingJournal -Confirmed -Runner (New-SafetyManagerRunner -State $managerFixture.State)
        Assert-Equal 'CriticalError' $conflicting.Status 'A create request whose manager conflicts with the selected installation was accepted.'
        $absentVms = [pscustomobject]@{
            Edition = 'Global'
            InstallRoot = $managerFixture.Install.InstallRoot
            VmsPath = (Join-Path $managerFixture.Install.InstallRoot 'vms\absent')
            ManagerPath = $managerFixture.Install.ManagerPath
            Source = 'Fallback'
        }
        $absentVmsJournal = New-TargetJournal -Instance $managerFixture.Install
        $absentVmsResult = New-MuMuInstance -ManagerPath $managerFixture.Install.ManagerPath -Install $absentVms -Journal $absentVmsJournal -Confirmed -Runner (New-SafetyManagerRunner -State $managerFixture.State)
        Assert-Equal 'CriticalError' $absentVmsResult.Status 'A create request with an unavailable instance root was accepted.'
        Assert-Equal 0 @(Get-TargetMutatingCommands -State $managerFixture.State).Count "A rejected create request reached the manager: $(@(Get-TargetManagerCommands -State $managerFixture.State) -join '|')"

        $createFixture = New-TargetFixture -Name 'create'
        $createFixture.State.CreateIndexes = @('5')
        $createSnapshotBefore = New-MenuSnapshot -Root $createFixture.Install.VmsPath
        $createJournal = New-TargetJournal -Instance $createFixture.Install
        $create = New-MuMuInstance -ManagerPath $createFixture.Install.ManagerPath -Install $createFixture.Install -Journal $createJournal -Count 1 -StartIndex '5' -Confirmed -Runner (New-SafetyManagerRunner -State $createFixture.State)
        Assert-Equal 'Success' $create.Status "A confirmed instance creation failed: $($create.Message)"
        Assert-Equal 5 $create.Data.Index 'The created instance record reported the wrong index.'
        Assert-Equal 'Created instance' $create.Data.Name 'The created instance record reported the wrong name.'
        Assert-Equal '12.0' $create.Data.AndroidVersion 'The created instance record reported the wrong Android version.'
        Assert-Equal $false $create.Data.Running 'The created instance record reported the wrong running state.'
        Assert-True ([long]$create.Data.DiskBytes -gt 0) 'The created instance record reported no usable disk.'
        Assert-Equal 5 $create.Data.RequestedIndex 'The created instance record lost the requested start index.'
        Assert-Equal $true $create.Data.StaticReady 'The created instance record is not marked statically ready.'
        Assert-Equal $false $create.Data.ColdBootVerified 'The created instance record claims a verified cold boot.'
        Assert-True ($create.Message -match 'cold boot is not verified') 'The created instance record hides that a cold boot is unverified.'
        Assert-Equal 'Running' $createJournal.State 'A confirmed instance creation did not leave its journal open for the caller to close.'
        Assert-True (@((Get-OperationJournal -Path $createJournal.JournalPath).Checkpoints)).Count -ge 1 'A confirmed instance creation did not record the created instance in its journal.'
        Assert-TargetManagerCommands -State $createFixture.State -AllowedVerbs @('info', 'setting', 'create') -Message 'A confirmed instance creation'
        $createCommands = @(Get-TargetManagerCommands -State $createFixture.State)
        Assert-Equal 1 @($createCommands | Where-Object { $_ -ceq 'create|-n|1' }).Count "A confirmed instance creation issued an unexpected create command: $($createCommands -join '|')"
        Assert-Equal 2 @($createCommands | Where-Object { $_ -ceq 'info|-v|all' }).Count "A confirmed instance creation did not re-enumerate the instances exactly twice: $($createCommands -join '|')"
        $createSourceDelta = @(Get-TargetSourceInstanceDelta -Before $createSnapshotBefore -After (New-MenuSnapshot -Root $createFixture.Install.VmsPath) -InstanceIndexes @(0, 2, 3))
        Assert-Equal 0 $createSourceDelta.Count "A confirmed instance creation changed an existing instance: $($createSourceDelta -join '|')"

        $ambiguousVmsFixture = New-TargetFixture -Name 'ambiguous vms' -AmbiguousVms
        $inferenceRefused = $false
        try {
            $null = Get-ToolkitVmsPath -InstallRoot $ambiguousVmsFixture.Install.InstallRoot -CandidatePath '' -Edition 'Global'
        }
        catch {
            $inferenceRefused = $true
        }
        Assert-True $inferenceRefused 'The multi-candidate fixture did not make instance root inference ambiguous.'
        $ambiguousVmsFixture.State.CreateIndexes = @('5')
        $ambiguousVmsJournal = New-TargetJournal -Instance $ambiguousVmsFixture.Install
        $ambiguousVmsCreate = New-MuMuInstance -ManagerPath $ambiguousVmsFixture.Install.ManagerPath -Install $ambiguousVmsFixture.Install -Journal $ambiguousVmsJournal -StartIndex '5' -Confirmed -Runner (New-SafetyManagerRunner -State $ambiguousVmsFixture.State)
        Assert-Equal 'Success' $ambiguousVmsCreate.Status "A create on an installation with several inferred instance roots failed: $($ambiguousVmsCreate.Message)"
        Assert-Equal 5 $ambiguousVmsCreate.Data.Index 'A create on an ambiguous installation reported the wrong index.'
        Assert-Equal (Join-Path $ambiguousVmsFixture.Install.VmsPath '5') $ambiguousVmsCreate.Data.VmsPath 'A create on an ambiguous installation did not use the selected installation instance root.'
        Assert-True (Test-Path -LiteralPath (Join-Path $ambiguousVmsFixture.Install.VmsPath '5\system.img') -PathType Leaf) 'A create on an ambiguous installation did not write the instance into the selected installation instance root.'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $ambiguousVmsFixture.Install.InstallRoot 'nx_device\12.0\vms\5'))) 'A create on an ambiguous installation wrote into an inferred instance root that was not selected.'

        $createTargetFixture = New-TargetFixture -Name 'create target'
        $createTargetFixture.State.CreateIndexes = @('5')
        $unconfirmedTargetJournal = New-TargetJournal -Instance $createTargetFixture.Install
        $unconfirmedTarget = Select-ToolkitTarget -Install $createTargetFixture.Install -Journal $unconfirmedTargetJournal -Mode Create -StartIndex '5' -Runner (New-SafetyManagerRunner -State $createTargetFixture.State)
        Assert-Equal 'CriticalError' $unconfirmedTarget.Status 'An unconfirmed create target mode was accepted.'
        Assert-True ($unconfirmedTarget.Message -match '(?i)confirm') 'An unconfirmed create target mode did not ask for an explicit confirmation.'
        Assert-Equal 0 $createTargetFixture.State.Calls.Count 'An unconfirmed create target mode reached the manager.'
        $createTargetJournal = New-TargetJournal -Instance $createTargetFixture.Install
        $createTarget = Select-ToolkitTarget -Install $createTargetFixture.Install -Journal $createTargetJournal -Mode Create -StartIndex '5' -Confirmed -Runner (New-SafetyManagerRunner -State $createTargetFixture.State)
        Assert-Equal 'Success' $createTarget.Status "A confirmed create target mode failed: $($createTarget.Message)"
        Assert-Equal 'Create' $createTarget.Data.Mode 'The create target mode did not report its mode.'
        Assert-Equal 5 $createTarget.Data.Index 'The create target mode did not report the created index.'
        Assert-Equal 'Global' $createTarget.Data.Edition 'The create target mode did not report the installation edition.'

        $namedRootFixture = New-TargetFixture -Name 'named root' -InstanceIndexes @(0, 2)
        foreach ($namedInstance in @('MuMuPlayerGlobal-12.0-3', 'MuMuPlayerGlobal-12.0-base', 'MuMuPlayer-15.0-4')) {
            [void][IO.Directory]::CreateDirectory((Join-Path $namedRootFixture.Install.VmsPath $namedInstance))
        }
        $namedGlobalRoot = Get-MuMuInstanceRootPath -VmsPath $namedRootFixture.Install.VmsPath -Index 3 -ReportedVmsPath ''
        Assert-Equal (Join-Path $namedRootFixture.Install.VmsPath 'MuMuPlayerGlobal-12.0-3') $namedGlobalRoot 'A named Global instance root was not resolved.'
        $namedChineseRoot = Get-MuMuInstanceRootPath -VmsPath $namedRootFixture.Install.VmsPath -Index 4 -ReportedVmsPath ''
        Assert-Equal (Join-Path $namedRootFixture.Install.VmsPath 'MuMuPlayer-15.0-4') $namedChineseRoot 'A named instance root of another edition naming was not resolved.'
        Assert-Equal (Join-Path $namedRootFixture.Install.VmsPath '2') (Get-MuMuInstanceRootPath -VmsPath $namedRootFixture.Install.VmsPath -Index 2 -ReportedVmsPath '') 'A numeric instance root was not resolved.'
        Assert-Equal $null (Get-MuMuInstanceRootPath -VmsPath $namedRootFixture.Install.VmsPath -Index 9 -ReportedVmsPath '') 'A base-only VMS root resolved an instance root for a missing index.'
        [void][IO.Directory]::CreateDirectory((Join-Path $namedRootFixture.Install.VmsPath 'vms\MuMuPlayerGlobal-12.0-5'))
        Assert-Equal (Join-Path $namedRootFixture.Install.VmsPath 'vms\MuMuPlayerGlobal-12.0-5') (Get-MuMuInstanceRootPath -VmsPath $namedRootFixture.Install.VmsPath -Index 5 -ReportedVmsPath '') 'A named instance root under a nested vms directory was not resolved.'
        Assert-Equal $null (Get-MuMuInstanceRootPath -VmsPath $namedRootFixture.Install.VmsPath -Index 6 -ReportedVmsPath '') 'A named instance root in two locations for one index was merged silently.'
        $ambiguousNamedFixture = New-TargetFixture -Name 'named root ambiguous' -InstanceIndexes @(0, 2)
        foreach ($ambiguousName in @('MuMuPlayerGlobal-12.0-3', 'MuMuPlayerGlobal-15.0-3')) {
            [void][IO.Directory]::CreateDirectory((Join-Path $ambiguousNamedFixture.Install.VmsPath $ambiguousName))
        }
        Assert-Equal $null (Get-MuMuInstanceRootPath -VmsPath $ambiguousNamedFixture.Install.VmsPath -Index 3 -ReportedVmsPath '') 'Two named instance roots for one index were merged silently.'
        $ambiguousNamedCreateFixture = New-TargetFixture -Name 'named create ambiguous' -InstanceIndexes @(0, 2)
        $ambiguousNamedCreateFixture.State.CreateIndexes = @('5')
        $ambiguousNamedCreateFixture.State.CreateRootName = 'MuMuPlayerGlobal-12.0-{0}'
        [void][IO.Directory]::CreateDirectory((Join-Path $ambiguousNamedCreateFixture.Install.VmsPath 'MuMuPlayerGlobal-15.0-5'))
        $ambiguousNamedCreateJournal = New-TargetJournal -Instance $ambiguousNamedCreateFixture.Install
        $ambiguousNamedCreate = New-MuMuInstance -ManagerPath $ambiguousNamedCreateFixture.Install.ManagerPath -Install $ambiguousNamedCreateFixture.Install -Journal $ambiguousNamedCreateJournal -Confirmed -Runner (New-SafetyManagerRunner -State $ambiguousNamedCreateFixture.State)
        Assert-Equal 'CriticalError' $ambiguousNamedCreate.Status 'A create whose instance root matched two named directories was accepted.'

        $namedCreateFixture = New-TargetFixture -Name 'named create' -InstanceIndexes @(0, 2)
        $namedCreateFixture.State.CreateIndexes = @('5')
        $namedCreateFixture.State.CreateRootName = 'MuMuPlayerGlobal-12.0-{0}'
        $namedCreateJournal = New-TargetJournal -Instance $namedCreateFixture.Install
        $namedCreate = New-MuMuInstance -ManagerPath $namedCreateFixture.Install.ManagerPath -Install $namedCreateFixture.Install -Journal $namedCreateJournal -Confirmed -Runner (New-SafetyManagerRunner -State $namedCreateFixture.State)
        Assert-Equal 'Success' $namedCreate.Status "A create into a named instance root failed: $($namedCreate.Message)"
        Assert-Equal 5 $namedCreate.Data.Index 'A create into a named instance root reported the wrong index.'
        Assert-Equal (Join-Path $namedCreateFixture.Install.VmsPath 'MuMuPlayerGlobal-12.0-5') $namedCreate.Data.VmsPath 'A create into a named instance root did not report the named instance root.'
        Assert-True ([long]$namedCreate.Data.DiskBytes -gt 0) 'A create into a named instance root reported no usable disk.'

        $createFailureFixture = New-TargetFixture -Name 'create failure'
        $createFailureFixture.State.CreateExitCode = 1
        $createFailureJournal = New-TargetJournal -Instance $createFailureFixture.Install
        $createFailure = New-MuMuInstance -ManagerPath $createFailureFixture.Install.ManagerPath -Install $createFailureFixture.Install -Journal $createFailureJournal -Confirmed -Runner (New-SafetyManagerRunner -State $createFailureFixture.State)
        Assert-Equal 'CriticalError' $createFailure.Status 'A failed manager create command was reported as a created instance.'
        Assert-True ($createFailure.Message -match '(?i)create command failed') "A failed create command did not explain itself: $($createFailure.Message)"

        foreach ($createdIndexes in @(@(), @('5', '6'))) {
            $ambiguousCreateFixture = New-TargetFixture -Name 'ambiguous create'
            $ambiguousCreateFixture.State.CreateIndexes = $createdIndexes
            $ambiguousCreateJournal = New-TargetJournal -Instance $ambiguousCreateFixture.Install
            $ambiguousCreate = New-MuMuInstance -ManagerPath $ambiguousCreateFixture.Install.ManagerPath -Install $ambiguousCreateFixture.Install -Journal $ambiguousCreateJournal -Confirmed -Runner (New-SafetyManagerRunner -State $ambiguousCreateFixture.State)
            Assert-Equal 'CriticalError' $ambiguousCreate.Status "A create reporting $($createdIndexes.Count) new instance(s) was accepted."
            Assert-True ($ambiguousCreate.Message -match '(?i)exactly one new instance') "An ambiguous create result did not explain itself: $($ambiguousCreate.Message)"
        }

        $malformedCreateFixture = New-TargetFixture -Name 'malformed create'
        $malformedCreateFixture.State.CreateIndexes = @('abc')
        $malformedCreateJournal = New-TargetJournal -Instance $malformedCreateFixture.Install
        $malformedCreate = New-MuMuInstance -ManagerPath $malformedCreateFixture.Install.ManagerPath -Install $malformedCreateFixture.Install -Journal $malformedCreateJournal -Confirmed -Runner (New-SafetyManagerRunner -State $malformedCreateFixture.State)
        Assert-Equal 'CriticalError' $malformedCreate.Status 'A create reporting an unparsable new index was accepted.'

        $baseCreateFixture = New-TargetFixture -Name 'base create'
        $baseCreateFixture.State.CreateIndexes = @('5')
        $baseCreateFixture.State.CreateIsMain = $true
        $baseCreateJournal = New-TargetJournal -Instance $baseCreateFixture.Install
        $baseCreate = New-MuMuInstance -ManagerPath $baseCreateFixture.Install.ManagerPath -Install $baseCreateFixture.Install -Journal $baseCreateJournal -Confirmed -Runner (New-SafetyManagerRunner -State $baseCreateFixture.State)
        Assert-Equal 'CriticalError' $baseCreate.Status 'A create reporting a base instance was accepted.'
        Assert-True ($baseCreate.Message -match 'non-base') "A base create result did not explain itself: $($baseCreate.Message)"

        $versionCreateFixture = New-TargetFixture -Name 'version create'
        $versionCreateFixture.State.CreateIndexes = @('5')
        $versionCreateFixture.State.CreateAndroid = ' '
        $versionCreateJournal = New-TargetJournal -Instance $versionCreateFixture.Install
        $versionCreate = New-MuMuInstance -ManagerPath $versionCreateFixture.Install.ManagerPath -Install $versionCreateFixture.Install -Journal $versionCreateJournal -Confirmed -Runner (New-SafetyManagerRunner -State $versionCreateFixture.State)
        Assert-Equal 'CriticalError' $versionCreate.Status 'A create without a readable Android version was accepted.'
        Assert-True ($versionCreate.Message -match '(?i)android version') "An unreadable create version did not explain itself: $($versionCreate.Message)"

        $diskCreateFixture = New-TargetFixture -Name 'disk create'
        $diskCreateFixture.State.CreateIndexes = @('5')
        $diskCreateFixture.State.CreateCreatesDisk = $false
        $diskCreateJournal = New-TargetJournal -Instance $diskCreateFixture.Install
        $diskCreate = New-MuMuInstance -ManagerPath $diskCreateFixture.Install.ManagerPath -Install $diskCreateFixture.Install -Journal $diskCreateJournal -Confirmed -Runner (New-SafetyManagerRunner -State $diskCreateFixture.State)
        Assert-Equal 'CriticalError' $diskCreate.Status 'A create without a usable disk was accepted.'
        Assert-True ($diskCreate.Message -match '(?i)disk') "An unusable create disk did not explain itself: $($diskCreate.Message)"

        $rootCreateFixture = New-TargetFixture -Name 'root create'
        $rootCreateFixture.State.CreateIndexes = @('5')
        $rootCreateFixture.State.CreateCreatesRoot = $false
        $rootCreateJournal = New-TargetJournal -Instance $rootCreateFixture.Install
        $rootCreate = New-MuMuInstance -ManagerPath $rootCreateFixture.Install.ManagerPath -Install $rootCreateFixture.Install -Journal $rootCreateJournal -Confirmed -Runner (New-SafetyManagerRunner -State $rootCreateFixture.State)
        Assert-Equal 'CriticalError' $rootCreate.Status 'A create without an instance root was accepted.'

        $outsideVmsFixture = New-TargetFixture -Name 'outside vms create'
        $outsideVmsFixture.State.CreateIndexes = @('5')
        $outsideVmsFixture.State.CreateVmsPath = (Join-Path $testRoot 'target fixtures\MuMu Global\elsewhere\vms')
        [void][IO.Directory]::CreateDirectory($outsideVmsFixture.State.CreateVmsPath)
        $outsideVmsJournal = New-TargetJournal -Instance $outsideVmsFixture.Install
        $outsideVms = New-MuMuInstance -ManagerPath $outsideVmsFixture.Install.ManagerPath -Install $outsideVmsFixture.Install -Journal $outsideVmsJournal -Confirmed -Runner (New-SafetyManagerRunner -State $outsideVmsFixture.State)
        Assert-Equal 'CriticalError' $outsideVms.Status 'A create outside the selected installation instance root was accepted.'

        $cloneFixture = New-TargetFixture -Name 'clone' -Running
        $cloneState = $cloneFixture.State
        $cloneSnapshotBefore = New-MenuSnapshot -Root $cloneFixture.Install.VmsPath
        $unconfirmedCloneJournal = New-TargetJournal -Instance $cloneFixture.Install
        $unconfirmedClone = Select-ToolkitTarget -Install $cloneFixture.Install -Journal $unconfirmedCloneJournal -Mode Clone -SourceIndex 3 -Runner (New-SafetyManagerRunner -State $cloneState)
        Assert-Equal 'CriticalError' $unconfirmedClone.Status 'An unconfirmed clone target mode was accepted.'
        Assert-Equal 0 $cloneState.Calls.Count 'An unconfirmed clone target mode reached the manager.'
        $cloneJournal = New-TargetJournal -Instance $cloneFixture.Install
        $clone = Select-ToolkitTarget -Install $cloneFixture.Install -Journal $cloneJournal -Mode Clone -SourceIndex 3 -Confirmed -Runner (New-SafetyManagerRunner -State $cloneState)
        Assert-Equal 'Success' $clone.Status "A confirmed clone target mode failed: $($clone.Message)"
        Assert-Equal 'Clone' $clone.Data.Mode 'The clone target mode did not report its mode.'
        Assert-Equal 4 $clone.Data.Index 'The clone target mode did not report the clone index.'
        Assert-Equal 'Target clone' $clone.Data.Name 'The clone target mode did not report the clone name.'
        Assert-Equal 3 $clone.Data.SourceIndex 'The clone target mode did not report its source index.'
        Assert-Equal 'Global' $clone.Data.Edition 'The clone target mode did not report the installation edition.'
        Assert-Equal 'Running' $cloneJournal.State 'A confirmed clone target mode did not leave its journal open for the caller to close.'
        $cloneCommands = @(Get-TargetManagerCommands -State $cloneState)
        Assert-Equal 1 @($cloneCommands | Where-Object { $_ -ceq 'clone|-v|3|-n|1' }).Count "The clone target mode issued an unexpected clone command: $($cloneCommands -join '|')"
        Assert-Equal 1 @($cloneCommands | Where-Object { $_ -ceq 'control|-v|3|shutdown' }).Count "The clone target mode issued an unexpected control command: $($cloneCommands -join '|')"
        Assert-TargetManagerCommands -State $cloneState -AllowedVerbs @('info', 'setting', 'control', 'clone') -Message 'The clone target mode'
        $cloneSourceDelta = @(Get-TargetSourceInstanceDelta -Before $cloneSnapshotBefore -After (New-MenuSnapshot -Root $cloneFixture.Install.VmsPath) -InstanceIndexes @(0, 2, 3))
        Assert-Equal 0 $cloneSourceDelta.Count "The clone target mode changed the source instance: $($cloneSourceDelta -join '|')"

        $missingSourceFixture = New-TargetFixture -Name 'clone missing source'
        $missingSourceJournal = New-TargetJournal -Instance $missingSourceFixture.Install
        $missingSource = Select-ToolkitTarget -Install $missingSourceFixture.Install -Journal $missingSourceJournal -Mode Clone -SourceIndex 9 -Confirmed -Runner (New-SafetyManagerRunner -State $missingSourceFixture.State)
        Assert-Equal 'CriticalError' $missingSource.Status 'A clone of an undiscovered source instance was accepted.'
        Assert-TargetManagerCommands -State $missingSourceFixture.State -AllowedVerbs @('info', 'setting') -Message 'A clone of an undiscovered source instance'
        Assert-Equal 0 @(@(Get-TargetManagerCommands -State $missingSourceFixture.State) | Where-Object { $_ -like 'clone|*' }).Count 'A clone of an undiscovered source instance reached the manager clone command.'
        $sourceLessFixture = New-TargetFixture -Name 'clone without source'
        $sourceLessJournal = New-TargetJournal -Instance $sourceLessFixture.Install
        $sourceLess = Select-ToolkitTarget -Install $sourceLessFixture.Install -Journal $sourceLessJournal -Mode Clone -Confirmed -Runner (New-SafetyManagerRunner -State $sourceLessFixture.State)
        Assert-Equal 'CriticalError' $sourceLess.Status 'A clone without a source instance index was accepted.'
        Assert-True ($sourceLess.Message -match '(?i)explicit clone source') "A clone without a source index did not explain itself: $($sourceLess.Message)"
        Assert-Equal 0 @(@(Get-TargetManagerCommands -State $sourceLessFixture.State) | Where-Object { $_ -like 'clone|*' }).Count 'A clone without a source instance index reached the manager clone command.'
        $sourceLessPromptedJournal = New-TargetJournal -Instance $sourceLessFixture.Install
        $sourceLessPrompted = Select-ToolkitTarget -Install $sourceLessFixture.Install -Journal $sourceLessPromptedJournal -Mode Clone -Prompt ({ '2' }).GetNewClosure() -Confirmed -Runner (New-SafetyManagerRunner -State $sourceLessFixture.State)
        Assert-Equal 'Success' $sourceLessPrompted.Status "A prompted clone source selection failed: $($sourceLessPrompted.Message)"
        Assert-Equal 3 $sourceLessPrompted.Data.SourceIndex 'A prompted clone source selection chose the wrong source instance.'

        $baseSourceFixture = New-TargetFixture -Name 'clone base source'
        $baseSourceJournal = New-TargetJournal -Instance $baseSourceFixture.Install
        $baseSource = Select-ToolkitTarget -Install $baseSourceFixture.Install -Journal $baseSourceJournal -Mode Clone -SourceIndex 0 -Confirmed -Runner (New-SafetyManagerRunner -State $baseSourceFixture.State)
        Assert-Equal 'CriticalError' $baseSource.Status 'A base instance was accepted as a clone source.'
        Assert-Equal 0 @(@(Get-TargetManagerCommands -State $baseSourceFixture.State) | Where-Object { $_ -notmatch '^(info|setting)\|' }).Count 'A base clone source reached a mutating manager command.'

        $oldSourceFixture = New-TargetFixture -Name 'clone old source'
        foreach ($oldSourceInstance in @($oldSourceFixture.State.Instances)) {
            if ([int]$oldSourceInstance.Index -eq 3) {
                $oldSourceInstance.Android = '11.0'
            }
        }
        $oldSourceJournal = New-TargetJournal -Instance $oldSourceFixture.Install
        $oldSource = Select-ToolkitTarget -Install $oldSourceFixture.Install -Journal $oldSourceJournal -Mode Clone -SourceIndex 3 -Confirmed -Runner (New-SafetyManagerRunner -State $oldSourceFixture.State)
        Assert-Equal 'CriticalError' $oldSource.Status 'An unsupported Android version was accepted as a clone source.'
        Assert-Equal 0 @(@(Get-TargetManagerCommands -State $oldSourceFixture.State) | Where-Object { $_ -notmatch '^(info|setting)\|' }).Count 'An unsupported clone source reached a mutating manager command.'

        $defaultSourceFixture = New-TargetFixture -Name 'clone default source'
        $defaultSourceJournal = New-TargetJournal -Instance $defaultSourceFixture.Install
        $defaultSource = Select-ToolkitTarget -Install $defaultSourceFixture.Install -Journal $defaultSourceJournal -Mode Clone -InstanceIndex 3 -Confirmed -Runner (New-SafetyManagerRunner -State $defaultSourceFixture.State)
        Assert-Equal 'Success' $defaultSource.Status "A clone of the selected instance failed: $($defaultSource.Message)"
        Assert-Equal 3 $defaultSource.Data.SourceIndex 'A clone of the selected instance did not use the selected index as its source.'
        $invalidInstall = Select-ToolkitTarget -Install $null -Journal (New-TargetJournal -Instance $defaultSourceFixture.Install) -Mode Clone -Confirmed -Runner (New-SafetyManagerRunner -State $defaultSourceFixture.State)
        Assert-Equal 'CriticalError' $invalidInstall.Status 'A clone with an invalid install was accepted.'

        $controllerIdentify = New-TargetFixture -Name 'controller identify'
        $controllerCreate = New-TargetFixture -Name 'controller create'
        $controllerCreate.State.CreateIndexes = @('5')
        $controllerCreatePrompted = New-TargetFixture -Name 'controller create prompted'
        $controllerCreatePrompted.State.CreateIndexes = @('5')
        $controllerCreateExplicit = New-TargetFixture -Name 'controller create explicit'
        $controllerCreateExplicit.State.CreateIndexes = @('5')
        $controllerClone = New-TargetFixture -Name 'controller clone' -Running
        $controllerClonePrompted = New-TargetFixture -Name 'controller clone prompted' -Running
        $controllerCloneExplicit = New-TargetFixture -Name 'controller clone explicit' -Running
        $script:TargetFallbackRoots = @(
            $controllerIdentify.Install.InstallRoot
            $controllerCreate.Install.InstallRoot
            $controllerCreatePrompted.Install.InstallRoot
            $controllerCreateExplicit.Install.InstallRoot
            $controllerClone.Install.InstallRoot
            $controllerClonePrompted.Install.InstallRoot
            $controllerCloneExplicit.Install.InstallRoot
        )
        function Get-ToolkitDiscoverySources {
            return @{
                RegistryRoots = @('FixtureRegistry:\Target')
                ProcessSnapshot = @()
                FallbackRoots = @($script:TargetFallbackRoots)
            }
        }
        function Get-ToolkitUninstallEntries {
            param([string]$Root)

            return @()
        }

        $controllerStateRoot = Join-Path $testRoot 'target controller state'
        [void][IO.Directory]::CreateDirectory($controllerStateRoot)
        $absentInstallRoot = Join-Path $testRoot 'target fixtures\MuMu Global\absent install'

        $earlyMode = Invoke-ToolkitAction -Action 'Target' -InstallRoot $absentInstallRoot -StateRoot $controllerStateRoot -Mode 'Bogus'
        Assert-Equal 'TARGET_MODE_INVALID' $earlyMode.Data.Code 'An unsupported mode was not rejected before installation discovery.'
        Assert-True ($earlyMode.Message -notmatch 'installation was not discovered') 'The unsupported mode was rejected after installation discovery.'
        $earlyMisuse = Invoke-ToolkitAction -Action 'Detect' -InstallRoot $absentInstallRoot -StateRoot $controllerStateRoot -Mode 'Identify'
        Assert-Equal 'TARGET_PARAMETER_MISUSE' $earlyMisuse.Data.Code 'A target parameter on another action was not rejected before installation discovery.'
        $earlyStartIndex = Invoke-ToolkitAction -Action 'Target' -InstallRoot $absentInstallRoot -StateRoot $controllerStateRoot -Mode 'Create'
        Assert-Equal 'TARGET_START_INDEX_REQUIRED' $earlyStartIndex.Data.Code 'A noninteractive create without a start index was not rejected before installation discovery.'
        $earlyBlankStartIndex = Invoke-ToolkitAction -Action 'Target' -InstallRoot $absentInstallRoot -StateRoot $controllerStateRoot -Mode 'Create' -StartIndex '  '
        Assert-Equal 'TARGET_START_INDEX_REQUIRED' $earlyBlankStartIndex.Data.Code 'A noninteractive create with a blank start index was not rejected before installation discovery.'
        Assert-Equal 0 @(@(Get-ToolkitJournalRecords -StateRoot $controllerStateRoot)).Count 'A refused target parameter created an operation journal.'

        $missingMode = Invoke-ToolkitAction -Action 'Target' -InstallRoot $controllerIdentify.Install.InstallRoot -StateRoot $controllerStateRoot
        Assert-Equal 'CriticalError' $missingMode.Status 'A noninteractive target run without an explicit mode was accepted.'
        Assert-Equal 'TARGET_MODE_REQUIRED' $missingMode.Data.Code 'A noninteractive target run without an explicit mode did not report the missing mode.'
        Assert-Equal 0 @(Get-TargetMutatingCommands -State $controllerIdentify.State).Count "A target run without a mode reached a mutating manager command: $(@(Get-TargetManagerCommands -State $controllerIdentify.State) -join '|')"

        $invalidControllerMode = Invoke-ToolkitAction -Action 'Target' -InstallRoot $controllerIdentify.Install.InstallRoot -StateRoot $controllerStateRoot -Mode 'Bogus'
        Assert-Equal 'CriticalError' $invalidControllerMode.Status 'A target run with an unsupported mode was accepted.'
        Assert-Equal 'TARGET_MODE_INVALID' $invalidControllerMode.Data.Code 'A target run with an unsupported mode did not report the invalid mode.'
        Assert-Equal 0 @(Get-TargetMutatingCommands -State $controllerIdentify.State).Count 'A target run with an unsupported mode reached a mutating manager command.'

        $modeMisuse = Invoke-ToolkitAction -Action 'Detect' -InstallRoot $controllerIdentify.Install.InstallRoot -StateRoot $controllerStateRoot -Mode 'Identify'
        Assert-Equal 'CriticalError' $modeMisuse.Status 'A target parameter was accepted by another action.'
        Assert-Equal 'TARGET_PARAMETER_MISUSE' $modeMisuse.Data.Code 'A target parameter on another action did not report the misuse code.'
        $misuseFixture = New-TargetFixture -Name 'parameter misuse'
        $script:TargetFallbackRoots = @($script:TargetFallbackRoots) + @($misuseFixture.Install.InstallRoot)
        $misuseStateRoot = Join-Path $testRoot 'target misuse state'
        $sourceIndexMisuse = Invoke-ToolkitAction -Action 'Detect' -InstallRoot $misuseFixture.Install.InstallRoot -StateRoot $misuseStateRoot -SourceIndex 2 -Runner (New-SafetyManagerRunner -State $misuseFixture.State)
        Assert-Equal 'CriticalError' $sourceIndexMisuse.Status 'A target source parameter was accepted by another action.'
        Assert-Equal 'TARGET_PARAMETER_MISUSE' $sourceIndexMisuse.Data.Code 'A target source parameter on another action did not report the misuse code.'
        Assert-True ($sourceIndexMisuse.Message -match '-SourceIndex') "A target source parameter refusal does not name the parameter: $($sourceIndexMisuse.Message)"
        Assert-Equal 0 $misuseFixture.State.Calls.Count "A non-target action with a target source parameter reached the manager: $(@(Get-TargetManagerCommands -State $misuseFixture.State) -join '|')"
        Assert-True (-not (Test-Path -LiteralPath $misuseStateRoot)) 'A refused target parameter created the toolkit state directory.'
        $misuseJournalCount = @(Get-ToolkitJournalRecords -StateRoot $controllerStateRoot).Count
        $startIndexMisuse = Invoke-ToolkitAction -Action 'Verify' -InstallRoot $controllerIdentify.Install.InstallRoot -StateRoot $controllerStateRoot -StartIndex 5 -Runner (New-SafetyManagerRunner -State $controllerIdentify.State)
        Assert-Equal 'TARGET_PARAMETER_MISUSE' $startIndexMisuse.Data.Code 'A target start index on another action did not report the misuse code.'
        Assert-Equal $misuseJournalCount @(Get-ToolkitJournalRecords -StateRoot $controllerStateRoot).Count 'A refused target parameter wrote an operation journal.'
        $directTarget = Invoke-ToolkitTarget -Install $controllerCreate.Install -StateRoot $controllerStateRoot -Mode 'Create'
        Assert-Equal 'CriticalError' $directTarget.Status 'A direct target call without a prompt and without a start index was accepted.'
        Assert-Equal 'TARGET_START_INDEX_REQUIRED' $directTarget.Data.Code 'A direct target call without a prompt did not report the structured start index refusal.'
        Assert-True ($null -ne $directTarget.PSObject.Properties['Message']) 'A direct target call returned no structured result.'
        $directPaddedTarget = Invoke-ToolkitTarget -Install $controllerCreate.Install -StateRoot $controllerStateRoot -Mode ' Create '
        Assert-Equal 'CriticalError' $directPaddedTarget.Status 'A direct target call with a padded mode was accepted.'
        Assert-Equal 'TARGET_START_INDEX_REQUIRED' $directPaddedTarget.Data.Code 'A direct target call with a padded mode did not normalize the mode.'
        $directNoMode = Invoke-ToolkitTarget -Install $controllerCreate.Install -StateRoot $controllerStateRoot
        Assert-Equal 'TARGET_MODE_REQUIRED' $directNoMode.Data.Code 'A direct target call without a mode did not report the missing mode.'

        $identifyAction = Invoke-ToolkitAction -Action 'Target' -InstallRoot $controllerIdentify.Install.InstallRoot -InstanceIndex 2 -StateRoot $controllerStateRoot -Mode 'Identify' -Runner (New-SafetyManagerRunner -State $controllerIdentify.State)
        Assert-Equal 'Success' $identifyAction.Status "The Target action failed: $($identifyAction.Message)"
        Assert-Equal 'Identify' $identifyAction.Data.Mode 'The Target action did not report its mode.'
        Assert-Equal 2 $identifyAction.Data.Index 'The Target action did not report the target index.'
        Assert-Equal 'Other' $identifyAction.Data.Name 'The Target action did not report the target name.'
        Assert-Equal 'Global' $identifyAction.Data.Edition 'The Target action did not report the installation edition.'
        Assert-Equal '12.0' $identifyAction.Data.AndroidVersion 'The Target action did not report the Android version.'
        Assert-True ((@(Format-ToolkitResult -Result $identifyAction) -join "`n") -match 'Instance 3 \| Target') 'The controller Target result did not render every discovered instance.'
        Assert-Equal 0 @(Get-TargetMutatingCommands -State $controllerIdentify.State).Count "The controller Identify target mode issued a mutating manager command: $(@(Get-TargetManagerCommands -State $controllerIdentify.State) -join '|')"
        Assert-Equal 1 @(Get-ToolkitJournalRecords -StateRoot $controllerStateRoot | Where-Object { [string]$_.Operation -ceq 'Target' -and [string]$_.State -ceq 'Completed' }).Count 'The Target action did not keep exactly one completed target journal.'

        $targetSourceAccepted = Invoke-ToolkitAction -Action 'Target' -InstallRoot $misuseFixture.Install.InstallRoot -StateRoot $controllerStateRoot -Mode 'Clone' -SourceIndex 3 -Confirmed -Runner (New-SafetyManagerRunner -State $misuseFixture.State)
        Assert-Equal 'Success' $targetSourceAccepted.Status "A target source parameter was refused for the Target action: $($targetSourceAccepted.Message)"
        Assert-Equal 3 $targetSourceAccepted.Data.SourceIndex 'The Target action did not use the supplied source index.'
        Assert-Equal 1 @(@(Get-TargetManagerCommands -State $misuseFixture.State) | Where-Object { $_ -eq 'clone|-v|3|-n|1' }).Count "A target source parameter did not reach the manager clone command: $(@(Get-TargetManagerCommands -State $misuseFixture.State) -join '|')"

        $nonInteractiveStartIndex = Invoke-MenuAction -Action 'Target' -InstallRoot $absentInstallRoot -StateRoot $controllerStateRoot -Mode 'Create' -LogPath (Join-Path $controllerStateRoot 'target.log')
        Assert-Equal 'TARGET_START_INDEX_REQUIRED' $nonInteractiveStartIndex.Data.Code 'A noninteractive create target run without a start index was accepted.'
        $nonInteractiveCreate = Invoke-ToolkitAction -Action 'Target' -InstallRoot $controllerCreate.Install.InstallRoot -StateRoot $controllerStateRoot -Mode 'Create' -StartIndex '5' -Runner (New-SafetyManagerRunner -State $controllerCreate.State)
        Assert-Equal 'CriticalError' $nonInteractiveCreate.Status 'A noninteractive create target run without a confirmation was accepted.'
        Assert-True ($nonInteractiveCreate.Message -match '(?i)confirm') 'A noninteractive create target run without a confirmation did not report the missing confirmation.'
        Assert-Equal 0 @(Get-TargetMutatingCommands -State $controllerCreate.State).Count "A refused noninteractive controller create reached a mutating manager command: $(@(Get-TargetManagerCommands -State $controllerCreate.State) -join '|')"
        $nonInteractiveClone = Invoke-ToolkitAction -Action 'Target' -InstallRoot $controllerClone.Install.InstallRoot -StateRoot $controllerStateRoot -Mode 'Clone' -SourceIndex 3 -Runner (New-SafetyManagerRunner -State $controllerClone.State)
        Assert-Equal 'CriticalError' $nonInteractiveClone.Status 'A noninteractive clone target run without a confirmation was accepted.'
        Assert-Equal 0 @(Get-TargetMutatingCommands -State $controllerClone.State).Count "A refused noninteractive controller clone reached a mutating manager command: $(@(Get-TargetManagerCommands -State $controllerClone.State) -join '|')"
        $nonInteractiveCloneSource = Invoke-ToolkitAction -Action 'Target' -InstallRoot $controllerClone.Install.InstallRoot -StateRoot $controllerStateRoot -Mode 'Clone' -Confirmed -Runner (New-SafetyManagerRunner -State $controllerClone.State)
        Assert-Equal 'CriticalError' $nonInteractiveCloneSource.Status 'A noninteractive clone target run without an explicit source was accepted.'
        Assert-Equal 0 @(Get-TargetMutatingCommands -State $controllerClone.State).Count 'A noninteractive clone without a source reached a mutating manager command.'

        $controllerCreateCalls = @($controllerCreate.State.Calls).Count
        $confirmedCreate = Invoke-ToolkitAction -Action 'Target' -InstallRoot $controllerCreate.Install.InstallRoot -StateRoot $controllerStateRoot -Mode 'Create' -StartIndex '5' -Confirmed -Runner (New-SafetyManagerRunner -State $controllerCreate.State)
        Assert-Equal 'Success' $confirmedCreate.Status "A confirmed controller create target run failed: $($confirmedCreate.Message)"
        Assert-Equal 'Create' $confirmedCreate.Data.Mode 'A confirmed controller create target run did not report its mode.'
        Assert-Equal 5 $confirmedCreate.Data.Index 'A confirmed controller create target run did not report the created index.'
        Assert-True ([long]$confirmedCreate.Data.DiskBytes -gt 0) 'A confirmed controller create target run reported no usable disk.'
        $controllerCreateCommands = @(Get-TargetManagerCommands -State $controllerCreate.State)
        Assert-Equal 1 @($controllerCreateCommands | Where-Object { $_ -ceq 'create|-n|1' }).Count "A confirmed controller create target run issued an unexpected create command: $($controllerCreateCommands -join '|')"
        Assert-Equal 2 @($controllerCreateCommands | Where-Object { $_ -ceq 'info|-v|all' }).Count "A confirmed controller create target run did not enumerate exactly twice: $($controllerCreateCommands -join '|')"
        Assert-TargetManagerCommands -State $controllerCreate.State -AllowedVerbs @('info', 'setting', 'create') -Message 'A confirmed controller create target run'
        Assert-True ((@($controllerCreate.State.Calls).Count) -gt $controllerCreateCalls) 'A confirmed controller create target run issued no manager request.'

        $controllerCloneCommands = @(Get-TargetManagerCommands -State $controllerClone.State)
        $confirmedClone = Invoke-ToolkitAction -Action 'Target' -InstallRoot $controllerClone.Install.InstallRoot -StateRoot $controllerStateRoot -Mode 'Clone' -SourceIndex 3 -Confirmed -Runner (New-SafetyManagerRunner -State $controllerClone.State)
        Assert-Equal 'Success' $confirmedClone.Status "A confirmed controller clone target run failed: $($confirmedClone.Message)"
        Assert-Equal 'Clone' $confirmedClone.Data.Mode 'A confirmed controller clone target run did not report its mode.'
        Assert-Equal 3 $confirmedClone.Data.SourceIndex 'A confirmed controller clone target run did not select the requested source instance.'
        Assert-Equal 4 $confirmedClone.Data.Index 'A confirmed controller clone target run did not report the clone index.'
        $controllerCloneCommands = @(Get-TargetManagerCommands -State $controllerClone.State)
        Assert-Equal 1 @($controllerCloneCommands | Where-Object { $_ -ceq 'clone|-v|3|-n|1' }).Count "A confirmed controller clone target run issued an unexpected clone command: $($controllerCloneCommands -join '|')"
        Assert-Equal 1 @($controllerCloneCommands | Where-Object { $_ -ceq 'control|-v|3|shutdown' }).Count "A confirmed controller clone target run issued an unexpected control command: $($controllerCloneCommands -join '|')"
        Assert-TargetManagerCommands -State $controllerClone.State -AllowedVerbs @('info', 'setting', 'control', 'clone') -Message 'A confirmed controller clone target run'

        $targetPromptState = @{ Questions = @(); Answers = @() }
        $targetPrompt = {
            param($Question)
            $targetPromptState.Questions += [string]$Question
            if ($targetPromptState.Answers.Count -eq 0) {
                return ''
            }
            $answer = $targetPromptState.Answers[0]
            $targetPromptState.Answers = @(@($targetPromptState.Answers) | Select-Object -Skip 1)
            return $answer
        }.GetNewClosure()

        $targetPromptState.Questions = @()
        $targetPromptState.Answers = @('Bogus')
        $promptedInvalidMode = Invoke-ToolkitAction -Action 'Target' -InstallRoot $controllerIdentify.Install.InstallRoot -StateRoot $controllerStateRoot -Prompt $targetPrompt -Runner (New-SafetyManagerRunner -State $controllerIdentify.State)
        Assert-Equal 'CriticalError' $promptedInvalidMode.Status 'A prompted target run with an unsupported answer was accepted.'
        Assert-True ((@($targetPromptState.Questions) -join '|') -match 'Identify, Create, or Clone') 'The target action did not ask for a mode.'
        Assert-True ((@($targetPromptState.Questions) -join '|') -notmatch 'CONFIRM') 'An unsupported prompted mode asked for a mutation confirmation.'

        $targetPromptState.Questions = @()
        $targetPromptState.Answers = @('Identify', '1')
        $promptedIdentify = Invoke-ToolkitAction -Action 'Target' -InstallRoot $controllerIdentify.Install.InstallRoot -StateRoot $controllerStateRoot -Prompt $targetPrompt -Runner (New-SafetyManagerRunner -State $controllerIdentify.State)
        Assert-Equal 'Success' $promptedIdentify.Status "A prompted Identify target run failed: $($promptedIdentify.Message)"
        Assert-Equal 2 $promptedIdentify.Data.Index 'A prompted Identify target run chose the wrong instance.'
        Assert-True ((@($targetPromptState.Questions) -join '|') -match 'Select the target MuMu instance') 'The Identify target mode did not ask for a target instance.'
        Assert-True ((@($targetPromptState.Questions) -join '|') -notmatch 'CONFIRM') 'A prompted Identify target run asked for a mutation confirmation.'

        $targetPromptState.Questions = @()
        $targetPromptState.Answers = @('Create', '7', 'no')
        $createMutationsBefore = @(Get-TargetMutatingCommands -State $controllerCreate.State).Count
        $refusedCreate = Invoke-ToolkitAction -Action 'Target' -InstallRoot $controllerCreate.Install.InstallRoot -StateRoot $controllerStateRoot -Prompt $targetPrompt -Runner (New-SafetyManagerRunner -State $controllerCreate.State)
        Assert-Equal 'CriticalError' $refusedCreate.Status 'A refused create target run was accepted.'
        Assert-True ((@($targetPromptState.Questions) -join '|') -match 'Free instance index') 'The create target mode did not ask for the new instance index.'
        Assert-True ((@($targetPromptState.Questions) -join '|') -match 'CONFIRM') 'The create target mode did not ask for an explicit confirmation.'
        Assert-Equal $createMutationsBefore @(Get-TargetMutatingCommands -State $controllerCreate.State).Count 'A refused create target run reached a mutating manager command.'

        $targetPromptState.Questions = @()
        $targetPromptState.Answers = @('Create', 'blank')
        $createMutationsBefore = @(Get-TargetMutatingCommands -State $controllerCreate.State).Count
        $blankIndexCreate = Invoke-ToolkitAction -Action 'Target' -InstallRoot $controllerCreate.Install.InstallRoot -StateRoot $controllerStateRoot -Prompt $targetPrompt -Runner (New-SafetyManagerRunner -State $controllerCreate.State)
        Assert-Equal 'TARGET_START_INDEX_INVALID' $blankIndexCreate.Data.Code 'A prompted create with a blank free instance index was accepted.'
        Assert-True ((@($targetPromptState.Questions) -join '|') -notmatch 'CONFIRM') 'A blank free instance index asked for a mutation confirmation.'
        Assert-Equal $createMutationsBefore @(Get-TargetMutatingCommands -State $controllerCreate.State).Count 'A blank free instance index reached a mutating manager command.'

        $targetPromptState.Questions = @()
        $targetPromptState.Answers = @('Create', '6', 'CONFIRM')
        $confirmedPromptedCreate = Invoke-ToolkitAction -Action 'Target' -InstallRoot $controllerCreatePrompted.Install.InstallRoot -StateRoot $controllerStateRoot -Prompt $targetPrompt -Runner (New-SafetyManagerRunner -State $controllerCreatePrompted.State)
        Assert-Equal 'Success' $confirmedPromptedCreate.Status "A prompted confirmed create target run failed: $($confirmedPromptedCreate.Message)"
        Assert-Equal 6 $confirmedPromptedCreate.Data.RequestedIndex 'A prompted confirmed create did not pass the answered free instance index.'

        $targetPromptState.Questions = @()
        $targetPromptState.Answers = @('CONFIRM')
        $explicitIndexCreate = Invoke-ToolkitAction -Action 'Target' -InstallRoot $controllerCreateExplicit.Install.InstallRoot -StateRoot $controllerStateRoot -Mode 'Create' -StartIndex '8' -Prompt $targetPrompt -Runner (New-SafetyManagerRunner -State $controllerCreateExplicit.State)
        Assert-Equal 'Success' $explicitIndexCreate.Status "A create target run with an explicit start index failed: $($explicitIndexCreate.Message)"
        Assert-Equal 8 $explicitIndexCreate.Data.RequestedIndex 'A create target run with an explicit start index did not pass it through.'
        Assert-True ((@($targetPromptState.Questions) -join '|') -notmatch 'Free instance index') 'A create target run asked for a start index that was supplied as a parameter.'

        $targetPromptState.Questions = @()
        $targetPromptState.Answers = @('Clone', '9')
        $cloneMutationsBefore = @(Get-TargetMutatingCommands -State $controllerClone.State).Count
        $refusedCloneSource = Invoke-ToolkitAction -Action 'Target' -InstallRoot $controllerClone.Install.InstallRoot -StateRoot $controllerStateRoot -Prompt $targetPrompt -Runner (New-SafetyManagerRunner -State $controllerClone.State)
        Assert-Equal 'CriticalError' $refusedCloneSource.Status 'A prompted clone with an invalid source was accepted.'
        Assert-True ((@($targetPromptState.Questions) -join '|') -match 'clone source MuMu instance') 'The clone target mode did not ask for a source instance.'
        Assert-True ((@($targetPromptState.Questions) -join '|') -notmatch 'CONFIRM') 'An invalid prompted clone source asked for a mutation confirmation.'
        Assert-Equal $cloneMutationsBefore @(Get-TargetMutatingCommands -State $controllerClone.State).Count 'A prompted clone with an invalid source reached a mutating manager command.'

        $targetPromptState.Questions = @()
        $targetPromptState.Answers = @('Clone', '2', 'no')
        $cloneMutationsBefore = @(Get-TargetMutatingCommands -State $controllerClone.State).Count
        $refusedClone = Invoke-ToolkitAction -Action 'Target' -InstallRoot $controllerClone.Install.InstallRoot -StateRoot $controllerStateRoot -Prompt $targetPrompt -Runner (New-SafetyManagerRunner -State $controllerClone.State)
        Assert-Equal 'CriticalError' $refusedClone.Status 'A declined clone confirmation was accepted.'
        Assert-True ((@($targetPromptState.Questions) -join '|') -match 'CONFIRM') 'The declined clone did not ask for a confirmation.'
        Assert-Equal $cloneMutationsBefore @(Get-TargetMutatingCommands -State $controllerClone.State).Count 'A declined clone confirmation reached a mutating manager command.'

        $targetPromptState.Questions = @()
        $targetPromptState.Answers = @('Clone', '2', 'CONFIRM')
        $confirmedPromptedClone = Invoke-ToolkitAction -Action 'Target' -InstallRoot $controllerClonePrompted.Install.InstallRoot -StateRoot $controllerStateRoot -Prompt $targetPrompt -Runner (New-SafetyManagerRunner -State $controllerClonePrompted.State)
        Assert-Equal 'Success' $confirmedPromptedClone.Status "A prompted confirmed clone target run failed: $($confirmedPromptedClone.Message)"
        Assert-Equal 3 $confirmedPromptedClone.Data.SourceIndex 'A prompted confirmed clone did not use the answered source instance.'
        Assert-True (@(@(Get-TargetManagerCommands -State $controllerClonePrompted.State) | Where-Object { $_ -eq 'clone|-v|3|-n|1' }).Count -ge 1) 'A prompted confirmed clone did not reach the manager clone command.'

        $targetPromptState.Questions = @()
        $targetPromptState.Answers = @('CONFIRM')
        $explicitSourceClone = Invoke-ToolkitAction -Action 'Target' -InstallRoot $controllerCloneExplicit.Install.InstallRoot -StateRoot $controllerStateRoot -Mode 'Clone' -SourceIndex 3 -Prompt $targetPrompt -Runner (New-SafetyManagerRunner -State $controllerCloneExplicit.State)
        Assert-Equal 'Success' $explicitSourceClone.Status "A clone target run with an explicit source index failed: $($explicitSourceClone.Message)"
        Assert-Equal 3 $explicitSourceClone.Data.SourceIndex 'A clone target run with an explicit source index did not use it.'
        Assert-True ((@($targetPromptState.Questions) -join '|') -notmatch 'clone source MuMu instance') 'A clone target run asked for a source that was supplied as a parameter.'

        $controllerCatalog = @(Get-ToolkitActionCatalog | ForEach-Object { [string]$_.Name })
        Assert-True ($controllerCatalog -ccontains 'Target') 'The action catalog does not offer the Target action.'
        Assert-True ([int](@($controllerCatalog).IndexOf('Target')) -lt [int](@($controllerCatalog).IndexOf('Root12'))) 'The Target action is not offered before the root actions.'
        Assert-True ([int](@($controllerCatalog).IndexOf('Target')) -gt [int](@($controllerCatalog).IndexOf('Verify'))) 'The Target action is not offered after the read-only report.'
    }
    finally {
        $env:APPDATA = $targetAppData
        $script:TargetFallbackRoots = @()
    }
}

function Invoke-DocsTests {
    $readmePath = Join-Path $repoRoot 'README.md'
    $noticePath = Join-Path $repoRoot 'NOTICE.md'
    $licensePath = Join-Path $repoRoot 'LICENSE'
    $workflowPath = Join-Path $repoRoot '.github\workflows\test.yml'
    $gitignorePath = Join-Path $repoRoot '.gitignore'
    foreach ($requiredPath in @($readmePath, $noticePath, $licensePath, $workflowPath, $gitignorePath)) {
        Assert-True (Test-Path -LiteralPath $requiredPath -PathType Leaf) "A required documentation or publishing file is missing: $requiredPath"
    }

    $readme = Get-Content -LiteralPath $readmePath -Raw
    $notice = Get-Content -LiteralPath $noticePath -Raw
    $license = Get-Content -LiteralPath $licensePath -Raw
    $workflow = Get-Content -LiteralPath $workflowPath -Raw
    $gitignore = Get-Content -LiteralPath $gitignorePath -Raw

    # The upstream release pages are derived from the pinned manifest so the documentation cannot drift from the pins.
    $manifest = Get-ToolkitManifest -Path $manifestPath
    foreach ($dependency in @($manifest.dependencies)) {
        $projectUrl = @(([string]$dependency.url -split '/releases/'))[0]
        $releasePage = $projectUrl + '/releases/tag/' + [string]$dependency.version
        Assert-True ($readme.Contains($releasePage)) "README does not link the pinned release page: $releasePage"
        Assert-True ($notice.Contains($projectUrl)) "NOTICE does not credit the upstream project: $projectUrl"
    }
    foreach ($mumuLink in @('https://www.mumuplayer.com/download/', 'https://www.mumuplayer.com/help/win/how-to-upgrade-mumuplayer.html')) {
        Assert-True ($readme.Contains($mumuLink)) "README is missing a tested reference link: $mumuLink"
    }
    Assert-True ($readme.Contains([string]$manifest.mumu.testedVersion)) "README does not state the tested MuMu version: $([string]$manifest.mumu.testedVersion)"
    Assert-True ($readme.Contains('https://github.com/JingMatrix/Vector/releases/tag/v2.2')) 'README does not link the canonical Vector release page that the manifest pins.'

    # The exact Kitsune phrase is taken from the product constant, not retyped here.
    $kitsuneChoice = [string]$script:ToolkitKitsuneChoice
    $kitsunePrompt = [string]$script:ToolkitKitsunePrompt
    Assert-True (-not [string]::IsNullOrWhiteSpace($kitsuneChoice)) 'The Kitsune system-partition choice constant is unavailable.'
    Assert-True ($kitsunePrompt.Contains($kitsuneChoice)) 'The Kitsune prompt constant does not carry the accepted choice.'
    Assert-True ($readme.Contains($kitsunePrompt)) "README lacks the exact Kitsune instruction from the product constant: $kitsunePrompt"
    Assert-True ($readme.Contains($kitsuneChoice)) "README lacks the exact Kitsune system-partition choice from the product constant: $kitsuneChoice"

    foreach ($statement in @(
            @{ Pattern = 'Global.*Chinese'; Message = 'README does not state the supported MuMu editions.' }
            @{ Pattern = 'Android 12'; Message = 'README does not state the Android 12 behavior.' }
            @{ Pattern = 'Android 15'; Message = 'README does not state the Android 15 behavior.' }
            @{ Pattern = '(?i)Setup order'; Message = 'README does not state the setup order.' }
            @{ Pattern = '(?i)Run as administrator'; Message = 'README does not state how the operator supplies administrator rights.' }
            @{ Pattern = '(?i)asks for administrator rights'; Message = 'README does not state that only a permission failure asks for administrator rights.' }
            @{ Pattern = '(?i)and only once'; Message = 'README does not state that elevation is asked for at most once.' }
            @{ Pattern = '-ElevatedChild'; Message = 'README does not state the internal switch that stops the elevated child from asking again.' }
            @{ Pattern = '(?i)inside this toolkit''s own `src` directory'; Message = 'README does not state the source-directory boundary the elevated child is held to.' }
            @{ Pattern = '(?i)never creates a scheduled task'; Message = 'README does not state that no scheduled task is created.' }
            @{ Pattern = '(?i)fails closed'; Message = 'README does not state the current fail-closed behavior.' }
            @{ Pattern = '(?i)creates and verifies a clone'; Message = 'README does not state the clone-first behavior.' }
            @{ Pattern = '(?i)Recovery'; Message = 'README does not state how to recover from an interrupted operation.' }
            @{ Pattern = '-Confirmed'; Message = 'README does not document the explicit Android 15 confirmation switch.' }
            @{ Pattern = 'CONFIRM'; Message = 'README does not document the interactive Android 15 confirmation word.' }
            @{ Pattern = '(?i)verified clone'; Message = 'README does not state that concealment requires a verified clone.' }
            @{ Pattern = '(?i)explicitly selected'; Message = 'README does not state the selected-app-only concealment scope.' }
            @{ Pattern = '(?i)-FetchDependencies'; Message = 'README does not document the explicit concealment dependency opt-in.' }
            @{ Pattern = '(?i)HMA and Vector'; Message = 'README does not state that concealment installs its declared dependencies.' }
            @{ Pattern = 'Concealment\.Code'; Message = 'The Verify report section does not name the concealment evidence code.' }
            @{ Pattern = 'Concealment\.InScope'; Message = 'The Verify report section does not name the concealment scope evidence.' }
            @{ Pattern = '(?i)KERNELSU_ABSENT'; Message = 'README does not state the honest concealment result on a Kitsune clone.' }
            @{ Pattern = '-Packages'; Message = 'README does not document the package selection parameter.' }
            @{ Pattern = 'campaign\.json'; Message = 'README does not state the advertisement scope.' }
            @{ Pattern = '(?i)AllowedRoot'; Message = 'README does not state the advertisement restore boundary.' }
            @{ Pattern = '-Action Restore'; Message = 'README does not document the advertisement restore command.' }
            @{ Pattern = '-NonInteractive'; Message = 'README does not document the noninteractive mode.' }
            @{ Pattern = '(?i)only .*with.*-NonInteractive|only .*together with.*-NonInteractive'; Message = 'README does not state that -Action is honored only together with -NonInteractive.' }
            @{ Pattern = '(?i)USER_CONFIRMATION_REQUIRED'; Message = 'README does not document the fail-closed code reported by a noninteractive Root12 run.' }
            @{ Pattern = '(?i)menu only|menu-only'; Message = 'README does not mark Root12 as a menu-only action.' }
            @{ Pattern = '(?i)creates the toolkit state directory|create the toolkit state directory'; Message = 'README does not state that the read-only actions still create local toolkit state.' }
            @{ Pattern = '(?i)Design intent'; Message = 'README does not mark the unelevated-phase download rule as design intent.' }
            @{ Pattern = '(?m)Success.*\b0\b'; Message = 'README does not map Success to exit code 0.' }
            @{ Pattern = '(?m)Warning.*\b0\b'; Message = 'README does not map Warning to exit code 0.' }
            @{ Pattern = '(?m)RecoverableError.*\b2\b'; Message = 'README does not map RecoverableError to exit code 2.' }
            @{ Pattern = '(?m)CriticalError.*\b1\b'; Message = 'README does not map CriticalError to exit code 1.' }
            @{ Pattern = '(?i)transport'; Message = 'README does not disclose the transport assumptions.' }
            @{ Pattern = '(?i)Play Integrity'; Message = 'README does not address Play Integrity.' }
            @{ Pattern = '(?i)no guarantee|does not guarantee'; Message = 'README does not disclaim any Play Integrity or attestation guarantee.' }
            @{ Pattern = '(?i)no binaries'; Message = 'README does not state that no binaries are bundled.' }
        )) {
        Assert-True ($readme -match $statement.Pattern) $statement.Message
    }

    # The live runs happened, so README must state what each one actually proved and forbid the old denial.
    Assert-True ($readme -notmatch '(?i)no live (qualification|run|test)') 'README still claims that no live qualification was performed, which is false.'
    foreach ($liveStatement in @(
            @{ Pattern = '(?is)Android 12.{0,200}?\bqualified\b'; Message = 'README does not state that Android 12 is qualified.' }
            @{ Pattern = '(?i)retained vendor root'; Message = 'README does not state that the Android 12 qualification retained the vendor root.' }
            @{ Pattern = '(?i)Chinese[- ]edition MuMu 6\.8\.0\.0'; Message = 'README does not scope the live results to the Chinese-edition MuMu 6.8.0.0 build.' }
            @{ Pattern = '(?is)Android 15.{0,200}?\bunqualified\b'; Message = 'README does not state that Android 15 is unqualified.' }
            @{ Pattern = '(?i)inherited.{0,80}Kitsune'; Message = 'README does not state that the Android 15 clone inherited Kitsune.' }
            @{ Pattern = '(?i)clone 5'; Message = 'README does not name the Android 15 clone index.' }
            @{ Pattern = '(?is)concealment.{0,200}?\bunqualified\b'; Message = 'README does not state that concealment is unqualified.' }
            @{ Pattern = 'jp\.pokemon\.pokemontcgp'; Message = 'README does not name the concealment target package.' }
            @{ Pattern = '(?i)clone 4'; Message = 'README does not name the concealment clone index.' }
            @{ Pattern = '(?is)RemoveAds.{0,200}?\bno-op\b'; Message = 'README does not state that RemoveAds was a no-op on this host.' }
            @{ Pattern = '(?i)no campaign file'; Message = 'README does not state that no campaign file exists on this host.' }
            @{ Pattern = 'zygisk_vector'; Message = 'README does not record the installed Vector module id.' }
            @{ Pattern = '31\.0-kitsune'; Message = 'README does not record the observed Kitsune app version.' }
            @{ Pattern = '7304644'; Message = 'README does not record the observed HMA version code.' }
            @{ Pattern = '(?m)\|\s*`?2047`?\s*\|'; Message = 'README does not record the observed CorePatch version code.' }
        )) {
        Assert-True ($readme -match $liveStatement.Pattern) $liveStatement.Message
    }

    # The documented action set is bound to the dispatcher catalog, and every example must be accurate.
    $nonInteractiveActions = @('Detect', 'Verify', 'Target', 'Root15', 'Conceal', 'RemoveAds', 'Restore')
    foreach ($implementedAction in @($script:ToolkitActions)) {
        Assert-True ($readme -match ('(?i)-Action ' + [regex]::Escape([string]$implementedAction) + '\b')) "README does not document the implemented action: $implementedAction"
        if ($nonInteractiveActions -notcontains [string]$implementedAction) {
            continue
        }
        $example = [regex]::Match($readme, '(?m)^.*-Action ' + [regex]::Escape([string]$implementedAction) + '\b.*$')
        Assert-True ($example.Success) "README has no example command for the noninteractive action: $implementedAction"
        Assert-True ($example.Value -match '-NonInteractive') "The README example for $implementedAction omits -NonInteractive, so the command would only open the menu."
    }
    foreach ($removedAction in @('DryRun', 'Backup', 'Hide')) {
        Assert-True ($readme -notmatch ('(?i)-Action ' + $removedAction + '\b')) "README documents the removed action as a command: $removedAction"
    }

    # The target selection section is bound to the three implemented modes and to the confirmation rule.
    $targetSection = [regex]::Match($readme, '(?ms)^## Target selection$.*?(?=^## )')
    Assert-True $targetSection.Success 'README has no Target selection section.'
    foreach ($targetStatement in @(
            @{ Pattern = 'Identify'; Message = 'The target selection section does not document the Identify mode.' }
            @{ Pattern = 'Create'; Message = 'The target selection section does not document the Create mode.' }
            @{ Pattern = 'Clone'; Message = 'The target selection section does not document the Clone mode.' }
            @{ Pattern = '(?i)read-only'; Message = 'The target selection section does not state that Identify is read-only.' }
            @{ Pattern = '(?i)required'; Message = 'The target selection section does not state the confirmation requirement.' }
            @{ Pattern = '-Mode Identify'; Message = 'The target selection section has no noninteractive Identify example.' }
            @{ Pattern = '-Mode Create'; Message = 'The target selection section has no noninteractive Create example.' }
            @{ Pattern = '-Mode Clone'; Message = 'The target selection section has no noninteractive Clone example.' }
            @{ Pattern = '-StartIndex'; Message = 'The target selection section does not document the start index parameter.' }
            @{ Pattern = '-SourceIndex'; Message = 'The target selection section does not document the clone source parameter.' }
            @{ Pattern = '-InstanceIndex'; Message = 'The target selection section does not bind the reported target index to the later actions.' }
            @{ Pattern = '-Confirmed'; Message = 'The target selection section does not document the explicit confirmation switch.' }
            @{ Pattern = '(?i)precondition, not an instruction'; Message = 'The target selection section does not state that the start index is a precondition rather than a manager argument.' }
            @{ Pattern = '(?i)never sent to the manager'; Message = 'The target selection section does not state that the requested index is not sent to the manager.' }
            @{ Pattern = '(?i)MuMu assigns the index itself'; Message = 'The target selection section does not state that the manager assigns the created index.' }
            @{ Pattern = '(?i)`Index` in the result is the only authoritative index'; Message = 'The target selection section does not state that the returned index is authoritative.' }
            @{ Pattern = '(?i)Always use the returned `Index` for later actions'; Message = 'The target selection section does not tell the operator to use the returned index for later actions.' }
            @{ Pattern = '(?i)never the\s+requested index'; Message = 'The target selection section does not exclude the requested index as a later target.' }
            @{ Pattern = 'RequestedIndex'; Message = 'The target selection section does not name the reported precondition field.' }
            @{ Pattern = '(?i)never overwrites an index'; Message = 'The target selection section does not state that Create never overwrites an index.' }
            @{ Pattern = '(?i)base instance, has an unsupported Android'; Message = 'The target selection section does not state which clone sources are refused.' }
            @{ Pattern = '(?i)lists every discovered instance'; Message = 'The target selection section does not state that Identify lists every instance.' }
            @{ Pattern = '(?i)noninteractive run never prompts and\s+never confirms'; Message = 'The target selection section does not state that a noninteractive run never prompts or confirms.' }
            @{ Pattern = 'TARGET_MODE_REQUIRED'; Message = 'The target selection section does not document the fail-closed code for a missing mode.' }
            @{ Pattern = 'TARGET_MODE_INVALID'; Message = 'The target selection section does not document the fail-closed code for an unsupported mode.' }
            @{ Pattern = 'TARGET_START_INDEX_REQUIRED'; Message = 'The target selection section does not document the fail-closed code for a missing start index.' }
            @{ Pattern = 'TARGET_START_INDEX_INVALID'; Message = 'The target selection section does not document the fail-closed code for an invalid free instance index.' }
            @{ Pattern = 'TARGET_PARAMETER_MISUSE'; Message = 'The target selection section does not document the fail-closed code for a target parameter on another action.' }
        )) {
        Assert-True ($targetSection.Value -match $targetStatement.Pattern) $targetStatement.Message
    }
    Assert-True ($targetSection.Value -notmatch '(?i)(use|pass|run)[^.\n]*requested index (for|as) ') 'The target selection section tells the operator to use the requested index for a later action.'

    # The Verify report section is bound to the fields the controller actually prints.
    $verifySection = [regex]::Match($readme, '(?ms)^## Verify report$.*?(?=^## )')
    Assert-True $verifySection.Success 'README has no Verify report section.'
    foreach ($reportStatement in @(
            @{ Pattern = '(?i)one field per line'; Message = 'The Verify report section does not state the shape of the printed report.' }
            @{ Pattern = 'Install\.InstallRoot'; Message = 'The Verify report section does not name the installation identity.' }
            @{ Pattern = 'Install\.ManagerPath'; Message = 'The Verify report section does not name the manager path.' }
            @{ Pattern = 'RootSetting'; Message = 'The Verify report section does not name the per-instance vendor root setting.' }
            @{ Pattern = 'Virtualization'; Message = 'The Verify report section does not name the virtualization state.' }
            @{ Pattern = 'Guest\.Root'; Message = 'The Verify report section does not name the guest root state.' }
            @{ Pattern = 'Guest\.DaemonCount'; Message = 'The Verify report section does not name the guest root daemon evidence.' }
            @{ Pattern = 'Guest\.HmaInstalled'; Message = 'The Verify report section does not name the Hide My Applist module state.' }
            @{ Pattern = 'Guest\.VectorModuleInstalled'; Message = 'The Verify report section does not name the Vector module state.' }
            @{ Pattern = 'Ads\.RestorePoint'; Message = 'The Verify report section does not name the advertisement restore point.' }
            @{ Pattern = 'Backups\.CloneIndex'; Message = 'The Verify report section does not name the verified clone backup.' }
            @{ Pattern = 'JournalState'; Message = 'The Verify report section does not name the journal state.' }
            @{ Pattern = 'Failures:'; Message = 'The Verify report section does not name the failure list.' }
            @{ Pattern = '(?i)not-detected'; Message = 'The Verify report section does not state the marker for a value that was not reported.' }
            @{ Pattern = '(?i)`none`'; Message = 'The Verify report section does not state the marker for a value that is empty.' }
        )) {
        Assert-True ($verifySection.Value -match $reportStatement.Pattern) $reportStatement.Message
    }
    Assert-True ($verifySection.Value -notmatch '(?i)no live (qualification|run|test)') 'The Verify report section reintroduces a negative live-status claim.'

    Assert-True ($license -match 'MIT License') 'LICENSE is not the MIT license.'
    Assert-True ($license -match 'Permission is hereby granted, free of charge') 'LICENSE does not contain the MIT grant.'
    Assert-True ($license -match 'THE SOFTWARE IS PROVIDED "AS IS"') 'LICENSE does not contain the MIT warranty disclaimer.'
    Assert-True ($notice -match 'Jordan231111/mumu-magisk-1click') 'NOTICE does not credit the original project this work is clean-room from.'
    Assert-True ($notice -match '(?i)own licen') 'NOTICE does not state that upstream artifacts keep their own licenses.'
    Assert-True ($notice -match '(?i)does not imply endorsement|no endorsement|not endorsed') 'NOTICE does not disclaim endorsement.'
    Assert-True ($readme -match 'NOTICE\.md') 'README does not point at the attribution file.'
    Assert-True ($readme -match 'Jordan231111/mumu-magisk-1click') 'README does not credit the original project this work is clean-room from.'

    Assert-True ($workflow -match '(?m)^\s*runs-on:\s*windows') 'The workflow does not run on Windows.'
    Assert-True ($workflow -match 'actions/checkout@v[0-9]+') 'The workflow does not check out the repository with a pinned action.'
    Assert-True ($workflow -match '\[System\.Management\.Automation\.Language\.Parser\]') 'The workflow does not run PowerShell parser checks.'
    Assert-True ($workflow -match '-Suite All') 'The workflow does not run the full suite.'
    Assert-True ($workflow -match '(?m)^on:\s*$') 'The workflow does not declare its triggers.'
    foreach ($trigger in @('push', 'pull_request')) {
        Assert-True ($workflow -match ('(?m)^\s{2}' + $trigger + ':\s*$')) "The workflow does not run on the $trigger trigger."
    }
    Assert-True ($workflow -match '(?m)^\s*permissions:\s*$') 'The workflow does not declare token permissions.'
    Assert-True ($workflow -match '(?m)^\s{2}contents:\s*read\s*$') 'The workflow does not restrict the workflow token to read-only contents.'
    Assert-True ($workflow -match '(?m)^\s*timeout-minutes:\s*[0-9]+\s*$') 'The workflow does not bound the job with timeout-minutes.'
    foreach ($forbidden in @(
            'upload-artifact'
            'actions/setup-'
            'Invoke-WebRequest'
            'Invoke-RestMethod'
            'Install-Module'
            'Save-Module'
            'Set-ExecutionPolicy'
            'choco '
            'winget'
            'scoop'
            'dotnet'
            'pip install'
            'npm install'
            '(?i)mumu'
            '(?i)\badb\b'
        )) {
        Assert-True ($workflow -notmatch $forbidden) "The workflow uses a forbidden construct for a checkout-only build: $forbidden"
    }

    foreach ($document in @(
            [pscustomobject]@{ Name = 'README.md'; Text = $readme }
            [pscustomobject]@{ Name = 'NOTICE.md'; Text = $notice }
        )) {
        Assert-True ($document.Text -notmatch '[^\x00-\x7F]') "$($document.Name) contains non-ASCII text, which is not the clean-room English documentation."
        Assert-True ($document.Text -notmatch '(?i)\.(apk|zip|7z|msi|img|ico|iso|cab|whl|nupkg)\b') "$($document.Name) references a packaged binary artifact file name."
        foreach ($hostMatch in [regex]::Matches($document.Text, 'https?://([A-Za-z0-9.-]+)')) {
            $linkHost = $hostMatch.Groups[1].Value.ToLowerInvariant()
            Assert-True (@('github.com', 'www.mumuplayer.com', 'mumuplayer.com') -contains $linkHost) "$($document.Name) links a host that is not an official upstream source: $linkHost"
        }
    }
    foreach ($ignoredPattern in @('*.apk', '*.zip', '*.exe', '*.pfx')) {
        Assert-True ($gitignore.Contains($ignoredPattern)) ".gitignore does not exclude the publishing safeguard pattern: $ignoredPattern"
    }
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
        'Transport' {
            Invoke-TransportTests
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
        'Target' {
            Invoke-TargetTests
        }
        'Menu' {
            Invoke-MenuTests
        }
        'Docs' {
            Invoke-DocsTests
        }
        'All' {
            Invoke-ManifestTests
            Invoke-AssetTests
            Invoke-ResultTests
            Invoke-ProcessTests
            Invoke-JournalTests
            Invoke-DiscoveryTests
            Invoke-SafetyTests
            Invoke-TransportTests
            Invoke-AdsTests
            Invoke-VerificationTests
            Invoke-ConcealmentTests
            Invoke-TargetTests
            Invoke-Root12Tests
            Invoke-Root15Tests
            Invoke-MenuTests
            Invoke-DocsTests
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