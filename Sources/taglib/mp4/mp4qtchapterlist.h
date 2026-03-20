/**************************************************************************
    copyright            : (C) 2025 by Ryan Francesconi
 **************************************************************************/

/***************************************************************************
 *   This library is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU Lesser General Public License version   *
 *   2.1 as published by the Free Software Foundation.                     *
 *                                                                         *
 *   This library is distributed in the hope that it will be useful, but   *
 *   WITHOUT ANY WARRANTY; without even the implied warranty of            *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU     *
 *   Lesser General Public License for more details.                       *
 *                                                                         *
 *   You should have received a copy of the GNU Lesser General Public      *
 *   License along with this library; if not, write to the Free Software   *
 *   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA         *
 *   02110-1301  USA                                                       *
 *                                                                         *
 *   Alternatively, this file is available under the Mozilla Public        *
 *   License Version 1.1.  You may obtain a copy of the License at         *
 *   http://www.mozilla.org/MPL/                                           *
 ***************************************************************************/

#ifndef TAGLIB_MP4QTCHAPTERLIST_H
#define TAGLIB_MP4QTCHAPTERLIST_H

#include <taglib/mp4chapterlist.h>

namespace TagLib {
  namespace MP4 {

    /*!
     * Reads, writes, and removes QuickTime-style chapter tracks from MP4
     * files. A QT chapter track is a disabled text track (`hdlr` type
     * `"text"`) referenced by a `chap` track-reference in the audio track's
     * `tref` box. This format is understood by QuickTime, iTunes, Final Cut,
     * Logic, DaVinci Resolve, Twisted Wave, and most other Apple/macOS
     * software.
     *
     * The existing \c MP4ChapterList class handles Nero-style `chpl` atoms,
     * which are a different (and less widely supported) chapter format.
     *
     * Chapter times use the same 100-nanosecond unit convention as
     * \c MP4ChapterList so that existing \c Chapter / \c ChapterList types
     * can be shared.
     */
    class TAGLIB_EXPORT MP4QTChapterList
    {
    public:
      /*!
       * Reads chapter markers from the QuickTime chapter track in the
       * MP4 file at \a path. Returns an empty list if the file has no
       * chapter track (i.e. no `tref/chap` reference to a text track).
       */
      static ChapterList read(const char *path);

      /*!
       * Writes chapter markers as a QuickTime chapter track to the MP4
       * file at \a path, replacing any existing chapter track. The file's
       * duration is read internally from the movie header.
       * Returns \c true on success.
       */
      static bool write(const char *path, const ChapterList &chapters);

      /*!
       * Removes the QuickTime chapter track and its `tref/chap` reference
       * from the MP4 file at \a path.
       * Returns \c true on success, or if no chapter track exists.
       */
      static bool remove(const char *path);
    };

  }  // namespace MP4
}  // namespace TagLib

#endif
