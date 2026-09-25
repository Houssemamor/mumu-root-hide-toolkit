$script:ToolkitCampaignRestorePointFile = 'restore-point.json'
$script:ToolkitCampaignListProperties = @('campaigns', 'campaign_list', 'list')
$script:ToolkitCampaignRelativePaths = @{
    Global = @('shell\ad\campaign.json', 'nx_device\configs\campaign.json')
    Chinese = @('MuMuPlayer\ad\campaign.json', 'shell\ad\campaign.json')
}
$script:ToolkitCampaignJsonDepth = 20

function New-MuMuAdFailure {
    param(
        [object]$Journal,
        [string]$Message
    )

    $message = Protect-ToolkitText $Message
    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = 'MuMu advertisement suppression failed.'
    }
    $result = Get-ToolkitResult -Status 'CriticalError' -Message $message
    $journalState = $null
    if ($null -ne $Journal -and $null -ne $Journal.PSObject -and $null -ne $Journal.PSObject.Properties['State']) {
        $journalState = $Journal.State
    }
    if ($journalState -ne 'Running') {
        return $result
    }
    try {
        Write-JournalEvent -Journal $Journal -Level 'Error' -Message $message -Data $null
        Fail-OperationJournal -Journal $Journal -Result $result
    }
    catch {
        return Get-ToolkitResult -Status 'CriticalError' -Message ($message + ' The failure could not be journaled.')
    }
    return $result
}

function Assert-MuMuAdJournal {
    param(
        [AllowNull()]
        [object]$Journal
    )

    if ($null -eq $Journal) {
        throw 'A MuMu advertisement journal is required.'
    }
    Assert-OperationJournal $Journal
}

function Assert-ToolkitCampaignBackupRoot {
    param([string]$BackupRoot)

    if ([string]::IsNullOrWhiteSpace($BackupRoot)) {
        throw 'A campaign backup root is required.'
    }
    $root = ConvertTo-ToolkitFullPath -Path $BackupRoot
    if ($null -eq $root) {
        throw 'The campaign backup root path is invalid.'
    }
    try {
        $item = Get-Item -LiteralPath $root -Force -ErrorAction Stop
    }
    catch {
        throw 'The campaign backup root is unavailable.'
    }
    if ($item -isnot [IO.DirectoryInfo]) {
        throw 'The campaign backup root is not a directory.'
    }
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw 'The campaign backup root is a reparse point such as a junction or symbolic link.'
    }
    return $root
}

function Get-CampaignText {
    param([byte[]]$Bytes)

    $utf8 = New-Object Text.UTF8Encoding($false, $true)
    $text = $null
    try {
        $text = $utf8.GetString($Bytes)
    }
    catch {
        $text = $null
    }
    if ($null -ne $text) {
        if ($text.Length -gt 0 -and $text[0] -eq [char]0xfeff) {
            $text = $text.Substring(1)
        }
        return [pscustomobject]@{ Encoding = $utf8; Text = $text }
    }
    $fallback = [Text.Encoding]::Default
    $fallbackText = $fallback.GetString($Bytes)
    if ([Convert]::ToBase64String($fallback.GetBytes($fallbackText)) -cne [Convert]::ToBase64String($Bytes)) {
        return $null
    }
    return [pscustomobject]@{ Encoding = $fallback; Text = $fallbackText }
}

function ConvertFrom-CampaignJson {
    param([string]$Text)

    $document = $Text | ConvertFrom-Json -ErrorAction Stop
    if ($null -eq $document -or $document -is [string] -or $document -is [ValueType]) {
        throw 'Campaign document is malformed.'
    }
    $trimmed = $Text.TrimStart()
    if ($trimmed.Length -gt 0 -and $trimmed[0] -eq [char]'[') {
        return , @($document)
    }
    return $document
}

function Get-CampaignRecords {
    param([object]$Document)

    if ($Document -is [Array]) {
        return , @($Document)
    }
    foreach ($propertyName in $script:ToolkitCampaignListProperties) {
        $property = $Document.PSObject.Properties[$propertyName]
        if ($null -ne $property -and $property.Value -is [Array]) {
            return , @($property.Value)
        }
    }
    return $null
}

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

