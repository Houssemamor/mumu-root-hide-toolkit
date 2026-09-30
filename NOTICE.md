# NOTICE

## This project

`mumu-root-hide-toolkit` is an independently written Windows PowerShell toolkit. The code,
tests, documentation, and workflow in this repository were written for this project.

The toolkit code is MIT licensed; see `LICENSE`.

## Clean-room reference

`Jordan231111/mumu-magisk-1click` is the original project that this work is a clean-room
reference for. That project is published by its own authors under CC BY-NC-ND 4.0, which does
not permit sharing adapted material. Nothing from it was copied into this repository: not its
source, not its scripts, not its binaries, not its assets, not its icons, not its tests, and
not its README prose. The behavior this toolkit provides was implemented from public MuMu
command-line interfaces, official vendor documentation, and the upstream projects listed below.

Any statement here is a statement about this repository. This repository does not imply endorsement by, affiliation with, or any review of
`Jordan231111/mumu-magisk-1click`, and that project's authors do not endorse this repository.

## Upstream projects

At run time the toolkit downloads pinned artifacts from official upstream release pages and
verifies each one against the size and SHA-256 hash recorded in `src/Manifest.json`. No
upstream artifact is committed to this repository, and no upstream artifact is relicensed by
it. Every upstream artifact keeps its own license, and its own terms apply to it; read the
license in the upstream project before you redistribute anything.

| Upstream project | Role in this toolkit | Official project page |
| --- | --- | --- |
| NetEase MuMu Player | the emulator this toolkit configures; not affiliated with or supported by NetEase | https://www.mumuplayer.com/ |
| Jordan231111/KitsuneMagisk | Kitsune Magisk, the Android 12 root implementation | https://github.com/Jordan231111/KitsuneMagisk |
| frknkrc44/HMA-OSS | Hide My Applist OSS, the per-app concealment app | https://github.com/frknkrc44/HMA-OSS |
| JingMatrix/Vector | the LSPosed module runtime used by Hide My Applist OSS, now published as Vector and installed as the `zygisk_vector` module | https://github.com/JingMatrix/Vector |
| JingMatrix/NeoZygisk | pinned for future use; no action installs it yet | https://github.com/JingMatrix/NeoZygisk |
| LSPosed/CorePatch | pinned for future use; no action installs it yet | https://github.com/LSPosed/CorePatch |

The authors of those projects are the sole owners of their own work. Listing them here is
attribution, not a claim about their quality, and not a request for support.

## Prior art and sources consulted

The behaviours this toolkit implements are not all original discoveries. Several were found in
public documentation, and where that happened the technique belongs to whoever published it. Nothing
below was copied as code; these are the sources for *what the behavior is*, and the implementation is
this repository's own.

| Source | What this repository took from it |
| --- | --- |
| MuMu Player official blog, "Use Magisk (the root manager) on Mac" | That the system-partition install option can be absent on first open and that restarting the app reveals it; that the in-app reboot does not work in the emulator; and that finishing the install by hand means removing the vendor `su` | 
| `hamjin/kitsune-magisk-files` (Kitsune author's file mirror) | The same "close and re-open the app" instruction, and the statement that closing the emulator's root access intentionally removes the Magisk `su`, which is why this toolkit treats that as the vendor's designed behavior rather than a defect |
| `tiann/KernelSU` official documentation | That KernelSU is allowlist based and that only a permitted app can see `su`, which is the whole basis of the Android 15 superuser handoff |
| `JingMatrix/Vector` documentation | That Vector is a Zygisk module requiring a Zygisk implementation, and the two archive layouts the installer accepts |
| `JingMatrix/NeoZygisk` issue #120 | That Vector 2.x and NeoZygisk do not work together on every Android version, and that a report of "Vector crashes on launch" is a known interaction rather than a bad archive |
| `topjohnwu/Magisk` issue #6930 | That a guest can carry a working Magisk root whose `su` is not on the `PATH`, which is why the root probe falls back to `magisk su` |
| `Jordan231111/mumu-magisk-1click` | The clean-room reference named above. Its published workflow is the origin of the Android 12 approach this toolkit re-implements, including hash-checked vendor `su` removal in a private mount namespace |
| `Bascter-Main/mumu_magisk_lsposed_oneclick` | Recorded as prior art for Android 15, where it installs Magisk, NeoZygisk, and Vector on a MuMu Android 15 instance. It is an independent project and not a dependency |

Where this repository departs from those sources it says so in `README.md`. In particular: this
toolkit does **not** perform the hash-checked vendor `su` removal that the vendor documents and the
clean-room reference automate, and it says so rather than claiming the same result.

## Trademarks

MuMu, NetEase, Kitsune Magisk, Magisk, Hide My Applist, Vector, LSPosed, NeoZygisk, CorePatch,
and KernelSU are the names of their respective owners. They are used here only to identify the
software this toolkit works with.
