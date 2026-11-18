#!/usr/bin/env python3
"""Build a bootanimation.zip for the A71 and pad it to the exact size of the
stock file (1156803 bytes) so it can be written into the /system partition
blocks without touching ext4 metadata.

Usage: bootanim_build.py <frames_dir> <fps> <out.zip>
frames_dir holds 0001.png ... sized 720x1280.
"""
import io, os, sys, zipfile

TARGET = 1156803

def build(frames, fps, pad):
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_STORED) as z:
        z.writestr("desc.txt",
                   "# global width height offsetx offsety fps\n"
                   f"g 720 1280 0 0 {fps}\n"
                   "p 1 0 part0\n")
        for n in sorted(os.listdir(frames)):
            if n.endswith(".png"):
                z.write(os.path.join(frames, n), "part0/" + n)
        if pad >= 0:
            z.writestr("pad.bin", b"\0" * pad)
    return buf.getvalue()

frames, fps, out = sys.argv[1], int(sys.argv[2]), sys.argv[3]
base = build(frames, fps, -1)
overhead = len(build(frames, fps, 1)) - len(base) - 1
data = build(frames, fps, TARGET - len(base) - overhead)
assert len(data) == TARGET, len(data)
open(out, "wb").write(data)
print(f"{out}: {len(data)} bytes")