function Set-CampaignFileContent {
    param(
        [string]$Path,
        [string]$Text,
        [System.Text.Encoding]$Encoding,
        [System.IO.FileAttributes]$OriginalAttributes
    )

    $temporaryPath = Join-Path ([IO.Path]::GetDirectoryName($Path)) ('.' + [IO.Path]::GetFileName($Path) + '.' + [Guid]::NewGuid().ToString('N') + '.tmp')
    $replacedPath = $temporaryPath + '.bak'
    $original = [int]$OriginalAttributes
    $writable = [IO.FileAttributes]($original -band (-bnot [int][IO.FileAttributes]::ReadOnly))
    $createdTemporary = $false
    try {
        [IO.File]::WriteAllText($temporaryPath, $Text, $Encoding)
        $createdTemporary = $true
        [IO.File]::SetAttributes($temporaryPath, $writable)
        if (($original -band [int][IO.FileAttributes]::ReadOnly) -ne 0) {
            [IO.File]::SetAttributes($Path, $writable)
        }
        [IO.File]::Replace($temporaryPath, $Path, $replacedPath)
        $createdTemporary = $false
        [IO.File]::SetAttributes($Path, [IO.FileAttributes]$original)
    }
    catch {
        $replacementFailure = Protect-ToolkitText ([string]$_.Exception.Message)
        if ($createdTemporary -and [IO.File]::Exists($temporaryPath)) {
            try {
                [IO.File]::Delete($temporaryPath)
            }
            catch {
            }
        }
        try {
            if ([IO.File]::Exists($Path)) {
                [IO.File]::SetAttributes($Path, [IO.FileAttributes]$original)
            }
        }
        catch {
        }
        return Get-ToolkitResult -Status 'CriticalError' -Message "Campaign replacement failed: $replacementFailure"
    }
    if ([IO.File]::Exists($replacedPath)) {
        try {
            [IO.File]::Delete($replacedPath)
        }
        catch {
            return Get-ToolkitResult -Status 'CriticalError' -Message ("Campaign replacement failed: " + (Protect-ToolkitText ([string]$_.Exception.Message)) + ' The campaign backup was kept.')
        }
    }
    return Get-ToolkitResult -Status 'Success' -Message 'Campaign file was replaced atomically.'
}

function Write-CampaignRestorePoint {
    param(
        [string]$Path,
        [string]$Text
    )

    $created = $false
    try {
        $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $created = $true
        try {
            $bytes = (New-Object Text.UTF8Encoding($false, $true)).GetBytes($Text)
            $stream.Write($bytes, 0, $bytes.Length)
            $stream.Flush()
        }
        finally {
            $stream.Dispose()
        }
    }
    catch {
        if ($created -and [IO.File]::Exists($Path)) {
            try {
                [IO.File]::Delete($Path)
            }
            catch {
            }
        }
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The campaign restore point manifest could not be written.'
    }
    return Get-ToolkitResult -Status 'Success' -Message 'The campaign restore point manifest was written.'
}

function Get-MuMuCampaignPaths {
    param([object]$Install)

    if ($null -eq $Install -or $Install -is [Array] -or $Install -isnot [pscustomobject]) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Install is invalid.'
    }
    $editionProperty = $Install.PSObject.Properties['Edition']
    if ($null -eq $editionProperty -or $editionProperty.Value -isnot [string] -or
        $script:ToolkitCampaignRelativePaths.Keys -cnotcontains [string]$editionProperty.Value) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Install.Edition is invalid.'
    }
    $installRootProperty = $Install.PSObject.Properties['InstallRoot']
    if ($null -eq $installRootProperty -or $installRootProperty.Value -isnot [string] -or
        [string]::IsNullOrWhiteSpace($installRootProperty.Value)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Install.InstallRoot is required.'
    }
    $installRoot = ConvertTo-ToolkitFullPath -Path $installRootProperty.Value
    if ($null -eq $installRoot -or -not (Test-Path -LiteralPath $installRoot -PathType Container)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Install.InstallRoot is unavailable.'
    }

    $campaignPaths = @{}
    foreach ($relativePath in @($script:ToolkitCampaignRelativePaths[[string]$editionProperty.Value])) {
        $candidate = ConvertTo-ToolkitFullPath -Path (Join-Path $installRoot $relativePath)
        if ($null -eq $candidate -or -not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            continue
        }
        if (-not (Test-ToolkitPathWithinRoot -Path $candidate -Root $installRoot)) {
            continue
        }
        try {
            $item = Get-Item -LiteralPath $candidate -Force -ErrorAction Stop
        }
        catch {
            continue
        }
        if ($item -isnot [IO.FileInfo] -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            continue
        }
        $campaignPaths[$candidate.ToUpperInvariant()] = $candidate
    }
    return Get-ToolkitResult -Status 'Success' -Message 'MuMu campaign files were located.' -Data (@($campaignPaths.Values | Sort-Object))
}

