# The menu is one design in three screens: the dashboard lists the instances, the target screen chooses
# what to work on, and the action screen runs one thing. Every screen is built from the same renderer,
# so a row, a tag and a title look identical wherever they appear.
#
# These screens are a presentation layer over the existing actions. A mutating row still resolves to one
# of the dispatched actions, so the elevation seam, the operation journal and the fail-closed
# confirmation are unchanged: the menu decides what to run, never how to run it.

# The consequence tag on every row. A tag is the warning a person needs before choosing, so it is the
# shortest true statement of what the row will do. 'read-only' changes nothing, 'new instance' adds a
# MuMu instance, 'changes guest' writes inside the Android guest, 'changes installation' writes the
# campaign files, 'restores' puts files back from a restore point, and 'downloads' reaches the network
# for a pinned artifact.
$script:ToolkitMenuTags = @{
    'Verify'         = 'read-only'
    'Root12'         = 'downloads + changes guest'
    'Root15'         = 'changes guest'
    'Conceal'        = 'changes guest'
    'FullSetup'      = 'downloads + changes guest'
    'RemoveAds'      = 'changes installation'
    'Restore'        = 'restores'
    'NewInstance'    = 'new instance'
    'CloneKeepInfo'  = 'new instance'
    'CloneFreshInfo' = 'new instance'
    'ContinueClone'  = 'changes guest'
}

# A tag that writes is red, a tag that only reaches outside the guest is yellow, and a read-only tag is
# plain. A combined tag is colored by the writing part, because that is the part a person must not
# misread, and the download in the same tag is already spelled out in words.
function Get-ToolkitTagColor {
    param([string]$Tag)

    if ($Tag -match 'changes') { return 'Red' }
    if ($Tag -match 'downloads') { return 'Yellow' }
    if ($Tag -match 'new instance|restores') { return 'Cyan' }
    return ''
}

# A boolean reads as yes or no, and an unreadable value reads as unknown rather than as no. The manager
# reports no root setting at all for some instances, and calling that 'no' would claim a measurement
# that was never taken.
function Get-ToolkitYesNoText {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) {
        return 'unknown'
    }
    if ($Value -is [bool]) {
        if ($Value) { return 'yes' }
        return 'no'
    }
    return [string]$Value
}

# One screen, rendered the same way wherever it appears: an indented title, a rule as wide as the widest
# row, the rows grouped with the group name printed on the first row of its group, and a dim note at the
# foot. The caller decides which rows a screen offers; the renderer only lays them out.
function Format-ToolkitScreen {
    param(
        [string]$Title,
        [object[]]$Rows,
        [string[]]$Notes = @()
    )

    $lines = @()
    $heading = '  ' + $Title
    $lines += $heading
    $width = $heading.Length
    $texts = @()
    foreach ($row in @($Rows)) {
        $text = (Format-ToolkitRowText -Row $row).TrimEnd()
        $texts += $text
        if ($text.Length -gt $width) {
            $width = $text.Length
        }
    }
    $lines += '  ' + ('=' * $width)
    foreach ($text in $texts) {
        $lines += $text
    }
    foreach ($note in @($Notes)) {
        $lines += '  ' + $note
    }
    return $lines
}

# A single menu row: the number the operator types, the name of what it does, and the tag for what it
# costs. The group name is printed once per group, which is the grouping the earlier menu already used
# and the shape the Command Line Interface Guidelines ask for.
function Format-ToolkitRowText {
    param([object]$Row)

    $group = [string]$Row.Group
    if ([string]::IsNullOrWhiteSpace($group)) {
        $group = 'Other'
    }
    $label = ([string]$row.Number) + ' ' + ([string]$row.Name)
    $text = '  ' + $group.PadRight(9) + '  ' + $label.PadRight(32)
    $tag = [string]$Row.Tag
    if (-not [string]::IsNullOrWhiteSpace($tag)) {
        $text += '  ' + $tag
    }
    return $text
}

# The instance table on the dashboard. Two number columns, because they are not the same thing: '#' is
# what the operator types and 'Idx' is the index MuMu itself uses. Printing only the MuMu index beside a
# prompt that counts from one is how the wrong instance gets rooted.
function Format-ToolkitInstanceTable {
    param([object[]]$Instances)

    $lines = @()
    $lines += '      ' + '#'.PadRight(3) + 'Idx'.PadRight(5) + 'Name'.PadRight(20) + 'Android'.PadRight(8) + 'Running'.PadRight(9) + 'Vendor root'
    $number = 1
    foreach ($instance in @($Instances)) {
        if ($null -eq $instance -or $null -eq $instance.PSObject) {
            continue
        }
        $name = [string](Get-ToolkitRecordValue -Record $instance -PropertyNames @('Name'))
        if ($name.Length -gt 18) {
            $name = $name.Substring(0, 17) + '.'
        }
        # The cell carries the bare version because the column header already names it, which keeps the
        # column narrow enough for the table to stay readable on an 80 column console.
        $lines += '      ' + ([string]$number).PadRight(3) +
        ([string](Get-ToolkitRecordValue -Record $instance -PropertyNames @('Index'))).PadRight(5) +
        $name.PadRight(20) +
        ([string](Get-ToolkitRecordValue -Record $instance -PropertyNames @('AndroidVersion'))).PadRight(8) +
        (Get-ToolkitYesNoText (Get-ToolkitRecordValue -Record $instance -PropertyNames @('Running'))).PadRight(9) +
        (Get-ToolkitYesNoText (Get-ToolkitRecordValue -Record $instance -PropertyNames @('RootSetting')))
        $number++
    }
    return $lines
}

