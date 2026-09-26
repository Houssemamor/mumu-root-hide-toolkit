# MuMu Root Hide Toolkit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a clean-room Windows PowerShell toolkit that detects Global and Chinese MuMu installations, safely roots Android 12 or Android 15 instances, configures selected-app root concealment, suppresses MuMu-owned ads, and restores or verifies every mutation.

**Architecture:** A double-click launcher starts a PowerShell controller. The controller composes focused scripts for discovery, elevation, journaling, backup, Android-version-specific root flows, concealment, ads, and verification. Every mutating operation is preceded by a verified instance clone and represented in a journal; interactive errors return to a persistent menu, while unsafe states fail closed.

**Tech Stack:** Windows PowerShell 5.1-compatible script hosting, .NET JSON and hashing APIs, MuMuManager CLI, ADB supplied by MuMu, official GitHub release assets, and custom fixture-based tests without a third-party test framework.

## Global Constraints

- Support MuMu Player Global and Chinese editions on Windows 10 and Windows 11.
- Support MuMu Android 12 instances with the Kitsune guided flow and Android 15 instances with MuMu's built-in KernelSU only.
- Use independently written code; do not copy the original project's source, README prose, binaries, workflows, tests, icons, or assets.
- License independently written toolkit code under MIT; retain upstream dependency licenses and notices.
- Download dependencies only from pinned official upstream URLs and verify SHA-256 before use.
- Use the exact Android 12 Kitsune choice `Install -> Direct Install into system partition`; never silently select ordinary `Direct Install` or `Select and Patch a File`.
- Create and verify an instance clone before every mutating operation; never overwrite the only original backup.
- Never edit hosts files, firewall rules, startup entries, scheduled tasks, Hyper-V, VBS, or Windows security policy.
- Never patch game APKs or suppress third-party application advertisements.
- Keep all paths as structured PowerShell arguments; never concatenate untrusted paths into shell command strings.
- If UAC is missing, suppressed, or denied, report the condition and remain in the menu; do not bypass Windows security.
- Critical errors stop only the current action and prevent later mutation steps; recoverable errors use bounded retries and return to the menu.
- Use ASCII-only source and documentation, with no code comments unless explicitly requested.
- Test fixtures must never modify a real MuMu installation.
- Tested references are MuMu Player 6.8.0.0, Android 12.0, Android 15.0 with built-in KernelSU 3.2.5, Kitsune v31.0-25fa2159, HMA-OSS oss-161, Vector v2.0, NeoZygisk v2.3, and CorePatch 4.9.

---

## File Map

The implementation will create these focused files:

- `Run-MumuToolkit.bat`: non-elevating double-click launcher; delegates to the PowerShell controller.
- `src/Invoke-MumuToolkit.ps1`: parameter dispatch and persistent interactive menu.
- `src/Common.ps1`: result objects, logging, JSON/hash helpers, safe external process execution, and shared constants.
- `src/Manifest.ps1`: manifest loading, release-asset resolution, download, and hash verification.
- `src/Discovery.ps1`: registry/process/fallback installation discovery and instance selection.
- `src/Elevation.ps1`: administrator detection, direct UAC relaunch, and elevated-child verification.
- `src/Journal.ps1`: operation records, checkpoints, redaction, resume, and failure state.
- `src/Backup.ps1`: instance cloning, clone verification, exact file backups, and restoration.
- `src/Root12.ps1`: Android 12 Kitsune preparation, guided system-partition installation, and verification.
- `src/Root15.ps1`: Android 15 built-in root toggle and KernelSU verification.
- `src/Concealment.ps1`: HMA/Vector installation, reusable Root template, selected-app scope, and KernelSU profile handoff.
- `src/Target.ps1`: read-only instance choices, verified instance creation, and the Identify/Create/Clone target selection.
- `src/Ads.ps1`: MuMu campaign suppression and exact restoration.
- `src/Verification.ps1`: shared read-only root verification primitives, and from Task 9 the read-only status report.
- `src/Manifest.json`: tested versions, official URLs, asset names, sizes, and SHA-256 values.
- `tests/Run-Tests.ps1`: dependency-free test runner and assertions.
- `tests/Fixtures/`: generated temporary fixture data only; no real credentials or installations.
- `README.md`: setup, tested links, menu usage, recovery, and limitations.
- `NOTICE.md`: original-project and upstream attribution.
- `LICENSE`: MIT license text.
- `.gitignore`: logs, caches, staged dependencies, and test artifacts.
- `.github/workflows/test.yml`: Windows parser and fixture-test workflow.

---

### Task 1: Establish the clean-room shell and verified manifest

**Files:**
- Create: `src/Manifest.json`
- Create: `src/Manifest.ps1`
- Create: `src/Common.ps1`
- Create: `tests/Run-Tests.ps1`
- Create: `.gitignore`
- Test: `tests/Run-Tests.ps1`

**Interfaces:**
- Produces `Get-ToolkitManifest -Path <string>` returning a validated manifest object.
- Produces `Get-ToolkitResult -Status <string> -Message <string> -Data <object>` returning `Success`, `AlreadyApplied`, `Warning`, `RecoverableError`, or `CriticalError` results.
- Produces `Invoke-CheckedProcess -FilePath <string> -ArgumentList <string[]> [-Runner <scriptblock>]` returning exit code and captured text without shell-string interpolation.
- Produces `Get-ToolkitLogPath()` returning a per-user log path under `%LOCALAPPDATA%\mumu-root-hide-toolkit\logs`.
- Produces `Get-VerifiedAsset -Manifest <object> -Id <string> -CacheRoot <string>` returning a local path only after size and SHA-256 verification.

- [ ] **Step 1: Write the failing manifest tests**

Add tests to `tests/Run-Tests.ps1` that load `src/Manifest.json`, require schema version `1`, reject debug assets, require these exact release assets and digests, and reject a manifest with a missing hash.

```powershell
$manifest = Get-Content -LiteralPath (Join-Path $repoRoot 'src\Manifest.json') -Raw | ConvertFrom-Json
Assert-True ($manifest.schemaVersion -eq 1) 'Manifest schema version is invalid.'
Assert-True (@($manifest.dependencies | Where-Object { $_.assetName -match 'debug' }).Count -eq 0) 'Debug assets are not allowed.'
$requiredAssets = @('app-release.apk', 'HMA-OSS-oss-161-release.apk', 'Vector-v2.0-3021-Release.zip', 'NeoZygisk-v2.3-275-release.zip', 'app-release.apk')
Assert-True (@($manifest.dependencies).Count -eq $requiredAssets.Count) 'Manifest dependency count is invalid.'
foreach ($dependency in $manifest.dependencies) {
    Assert-True ($dependency.sha256 -match '^[0-9a-f]{64}$') "Manifest hash is invalid: $($dependency.id)"
    Assert-True ($dependency.url -match '^https://github\.com/') "Manifest URL is not an official GitHub asset: $($dependency.id)"
}
```

- [ ] **Step 2: Run the tests and verify the expected failure**

Run: `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite Manifest`

Expected: FAIL because `src/Manifest.json` does not exist yet.

- [ ] **Step 3: Create the manifest with verified release assets**

Create `src/Manifest.json` with schema version `1`, tested MuMu version `6.8.0.0`, and these official assets:

