function Protect-JournalValue {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return $null
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $copy = @{}
        foreach ($key in $Value.Keys) {
            $propertyName = [string]$key
            if ([string]::IsNullOrWhiteSpace($propertyName)) {
                throw 'Journal object key is invalid.'
            }
            $copy[$propertyName] = if ($propertyName -match 'token|password|secret|authorization|cookie|key') {
                '[REDACTED]'
            }
            else {
                Protect-JournalValue $Value[$key]
            }
        }
        return $copy
    }
    if ($Value -is [pscustomobject]) {
        $copy = @{}
        foreach ($property in $Value.PSObject.Properties) {
            if ($property.Name -match 'token|password|secret|authorization|cookie|key') {
                $copy[$property.Name] = '[REDACTED]'
            }
            else {
                $copy[$property.Name] = Protect-JournalValue $property.Value
            }
        }
        return [pscustomobject]$copy
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $copy = @()
        foreach ($item in $Value) {
            $copy += @(Protect-JournalValue $item)
        }
        return ,$copy
    }
    return $Value
}

function Test-JournalValueRedacted {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return $true
    }
    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            $propertyName = [string]$key
            $item = $Value[$key]
            if ($propertyName -match 'token|password|secret|authorization|cookie|key') {
                if ($item -isnot [string] -or $item -cne '[REDACTED]') {
                    return $false
                }
            }
            elseif (-not (Test-JournalValueRedacted $item)) {
                return $false
            }
        }
        return $true
    }
    if ($Value -is [pscustomobject]) {
        foreach ($property in $Value.PSObject.Properties) {
            if ($property.Name -match 'token|password|secret|authorization|cookie|key') {
                if ($property.Value -isnot [string] -or $property.Value -cne '[REDACTED]') {
                    return $false
                }
            }
            elseif (-not (Test-JournalValueRedacted $property.Value)) {
                return $false
            }
        }
        return $true
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($item in $Value) {
            if (-not (Test-JournalValueRedacted $item)) {
                return $false
            }
        }
    }
    return $true
}

