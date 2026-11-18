# Device notes — CPH1801 (OPPO A71)

Everything here was measured on the device, not copied from a wiki. Where a value
is model-specific it is marked. Wrong values on other devices are expected.

## Identity

| | |
|---|---|
| Model | CPH1801 |
| SoC | Qualcomm SDM450 (8× Cortex-A53) |
| RAM | 2 GB |
| Display | 720×1280, 60 Hz |
| Android | 7.1.1 (API 25) |
| `/system` | ext4, mounted read-only |

## Partition map (the parts that mattered)

`/system` is `/dev/block/mmcblk0p59`. `by-name` entries exist for the usual
partitions; the interesting property is that there is **no `dm-verity`** on this
build (`ro.boot.veritymode` is not `enforcing`), so a raw block write to `/system`
does not trip verification on the next boot.

That is unusual and worth stating plainly: on most devices of this era the same
write would brick the boot. Do not assume it holds on another model without
checking `veritymode` first.

## `remount` returns EPERM

```
mount -o rw,remount /system
→ mount: Operation not permitted
```

Even as `uid=0`. The kernel/SEPolicy combination refuses the remount, so the usual
`mount -o rw` path is closed. Writing anyway is possible because the block device
node is writable by root, which makes the workflow:

1. `tools/fiemap.c` — ask the filesystem where the target file physically lives
   (ext4 extents, not contiguous in general).
2. `dd` the payload over those extents, in order.

On this device `/system/media/bootanimation.zip` was inode **265680**, occupying
**3 extents**. Any replacement must be the same byte length, because the file
cannot grow — there is no free space reserved after it.

## The bootanimation slot is a fixed size

`/system/media/bootanimation.zip` is **1,156,803 bytes** on this build. Not "about
1.1 MB" — that exact number, because the file is replaced in place and the extents
do not move.

Practical consequence: a custom animation has to be padded to that exact count.
`tools/bootanim_build.py` builds the archive, measures ZIP overhead, and pads with
a NUL entry; if the frames do not fit it exits instead of writing a truncated
(and therefore non-booting) file.

## The bootanimation binary is a fork

The OPPO build does not parse the AOSP `desc.txt`. It reads:

```
g <w> <h> <ox> <oy> <fps>
p <count> <pause> <path>
```

and ignores `/data/local/bootanimation.zip` entirely — the usual "drop a zip in
/data/local to preview" trick does not work here. Confirmed from the boot log:

```
BootAnimation: > w=720, h=1280, ox=0, oy=0, fps=12
BootAnimation: > count=1, pause=0, path=part0
```

Frame decoding goes through `SkImageDecoder::Factory`, which sniffs content rather
than extension, and `libskia.so` in this ROM contains JPEG, PNG, and WebP codecs.
So `.jpg` frames work — worth knowing, because JPEG buys roughly 3× the frame
budget of PNG at the same visual quality for photographic frames.

## adb over WiFi

`setprop persist.adb.tcp.port 5555` survives reboot and brings adbd back up
listening without a cable. Note the failure mode found the hard way: if adbd is
killed mid-session and restarted by init, the socket can end up listening while
the daemon never answers the handshake — the port accepts TCP, `adb devices`
reports `offline` forever, and only a reboot clears it. Checking "is the port
open" is not enough to conclude adbd is healthy.

## Performance stack

The device throttles hard on 2 GB of RAM. A small shell daemon watching foreground
app changes and writing to the kernel's cpufreq/GPU governors made a measurable
difference in app-switch latency; it autostarts from the same pre-zygote stage the
detector looks for. Not included here — it is device-tuned and would be wrong on
anything else.
