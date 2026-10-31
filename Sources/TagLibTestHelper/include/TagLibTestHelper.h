/**************************************************************************
    copyright            : (C) 2026 by Ryan Francesconi
 **************************************************************************/

#ifndef TAGLIB_TEST_HELPER_H
#define TAGLIB_TEST_HELPER_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Result of a chapter read operation.
typedef struct {
    int count;
    /// Start times in milliseconds for up to 8 chapters.
    long long startTimesMs[8];
    /// Titles as null-terminated UTF-8 strings (max 64 bytes each).
    char titles[8][64];
} ChapterReadResult;

// MARK: - QT chapters

/// Writes QT chapters to the file at `path`.
/// `count` chapters, with `startTimesMs` in milliseconds and `titles` as UTF-8.
/// Returns true on success.
bool qtChapterWrite(const char *path, int count,
                    const long long *startTimesMs, const char **titles);

/// Reads QT chapters from the file at `path`.
ChapterReadResult qtChapterRead(const char *path);

/// Removes QT chapters from the file at `path`.
/// Returns true on success.
bool qtChapterRemove(const char *path);

// MARK: - Nero chapters

/// Writes Nero-style chpl chapters to the file at `path`.
/// `count` chapters, with `startTimesMs` in milliseconds and `titles` as UTF-8.
/// Returns true on success.
bool neroChapterWrite(const char *path, int count,
                      const long long *startTimesMs, const char **titles);

/// Reads Nero-style chpl chapters from the file at `path`.
ChapterReadResult neroChapterRead(const char *path);

/// Removes Nero-style chpl chapters from the file at `path`.
/// Returns true on success.
bool neroChapterRemove(const char *path);

// MARK: - RIFF / RF64

/// Audio properties as TagLib reports them.
typedef struct {
    int lengthMs;
    int bitrate;
    int sampleRate;
    int channels;
} WavPropertiesResult;

/// The 32-bit size field at offset 4 plus the fixed `ds64` fields, read straight from
/// the file rather than through TagLib — an independent check on what a write left behind.
typedef struct {
    /// Four-character magic at offset 0.
    char magic[5];
    /// The 32-bit size field at offset 4. Must stay 0xFFFFFFFF for RF64/BW64.
    unsigned int sizeField;
    bool hasDS64;
    long long riffSize;
    long long dataSize;
    long long sampleCount;
    unsigned int tableLength;
    /// Size of the file in bytes.
    long long fileSize;
    /// Declared 32-bit size of the `data` chunk, or -1 if there is none.
    long long dataChunkDeclaredSize;
    /// Offset of the `data` chunk's payload, or -1 if there is none.
    long long dataChunkOffset;
} RiffHeaderInfo;

/// Whether TagLib's WAV reader accepts the file at `path`.
bool wavIsSupported(const char *path);

/// Writes TITLE and ARTIST through the property map. Returns true if the save succeeded.
bool wavWriteProperties(const char *path, const char *title, const char *artist);

/// Reads the property `key` into `out`. Returns false if the key is absent.
bool wavReadProperty(const char *path, const char *key, char *out, int outSize);

/// Reads the audio properties of the file at `path`.
WavPropertiesResult wavAudioProperties(const char *path);

/// Parses the RIFF header of the file at `path` directly, without going through TagLib.
RiffHeaderInfo riffHeaderInfo(const char *path);

// MARK: - RIFF INFO

/// What `RIFF::Info::Tag::properties()` reports for a tag holding INAM = `title` and `fieldID`, an ID
/// with no property key, and what `removeUnsupportedProperties(unsupportedData())` then leaves.
typedef struct {
    int unsupportedCount;
    /// The first entry of `unsupportedData()` as UTF-8; empty if there is none.
    char firstUnsupported[16];
    /// Whether the map's TITLE is `title`.
    bool titleMapped;
    /// Whether `fieldID` is still in the tag after the removal.
    bool fieldRemains;
    /// Whether INAM still holds `title` after the removal.
    bool titleKept;
} InfoUnsupportedResult;

InfoUnsupportedResult infoUnsupportedProperties(const char *title, const char *fieldID);

/// Parses an INFO list holding one IARL field of `size` bytes from `fieldBytes`, with
/// `declaredCodePage` as the file's CSET code page (0 for none) and `assumedCodePage` set through
/// `setAssumedCodePage()` for the parse only, and copies the field's text as UTF-8 into `out`.
/// Returns the length of that text.
int infoDecodedField(const char *fieldBytes, unsigned int size, unsigned int declaredCodePage,
                     unsigned int assumedCodePage, char *out, int outSize);

// MARK: - Matroska

/// Sets the property `key` to `value` through the property map, keeping every other property, and
/// saves. Returns false if the file could not be opened or saved.
bool mkvSetProperty(const char *path, const char *key, const char *value);

/// The length in bytes of the property `key`'s first value as TagLib reads it back, or -1 if absent.
/// `out` receives up to `outSize - 1` bytes of it.
long long mkvReadProperty(const char *path, const char *key, char *out, long long outSize);

/// Sets the property `key` to `value`, adds an attached file holding `size` bytes of `data`, and
/// saves with `WriteStyle::AvoidInsert` when `avoidInsert`, `WriteStyle::Compact` otherwise.
bool mkvSetPropertyAndAttach(const char *path, const char *key, const char *value,
                             const void *data, unsigned int size, bool avoidInsert);

