function Protect-JournalValue {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return $null
    }
    if ($Value -is [System.Exception]) {
        return [pscustomobject]@{
            Type = Protect-ToolkitText $Value.GetType().FullName
            Message = Protect-ToolkitText $Value.Message
            Source = Protect-ToolkitText $Value.Source
            HResult = $Value.HResult
            Data = Protect-JournalValue $Value.Data
            InnerException = Protect-JournalValue $Value.InnerException
            TargetSite = '[OMITTED]'
        }
    }
    if ($Value -is [System.Reflection.MemberInfo]) {
        return '[OMITTED]'
    }
    if ($Value -is [scriptblock] -or
        $Value -is [System.IO.Stream] -or
        $Value -is [System.Threading.WaitHandle] -or
        $Value -is [System.Delegate]) {
        throw 'Journal object type is unsupported.'
    }
    if ($Value -is [string]) {
        return Protect-ToolkitText $Value
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
    $type = $Value.GetType()
    if ($type.IsPrimitive -or
        $Value -is [decimal] -or
        $Value -is [DateTime] -or
        $Value -is [DateTimeOffset] -or
        $Value -is [Guid] -or
        $Value -is [TimeSpan] -or
        $Value -is [Uri] -or
        $Value -is [Version] -or
        $Value -is [System.Enum]) {
        return $Value
    }
    $properties = @($Value.PSObject.Properties | Where-Object {
        $_.IsGettable -and
        ($_.MemberType -eq [Management.Automation.PSMemberTypes]::Property -or
         $_.MemberType -eq [Management.Automation.PSMemberTypes]::NoteProperty)
    })
    if ($properties.Count -eq 0) {
        throw 'Journal object type is unsupported.'
    }
    $copy = @{}
    foreach ($property in $properties) {
        $copy[$property.Name] = if ($property.Name -match 'token|password|secret|authorization|cookie|key') {
            '[REDACTED]'
        }
        else {
            Protect-JournalValue $property.Value
        }
    }
    return [pscustomobject]$copy
}