# The dashboard rows: one per instance, then the three installation level choices and quit. A fresh
# instance lives here rather than on an instance screen because a created instance has no source, so
# putting it under a header that names another instance would be a false description of the choice.
function Get-ToolkitDashboardRows {
    $rows = @()
    $rows += [pscustomobject]@{ Number = 'N'; Name = 'New empty instance'; Tag = [string]$script:ToolkitMenuTags['NewInstance']; Group = 'Prepare' }
    $rows += [pscustomobject]@{ Number = 'A'; Name = 'Remove ads'; Tag = [string]$script:ToolkitMenuTags['RemoveAds']; Group = 'Other' }
    $rows += [pscustomobject]@{ Number = 'B'; Name = 'Restore ads'; Tag = [string]$script:ToolkitMenuTags['Restore']; Group = '' }
    $rows += [pscustomobject]@{ Number = 'Q'; Name = 'Quit'; Tag = ''; Group = '' }
    return $rows
}

# The target screen for one instance. Every guest change in this toolkit is clone-then-mutate, so the
# only choices are to copy the instance, to copy it with fresh identifiers, or to continue on the copy a
# previous run already made. There is no in-place row, because Root12, Root15 and Conceal all refuse to
# write to a source instance.
function Get-ToolkitTargetRows {
    $rows = @()
    $rows += [pscustomobject]@{ Number = 1; Name = 'Clone, keep device info'; Target = 'CloneKeepInfo'; Tag = [string]$script:ToolkitMenuTags['CloneKeepInfo']; Group = 'Target' }
    $rows += [pscustomobject]@{ Number = 2; Name = 'Clone, fresh identifiers'; Target = 'CloneFreshInfo'; Tag = [string]$script:ToolkitMenuTags['CloneFreshInfo']; Group = '' }
    $rows += [pscustomobject]@{ Number = 3; Name = 'Continue on its clone'; Target = 'ContinueClone'; Tag = [string]$script:ToolkitMenuTags['ContinueClone']; Group = '' }
    $rows += [pscustomobject]@{ Number = 4; Name = 'Back to the instances'; Target = 'Back'; Tag = ''; Group = 'Back' }
    return $rows
}

# The action screen for one instance. The rows are filtered by the instance Android version, because a 12
# instance cannot take the built-in 15 root and a 15 instance cannot take the Kitsune release. An entry
# that cannot work is not offered rather than offered and then refused.
function Get-ToolkitActionRows {
    param([string]$AndroidVersion)

    $rows = @()
    $next = 1
    $rows += [pscustomobject]@{ Number = $next; Name = 'Status'; Action = 'Verify'; Tag = [string]$script:ToolkitMenuTags['Verify']; Group = 'Inspect' }
    $next++
    # The root rows are filtered by the instance Android version, because a 12 instance cannot take the
    # built-in 15 root and a 15 instance cannot take the Kitsune release. Each row carries the action it
    # dispatches, so the number the operator reads cannot drift from the work that is done.
    if ($AndroidVersion -like '12*') {
        $rows += [pscustomobject]@{ Number = $next; Name = 'Root with Kitsune'; Action = 'Root12'; Tag = [string]$script:ToolkitMenuTags['Root12']; Group = 'Change' }
        $next++
    }
    elseif ($AndroidVersion -like '15*') {
        $rows += [pscustomobject]@{ Number = $next; Name = 'Built-in root'; Action = 'Root15'; Tag = [string]$script:ToolkitMenuTags['Root15']; Group = 'Change' }
        $next++
    }
    elseif ($AndroidVersion -ceq 'unknown') {
        # A session that named an instance on the command line has no version yet, so both root rows are
        # offered and the action refuses the one that does not apply to the instance it resolves.
        $rows += [pscustomobject]@{ Number = $next; Name = 'Root with Kitsune'; Action = 'Root12'; Tag = [string]$script:ToolkitMenuTags['Root12']; Group = 'Change' }
        $next++
        $rows += [pscustomobject]@{ Number = $next; Name = 'Built-in root'; Action = 'Root15'; Tag = [string]$script:ToolkitMenuTags['Root15']; Group = '' }
        $next++
    }
    # An instance whose version is neither 12 nor 15 gets no root row at all, because neither root
    # implementation in this toolkit applies to it.
    $rows += [pscustomobject]@{ Number = $next; Name = 'Conceal apps'; Action = 'Conceal'; Tag = [string]$script:ToolkitMenuTags['Conceal']; Group = 'Change' }
    $next++
    $rows += [pscustomobject]@{ Number = $next; Name = 'Full setup'; Action = 'FullSetup'; Tag = [string]$script:ToolkitMenuTags['FullSetup']; Group = '' }
    $next++
    $rows += [pscustomobject]@{ Number = $next; Name = 'Back to the instances'; Action = 'Back'; Tag = ''; Group = 'Back' }
    return $rows
}

