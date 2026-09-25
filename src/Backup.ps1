$script:ToolkitBackupRecordProperties = @('Source', 'Backup', 'Sha256', 'ReadOnly', 'Length')

function Get-ToolkitFileSha256 {
    param([string]$Path)

    try {
        return [string](Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
    }
    catch {
        return $null
    }
}

function Assert-ToolkitRegularFile {
    param(
        [string]$Path,
        [string]$Label
    )

    $fullPath = ConvertTo-ToolkitFullPath -Path $Path
    if ([string]::IsNullOrWhiteSpace($fullPath)) {
        throw "$Label path is invalid."
    }
    $item = $null
    try {
        $item = Get-Item -LiteralPath $fullPath -Force -ErrorAction Stop
    }
    catch {
        throw "$Label is unavailable."
    }
    if ($item -isnot [IO.FileInfo] -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "$Label is not a regular file."
    }
    return $item
}

function Backup-ChangedFile {
    param(
        [string]$Path,
        [string]$BackupRoot
    )

    $sourceItem = $null
    try {
        $sourceItem = Assert-ToolkitRegularFile -Path $Path -Label 'Backup source'
    }
    catch {
        return Get-ToolkitResult -Status 'CriticalError' -Message (Protect-ToolkitText ([string]$_.Exception.Message))
    }

    $rootItem = $null
    if ([string]::IsNullOrWhiteSpace($BackupRoot)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Backup root is required.'
    }
    $root = ConvertTo-ToolkitFullPath -Path $BackupRoot
    if ($null -eq $root) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Backup root path is invalid.'
    }
    try {
        $rootItem = Get-Item -LiteralPath $root -Force -ErrorAction Stop
    }
    catch {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Backup root is unavailable.'
    }
    if ($rootItem -isnot [IO.DirectoryInfo]) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Backup root is not a directory.'
    }

    $sourcePath = $sourceItem.FullName
    $target = Join-Path $root $sourceItem.Name
    if (Test-Path -LiteralPath $target) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Backup target already exists. An existing backup is never overwritten.'
    }

    $sourceHash = Get-ToolkitFileSha256 -Path $sourcePath
    if ($null -eq $sourceHash) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Backup source could not be hashed.'
    }
    $readOnly = [bool]$sourceItem.IsReadOnly
    $createdTarget = $false
    try {
        $targetStream = [IO.File]::Open($target, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $createdTarget = $true
        try {
            $sourceStream = [IO.File]::Open($sourcePath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
            try {
                $sourceStream.CopyTo($targetStream)
            }
            finally {
                $sourceStream.Dispose()
            }
        }
        finally {
            $targetStream.Dispose()
        }
        [IO.File]::SetAttributes($target, [IO.FileAttributes]::Normal)
    }
    catch {
        $copyFailure = Protect-ToolkitText ([string]$_.Exception.Message)
        if ($createdTarget -and [IO.File]::Exists($target)) {
            try {
                [IO.File]::Delete($target)
            }
            catch {
            }
        }
        return Get-ToolkitResult -Status 'CriticalError' -Message "Backup copy failed: $copyFailure"
    }
    $targetHash = Get-ToolkitFileSha256 -Path $target
    if ($null -eq $targetHash -or -not $targetHash.Equals($sourceHash, [StringComparison]::Ordinal)) {
        if ($createdTarget -and [IO.File]::Exists($target)) {
            try {
                [IO.File]::Delete($target)
            }
            catch {
            }
        }
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Backup copy does not match the source hash.'
    }

    $record = [pscustomobject]@{
        Source = $sourcePath
        Backup = $target
        Sha256 = $sourceHash
        ReadOnly = $readOnly
        Length = [long]$sourceItem.Length
    }
    return Get-ToolkitResult -Status 'Success' -Message 'Changed file was backed up.' -Data $record
}

function Restore-BackupFile {
    param([object]$BackupRecord)

    if ($null -eq $BackupRecord -or $BackupRecord -is [Array] -or $BackupRecord -isnot [pscustomobject]) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Backup record is invalid.'
    }
    $propertyNames = @($BackupRecord.PSObject.Properties | ForEach-Object { $_.Name })
    if ($propertyNames.Count -ne $script:ToolkitBackupRecordProperties.Count) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Backup record is invalid.'
    }
    foreach ($propertyName in $script:ToolkitBackupRecordProperties) {
        if ($propertyNames -cnotcontains $propertyName) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'Backup record is invalid.'
        }
    }
    foreach ($propertyName in @('Source', 'Backup')) {
        $propertyValue = $BackupRecord.PSObject.Properties[$propertyName].Value
        if ($propertyValue -isnot [string] -or [string]::IsNullOrWhiteSpace($propertyValue)) {
            return Get-ToolkitResult -Status 'CriticalError' -Message "Backup record $propertyName is invalid."
        }
    }
    $hashProperty = $BackupRecord.PSObject.Properties['Sha256']
    if ($hashProperty.Value -isnot [string] -or $hashProperty.Value -notmatch '^[0-9a-fA-F]{64}$') {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Backup record Sha256 is invalid.'
    }
    $expectedHash = [string]$hashProperty.Value
    if ($BackupRecord.ReadOnly -isnot [bool]) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Backup record ReadOnly is invalid.'
    }
    if ($BackupRecord.Length -isnot [long] -and $BackupRecord.Length -isnot [int]) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Backup record Length is invalid.'
    }

    $backupItem = $null
    try {
        $backupItem = Assert-ToolkitRegularFile -Path $BackupRecord.Backup -Label 'Backup file'
    }
    catch {
        return Get-ToolkitResult -Status 'CriticalError' -Message (Protect-ToolkitText ([string]$_.Exception.Message))
    }
    $backupPath = $backupItem.FullName
    if ([long]$backupItem.Length -ne [long]$BackupRecord.Length) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Backup file length does not match the backup record.'
    }
    $actualHash = Get-ToolkitFileSha256 -Path $backupPath
    if ($null -eq $actualHash -or -not $actualHash.Equals($expectedHash, [StringComparison]::OrdinalIgnoreCase)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Backup file hash does not match the backup record.'
    }

    $sourcePath = ConvertTo-ToolkitFullPath -Path $BackupRecord.Source
    $targetAttributes = [int][IO.FileAttributes]::Normal
    $targetExists = $false
    if (Test-Path -LiteralPath $sourcePath) {
        $sourceItem = $null
        try {
            $sourceItem = Assert-ToolkitRegularFile -Path $BackupRecord.Source -Label 'Restore target'
        }
        catch {
            return Get-ToolkitResult -Status 'CriticalError' -Message (Protect-ToolkitText ([string]$_.Exception.Message))
        }
        $targetAttributes = [int]$sourceItem.Attributes
        $targetExists = $true
    }
    $targetAttributes = $targetAttributes -band (-bnot [int][IO.FileAttributes]::ReadOnly)
    $readOnlyAttributes = [IO.FileAttributes]($targetAttributes -bor [int][IO.FileAttributes]::ReadOnly)

    try {
        if ($targetExists) {
            [IO.File]::SetAttributes($sourcePath, [IO.FileAttributes]$targetAttributes)
        }
        [IO.File]::Copy($backupPath, $sourcePath, $true)
    }
    catch {
        $restoreFailure = Protect-ToolkitText ([string]$_.Exception.Message)
        if ($BackupRecord.ReadOnly) {
            try {
                [IO.File]::SetAttributes($sourcePath, $readOnlyAttributes)
            }
            catch {
            }
        }
        return Get-ToolkitResult -Status 'CriticalError' -Message "Backup restore failed: $restoreFailure"
    }
    if ($BackupRecord.ReadOnly) {
        try {
            [IO.File]::SetAttributes($sourcePath, $readOnlyAttributes)
        }
        catch {
            $attributeFailure = Protect-ToolkitText ([string]$_.Exception.Message)
            return Get-ToolkitResult -Status 'CriticalError' -Message "Backup restore did not preserve the read-only state: $attributeFailure"
        }
    }
    $restoredHash = Get-ToolkitFileSha256 -Path $sourcePath
    if ($null -eq $restoredHash -or -not $restoredHash.Equals($expectedHash, [StringComparison]::OrdinalIgnoreCase)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'Restored file hash does not match the backup record.'
    }
    return Get-ToolkitResult -Status 'Success' -Message 'File was restored from its backup.'
}