function Test-JournalValueRedacted {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return $true
    }
    if ($Value -is [string]) {
        return (Protect-ToolkitText $Value) -ceq $Value
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
        [object]$Result,
        [string]$State
    )

    if ($null -eq $Result) {
        if ($State -ne 'Running') {
            throw 'Journal state and result do not match.'
        }
        return
    }
    if ($State -eq 'Running' -or $Result -is [Array] -or $Result -isnot [pscustomobject]) {
        throw 'Journal result does not match journal state.'
    }
    $resultProperties = @($Result.PSObject.Properties | ForEach-Object { $_.Name })
    if ($resultProperties.Count -ne 3) {
        throw 'Journal result is invalid.'
    }
    foreach ($propertyName in @('Status', 'Message', 'Data')) {
        if ($resultProperties -cnotcontains $propertyName) {
            throw 'Journal result is invalid.'
        }
    }
    $allowedStatuses = if ($State -eq 'Completed') {
        @('Success', 'AlreadyApplied', 'Warning')
    }
    else {
        @('RecoverableError', 'CriticalError')
    }
    if ($Result.Status -isnot [string] -or
        $allowedStatuses -cnotcontains $Result.Status -or
        $Result.Message -isnot [string] -or
        [string]::IsNullOrWhiteSpace($Result.Message) -or
        (Protect-ToolkitText $Result.Message) -cne $Result.Message) {
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
        $checkpointProperties = @($checkpoint.PSObject.Properties | ForEach-Object { $_.Name })
        if ($checkpointProperties.Count -ne 4) {
            throw 'Journal checkpoint is invalid.'
        }
        foreach ($propertyName in @('Timestamp', 'Level', 'Message', 'Data')) {
            if ($checkpointProperties -cnotcontains $propertyName) {
                throw 'Journal checkpoint is invalid.'
            }
        }
        [void](ConvertTo-JournalDateTime $checkpoint.Timestamp)
        if ($checkpoint.Level -isnot [string] -or
            [string]::IsNullOrWhiteSpace($checkpoint.Level) -or
            (Protect-ToolkitText $checkpoint.Level) -cne $checkpoint.Level -or
            $checkpoint.Message -isnot [string] -or
            [string]::IsNullOrWhiteSpace($checkpoint.Message) -or
            (Protect-ToolkitText $checkpoint.Message) -cne $checkpoint.Message) {
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
    $requiredProperties = @('Id', 'StartedAt', 'State', 'Operation', 'Instance', 'Checkpoints', 'Result', 'JournalPath')
    $actualProperties = @($Journal.PSObject.Properties | ForEach-Object { $_.Name })
    if ($actualProperties.Count -ne $requiredProperties.Count) {
        throw 'Journal object is invalid.'
    }
    foreach ($propertyName in $requiredProperties) {
        if ($actualProperties -cnotcontains $propertyName) {
            throw 'Journal object is invalid.'
        }
    }
    if ($Journal.Id -isnot [string] -or $Journal.Id -notmatch '^[a-f0-9]{32}$') {
        throw 'Journal ID is invalid.'
    }
    if ($Journal.State -isnot [string] -or @('Running', 'Completed', 'Failed') -cnotcontains $Journal.State) {
        throw 'Journal state is invalid.'
    }
    if ($Journal.Operation -isnot [string] -or
        [string]::IsNullOrWhiteSpace($Journal.Operation) -or
        (Protect-ToolkitText $Journal.Operation) -cne $Journal.Operation) {
        throw 'Journal operation is invalid.'
    }
    if ($Journal.JournalPath -isnot [string] -or
        [string]::IsNullOrWhiteSpace($Journal.JournalPath) -or
        -not [IO.Path]::IsPathRooted($Journal.JournalPath)) {
        throw 'Journal path is invalid.'
    }
    [void](ConvertTo-JournalDateTime $Journal.StartedAt)
    Assert-JournalCheckpoints $Journal.Checkpoints
    Assert-JournalResult -Result $Journal.Result -State $Journal.State
    if (-not (Test-JournalValueRedacted $Journal.Instance)) {
        throw 'Journal instance contains unredacted sensitive data.'
    }
}

function Remove-OperationJournalTemporaryFile {
    param(
        [string]$TemporaryPath
    )

    if (-not [IO.File]::Exists($TemporaryPath)) {
        return
    }
    try {
        [IO.File]::Delete($TemporaryPath)
    }
    catch {
        throw 'Journal temporary-file cleanup failed.'
    }
}

function Install-OperationJournalFile {
    param(
        [string]$TemporaryPath,
        [string]$JournalPath
    )

    $replacementFailure = $null
    $backupPath = $null
    try {
        if ([IO.File]::Exists($JournalPath)) {
            $journalDirectory = [IO.Path]::GetDirectoryName($JournalPath)
            $backupPath = Join-Path $journalDirectory ('.' + [IO.Path]::GetFileName($JournalPath) + '.' + [Guid]::NewGuid().ToString('N') + '.bak')
            [IO.File]::Replace($TemporaryPath, $JournalPath, $backupPath)
        }
        else {
            [IO.File]::Move($TemporaryPath, $JournalPath)
        }
    }
    catch {
        $replacementFailure = $_.Exception
    }
    Remove-OperationJournalTemporaryFile $TemporaryPath
    if ($null -ne $replacementFailure) {
        $failureMessage = Protect-ToolkitText ([string]$replacementFailure.Message)
        if ([string]::IsNullOrWhiteSpace($failureMessage)) {
            $failureMessage = 'Unknown replacement failure.'
        }
        throw "Journal atomic replacement failed: $failureMessage"
    }
    if ($null -ne $backupPath -and [IO.File]::Exists($backupPath)) {
        try {
            [IO.File]::Delete($backupPath)
        }
        catch {
            $cleanupException = New-Object InvalidOperationException 'Journal backup cleanup failed.'
            $cleanupException.Data['JournalWriteCommitted'] = $true
            throw $cleanupException
        }
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
            Operation = Protect-ToolkitText $Journal.Operation
            Instance = Protect-JournalValue $Journal.Instance
            State = $Journal.State
            Checkpoints = Protect-JournalValue $Journal.Checkpoints
            Result = Protect-JournalValue $Journal.Result
        }
        $json = $record | ConvertTo-Json -Depth 20
        $utf8 = [Text.UTF8Encoding]::new($false, $true)
        [IO.File]::WriteAllText($temporaryPath, ($json + [Environment]::NewLine), $utf8)
    }
    catch {
        $failureMessage = Protect-ToolkitText ([string]$_.Exception.Message)
        try {
            Remove-OperationJournalTemporaryFile $temporaryPath
        }
        catch {
            $failureMessage = Protect-ToolkitText ([string]$_.Exception.Message)
        }
        if ([string]::IsNullOrWhiteSpace($failureMessage)) {
            $failureMessage = 'Unknown write failure.'
        }
        throw "Journal write failed: $failureMessage"
    }
    Install-OperationJournalFile -TemporaryPath $temporaryPath -JournalPath $journalPath
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
    $operationText = Protect-ToolkitText $Operation
    if ([string]::IsNullOrWhiteSpace($operationText)) {
        throw 'Journal operation is invalid.'
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
        Operation = $operationText
        Instance = Protect-JournalValue $Instance
        Checkpoints = @()
        Result = $null
        JournalPath = [IO.Path]::Combine($rootPath, ($id + '.json'))
    }
    Write-OperationJournal $journal
    return $journal
}