# The disclosure printed before anything that writes. It names the instance, what will change on it, and
# where the restore point is, and it is printed before the confirmation word is asked for, so a person
# reads the consequence and then decides. This is the warning a one line row tag cannot carry.
function Format-ToolkitDisclosure {
    param(
        [string]$Action,
        [object]$Instance,
        [string[]]$Packages = @(),
        [string]$RestorePoint = ''
    )

    $index = [string](Get-ToolkitRecordValue -Record $Instance -PropertyNames @('Index'))
    $name = [string](Get-ToolkitRecordValue -Record $Instance -PropertyNames @('Name'))
    $lines = @()
    $lines += '  This will change instance ' + $index + ' (' + $name + ').'
    if ($Action -ceq 'Conceal') {
        $lines += '  * ' + [string]@($Packages).Count + ' app(s) join the Root template: ' + (@($Packages) -join ', ')
        $lines += '  * The vendor root is off on the clone, so an app probing for su sees nothing.'
    }
    elseif ($Action -ceq 'Root12') {
        $lines += '  * The pinned Kitsune release is installed into the system partition of the clone.'
        $lines += '  * The clone vendor root is turned off, so an app probing for su sees nothing.'
    }
    elseif ($Action -ceq 'Root15') {
        $lines += '  * The built-in root is enabled on the clone and is kept enabled.'
    }
    elseif ($Action -ceq 'FullSetup') {
        $lines += '  * The root that applies to this Android version is applied to a clone of this instance.'
        $lines += '  * The selected apps join the Root template on that clone.'
        $lines += '  * The campaign advertisement files for this installation are suppressed.'
    }
    elseif ($Action -ceq 'RemoveAds') {
        $lines += '  * The campaign advertisement files for this installation are suppressed.'
    }
    elseif ($Action -ceq 'Restore') {
        $lines += '  * The campaign files are put back from the toolkit restore point.'
    }
    if (-not [string]::IsNullOrWhiteSpace($RestorePoint)) {
        $lines += '  * Restore point: ' + $RestorePoint
    }
    return $lines
}

# The simulated identifiers the manager exposes. The GUI offers a 'keep device info' toggle, but the
# manager clone subcommand has no such flag, so the choice is carried out with the simulation subcommand
# and then read back. A toggle that silently did nothing would be worse than no toggle, so both branches
# compare a measurement instead of assuming an outcome.
$script:ToolkitIdentifierKeys = @('android_id', 'mac_address', 'imei')

function Get-MuMuInstanceIdentifiers {
    param(
        [string]$ManagerPath,
        [int]$Index,
        [scriptblock]$Runner = $null
    )

    $identifiers = @{}
    foreach ($key in @($script:ToolkitIdentifierKeys)) {
        $outcome = Invoke-CheckedProcess -FilePath $ManagerPath -ArgumentList @('simulation', '-v', [string]$Index, '-sk', $key) -Runner $Runner
        if ($null -eq $outcome -or $outcome.ExitCode -ne 0) {
            return Get-ToolkitResult -Status 'CriticalError' -Message "The $key on the instance at index $Index could not be read, so no identifier state is claimed in either direction." -Data (@{ Code = 'IDENTIFIER_UNREADABLE'; Key = $key })
        }
        try {
            $parsed = ConvertFrom-ToolkitJson -Text $outcome.Text
        }
        catch {
            return Get-ToolkitResult -Status 'CriticalError' -Message "The $key on the instance at index $Index was not a readable value, so no identifier state is claimed in either direction." -Data (@{ Code = 'IDENTIFIER_UNREADABLE'; Key = $key })
        }
        $reported = Get-ToolkitRecordValue -Record $parsed -PropertyNames @($key)
        $identifiers[$key] = if ($null -eq $reported) { '' } else { [string]$reported }
    }
    return Get-ToolkitResult -Status 'Success' -Message 'The simulated identifiers were read from the manager.' -Data $identifiers
}

