# MuMu Root Hide Toolkit

A clean-room Windows PowerShell toolkit that roots MuMu Player instances, hides the root
implementation from selected apps, and suppresses MuMu's own advertisement campaign.

Two rules cover every change made inside an emulator. A guest is never modified on the instance you
selected; the change happens on a verified clone. And every action that changes anything writes an
operation journal first, so you can read back what happened with `Verify` before you trust it.

`RemoveAds` and `Restore` are the two exceptions to "inside an emulator": they change campaign files
in the MuMu installation itself, and they keep a byte-exact backup instead of a clone.

This project is not affiliated with, endorsed by, or supported by NetEase, by the original
`Jordan231111/mumu-magisk-1click` project that it is a clean-room reference for, or by any
upstream project named below. See `NOTICE.md` for attribution.

## Status

Read this before you rely on any action. The live qualification matrix is the honest state of the
tool, and it is not uniform.

| Action | Proven on real hardware | Result on this host |
| --- | --- | --- |
| `Detect` | yes | reports installations and instances correctly |
| `Verify` | yes | the read-only report renders every field it collects |
| `Target` | yes | all three modes were exercised: `Identify` read-only, `Create` added instance 3, `Clone` added instance 4 |
| `Root12` | yes, with a caveat | reports `Warning` with `ROOT_AFTER_DISABLE_ROLLED_BACK` and keeps the MuMu vendor root enabled |
| `Root15` | **no** | unqualified. The live run produced a clone that inherited Kitsune, so no built-in-KernelSU target was ever verified |
| `Conceal` | **no** | unqualified. The Vector module install has not succeeded on a live clone, and the target package is not installed on it |
| `RemoveAds` | **no** | wrote nothing. There is no campaign file anywhere in the Chinese-edition installation |
| `Restore` | **no** | nothing to restore, because nothing was suppressed |

Three things the table does not say on its own:

- **`Root12` leaves MuMu's vendor root doing the work, not Kitsune's.** Disabling the vendor root on
  MuMu 6.8 removes the Kitsune `su` path, so the toolkit turns the vendor root back on and reports
  `Warning`. A result of `RootVerified=true` there means a root shell was verified after that
  rollback; it does not mean the Kitsune root survived on its own.
- **`Root12` has no noninteractive path at all.** It is menu-only, so the one Android 12 action that
  is proven cannot be automated from a script.
- **A clone is a new instance, not a copy of your data.** Apps installed on your original are not
  necessarily installed on the clone. That is one of the two documented reasons concealment is
  unqualified on this host; the other is the Vector install, which installing the app will not fix.

Every live result above comes from the Chinese-edition MuMu 6.8.0.0 build. The Global edition is
covered by fixture tests only. `Limitations` states every remaining limit in full.

## Contents

