# MuMu Root Hide Toolkit

A clean-room Windows PowerShell toolkit that roots MuMu Player instances, hides the root
implementation from selected apps, and suppresses MuMu's own advertisement campaign. Every
change is placed behind a verified clone and an exact restore point.

This project is not affiliated with, endorsed by, or supported by NetEase, by the original
`Jordan231111/mumu-magisk-1click` project that it is a clean-room reference for, or by any
upstream project named below. See `NOTICE.md` for attribution.

## Supported targets

- MuMu Player Global and Chinese editions, in any local installation path, including paths with
  spaces, non-ASCII characters, and relocated instance roots.
- Android 12 instances: the guided Kitsune Magisk workflow, including the exact system-partition
  install choice.
- Android 15 instances: MuMu's built-in KernelSU root only. Kitsune is never installed on an
  Android 15 instance.
- Windows 10 and Windows 11 with Windows PowerShell 5.1 or newer.

Anything outside those targets fails closed. An unsupported Android version, an ambiguous
installation or instance, an unreadable MuMu manager, an unverifiable clone, or an unverified
dependency stops the action before it changes anything.

## Tested setup versions

The toolkit pins exact versions and SHA-256 hashes in `src/Manifest.json`. A newer release is
not treated as compatible until it has been tested and pinned again.