function Set-MuMuInstanceIdentifiers {
    param(
        [string]$ManagerPath,
        [int]$Index,
        [hashtable]$Values,
        [scriptblock]$Runner = $null
    )

    foreach ($key in @($script:ToolkitIdentifierKeys)) {
        if (-not $Values.ContainsKey($key)) {
            continue
        }
        $outcome = Invoke-CheckedProcess -FilePath $ManagerPath -ArgumentList @('simulation', '-v', [string]$Index, '-sk', $key, '-sv', [string]$Values[$key]) -Runner $Runner
        if ($null -eq $outcome -or $outcome.ExitCode -ne 0) {
            return Get-ToolkitResult -Status 'CriticalError' -Message "The $key on the clone at index $Index was not accepted by the manager, so fresh identifiers are not claimed." -Data (@{ Code = 'IDENTIFIER_WRITE_FAILED'; Key = $key })
        }
    }
    return Get-ToolkitResult -Status 'Success' -Message 'The clone identifiers were written through the manager.' -Data ([pscustomobject]@{ Keys = @($Values.Keys) })
}

# A fresh android id and mac are generated here because the manager only clears a value with __null__,
# and the choice is a *different* value rather than an empty one. An IMEI the source never reported is
# left alone: a value that was never set is not a value to randomize, and writing one would invent an
# identifier the device never had.
function New-ToolkitFreshIdentifier {
    param(
        [string]$Key,
        [string]$Source
    )

    if ($Key -eq 'android_id') {
        return [Guid]::NewGuid().ToString('N')
    }
    if ($Key -eq 'mac_address') {
        $bytes = New-Object byte[] 6
        $random = [Security.Cryptography.RandomNumberGenerator]::Create()
        try {
            $random.GetBytes($bytes)
        }
        finally {
            $random.Dispose()
        }
        # The locally administered bit is set and the multicast bit is cleared, so the generated address
        # is a valid unicast address and cannot collide with a real vendor prefix.
        $bytes[0] = [byte](($bytes[0] -band 0xFE) -bor 0x02)
        return (($bytes | ForEach-Object { $_.ToString('X2') }) -join ':')
    }
    if ([string]::IsNullOrWhiteSpace($Source)) {
        return ''
    }
    return [string](Get-Random -Minimum 100000000000000 -Maximum 999999999999999)
}

# The whole keep-info choice, and the only place it is carried out. The source identifiers are read
# first, the clone is made by the caller, and then either the clone is left as the manager copied it or
# fresh values are written and read back. Both branches end in a comparison against the source, so the
# outcome is a measurement rather than an assumption.
function Resolve-ToolkitCloneIdentifiers {
    param(
        [string]$ManagerPath,
        [int]$SourceIndex,
        [int]$CloneIndex,
        [switch]$Fresh,
        [scriptblock]$Runner = $null
    )

    $source = Get-MuMuInstanceIdentifiers -ManagerPath $ManagerPath -Index $SourceIndex -Runner $Runner
    if ($source.Status -ne 'Success') {
        return $source
    }
    $sourceValues = $source.Data

    if (-not $Fresh) {
        $clone = Get-MuMuInstanceIdentifiers -ManagerPath $ManagerPath -Index $CloneIndex -Runner $Runner
        if ($clone.Status -ne 'Success') {
            return $clone
        }
        $matched = @()
        foreach ($key in @($script:ToolkitIdentifierKeys)) {
            if ([string]$clone.Data[$key] -ceq [string]$sourceValues[$key]) {
                $matched += $key
            }
        }
        if ($matched.Count -eq 0) {
            return Get-ToolkitResult -Status 'CriticalError' -Message 'The clone reports no simulated identifier that matches the source, so keeping the device info is not claimed. Use the fresh identifier path instead.' -Data (@{ Code = 'IDENTIFIER_KEEP_UNVERIFIED'; SourceIndex = $SourceIndex; CloneIndex = $CloneIndex })
        }
        return Get-ToolkitResult -Status 'Success' -Message "The clone at index $CloneIndex reports the same simulated identifiers as the source at index $SourceIndex, so the device info was kept: $($matched -join ', ')." -Data ([pscustomobject]@{ SourceIndex = $SourceIndex; CloneIndex = $CloneIndex; Kept = $true; Matched = $matched })
    }

    # The map is named generatedValues rather than fresh because PowerShell variables are case
    # insensitive: a hashtable named $fresh would be the same variable as the -Fresh switch parameter, and
    # assigning a hashtable to it would leave the switch behind, so indexing it would fail on the first key.
    $generatedValues = @{}
    foreach ($key in @($script:ToolkitIdentifierKeys)) {
        $generatedValues[$key] = New-ToolkitFreshIdentifier -Key $key -Source ([string]$sourceValues[$key])
    }
    $written = Set-MuMuInstanceIdentifiers -ManagerPath $ManagerPath -Index $CloneIndex -Values $generatedValues -Runner $Runner
    if ($written.Status -ne 'Success') {
        return $written
    }
    $clone = Get-MuMuInstanceIdentifiers -ManagerPath $ManagerPath -Index $CloneIndex -Runner $Runner
    if ($clone.Status -ne 'Success') {
        return $clone
    }
    $changed = @()
    foreach ($key in @($script:ToolkitIdentifierKeys)) {
        $reported = [string]$clone.Data[$key]
        $original = [string]$sourceValues[$key]
        if (-not [string]::IsNullOrWhiteSpace($reported) -and $reported -cne $original) {
            $changed += $key
        }
    }
    if ($changed.Count -eq 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'No simulated identifier on the clone differs from the source, so fresh identifiers are not claimed and the clone is left as the manager produced it.' -Data (@{ Code = 'IDENTIFIER_FRESH_UNVERIFIED'; SourceIndex = $SourceIndex; CloneIndex = $CloneIndex })
    }
    return Get-ToolkitResult -Status 'Success' -Message "The clone at index $CloneIndex reports different simulated identifiers from the source at index $SourceIndex, so the device info was not kept: $($changed -join ', ')." -Data ([pscustomobject]@{ SourceIndex = $SourceIndex; CloneIndex = $CloneIndex; Kept = $false; Changed = $changed })
}

