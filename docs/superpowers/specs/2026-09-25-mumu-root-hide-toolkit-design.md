# MuMu Root Hide Toolkit Design

Date: 2026-09-25
Status: Approved design

## Purpose

Create a clean-room Windows PowerShell toolkit for MuMu Player Global and Chinese editions. The toolkit will safely detect installations with non-default paths, create a verified instance clone before mutations, route Android 12 and Android 15 instances to the correct root workflow, configure selected-app root concealment, suppress MuMu-owned advertisements, and provide verification and restoration.

The project name is `mumu-root-hide-toolkit`.

## Clean-room boundary

The original `mumu-magisk-1click` project is credited in `NOTICE.md` and README credits. Its CC BY-NC-ND 4.0 license prohibits sharing adapted material without permission. This repository will therefore:

- contain independently written code;
- use public MuMu command-line interfaces, official documentation, and independently designed tests;
- download third-party dependencies from their official upstream sources at runtime;
- avoid copying the original project's source, README prose, binaries, workflows, tests, icons, or other assets;
- retain each downloaded dependency's own license and notices;
- license the independently written toolkit code under MIT.

The repository will not claim endorsement by the original author or MuMu.

## Scope

Supported targets:

- MuMu Player Global and Chinese editions;
- MuMu Android 12 instances using the Kitsune guided workflow;
- MuMu Android 15 instances using MuMu's built-in KernelSU root implementation;
- Windows 10 and Windows 11 with Windows PowerShell 5.1 or newer.

## Tested setup versions

These are the versions used for the live setup verification on 2026-09-25 and 2026-09-26. The implementation pins these versions and hashes in its manifest; a newer release is not treated as compatible until it is separately tested. The live verification used the Chinese edition of MuMu Player 6.8.0.0. Global-edition support remains fixture-tested.

