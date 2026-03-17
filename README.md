# spfk-taglib

[TagLib](https://taglib.org/) repackaged for Swift Package Manager.

## Lineage

This package is derived from [sbooth/CXXTagLib](https://github.com/sbooth/CXXTagLib), which repackages the [taglib/taglib](https://github.com/taglib/taglib) C++ library for SPM consumption. spfk-taglib is an independent fork with its own versioning — it does not track sbooth/CXXTagLib releases.

## Additions

spfk-taglib includes the following extensions beyond upstream TagLib:

- **MP4ChapterList** — Read, write, and remove Nero-style chapter markers (`chpl` atom at `moov/udta/chpl`) in MP4/M4A/M4B containers. Operates independently of `MP4::Tag::save()`, with proper parent atom size updates and chunk offset (`stco`/`co64`/`tfhd`) fixups.

- **XiphChapterUtil** — Read, write, and remove Vorbis comment chapters in FLAC, OGG, and Opus files via `CHAPTER###` / `CHAPTER###NAME` field conventions.

- **BEXT (Broadcast Wave)** — Read and write Broadcast Audio Extension chunks in WAV files (EBU Tech 3285, versions 0–2).

- **iXML** — Read and write iXML metadata chunks in WAV files.

## Versioning

This package uses its own semantic versioning starting at `1.0.0`, independent of both upstream TagLib and sbooth/CXXTagLib version numbers. The upstream TagLib source revision this package is based on is noted in the tag description when relevant.

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
            .product(name: "CXXTagLib", package: "spfk-taglib"),
        ]
    ),
]
```

## License

TagLib is distributed under the [LGPL](https://www.gnu.org/licenses/lgpl-2.1.html) and [MPL](https://www.mozilla.org/en-US/MPL/) licenses.