# The dashboard is rebuilt from live discovery on every visit rather than cached, because the instance
# set changes outside this menu and a stale table is how the wrong instance gets rooted. The discovery is
# the same cheap read the Detect action uses: the registry, the process list and the manager's own
# instance query. No guest is contacted from the dashboard.
function Get-ToolkitDashboardSnapshot {
    param(
        [string]$InstallRoot = '',
        [scriptblock]$Runner = $null
    )

    $sources = Get-ToolkitDiscoverySources
    $installs = @(Find-MuMuInstallations -Edition 'All' -RegistryRoots @($sources.RegistryRoots) -ProcessSnapshot @($sources.ProcessSnapshot) -FallbackRoots @($sources.FallbackRoots) |
            Where-Object { $null -eq $_.PSObject.Properties['Status'] })
    if ($installs.Count -eq 0) {
        return Get-ToolkitResult -Status 'CriticalError' -Message 'No MuMu installation was discovered, so no instance can be listed.' -Data (@{ Code = 'INSTALL_NOT_DISCOVERED' })
    }
    # An installation named on the command line is the one the operator already chose, so the dashboard
    # shows it rather than the first one discovered. A path that matches nothing is refused here instead of
    # silently falling back, because a table from a different installation is a wrong answer, not a default.
    $install = $installs[0]
    if (-not [string]::IsNullOrWhiteSpace($InstallRoot)) {
        $requested = ConvertTo-ToolkitFullPath -Path $InstallRoot
        $matched = $null
        foreach ($candidate in $installs) {
            $candidateRoot = ConvertTo-ToolkitFullPath -Path ([string](Get-ToolkitRecordValue -Record $candidate -PropertyNames @('InstallRoot')))
            if ($null -ne $requested -and $null -ne $candidateRoot -and $candidateRoot.Equals($requested, [StringComparison]::OrdinalIgnoreCase)) {
                $matched = $candidate
                break
            }
        }
        if ($null -eq $matched) {
            return Get-ToolkitResult -Status 'CriticalError' -Message "The requested installation was not discovered on this system, so no instance can be listed." -Data (@{ Code = 'INSTALL_NOT_DISCOVERED' })
        }
        $install = $matched
    }
    $managerPath = [string](Get-ToolkitFirstProperty -InputObject $install -PropertyNames @('ManagerPath'))
    $instances = @(Get-MuMuInstances -Install $install -ManagerPath $managerPath -Runner $Runner |
            Where-Object { $null -eq $_.PSObject.Properties['Status'] })
    return Get-ToolkitResult -Status 'Success' -Message "$($instances.Count) instance(s) were read from $($installs.Count) discovered installation(s)." -Data ([pscustomobject]@{
            Install = $install
            InstallCount = $installs.Count
            Instances = $instances
        })
}