function Get-JournalJsonStringEnd {
    param(
        [string]$Json,
        [int]$StartIndex
    )

    $index = $StartIndex + 1
    while ($index -lt $Json.Length) {
        $character = $Json[$index]
        if ([int][char]$character -lt 32) {
            throw 'Journal JSON is invalid.'
        }
        if ($character -eq [char]'"') {
            return $index + 1
        }
        if ($character -eq [char]'\') {
            $index++
            if ($index -ge $Json.Length) {
                throw 'Journal JSON is invalid.'
            }
            $escape = $Json[$index]
            if ($escape -notin @([char]'"', [char]'\', [char]'/', [char]'b', [char]'f', [char]'n', [char]'r', [char]'t', [char]'u')) {
                throw 'Journal JSON is invalid.'
            }
            if ($escape -eq [char]'u') {
                if ($index + 4 -ge $Json.Length) {
                    throw 'Journal JSON is invalid.'
                }
                $index += 4
            }
        }
        $index++
    }
    throw 'Journal JSON is invalid.'
}

function Assert-NoDuplicateJournalProperty {
    param(
        [string]$Json
    )

    $frames = New-Object System.Collections.Stack
    $index = 0
    while ($index -lt $Json.Length) {
        $character = $Json[$index]
        if ([char]::IsWhiteSpace($character)) {
            $index++
            continue
        }
        if ($character -eq [char]'"') {
            $stringStart = $index
            $index = Get-JournalJsonStringEnd -Json $Json -StartIndex $index
            if ($frames.Count -gt 0) {
                $frame = $frames.Peek()
                if ($frame.Kind -eq 'Object' -and ($frame.State -eq 'PropertyOrEnd' -or $frame.State -eq 'Property')) {
                    $propertyName = [string]($Json.Substring($stringStart, $index - $stringStart) | ConvertFrom-Json -ErrorAction Stop)
                    if (-not $frame.Names.Add($propertyName)) {
                        throw 'Journal JSON contains duplicate properties.'
                    }
                    $frame.State = 'Colon'
                }
                else {
                    if ($frame.State -notin @('Value', 'ValueOrEnd')) {
                        throw 'Journal JSON is invalid.'
                    }
                    $frame.State = 'AfterValue'
                }
            }
            continue
        }
        if ($character -eq [char]'{' -or $character -eq [char]'[') {
            if ($frames.Count -gt 0) {
                $parent = $frames.Peek()
                if ($parent.State -notin @('Value', 'ValueOrEnd')) {
                    throw 'Journal JSON is invalid.'
                }
                $parent.State = 'InValue'
            }
            $kind = if ($character -eq [char]'{') { 'Object' } else { 'Array' }
            $state = if ($kind -eq 'Object') { 'PropertyOrEnd' } else { 'ValueOrEnd' }
            $names = $null
            if ($kind -eq 'Object') {
                $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            }
            $frames.Push([pscustomobject]@{ Kind = $kind; State = $state; Names = $names })
            $index++
            continue
        }
        if ($character -eq [char]'}' -or $character -eq [char]']') {
            if ($frames.Count -eq 0) {
                throw 'Journal JSON is invalid.'
            }
            $frame = $frames.Peek()
            $expectedKind = if ($character -eq [char]'}') { 'Object' } else { 'Array' }
            $allowedStates = if ($expectedKind -eq 'Object') { @('PropertyOrEnd', 'AfterValue') } else { @('ValueOrEnd', 'AfterValue') }
            if ($frame.Kind -ne $expectedKind -or $frame.State -notin $allowedStates) {
                throw 'Journal JSON is invalid.'
            }
            [void]$frames.Pop()
            if ($frames.Count -gt 0) {
                $frames.Peek().State = 'AfterValue'
            }
            $index++
            continue
        }
        if ($character -eq [char]':') {
            if ($frames.Count -eq 0 -or $frames.Peek().Kind -ne 'Object' -or $frames.Peek().State -ne 'Colon') {
                throw 'Journal JSON is invalid.'
            }
            $frames.Peek().State = 'Value'
            $index++
            continue
        }
        if ($character -eq [char]',') {
            if ($frames.Count -eq 0 -or $frames.Peek().State -ne 'AfterValue') {
                throw 'Journal JSON is invalid.'
            }
            $frames.Peek().State = if ($frames.Peek().Kind -eq 'Object') { 'Property' } else { 'Value' }
            $index++
            continue
        }
        $primitiveStart = $index
        while ($index -lt $Json.Length -and
            -not [char]::IsWhiteSpace($Json[$index]) -and
            $Json[$index] -notin @([char]',', [char]'{', [char]'}', [char]'[', [char]']', [char]':')) {
            $index++
        }
        if ($index -eq $primitiveStart) {
            throw 'Journal JSON is invalid.'
        }
        if ($frames.Count -gt 0) {
            $frame = $frames.Peek()
            if ($frame.State -notin @('Value', 'ValueOrEnd')) {
                throw 'Journal JSON is invalid.'
            }
            $frame.State = 'AfterValue'
        }
    }
    if ($frames.Count -ne 0) {
        throw 'Journal JSON is invalid.'
    }
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
        Assert-NoDuplicateJournalProperty $json
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
    if ($record.Operation -isnot [string] -or
        [string]::IsNullOrWhiteSpace($record.Operation) -or
        (Protect-ToolkitText $record.Operation) -cne $record.Operation) {
        throw 'Journal operation is invalid.'
    }
    if ($record.State -isnot [string] -or @('Running', 'Completed', 'Failed') -cnotcontains $record.State) {
        throw 'Journal state is invalid.'
    }
    $startedAt = ConvertTo-JournalDateTime $record.StartedAt
    Assert-JournalCheckpoints $record.Checkpoints
    Assert-JournalResult -Result $record.Result -State $record.State
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
        Level = Protect-ToolkitText $Level
        Message = Protect-ToolkitText $Message
        Data = Protect-JournalValue $Data
    }
    $Journal.Checkpoints = @($Journal.Checkpoints) + @($event)
    try {
        Write-OperationJournal $Journal
    }
    catch {
        if ($_.Exception.Data['JournalWriteCommitted'] -ne $true) {
            $Journal.Checkpoints = $previousCheckpoints
        }
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
    Assert-JournalResult -Result $protectedResult -State $State
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
        if ($_.Exception.Data['JournalWriteCommitted'] -ne $true) {
            $Journal.State = $previousState
            $Journal.Result = $previousResult
        }
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
