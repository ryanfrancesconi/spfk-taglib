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

// MARK: - FileStream moves

/// `FileStream::insert` on the file at `path`, through a move buffer of `moveBufferSize` bytes
/// (0 for the default). Returns false if the file could not be opened for writing.
bool streamInsert(const char *path, const void *data, unsigned int size,
                  long long start, unsigned int replace, unsigned int moveBufferSize);

/// `FileStream::removeBlock` on the file at `path`, as `streamInsert`.
bool streamRemoveBlock(const char *path, long long start, unsigned int length,
                       unsigned int moveBufferSize);

/// The move buffer size a new `FileStream` uses, and what `setMoveBufferSize(size)` then reports.
unsigned int streamMoveBufferSize(unsigned int size);

// MARK: - DeferredWriteStream

/// Applies `operations` seeded random writes, insertions, removals and truncations to a
/// `DeferredWriteStream` over the file at `path` and to a `ByteVectorStream` holding the same bytes,
/// comparing their whole content after each one, then commits and compares the file. Returns -1
/// when everything matched, the index of the first operation after which the contents differed, or
/// `operations` when only the committed file differed.
int deferredStreamFuzz(const char *path, unsigned int seed, int operations);

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
