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
| JingMatrix/Vector | the LSPosed module runtime used by Hide My Applist OSS, now published as Vector | https://github.com/JingMatrix/Vector |
| JingMatrix/NeoZygisk | pinned for future use; no action installs it yet | https://github.com/JingMatrix/NeoZygisk |
| LSPosed/CorePatch | pinned for future use; no action installs it yet | https://github.com/LSPosed/CorePatch |

The authors of those projects are the sole owners of their own work. Listing them here is
attribution, not a claim about their quality, and not a request for support.

## Trademarks

MuMu, NetEase, Kitsune Magisk, Magisk, Hide My Applist, Vector, LSPosed, NeoZygisk, CorePatch,
and KernelSU are the names of their respective owners. They are used here only to identify the
software this toolkit works with.