function Suppress-MuMuAds {
    param(
        [string[]]$Paths,
        [string]$BackupRoot,
        [object]$Journal
    )

    try {
        Assert-MuMuAdJournal -Journal $Journal
    }
    catch {
        return New-MuMuAdFailure -Journal $null -Message 'The MuMu advertisement journal is invalid.'
    }
    $backupRootPath = $null
    try {
        $backupRootPath = Assert-ToolkitCampaignBackupRoot -BackupRoot $BackupRoot
    }
    catch {
        return New-MuMuAdFailure -Journal $Journal -Message ([string]$_.Exception.Message)
    }

    $campaignPaths = @()
    $seenPaths = @{}
    foreach ($path in @($Paths)) {
        if ($path -isnot [string] -or [string]::IsNullOrWhiteSpace($path)) {
            return New-MuMuAdFailure -Journal $Journal -Message 'A campaign path is invalid.'
        }
        $fullPath = ConvertTo-ToolkitFullPath -Path $path
        if ($null -eq $fullPath) {
            return New-MuMuAdFailure -Journal $Journal -Message 'A campaign path is invalid.'
        }
        if ($seenPaths.ContainsKey($fullPath.ToUpperInvariant())) {
            continue
        }
        $seenPaths[$fullPath.ToUpperInvariant()] = $true
        $campaignPaths += $fullPath
    }
    if ($campaignPaths.Count -eq 0) {
        return Get-ToolkitResult -Status 'AlreadyApplied' -Message 'No MuMu campaign file is present.' -Data (@{ Changed = 0; Skipped = 0; Backups = @() })
    }

    $restorePointPath = Join-Path $backupRootPath $script:ToolkitCampaignRestorePointFile
    if (Test-Path -LiteralPath $restorePointPath) {
        return New-MuMuAdFailure -Journal $Journal -Message 'The campaign backup root already contains a restore point. An existing backup is never overwritten.'
    }

    $changed = 0
    $skipped = 0
    $records = @()
    for ($campaignIndex = 0; $campaignIndex -lt $campaignPaths.Count; $campaignIndex++) {
        $campaignPath = $campaignPaths[$campaignIndex]
        $campaignItem = $null
        try {
            $campaignItem = Assert-ToolkitRegularFile -Path $campaignPath -Label 'Campaign file'
        }
        catch {
            return New-MuMuAdFailure -Journal $Journal -Message ([string]$_.Exception.Message)
        }

        $bytes = $null
        try {
            $bytes = [IO.File]::ReadAllBytes($campaignPath)
        }
        catch {
            return New-MuMuAdFailure -Journal $Journal -Message "Campaign file is unavailable: $campaignPath"
        }
        $decoded = Get-CampaignText -Bytes $bytes
        if ($null -eq $decoded) {
            return New-MuMuAdFailure -Journal $Journal -Message "Campaign file text cannot be rewritten without changing its bytes: $campaignPath"
        }
        $document = $null
        try {
            $document = ConvertFrom-CampaignJson -Text $decoded.Text
        }
        catch {
            $document = $null
        }
        if ($null -eq $document) {
            return New-MuMuAdFailure -Journal $Journal -Message "Campaign file JSON is malformed: $campaignPath"
        }
        $campaigns = Get-CampaignRecords -Document $document
        if ($null -eq $campaigns -or $campaigns.Count -eq 0) {
            return New-MuMuAdFailure -Journal $Journal -Message "Campaign file JSON is incomplete: $campaignPath"
        }
        foreach ($campaign in $campaigns) {
            if ($null -eq $campaign -or $campaign -isnot [pscustomobject]) {
                return New-MuMuAdFailure -Journal $Journal -Message "Campaign file JSON is incomplete: $campaignPath"
            }
        }

        $displayCount = Set-CampaignDisplays -Campaigns $campaigns
        if ($displayCount -eq 0) {
            $skipped++
            continue
        }

        $campaignBackupRoot = [IO.Path]::Combine($backupRootPath, [string]$campaignIndex)
        try {
            [void][IO.Directory]::CreateDirectory($campaignBackupRoot)
        }
        catch {
            return New-MuMuAdFailure -Journal $Journal -Message "A campaign backup directory could not be created: $campaignBackupRoot"
        }
        $backup = Backup-ChangedFile -Path $campaignPath -BackupRoot $campaignBackupRoot
        if ($backup.Status -ne 'Success') {
            return New-MuMuAdFailure -Journal $Journal -Message $backup.Message
        }

        $replacement = Set-CampaignFileContent -Path $campaignPath -Text (ConvertTo-Json -InputObject $document -Depth $script:ToolkitCampaignJsonDepth) -Encoding $decoded.Encoding -OriginalAttributes $campaignItem.Attributes
        if ($replacement.Status -ne 'Success') {
            return New-MuMuAdFailure -Journal $Journal -Message ($replacement.Message + ' The campaign backup was kept.')
        }

        try {
            Write-JournalEvent -Journal $Journal -Level 'Info' -Message "Suppressed $displayCount campaign display flag(s)." -Data ([pscustomobject]@{
                    Path          = $campaignPath
                    Backup        = [string]$backup.Data.Backup
                    DisplayCount  = $displayCount
                })
        }
        catch {
            return New-MuMuAdFailure -Journal $Journal -Message 'A suppressed campaign file could not be journaled.'
        }
        $records += $backup.Data
        $changed++
    }

    if ($changed -gt 0) {
        $restorePoint = [ordered]@{
            SchemaVersion = 1
            Records       = @($records)
        }
        $written = Write-CampaignRestorePoint -Path $restorePointPath -Text ($restorePoint | ConvertTo-Json -Depth 6)
        if ($written.Status -ne 'Success') {
            return New-MuMuAdFailure -Journal $Journal -Message ($written.Message + ' The campaign backups were kept.')
        }
    }

    $status = if ($changed -eq 0) { 'AlreadyApplied' } else { 'Success' }
    return Get-ToolkitResult -Status $status -Message "Suppressed $changed campaign file(s) and skipped $skipped." -Data (@{ Changed = $changed; Skipped = $skipped; Backups = @($records) })
}