| Component | Tested version | Reference |
| --- | --- | --- |
| MuMu Player Chinese edition | 6.8.0.0 | [Official download page](https://www.mumuplayer.com/download/) |
| Android 12 instance | Android 12.0 | [MuMu Android-version documentation](https://www.mumuplayer.com/help/win/how-to-upgrade-mumuplayer.html) |
| Android 15 instance | Android 15.0, built-in KernelSU 3.2.5 | [MuMu Android-version documentation](https://www.mumuplayer.com/help/win/how-to-upgrade-mumuplayer.html) |
| Kitsune Magisk | v31.0-25fa2159 | [Kitsune release](https://github.com/Jordan231111/KitsuneMagisk/releases/tag/v31.0-25fa2159) |
| Hide My Applist OSS | oss-161 | [HMA-OSS release](https://github.com/frknkrc44/HMA-OSS/releases/tag/oss-161) |
| Vector | v2.2, build 3080, installed as the `zygisk_vector` module | [Vector release](https://github.com/JingMatrix/Vector/releases/tag/v2.2) |
| NeoZygisk | v2.4, build 289, installed as the `zygisksu` module | [NeoZygisk release](https://github.com/JingMatrix/NeoZygisk/releases/tag/v2.4) |
| CorePatch | 4.9 | [CorePatch release](https://github.com/LSPosed/CorePatch/releases/tag/4.9) |

Explicit non-goals:

- modifying or patching individual game APKs;
- removing advertisements from third-party applications;
- editing hosts files, firewall rules, startup services, scheduled tasks, Hyper-V, VBS, or Windows security policy;
- bypassing hardware-backed attestation or guaranteeing Play Integrity results;
- silently automating every Android UI confirmation;
- running destructive changes without a verified clone.

## User experience

A double-clickable `Run-MumuToolkit.bat` launches an interactive menu. The menu exposes:

1. Detect installations and instances.
2. Run a read-only dry run.
3. Create and verify a backup clone.
4. Root an Android 12 instance.
5. Enable built-in root on Android 15.
6. Configure root concealment for selected apps.
7. Suppress or restore MuMu advertisements.
8. Verify the selected instance.
9. Restore a previous file backup or report the backup clone.
10. Quit.

The launcher does not permanently change PowerShell execution policy. Command-line actions remain available for automation, but the interactive menu is the primary interface.

## Repository layout

The implementation will use a small, testable layout:

```text
Run-MumuToolkit.bat
src/
  Invoke-MumuToolkit.ps1
  Discovery.ps1
  Elevation.ps1
  Journal.ps1
  Backup.ps1
  Root12.ps1
  Root15.ps1
  Concealment.ps1
  Ads.ps1
  Verification.ps1
  Common.ps1
  Manifest.json
 tests/
  Run-Tests.ps1
  Fixtures/
 docs/
  superpowers/specs/
 .github/workflows/
 README.md
 NOTICE.md
 LICENSE
```

The exact file count may be reduced during implementation if a module boundary is not needed. No implementation abstraction will be added without a concrete test or operation that needs it.

## Discovery and edge cases

Discovery will use, in order:

1. Windows uninstall registry entries and their `InstallLocation` values;
2. running MuMu process command lines;
3. known installation roots only as a fallback;
4. manager-reported VMS paths and instance metadata.

The resolver will handle:

- installation directories on any local drive;
- paths containing spaces and Unicode;
- junctions, symlinks, and relocated VMS roots;
- Global and Chinese user-data locations;
- multiple installations and multiple instances;
- stale or partially migrated metadata;
- missing `MuMuManager.exe`, missing ADB, broken VDI paths, and disabled VT.

The tool will never silently choose an instance when multiple eligible instances exist. It will display edition, name, index, Android version, path, running state, and root state, then require an explicit selection. Unsupported Android versions, broken virtualization metadata, ambiguous paths, and insufficient free space fail closed.

All command arguments will be passed as structured argument arrays. Paths will be resolved with PowerShell path APIs, and no path will be interpolated into an unquoted shell command.

## Backup and transactions

Before any mutating operation, the tool will:

1. cleanly stop the selected instance;
2. create one clone using MuMu's supported clone operation;
3. verify the clone's identity, Android version, disk presence, and boot readiness;
4. record the clone index in a local journal;
5. refuse to proceed if verification fails or a backup name collides.

Every changed configuration file receives an exact byte backup and metadata needed to restore its original read-only state. Existing backups are never overwritten. A journal records phases, timestamps, paths, hashes, selected instance, backup clone, and verification results. Interrupted operations can be retried or restored; they are not treated as successful.

## UAC and permissions

`Detect` and `DryRun` do not require elevation. A mutating action is attempted in the current process first, so a host whose manager calls and file writes already succeed unelevated is never prompted. Only a reported permission failure asks for rights, and it asks once: the dispatcher starts PowerShell directly with `Start-Process -Verb RunAs`, repeats the caller's own allowlisted action with its bound paths and its operator confirmation, and the child verifies that it is actually elevated before touching MuMu. A process that already holds rights is not asked for them again, and the elevated child runs with an internal flag that makes a second request impossible.

The child may run only a script inside this toolkit's own `src` directory, checked on resolved paths so a reparse point cannot carry it out of the boundary.

If the user's UAC policy suppresses the prompt or denies elevation, the action returns a clear permission error, nothing is retried in the unelevated process, and the interactive menu remains open. The tool does not bypass UAC, create scheduled tasks, alter execution policy permanently, take ownership of files, or weaken ACLs.

Dependency downloads and SHA-256 verification happen before elevation. No replacement code or dependency is downloaded after the elevated phase begins.

## Error handling

The interactive controller catches action errors and returns to the menu. Each operation returns a structured result:

- `Success`;
- `AlreadyApplied`;
- `Warning`;
- `RecoverableError`;
- `CriticalError`.

Recoverable errors receive bounded retries, cleanup, and an actionable message. Critical errors stop the current action but not the menu. They prevent all later mutation steps when state cannot be trusted.

The controller always attempts cleanup of temporary files and child-process handles in `finally` blocks. A critical error includes a log path and recovery guidance. Command-line mode returns meaningful nonzero exit codes even though interactive mode remains open.

## Android 12 root flow

The Android 12 path is guided rather than silently automated:

1. discover and select the Android 12 instance;
2. create and verify the clone;
3. enable the supported MuMu root and writable-system settings;
4. download the pinned official Kitsune APK and verify its SHA-256;
5. install and launch the APK;
6. pause with the exact instruction: `Install -> Direct Install into system partition`;
7. explicitly warn users not to choose ordinary phone-style `Direct Install` or `Select and Patch a File`;
8. wait for the user to report completion;
9. cold-boot the instance;
10. verify the expected Kitsune package, root daemon, and root access;
11. disable temporary vendor root only after successful verification;
12. record completion in the journal.

If the system-partition option is missing, the tool stops and leaves the instance recoverable instead of selecting another installation method.

## Android 15 root flow

The Android 15 path never installs Kitsune or Magisk. It:

1. creates and verifies the clone;
2. enables MuMu's built-in root setting;
3. cold-boots the instance;
4. verifies the built-in KernelSU implementation and root access;
5. leaves the Android 12 Kitsune workflow available only for Android 12 instances.

## Root concealment

Root concealment is per selected application. The tool will install only pinned, hash-verified upstream HMA and Vector artifacts when needed, before it writes any app scope, and only on a verified clone. It will create one reusable Root template containing the installed root-related packages, including KernelSU where present.

For each selected app, the tool enables HMA concealment, denies app root, and enables KernelSU `Unmount modules`. If the installed HMA configuration schema is unknown or unsupported, the tool stops safely and explains how to configure the supported UI manually. It will not corrupt an unknown private configuration format.

The read-only verification report carries concealment evidence read from the installed HMA configuration on the verified clone, so a concealment claim is never made without an observation behind it. A clone whose root comes from Kitsune rather than KernelSU reports the absent KernelSU package honestly instead of claiming a profile state it cannot read.

Root concealment reduces package and module visibility. It does not guarantee bypass of hardware-backed attestation.

## Advertisement suppression

The ad action will modify only MuMu-owned campaign configuration. It will:

- locate the relevant Global or Chinese campaign file;
- parse and validate JSON;
- create an exact backup;
- set existing campaign display flags to false;
- preserve and restore the original read-only state;
- refuse to overwrite an existing restore point.

It will not patch games, alter app data, change network settings, or suppress third-party application ads.

## Verification

Verification is read-only and reports:

- detected edition and installation path;
- selected instance and Android version;
- manager and ADB availability;
- VT and Hyper-V/VBS state without changing them;
- clone status and disk presence;
- MuMu root setting and writable-system state;
- Kitsune or KernelSU package/version state;
- root daemon and root-shell result;
- HMA/Vector state and selected-app scope where readable;
- advertisement suppression and restore-point state;
- operation journal and last failure.

A successful report must be based on fresh command output, not assumptions.

## Testing

Tests use temporary fixtures and must not modify a real MuMu installation. Coverage includes:

- Global and Chinese discovery;
- arbitrary, spaced, Unicode, and relocated paths;
- registry, process, and fallback discovery;
- ambiguous-instance refusal;
- UAC preflight and denied-elevation handling;
- JSON backup, read-only preservation, duplicate protection, and restore;
- Android 12 versus Android 15 routing;
- backup clone verification;
- structured error results and journal recovery;
- HMA template and selected-app configuration validation;
- PowerShell syntax and parser checks.

CI may run fixture tests and syntax checks on Windows. It must not run live root, ad, or concealment mutations.

## Publishing

The repository is created locally first. GitHub publishing will use a user-provided authenticated remote or GitHub CLI installation. No credentials, tokens, or account data are stored in the repository. The remote URL and owner are intentionally requested only after the local implementation and tests are ready.

## Acceptance criteria

The project is complete when:

- the interactive menu remains open after recoverable and critical action errors;
- non-default installation paths and both MuMu editions are detected;
- ambiguous or unsupported instances are refused safely;
- missing or suppressed UAC is reported without bypassing Windows security;
- a verified clone exists before any mutation;
- Android 12 uses the exact system-partition Kitsune option;
- Android 15 uses built-in KernelSU and never Kitsune;
- selected-app concealment and MuMu-only ad suppression are reversible;
- all fixture tests and PowerShell syntax checks pass;
- the repository contains no copied original code or assets and clearly credits upstream projects.