```json
{
  "schemaVersion": 1,
  "mumu": { "testedVersion": "6.8.0.0" },
  "dependencies": [
    {
      "id": "kitsune",
      "version": "v31.0-25fa2159",
      "assetName": "app-release.apk",
      "url": "https://github.com/Jordan231111/KitsuneMagisk/releases/download/v31.0-25fa2159/app-release.apk",
      "size": 12574128,
      "sha256": "fac319d2de262fcfff1684e13e1a5c61c486d2a773a7a8ffcfdbfe6f763a7fd4"
    },
    {
      "id": "hma",
      "version": "oss-161",
      "assetName": "HMA-OSS-oss-161-release.apk",
      "url": "https://github.com/frknkrc44/HMA-OSS/releases/download/oss-161/HMA-OSS-oss-161-release.apk",
      "size": 3094974,
      "sha256": "059f9fa4a2ccdef83f281d9434c852d29a0728d5e0e4e0f1e13d96fade6947cd"
    },
    {
      "id": "vector",
      "version": "v2.0",
      "assetName": "Vector-v2.0-3021-Release.zip",
      "url": "https://github.com/JingMatrix/Vector/releases/download/v2.0/Vector-v2.0-3021-Release.zip",
      "size": 8434264,
      "sha256": "d5e39669c02c2c699ab948eb8f3639b348eefb7749553224a9c62fa4a2f2dc18"
    },
    {
      "id": "neozygisk",
      "version": "v2.3",
      "assetName": "NeoZygisk-v2.3-275-release.zip",
      "url": "https://github.com/JingMatrix/NeoZygisk/releases/download/v2.3/NeoZygisk-v2.3-275-release.zip",
      "size": 3208704,
      "sha256": "5c84df9f962c04855b3523a3a75022cf5e4f3ad3dfd94794ed92b43e911f3b9a"
    },
    {
      "id": "corepatch",
      "version": "4.9",
      "assetName": "app-release.apk",
      "url": "https://github.com/LSPosed/CorePatch/releases/download/4.9/app-release.apk",
      "size": 64416,
      "sha256": "1bdc47d5b48afffd37948a9f5638ae6a5f3d4d02ca01ae36143588284b979996"
    }
  ]
}
```

The implementation must record that Vector build `3043` and NeoZygisk build `282` were used during the local verification, while the clean-room manifest uses the official tagged assets above. If a tagged asset fails qualification, it must be marked unverified rather than silently substituted.

- [ ] **Step 4: Implement manifest validation and result helpers**

Implement `Get-ToolkitManifest`, `Get-ToolkitResult`, `Get-ToolkitLogPath`, and `Get-VerifiedAsset` in `src/Common.ps1` and `src/Manifest.ps1`. Use `Get-FileHash -Algorithm SHA256`, compare file length before hashing, and return `CriticalError` without executing an asset when either check fails.

```powershell
function Get-ToolkitResult {
    param([ValidateSet('Success','AlreadyApplied','Warning','RecoverableError','CriticalError')][string]$Status,
          [string]$Message,
          [object]$Data = $null)
    [pscustomobject]@{ Status = $Status; Message = $Message; Data = $Data }
}

function Assert-VerifiedAsset {
    param([string]$Path, [long]$ExpectedSize, [string]$ExpectedSha256)
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($item.Length -ne $ExpectedSize -or $hash -ne $ExpectedSha256.ToLowerInvariant()) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Asset verification failed.'
    }
    return Get-ToolkitResult -Status 'Success' -Message 'Asset verified.' -Data $Path
}
```

- [ ] **Step 5: Run the manifest tests**

Run: `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite Manifest`

Expected: PASS for schema, official URL, asset name, size, and hash validation.

- [ ] **Step 6: Commit**

```powershell
git add .gitignore src/Manifest.json src/Manifest.ps1 src/Common.ps1 tests/Run-Tests.ps1
git commit -m "feat: add clean-room manifest and result primitives"
```

---

### Task 2: Add journaling, redaction, and deep error primitives

**Files:**
- Modify: `src/Common.ps1`
- Create: `src/Journal.ps1`
- Modify: `tests/Run-Tests.ps1`

**Interfaces:**
- Produces `New-OperationJournal -Root <string> -Operation <string> -Instance <object>` returning a journal object with `Id`, `StartedAt`, `State`, `Checkpoints`, and `JournalPath`.
- Produces `Get-OperationJournal -Path <string>` reopening a persisted journal.
- Produces `Write-JournalEvent -Journal <object> -Level <string> -Message <string> -Data <object>` appending a redacted event.
- Produces `Complete-OperationJournal -Journal <object> -Result <object>` and `Fail-OperationJournal -Journal <object> -Result <object>`.
- Produces `Invoke-WithRetry -Operation <scriptblock> -Attempts <int> -DelaySeconds <int>` returning the last result or a `RecoverableError`.

- [ ] **Step 1: Write failing tests for journal recovery and redaction**

Add tests that create a temporary journal, write a checkpoint containing a path with spaces and a fake token-shaped value, close it as failed, reopen it, and assert that the token is absent and the checkpoint is present.

```powershell
$journal = New-OperationJournal -Root $testRoot -Operation 'Root12' -Instance $fixtureInstance
Write-JournalEvent -Journal $journal -Level 'Info' -Message 'checkpoint' -Data @{ Path = 'C:\Program Files\MuMu\config.json'; Token = 'ghp_example_secret' }
Fail-OperationJournal -Journal $journal -Result (Get-ToolkitResult -Status 'CriticalError' -Message 'hash mismatch')
$reopened = Get-OperationJournal -Path $journal.JournalPath
Assert-True ($reopened.State -eq 'Failed') 'Failed journal state was not persisted.'
Assert-True ($reopened.Checkpoints.Count -ge 1) 'Journal checkpoint was lost.'
Assert-True ((Get-Content $journal.JournalPath -Raw) -notmatch 'ghp_example_secret') 'Journal leaked a secret-shaped value.'
```

- [ ] **Step 2: Run the tests and verify failure**

Run: `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite Journal`

Expected: FAIL because journal functions do not exist.

- [ ] **Step 3: Implement atomic journal writes and bounded retries**

Use UTF-8 JSON, a temporary file in the same directory, and `Move-Item -Force` after serialization. Redact keys matching `token|password|secret|authorization|cookie|key`. `Invoke-WithRetry` must use bounded attempts, clean temporary files in `finally`, and return structured results instead of throwing into the menu loop.

```powershell
function Protect-JournalValue {
    param([object]$Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [hashtable]) {
        $copy = @{}
        foreach ($key in $Value.Keys) {
            $copy[$key] = if ([string]$key -match 'token|password|secret|authorization|cookie|key') { '[REDACTED]' } else { Protect-JournalValue $Value[$key] }
        }
        return $copy
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        return @($Value | ForEach-Object { Protect-JournalValue $_ })
    }
    return $Value
}

function Invoke-WithRetry {
    param([scriptblock]$Operation, [int]$Attempts = 3, [int]$DelaySeconds = 2)
    $last = Get-ToolkitResult -Status 'RecoverableError' -Message 'Operation did not run.'
    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try { return & $Operation } catch { $last = Get-ToolkitResult -Status 'RecoverableError' -Message $_.Exception.Message }
        if ($attempt -lt $Attempts) { Start-Sleep -Seconds $DelaySeconds }
    }
    return $last
}
```