# The rendered lines for whichever screen is showing, plus the prompt the reader is about to be asked.
# Returning both from one function keeps the screen and its question from drifting apart, which is how a
# prompt ends up naming a range the screen no longer prints.
function Get-ToolkitScreenLines {
    param(
        [string]$Screen,
        [object]$Snapshot,
        [object]$Instance,
        [object]$Target,
        [scriptblock]$Writer = $null
    )

    if ($Screen -ceq 'Dashboard') {
        # The snapshot arrives either as a result with a Data field or as the payload alone, and a
        # dashboard that assumed one shape would read the other's fields as empty and print a blank
        # table. The payload is accepted directly, so a caller that already has a snapshot is not made
        # to re-run discovery just to satisfy a wrapper.
        $payload = $null
        if ($null -ne $Snapshot -and $null -ne $Snapshot.PSObject) {
            if ($null -ne $Snapshot.PSObject.Properties['Data']) {
                $payload = $Snapshot.Data
            }
            elseif ($null -ne $Snapshot.PSObject.Properties['Instances']) {
                $payload = $Snapshot
            }
        }
        $failed = $null -ne $Snapshot -and $null -ne $Snapshot.PSObject -and
            $null -ne $Snapshot.PSObject.Properties['Status'] -and [string]$Snapshot.Status -cne 'Success'
        if ($null -eq $payload -and -not $failed) {
            $read = Get-ToolkitDashboardSnapshot
            if ($null -eq $read -or $null -eq $read.PSObject -or $null -eq $read.PSObject.Properties['Data']) {
                $failed = $true
            }
            else {
                $payload = $read.Data
            }
        }
        if ($null -eq $payload -or $failed) {
            $message = 'No MuMu instance can be listed.'
            if ($null -ne $Snapshot) {
                $message = [string]$Snapshot.Message
            }
            # Each element is parenthesized because a comma binds tighter than + here, and an unparenthesized
        # pair would be joined onto a single line by the string addition.
        $lines = @(('  ' + [string]$script:ToolkitMenuTitle), ('  ' + ('=' * 60)), ('  ' + $message), '  Quit with Q.', '  R refreshes the list.')
        return $lines
        }
        # The payload fields are read through the shared record reader for the same reason: a dashboard
        # that assumes a field exists turns a partial payload into a crash instead of a shorter table.
        # The record reader returns an array wrapped one level deep so a one-element list stays a list,
        # which means the assignment takes the array itself and the loop below enumerates it.
        $instances = Get-ToolkitRecordValue -Record $payload -PropertyNames @('Instances')
        if ($null -eq $instances) {
            $instances = @()
        }
        $install = Get-ToolkitRecordValue -Record $payload -PropertyNames @('Install')
        $edition = [string](Get-ToolkitRecordValue -Record $install -PropertyNames @('Edition'))
        $installRoot = [string](Get-ToolkitRecordValue -Record $install -PropertyNames @('InstallRoot'))
        $installCount = [int](Get-ToolkitRecordValue -Record $payload -PropertyNames @('InstallCount'))
        $lines = @()
        $lines += @(Format-ToolkitInstanceTable -Instances $instances)
        if (-not [string]::IsNullOrWhiteSpace($edition) -or -not [string]::IsNullOrWhiteSpace($installRoot)) {
            $summary = '  Installation ' + $edition
            if (-not [string]::IsNullOrWhiteSpace($installRoot)) {
                $summary += '  ' + $installRoot
            }
            if ($installCount -gt 1) {
                $summary += '  (' + [string]$installCount + ' installations discovered, showing the first)'
            }
            $lines += $summary
            $lines += ''
        }
        $lines += @(Format-ToolkitScreen -Title ([string]$script:ToolkitMenuTitle) -Rows @(Get-ToolkitDashboardRows -Instances $instances) -Notes @('Vendor root is the MuMu setting. The guest root is reported by Status.'))
        $lines += ''
        $lines += ('Select an instance (1-' + [string]$instances.Count + '), or N, A, B or Q:')
        return $lines
    }

    $index = [string](Get-ToolkitRecordValue -Record $Instance -PropertyNames @('Index'))
    $name = [string](Get-ToolkitRecordValue -Record $Instance -PropertyNames @('Name'))
    $version = [string](Get-ToolkitRecordValue -Record $Instance -PropertyNames @('AndroidVersion'))
    $title = 'Instance ' + $index + '  ' + $name + '  Android ' + $version

    if ($Screen -ceq 'Target') {
        $lines = @(Format-ToolkitScreen -Title $title -Rows @(Get-ToolkitTargetRows) -Notes @('Every guest change is made on a clone, so the source instance is never written.'))
        $lines += ''
        $lines += 'Select a target (1-4):'
        return $lines
    }

    # A seeded session arrives without a discovered version, because the index was named on the command
    # line rather than picked from the table. Every root row is offered in that case and the action itself
    # refuses an instance whose version it does not support, which is a better answer than hiding the row
    # against a version nobody has read yet.
    if ([string]::IsNullOrWhiteSpace($version)) {
        $version = 'unknown'
    }

    $lines = @(Format-ToolkitScreen -Title $title -Rows @(Get-ToolkitActionRows -AndroidVersion $version) -Notes @('Anything that writes prints what it will change and asks for CONFIRM.'))
    if ($null -ne $Target) {
        $lines += ''
        $lines += '  Working on instance ' + [string]$Target.Index + ' (' + [string]$Target.Name + ').'
    }
    $lines += ''
    $lines += 'Select an action (1-5):'
    return $lines
}

