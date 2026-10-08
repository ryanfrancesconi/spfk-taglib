/**************************************************************************
    copyright            : (C) 2026 by Ryan Francesconi
 **************************************************************************/

#include "TagLibTestHelper.h"

#include <taglib/matroskaattachedfile.h>
#include <taglib/matroskaattachments.h>
#include <taglib/matroskafile.h>
#include <taglib/mp4chapter.h>
#include <taglib/mp4file.h>
#include <taglib/tbytevectorstream.h>
#include <taglib/tdeferredwritestream.h>
#include <taglib/tfilestream.h>
#include <taglib/tpropertymap.h>
#include <taglib/wavfile.h>

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <random>
#include <iterator>
#include <vector>

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

// MARK: - Matroska

bool mkvSetProperty(const char *path, const char *key, const char *value)
{
    Matroska::File file(path);
    if(!file.isValid() || file.readOnly()) return false;
    PropertyMap properties = file.properties();
    properties.replace(String(key, String::UTF8), StringList(String(value, String::UTF8)));
    file.setProperties(properties);
    return file.save();
}

long long mkvReadProperty(const char *path, const char *key, char *out, long long outSize)
{
    Matroska::File file(path);
    if(!file.isValid()) return -1;
    const PropertyMap properties = file.properties();
    const auto it = properties.find(String(key, String::UTF8));
    if(it == properties.end() || it->second.isEmpty()) return -1;
    const ByteVector data = it->second.front().data(String::UTF8);
    if(out && outSize > 0) {
        const auto count = std::min<long long>(data.size(), outSize - 1);
        std::memcpy(out, data.data(), static_cast<size_t>(count));
        out[count] = '\0';
    }
    return data.size();
}

bool mkvSetPropertyAndAttach(const char *path, const char *key, const char *value,
                             const void *data, unsigned int size, bool avoidInsert)
{
    Matroska::File file(path);
    if(!file.isValid() || file.readOnly()) return false;
    PropertyMap properties = file.properties();
    properties.replace(String(key, String::UTF8), StringList(String(value, String::UTF8)));
    file.setProperties(properties);
    file.attachments(true)->addAttachedFile(Matroska::AttachedFile(
        ByteVector(static_cast<const char *>(data), size), "cover.jpg", "image/jpeg"));
    return file.save(avoidInsert ? Matroska::WriteStyle::AvoidInsert : Matroska::WriteStyle::Compact);
}

int mkvAttachedFileCount(const char *path)
{
    Matroska::File file(path);
    if(!file.isValid()) return -1;
    const auto *attachments = file.attachments();
    return attachments ? static_cast<int>(attachments->attachedFileList().size()) : 0;
}

namespace {

// An EBML ID's length from its first byte (1-4), or 0 if the byte cannot start one.
int ebmlIDLength(uint8_t first)
{
    for(int length = 1; length <= 4; ++length) {
        if(first & (0x80 >> (length - 1))) return length;
    }
    return 0;
}

// Reads an EBML variable-length size at `offset`; false if it runs off `bytes`.
bool ebmlSize(const std::vector<uint8_t> &bytes, size_t offset, long long &value, int &length)
{
    if(offset >= bytes.size()) return false;
    const uint8_t first = bytes[offset];
    length = 0;
    for(int candidate = 1; candidate <= 8; ++candidate) {
        if(first & (0x80 >> (candidate - 1))) { length = candidate; break; }
    }
    if(length == 0 || offset + length > bytes.size()) return false;
    value = first & ((0x80 >> (length - 1)) - 1);
    for(int index = 1; index < length; ++index) value = (value << 8) | bytes[offset + index];
    return true;
}

} // namespace

MkvSegmentLayout mkvSegmentLayout(const char *path)
{
    MkvSegmentLayout layout { false, -1, -1, -1 };

    std::ifstream stream(path, std::ios::binary);
    const std::vector<uint8_t> bytes((std::istreambuf_iterator<char>(stream)), std::istreambuf_iterator<char>());
    layout.fileSize = static_cast<long long>(bytes.size());

    size_t offset = 0;
    while(offset < bytes.size()) {
        const int idLength = ebmlIDLength(bytes[offset]);
        long long size = 0;
        int sizeLength = 0;
        if(idLength == 0 || !ebmlSize(bytes, offset + idLength, size, sizeLength)) return layout;

        uint32_t id = 0;
        for(int index = 0; index < idLength; ++index) id = (id << 8) | bytes[offset + index];
        const size_t dataOffset = offset + idLength + sizeLength;

        if(id != 0x18538067) {
            offset = dataOffset + static_cast<size_t>(size);
            continue;
        }

        layout.segmentEnd = static_cast<long long>(dataOffset) + size;
        size_t child = dataOffset;
        while(child < static_cast<size_t>(layout.segmentEnd)) {
            const int childIDLength = child < bytes.size() ? ebmlIDLength(bytes[child]) : 0;
            long long childSize = 0;
            int childSizeLength = 0;
            if(childIDLength == 0 || !ebmlSize(bytes, child + childIDLength, childSize, childSizeLength)) return layout;

            uint32_t childID = 0;
            for(int index = 0; index < childIDLength; ++index) childID = (childID << 8) | bytes[child + index];
            if(childID == 0x1F43B675 && layout.firstClusterOffset < 0) layout.firstClusterOffset = static_cast<long long>(child);

            child += childIDLength + childSizeLength + static_cast<size_t>(childSize);
        }
        layout.contiguous = child == static_cast<size_t>(layout.segmentEnd);
        return layout;
    }
    return layout;
}

