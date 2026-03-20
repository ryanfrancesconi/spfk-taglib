/**************************************************************************
    copyright            : (C) 2026 by Ryan Francesconi
 **************************************************************************/

#include "TagLibTestHelper.h"

#include <taglib/mp4qtchapterlist.h>
#include <taglib/mp4chapterlist.h>
#include <taglib/mp4file.h>

#include <cstring>
#include <fstream>

using namespace TagLib;

extern "C" {

bool qtChapterWrite(const char *path, int count,
                    const long long *startTimesMs, const char **titles)
{
    MP4::ChapterList chapters;
    for(int i = 0; i < count; ++i) {
        MP4::Chapter ch;
        // Convert ms to 100-ns units
        ch.startTime = startTimesMs[i] * 10000LL;
        ch.title = String(titles[i], String::UTF8);
        chapters.append(ch);
    }
    return MP4::MP4QTChapterList::write(path, chapters);
}

ChapterReadResult qtChapterRead(const char *path)
{
    ChapterReadResult result;
    memset(&result, 0, sizeof(result));

    MP4::ChapterList chapters = MP4::MP4QTChapterList::read(path);
    result.count = static_cast<int>(chapters.size());

    int i = 0;
    for(const auto &ch : chapters) {
        if(i >= 8) break;
        // Convert 100-ns to ms
        result.startTimesMs[i] = ch.startTime / 10000LL;
        ByteVector utf8 = ch.title.data(String::UTF8);
        size_t len = utf8.size() < 63 ? utf8.size() : 63;
        memcpy(result.titles[i], utf8.data(), len);
        result.titles[i][len] = '\0';
        ++i;
    }
    return result;
}

bool qtChapterRemove(const char *path)
{
    return MP4::MP4QTChapterList::remove(path);
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

}  // extern "C"