# The answer on the current screen resolved to a single meaning. An answer that matches nothing is
# refused rather than guessed at, so a mistyped number can never select a different instance or start a
# different action than the operator read.
function Resolve-ToolkitScreenChoice {
    param(
        [string]$Screen,
        [string]$Answer,
        [object]$Snapshot,
        [object]$Instance
    )

    $choice = ([string]$Answer).Trim()
    if ([string]::IsNullOrWhiteSpace($choice)) {
        return $null
    }
    if ($choice -ceq 'Q' -or $choice -ceq 'q') {
        return [pscustomobject]@{ Kind = 'Quit' }
    }
    if ($Screen -ceq 'Dashboard') {
        if ($choice -ceq 'R' -or $choice -ceq 'r') {
            return [pscustomobject]@{ Kind = 'Refresh' }
        }
        if ($choice -ceq 'A' -or $choice -ceq 'a') {
            return [pscustomobject]@{ Kind = 'Advertisements'; Advertisements = 'RemoveAds' }
        }
        if ($choice -ceq 'B' -or $choice -ceq 'b') {
            return [pscustomobject]@{ Kind = 'Advertisements'; Advertisements = 'Restore' }
        }
        if ($choice -ceq 'N' -or $choice -ceq 'n') {
            return [pscustomobject]@{ Kind = 'NewInstance' }
        }
        # The snapshot is read the same defensive way the dashboard reads it, so a caller that hands
        # over the payload alone gets the same instance list rather than a refused answer.
        $instances = $null
        if ($null -ne $Snapshot -and $null -ne $Snapshot.PSObject) {
            if ($null -ne $Snapshot.PSObject.Properties['Data']) {
                $instances = Get-ToolkitRecordValue -Record $Snapshot.Data -PropertyNames @('Instances')
            }
            elseif ($null -ne $Snapshot.PSObject.Properties['Instances']) {
                $instances = Get-ToolkitRecordValue -Record $Snapshot -PropertyNames @('Instances')
            }
        }
        if ($null -eq $instances) {
            return $null
        }
        $number = 0
        if (-not [int]::TryParse($choice, [ref]$number) -or $number -lt 1 -or $number -gt @($instances).Count) {
            return $null
        }
        return [pscustomobject]@{ Kind = 'SelectInstance'; Instance = @($instances)[$number - 1] }
    }

    if ($Screen -ceq 'Target') {
        # The answer resolves through the printed rows, so a row that is later removed or reordered cannot
        # leave the numbering pointing at something else. The session may have arrived here with a command
        # line instance index and no table, so the target is resolved from the action's own error when the
        # caller supplied no snapshot, and the screen is left for the operator to drive from there.
        $row = @(Get-ToolkitTargetRows | Where-Object { [string]$_.Number -ceq $choice })[0]
        if ($null -eq $row) {
            return $null
        }
        if ([string]$row.Name -ceq 'Back to the instances') {
            return [pscustomobject]@{ Kind = 'Back' }
        }
        if ($null -ne $Snapshot -and $null -ne $Snapshot.PSObject) {
            return [pscustomobject]@{ Kind = 'Target'; Target = [string]$row.Target }
        }
        # Without an installation the clone cannot be made here, so the choice is handed to the action with
        # the install root the session was given. A session with neither is refused rather than guessed at.
        return [pscustomobject]@{ Kind = 'Target'; Target = [string]$row.Target; NeedsInstall = $true }
    }

    # The answer resolves through the same row list the screen printed, so the number the operator read is
    # the number that is dispatched. A positional table beside a filtered row list is how row 3 ends up
    # running something the screen never showed.
    $version = [string](Get-ToolkitRecordValue -Record $Instance -PropertyNames @('AndroidVersion'))
    if ([string]::IsNullOrWhiteSpace($version)) {
        $version = 'unknown'
    }
    $row = @(Get-ToolkitActionRows -AndroidVersion $version | Where-Object { [string]$_.Number -ceq $choice })[0]
    if ($null -eq $row) {
        return $null
    }
    if ([string]$row.Name -ceq 'Back to the instances') {
        return [pscustomobject]@{ Kind = 'Back' }
    }
    # The root rows are named by what they do rather than by the action they dispatch, so the mapping is
    # declared with the row and cannot drift from the label the operator read.
    $action = [string]$row.Action
    if ([string]::IsNullOrWhiteSpace($action)) {
        $action = [string]$row.Name
    }
    return [pscustomobject]@{ Kind = 'Action'; Action = $action }
}

