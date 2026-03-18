# spfk-taglib

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-taglib%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-taglib)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-taglib%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-taglib)

[TagLib](https://taglib.org/) packaged for Swift Package Manager.

## Overview

spfk-taglib is an independent SPM repackaging of [taglib/taglib](https://github.com/taglib/taglib), the C++ audio metadata library. The source tree mirrors upstream TagLib's directory layout — headers live alongside their `.cpp` files in format-specific subdirectories — making syncs with upstream a straightforward directory-level diff.

The current upstream base is **TagLib 2.2.1** (tracked via `SPFK_TAGLIB_UPSTREAM_VERSION` in `taglib_config.h`).

## Structure

Public headers are colocated with their implementations (matching upstream) and exposed to SPM via symlinks in `include/taglib/`. A `module.modulemap` defines the `taglib` and `taglib_c` modules. Run `scripts/update-symlinks.sh` after adding or removing public headers.

## Fork Additions

spfk-taglib includes the following extensions beyond upstream TagLib:

- **MP4ChapterList** — Read, write, and remove Nero-style chapter markers (`chpl` atom at `moov/udta/chpl`) in MP4/M4A/M4B containers. Operates independently of `MP4::Tag::save()`, with proper parent atom size updates and chunk offset (`stco`/`co64`/`tfhd`) fixups.

- **XiphChapterUtil** — Read, write, and remove Vorbis comment chapters in FLAC, OGG, and Opus files via `CHAPTER###` / `CHAPTER###NAME` field conventions.

- **BEXT (Broadcast Wave)** — Read and write Broadcast Audio Extension chunks in WAV files (EBU Tech 3285, versions 0-2).

- **iXML** — Read and write iXML metadata chunks in WAV files.

## Syncing with Upstream

The directory layout mirrors upstream TagLib, so syncing involves:

1. Diff upstream's `taglib/` directory against `Sources/taglib/` to identify new, modified, and deleted files.
2. Copy changed files directly — header search paths and include resolution are already set up.
3. For new format modules, add the corresponding `headerSearchPath` entries to `Package.swift`, add public headers to `module.modulemap`, and run `scripts/update-symlinks.sh`.
4. Update `SPFK_TAGLIB_UPSTREAM_VERSION` in `Sources/taglib/toolkit/taglib_config.h`.

Fork-specific additions (`mp4chapterlist`, `xiphchapterutil`, `bext`, `ixml`) live in their own files and don't conflict with upstream changes.

## History

This package originated as a fork of [sbooth/CXXTagLib](https://github.com/sbooth/CXXTagLib), which repackages TagLib for SPM. spfk-taglib has since been restructured to mirror the upstream layout directly and is maintained independently.

The SPM repackaging, directory restructure, upstream sync tooling, fork additions (MP4ChapterList, XiphChapterUtil, BEXT, iXML), and initial upstream sync to TagLib 2.2.1 were implemented with [Claude Code](https://claude.ai/claude-code).

## Versioning

This package uses its own semantic versioning starting at `1.0.0`, independent of upstream TagLib version numbers. The upstream TagLib revision is tracked in `taglib_config.h`.

## Usage

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