function ConvertTo-JournalDateTime {
    param(
        [object]$Value
    )

    if ($Value -is [DateTime]) {
        return ([DateTime]$Value).ToUniversalTime()
    }
    if ($Value -isnot [string] -or [string]::IsNullOrWhiteSpace($Value)) {
        throw 'Journal timestamp is invalid.'
    }
    $parsed = [DateTime]::MinValue
    $styles = [Globalization.DateTimeStyles]::RoundtripKind
    if (-not [DateTime]::TryParse($Value, [Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$parsed)) {
        throw 'Journal timestamp is invalid.'
    }
    return $parsed.ToUniversalTime()
}

function Assert-JournalResult {
    param(
        [AllowNull()]
        [object]$Result
    )

    if ($null -eq $Result) {
        return
    }
    if ($Result -is [Array] -or $Result -isnot [pscustomobject]) {
        throw 'Journal result is invalid.'
    }
    foreach ($propertyName in @('Status', 'Message', 'Data')) {
        if ($null -eq $Result.PSObject.Properties[$propertyName]) {
            throw 'Journal result is invalid.'
        }
    }
    if ($Result.Status -isnot [string] -or
        @('Success', 'AlreadyApplied', 'Warning', 'RecoverableError', 'CriticalError') -cnotcontains $Result.Status -or
        $Result.Message -isnot [string] -or
        [string]::IsNullOrWhiteSpace($Result.Message)) {
        throw 'Journal result is invalid.'
    }
    if (-not (Test-JournalValueRedacted $Result.Data)) {
        throw 'Journal result contains unredacted sensitive data.'
    }
}

function Assert-JournalCheckpoints {
    param(
        [object]$Checkpoints
    )

    if ($Checkpoints -isnot [Array]) {
        throw 'Journal checkpoints are invalid.'
    }
    foreach ($checkpoint in $Checkpoints) {
        if ($null -eq $checkpoint -or $checkpoint -is [Array] -or $checkpoint -isnot [pscustomobject]) {
            throw 'Journal checkpoint is invalid.'
        }
        foreach ($propertyName in @('Timestamp', 'Level', 'Message', 'Data')) {
            if ($null -eq $checkpoint.PSObject.Properties[$propertyName]) {
                throw 'Journal checkpoint is invalid.'
            }
        }
        [void](ConvertTo-JournalDateTime $checkpoint.Timestamp)
        if ($checkpoint.Level -isnot [string] -or
            [string]::IsNullOrWhiteSpace($checkpoint.Level) -or
            $checkpoint.Message -isnot [string] -or
            [string]::IsNullOrWhiteSpace($checkpoint.Message)) {
            throw 'Journal checkpoint is invalid.'
        }
        if (-not (Test-JournalValueRedacted $checkpoint.Data)) {
            throw 'Journal checkpoint contains unredacted sensitive data.'
        }
    }
}

function Assert-OperationJournal {
    param(
        [object]$Journal
    )

    if ($null -eq $Journal -or $Journal -is [Array] -or $Journal -isnot [pscustomobject]) {
        throw 'Journal object is invalid.'
    }
    foreach ($propertyName in @('Id', 'StartedAt', 'State', 'Operation', 'Instance', 'Checkpoints', 'Result', 'JournalPath')) {
        if ($null -eq $Journal.PSObject.Properties[$propertyName]) {
            throw 'Journal object is invalid.'
        }
    }
    if ($Journal.Id -isnot [string] -or $Journal.Id -notmatch '^[a-f0-9]{32}$') {
        throw 'Journal ID is invalid.'
    }
    if ($Journal.State -isnot [string] -or @('Running', 'Completed', 'Failed') -cnotcontains $Journal.State) {
        throw 'Journal state is invalid.'
    }
    if ($Journal.Operation -isnot [string] -or [string]::IsNullOrWhiteSpace($Journal.Operation)) {
        throw 'Journal operation is invalid.'
    }
    if ($Journal.JournalPath -isnot [string] -or
        [string]::IsNullOrWhiteSpace($Journal.JournalPath) -or
        -not [IO.Path]::IsPathRooted($Journal.JournalPath)) {
        throw 'Journal path is invalid.'
    }
    [void](ConvertTo-JournalDateTime $Journal.StartedAt)
    Assert-JournalCheckpoints $Journal.Checkpoints
    Assert-JournalResult $Journal.Result
    if (($Journal.State -eq 'Running' -and $null -ne $Journal.Result) -or
        ($Journal.State -ne 'Running' -and $null -eq $Journal.Result)) {
        throw 'Journal state and result do not match.'
    }
    if (-not (Test-JournalValueRedacted $Journal.Instance)) {
        throw 'Journal instance contains unredacted sensitive data.'
    }
}

function Write-OperationJournal {
    param(
        [object]$Journal
    )

    Assert-OperationJournal $Journal
    $journalPath = [IO.Path]::GetFullPath($Journal.JournalPath)
    $journalDirectory = [IO.Path]::GetDirectoryName($journalPath)
    [void][IO.Directory]::CreateDirectory($journalDirectory)
    $temporaryPath = Join-Path $journalDirectory ('.' + [IO.Path]::GetFileName($journalPath) + '.' + [Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $record = [ordered]@{
            SchemaVersion = 1
            Id = $Journal.Id
            StartedAt = ([DateTime]$Journal.StartedAt).ToUniversalTime().ToString('o', [Globalization.CultureInfo]::InvariantCulture)
            Operation = $Journal.Operation
            Instance = Protect-JournalValue $Journal.Instance
            State = $Journal.State
            Checkpoints = @($Journal.Checkpoints)
            Result = Protect-JournalValue $Journal.Result
        }
        $json = $record | ConvertTo-Json -Depth 20
        $utf8 = [Text.UTF8Encoding]::new($false, $true)
        [IO.File]::WriteAllText($temporaryPath, ($json + [Environment]::NewLine), $utf8)
        Move-Item -LiteralPath $temporaryPath -Destination $journalPath -Force -ErrorAction Stop
    }
    finally {
        if ([IO.File]::Exists($temporaryPath)) {
            Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function New-OperationJournal {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,
        [Parameter(Mandatory = $true)]
        [string]$Operation,
        [object]$Instance
    )

    if ([string]::IsNullOrWhiteSpace($Root) -or [string]::IsNullOrWhiteSpace($Operation)) {
        throw 'Journal root and operation are required.'
    }
    try {
        $rootPath = [IO.Path]::GetFullPath($Root)
    }
    catch {
        throw 'Journal root is invalid.'
    }
    [void][IO.Directory]::CreateDirectory($rootPath)
    $id = [Guid]::NewGuid().ToString('N')
    $journal = [pscustomobject]@{
        Id = $id
        StartedAt = [DateTime]::UtcNow
        State = 'Running'
        Operation = $Operation
        Instance = Protect-JournalValue $Instance
        Checkpoints = @()
        Result = $null
        JournalPath = [IO.Path]::Combine($rootPath, ($id + '.json'))
    }
    Write-OperationJournal $journal
    return $journal
}

function Get-OperationJournal {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'Journal path is required.'
    }
    try {
        $journalPath = [IO.Path]::GetFullPath($Path)
    }
    catch {
        throw 'Journal path is invalid.'
    }
    if (-not [IO.File]::Exists($journalPath)) {
        throw 'Journal file does not exist.'
    }
    try {
        $utf8 = [Text.UTF8Encoding]::new($false, $true)
        $json = [IO.File]::ReadAllText($journalPath, $utf8)
        $record = $json | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw 'Journal JSON is invalid.'
    }
    if ($null -eq $record -or $record -is [Array] -or $record -isnot [pscustomobject]) {
        throw 'Journal root is invalid.'
    }
    $requiredProperties = @('SchemaVersion', 'Id', 'StartedAt', 'Operation', 'Instance', 'State', 'Checkpoints', 'Result')
    $actualProperties = @($record.PSObject.Properties | ForEach-Object { $_.Name })
    if ($actualProperties.Count -ne $requiredProperties.Count) {
        throw 'Journal schema is invalid.'
    }
    foreach ($propertyName in $requiredProperties) {
        if ($actualProperties -cnotcontains $propertyName) {
            throw 'Journal schema is invalid.'
        }
    }
    if (($record.SchemaVersion -isnot [int] -and $record.SchemaVersion -isnot [long]) -or $record.SchemaVersion -ne 1) {
        throw 'Journal schema version is invalid.'
    }
    if ($record.Id -isnot [string] -or $record.Id -notmatch '^[a-f0-9]{32}$') {
        throw 'Journal ID is invalid.'
    }
    if ($record.Operation -isnot [string] -or [string]::IsNullOrWhiteSpace($record.Operation)) {
        throw 'Journal operation is invalid.'
    }
    if ($record.State -isnot [string] -or @('Running', 'Completed', 'Failed') -cnotcontains $record.State) {
        throw 'Journal state is invalid.'
    }
    $startedAt = ConvertTo-JournalDateTime $record.StartedAt
    Assert-JournalCheckpoints $record.Checkpoints
    Assert-JournalResult $record.Result
    if (($record.State -eq 'Running' -and $null -ne $record.Result) -or
        ($record.State -ne 'Running' -and $null -eq $record.Result)) {
        throw 'Journal state and result do not match.'
    }
    if (-not (Test-JournalValueRedacted $record.Instance)) {
        throw 'Journal instance contains unredacted sensitive data.'
    }
    return [pscustomobject]@{
        Id = $record.Id
        StartedAt = $startedAt
        State = $record.State
        Operation = $record.Operation
        Instance = $record.Instance
        Checkpoints = $record.Checkpoints
        Result = $record.Result
        JournalPath = $journalPath
    }
}

function Write-JournalEvent {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Journal,
        [Parameter(Mandatory = $true)]
        [string]$Level,
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [object]$Data
    )

    if ([string]::IsNullOrWhiteSpace($Level) -or [string]::IsNullOrWhiteSpace($Message)) {
        throw 'Journal event level and message are required.'
    }
    Assert-OperationJournal $Journal
    if ($Journal.State -ne 'Running') {
        throw 'Journal does not accept events in its current state.'
    }
    $previousCheckpoints = $Journal.Checkpoints
    $event = [pscustomobject]@{
        Timestamp = [DateTime]::UtcNow
        Level = $Level
        Message = $Message
        Data = Protect-JournalValue $Data
    }
    $Journal.Checkpoints = @($Journal.Checkpoints) + @($event)
    try {
        Write-OperationJournal $Journal
    }
    catch {
        $Journal.Checkpoints = $previousCheckpoints
        throw
    }
}

function Set-OperationJournalState {
    param(
        [object]$Journal,
        [string]$State,
        [object]$Result
    )

    $protectedResult = Protect-JournalValue $Result
    Assert-JournalResult $protectedResult
    Assert-OperationJournal $Journal
    if ($Journal.State -ne 'Running') {
        throw 'Journal does not accept a final state in its current state.'
    }
    $previousState = $Journal.State
    $previousResult = $Journal.Result
    $Journal.State = $State
    $Journal.Result = $protectedResult
    try {
        Write-OperationJournal $Journal
    }
    catch {
        $Journal.State = $previousState
        $Journal.Result = $previousResult
        throw
    }
}

function Complete-OperationJournal {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Journal,
        [Parameter(Mandatory = $true)]
        [object]$Result
    )

    Set-OperationJournalState -Journal $Journal -State 'Completed' -Result $Result
}

function Fail-OperationJournal {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Journal,
        [Parameter(Mandatory = $true)]
        [object]$Result
    )

    Set-OperationJournalState -Journal $Journal -State 'Failed' -Result $Result
}
