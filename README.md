# spfk-taglib

[![CI](https://github.com/ryanfrancesconi/spfk-taglib/actions/workflows/ci.yml/badge.svg?branch=development)](https://github.com/ryanfrancesconi/spfk-taglib/actions/workflows/ci.yml)
[![Version](https://img.shields.io/github/v/tag/ryanfrancesconi/spfk-taglib)](https://github.com/ryanfrancesconi/spfk-taglib/tags)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-taglib%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-taglib)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-taglib%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-taglib)

[TagLib](https://taglib.org/) packaged for Swift Package Manager.

## Overview

spfk-taglib is an independent SPM repackaging of [taglib/taglib](https://github.com/taglib/taglib), the C++ audio metadata library. The source tree mirrors upstream TagLib's directory layout — headers live alongside their `.cpp` files in format-specific subdirectories — making syncs with upstream a straightforward directory-level diff.

The current upstream base is **TagLib 2.3** (tracked via `SPFK_TAGLIB_UPSTREAM_VERSION` in `taglib_config.h`).

## Structure

Public headers are colocated with their implementations (matching upstream) and exposed to SPM via symlinks in `include/taglib/`. A `module.modulemap` defines the `taglib` and `taglib_c` modules. Run `scripts/update-symlinks.sh` after adding or removing public headers.

## Syncing with Upstream

The directory layout mirrors upstream TagLib, so syncing is a bulk mirror of upstream's `taglib/` directory into `Sources/taglib/` via `rsync --delete`, preserving the SPM-specific paths (`include/`, `utfcpp/`, `toolkit/taglib_config.h`) and stripping build-system files (`CMakeLists.txt`, `*.cmake`, etc.).

For new format modules introduced upstream, add the corresponding `headerSearchPath` entries to `Package.swift`, add public headers to `module.modulemap`, and run `scripts/update-symlinks.sh`.

On tagged upstream releases, bump `SPFK_TAGLIB_UPSTREAM_VERSION` in `Sources/taglib/toolkit/taglib_config.h` and the version line in this README.

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