- [ ] **Step 4: Run the tests and parser check**

Run: `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite Journal`

Expected: PASS.

Run: `powershell.exe -NoProfile -Command "[System.Management.Automation.Language.Parser]::ParseFile('src\Journal.ps1',[ref]$null,[ref]$null) | Out-Null; 'PARSE_OK'"`

Expected: `PARSE_OK`.

- [ ] **Step 5: Commit**

```powershell
git add src/Common.ps1 src/Journal.ps1 tests/Run-Tests.ps1
git commit -m "feat: add journaled recoverable errors"
```

---

### Task 3: Implement installation and instance discovery

**Files:**
- Create: `src/Discovery.ps1`
- Modify: `src/Common.ps1`
- Modify: `tests/Run-Tests.ps1`

**Interfaces:**
- Produces `Find-MuMuInstallations -Edition <string> -RegistryRoots <string[]> -ProcessSnapshot <object[]> -FallbackRoots <string[]>` returning normalized installation records with `Edition`, `InstallRoot`, `VmsPath`, `ManagerPath`, and `Source`.
- Produces `Get-MuMuInstances -Install <object> -ManagerPath <string>` returning records with `Index`, `Name`, `AndroidVersion`, `Install`, `Running`, and `RootSetting`.
- Produces `Resolve-SelectedInstance -Instances <object[]> -Selection <object>` returning exactly one record or a `CriticalError` for zero or multiple eligible records.

- [ ] **Step 1: Write failing discovery fixtures**

Create temporary fixture roots such as `D:\Odd Path\MuMu Global`, `E:\安装\MuMu`, and a Chinese user-data root. Assert that registry `InstallLocation`, process command lines, and fallback roots are considered; assert that an ambiguous list is rejected.

```powershell
$installs = Find-MuMuInstallations -Edition 'All' -RegistryRoots $fixtureRegistryRoots -ProcessSnapshot $fixtureProcesses -FallbackRoots $fixtureFallbackRoots
Assert-True (@($installs | Where-Object { $_.InstallRoot -eq 'D:\Odd Path\MuMu Global' }).Count -eq 1) 'Spaced Global install was not discovered.'
Assert-True (@($installs | Where-Object { $_.InstallRoot -eq 'E:\安装\MuMu' }).Count -eq 1) 'Unicode Chinese install was not discovered.'
$ambiguous = Resolve-SelectedInstance -Instances @($fixtureInstance0, $fixtureInstance1) -Selection $null
Assert-True ($ambiguous.Status -eq 'CriticalError') 'Ambiguous instance selection was accepted.'
```

- [ ] **Step 2: Run discovery tests and verify failure**

Run: `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite Discovery`

Expected: FAIL because discovery functions do not exist.

- [ ] **Step 3: Implement normalized discovery and explicit selection**

Use registry APIs and structured process records, normalize paths with `[IO.Path]::GetFullPath`, resolve manager-reported VMS paths, and never execute a path until it has passed `Test-Path`. Sort instances by numeric index, display all candidates, and require an explicit index when more than one is eligible.

```powershell
function Resolve-SelectedInstance {
    param([object[]]$Instances, [object]$Selection)
    $eligible = @($Instances | Where-Object { $_.Eligible })
    if ($null -ne $Selection -and $null -ne $Selection.Index) {
        return @($eligible | Where-Object { [int]$_.Index -eq [int]$Selection.Index }) | Select-Object -First 1
    }
    if ($eligible.Count -ne 1) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Select exactly one eligible MuMu instance.'
    }
    return $eligible[0]
}
```

- [ ] **Step 4: Add negative discovery tests**

Add cases for missing manager, missing VMS path, a base instance, unsupported Android version, stale metadata, and a process whose path is outside the discovered install. Each must return a structured `CriticalError` with no process execution.

- [ ] **Step 5: Run the full discovery suite**

Run: `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite Discovery`

Expected: PASS for all positive and negative fixtures.

- [ ] **Step 6: Commit**

```powershell
git add src/Discovery.ps1 src/Common.ps1 tests/Run-Tests.ps1
git commit -m "feat: discover relocated Mumu installations"
```

---

### Task 4: Add UAC handling and verified instance backups

**Files:**
- Create: `src/Elevation.ps1`
- Create: `src/Backup.ps1`
- Modify: `src/Common.ps1`
- Modify: `tests/Run-Tests.ps1`

**Interfaces:**
- Produces `Test-ToolkitAdministrator` returning a boolean based on the current Windows token.
- Produces `Invoke-ElevatedToolkitAction -ScriptPath <string> -Arguments <string[]> [-Runner <scriptblock>]` returning the child exit code and verified elevation state.
- Produces `New-InstanceClone -ManagerPath <string> -Instance <object> -Journal <object> [-Runner <scriptblock>]` returning a verified clone record.
- Produces `Backup-ChangedFile -Path <string> -BackupRoot <string>` and `Restore-BackupFile -BackupRecord <object>`.

- [ ] **Step 1: Write failing UAC and clone tests**

Use an injectable process runner and fixture manager. Assert that a non-admin mutating action requests direct PowerShell elevation, a denied child returns `CriticalError`, a running instance is stopped before clone, and a clone that does not boot is not accepted.

```powershell
$preflight = Test-ToolkitAdministrator
Assert-True ($preflight -is [bool]) 'Administrator preflight did not return a boolean.'
$denied = Invoke-ElevatedToolkitAction -ScriptPath $fakeScript -Arguments @('-Fixture', 'Denied') -Runner $fakeDeniedRunner
Assert-True ($denied.Status -eq 'CriticalError') 'Denied UAC elevation was treated as success.'
$clone = New-InstanceClone -ManagerPath $fixtureManager -Instance $fixtureInstance -Journal $fixtureJournal -Runner $fakeFailingCloneRunner
Assert-True ($clone.Status -eq 'CriticalError') 'Unverified clone was accepted.'
```

- [ ] **Step 2: Run the tests and verify failure**

Run: `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite Safety`

Expected: FAIL because elevation and clone functions do not exist.

- [ ] **Step 3: Implement direct UAC relaunch and token verification**

Invoke `Start-Process powershell.exe -Verb RunAs -Wait -PassThru` with `-NoProfile -ExecutionPolicy RemoteSigned`. The child must call `Test-ToolkitAdministrator` and return a distinct nonzero code if it is not elevated. Never create a scheduled task or alter UAC policy.

```powershell
function Test-ToolkitAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
```

- [ ] **Step 4: Implement clone and file backup transactions**

Call `MuMuManager control -v <index> shutdown`, wait for a stable stopped state, call `MuMuManager clone -v <index> -n 1`, identify the returned new index, and verify name, Android version, disk size, and boot readiness. Copy every changed file to a timestamped backup directory and record its SHA-256, owner-readable metadata, and original read-only bit.

```powershell
function Backup-ChangedFile {
    param([string]$Path, [string]$BackupRoot)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $item = Get-Item -LiteralPath $Path
    $target = Join-Path $BackupRoot ([IO.Path]::GetFileName($Path))
    [IO.File]::Copy($Path, $target, $false)
    [pscustomobject]@{
        Source = $Path
        Backup = $target
        Sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        ReadOnly = [bool]$item.IsReadOnly
    }
}
```

