/**************************************************************************
    copyright            : (C) 2026 by Ryan Francesconi
 **************************************************************************/

#include "TagLibTestHelper.h"

#include <taglib/mp4chapter.h>
#include <taglib/mp4file.h>
#include <taglib/tfilestream.h>
#include <taglib/tpropertymap.h>
#include <taglib/wavfile.h>

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

// MARK: - RIFF / RF64

bool wavIsSupported(const char *path)
{
    FileStream stream(path, true);
    return RIFF::WAV::File::isSupported(&stream);
}

bool wavWriteProperties(const char *path, const char *title, const char *artist)
{
    RIFF::WAV::File file(path);
    if(!file.isOpen() || !file.isValid())
        return false;

    PropertyMap map;
    map.insert("TITLE", StringList(String(title, String::UTF8)));
    map.insert("ARTIST", StringList(String(artist, String::UTF8)));

    if(!file.setProperties(map).isEmpty())
        return false;

    return file.save();
}

bool wavReadProperty(const char *path, const char *key, char *out, int outSize)
{
    if(outSize > 0)
        out[0] = '\0';

    RIFF::WAV::File file(path);
    if(!file.isOpen() || !file.isValid())
        return false;

    const PropertyMap map = file.properties();
    const auto it = map.find(String(key, String::UTF8));
    if(it == map.end() || it->second.isEmpty())
        return false;

    const ByteVector utf8 = it->second.front().data(String::UTF8);
    const size_t len = utf8.size() < static_cast<size_t>(outSize) - 1
                           ? utf8.size()
                           : static_cast<size_t>(outSize) - 1;
    memcpy(out, utf8.data(), len);
    out[len] = '\0';
    return true;
}

WavPropertiesResult wavAudioProperties(const char *path)
{
    WavPropertiesResult result;
    memset(&result, 0, sizeof(result));

    RIFF::WAV::File file(path);
    if(!file.isOpen() || !file.isValid())
        return result;

    if(const auto *props = file.audioProperties()) {
        result.lengthMs   = props->lengthInMilliseconds();
        result.bitrate    = props->bitrate();
        result.sampleRate = props->sampleRate();
        result.channels   = props->channels();
    }
    return result;
}

RiffHeaderInfo riffHeaderInfo(const char *path)
{
    RiffHeaderInfo info;
    memset(&info, 0, sizeof(info));
    info.dataChunkDeclaredSize = -1;
    info.dataChunkOffset = -1;
    info.fileSize = -1;

    std::ifstream f(path, std::ios::binary | std::ios::ate);
    if(!f) return info;

    info.fileSize = static_cast<long long>(f.tellg());
    f.seekg(0, std::ios::beg);

    auto readU32 = [&f]() -> unsigned int {
        unsigned char b[4] = {0, 0, 0, 0};
        f.read(reinterpret_cast<char *>(b), 4);
        return static_cast<unsigned int>(b[0]) | static_cast<unsigned int>(b[1]) << 8 |
               static_cast<unsigned int>(b[2]) << 16 | static_cast<unsigned int>(b[3]) << 24;
    };
    auto readU64 = [&readU32]() -> long long {
        const unsigned long long lo = readU32();
        const unsigned long long hi = readU32();
        return static_cast<long long>(lo | hi << 32);
    };

    f.read(info.magic, 4);
    info.magic[4] = '\0';
    info.sizeField = readU32();

    long long offset = 12;
    while(offset + 8 <= info.fileSize) {
        f.seekg(offset);
        char name[5] = {0, 0, 0, 0, 0};
        f.read(name, 4);
        const unsigned int declared = readU32();

        long long advance = declared;

        if(memcmp(name, "ds64", 4) == 0 && declared >= 28) {
            info.hasDS64 = true;
            info.riffSize = readU64();
            info.dataSize = readU64();
            info.sampleCount = readU64();
            info.tableLength = readU32();
        }
        else if(memcmp(name, "data", 4) == 0) {
            info.dataChunkDeclaredSize = declared;
            info.dataChunkOffset = offset + 8;
            if(declared == 0xffffffffu) {
                if(!info.hasDS64) break;
                advance = info.dataSize;
            }
        }

        offset += 8 + advance + (advance % 2);
    }

    return info;
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
