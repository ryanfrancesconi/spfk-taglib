#!/usr/bin/env python3
"""Dump MP4/M4A atom structure.

Usage: python3 dump_atoms.py <file.m4a>

Recursively prints every atom with offset, name, and size.
Annotates key atoms with extra detail:
  - tkhd: version and flags
  - hdlr: handler type (soun, text, etc.)
  - stco: entry count and first few chunk offsets
  - mdat: payload size (excluding 8-byte header)
  - mvhd: timescale and duration
  - mdhd: timescale and duration
"""
import struct, sys

def dump(f, end, depth=0):
    while f.tell() < end:
        pos = f.tell()
        hdr = f.read(8)
        if len(hdr) < 8:
            break
        size, name = struct.unpack('>I4s', hdr)
        name = name.decode('latin-1')
        if size == 1:
            size = struct.unpack('>Q', f.read(8))[0]
        elif size == 0:
            size = end - pos

        extra = ""
        # Show tkhd flags
        if name == 'tkhd' and size >= 12:
            saved = f.tell()
            vf = f.read(4)
            if len(vf) == 4:
                version = vf[0]
                flags = (vf[1] << 16) | (vf[2] << 8) | vf[3]
                extra = f" [v{version} flags=0x{flags:06x}]"
            f.seek(saved)
        # Show hdlr type
        elif name == 'hdlr' and size >= 20:
            saved = f.tell()
            f.read(8)  # version+flags + pre_defined
            ht = f.read(4)
            if len(ht) == 4:
                extra = f" [{ht.decode('latin-1')}]"
            f.seek(saved)
        # Show stco entry count + first few offsets
        elif name == 'stco' and size >= 16:
            saved = f.tell()
            f.read(4)  # version+flags
            count = struct.unpack('>I', f.read(4))[0]
            offsets = []
            for _ in range(min(count, 8)):
                offsets.append(struct.unpack('>I', f.read(4))[0])
            extra = f" [count={count} offsets={offsets}]"
            f.seek(saved)
        # Show mdat size
        elif name == 'mdat':
            extra = f" [data_size={size - 8}]"
        # Show mvhd timescale and duration
        elif name == 'mvhd' and size >= 28:
            saved = f.tell()
            vf = f.read(4)
            if len(vf) == 4:
                version = vf[0]
                if version == 0:
                    f.read(8)  # creation + modification time
                    ts = struct.unpack('>I', f.read(4))[0]
                    dur = struct.unpack('>I', f.read(4))[0]
                else:
                    f.read(16)  # creation + modification time (64-bit)
                    ts = struct.unpack('>I', f.read(4))[0]
                    dur = struct.unpack('>Q', f.read(8))[0]
                extra = f" [v{version} timescale={ts} duration={dur}]"
            f.seek(saved)
        # Show mdhd timescale and duration
        elif name == 'mdhd' and size >= 24:
            saved = f.tell()
            vf = f.read(4)
            if len(vf) == 4:
                version = vf[0]
                if version == 0:
                    f.read(8)  # creation + modification time
                    ts = struct.unpack('>I', f.read(4))[0]
                    dur = struct.unpack('>I', f.read(4))[0]
                else:
                    f.read(16)  # creation + modification time (64-bit)
                    ts = struct.unpack('>I', f.read(4))[0]
                    dur = struct.unpack('>Q', f.read(8))[0]
                extra = f" [v{version} timescale={ts} duration={dur}]"
            f.seek(saved)

        print(f"{'  ' * depth}{pos:8d}  {name}  size={size}{extra}")

        containers = {'moov','trak','mdia','minf','stbl','udta','dinf',
                       'tref','edts','gmhd','meta','ilst'}
        if name in containers:
            dump(f, pos + size, depth + 1)
        f.seek(pos + size)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <file.m4a|.mp4>", file=sys.stderr)
        sys.exit(1)
    with open(sys.argv[1], 'rb') as f:
        f.seek(0, 2)
        fsize = f.tell()
        f.seek(0)
        print(f"File: {sys.argv[1]}  ({fsize} bytes)")
        dump(f, fsize)