| Component | Tested version | Used for | Official release page |
| --- | --- | --- | --- |
| MuMu Player | 6.8.0.0 | the host application under test | [download page](https://www.mumuplayer.com/download/) |
| MuMu Android version selection | Android 12.0 and Android 15.0 | choosing the instance image | [Android version documentation](https://www.mumuplayer.com/help/win/how-to-upgrade-mumuplayer.html) |
| Kitsune Magisk | v31.0-25fa2159 | Android 12 root | [Kitsune release](https://github.com/Jordan231111/KitsuneMagisk/releases/tag/v31.0-25fa2159) |
| Hide My Applist OSS | oss-161 | app and module concealment | [HMA-OSS release](https://github.com/frknkrc44/HMA-OSS/releases/tag/oss-161) |
| Vector | v2.0 | LSPosed module runtime used by HMA OSS | [Vector release](https://github.com/JingMatrix/Vector/releases/tag/v2.0) |
| NeoZygisk | v2.3 | pinned for future use; no action installs it yet | [NeoZygisk release](https://github.com/JingMatrix/NeoZygisk/releases/tag/v2.3) |
| CorePatch | 4.9 | pinned for future use; no action installs it yet | [CorePatch release](https://github.com/LSPosed/CorePatch/releases/tag/4.9) |

Vector is the current name of the LSPosed project. The pinned artifact comes from the
`JingMatrix/Vector` repository, whose v2.0 release page is the canonical link; the older
`JingMatrix/LSPosed` release path only redirects there.

Dependencies are downloaded at run time from those official release pages into
`%LOCALAPPDATA%\mumu-root-hide-toolkit\assets`, and each one is verified against its pinned size
and SHA-256 hash before it is used. Design intent: a dependency is never fetched from an
elevated phase, so nothing is downloaded after rights are raised. The actions do not raise
rights themselves yet, so there is no elevated phase today.

## Setup order

1. Install MuMu Player yourself and create the instance you want to work on. The toolkit never
   installs, updates, or repairs MuMu.
2. Run the `Target` action to identify the instance you will work on, to create one, or to clone
   an existing one. It reports the target index, and that index is what the later actions take.
3. Run `Detect` and confirm that the reported edition, installation path, and instance index are
   the ones you intend to use.
4. Run `Verify` for the read-only report. Fix anything it reports before you change anything.
5. Run `Root12` for an Android 12 instance, or `Root15` for an Android 15 instance. Each one
   works on its own clone, never on the instance you selected.
6. Run `Conceal` with the package names of the specific apps that must not see root.
7. Run `RemoveAds` to suppress MuMu's own campaign advertisements.
8. Run `Restore` when you want the advertisement files back.

## Actions

Double-click `Run-MumuToolkit.bat` to open the interactive menu. On the command line `-Action`
is honored only together with `-NonInteractive`; without `-NonInteractive` the launcher opens
the menu and the `-Action` value is ignored, so every example below passes both.

| Action | What it changes | Noninteractive command |
| --- | --- | --- |
| `Detect` | nothing in MuMu; reports installations and instances | `Run-MumuToolkit.bat -Action Detect -NonInteractive` |
| `Verify` | nothing in MuMu; reports the read-only status of the selected instance | `Run-MumuToolkit.bat -Action Verify -NonInteractive` |
| `Target` | `Identify` changes nothing; `Create` and `Clone` each add exactly one MuMu instance | `Run-MumuToolkit.bat -Action Target -Mode Identify -NonInteractive` |
| `Root12` | the verified clone of an Android 12 instance | menu only; `-Action Root12 -NonInteractive` always returns `USER_CONFIRMATION_REQUIRED` |
| `Root15` | the verified clone of an Android 15 instance | `Run-MumuToolkit.bat -Action Root15 -Confirmed -NonInteractive` |
| `Conceal` | root visibility for explicitly selected apps on the verified clone | `Run-MumuToolkit.bat -Action Conceal -Packages com.example.app -NonInteractive` |
| `RemoveAds` | MuMu campaign display flags inside the selected installation | `Run-MumuToolkit.bat -Action RemoveAds -NonInteractive` |
| `Restore` | the MuMu campaign files, from the toolkit restore point | `Run-MumuToolkit.bat -Action Restore -NonInteractive` |

`Root12` is menu-only. A noninteractive `Root12` run resolves the installation and the instance,
verifies the pinned Kitsune artifact, and then returns `USER_CONFIRMATION_REQUIRED` without
creating a clone and without changing anything, because the exact Kitsune choice must be
confirmed by a person and the noninteractive dispatcher carries no confirmation token. There is
no one-command Android 12 root automation; use the menu for that action.

`Conceal` needs a verified clone record from a completed `Root12` or `Root15` run for the same
instance, so a noninteractive `Conceal` follows either a menu `Root12` run or a noninteractive
`Root15` run.

## Target selection

`Target` is the prerequisite step. It reports which instance the later actions would work on and
it is the only action that can add a MuMu instance. It never starts root or concealment work, and
it never guesses: when more than one eligible instance exists it requires an explicit
`-InstanceIndex` or a menu choice.

| Mode | What it changes | Confirmation |
| --- | --- | --- |
| `Identify` | nothing in MuMu; lists every discovered instance with its index, name, Android version, running state, and eligibility, then names the selected target | not required, because it is read-only |
| `Create` | adds exactly one new instance, at the index MuMu actually assigns | required: the menu asks for a free index to insist on and then for `CONFIRM`, the command line requires `-StartIndex` and `-Confirmed` |
| `Clone` | adds exactly one clone of a source instance, after stopping that source instance | required: the menu asks for `CONFIRM` once the source is known, the command line requires `-Confirmed` |

The menu asks for the mode with the words `Identify`, `Create`, or `Clone`. `Identify` and `Clone`
ask which instance to use when more than one is eligible. A noninteractive run never prompts and
never confirms anything, so it must carry the parameters itself:

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
| `TARGET_START_INDEX_INVALID` | the free instance index answered in the menu is not a non-negative integer |
| `TARGET_PARAMETER_MISUSE` | `-Mode`, `-StartIndex`, or `-SourceIndex` was supplied to another action |

`Target Clone` refuses a source instance that is a base instance, has an unsupported Android
version, or has an unknown state, so it never returns an unusable target.

`-StartIndex` is a precondition, not an instruction to the manager. The toolkit verifies that the
index is free and refuses to continue when it is not, then asks MuMu to create one instance without
sending the index at all. MuMu assigns the index itself, so the created index can differ from the
requested one. The `Index` in the result is the only authoritative index; the result also echoes the
precondition as `RequestedIndex`. Always use the returned `Index` for later actions, never the
requested index.

`Create` never overwrites an index and never deletes or renames anything. After the manager reports
the new instance, the action requires exactly one new index and verifies that it is a non-base
instance with a readable Android version, an instance root inside the selected installation, and a
usable disk. `Clone` reuses the same verified clone flow that `Root12` and `Root15` use. Neither
mode changes any other instance, and both are recorded in the operation journal.

The reported target index is the value to pass to `-InstanceIndex` for `Root12`, `Root15`, and
`Conceal`. `Target` does not store that choice: the toolkit never picks an instance on your behalf
in a later run.

Command-line parameters:

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
| `-SkipToolbar` | omit the menu banner |

## Android 12: the exact Kitsune choice

`Root12` is an interactive action; run it from the menu. It verifies the pinned Kitsune artifact,
creates and verifies a clone, enables the
temporary MuMu vendor root on that clone only, installs the Kitsune app, and starts it. The
workflow then pauses and waits for you, in the Kitsune app on the clone, to choose exactly:

```text
Install -> Direct Install into system partition
```

Do not choose the ordinary `Direct Install` or `Select and Patch a File` option. Only the exact
choice above is accepted; any other answer stops the workflow before the cold boot, and the
clone is left as it is. After you confirm, the toolkit cold-boots the clone, verifies the
Kitsune package, the root daemon, and a root shell, disables the temporary vendor root again,
and then repeats the same three checks. Success is reported only when those checks still pass
after the cleanup, because disabling the vendor root can remove the root shell.

On MuMu 6.8 that cleanup does remove `/system/bin/su` while the Kitsune files and one `magiskd`
survive. The adb shell on that build stays `uid=2000`, root comes from the Magisk `su`, and the
`su` path lives at `/system/bin/su`, so the Kitsune root does not survive the cleanup. When the
checks after the cleanup fail, the toolkit therefore enables the vendor root again on that clone,
reads the settings back, repeats the three checks, and reports a `Warning` with the code
`ROOT_AFTER_DISABLE_ROLLED_BACK`, `VendorRootRetained`, and a message that names the retained
vendor root and the removed `su` path. The journal is completed as a warning, the clone keeps the
vendor root on, and the result is never reported as a `Success` root result. A script must check
`Status`, not the process exit code, because a `Warning` exits `0`. If the rollback itself fails,
the toolkit reports `CriticalError` with the code `ROOT_RECOVERY_FAILED`, fails the journal, and
claims no root. Nothing outside the selected clone is changed in either path.

## Android 15: built-in root and explicit confirmation

`Root15` never installs Kitsune or Magisk. It creates and verifies a clone, enables MuMu's
built-in root setting on that clone, cold-boots it, and verifies the built-in KernelSU package,
the absence of the Kitsune package, and a root shell, in that order. The Kitsune check runs first
so a clone that inherited the Kitsune package is reported as `KITSUNE_PRESENT`, with the observed
package line, instead of being reported as a root denial it never had. A guest with no `su` binary
at all is reported as `ROOT_UNAVAILABLE`, which says the root state is unknown, rather than as a
policy denial. The built-in root is kept enabled on the clone.

Android 15 is **not qualified on this host yet.** The live run on the instance at index 1 produced
a clone that inherited `io.github.huskydg.magisk` and had no usable `su` and no built-in KernelSU
daemon, so that clone is not a valid built-in-KernelSU target and the action reported
`KITSUNE_PRESENT`. A source instance that already carries Kitsune cannot be qualified with
`Root15`; a Kitsune-free instance still has to be run before Android 15 can be called qualified.

Because that change is not reversible through the toolkit, `Root15` requires explicit
confirmation. The menu asks you to type `CONFIRM`; the command line requires `-Confirmed`.
Without it the action changes nothing and reports `USER_CONFIRMATION_REQUIRED`.

## Clone-first safety

Every mutating action creates and verifies a clone before it changes anything. The instance you
selected is only stopped so that it can be cloned. The clone's index, name, Android version,
installation boundary, and disk are verified, and the clone index is written to the operation
journal. If any of those checks fail, the action stops and the selected instance is untouched.

## Recovery

- Every operation keeps a journal under `%LOCALAPPDATA%\mumu-root-hide-toolkit\journals`, and
  the log is at `%LOCALAPPDATA%\mumu-root-hide-toolkit\logs\mumu-root-hide-toolkit.log`. Both
  are written with user paths and identifiers redacted.
- An interrupted action is never treated as successful. Read the journal, run `Verify` for a
  fresh read-only report, and run the action again.
- Re-running a root action creates an additional verified clone instead of reusing an old one.
  Earlier clones are left in place, so the untouched original and any previous clone remain
  available. The module can resume on a recorded clone, but neither the menu nor the command
  line exposes that yet, so re-running is the supported recovery path.
- Advertisement changes are undone with `Restore`, described below.

## Concealment scope

`Conceal` changes only the verified clone and only for the apps you name. It refuses to run
without `-Packages`, refuses any package that is not installed on the clone, and refuses a
selection that would cover every installed app, because concealment is a per-app change and a
global scope is not supported.

The action builds a reusable `Root` template that hides the installed root packages, assigns it
to each explicitly selected app, and leaves every other app untouched. It backs up the Hide My
Applist OSS configuration on the clone before writing and verifies the backup byte for byte.
The KernelSU Superuser profile is not machine readable, so the action prints the exact manual
steps to confirm in the app. If the configuration schema is unknown or unsupported, the action
writes nothing and hands off the supported UI steps instead.

Hide My Applist OSS must already be installed on the clone. The manifest pins the HMA OSS and
Vector artifacts and `src/Concealment.ps1` can install them from the verified cache, but the
menu does not run that step yet.

## Advertisement scope and restore

`RemoveAds` touches only MuMu's own campaign configuration inside the selected installation:
`shell\ad\campaign.json` and `nx_device\configs\campaign.json` for the Global edition,
`MuMuPlayer\ad\campaign.json` and `shell\ad\campaign.json` for the Chinese edition. It sets the
existing campaign `display` flags to false, keeps an exact byte backup of every file it changes
together with the original read-only state, and refuses to overwrite an existing restore point.
It never patches games, changes app data, changes network settings, or suppresses any
third-party advertisement.

To restore:

1. Run `Run-MumuToolkit.bat -Action Restore -NonInteractive` and select the same installation
   with `-InstallRoot` if more than one is discovered.
2. The newest restore point for that installation is applied, and the restored files and their
   read-only state are reported.
3. Every restored path is re-validated against the installation root, the restore boundary the
   advertisement module calls `AllowedRoot`. A restore path outside that boundary is refused and
   no file is written.
4. If no restore point exists for the installation, nothing is changed and the action reports
   `CAMPAIGN_RESTORE_POINT_MISSING`.

Restore points live under `%LOCALAPPDATA%\mumu-root-hide-toolkit\campaigns`, one directory per
installation scope, each with its own `restore-point.json`.

## UAC and administrator rights

Actions never bypass, weaken, or reconfigure Windows security. The toolkit never relaunches itself with higher rights, never creates a scheduled task, never changes the
execution policy permanently, and never takes ownership of files or weakens an access
control list. `src/Elevation.ps1` implements a direct `RunAs` relaunch of a single action
script and a child that verifies its own administrator token before it runs, but the action
dispatcher does not call it yet.

Current behavior: if an action needs rights the current process does not have, it fails closed.
The action stops, the operation journal records the failure, nothing is retried automatically,
and no configuration is left half-written on purpose. Start `Run-MumuToolkit.bat` from an
elevated console (Run as administrator) for the actions that write into the MuMu installation.
`Detect` and `Verify` never change MuMu and do not need elevation; they still
create the toolkit state directory, and a non-success result appends a redacted line to the
toolkit log.

## Noninteractive exit codes

With `-NonInteractive` the process runs one action and exits with:

| Result status | Exit code |
| --- | --- |
| `Success` | `0` |
| `AlreadyApplied` | `0` |
| `Warning` | `0` with the report on standard output |
| `RecoverableError` | `2` |
| `CriticalError` | `1` |

A noninteractive `Root12` therefore always exits `1` with `USER_CONFIRMATION_REQUIRED`; that is
the intended fail-closed result, not a defect. In the interactive menu a failed action returns to
the menu, prints the log path and the
recovery guidance, and never closes the window.

## Limitations

These are the honest limits of the current state of the code.

- No live qualification was performed in this repository. Every behavior here is covered by
  fixture tests and parser checks; the end-to-end MuMu, ADB, UAC, and cold-boot paths have not
  been exercised on a real installation from this repository.
- The transport assumptions are unverified: the workflow depends on `MuMuManager.exe` reporting
  the documented instance, clone, and root-setting responses, and on its bundled ADB accepting
  the commands the toolkit sends. A different manager version, a localized response, or a
  blocked port makes the action fail closed rather than guess.
- `Target Create` and `Target Clone` are the only actions that add an instance, and both depend on
  the manager accepting the `create` and `clone` commands with these exact arguments. The manager
  assigns the created index itself, so `Target Create` reports the index MuMu returned and never
  assumes the requested index. Neither mode has been exercised against a live MuMu installation
  from this repository.
- Root concealment reduces package and module visibility. It is not attestation bypass, and
  there is no guarantee about Play Integrity, device integrity, or any other hardware-backed
  signal.
- The temporary MuMu vendor root is left enabled on an Android 12 clone when root
  verification fails, because disabling it would hide the state that needs investigation.
- The temporary MuMu vendor root stays enabled on an Android 12 clone when the Kitsune root does not
  survive the cleanup, because on MuMu 6.8 the Kitsune `su` path is `/system/bin/su` and disabling
  the vendor root removes it while the adb shell stays `uid=2000`. That state is reported as a
  `Warning`, never as a `Success`, and the retained vendor root is recorded in the journal.
- Android 15 is not qualified. The live run on the instance at index 1 produced a clone that
  inherited `io.github.huskydg.magisk` and had no usable `su` and no built-in KernelSU daemon, so
  that clone is not a valid built-in-KernelSU target. `Root15` reports `KITSUNE_PRESENT` for it and
  a source instance that already carries Kitsune cannot be qualified.
- no binaries are bundled: no APK, archive, installer, or image is committed here, and the
  repository ignores those file types on purpose.
- The Chinese edition is fixture-tested only. The live setup verification behind the tested
  version statement used the Global edition.
- The menu does not yet self-elevate or install the concealment dependencies; see the sections
  above for the current fail-closed behavior.

## Tests

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite Docs
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests\Run-Tests.ps1 -Suite All
```

The tests use temporary fixtures, never a real MuMu installation, and never the network. The
GitHub Actions workflow in `.github/workflows/test.yml` runs on Windows, checks out the
repository, runs the PowerShell parser over every script, and runs the full suite. It installs
nothing, downloads nothing, mutates nothing, and uploads no logs, because a log from this
toolkit contains user paths.

## License and attribution

The toolkit code in this repository is MIT licensed; see `LICENSE`. `NOTICE.md` credits
`Jordan231111/mumu-magisk-1click` as the clean-room reference and lists the upstream projects
whose artifacts are downloaded at run time. Upstream artifacts keep their own licenses and are
not relicensed here. Nothing in this repository implies endorsement by any of those projects.