- [Status](#status)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Walkthrough](#walkthrough)
- [Actions](#actions)
- [Pinned versions](#pinned-versions)
- [How the safety rules work](#how-the-safety-rules-work)
- [Verify report](#verify-report)
- [Target selection](#target-selection)
- [Android 12: the exact Kitsune choice](#android-12-the-exact-kitsune-choice)
- [Android 15: built-in root and explicit confirmation](#android-15-built-in-root-and-explicit-confirmation)
- [Concealment scope](#concealment-scope)
- [What a Magisk module is here, and why one is installed](#what-a-magisk-module-is-here-and-why-one-is-installed)
- [Advertisement scope and restore](#advertisement-scope-and-restore)
- [Administrator rights](#administrator-rights)
- [Transport bounds](#transport-bounds)
- [Recovery](#recovery)
- [Command line](#command-line)
- [Limitations](#limitations)
- [Tests](#tests)
- [License and attribution](#license-and-attribution)

## Requirements

- MuMu Player, Global or Chinese edition, in any local installation path. Paths with spaces and
  non-ASCII characters work, and a relocated instance root is discovered rather than assumed. The
  Global edition is supported and discovered correctly, but every live result in this document comes
  from the Chinese edition, so treat Global as fixture-tested only.
- Windows 10 or Windows 11 with Windows PowerShell 5.1 or newer.
- Android 12 or Android 15 instances. The two Android versions use different root implementations and
  are never mixed.

Anything outside those targets fails closed. An unsupported Android version, an ambiguous
installation or instance, an unreadable MuMu manager, an unverifiable clone, or an unverified
dependency stops the action before it changes anything.

## Quick start

This is the setup order, and it is also the shortest path to a result you can verify.

1. Install MuMu Player yourself and create the instance you want to work on. The toolkit never
   installs, updates, or repairs MuMu.
2. Run the `Target` action to pick the instance the later actions will use, to create one, or to
   clone an existing one. It reports the target index, and that index is what the later actions take.
3. Run `Detect` and confirm the reported edition, installation path, and instance index are the ones
   you intend to use.
4. Run `Verify` and read the whole report. Fix anything it reports before you change anything.
5. Run `Root12` for an Android 12 instance, or `Root15` for an Android 15 instance. Each works on
   its own new clone.
6. Run `Conceal` with the package names of the specific apps that must not see root.
7. Run `RemoveAds` to suppress MuMu's own campaign advertisements, and `Restore` to put them back.

The order above is the command-line order. The menu does not use these numbers at all: it has no `Detect`,
`Verify` or `Target` rows, because discovery runs on its own when the menu opens and `Status` is one
keystroke from the instance list. If you prefer the menu, follow [Walkthrough](#walkthrough) instead of
this list.

`Target` does not remember its choice. Every later action needs the target index again, passed as
`-InstanceIndex` or answered at the menu. If you do not pass one and more than one instance is
eligible, the action stops with `INSTANCE_SELECTION_REQUIRED` rather than picking for you.

### The interactive menu

Double-click `Run-MumuToolkit.bat`. The menu is three screens in one design, and every screen is written
again before each prompt so the choices never scroll out of reach.

Every block below is **captured output from a real run** on this repository's own test host, not a mock
up, with one exception applied throughout: the instance names have been replaced with `Base`,
`Device-B` and a description of the clone, so no real machine's names appear here. Everything else on
every line is exactly what the run printed, and the test suite renders the current screens and fails if a
line here is no longer one of them.

The status colors are not visible in the text capture; the console shows green for `Success` and
`AlreadyApplied`, yellow for `Warning`, `RecoverableError` and the invalid-answer hint, red for
`CriticalError`, cyan for the screen title, and dim gray for the rule and safety line.

**1. The dashboard.** It runs the read-only discovery on start, so you see the machines you are about to
change instead of being asked to trust a menu. Two number columns, because they are not the same thing:
`#` is what you type, `Idx` is the index MuMu itself uses.

```text
      #  Idx  Name                Android Running  Vendor root
      1  0    Base                12.0    no       no
      2  2    Device-B            12.0    yes      no
  Installation Chinese  D:\Program Files\Netease\MuMuPlayer

  MuMu Root Hide Toolkit
  ===================================================================
  Create     N New empty instance              new instance
  Advertise  A Remove ads                      changes installation
             B Restore ads                     restores
             Q Quit
  Vendor root is the MuMu setting. The guest root is reported by Status.

Select an instance (1-2), or N, A, B or Q:
```

`Vendor root` is the **MuMu setting**, not the guest. It reads `unknown` when the manager reports no value
at all, because `no` would claim a measurement that was never taken. The real guest root, and which
implementation provides it, is reported by `Status` on the selected instance.

`N`, `A` and `B` each print what they will change and ask for the word `CONFIRM` before doing it. They used
to run from the keypress that chose them, which meant one stray key could spend real disk on a new instance
or rewrite the advertisement files that every instance in the installation shares. The test suite now
asserts that an unconfirmed `RemoveAds`, `Restore` and instance creation each change nothing.

**2 and 3. The target screen, then the action screen.** The target screen decides, it does not perform.
Every guest change in this toolkit is made on a clone, and the action that makes the change is the only
thing that makes the clone, so the target screen records the choice and asks for no confirmation. The
action asks for the confirmation that covers the clone it is about to make. Both screens, captured in one
walk:

```text
  Instance 0  Base  Android 12.0
  ============================================================
  Inspect    1 Status                          read-only
  Target     2 Clone, keep device info         new instance
             3 Clone, fresh identifiers        new instance
             4 Continue on its clone           changes guest
  Back       5 Back to the instances
  Status reads this instance and changes nothing. Every other choice works on a clone.
  The source instance is never written.

Select what to do (1-5):

  Instance 0  Base  Android 12.0
  ===========================================================
  Change     1 Root with Kitsune               downloads + changes guest
  Change     2 Conceal apps                    changes guest
             3 Full setup                      downloads + changes guest
  Back       4 Back to the instances
  Anything that writes prints what it will change and asks for CONFIRM.

  The action will work on a clone of instance 0 (Base).

Select an action (1-4):
```

`Status` sits on the target screen because it reads a guest and changes nothing. It used to sit on the
action screen, which made answering it mean choosing a clone first: you committed to a copy just to look
at the instance you had already named, and the report came back for the source rather than the clone.

Rows 2, 3 and 4 on the target screen are declarations, not clones. The action receives the **source**
instance and makes exactly one clone. An earlier version had this screen clone and the root action clone
that clone, which spent a second full instance on every root run; the test suite now asserts the action is
handed the source and that a resumed run asks for no clone at all.

**Keep device info** is the same choice the MuMu GUI offers, and it is verified rather than assumed. The
manager's own `clone` subcommand has no such flag, so the identifiers are read and compared around the clone
the action makes: row 1 compares the clone's `android_id`, `mac_address` and `imei` against the source and
claims the device info was kept only if they match, row 2 writes fresh values and claims they differ only
if the read-back confirms it. A run where neither is true reports `IDENTIFIER_KEEP_UNVERIFIED` or
`IDENTIFIER_FRESH_UNVERIFIED` instead of a success. The identifier step is reported as its own result, so a
run that rooted successfully and then failed to set fresh identifiers does not claim both.

**Continue on its clone** resolves the clone a previous root action verified and recorded in the operation
journal, and the action resumes it rather than copying again. It reads the journal, not the manager, so it
is available before anything is started, and it refuses with `CLONE_RECORD_MISSING` when there is no record
rather than making a new clone behind your back.

**3. The action screen.** Every row here writes, which is why the read-only `Status` is on the target
screen instead. The rows are filtered by the instance's Android version, so an entry that cannot work is
never offered:

```text
  Instance 0  Base  Android 12.0
  ===========================================================
  Change     1 Root with Kitsune               downloads + changes guest
  Change     2 Conceal apps                    changes guest
             3 Full setup                      downloads + changes guest
  Back       4 Back to the instances
  Anything that writes prints what it will change and asks for CONFIRM.

  The action will work on a clone of instance 0 (Base).
```

The tag on each row is the shortest true statement of what it costs: `read-only` changes nothing,
`new instance` adds a MuMu instance, `changes guest` writes inside the Android guest, `changes
installation` writes the campaign files, `restores` puts files back from a restore point, and `downloads`
reaches the network for a pinned artifact. Anything that writes prints a disclosure first and asks for
`CONFIRM` after, so you read the consequence and then decide. The disclosure is captured further down,
after the `Status` report, because it is part of a real run rather than a diagram.

`Full setup` runs root, then conceal, then the advertisement suppression, in that order. It stops at the
first step that does not succeed and states which steps completed and which did not run, because a chain
that failed halfway leaves a mixed instance. Each step keeps its own operation journal, so a partial run is
resumable rather than mysterious.

Because the menu stays on screen it is a legend rather than a description. What each action does is in
[Actions](#actions) below, and what it is allowed to change is in
[How the safety rules work](#how-the-safety-rules-work).

Here is a real `Status` run on instance 0, captured. The screens above it are omitted so the report is
readable; the run printed them on the way. The report itself is reproduced in full in
[the Verify report section](#verify-report). Notice that it is a **`Warning`**, not a `Success`: the
guest is stopped, so the ADB probe could not run and the report says `Unverified` rather than claiming a
root state it never measured.

```text
[Warning] The read-only report for the instance at index 0 is collected. Root state: Unverified. Concealment: CLONE_UNVERIFIED. Chinese installation D:\Program Files\Netease\MuMuPlayer.
  Log: <state dir>\logs\mumu-root-hide-toolkit.log
  Install.Edition = Chinese
  ...
  Guest.Root = Unverified
  Guest.Code = ADB_FAILED
  Guest.Kitsune = none
  Guest.KernelSU = none
  Failures:
    Failure 1 = The Kitsune package query failed. The installed package list could not be read.
```

Anything that writes prints a disclosure first, so you read the consequence and then decide. Here is the
real `Full setup` row with the confirmation declined:

```text
  This will not change instance 0 (Base) itself.
  It works on a new clone of that instance, so the source is left as it is.
  * The root that applies to this Android version is applied to a clone of this instance.
  * The apps you name next join the Root template on that clone.
  * The campaign advertisement files for this installation are suppressed.
[CriticalError] The full setup changes the instance, so it requires an explicit confirmation. Nothing was changed.
  Code = USER_CONFIRMATION_REQUIRED
  Log: <state dir>\logs\mumu-root-hide-toolkit.log
  Recovery: run Verify for a read-only report, then retry the action. The operation journal and the log are kept under the toolkit state directory.
```

The headline used to read `This will change instance 0 (Base).` while the bullets underneath it
spoke of *the clone*, so the same sentence both promised and denied that the instance you had just selected
was the thing being written to. It now names the source and the clone separately. The advertisement rows
get a different headline again, because they change the installation and touch no instance at all.

Note what did **not** happen: no clone, no download, no cache write. The authorization is checked before
the copy is made, so declining costs nothing.

The two advertisement rows, captured with the confirmation declined. `Remove ads` rewrites files that
every instance in the installation shares, so it discloses and asks for `CONFIRM` like the guest changes do:

```text
  This will change the advertisement files of this installation. No instance is touched.
  * The campaign advertisement files for this installation are suppressed.

[CriticalError] USER_CONFIRMATION_REQUIRED: RemoveAds rewrites advertisement files shared by every instance, so it must be confirmed first. No advertisement file was changed.
  Code = USER_CONFIRMATION_REQUIRED
  Log: <state dir>\logs\mumu-root-hide-toolkit.log
  Recovery: run Verify for a read-only report, then retry the action. The operation journal and the log are kept under the toolkit state directory.
```

Confirmed on a machine with no campaign file present, suppression has nothing to do and says so:

```text
[AlreadyApplied] No MuMu campaign file is present.
  Changed = 0
  Skipped = 0
```

`Restore` on a machine that never removed the ads is a **precondition, not a fault**, and reports a
`Warning` with a success exit code rather than a `CriticalError` that made the launcher stop and wait for a
keypress on a fresh installation:

```text
[Warning] There is no advertisement restore point for this installation yet, so nothing was restored. Run Remove ads first if you want one.
  Code = CAMPAIGN_RESTORE_POINT_MISSING
```

A restore pointed at an installation that is *not* the one the restore point belongs to is a different
thing, and stays a `CriticalError`: returning a success code for a restore that touched nothing would be
worse than a loud refusal.

Every mutating action asks for its confirmation in the menu, and the menu never closes itself when an
action fails. `Q` quits from any screen.

Result lines are colored in the console: green for `Success` and `AlreadyApplied`, yellow for
`Warning`, `RecoverableError`, and the invalid-answer hint, red for `CriticalError`. A row tag that
writes is red and a tag that only downloads is yellow, the screen title is cyan, and its rule and safety
line are dimmed. Set the `NO_COLOR` environment variable to any non-empty value to turn all of the
colors off.

Interactive output is written for a person: a discovery is a summary line and the instance it settled
on, rather than a field dump. **`-NonInteractive` output is unchanged and stays in the `Field = Value`
form**, because that is what a script reads. Captured, on the same host:

```text
PS> Run-MumuToolkit.bat -Action Detect -NonInteractive -InstanceIndex 0
[Success] Discovered Chinese installation D:\Program Files\Netease\MuMuPlayer with 2 instance(s).
  AndroidVersion = 12.0
  Edition = Chinese
  InstallRoot = D:\Program Files\Netease\MuMuPlayer
  InstanceCount = 2
  InstanceIndex = 0
  InstanceName = Base
  ManagerPath = D:\Program Files\Netease\MuMuPlayer\nx_main\MuMuManager.exe
  RootSetting = False
  Running = False
```

## Walkthrough

This is the menu path, start to finish, for a first run on a machine with one Android 12 instance. Every
step below is a real screen from the captures above. Nothing here is written until you type `CONFIRM`, and
you can stop at any step: the menu never closes itself when an action fails.

**1. Double-click `Run-MumuToolkit.bat`.** Discovery runs on its own, so the first thing you see is the
list of instances you are about to choose from, not a menu that asks you to trust it:

```text
      #  Idx  Name                Android Running  Vendor root
      1  0    Base                12.0    no       no
  Installation Chinese  D:\Program Files\Netease\MuMuPlayer

  MuMu Root Hide Toolkit
  ===================================================================
  Create     N New empty instance              new instance
  Advertise  A Remove ads                      changes installation
             B Restore ads                     restores
             Q Quit
  Vendor root is the MuMu setting. The guest root is reported by Status.

Select an instance (1-2), or N, A, B or Q:
```

Read two columns carefully, because they are not the same thing. `#` is what you type; `Idx` is the index
MuMu itself uses. `Vendor root` is the MuMu setting and says nothing about whether the guest is rooted.

**2. Type the number of your instance.** This is the only selection you make by number, and it changes
nothing. You land on a screen that asks what to do with that one instance:

```text
  Instance 0  Base  Android 12.0
  ============================================================
  Inspect    1 Status                          read-only
  Target     2 Clone, keep device info         new instance
             3 Clone, fresh identifiers        new instance
             4 Continue on its clone           changes guest
  Back       5 Back to the instances
  Status reads this instance and changes nothing. Every other choice works on a clone.
  The source instance is never written.

Select what to do (1-5):
```

**3. Type `1` for `Status` first, always.** It reads the guest and changes nothing, and it is the step
that tells you whether the rest is worth doing. Read it in full rather than scanning for the root line:

- `Guest.Root = Unverified` with `Guest.Code = ADB_FAILED` means the guest is **stopped**, not unrooted.
  Start the instance and run `Status` again. A stopped guest cannot answer, and the report says so rather
  than guessing.
- `Guest.Root = Unrooted` is a real measurement: the guest answered and has no root.
- A field that could not be measured reads `not-detected`; a value that is genuinely absent reads `none`.
  Neither is ever turned into a measurement that was not taken.
- Any `Failure 1 = ...` line is a sentence, not a code, and it is the reason anything above it is unknown.

**4. Only once `Status` is clean, pick a target.** On an Android 12 instance choose `2` for
`Clone, keep device info`. Rows `2`, `3` and `4` are **declarations, not clones**: nothing is copied here,
and the action you pick next is the thing that makes the single clone. `4 Continue on its clone` reuses the
clone a previous run recorded in the journal, and refuses with `CLONE_RECORD_MISSING` if there is no record
rather than quietly making you a second instance.

**5. Pick the action.** Every row on this screen writes, which is why the read-only `Status` is not here:

```text
  Instance 0  Base  Android 12.0
  ===========================================================
  Change     1 Root with Kitsune               downloads + changes guest
  Change     2 Conceal apps                    changes guest
             3 Full setup                      downloads + changes guest
  Back       4 Back to the instances
  Anything that writes prints what it will change and asks for CONFIRM.

  The action will work on a clone of instance 0 (Base).

Select an action (1-4):
```

**6. Read the disclosure, then type `CONFIRM`.** The disclosure appears before the question, so you see the
consequence and then decide:

```text
  This will not change instance 0 (Base) itself.
  It works on a new clone of that instance, so the source is left as it is.
  * The pinned Kitsune release is installed into the system partition of the clone.
  * The clone vendor root is turned off, so an app probing for su sees nothing.
```

Anything other than the exact word `CONFIRM` refuses the action and changes nothing. The confirmation is
asked twice on an Android 12 root, and both are required: once for the run, and once for the Kitsune
choice described in [the exact Kitsune choice](#android-12-the-exact-kitsune-choice).

**7. Answer the Kitsune question in the emulator, then wait.** The toolkit launches Kitsune in the clone
and asks you to choose `Install -> Direct Install into system partition` **inside the Kitsune app**, then
asks you to confirm that you did. The cold boot after that is automatic:

```text
  The clone at index 4 (the new clone's name) is rebooting now. This is automatic: nothing else is
  needed from you, and no word will release the wait. The root is checked as soon as the guest
  reports it finished booting.
```

The name in that line is the clone MuMu created, which it names for you rather than asking; the index is
the one that matters, because it is what the journal records and what a later `Continue on its clone`
resumes.

The console is silent for a few minutes while the clone reboots. **Do not type anything.** The wait ends
when the guest reports it finished booting, or when the bound in
[Transport bounds](#transport-bounds) is reached, and never on an answer, so a word you type is not
releasing anything.

**8. Read the result, and check it yourself.** Run `Status` on the clone afterward. The toolkit's own
report is the claim; `Status` is the measurement. On this host `Root12` reports a `Warning` rather than a
`Success`, and the reason is in [Status](#status) above.

### If you only want to read

Type `1` at the instance list, then `1` again. That is the whole read-only path, and it is the only path
that cannot spend disk, download anything, or write to MuMu.

### Recovering from a stop

The menu does not close on a failure. Read the `Code` line, then follow
[Recovery](#recovery). Every action keeps a journal, and a run that stopped part way is resumable through
`Continue on its clone` rather than by starting over on a second instance.

## Actions

| Action | What it changes | Noninteractive command |
| --- | --- | --- |
| `Detect` | nothing in MuMu; reports installations and instances | `Run-MumuToolkit.bat -Action Detect -NonInteractive` |
| `Verify` | nothing in MuMu; reports the read-only status of the selected instance | `Run-MumuToolkit.bat -Action Verify -NonInteractive` |
| `Target` | `Identify` changes nothing; `Create` and `Clone` each add exactly one MuMu instance | `Run-MumuToolkit.bat -Action Target -Mode Identify -NonInteractive` |
| `Root12` | the verified clone of an Android 12 instance | menu only; `-Action Root12 -NonInteractive` always returns `USER_CONFIRMATION_REQUIRED` |
| `Root15` | the verified clone of an Android 15 instance | `Run-MumuToolkit.bat -Action Root15 -Confirmed -NonInteractive` |
| `Conceal` | root visibility for explicitly selected apps on the verified clone | `Run-MumuToolkit.bat -Action Conceal -Packages com.example.app -NonInteractive` |
| `FullSetup` | root, then concealment, then the advertisement suppression, stopping at the first step that does not succeed | `Run-MumuToolkit.bat -Action FullSetup -Packages com.example.app -Confirmed -NonInteractive` |
| `RemoveAds` | MuMu campaign display flags inside the selected installation | `Run-MumuToolkit.bat -Action RemoveAds -NonInteractive` |
| `Restore` | the MuMu campaign files, from the toolkit restore point | `Run-MumuToolkit.bat -Action Restore -NonInteractive` |

`FullSetup` picks the root by the instance's Android version, so it needs `-Packages` and `-Confirmed`.
Its command-line form takes the instance from `-InstanceIndex`; the menu asks for the apps and the
confirmation itself. It is a composition of the three actions above rather than a fourth flow: each step
runs through the same dispatch, keeps its own journal, and the run reports which steps completed.

`Root12` is menu-only. A noninteractive run resolves the installation and the instance and then
refuses with `USER_CONFIRMATION_REQUIRED`, because the Kitsune install is a guided action in the
emulator. The run authorization is checked **before the clone**: declining costs nothing, no instance
is created and the dependency cache is not touched. That ordering was wrong once: the flow cloned an
instance and installed the artifact before asking, so a misclick cost a full instance's disk. The
Kitsune option itself is a second, later question, asked once the clone exists so it can name the
instance the APK actually landed on.
returns `USER_CONFIRMATION_REQUIRED` without creating a clone, without changing anything in MuMu, and
without reaching the network or the dependency cache, because the exact Kitsune choice must be
confirmed by a person and the noninteractive dispatcher carries no confirmation token. The pinned
artifact is verified only once that confirmation exists. There is no one-command Android 12 root
automation; use the menu for that action.

`Conceal` needs a verified clone record from a completed `Root12` or `Root15` run for the same
instance, so a noninteractive `Conceal` follows either a menu `Root12` run or a noninteractive
`Root15` run.

## Pinned versions

The toolkit pins an exact version, size, and SHA-256 hash for every dependency in
`src/Manifest.json`, and verifies all three before it uses a file. A newer release is not treated as
compatible until it has been tested and pinned again.

| Component | Pinned version | Used for | Official release page |
| --- | --- | --- | --- |
| MuMu Player | 6.8.0.0 | the host application under test | [download page](https://www.mumuplayer.com/download/) |
| MuMu Android version selection | Android 12.0 and Android 15.0 | choosing the instance image | [Android version documentation](https://www.mumuplayer.com/help/win/how-to-upgrade-mumuplayer.html) |
| Kitsune Magisk | v31.0-25fa2159 | Android 12 root | [Kitsune release](https://github.com/Jordan231111/KitsuneMagisk/releases/tag/v31.0-25fa2159) |
| Hide My Applist OSS | oss-161 | app and module concealment | [HMA-OSS release](https://github.com/frknkrc44/HMA-OSS/releases/tag/oss-161) |
| Vector | v2.2 | LSPosed module runtime used by HMA OSS; installed at the module id `zygisk_vector` | [Vector release](https://github.com/JingMatrix/Vector/releases/tag/v2.2) |
| NeoZygisk | v2.4 | pinned for future use; no action installs it yet | [NeoZygisk release](https://github.com/JingMatrix/NeoZygisk/releases/tag/v2.4) |
| CorePatch | 4.9 | pinned for future use; no action installs it yet | [CorePatch release](https://github.com/LSPosed/CorePatch/releases/tag/4.9) |

Vector is the current name of the LSPosed project. The pinned artifact comes from the
`JingMatrix/Vector` repository, whose v2.2 release page is the canonical link; the older
`JingMatrix/LSPosed` release path only redirects there.

### The versions this was qualified against

These were read from the live MuMu instance 0 of the Chinese-edition MuMu 6.8.0.0 installation, and
they are the versions the toolkit pins:

| Observed on instance 0 | Version | Version code |
| --- | --- | --- |
| Kitsune Magisk app `io.github.huskydg.magisk` | `31.0-kitsune` | `31000` |
| `magisk` binary and `su` | `31.0-kitsune` | `31000` |
| Hide My Applist OSS `org.frknkrc44.hma_oss` | `oss-161` | `7304644` |
| CorePatch `com.coderstory.toolkit` | `4.9` | `2047` |
| Vector module `zygisk_vector` | `v2.2` | `3080` |
| NeoZygisk module `zygisksu` | `v2.4` | `289` |

The HMA configuration schema observed there is version `93`, which is the version this toolkit reads
and writes. The `zygisk_vector` module was already present on instance 0 as a manual install, not as
anything this toolkit did. The toolkit installs and probes its own Vector artifact at
`/data/adb/modules/zygisk_vector` on a verified clone, and that install has not been observed to
succeed yet, as [Concealment scope](#concealment-scope) states.

Dependencies are downloaded at run time from those official release pages into
`%LOCALAPPDATA%\mumu-root-hide-toolkit\assets`, and each one is verified against its pinned size and
SHA-256 hash before it is used. A download is only ever attempted over `https://github.com`, and a
file that fails its hash is never used. Design intent: a dependency is never fetched from an elevated
phase, so nothing is downloaded after rights are raised.

The two actions that need a dependency do not ask the same way, and the difference is worth knowing
before your first root run:

- `Conceal` asks first. It only fetches when you pass `-FetchDependencies`, or when you type `FETCH`
  at the menu, and its install step is cached-only, so an elevated retry can never reach the network.
- `Root12` fetches the pinned Kitsune artifact itself when the per-user cache does not already hold
  a verified copy, and it does not stop to ask. It does that only after the operator has confirmed
  the workflow, so a run that is refused for a missing confirmation reaches neither the network nor
  the cache. To pre-place the file yourself, put the pinned asset in the cache directory under its
  `id` before running `Root12`.

## How the safety rules work

**Clone first.** Every mutating action creates and verifies a clone before it changes anything. The
instance you selected is only stopped so that it can be cloned, and the toolkit does not start it
again afterwards. The clone's index, name, Android version, installation boundary, and disk are
verified, and the clone index is written to the operation journal. If any of those checks fail, the
action stops and the selected instance is not used.

A clone is a new MuMu instance created from the source's configuration. It is not a copy of the
source's installed apps or app data, so an app you have on the original may not be on the clone.
`Conceal` checks this and refuses a package the clone does not have.

**Journal first.** Every operation writes a journal under
`%LOCALAPPDATA%\mumu-root-hide-toolkit\journals` before it changes anything, and the journal carries
the action's state, its evidence, and its outcome. A log is written alongside it at
`%LOCALAPPDATA%\mumu-root-hide-toolkit\logs\mumu-root-hide-toolkit.log`. Both are written with user
paths and identifiers redacted.

**Fail closed.** An interrupted action is never treated as successful. An ambiguous discovery, an
unreadable manager, an unverifiable clone, an unverified dependency, or an unanswered question stops
the action and reports a code, rather than guessing.

**Administrator rights are never taken silently.** See [Administrator rights](#administrator-rights).
The toolkit never suppresses the UAC prompt, never creates a scheduled task, never changes the
execution policy permanently, and never takes ownership of files or weakens an access control list.

## Verify report

`Verify` changes nothing in MuMu and prints the whole read-only report, so nothing it found stays
invisible to you. The report is plain text with one field per line, so it can be read directly or
searched for a single field.

A captured report is reproduced here in full. The screens that produced it are in
[the interactive menu section](#the-interactive-menu). The fields fall into four groups: the
installation and the manager (`Install.*`, `ManagerVersion`), every instance the manager reports
(`Instances`), the guest itself (`Guest.*`), and what the toolkit has on record (`Ads`, `Backups`,
`Concealment`, `Journal*`), ending with the failures that explain anything unreadable.

```text
[Warning] The read-only report for the instance at index 0 is collected. Root state: Unverified. Concealment: CLONE_UNVERIFIED. Chinese installation D:\Program Files\Netease\MuMuPlayer.
  Log: <state dir>\logs\mumu-root-hide-toolkit.log
  Install.Edition = Chinese
  Install.InstallRoot = D:\Program Files\Netease\MuMuPlayer
  Install.VmsPath = D:\Program Files\Netease\MuMuPlayer\vms
  Install.ManagerPath = D:\Program Files\Netease\MuMuPlayer\nx_main\MuMuManager.exe
  Install.Source = Registry
  ManagerVersion = Unknown
  Instances:
    Instance 0 | Base | Android 12.0 | Running False | RootSetting False
    Instance 2 | Device-B | Android 12.0 | Running True | RootSetting False
  Virtualization = Enabled
  Guest.Root = Unverified
  Guest.Code = ADB_FAILED
  Guest.RootPermission = not-detected
  Guest.Kitsune = none
  Guest.KernelSU = none
  Guest.DaemonCount = not-detected
  Guest.HmaInstalled = not-detected
  Guest.VectorModuleInstalled = False
  Ads.RestorePoint = Missing
  Backups.CloneIndex = not-detected
  Backups.CloneName = none
  Concealment.Target = none
  Concealment.Status = NotVerified
  Concealment.Code = CLONE_UNVERIFIED
  Concealment.Packages = none
  Concealment.InScope = none
  Concealment.OutOfScope = none
  Concealment.TemplateFound = False
  Concealment.IsWhitelist = False
  Concealment.HmaConfigVersion = not-detected
  Concealment.KernelSUInstalled = False
  Concealment.AllowlistPresent = False
  JournalState = None
  JournalOperation = none
  JournalId = none
  Failures:
    Failure 1 = The Kitsune package query failed. The installed package list could not be read.
```

Two details are worth reading rather than skimming:

- A field that could not be measured reads `not-detected`, and a value that is genuinely absent reads
  `none`. Neither is ever turned into a measurement that was not taken.
- A report on a **stopped** instance comes back as `[Warning]` with `Guest.Code = ADB_FAILED`, because
  the guest could not be reached. That is the report being honest, not the report being broken. Start
  the instance and run it again to get a real root state.

Two things to know about that report. A real `Failure` entry is a full sentence rather than a short code,
and the `Concealment` block is the widest part of the report because concealment is a per-app claim: it
carries the packages in scope and out of scope, the Hide My Applist configuration version, and whether
the KernelSU package is installed. A run where an app was refused before any scope was written reports
`PACKAGE_NOT_INSTALLED` with no package under test, which is the honest result for a run that changed
nothing.

`Guest.Root = Unverified` with `Guest.Code = ADB_FAILED` is what a **stopped or unreachable** instance
looks like. A healthy, running guest shows `Guest.Root = Verified`.

**Two instance indexes appear in one report, and they are not the same instance.** The `Install.*`,
`Instances` and `Guest.*` lines describe the instance you selected. The `Backups.*` and `Concealment.*`
lines describe that instance's verified clone, which is the one the toolkit changed. In a report for a
rooted instance the header and `Backups.CloneIndex` therefore name different indexes, and
`Backups.CloneIndex` is where you read back which instance is actually rooted. A root action's own
result reports the same number as `CloneIndex`.

The report names the installation identity, every discovered instance with its index, Android
version, and vendor root setting, the virtualization state, the guest root and root daemon
evidence, the Hide My Applist and Vector module state, the advertisement restore point, the verified
clone backup, the concealment scope observed on that clone, the last journal state, and every
failure it collected.

How to read a field:

- A value the manager or the guest did not report is printed as `not-detected`.
- A value that is present but empty is printed as `none`.
- A field that carries a collection is printed as its count followed by its quoted elements, for
  example `1: "a.b"`, so two package names can never be read as one odd package name. An empty
  collection is printed as `none`, and a collection the report could not read at all is printed as
  `not-detected`.
- The guest root daemon count and the Hide My Applist and Vector module states are tri-state on
  purpose. A probe the guest never answered prints `not-detected` and is recorded in `Failures`,
  which is how a probe that failed to answer is distinguished from a guest that answered "absent".
- A clean instance prints `Failures: none` after the same field list, so an empty failure list is
  stated rather than implied.

A concealment evidence that is not a verified scope is recorded in `Failures` with its code, so the
status is never quieter than the report: a concealment warning makes `Verify` a `Warning`, and a
concealment failure makes it a `CriticalError` that exits `1`.

The `Concealment` lines are the evidence the verifier collected by reading the installed Hide My
Applist configuration on the verified clone, so the verifier is reachable and no concealment claim
exists without an observation behind it. The packages under test are the ones the toolkit itself
assigned to the blacklist `Root` template, so nothing has to be named again. An Android 12 Kitsune
clone has no KernelSU package, so it honestly reports `KERNELSU_ABSENT` and
`Concealment.Status = Warning` instead of a claimed success, and an instance with no verified clone
record reports `CLONE_UNVERIFIED` with `Concealment.Target = none`.

## Target selection

`Target` is the prerequisite step. It reports which instance the later actions would work on, and
it is the only action that can add a MuMu instance. It never starts root or concealment work, and it
never guesses: when more than one eligible instance exists it requires an explicit `-InstanceIndex`
or a menu choice.

| Mode | What it changes | Confirmation |
| --- | --- | --- |
| `Identify` | nothing in MuMu; lists every discovered instance with its index, name, Android version, running state, and eligibility, then names the selected target | not required, because it is read-only |
| `Create` | adds exactly one new instance, at the index MuMu actually assigns | required: the menu asks for a free index to insist on and then for `CONFIRM`; the command line requires `-StartIndex` and `-Confirmed` |

In the menu, the free index prompt names the next free index it found and **pressing Enter takes it**, so a
blank answer is a decision rather than a refusal. The suggested index is read from the manager and fills the
lowest gap, so a machine whose indexes are `0, 1, 3` is offered `2`. An answer that is not a number is still
refused with `TARGET_START_INDEX_INVALID`, and the refusal carries the offered default in `Suggested`.
| `Clone` | adds exactly one clone of a source instance, after stopping that source instance | required: the menu asks for `CONFIRM` once the source is known; the command line requires `-Confirmed` |

The menu asks for the mode with the words `Identify`, `Create`, or `Clone`, and asks which instance
to use when more than one is eligible. A noninteractive run never prompts and never confirms
anything, so it must carry the parameters itself:

```text
Run-MumuToolkit.bat -Action Target -Mode Identify -InstanceIndex 2 -NonInteractive
Run-MumuToolkit.bat -Action Target -Mode Create -StartIndex 5 -Confirmed -NonInteractive
Run-MumuToolkit.bat -Action Target -Mode Clone -SourceIndex 2 -Confirmed -NonInteractive
```

`-Mode`, `-StartIndex`, and `-SourceIndex` belong to `Target`; any other action refuses them. Every
refusal changes nothing and reports a code:

| Code | Meaning |
| --- | --- |
| `TARGET_MODE_REQUIRED` | a noninteractive run supplied no `-Mode` |
| `TARGET_MODE_INVALID` | the supplied mode is not `Identify`, `Create`, or `Clone` |
| `TARGET_START_INDEX_REQUIRED` | a noninteractive `Create` supplied no usable `-StartIndex` |
| `TARGET_START_INDEX_INVALID` | the free instance index answered in the menu is not a non-negative integer; the answer carries the offered default in `Suggested` |
| `START_INDEX_UNREADABLE` | the manager reported no instance state, so no free index could be offered; pass `-StartIndex` |
| `TARGET_PARAMETER_MISUSE` | `-Mode`, `-StartIndex`, or `-SourceIndex` was supplied to another action |

`Target Clone` refuses a source instance that is a base instance, has an unsupported Android version,
or has an unknown state, so it never returns an unusable target.

`-StartIndex` is a precondition, not an instruction to the manager. The toolkit verifies that the
index is free and refuses to continue when it is not, then asks MuMu to create one instance. The
requested index is never sent to the manager, and no existing index is ever overwritten.
MuMu assigns the index itself, so the created index can differ from the requested one.
`Index` in the result is the only authoritative index, and the result also echoes the precondition
as `RequestedIndex`. Always use the returned `Index` for later actions, never the requested index.

`Create` never overwrites an index and never deletes or renames anything. After the manager reports
the new instance, the action requires exactly one new index and verifies that it is a non-base
instance with a readable Android version, an instance root inside the selected installation, and a
usable disk. `Clone` reuses the same verified clone flow that `Root12` and `Root15` use. Neither
mode changes any other instance, and both are recorded in the operation journal.

The reported target index is the value to pass to `-InstanceIndex` for `Root12`, `Root15`, and
`Conceal`. `Target` does not store that choice: the toolkit never picks an instance on your behalf
in a later run.

## Android 12: the exact Kitsune choice

`Root12` is an interactive action; run it from the menu. It verifies the pinned Kitsune artifact,
creates and verifies a clone, enables the temporary MuMu vendor root on that clone only, installs
the Kitsune app, and starts it. The workflow then pauses and waits for you, in the Kitsune app on
the clone, to choose exactly:

```text
Install -> Direct Install into system partition
```

Do not choose the ordinary `Direct Install` or `Select and Patch a File` option. Only the exact
choice above is accepted; any other answer stops the workflow before the cold boot, and the clone is
left as it is.

### If the system-partition option is not there

**The `Direct Install` option that modifies `/system` directly does not always appear on the first
open.** On some clones and after some reboots, Kitsune shows only the ordinary options, and the
system-partition choice is simply absent from the screen.

When that happens, **close the Kitsune app completely and open it again**, then look for the option
again. Do not fall back to `Select and Patch a File`: it patches a boot image instead of writing the
system partition, which is not what this workflow verifies, and the toolkit will not accept a
confirmation of a choice that was not that one.

Two other things that look like a hang but are not:

- **The in-app reboot button does not work on an emulator.** That is expected. The workflow does not
  use it: after you confirm the choice, the toolkit performs its own cold boot through the MuMu
  manager. **Do not reboot the clone yourself first** - if you do, the toolkit simply shuts it down
  and boots it again, which costs you a second boot for nothing.
- **The console looks frozen after you confirm, for several minutes.** That is the cold boot. It
  prints a line saying the reboot is automatic and that no word releases the wait. Wait for it. It
  ends when the guest reports it finished booting, or when the bound in [Transport bounds](#transport-bounds)
  is reached, and never on an answer.

### What the confirmation prompt actually asks for

There are **two** gates, and they want **different** words. This trips people up, because the second
prompt names the option to choose in the app and used to leave you to guess what to type:

| Gate | When | Type |
| --- | --- | --- |
| Run authorization | before the clone is made | `CONFIRM` |
| Kitsune choice | after you install in the app, before the cold boot | `Direct Install into system partition` |

The second answer is matched case sensitively and in full, so `confirm`, `yes` and `Done` are all
refused with `USER_CONFIRMATION_REQUIRED`. The prompt now states the exact string to type, and the
prompt is generated from the same value the gate compares against, so the two cannot drift apart. If
you get that refusal, nothing was rebooted and no root was claimed; re-run and type the full phrase.

If you abandon the run at that prompt, the clone is left with the **temporary vendor root still
enabled**, because it is enabled before the install and only disabled after the root is verified.
Either finish the run or resume it with `Continue on its clone`, which picks the same clone back up
from the journal rather than making another one.

After you confirm, the toolkit cold-boots the clone, verifies the Kitsune package, the root daemon,
and a root shell, disables the temporary vendor root again, and then repeats the same three checks.
Success is reported only when those checks still pass after the cleanup, because disabling the vendor
root can remove the root shell.

On MuMu 6.8 that cleanup does remove `/system/bin/su` while the Kitsune files and one `magiskd`
survive. The adb shell on that build stays `uid=2000`, root comes from the Magisk `su`, and the
`su` path lives at `/system/bin/su`, so the Kitsune root does not survive the cleanup. When the
checks after the cleanup fail, the toolkit therefore enables the vendor root again on that clone,
reads the settings back, repeats the three checks, and reports a `Warning` with the code
`ROOT_AFTER_DISABLE_ROLLED_BACK`, `VendorRootRetained`, and a message that names the retained vendor
root and the removed `su` path. The journal is completed as a warning, the clone keeps the vendor
root on, and the result is never reported as a `Success` root result.

A script must check `Status`, not the process exit code, because a `Warning` exits `0`. If the
rollback itself fails, the toolkit reports `CriticalError` with the code `ROOT_RECOVERY_FAILED`, fails
the journal, and claims no root. Nothing outside the selected clone is changed in either path.

## Android 15: built-in root and explicit confirmation

`Root15` never installs Kitsune or Magisk. It creates and verifies a clone, enables MuMu's built-in
root setting on that clone, cold-boots it, and verifies the built-in KernelSU package, the absence of
the Kitsune package, and a root shell, in that order. The Kitsune check runs first so a clone that
inherited the Kitsune package is reported as `KITSUNE_PRESENT`, with the observed package line,
instead of being reported as a root denial it never had. A guest with no `su` binary at all is
reported as `ROOT_UNAVAILABLE`, which says the root state is unknown, rather than as a policy denial.
The built-in root is kept enabled on the clone.

Because that change is not reversible through the toolkit, `Root15` requires explicit confirmation.
The menu asks you to type `CONFIRM`; the command line requires `-Confirmed`. Without it the action
changes nothing and reports `USER_CONFIRMATION_REQUIRED`.

Android 15 is **not qualified on this host yet.** The live run on the instance at index 1 produced a
clone that inherited `io.github.huskydg.magisk` and had no usable `su` and no built-in KernelSU
daemon, so that clone is not a valid built-in-KernelSU target and the action reported
`KITSUNE_PRESENT`. A source instance that already carries Kitsune cannot be qualified with
`Root15`; a Kitsune-free instance still has to be run before Android 15 can be called qualified.

## Concealment scope

`Conceal` changes only the verified clone and only for the apps you name. It refuses to run without
`-Packages`, refuses any package that is not installed on the clone, and refuses a selection that
would cover every installed app, because concealment is a per-app change and a global scope is not
supported.

The action builds a reusable `Root` template that hides the installed root packages, assigns it to
each explicitly selected app, and leaves every other app untouched. It backs up the Hide My Applist
OSS configuration on the clone before writing and verifies the backup byte for byte. The KernelSU
Superuser profile is not machine readable, so the action prints the exact manual steps to confirm in
the app rather than claiming that state; those steps are printed by the action itself and are not
reproduced here. If the configuration schema is unknown or unsupported, the action writes nothing and
hands off the supported UI steps instead.

`Conceal` installs or verifies its declared dependencies before it writes anything, on the verified
clone only, and reads both back from the guest afterwards. The two dependencies are the pinned HMA
OSS artifact, installed as a package, and the pinned Vector artifact, whose only accepted module id
is `zygisk_vector`. NeoZygisk is a root-side module, not a concealment dependency, so `Conceal` never
acquires or installs it.

Acquisition and mutation are separate phases. The install step is cached-only, so it can never reach
the network. The pinned assets are fetched and verified first, and only when you ask for it with
`-FetchDependencies` on the command line or by typing `FETCH` at the menu:

```text
Run-MumuToolkit.bat -Action Conceal -FetchDependencies -Packages com.example.app -NonInteractive
```

The menu asks the same question with the same explicit consent, so a cold cache is reachable without
leaving the menu, and any other answer downloads nothing. The question is asked only when a download
is actually missing, so a cache that already holds both verified pinned assets is used without a
prompt, and an explicit `-FetchDependencies` on the command line is honored instead of being asked
about again. Without that consent the run uses the already verified per-user cache and fails closed
with `ASSET_VERIFICATION_FAILED`, and that failure names both remedies. An elevated retry never
fetches: the toolkit downloads nothing after rights are raised.

### Three contracts the live guest actually dictates

- **Guest commands.** The MuMu manager strips double quotes from a request, so every `su -c` command
  is sent as one single-quoted guest command built by the shared guest-command funnel. It accepts
  only the command words, options, and operators concealment needs, every path must be a plain
  absolute guest path, and a quote, a substitution, a newline, or a space inside a path is refused
  instead of escaped.
- **The HMA scope map.** HMA configuration version 93 stores the per-app assignment in `scope`,
  keyed by package name with the template name as the value. That is the only key the toolkit writes;
  it never creates an `apps` key, and it preserves every other field of the configuration as it found
  them. A `scope` that is not a map of package to template name is refused as an unsupported schema.
- **The Vector archive.** The pinned Vector v2.2 asset is a flat Magisk module archive, so the
  staging directory itself is moved into `/data/adb/modules/zygisk_vector` after its root
  `module.prop` is validated, including the declared module id. A single top-level `zygisk_vector/`
  directory is also accepted. An archive that is both, neither, carries another module root, or
  declares another module id is refused, and its staged archive and staging directory are removed.

The verifier reports `Warning` with `KERNELSU_ABSENT` on a clone where the KernelSU package is not
installed, such as an Android 12 Kitsune clone, and claims no KernelSU profile state there; the
manual handoff stays. On that clone the root comes from Kitsune, and the HMA scope and Vector module
are the parts this toolkit can verify from observation. That result is also carried in the read-only
`Verify` report, so it is not a claim you have to take on trust.

**Concealment is unqualified on this host, for two independent reasons, and both are visible in the
`Verify` report.** The pinned Vector module was **not installed**: the live dependency step on clone 4
stopped with `MODULE_LAYOUT_UNSUPPORTED` before the move, so the HMA artifact was installed and
verified while the Vector artifact was not installed at all. Separately, the selected app
`jp.pokemon.pokemontcgp` is not installed on the live clone 4, so the action refuses it with
`PACKAGE_NOT_INSTALLED` and no concealment scope is applied. No artifact is invented for a package
that is absent; install the app on the clone yourself, or select apps that are installed, before
concealment can be called qualified. The Vector install path has been exercised only by fixtures,
and the flat-archive gate for the pinned v2.2 asset has not been run against a live clone.

## What a Magisk module is here, and why one is installed

Exactly one Magisk module is ever installed by this toolkit: the pinned **Vector** v2.2 module, into
`/data/adb/modules/zygisk_vector`. This section explains what it is, why concealment needs one, and
exactly what the toolkit does to put it there, because "installs a module" is otherwise a sentence you
have to take on trust.

### Why a module at all

The root itself is **not** a module. On Android 12, Kitsune is installed into the system partition by the
Kitsune app's own `Install -> Direct Install into system partition` flow, and it lives in the partition,
not in a module directory. On Android 15 the built-in root is enabled through MuMu's own setting. Neither
root is something this toolkit drops into a folder.

Concealment is a different job, and it needs something that runs in the same space as the apps being
hidden from. A root implementation is visible to an app that looks for it: it can find `su` on the `PATH`,
find a root daemon, find a root package by name, or notice a patched binary. Vector is a Zygisk-based
module that intercepts the app process at load time so those signals are not there to find. So the chain is:

- **Kitsune, or MuMu's built-in root, provides root.** Installed into the partition, not as a module.
- **Hide My Applist OSS** rewrites the package list an app can see, so the root *packages* are absent from
  an app's view. Installed as an ordinary APK with `install -r`.
- **Vector** is the part that has to live in the root implementation's own space, because it hooks process
  creation. That is a module, so it is the one thing that must go into `/data/adb/modules`.

None of the three is redundant. HMA hides the packages, Vector hides the hooks and the `su` path, and the
root itself does the actual work.

### What counts as a module

A Magisk module is a **directory**, not an archive, and not an app. It lives at
`/data/adb/modules/<module id>/` and contains at least a `module.prop` declaring `id=`, plus a `bin`
directory or a `*.sh` boot script. The root implementation reads those directories at boot and loads each
one. So installing one is a matter of putting a correctly shaped directory in a specific place, and the
whole difficulty is knowing the shape is right before you move it.

### How the toolkit installs Vector

On the verified clone, in this order, every step refusing to continue on failure:

1. **Verify the artifact before it goes near the guest.** Size and SHA-256 are checked against
   `Manifest.json` in the per-user cache. This step never reaches the network; a download happens only if
   you asked for one with `-FetchDependencies` or by typing `FETCH`. A mismatch is `ASSET_VERIFICATION_FAILED`
   and nothing is staged.
2. **Check whether it is already there.** `ls /data/adb/modules/zygisk_vector`. If it answers with
   content, the module is recorded as already present and the install is skipped rather than repeated.
   If the listing cannot be read at all, the run stops with `ADB_FAILED`, because "unknown" is not
   "absent" and installing over an unknown state is not safe.
3. **Stage the archive.** `adb push` the verified zip to `/data/local/tmp/`.
4. **Extract it.** `unzip -o` into a fresh `/data/local/tmp/vector-extract-<random>/`, so a stale
   directory from an earlier run can never be mistaken for this run's contents.
5. **Inspect the layout, and accept exactly two shapes.** Either a single top-level `zygisk_vector/`
   directory, or a flat module archive whose root `module.prop` is validated: the declared `id` must be
   `zygisk_vector`, there must be a `*.sh` or `bin` entry, and there must be no second module root nested
   inside. An archive that is both shapes, neither, carries a nested module, or declares a different `id`
   is refused with `MODULE_LAYOUT_UNSUPPORTED`.
6. **Move it into place.** `mv` the validated directory to `/data/adb/modules/zygisk_vector`.
7. **Read it back.** The module directory must exist after the move or the install is
   `MODULE_INSTALL_FAILED`. A move that reported success but produced nothing is a failure, not a pass.
8. **Clean up on every failure after the push.** Any refusal from step 4 onward removes the pushed archive
   and the staging directory, so a rejected archive is never left sitting in the guest.

The clone is then rebooted by the action that owns it, and the module is loaded at that boot. `Verify`
reports what it can observe afterwards: `Guest.VectorModuleInstalled` is read from the guest rather than
assumed from the install having returned success.

### What is in the manifest but never installed

`Manifest.json` pins five artifacts. Only three are installed by any action, and the other two are
deliberately not:

| Artifact | Installed | Why |
| --- | --- | --- |
| `kitsune` | yes, by `Root12` | the Android 12 root itself, into the system partition |
| `hma` | yes, by `Conceal` | an APK, installed as a package, not a module |
| `vector` | yes, by `Conceal` | the one Magisk module, into `/data/adb/modules/zygisk_vector` |
| `neozygisk` | **never** | a root-side Zygisk implementation, not a concealment dependency. Pinning it documents what it is not used for. |
| `corepatch` | **never** | an app-level bypass module. Out of scope for concealment. |

A pinned dependency that is never installed is worth stating plainly, because "the manifest lists it" and
"the toolkit installs it" are different claims and only one of them is true here.

### What is not proven about this

The Vector install path has been exercised by **fixtures only**. On the live host it stopped at step 5
with `MODULE_LAYOUT_UNSUPPORTED`, before the move, so the flat-archive gate has never been run against a
real clone. That is why the steps above describe the intended behaviour rather than a recorded success,
and it is the first thing to fix if you are re-qualifying this on your own machine. See
[Status](#status).

## Advertisement scope and restore

`RemoveAds` touches only MuMu's own campaign configuration inside the selected installation:
`shell\ad\campaign.json` and `nx_device\configs\campaign.json` for the Global edition, and
`MuMuPlayer\ad\campaign.json` and `shell\ad\campaign.json` for the Chinese edition. It sets the
existing campaign `display` flags to false, keeps an exact byte backup of every file it changes
together with the original read-only state, and refuses to overwrite an existing restore point. It
never patches games, changes app data, changes network settings, or suppresses any third-party
advertisement.

To restore:

1. Run `Run-MumuToolkit.bat -Action Restore -NonInteractive` and select the same installation with
   `-InstallRoot` if more than one is discovered.
2. The newest restore point for that installation is applied, and the restored files and their
   read-only state are reported.
3. Every restored path is re-validated against the installation root, the restore boundary the
   advertisement module calls `AllowedRoot`. A restore path outside that boundary is refused and no
   file is written.
4. If no restore point exists for the installation, nothing is changed and the action reports
   `CAMPAIGN_RESTORE_POINT_MISSING`.

Restore points live under `%LOCALAPPDATA%\mumu-root-hide-toolkit\campaigns`, one directory per
installation scope, each with its own `restore-point.json`.

## Administrator rights

Actions never bypass, weaken, or reconfigure Windows security. The toolkit never suppresses the UAC
prompt, never creates a scheduled task, never changes the execution policy permanently, and never
takes ownership of files or weakens an access control list.

The mutating actions that write inside the MuMu installation are `RemoveAds`, `Restore`, `Target`
create and clone, `Root12`, `Root15`, and `Conceal`. They are reachable through elevation, and the
sequence is deliberate:

1. The action is attempted in this process, exactly once. A host whose manager calls and file writes
   already succeed unelevated is never prompted at all.
2. Only a permission failure asks for administrator rights, once and only once. The elevated child
   is a direct `RunAs` relaunch of the controller with the same allowlisted action, the same bound
   paths, and the same operator confirmation, so nothing is retried with more authority than you
   gave.
3. The elevated child never asks for rights again. It runs with the internal `-ElevatedChild` switch,
   and the process entry point does not arm the elevation seam for it, so a second attempt is not
   possible even if the dispatcher misreads the failure.
4. The child may run only a script inside this toolkit's own `src` directory. The check is made on
   resolved paths, so a junction or symlink on the way in cannot carry it out of the boundary.

The read-only actions `Detect` and `Verify` never ask for rights: they change nothing in MuMu. They
still create the toolkit state directory, and a non-success result appends a redacted line to the
toolkit log.

If elevation is declined or fails, the action fails closed: the result is a `CriticalError` naming
the permission problem, the operation journal records the failure, nothing that changes MuMu is
retried in this process, and no configuration is left half-written on purpose. An unanswered UAC
prompt is the same case: the prompt is waited on for a bounded time, and an expired prompt reports
the bound and claims no elevated child. The interactive menu stays open. Starting
`Run-MumuToolkit.bat` from an elevated console (Run as administrator) is still supported and skips
the prompt entirely, because a process that already holds rights is never asked for them again.

Only host access denials ask for rights. The classifier recognizes a .NET unauthorized-access or
access-denied failure and a manager message that names one; a guest shell refusal such as `su:
permission denied` is a guest answer and never raises a prompt. The two bounds are in
[Transport bounds](#transport-bounds).

The elevated retry is noninteractive. Bind every selection explicitly on the command line, with
`-InstallRoot`, `-InstanceIndex`, `-SourceIndex`, `-Mode`, `-StartIndex`, and `-Packages`, or the
elevated child reports the missing selection instead of prompting for it.

## Transport bounds

Every external process except the elevated relaunch is started through one funnel, so a wedged
`MuMuManager.exe` or a blocked ADB port cannot hang the menu. The wait is bounded at 120 seconds per
call, the child is terminated when that bound expires, and the call is reported as a transport
failure that names the timeout. Both redirected streams are drained while the child runs, so a large
response cannot wedge it.

A surviving grandchild can inherit a redirected handle and hold it open after the child itself has
exited, so the stream never reaches EOF. When the bounded drain expires with output still
uncollected, the call is reported as a transport failure that says so, and the capture is discarded
rather than reported as empty output behind the child's real exit code. No caller therefore reads a
clean exit with no output as a real negative: a package that could not be listed, a daemon that could
not be queried, or a module that could not be probed is a transport failure, not an absent one.

A read-only transport call is retried up to 3 times with a 2 second pause, and only for a transport
failure or an explicit not-started transient such as a stopped instance. The read-only test is a
whole-command invariant, not a first-token match: a request that carries an operator, a shell
metacharacter, or any state-changing command word anywhere is never retried, so a command that starts
read-only and then removes or moves something cannot be repeated. A semantic refusal is answered
once, and nothing that changes MuMu is ever retried: a clone, create, install, root change,
advertisement change, or module install runs exactly once. When a read-only retry is exhausted the
result is `RecoverableError` with the last underlying error in its message, so a noninteractive run
exits `2`.

A boot poll is not multiplied by the retry. The poll is its own retry, so its probe runs once per
attempt and the whole poll stops at a 10 minute wall-clock budget, which puts one cold boot at **12
minutes** in the worst case: the budget plus the one in-flight 120 second process bound. Whichever
bound is reached first ends the wait, and that is the bound the timeout message names: with fast
answers the 30 attempt ceiling ends the poll, and the budget ends it only when a probe is slow enough
to eat into it.

The elevated relaunch is the one process a person can hold open, because Windows shows the UAC
consent dialog and waits for a human, so it carries its own two bounds and is documented separately
from the 120 second funnel. The consent is bounded by a 120 second timeout rather than by a proven
120 second wall clock: the toolkit stops waiting at that point, and it cannot say when Windows closes
a dialog nobody answered. The elevated child that does run runs one whole action and is bounded at 60
minutes, which is above the worst case of the longest elevated action. An unanswered or expired
prompt fails closed: the action reports a `CriticalError` that names the bound, no elevated child is
claimed, and nothing is retried here. A consent answered in the instant the timeout expires can still
create a child; that child is waited on and terminated, and the run still fails closed without
claiming an outcome for it.

| Process | Bound |
| --- | --- |
| MuMu manager, guest ADB, and every other tool child | 120 seconds, then terminated |
| one read-only call with its retry | about 6 minutes |
| one boot poll | 12 minutes (10 minute budget plus one 120 second call) |
| UAC prompt | 120 second timeout, then failed closed; a child created by a late consent is terminated |
| elevated child action | 60 minutes, then terminated and failed closed |

## Recovery

- Every operation keeps a journal under `%LOCALAPPDATA%\mumu-root-hide-toolkit\journals`, and the
  log is at `%LOCALAPPDATA%\mumu-root-hide-toolkit\logs\mumu-root-hide-toolkit.log`. Both are
  written with user paths and identifiers redacted.
- An interrupted action is never treated as successful. Read the journal, run `Verify` for a fresh
  read-only report, and run the action again.
- Re-running a root action creates an additional verified clone instead of reusing an old one. Earlier
  clones are left in place, so the original and any previous clone remain available to you, and
  nothing is deleted for you: remove an unwanted clone through MuMu's own instance manager. The
  module can resume on a recorded clone, but neither the menu nor the command line exposes that yet,
  so re-running is the supported recovery path.
- Advertisement changes are undone with `Restore`, described above.
- The temporary MuMu vendor root is left enabled on an Android 12 clone when root verification fails,
  because disabling it would hide the state that needs investigation.
- Nothing under `%LOCALAPPDATA%\mumu-root-hide-toolkit` is ever pruned by the toolkit. Journals, the
  log, and the verified asset cache accumulate across runs, so that state directory is the one thing
  to clear by hand if it grows past what you want to keep. Clones live in MuMu, not there, and are
  removed through MuMu's own instance manager.

## Command line

`-Action` is honored only together with `-NonInteractive`. Without `-NonInteractive` the launcher
opens the menu and the `-Action` value is ignored.

| Parameter | Meaning |
| --- | --- |
| `-InstallRoot <path>` | select one discovered installation without a prompt |
| `-InstanceIndex <n>` | select one eligible instance without a prompt; the target index reported by `Target` |
| `-StateRoot <path>` | override `%LOCALAPPDATA%\mumu-root-hide-toolkit` |
| `-Packages <a,b>` | the exact package names to conceal; required by `Conceal` |
| `-Mode <mode>` | the `Target` mode: `Identify`, `Create`, or `Clone` |
| `-SourceIndex <n>` | the `Target Clone` source instance; defaults to `-InstanceIndex` |
| `-StartIndex <n>` | a free instance index that `Target Create` insists on before it calls the manager; it is never sent to the manager and never overwritten |
| `-Confirmed` | the explicit confirmation required by `Root15`, `Target Create`, and `Target Clone` |
| `-NonInteractive` | run one action and exit instead of opening the menu |
| `-FetchDependencies` | `Conceal` only: fetch and verify the pinned HMA and Vector artifacts into the per-user cache before installing them; without it the run requires an already verified cache. The menu asks the same question and `FETCH` is the same opt-in |
| `-SkipToolbar` | omit the menu banner |

### Exit codes

With `-NonInteractive` the process runs one action and exits with:

| Result status | Exit code | Meaning |
| --- | --- | --- |
| `Success` | `0` | the action did what you asked |
| `AlreadyApplied` | `0` | the requested state was already in place and nothing changed. `RemoveAds` returns it when there is no campaign file or nothing left to suppress, `Conceal`'s dependency step when both dependencies are already installed, and `Root15` when the built-in root is already enabled |
| `Warning` | `0` | the end state needs your attention, not an error: the Android 12 vendor-root rollback, and concealment on a clone with no KernelSU package. A `Verify` warning prints its whole report on standard output |
| `RecoverableError` | `2` | a transient transport problem; the message carries the underlying error |
| `CriticalError` | `1` | the action stopped, and nothing is claimed |

`Success` and `Warning` are not the same thing, and neither is decided by the exit code. A script must
read the `Status` field, because a `Warning` and a `Success` both exit `0`.

A noninteractive `Root12` therefore always exits `1` with `USER_CONFIRMATION_REQUIRED`; that is the
intended fail-closed result, not a defect. In the interactive menu a failed action returns to the
menu, prints the log path and the recovery guidance, and never closes the window.

## Limitations

These are the honest limits of the current state of the code.

- Live runs were performed on a real installation, on the Chinese-edition MuMu 6.8.0.0 build. The
  results are mixed and are stated one action at a time in [Status](#status). Every other statement
  here is still covered only by fixture tests and parser checks.
- Android 12 is qualified on this build, with one caveat: the Kitsune root is installed and verified,
  and the MuMu vendor root is then left enabled, so the action reports `Warning` with
  `ROOT_AFTER_DISABLE_ROLLED_BACK` and `RootVerified=true` rather than `Success`. On MuMu 6.8 the
  Kitsune `su` path is `/system/bin/su` and disabling the vendor root removes it while the adb shell
  stays `uid=2000`, so the retained vendor root is the working state, not a leftover. The retained
  vendor root is recorded in the journal and in the result.
- Android 15 is unqualified. The live run produced a clone that inherited Kitsune, so clone 5
  carries `io.github.huskydg.magisk` and has no built-in KernelSU target. `Root15` reports
  `KITSUNE_PRESENT` for it, and a source instance that already carries Kitsune cannot be qualified.
- Concealment is unqualified, for two independent reasons: the Vector module install has not
  succeeded on a live clone, and the target package `jp.pokemon.pokemontcgp` is not installed on
  clone 4. Both are stated in full under [Concealment scope](#concealment-scope).
- `RemoveAds` was a no-op on this host. There is no campaign file anywhere in the Chinese-edition
  installation, so the action reported success with an empty path set and wrote nothing. That is a
  fact about this installation, not evidence that the advertisement logic works.
- The transport assumptions are only partly verified. Discovery, the instance clone transport, resume
  from a real recovery record, the manager responses, and the bundled ADB were exercised live. Other
  manager versions, a localized response, or a blocked port still make an action fail closed rather
  than guess.
- `Target Create` and `Target Clone` are the only actions that add an instance, and both depend on the
  manager accepting the `create` and `clone` commands with these exact arguments. The manager assigns
  the created index itself, so `Target Create` reports the index MuMu returned and never assumes the
  requested index.
- Root concealment reduces package and module visibility. It is not attestation bypass, and there is
  no guarantee about Play Integrity, device integrity, or any other hardware-backed signal.
- no binaries are bundled: no installer, archive, or image is committed here, and the repository
  ignores those file types on purpose.
- A mutating action only reaches elevation after a real permission failure, so a host whose manager
  calls and file writes already succeed unelevated never sees a UAC prompt. On a host that reports
  the failure in some other form, the action still fails closed and the operator has to start the
  toolkit from an elevated console; see [Administrator rights](#administrator-rights).
- The elevated retry is noninteractive, so a mutating action that would have prompted for an
  installation, an instance, a target mode, or a confirmation must have those bound on the command
  line or the elevated child reports the missing selection instead.

## Tests

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite Docs
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite All
```

The tests use temporary fixtures, never a real MuMu installation, and never the network. The GitHub
Actions workflow in `.github/workflows/test.yml` runs on Windows, checks out the repository, runs the
PowerShell parser over every script, and runs the full suite. It installs nothing, downloads
nothing, mutates nothing, and uploads no logs, because a log from this toolkit contains user paths.

## License and attribution

The toolkit code in this repository is MIT licensed; see `LICENSE`. `NOTICE.md` credits
`Jordan231111/mumu-magisk-1click` as the clean-room reference and lists the upstream projects whose
artifacts are downloaded at run time. Upstream artifacts keep their own licenses and are not
relicensed here. Nothing in this repository implies endorsement by any of those projects.