- [ ] **Step 5: Run safety tests and parser checks**

Run: `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite Safety`

Expected: PASS, including duplicate-backup refusal and denied-UAC behavior.

- [ ] **Step 6: Commit**

```powershell
git add src/Elevation.ps1 src/Backup.ps1 src/Common.ps1 tests/Run-Tests.ps1
git commit -m "feat: add safe elevation and verified backups"
```

---

### Task 5: Implement reversible MuMu advertisement suppression

**Files:**
- Create: `src/Ads.ps1`
- Modify: `src/Common.ps1`
- Modify: `tests/Run-Tests.ps1`

**Interfaces:**
- Produces `Get-MuMuCampaignPaths -Install <object>` returning existing Global and Chinese campaign paths.
- Produces `Suppress-MuMuAds -Paths <string[]> -BackupRoot <string> -Journal <object>` returning changed and skipped campaign counts.
- Produces `Restore-MuMuAds -BackupRoot <string> -AllowedRoot <string> -Journal <object>` restoring exact bytes and read-only state. `-AllowedRoot` is a mandatory caller-supplied boundary (the install or campaign root) and is never read from the restore-point manifest; a restore without it is refused.

- [ ] **Step 1: Write failing ad fixtures**

Create a valid campaign JSON fixture, a malformed fixture, and a read-only fixture. Assert that suppression changes only existing `display` fields, makes an exact backup, preserves read-only state, refuses a second suppression, and restores bytes exactly.

```powershell
$suppress = Suppress-MuMuAds -Paths @($campaignPath) -BackupRoot $testRoot -Journal $journal
Assert-True ($suppress.Status -eq 'Success') 'Valid campaign suppression failed.'
Assert-True ((Get-Item $campaignPath).IsReadOnly) 'Campaign read-only state was not preserved.'
$duplicate = Suppress-MuMuAds -Paths @($campaignPath) -BackupRoot $testRoot -Journal $journal
Assert-True ($duplicate.Status -eq 'CriticalError') 'Duplicate suppression overwrote a backup.'
$restore = Restore-MuMuAds -BackupRoot $testRoot -AllowedRoot $campaignRoot -Journal $journal
Assert-True ((Get-Content $campaignPath -Raw) -eq $originalCampaignJson) 'Campaign bytes were not restored exactly.'
```

- [ ] **Step 2: Run ad tests and verify failure**

Run: `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite Ads`

Expected: FAIL because ad functions do not exist.

- [ ] **Step 3: Implement validated atomic campaign edits**

Parse JSON before creating a backup, set only existing `display` properties to `false`, write UTF-8 without a BOM, restore the original read-only bit, and refuse malformed or incomplete restore points. Do not touch network files, app data, or game packages.

```powershell
function Set-CampaignDisplays {
    param([object]$Campaigns)
    $changed = 0
    foreach ($campaign in @($Campaigns)) {
        if ($campaign.PSObject.Properties['display']) {
            $campaign.display = $false
            $changed++
        }
    }
    return $changed
}
```

- [ ] **Step 4: Run the full ad suite**

Run: `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite Ads`

Expected: PASS for suppress, duplicate protection, malformed JSON, read-only preservation, and exact restore.

- [ ] **Step 5: Commit**

```powershell
git add src/Ads.ps1 src/Common.ps1 tests/Run-Tests.ps1
git commit -m "feat: add reversible Mumu ad suppression"
```

---

### Task 6: Implement the Android 12 Kitsune workflow

**Files:**
- Create: `src/Root12.ps1`
- Modify: `src/Manifest.ps1`
- Modify: `src/Backup.ps1`
- Modify: `tests/Run-Tests.ps1`

**Interfaces:**
- Produces `Install-Android12Root -Instance <object> -Manifest <object> -Journal <object> -Interactive <bool> [-Confirmation <string>] [-Runner <scriptblock>]` returning a structured result.
- Produces `Install-Android12Root -Instance <object> -Manifest <object> -Journal <object> -Interactive <bool> [-Confirmation <string>] [-CacheRoot <string>] [-Runner <scriptblock>] [-Prompt <scriptblock>] [-ResumeClone <object>] [-RequireCachedAsset]` returning a structured result.
  The extension parameters are optional and preserve the original signature: `-CacheRoot` defaults to the per-user dependency cache, `-Runner` injects the manager and ADB transport, `-Prompt` supplies the operator prompt used when `-Confirmation` is absent, `-ResumeClone` continues on a previously reported verified clone instead of cloning again and accepts the recovery record a failed call returns, and `-RequireCachedAsset` forbids any network fetch so an elevated phase can never download a dependency.
- Produces `Get-Android12KitsunePrompt` returning the exact text `Install -> Direct Install into system partition`.
- Produces `Test-KitsuneConfirmation` accepting only `Direct Install into system partition`, and `Read-Android12KitsuneConfirmation` with the `$script:ToolkitKitsuneDefaultPrompt` seam for the operator prompt, defaulting to `Read-Host`.
- Produces `Prepare-Android12Asset -Manifest <object> [-CacheRoot <string>] [-RequireCached] [-Fetch <scriptblock>]` so the controller can fetch and verify the pinned APK before any elevated phase.
- Produces `Get-Android12RootSetting -ManagerPath <string> -Index <int>` returning the vendor root setting with a distinct code for every unsupported or malformed manager response shape.
- Forward reference, updated by Task 7: that reader is now `Get-ToolkitRootSetting -ManagerPath <string> -Index <int> [-Runner <scriptblock>]` in `src/Verification.ps1`, shared with the Android 15 flow and also reporting `INDEX_MISMATCH` when a response names another instance. Task 6 itself did not create or modify `src/Verification.ps1`.
- Produces `Resolve-Android12Clone` and `Assert-Android12ResumeClone` so a successful clone with missing data, or a recorded clone that no longer matches, is refused before any further mutation. `-ResumeClone` accepts either the recovery record of a failed call or an equivalent object.
- Produces `Format-Android12InstallCommand` building the single quoted `install -r "<path>"` command element for MuMuManager.
- Produces `Test-Android12Root -ManagerPath <string> -InstanceIndex <int>` returning package, daemon, and root checks.

- [ ] **Step 1: Write failing Android 12 tests**

Use a fake manager and ADB runner. Assert that Android 15 is rejected by this function, the exact Kitsune APK hash is required, ordinary `Direct Install` is rejected by the confirmation parser, and missing confirmation returns `CriticalError` without changing the instance.

```powershell
$wrongVersion = Install-Android12Root -Instance $android15Fixture -Manifest $manifest -Journal $journal -Interactive $false
Assert-True ($wrongVersion.Status -eq 'CriticalError') 'Android 15 was sent to the Android 12 workflow.'
$prompt = Get-Android12KitsunePrompt
Assert-True ($prompt -match 'Direct Install into system partition') 'Kitsune prompt is ambiguous.'
$confirmed = Install-Android12Root -Instance $android12Fixture -Manifest $manifest -Journal $journal -Interactive $true -Confirmation 'Direct Install into system partition'
Assert-True ($confirmed.Status -eq 'Success') 'Confirmed Android 12 root workflow failed.'
```

- [ ] **Step 2: Run Android 12 tests and verify failure**

Run: `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite Root12`

Expected: FAIL because the workflow does not exist.