/// The number of attached files TagLib reads back, or -1 if the file is not valid.
int mkvAttachedFileCount(const char *path);

/// The Segment's top-level elements, read straight from the file rather than through TagLib.
typedef struct {
    /// Whether every top-level element in the Segment has a valid ID and size, and the last ends
    /// exactly where the Segment's declared size does.
    bool contiguous;
    long long segmentEnd;
    long long fileSize;
    /// Offset of the first Cluster, or -1 if there is none.
    long long firstClusterOffset;
} MkvSegmentLayout;

MkvSegmentLayout mkvSegmentLayout(const char *path);

/// The length in bytes `EBML::renderVINT(size, 0)` writes `size` in; 0 if it wrote nothing.
/// `roundTrips` reports whether parsing that rendering gives back `size` as a known size.
int ebmlSizeLength(unsigned long long size, bool *roundTrips);

// MARK: - ID3v2

/// The frames of an ID3v2 tag after `id3v2SetComment`.
typedef struct {
    /// COMM frames, in frame order; `languages` and `texts` describe the first 4 of them.
    int commentCount;
    char languages[4][4];
    /// Each COMM frame's text as UTF-8 (max 32 bytes each).
    char texts[4][32];
    int userTextCount;
} ID3v2CommentFrames;

/// Builds an ID3v2 tag holding an undescribed COMM frame for each of the `count` `languages` and
/// `texts`, then calls `setProperties` with COMMENT set to the `valueCount` `values`, or with the
/// tag's own `properties()` when `values` is null, and describes the frames that remain.
ID3v2CommentFrames id3v2SetComment(int count, const char **languages, const char **texts,
                                   int valueCount, const char **values);

/// A frame for `id3v2SetProperty` to build: a text (`T***`, `TXXX`), `COMM`, `USLT`, or URL
/// (`W***`, `WXXX`) frame. Strings are UTF-8; `language` and `description` are ignored by frames
/// without them.
typedef struct {
    const char *frameID;
    const char *language;
    const char *description;
    /// The text, URL, or `/`-separated fields of a text frame.
    const char *text;
    /// A `TagLib::String::Type` raw value: 0 Latin-1, 3 UTF-8.
    int encoding;
} ID3v2FrameSpec;

/// One frame of an `ID3v2FrameList`; strings are UTF-8, truncated to 31 bytes.
typedef struct {
    char frameID[5];
    char language[4];
    char description[32];
    /// The text or URL; a text frame's fields joined by `/`, without a TXXX description.
    char text[32];
    /// The stored `TagLib::String::Type`, or -1 for a frame without one.
    int encoding;
} ID3v2FrameState;

/// The frames of an ID3v2 tag in `frameList()` order; `frames` describes the first 8.
typedef struct {
    int frameCount;
    ID3v2FrameState frames[8];
} ID3v2FrameList;

/// Builds an ID3v2 tag from the `count` `frames`, then calls `setProperties` with the tag's own
/// `properties()` in which `key` is set to the `valueCount` `values`, or removed when `values` is
/// null, and describes the frames that remain.
ID3v2FrameList id3v2SetProperty(int count, const ID3v2FrameSpec *frames, const char *key,
                                int valueCount, const char **values);

/// A `CTOC` frame with `childCount` child element IDs and an embedded `TIT2`, rendered and parsed
/// back. `parsedChildren` is the parsed entry count; `titleParsed` whether the `TIT2` survived.
void id3v2TableOfContentsRoundTrip(int childCount, int *parsedChildren, bool *titleParsed);

// MARK: - DeferredWriteStream

/// Applies `operations` seeded random writes, insertions, removals and truncations to a
/// `DeferredWriteStream` over the file at `path` and to a `ByteVectorStream` holding the same bytes,
/// comparing their whole content after each one, then commits and compares the file. Returns -1
/// when everything matched, the index of the first operation after which the contents differed, or
/// `operations` when only the committed file differed. `copyPath`, an existing file, also receives
/// the content through `writeTo` before the commit; -2 when that copy differed.
int deferredStreamFuzz(const char *path, const char *copyPath, unsigned int seed, int operations);

/// `bytesToMove()` after one edit of the file at `path`: 0 overwrites 16 bytes at 100, 1 appends 16,
/// 2 inserts 16 at 100, 3 removes 16 at 100.
long long deferredStreamBytesToMove(const char *path, int edit);

/// The bytes a commit writes to the file at `path` after inserting `insertSize` bytes at
/// `insertAt` and then removing `removeSize` bytes at `removeAt`; -1 if the commit failed.
long long deferredStreamCommitBytes(const char *path, long long insertAt, unsigned int insertSize,
                                    long long removeAt, unsigned int removeSize);

/// Whether a commit over a read-only stream with recorded changes is refused.
bool deferredStreamRefusesReadOnlyCommit(const char *path);

// MARK: - File utilities

/// Copies `src` to `dst`. Returns true on success.
bool copyTestFile(const char *src, const char *dst);

/// Returns the file size in bytes, or -1 on error.
long long testFileSize(const char *path);

/// Counts top-level mdat atoms in an MP4/M4A file.
/// Returns the count, or -1 on error.
int countMdatAtoms(const char *path);

/// Returns the size in bytes of the first mdat atom in an MP4/M4A file.
/// Returns -1 on error or if no mdat is found.
long long firstMdatSize(const char *path);

#ifdef __cplusplus
}
#endif

#endif
