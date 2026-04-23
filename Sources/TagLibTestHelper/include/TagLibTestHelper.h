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