- [ ] **Step 3: Implement verified preparation and guided confirmation**

Verify the selected instance is Android 12, clone it, enable only supported MuMu root/writable settings, download and verify the manifest Kitsune asset before elevation, install the APK through ADB, and pause with the exact system-partition instruction. In non-interactive mode return `CriticalError` with `USER_CONFIRMATION_REQUIRED`; never auto-confirm.

```powershell
function Get-Android12KitsunePrompt {
    return 'Install -> Direct Install into system partition'
}

function Test-KitsuneConfirmation {
    param([string]$Confirmation)
    return $Confirmation -eq 'Direct Install into system partition'
}
```

- [ ] **Step 4: Implement cold-boot verification**

After confirmation, stop and launch the instance, wait for `sys.boot_completed=1`, verify package version `31.0-kitsune` / `31000`, verify one `magiskd`, verify root through the supported root shell, and only then disable temporary vendor root. Record every check in the journal.

```powershell
function Test-Android12Root {
    param([string]$ManagerPath, [int]$InstanceIndex)
    $package = Invoke-CheckedProcess -FilePath $ManagerPath -ArgumentList @('adb','-v',"$InstanceIndex",'-c','shell dumpsys package io.github.huskydg.magisk')
    $daemon = Invoke-CheckedProcess -FilePath $ManagerPath -ArgumentList @('adb','-v',"$InstanceIndex",'-c','shell pidof magiskd')
    return [pscustomobject]@{
        PackageVersion = $package.Text
        DaemonCount = @($daemon.Text -split '\s+' | Where-Object { $_ }).Count
        RootVerified = $false
    }
}
```

- [ ] **Step 5: Add failure and recovery tests**

Cover missing system-partition option, wrong APK hash, boot timeout, absent daemon, root denial, interrupted confirmation, and restore from the verified clone. Each must stop later steps and return to the menu with a recovery path.

- [ ] **Step 6: Run Android 12 tests and commit**

Run: `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite Root12`

Expected: PASS for success and every negative case.

```powershell
git add src/Root12.ps1 src/Manifest.ps1 src/Backup.ps1 tests/Run-Tests.ps1
git commit -m "feat: add guided Android 12 Kitsune rooting"
```

---

### Task 7: Implement the Android 15 built-in KernelSU workflow

**Files:**
- Create: `src/Root15.ps1`
- Create: `src/Verification.ps1`
- Modify: `tests/Run-Tests.ps1`

**Interfaces:**
- Produces `Enable-Android15Root -Instance <object> -Journal <object> [-Confirmed] [-Runner <scriptblock>]` returning the root-toggle and cold-boot result. `-Confirmed` is an explicit switch: without it the call returns `USER_CONFIRMATION_REQUIRED` before any manager or clone mutation, and the controller collects that confirmation explicitly rather than auto-confirming.
- Produces `Test-Android15Root -ManagerPath <string> -InstanceIndex <int> [-Runner <scriptblock>]` returning `RootPermission`, `KernelSU`, `RootShell`, and `KitsuneAbsent` fields.
- Creates the shared read-only primitives in `src/Verification.ps1`, which this task also rewires the Android 12 flow to use: `Invoke-ToolkitManagerAdb`, `Wait-ToolkitBootCompleted`, `Get-ToolkitRootSetting`, `Get-ToolkitPackageVersion`, `Get-ToolkitRootShellStatus`, and `New-ToolkitRootFailure`. Both root workflows use them, so the ADB request shape, the boot wait, the vendor root reader, the package identity rule, and the failure closer exist once. `src/Verification.ps1` must be dot-sourced before the first call into either root workflow, which this task does not enforce at definition time; the controller dot-sources the composed script set before it dispatches an action. Task 9 modifies the same file to add `Get-ToolkitReport`.

- [ ] **Step 1: Write failing Android 15 tests**

Assert that the function rejects Android 12, never calls the Kitsune downloader, sets `root_permission=true`, cold-boots, verifies built-in KernelSU, and does not change Hyper-V or VBS settings.

```powershell
$android12 = Enable-Android15Root -Instance $android12Fixture -Journal $journal -Runner $fakeRunner
Assert-True ($android12.Status -eq 'CriticalError') 'Android 12 was sent to Android 15 root flow.'
$android15 = Enable-Android15Root -Instance $android15Fixture -Journal $journal -Confirmed -Runner $fakeRunner
Assert-True ($android15.Status -eq 'Success') 'Android 15 root flow failed.'
Assert-True ($fakeRunner.HyperVCalls.Count -eq 0) 'Android 15 flow changed Hyper-V.'
Assert-True ($fakeRunner.KitsuneDownloads.Count -eq 0) 'Android 15 flow downloaded Kitsune.'
```

- [ ] **Step 2: Run tests and verify failure**

Run: `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite Root15`

Expected: FAIL because the workflow does not exist.

- [ ] **Step 3: Implement the built-in root toggle and verification**

Call the manager's `setting -k root_permission -val true`, restart the selected Android 15 instance, wait for Android readiness, verify the built-in KernelSU package and root shell, and assert that Kitsune is not installed by this workflow. Never disable Hyper-V, VBS, or memory integrity.

```powershell
function Enable-Android15Root {
    param([object]$Instance, [object]$Journal, [scriptblock]$Runner = $null)
    if ([string]$Instance.AndroidVersion -ne '15.0') {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Android 15 root requires an Android 15 instance.'
    }
    $setting = Invoke-CheckedProcess -FilePath $Instance.ManagerPath -ArgumentList @('setting','-v',"$($Instance.Index)",'-k','root_permission','-val','true') -Runner $Runner
    if ($setting.ExitCode -ne 0) { return Get-ToolkitResult -Status 'CriticalError' -Message 'MuMu root toggle failed.' }
    return Get-ToolkitResult -Status 'Success' -Message 'Android 15 root toggle requested; cold-boot verification is required.'
}
```

- [ ] **Step 4: Add negative and idempotency tests**

Cover already-enabled root, missing root toggle, failed boot, absent KernelSU, a near-name KernelSU package, a multi-block `dumpsys package` response whose near-name block carries a different version than the real package, a denied root shell, an ADB transport failure that is not a root-shell denial, an unfiltered package list that returns a usage or error string, a vendor root setting that names another instance, and an Android 15 instance with an existing unrelated Kitsune package. The package reader must take `versionName` and `versionCode` only from the matched exact `Package [<name>]` block, never from an adjacent block. The function must report `AlreadyApplied` only when verification passes, must reject an unconfirmed call with `USER_CONFIRMATION_REQUIRED` before any manager call, and must issue the bare `shell pm list packages` request rather than an unverified filtered form.

- [ ] **Step 5: Run tests and commit**

Run: `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite Root15`

Expected: PASS.

```powershell
git add src/Root15.ps1 src/Verification.ps1 tests/Run-Tests.ps1
git commit -m "feat: add Android 15 built-in root workflow"
```

---

### Task 8: Add selected-app root concealment

**Files:**
- Create: `src/Concealment.ps1`
- Modify: `src/Manifest.ps1`
- Modify: `tests/Run-Tests.ps1`