// MARK: - DeferredWriteStream

namespace {

ByteVector readWholeFile(const char *path)
{
    std::ifstream stream(path, std::ios::binary);
    const std::vector<char> bytes((std::istreambuf_iterator<char>(stream)), std::istreambuf_iterator<char>());
    return ByteVector(bytes.data(), static_cast<unsigned int>(bytes.size()));
}

ByteVector wholeContent(IOStream &stream)
{
    stream.seek(0);
    return stream.readBlock(static_cast<size_t>(stream.length()));
}

class CountingFileStream : public FileStream {
public:
    using FileStream::FileStream;
    long long written = 0;

    void writeBlock(const ByteVector &data) override
    {
        written += data.size();
        FileStream::writeBlock(data);
    }
};

} // namespace

int deferredStreamFuzz(const char *path, unsigned int seed, int operations)
{
    FileStream file(path);
    if(!file.isOpen() || file.readOnly()) return 0;

    ByteVectorStream reference(readWholeFile(path));
    DeferredWriteStream deferred(&file);
    std::mt19937 random(seed);

    auto below = [&random](long long bound) {
        return bound <= 0 ? 0LL : static_cast<long long>(random() % static_cast<unsigned long long>(bound));
    };
    auto bytes = [&random](long long count) {
        ByteVector data(static_cast<unsigned int>(count));
        for(unsigned int i = 0; i < data.size(); ++i) data[i] = static_cast<char>(random());
        return data;
    };

    for(int operation = 0; operation < operations; ++operation) {
        const long long length = reference.length();

        // Weighted so most of the original content survives to be moved by the commit.
        const unsigned int kind = random() % 20;
        switch(kind < 6 ? 0 : kind < 12 ? 1 : kind < 17 ? 2 : kind < 18 ? 3 : 4) {
        case 0: {
            const long long at = below(length + 16);
            const ByteVector data = bytes(1 + below(300));
            reference.seek(at);
            reference.writeBlock(data);
            deferred.seek(at);
            deferred.writeBlock(data);
            break;
        }
        case 1: {
            const long long at = below(length + 1);
            const size_t replace = static_cast<size_t>(below(std::min(length - at, 64LL) + 1));
            const ByteVector data = bytes(below(2000));
            reference.insert(data, at, replace);
            deferred.insert(data, at, replace);
            break;
        }
        case 2: {
            const long long at = below(length + 1);
            const size_t count = static_cast<size_t>(below(std::min(length - at, 2000LL) + 1));
            reference.removeBlock(at, count);
            deferred.removeBlock(at, count);
            break;
        }
        case 3: {
            const long long to = std::max(0LL, length - 64 + below(128));
            reference.truncate(to);
            deferred.truncate(to);
            break;
        }
        default: {
            const long long at = below(length + 1);
            const size_t count = static_cast<size_t>(below(500));
            reference.seek(at);
            deferred.seek(at);
            if(reference.readBlock(count) != deferred.readBlock(count)) return operation;
            if(reference.tell() != deferred.tell()) return operation;
            break;
        }
        }

        if(reference.length() != deferred.length() || wholeContent(reference) != wholeContent(deferred))
            return operation;
    }

    if(!deferred.commit()) return operations;
    file.seek(0);
    const ByteVector committed = file.readBlock(static_cast<size_t>(file.length()));
    if(committed != *reference.data() || wholeContent(deferred) != *reference.data()) return operations;
    return -1;
}

long long deferredStreamCommitBytes(const char *path, long long insertAt, unsigned int insertSize,
                                    long long removeAt, unsigned int removeSize)
{
    CountingFileStream file(path);
    if(!file.isOpen() || file.readOnly()) return -1;

    DeferredWriteStream deferred(&file);
    deferred.insert(ByteVector(insertSize, 'x'), insertAt, 0);
    deferred.removeBlock(removeAt, removeSize);

    file.written = 0;
    return deferred.commit() ? file.written : -1;
}

bool deferredStreamRefusesReadOnlyCommit(const char *path)
{
    FileStream file(path, true);
    DeferredWriteStream deferred(&file);
    deferred.insert(ByteVector("x", 1), 0, 0);
    const ByteVector before = readWholeFile(path);
    return !deferred.commit() && readWholeFile(path) == before;
}

// MARK: - FileStream moves

bool streamInsert(const char *path, const void *data, unsigned int size,
                  long long start, unsigned int replace, unsigned int moveBufferSize)
{
    FileStream stream(path);
    if(!stream.isOpen() || stream.readOnly()) return false;
    stream.setMoveBufferSize(moveBufferSize);
    stream.insert(ByteVector(static_cast<const char *>(data), size), start, replace);
    return true;
}

bool streamRemoveBlock(const char *path, long long start, unsigned int length,
                       unsigned int moveBufferSize)
{
    FileStream stream(path);
    if(!stream.isOpen() || stream.readOnly()) return false;
    stream.setMoveBufferSize(moveBufferSize);
    stream.removeBlock(start, length);
    return true;
}

unsigned int streamMoveBufferSize(unsigned int size)
{
    FileStream stream("/dev/null", true);
    stream.setMoveBufferSize(size);
    return stream.moveBufferSize();
}

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
