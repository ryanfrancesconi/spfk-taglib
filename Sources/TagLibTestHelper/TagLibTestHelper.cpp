/**************************************************************************
    copyright            : (C) 2026 by Ryan Francesconi
 **************************************************************************/

#include "TagLibTestHelper.h"

#include <taglib/mp4chapter.h>
#include <taglib/mp4file.h>

#include <cstdint>
#include <cstring>
#include <fstream>

using namespace TagLib;

extern "C" {

// MARK: - QT chapters

bool qtChapterWrite(const char *path, int count,
                    const long long *startTimesMs, const char **titles)
{
    MP4::ChapterList chapters;
    for(int i = 0; i < count; ++i) {
        chapters.append(MP4::Chapter(
            String(titles[i], String::UTF8),
            startTimesMs[i]  // already in ms
        ));
    }

    MP4::File file(path);
    if(!file.isOpen() || !file.isValid())
        return false;
    file.setQtChapters(chapters);
    return file.save();
}

ChapterReadResult qtChapterRead(const char *path)
{
    ChapterReadResult result;
    memset(&result, 0, sizeof(result));

    MP4::File file(path);
    if(!file.isOpen() || !file.isValid())
        return result;

    MP4::ChapterList chapters = file.qtChapters();
    result.count = static_cast<int>(chapters.size());

    int i = 0;
    for(const auto &ch : chapters) {
        if(i >= 8) break;
        result.startTimesMs[i] = ch.startTime();  // already in ms
        ByteVector utf8 = ch.title().data(String::UTF8);
        size_t len = utf8.size() < 63 ? utf8.size() : 63;
        memcpy(result.titles[i], utf8.data(), len);
        result.titles[i][len] = '\0';
        ++i;
    }
    return result;
}

bool qtChapterRemove(const char *path)
{
    MP4::File file(path);
    if(!file.isOpen() || !file.isValid())
        return false;
    file.setQtChapters(MP4::ChapterList());
    return file.save();
}

// MARK: - Nero chapters

bool neroChapterWrite(const char *path, int count,
                      const long long *startTimesMs, const char **titles)
{
    MP4::ChapterList chapters;
    for(int i = 0; i < count; ++i) {
        chapters.append(MP4::Chapter(
            String(titles[i], String::UTF8),
            startTimesMs[i]  // already in ms
        ));
    }

    MP4::File file(path);
    if(!file.isOpen() || !file.isValid())
        return false;
    file.setNeroChapters(chapters);
    return file.save();
}

ChapterReadResult neroChapterRead(const char *path)
{
    ChapterReadResult result;
    memset(&result, 0, sizeof(result));

    MP4::File file(path);
    if(!file.isOpen() || !file.isValid())
        return result;

    MP4::ChapterList chapters = file.neroChapters();
    result.count = static_cast<int>(chapters.size());

    int i = 0;
    for(const auto &ch : chapters) {
        if(i >= 8) break;
        result.startTimesMs[i] = ch.startTime();  // already in ms
        ByteVector utf8 = ch.title().data(String::UTF8);
        size_t len = utf8.size() < 63 ? utf8.size() : 63;
        memcpy(result.titles[i], utf8.data(), len);
        result.titles[i][len] = '\0';
        ++i;
    }
    return result;
}

bool neroChapterRemove(const char *path)
{
    MP4::File file(path);
    if(!file.isOpen() || !file.isValid())
        return false;
    file.setNeroChapters(MP4::ChapterList());
    return file.save();
}

// MARK: - File utilities

bool copyTestFile(const char *src, const char *dst)
{
    std::ifstream in(src, std::ios::binary);
    if(!in) return false;
    std::ofstream out(dst, std::ios::binary);
    if(!out) return false;
    out << in.rdbuf();
    return out.good();
}

long long testFileSize(const char *path)
{
    std::ifstream f(path, std::ios::binary | std::ios::ate);
    if(!f) return -1;
    return static_cast<long long>(f.tellg());
}

int countMdatAtoms(const char *path)
{
    std::ifstream f(path, std::ios::binary);
    if(!f) return -1;

    f.seekg(0, std::ios::end);
    const long long fileSize = static_cast<long long>(f.tellg());
    f.seekg(0, std::ios::beg);

    int count = 0;
    long long pos = 0;

    while(pos + 8 <= fileSize) {
        f.seekg(pos);

        uint8_t header[8] = {};
        if(!f.read(reinterpret_cast<char *>(header), 8))
            break;

        // Size is big-endian 32-bit
        long long size = (static_cast<long long>(header[0]) << 24) |
                         (static_cast<long long>(header[1]) << 16) |
                         (static_cast<long long>(header[2]) << 8)  |
                          static_cast<long long>(header[3]);

        if(header[4] == 'm' && header[5] == 'd' && header[6] == 'a' && header[7] == 't')
            ++count;

        if(size == 0) {
            // Atom extends to end of file
            break;
        } else if(size == 1) {
            // 64-bit extended size follows
            uint8_t ext[8] = {};
            if(!f.read(reinterpret_cast<char *>(ext), 8))
                break;
            size = (static_cast<long long>(ext[0]) << 56) |
                   (static_cast<long long>(ext[1]) << 48) |
                   (static_cast<long long>(ext[2]) << 40) |
                   (static_cast<long long>(ext[3]) << 32) |
                   (static_cast<long long>(ext[4]) << 24) |
                   (static_cast<long long>(ext[5]) << 16) |
                   (static_cast<long long>(ext[6]) << 8)  |
                    static_cast<long long>(ext[7]);
        }

        if(size < 8 || pos + size > fileSize)
            break;

        pos += size;
    }

    return count;
}

long long firstMdatSize(const char *path)
{
    std::ifstream f(path, std::ios::binary);
    if(!f) return -1;

    f.seekg(0, std::ios::end);
    const long long fileSize = static_cast<long long>(f.tellg());
    f.seekg(0, std::ios::beg);

    long long pos = 0;

    while(pos + 8 <= fileSize) {
        f.seekg(pos);

        uint8_t header[8] = {};
        if(!f.read(reinterpret_cast<char *>(header), 8))
            break;

        long long size = (static_cast<long long>(header[0]) << 24) |
                         (static_cast<long long>(header[1]) << 16) |
                         (static_cast<long long>(header[2]) << 8)  |
                          static_cast<long long>(header[3]);

        if(header[4] == 'm' && header[5] == 'd' && header[6] == 'a' && header[7] == 't') {
            if(size == 0)
                return fileSize - pos;  // extends to EOF
            if(size == 1) {
                uint8_t ext[8] = {};
                if(!f.read(reinterpret_cast<char *>(ext), 8))
                    return -1;
                return (static_cast<long long>(ext[0]) << 56) |
                       (static_cast<long long>(ext[1]) << 48) |
                       (static_cast<long long>(ext[2]) << 40) |
                       (static_cast<long long>(ext[3]) << 32) |
                       (static_cast<long long>(ext[4]) << 24) |
                       (static_cast<long long>(ext[5]) << 16) |
                       (static_cast<long long>(ext[6]) << 8)  |
                        static_cast<long long>(ext[7]);
            }
            return size;
        }

        if(size == 0) break;
        if(size == 1) {
            uint8_t ext[8] = {};
            if(!f.read(reinterpret_cast<char *>(ext), 8))
                break;
            size = (static_cast<long long>(ext[0]) << 56) |
                   (static_cast<long long>(ext[1]) << 48) |
                   (static_cast<long long>(ext[2]) << 40) |
                   (static_cast<long long>(ext[3]) << 32) |
                   (static_cast<long long>(ext[4]) << 24) |
                   (static_cast<long long>(ext[5]) << 16) |
                   (static_cast<long long>(ext[6]) << 8)  |
                    static_cast<long long>(ext[7]);
        }

        if(size < 8 || pos + size > fileSize)
            break;

        pos += size;
    }

    return -1;
}

}  // extern "C"