**Interfaces:**
- Produces `Install-ConcealmentDependencies -Instance <object> -VerifiedClone <object> -Manifest <object> -Journal <object> [-CacheRoot <string>] [-Runner <scriptblock>]` returning installed/already-present dependency IDs. `-VerifiedClone` is the verified clone record the root flow returns: without it the call returns `CLONE_REQUIRED` before any guest request, and a supplied record is revalidated against the MuMu manager, the reported clone identity, the selected instance's Android version, the installation boundary, and the clone disk before anything is installed. `-CacheRoot` defaults to the per-user dependency cache, and the call is cached-only, so a mutating phase can never download a dependency.
- Produces `Get-HmaConfig -Instance <object> [-TargetIndex <int>] [-Runner <scriptblock>]` returning a parsed HMA configuration or a schema error. `-TargetIndex` selects the instance to read so a read and a write can never disagree about the target. An invalid instance or manager is a `CriticalError` and never asks the operator to configure the UI; a configuration that cannot be read at all, and a genuine schema mismatch, both become the supported-UI `Warning` handoff, and that handoff carries the reader's own reason and the version it found.
- Produces `New-ReusableRootTemplate -Instance <object> -Journal <object> [-TargetIndex <int>] [-Runner <scriptblock>]` returning a verified HMA template record, including only the installed members of the four required root packages.
- Produces `Set-AppConcealment -Instance <object> -VerifiedClone <object> -Packages <string[]> -Journal <object> [-Runner <scriptblock>]` returning per-package status. The configuration backup is read back and compared by byte length and SHA-256 before the original is overwritten, and a configuration the serializer would truncate is refused instead of written.
- Produces `Test-Concealment -ManagerPath <string> -InstanceIndex <int> -Packages <string[]> [-Runner <scriptblock>]` returning HMA scope and KernelSU profile evidence. `Success` requires a stored blacklist `Root` template with a nonempty app list and every requested app assigned to it; otherwise it reports `TEMPLATE_MISSING`, `TEMPLATE_NOT_BLACKLIST`, or `SCOPE_INCOMPLETE`, and it never reports a root package it did not observe installed.

- [ ] **Step 1: Write failing concealment tests**

Use a fixture with packages `org.frknkrc44.hma_oss`, `io.github.huskydg.magisk`, `com.coderstory.toolkit`, and `me.weishu.kernelsu`. Assert that the reusable Root template includes all four, only selected apps receive the template, and an unknown HMA config version returns a safe UI-handoff warning.

```powershell
$template = New-ReusableRootTemplate -Instance $concealmentFixture -TargetIndex $cloneIndex -Journal $journal
Assert-True (@($template.Data.TemplatePackages) -contains 'me.weishu.kernelsu') 'KernelSU was omitted from the Root template.'
$selected = Set-AppConcealment -Instance $concealmentFixture -VerifiedClone $clone -Packages @('jp.pokemon.pokemontcgp') -Journal $journal
Assert-True ($selected.Status -eq 'Success') 'Selected app concealment failed.'
Assert-True (@($selected.Data.Packages) -contains 'jp.pokemon.pokemontcgp') 'The selected app is missing from the result.'
```

The read-only template check takes `-TargetIndex` so it inspects the same instance the apply will change, and the apply takes the verified clone record from the root flow. Every public result is the canonical `Get-ToolkitResult` envelope, so the records live under `Data`.

- [ ] **Step 2: Run concealment tests and verify failure**

Run: `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite Concealment`

Expected: FAIL because concealment functions do not exist.

- [ ] **Step 3: Implement verified HMA and Vector installation**

Download only manifest assets before elevation, verify size and SHA-256, install the HMA APK and Vector ZIP through the selected instance's manager/ADB path, and record package/module state. If a dependency cannot be verified, return `CriticalError` without installing a different artifact. Acquisition and mutation are separate phases: the pinned assets are fetched and verified through the manifest asset helper in a non-mutating phase, and the install call is cached-only, so a mutating concealment call can never reach the network.

```powershell
function Install-ConcealmentDependencies {
    param([object]$Instance, [object]$VerifiedClone, [object]$Manifest, [object]$Journal)
    $hma = Get-VerifiedAsset -Manifest $Manifest -Id 'hma' -CacheRoot $Instance.CacheRoot
    $vector = Get-VerifiedAsset -Manifest $Manifest -Id 'vector' -CacheRoot $Instance.CacheRoot
    if ($hma.Status -ne 'Success' -or $vector.Status -ne 'Success') {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Concealment dependency verification failed.'
    }
    return Get-ToolkitResult -Status 'Success' -Message 'Concealment dependencies verified.' -Data @{ Hma = $hma.Data; Vector = $vector.Data }
}
```

- [ ] **Step 4: Implement schema-checked HMA template configuration**

Back up HMA configuration before editing. Accept only `configVersion=93`; create or update a blacklist `Root` template containing the installed root-related packages, including `me.weishu.kernelsu`. Apply the template only to explicitly selected packages. If the schema is unknown, return a warning with the exact supported-UI steps and do not write the file.

```powershell
function New-ReusableRootTemplate {
    param([object]$Instance, [object]$Journal, [int]$TargetIndex)
    $packages = @('org.frknkrc44.hma_oss','io.github.huskydg.magisk','com.coderstory.toolkit','me.weishu.kernelsu')
    $existing = @((Get-HmaConfig -Instance $Instance).templates.Root.appList)
    $merged = @($existing + $packages | Select-Object -Unique)
    return [pscustomobject]@{ Name = 'Root'; IsWhitelist = $false; Packages = $merged }
}
```

- [ ] **Step 5: Implement the KernelSU profile handoff**

For each selected package, open or instruct the user to open KernelSU Superuser, select the package, keep Superuser disabled, choose `Custom`, and enable `Umount modules`. Do not edit the binary `.allowlist` file. After the handoff, verify the package appears in the profile UI or manager state and record the result.

```powershell
function Get-KernelSUProfileSteps {
    param([string]$PackageName)
    return @(
        "Open KernelSU Superuser and select $PackageName.",
        'Keep Superuser disabled.',
        'Choose Custom and enable Umount modules.'
    )
}
```

- [ ] **Step 6: Add abuse and negative tests**

Cover package-name validation, duplicate packages, a package that is not installed, an unknown HMA schema, missing HMA/Vector, and a user selecting all apps. The function must never apply a template globally without an explicit package list.

- [ ] **Step 7: Run tests and commit**

Run: `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite Concealment`

Expected: PASS for selected-app scope, four-package template, unknown-schema handoff, and negative cases.

```powershell
git add src/Concealment.ps1 src/Manifest.ps1 tests/Run-Tests.ps1
git commit -m "feat: add selected-app root concealment"
```

---

### Task 9: Implement verification and the persistent menu controller

**Files:**
- Modify: `src/Verification.ps1`
- Create: `src/Invoke-MumuToolkit.ps1`
- Create: `Run-MumuToolkit.bat`
- Modify: `src/Common.ps1`
- Modify: `tests/Run-Tests.ps1`