# The target screen decided, not performed. Every guest change in this toolkit is made on a clone, and the
# action that makes the change is the only thing that makes the clone: the earlier version had this screen
# clone and the action clone the clone, which silently spent a second full instance on every root run.
#
# So the screen now records a declaration and changes nothing. It asks for no confirmation, because there is
# nothing to confirm yet; the action asks for the confirmation that covers the clone it is about to make.
function Invoke-ToolkitMenuTarget {
    param(
        [string]$Choice,
        [object]$Install,
        [string]$StateRoot,
        [object]$Instance,
        [scriptblock]$Ask = $null,
        [scriptblock]$Show = $null,
        [scriptblock]$ActionRunner = $null,
        [scriptblock]$ProcessRunner = $null,
        [hashtable]$ActionArguments = @{}
    )

    $sourceIndex = [int](Get-ToolkitRecordValue -Record $Instance -PropertyNames @('Index'))
    $sourceName = [string](Get-ToolkitRecordValue -Record $Instance -PropertyNames @('Name'))

    # Continuing on a clone resolves the clone a previous root action verified and recorded. It reads the
    # operation journal, not the manager, so it is available before anything is started, and it refuses
    # when there is no record rather than making a new clone behind the operator's back.
    if ($Choice -ceq 'ContinueClone') {
        $clone = Get-ToolkitVerifiedClone -StateRoot $StateRoot -Install $Install -Index $sourceIndex
        if ($clone.Status -ne 'Success') {
            return [pscustomobject]@{ Lines = @(Format-ToolkitResult -Result $clone -Interactive); Result = $clone; Proceed = $false; Target = $null }
        }
        $target = [pscustomobject]@{
            Mode = 'Continue'
            SourceIndex = $sourceIndex
            SourceName = $sourceName
            ResumeClone = $clone.Data
            CloneIndex = [int]$clone.Data.CloneIndex
            CloneName = [string]$clone.Data.CloneName
            FreshIdentifiers = $false
        }
        return [pscustomobject]@{ Lines = @('  Continuing on the verified clone at index ' + [string]$target.CloneIndex + ' (' + $target.CloneName + '). No second clone is made.'); Result = $null; Proceed = $true; Target = $target }
    }

    $fresh = ($Choice -ceq 'CloneFreshInfo')
    $target = [pscustomobject]@{
        Mode = 'Clone'
        SourceIndex = $sourceIndex
        SourceName = $sourceName
        ResumeClone = $null
        CloneIndex = -1
        CloneName = ''
        FreshIdentifiers = $fresh
    }
    return [pscustomobject]@{ Lines = @(); Result = $null; Proceed = $true; Target = $target }
}

# A fresh instance, which carries nothing from any source. The engine is asked for explicitly because the
# manager otherwise picks a default, and a create aimed at the Android 15 root must not land on 12.
function Invoke-ToolkitMenuNewInstance {
    param(
        [object]$Install,
        [string]$StateRoot,
        [scriptblock]$Ask = $null,
        # The two seams are separate for the same reason as on the target screen: the action seam dispatches
        # the create, the process seam runs the manager's own instance query to find the next free index.
        [scriptblock]$ActionRunner = $null,
        [scriptblock]$ProcessRunner = $null,
        [hashtable]$ActionArguments = @{}
    )

    $installRoot = [string](Get-ToolkitRecordValue -Record $Install -PropertyNames @('InstallRoot'))
    $version = '12'
    if ($null -ne $Ask) {
        $answer = ([string](& $Ask 'Android version for the new instance: 12 or 15')).Trim()
        if ($answer -ceq '15') {
            $version = '15'
        }
        elseif ($answer -ceq '12' -or [string]::IsNullOrWhiteSpace($answer)) {
            $version = '12'
        }
        else {
            $refused = Get-ToolkitResult -Status 'CriticalError' -Message 'The Android version must be 12 or 15, so no instance was created.' -Data (@{ Code = 'TARGET_VERSION_INVALID' })
            return [pscustomobject]@{ Lines = @(Format-ToolkitResult -Result $refused -Interactive); Result = $refused; Instance = $null; Index = -1; Name = '' }
        }
    }

    $result = $null
    try {
        if ($null -ne $ActionRunner) {
            $result = & $ActionRunner 'Target'
        }
        else {
            # The process seam is forwarded so the create can read the manager for the next free index. A
            # production run leaves it unset and reaches the real manager through the action.
            $result = Invoke-ToolkitActionWithElevation -Action 'Target' -InstallRoot $installRoot -StateRoot $StateRoot -Mode 'Create' -AndroidVersion $version -Confirmed -Prompt $Ask -Runner $ProcessRunner
        }
    }
    catch {
        $result = Get-ToolkitResult -Status 'CriticalError' -Message ('The instance could not be created. ' + (Protect-ToolkitText ([string]$_.Exception.Message))) -Data (@{ Code = 'ACTION_THREW' })
    }
    $lines = @(Format-ToolkitResult -Result $result -Interactive)
    if ($result.Status -ne 'Success') {
        return [pscustomobject]@{ Lines = $lines; Result = $result; Instance = $null; Index = -1; Name = '' }
    }
    # The new instance is the selection, so a person can root it in the same run without going back to
    # the dashboard and finding it in the list.
    $instance = [pscustomobject]@{
        Index = [int]$result.Data.Index
        Name = [string]$result.Data.Name
        AndroidVersion = [string]$result.Data.AndroidVersion
        Running = $result.Data.Running
        RootSetting = $null
    }
    return [pscustomobject]@{ Lines = $lines; Result = $result; Instance = $instance; Index = [int]$result.Data.Index; Name = [string]$result.Data.Name }
}
