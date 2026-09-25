if (-not (Test-Path variable:script:ToolkitBootPollAttempts)) {
    $script:ToolkitBootPollAttempts = 30
}
if (-not (Test-Path variable:script:ToolkitBootPollDelaySeconds)) {
    $script:ToolkitBootPollDelaySeconds = 3
}

function Invoke-ToolkitManagerAdb {
    param(
        [string]$ManagerPath,
        [int]$InstanceIndex,
        [Parameter(Mandatory = $true)]
        [string]$Command,
        [scriptblock]$Runner = $null
    )

    return Invoke-CheckedProcess -FilePath $ManagerPath -ArgumentList @('adb', '-v', ([string]$InstanceIndex), '-c', $Command) -Runner $Runner
}

function Wait-ToolkitBootCompleted {
    param(
        [string]$ManagerPath,
        [int]$InstanceIndex,
        [scriptblock]$Runner = $null
    )

    for ($attempt = 1; $attempt -le $script:ToolkitBootPollAttempts; $attempt++) {
        $probe = Invoke-ToolkitManagerAdb -ManagerPath $ManagerPath -InstanceIndex $InstanceIndex -Command 'shell getprop sys.boot_completed' -Runner $Runner
        if ($null -ne $probe -and $probe.ExitCode -eq 0 -and ([string]$probe.Text).Trim() -ceq '1') {
            return $true
        }
        if ($attempt -lt $script:ToolkitBootPollAttempts) {
            Start-Sleep -Seconds $script:ToolkitBootPollDelaySeconds
        }
    }
    return $false
}

function Get-ToolkitRootSetting {
    param(
        [string]$ManagerPath,
        [int]$Index,
        [scriptblock]$Runner = $null
    )

    $manager = ConvertTo-ToolkitFullPath -Path $ManagerPath
    if ($null -eq $manager -or $Index -lt 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The vendor root setting manager is invalid.' -Data (@{ Code = 'MANAGER_UNAVAILABLE' })
    }

    $result = Invoke-CheckedProcess -FilePath $manager -ArgumentList @('setting', '-v', ([string]$Index), '-k', 'root_permission') -Runner $Runner
    if ($null -eq $result -or $result.ExitCode -ne 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The MuMu manager did not report the vendor root setting.' -Data (@{ Code = 'MANAGER_FAILED' })
    }
    $text = [string]$result.Text
    if ([string]::IsNullOrWhiteSpace($text)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The vendor root setting response is empty.' -Data (@{ Code = 'MANAGER_JSON_INVALID' })
    }
    try {
        $parsed = $text | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The vendor root setting response is not valid JSON.' -Data (@{ Code = 'MANAGER_JSON_INVALID' })
    }
    if ($null -eq $parsed -or $parsed -is [string] -or $parsed -is [ValueType]) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The vendor root setting response has an unsupported shape.' -Data (@{ Code = 'SHAPE_UNSUPPORTED' })
    }
    if ($parsed -is [Array]) {
        $records = @($parsed)
        if ($records.Count -ne 1) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'The vendor root setting response does not describe exactly one instance.' -Data (@{ Code = 'SHAPE_UNSUPPORTED' })
        }
        $record = $records[0]
    }
    else {
        $record = $parsed
    }
    if ($null -eq $record -or $record -isnot [pscustomobject]) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The vendor root setting response has an unsupported shape.' -Data (@{ Code = 'SHAPE_UNSUPPORTED' })
    }

    $errorCode = Get-ToolkitFirstProperty -InputObject $record -PropertyNames @('error_code', 'errcode')
    if ($null -ne $errorCode -and [string]$errorCode -notin @('0', 'False', 'false')) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The MuMu manager reported an error for the vendor root setting.' -Data (@{ Code = 'MANAGER_ERROR' })
    }
    $indexProperty = $record.PSObject.Properties['index']
    if ($null -ne $indexProperty) {
        $reportedIndex = 0
        if (-not [int]::TryParse([string]$indexProperty.Value, [ref]$reportedIndex) -or $reportedIndex -ne $Index) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'The vendor root setting describes a different instance.' -Data (@{ Code = 'INDEX_MISMATCH' })
        }
    }

    $reportedValue = Get-ToolkitFirstProperty -InputObject $record -PropertyNames @('root_permission', 'rootPermission', 'root_setting', 'rootSetting', 'value')
    if ($null -eq $reportedValue) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The vendor root setting response carries no supported root setting field.' -Data (@{ Code = 'SHAPE_UNSUPPORTED' })
    }
    $value = ConvertTo-ToolkitBoolean -Value $reportedValue
    if ($null -eq $value) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The vendor root setting value is not a supported boolean.' -Data (@{ Code = 'VALUE_INVALID' })
    }
    return Get-ToolkitResult -Status 'Success' -Message 'The vendor root setting was read.' -Data (@{ Code = 'OK'; Index = $Index; Value = [bool]$value })
}

function Get-ToolkitPackageVersion {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Text,
        [string]$PackageName
    )

    if ([string]::IsNullOrWhiteSpace($Text) -or [string]::IsNullOrWhiteSpace($PackageName)) {
        return $null
    }

    $headerPattern = '(?m)^\s*Package \[' + [regex]::Escape($PackageName) + '\](?=[\s(:])'
    if (-not [regex]::IsMatch($Text, $headerPattern)) {
        return $null
    }

    $nameMatch = [regex]::Match($Text, '(?m)^\s*versionName=(\S+)')
    $codeMatch = [regex]::Match($Text, '(?m)^\s*versionCode=(\d+)\b')
    return @{
        VersionName = if ($nameMatch.Success) { $nameMatch.Groups[1].Value } else { '' }
        VersionCode = if ($codeMatch.Success) { $codeMatch.Groups[1].Value } else { '' }
    }
}

function Get-ToolkitRootShellStatus {
    param(
        [AllowNull()]
        [object]$Call
    )

    if ($null -eq $Call -or $Call.ExitCode -eq -1) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The root shell query could not be executed.' -Data (@{ Code = 'ADB_FAILED' })
    }
    if ($Call.ExitCode -eq 0 -and ([string]$Call.Text) -match '(?m)uid=0\(') {
        return Get-ToolkitResult -Status 'Success' -Message 'The root shell returned a root identity.' -Data (@{ Code = 'OK'; RootShell = $true })
    }
    if ($Call.ExitCode -ne 0 -and [string]::IsNullOrWhiteSpace([string]$Call.Text)) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'The root shell query returned no guest output, so a guest refusal cannot be concluded.' -Data (@{ Code = 'ADB_FAILED' })
    }
    return Get-ToolkitResult -Status 'CriticalError' -Message 'The root shell did not return a root identity.' -Data (@{ Code = 'ROOT_DENIED' })
}

function New-ToolkitRootFailure {
    param(
        [object]$Journal,
        [string]$Message,
        [object]$Data = $null
    )

    $message = Protect-ToolkitText $Message
    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = 'The root workflow failed.'
    }
    $result = Get-ToolkitResult -Status 'CriticalError' -Message $message -Data $Data
    $journalState = $null
    if ($null -ne $Journal -and $null -ne $Journal.PSObject -and $null -ne $Journal.PSObject.Properties['State']) {
        $journalState = $Journal.State
    }
    if ($journalState -ne 'Running') {
        return $result
    }
    try {
        Write-JournalEvent -Journal $Journal -Level 'Error' -Message $message -Data $Data
        Fail-OperationJournal -Journal $Journal -Result $result
    }
    catch {
        return Get-ToolkitResult -Status 'CriticalError' -Message ($message + ' The failure could not be journaled.') -Data $Data
    }
    return $result
}