**Interfaces:**
- Produces `Get-ToolkitReport -Install <object> -Instance <object> -Journal <object>` returning a read-only report object, added to the `src/Verification.ps1` that Task 7 created with the shared read-only primitives.
- Produces `Invoke-ToolkitAction -Action <string>` dispatching one named operation and returning its structured result.
- Produces `Invoke-MenuAction -Action <string> [-Runner <scriptblock>]` returning one structured action result and never throwing into the interactive loop.
- `Invoke-MumuToolkit.ps1` accepts `-Action`, `-InstanceIndex`, `-NonInteractive`, and `-SkipToolbar`, dispatches one action, and keeps the menu alive after action errors. `-Action` is honored only together with `-NonInteractive`; without it the launcher opens the menu and ignores the action.
- `Run-MumuToolkit.bat` invokes PowerShell without self-elevating and leaves the window open when the controller returns an interactive error.
- The `RemoveAds` and `Restore` actions pass the selected installation's campaign root to `Restore-MuMuAds -AllowedRoot`; the boundary always comes from the selected install and never from a restore-point manifest, and a restore that cannot resolve one is refused rather than run without a boundary.

- [ ] **Step 1: Write failing menu and report tests**

Assert that a recoverable error returns to the menu, a critical error is displayed with a log path and does not run the next action, a read-only report does not mutate files, and a noninteractive command returns a nonzero exit code.

```powershell
$first = Invoke-MenuAction -Action 'Detect' -Runner $fakeMenuRunner
Assert-True ($first.Status -eq 'Success') 'Detect action failed.'
$error = Invoke-MenuAction -Action 'Root12' -Runner $fakeRecoverableRunner
Assert-True ($error.Status -eq 'RecoverableError') 'Recoverable error was not returned to the menu.'
$report = Get-ToolkitReport -Install $fixtureInstall -Instance $fixtureInstance -Journal $journal
Assert-True ($report.Mutated -eq $false) 'Verification report mutated state.'
```

- [ ] **Step 2: Run menu tests and verify failure**

Run: `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite Menu`

Expected: FAIL because the controller and report do not exist.

- [ ] **Step 3: Implement the report**

Collect fresh manager version, installation path, edition, instance version, running state, VT/Hyper-V state, root settings, package state, daemon state, HMA/Vector state, ad state, backup state, and journal state. Do not change any setting during report generation.

```powershell
function Get-ToolkitReport {
    param([object]$Install, [object]$Instance, [object]$Journal)
    $info = Get-MuMuInstances -Install $Install -ManagerPath $Install.ManagerPath
    return [pscustomobject]@{
        Install = $Install
        Instance = $Instance
        Instances = @($info)
        VT = (Get-CimInstance Win32_ComputerSystem).HypervisorPresent
        HyperV = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' -ErrorAction SilentlyContinue).EnableVirtualizationBasedSecurity
        JournalState = $Journal.State
        Mutated = $false
    }
}
```

- [ ] **Step 4: Implement the persistent controller**

Use a `while ($true)` menu loop. Each action is wrapped in `try/catch/finally`; the catch converts exceptions into structured results, writes a redacted log entry, prints recovery guidance, and returns to the menu. `Q` exits normally. `NonInteractive` maps `Success` and `AlreadyApplied` to exit code `0`, warnings to `0` with output, recoverable errors to `2`, and critical errors to `1`.

```powershell
function Invoke-MenuAction {
    param([string]$Action, [scriptblock]$Runner = $null)
    try {
        if ($null -ne $Runner) { return & $Runner $Action }
        return Invoke-ToolkitAction -Action $Action
    } catch {
        return Get-ToolkitResult -Status 'CriticalError' -Message $_.Exception.Message
    }
}
```

- [ ] **Step 5: Implement the launcher**

`Run-MumuToolkit.bat` must only resolve its own directory, invoke `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File src\Invoke-MumuToolkit.ps1`, propagate the exit code, and pause only when an interactive launch fails. It must not contain encoded commands, downloaders, persistence, or self-elevation logic.

```bat
@echo off
setlocal
set "ROOT=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%ROOT%src\Invoke-MumuToolkit.ps1" %*
set "CODE=%ERRORLEVEL%"
if not "%CODE%"=="0" pause
exit /b %CODE%
```

- [ ] **Step 6: Run the full fixture suite and parser checks**

Run: `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite All`

Expected: all suites PASS and the runner prints `ALL TESTS PASSED`.

Run: `powershell.exe -NoProfile -Command "Get-ChildItem -Recurse -Filter *.ps1 | ForEach-Object { [System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$null,[ref]$null) | Out-Null }; 'POWERSHELL_PARSE_OK'"`

Expected: `POWERSHELL_PARSE_OK`.

- [ ] **Step 7: Commit**

```powershell
git add Run-MumuToolkit.bat src/Invoke-MumuToolkit.ps1 src/Verification.ps1 src/Common.ps1 tests/Run-Tests.ps1
git commit -m "feat: add persistent menu and verification"
```

---

### Task 10: Add documentation, CI, and publishing safeguards

**Files:**
- Create: `README.md`
- Create: `NOTICE.md`
- Create: `LICENSE`
- Create: `.github/workflows/test.yml`
- Modify: `.gitignore`
- Test: `tests/Run-Tests.ps1`

**Interfaces:**
- Produces a documented command surface for `Detect`, `Verify`, `Root12`, `Root15`, `Conceal`, `RemoveAds`, and `Restore`. `Root12` is menu-only, because the noninteractive dispatcher carries no confirmation token for the Kitsune system-partition choice.
- Produces a clean-room attribution file naming the original project and all upstream dependencies without implying endorsement.

- [ ] **Step 1: Write failing documentation checks**

Add tests that require README links for the tested versions, require the exact Kitsune system-partition phrase, require the Global/Chinese support statement, require the UAC limitation, and reject copied original asset names or original README text markers.

```powershell
$readme = Get-Content -LiteralPath (Join-Path $repoRoot 'README.md') -Raw
foreach ($url in @(
    'https://www.mumuplayer.com/download/',
    'https://github.com/Jordan231111/KitsuneMagisk/releases/tag/v31.0-25fa2159',
    'https://github.com/frknkrc44/HMA-OSS/releases/tag/oss-161',
    'https://github.com/JingMatrix/Vector/releases/tag/v2.0',
    'https://github.com/JingMatrix/NeoZygisk/releases/tag/v2.3',
    'https://github.com/LSPosed/CorePatch/releases/tag/4.9'
)) { Assert-True ($readme.Contains($url)) "README is missing tested link: $url" }
Assert-True ($readme -match 'Direct Install into system partition') 'README lacks the exact Kitsune choice.'
Assert-True ($readme -match 'Global.*Chinese') 'README does not state supported editions.'
```

The Vector release page is the canonical `JingMatrix/Vector` URL that the manifest pins; the older
`JingMatrix/LSPosed` release path only redirects to it. Bind the Kitsune phrase assertion to
`$script:ToolkitKitsuneChoice` from `src/Root12.ps1` after the module is loaded, so the check
cannot drift from the product constant, and bind the documented action set to
`$script:ToolkitActions` with a negative assertion for `DryRun`, `Backup`, and `Hide`.
`-Action` is honored only together with `-NonInteractive`, and `Root12` is menu-only, so every
documented example must be accurate about both.

- [ ] **Step 2: Run documentation tests and verify failure**

Run: `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite Docs`

Expected: FAIL because README, NOTICE, and LICENSE do not exist.

- [ ] **Step 3: Write clean-room documentation**

README must state supported versions, tested links, setup order, exact Kitsune instruction, UAC behavior, backup-first behavior, per-app concealment, ad scope, restore instructions, and limitations. NOTICE must credit `Jordan231111/mumu-magisk-1click` and upstream authors without copying their prose. LICENSE must contain the MIT text.