function Restore-MuMuAds {
    param(
        [string]$BackupRoot,
        [object]$Journal
    )

    try {
        Assert-MuMuAdJournal -Journal $Journal
    }
    catch {
        return New-MuMuAdFailure -Journal $null -Message 'The MuMu advertisement journal is invalid.'
    }
    $backupRootPath = $null
    try {
        $backupRootPath = Assert-ToolkitCampaignBackupRoot -BackupRoot $BackupRoot
    }
    catch {
        return New-MuMuAdFailure -Journal $Journal -Message ([string]$_.Exception.Message)
    }

    $restorePointPath = Join-Path $backupRootPath $script:ToolkitCampaignRestorePointFile
    if (-not [IO.File]::Exists($restorePointPath)) {
        return New-MuMuAdFailure -Journal $Journal -Message 'The campaign backup root does not contain a complete restore point.'
    }
    $restorePoint = $null
    try {
        $restorePoint = (New-Object Text.UTF8Encoding($false, $true)).GetString([IO.File]::ReadAllBytes($restorePointPath)) | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        $restorePoint = $null
    }
    if ($null -eq $restorePoint -or $restorePoint -is [Array] -or $restorePoint -isnot [pscustomobject]) {
        return New-MuMuAdFailure -Journal $Journal -Message 'The campaign restore point manifest is malformed.'
    }
    $schemaProperty = $restorePoint.PSObject.Properties['SchemaVersion']
    $recordsProperty = $restorePoint.PSObject.Properties['Records']
    if ($null -eq $schemaProperty -or $schemaProperty.Value -isnot [int] -or $schemaProperty.Value -ne 1 -or
        $null -eq $recordsProperty -or $recordsProperty.Value -isnot [Array] -or @($recordsProperty.Value).Count -eq 0) {
        return New-MuMuAdFailure -Journal $Journal -Message 'The campaign restore point manifest is incomplete.'
    }

    $restored = 0
    foreach ($record in @($recordsProperty.Value)) {
        if ($null -eq $record -or $record -isnot [pscustomobject]) {
            return New-MuMuAdFailure -Journal $Journal -Message 'A campaign restore point record is invalid.'
        }
        $backupProperty = $record.PSObject.Properties['Backup']
        $backupPath = $null
        if ($null -ne $backupProperty -and $backupProperty.Value -is [string]) {
            $backupPath = ConvertTo-ToolkitFullPath -Path $backupProperty.Value
        }
        if ($null -eq $backupPath) {
            return New-MuMuAdFailure -Journal $Journal -Message 'A campaign restore point record is invalid.'
        }
        if (-not [IO.File]::Exists($backupPath)) {
            return New-MuMuAdFailure -Journal $Journal -Message "A campaign restore point file is missing: $backupPath"
        }
        if (-not (Test-ToolkitPathWithinRoot -Path $backupPath -Root $backupRootPath)) {
            return New-MuMuAdFailure -Journal $Journal -Message 'A campaign restore point file is outside the campaign backup root.'
        }
        $restore = Restore-BackupFile -BackupRecord $record
        if ($restore.Status -ne 'Success') {
            return New-MuMuAdFailure -Journal $Journal -Message $restore.Message
        }
        $restored++
    }

    $restoreMessage = "Restored $restored campaign file(s) from their restore point."
    try {
        Write-JournalEvent -Journal $Journal -Level 'Info' -Message $restoreMessage -Data (@{ Restored = $restored })
    }
    catch {
        return New-MuMuAdFailure -Journal $Journal -Message 'The restored campaign files could not be journaled.'
    }
    return Get-ToolkitResult -Status 'Success' -Message $restoreMessage -Data (@{ Restored = $restored })
}
