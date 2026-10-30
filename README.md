# spfk-taglib

[![Version](https://img.shields.io/github/v/tag/ryanfrancesconi/spfk-taglib)](https://github.com/ryanfrancesconi/spfk-taglib/tags)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-taglib%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-taglib)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-taglib%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-taglib)

[TagLib](https://taglib.org/) packaged for Swift Package Manager.

## Overview

spfk-taglib is an independent SPM repackaging of [taglib/taglib](https://github.com/taglib/taglib), the C++ audio metadata library. The source tree mirrors upstream TagLib's directory layout — headers live alongside their `.cpp` files in format-specific subdirectories — making syncs with upstream a straightforward directory-level diff.

The current upstream base is **TagLib 2.3.2** (tracked via `SPFK_TAGLIB_UPSTREAM_VERSION` in `taglib_config.h`).

## Changes Not in Upstream

`Sources/taglib/` is upstream plus the changes below, so this package may differ from taglib. Each is
its own set of commits here and is offered to taglib/taglib as its own pull request; it leaves this list
when a sync brings it back in from upstream, and stays if upstream declines it.

| Change | Commits (original; latest re-apply) | Files | Upstream |
| --- | --- | --- | --- |
| `DeferredWriteStream` — an `IOStream` over another stream that records every write, insertion, removal and truncation in memory and writes the result in one `commit()`, moving displaced bytes at most once; `bytesToMove()` and `writeTo()` let a caller write the result elsewhere instead | `26c64c2`, `3394281` | `toolkit/tdeferredwritestream.h`, `toolkit/tdeferredwritestream.cpp`, `include/module.modulemap`, `include/taglib/tdeferredwritestream.h` | PR #1476 open (issue #1474) |
| RIFF INFO: under an assumed UTF-8 (`setAssumedCodePage(65001)`, no `CSET`), a field that isn't valid UTF-8 is read as ISO 8859-1 instead of as empty; a declared code page is never second-guessed | `c901643` | `riff/wav/infotag.cpp`, `riff/wav/infotag.h` | carried; PR not opened |
| ID3v2 `setProperties` updates the one frame holding an edited key in place when its type can hold the new value, keeping a `COMM`/`USLT` language, a `TXXX` description's spelling, the frame's position and its stored encoding | `f4644d0` | `mpeg/id3v2/id3v2tag.cpp` | issue #1475 open; PR not opened |

## Structure

Public headers are colocated with their implementations (matching upstream) and exposed to SPM via symlinks in `include/taglib/`. A `module.modulemap` defines the `taglib` module. Run `scripts/update-symlinks.sh` after adding or removing public headers.

## Syncing with Upstream

The directory layout mirrors upstream TagLib, so syncing is a bulk mirror of upstream's `taglib/` directory into `Sources/taglib/` via `rsync --delete`, preserving the SPM-specific paths (`include/`, `utfcpp/`, `toolkit/taglib_config.h`) and stripping build-system files (`CMakeLists.txt`, `*.cmake`, etc.).

The mirror overwrites every change in [Changes Not in Upstream](#changes-not-in-upstream). Re-apply each one still listed after it, as its own commit, record that commit in the list, then run the tests.

For new format modules introduced upstream, add the corresponding `headerSearchPath` entries to `Package.swift`, add public headers to `module.modulemap`, and run `scripts/update-symlinks.sh`.

On tagged upstream releases, bump `SPFK_TAGLIB_UPSTREAM_VERSION` in `Sources/taglib/toolkit/taglib_config.h` and the version line in this README.

## Versioning

This package uses its own semantic versioning starting at `1.0.0`, independent of upstream TagLib version numbers. The upstream TagLib revision is tracked in `taglib_config.h`.

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ryanfrancesconi/spfk-taglib", from: "1.0.0"),
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "taglib", package: "spfk-taglib"),
        ]
    ),
]
```

## Swift Bindings

Swift bindings and higher-level metadata functionality are provided by [SPFKMetadata](https://github.com/ryanfrancesconi/spfk-metadata), which wraps spfk-taglib's C++ API in a native Swift interface.

## License

TagLib is distributed under the [LGPL](https://www.gnu.org/licenses/lgpl-2.1.html) and [MPL](https://www.mozilla.org/en-US/MPL/) licenses.

## About

Spongefork is the personal software projects of musician and developer [Ryan Francesconi](https://spongefork.com). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2026, Spongefork returns as his software container for more musical experimentation. In addition to [software releases](https://spongefork.com/shadowtag/), open source components can be found on his [GitHub page](https://github.com/ryanfrancesconi).