- [ ] **Step 4: Add the Windows CI workflow**

The workflow must checkout the repository, run PowerShell parser checks, run `tests\Run-Tests.ps1 -Suite All`, and upload no logs containing user paths. It must not install MuMu, download dependencies, or run live mutations.

- [ ] **Step 5: Run documentation and full tests**

Run: `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite Docs`

Expected: PASS.

Run: `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite All`

Expected: `ALL TESTS PASSED`.

Run: `git diff --check`

Expected: no output and exit code `0`.

- [ ] **Step 6: Commit**

```powershell
git add README.md NOTICE.md LICENSE .gitignore .github/workflows/test.yml tests/Run-Tests.ps1
git commit -m "docs: add clean-room usage and CI safeguards"
```

---

### Task 11: Qualify against a disposable MuMu instance and prepare publication

**Files:**
- Modify: `src/Manifest.json` only if a qualified asset hash changes.
- Modify: `README.md` only if the live qualification report changes the tested-version statement.
- Create: `docs/qualification-report.md` only if the user explicitly requests a report artifact.

**Interfaces:**
- Produces a read-only qualification result for one Android 12 instance and one Android 15 instance.
- Produces a read-only `Target Identify` result naming the qualified target index, name, edition, and Android version.
- Produces a clean Git working tree and a user-provided remote for publication.

- [ ] **Step 1: Qualify target selection before any root work**

Target selection is a prerequisite, so it is qualified first and in this order:

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File src\Invoke-MumuToolkit.ps1 -Action Target -Mode Identify -NonInteractive
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File src\Invoke-MumuToolkit.ps1 -Action Target -Mode Create -StartIndex 5 -Confirmed -NonInteractive
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File src\Invoke-MumuToolkit.ps1 -Action Target -Mode Clone -SourceIndex 2 -Confirmed -NonInteractive
```

`-SourceIndex` names the clone source directly; `-InstanceIndex` is the equivalent form and is what
Identify reports, so `-Mode Clone -InstanceIndex 2` selects the same source. Use the index the
`Create` run reported as `Index`, never the requested `-StartIndex` value.

Expected: `Identify` exits `0`, lists every discovered instance with its index, name, Android version, running state, and eligibility, and issues no manager command other than `info` and `setting`. `Create` and `Clone` exit `0` only after the explicit confirmation, add exactly one instance, and return a verified non-base instance with a readable Android version and a usable disk. Confirm that the noninteractive dispatcher never prompts and never auto-confirms: a `Target` run without `-Mode` returns `TARGET_MODE_REQUIRED`, and `Create` or `Clone` without `-Confirmed` changes nothing. Confirm that a refused `Create` over an existing `-StartIndex` index issues no `create` command, that an ambiguous new-index report is refused, and that no other instance is deleted, renamed, or changed. Record the reported target index; the later steps use it as `-InstanceIndex`. No root or concealment work runs in this step.

- [ ] **Step 2: Run a read-only preflight**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File src\Invoke-MumuToolkit.ps1 -Action Detect -NonInteractive
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File src\Invoke-MumuToolkit.ps1 -Action Verify -NonInteractive
```

Expected: both commands exit `0`, list the discovered installation and instances, report the read-only status, and change nothing inside MuMu. They do create the toolkit state directory under `%LOCALAPPDATA%`, and a warning-level report appends a redacted line to the toolkit log. There is no `DryRun` action; `Verify` is the read-only action. Pass `-InstallRoot` or `-InstanceIndex` if more than one installation or eligible instance is discovered, because a noninteractive run refuses to guess.

- [ ] **Step 3: Qualify a disposable Android 12 clone**

Run the interactive `Root12` action on a disposable Android 12 instance. It is the clone-first step: it stops the selected instance only to clone it, creates and verifies the clone, and reconfigures only that clone. Confirm that the workflow stops with `USER_CONFIRMATION_REQUIRED` when run as `-Action Root12 -NonInteractive`, that the menu pauses for the exact Kitsune choice `Install -> Direct Install into system partition`, and that the menu stays available after a recoverable error.

Expected: the clone boots, Kitsune root verification passes on the clone, the verified clone remains available, and neither the selected instance nor any other instance is changed.

- [ ] **Step 4: Qualify a disposable Android 15 clone**

Run the interactive `Root15` action, or `-Action Root15 -Confirmed -NonInteractive`, on a disposable Android 15 instance. It is also clone-first. Confirm that the built-in root toggle is used on the verified clone only, that KernelSU verification passes, that Kitsune is not downloaded, and that Hyper-V/VBS settings are unchanged.

Expected: Android 15 root verification passes on the clone without a Kitsune installation, and the same verified clone record then allows `Conceal`.

- [ ] **Step 5: Qualify concealment and ads**

Use a test package selected explicitly by the user. Verify HMA scope, KernelSU `Umount modules`, backup and restore of MuMu campaign data, and exact file restoration.

Expected: only the selected package is concealed and campaign bytes restore exactly.

- [ ] **Step 6: Run final verification**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite All
git diff --check
git status --short
git log --oneline -10
```

Expected: all tests pass, `git diff --check` is clean, and the working tree contains no uncommitted files.

- [ ] **Step 7: Prepare the remote without inventing credentials**

Ask the user for the GitHub owner and an existing empty repository URL or an authenticated `gh` session. Set the remote only after receiving it, run `git remote -v`, inspect the exact branch and commits, and never print or store a token.

- [ ] **Step 8: Commit any final manifest qualification change**

If and only if a dependency hash or tested-version statement changed:

```powershell
git add src/Manifest.json README.md
git commit -m "chore: record qualified dependency pins"
```

Do not create an empty commit when no file changed.

---

## Plan Self-Review

- **Spec coverage:** Tasks 1-2 cover manifest pins, clean-room boundaries, journaling, redaction, structured results, and retries. Tasks 3-4 cover arbitrary paths, Global/Chinese discovery, explicit selection, UAC, clone verification, and file backups. Task 5 covers reversible MuMu-only ads. Task 6 covers the exact Android 12 system-partition flow. Task 7 covers Android 15 built-in KernelSU. Task 8 covers selected-app HMA/KernelSU concealment. Task 9 covers the persistent menu and verification. Task 10 covers tested links, attribution, MIT licensing, and CI. Task 11 covers target selection, disposable live qualification, and remote publication.
- **Completeness scan:** No unresolved markers or vague implementation steps remain. Every task names exact files, interfaces, commands, expected outcomes, and a commit.
- **Type consistency:** `Get-ToolkitResult` is the common result shape; `Journal`, `Instance`, `Manifest`, and `ToolkitReport` names are reused consistently. Root12 and Root15 are separate version-specific functions. `Set-AppConcealment` consumes explicit package strings and never applies globally.
- **Scope check:** The plan is one cohesive toolkit with shared discovery, backup, journal, and verification primitives. It does not split into unrelated projects.
- **Security check:** Hash verification, no post-UAC downloads, structured process arguments, fail-closed clone/root states, no UAC bypass, no ACL weakening, no network blocking, and no secret logging are explicit tasks and tests.
- **Clean-room check:** No task copies original source or assets. Runtime downloads use official GitHub release assets, and NOTICE credits upstream projects.
