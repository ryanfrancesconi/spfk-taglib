# spfk-taglib

[![Version](https://img.shields.io/github/v/tag/ryanfrancesconi/spfk-taglib)](https://github.com/ryanfrancesconi/spfk-taglib/tags)
[![Swift](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-taglib%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-taglib)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-taglib%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-taglib)

[TagLib](https://taglib.org/), the C++ audio metadata library, packaged for Swift Package Manager.
Depend on the `taglib` product and import the `taglib` module from C++ or Objective-C++. Swift
bindings are in [SPFKMetadata](https://github.com/ryanfrancesconi/spfk-metadata).

The current upstream base is **TagLib 2.3.2** (tracked via `SPFK_TAGLIB_UPSTREAM_VERSION` in `taglib_config.h`).

This package is versioned independently of TagLib.

## Tracking upstream

`Sources/taglib/` mirrors upstream's `taglib/` directory, with headers beside their sources, so a
sync is a bulk mirror rather than a per-file merge. Public headers reach SwiftPM through symlinks in
`include/taglib/`, which `scripts/update-symlinks.sh` regenerates. A sync preserves the
SwiftPM-specific paths and removes the build-system files. The mirror overwrites every change
listed below: re-apply each one as its own commit and record that commit in the list. On a tagged
upstream release, also bump `SPFK_TAGLIB_UPSTREAM_VERSION` and the version line above.

## Changes Not in Upstream

`Sources/taglib/` is upstream plus the changes below, so this package may differ from taglib. Each is
its own set of commits here and is offered to taglib/taglib as its own pull request. It leaves this
list when a sync brings it in from upstream, and stays if upstream declines it.

None at present: `Sources/taglib/` is a plain mirror of upstream.

| Change | Commits (original; latest re-apply) | Files | Upstream |
| --- | --- | --- | --- |

## License

TagLib is distributed under the [LGPL](https://www.gnu.org/licenses/lgpl-2.1.html) and [MPL](https://www.mozilla.org/en-US/MPL/) licenses.

## About

Spongefork is the personal software projects of musician and developer [Ryan Francesconi](https://spongefork.com). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2026, Spongefork returns as his software container for more musical experimentation. In addition to [software releases](https://spongefork.com/shadowtag/), open source components can be found on his [GitHub page](https://github.com/ryanfrancesconi).
