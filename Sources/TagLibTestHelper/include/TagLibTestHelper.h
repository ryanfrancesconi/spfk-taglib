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
