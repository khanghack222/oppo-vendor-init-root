# oppo-vendor-init-root

Root an OPPO/ColorOS device **without unlocking the bootloader, without patching
`boot.img`, and without touching `dm-verity`** — by going through the vendor's own
root-privileged init stage instead of attacking the boot chain.

> Status: **research repo + tooling**. Verified on one device (see table). The
> detector ships here; the payload does not. Read [Scope](#scope) before opening
> an issue.

---

## Verified on

| Device | SoC | Android | ROM | Result |
|---|---|---|---|---|
| CPH1801 (A71) | SDM450 | 7.1.1 | ColorOS 3.x | `su` → `uid=0`, survives reboot |

One device is one data point. If you run it, open an issue with the output of
`tools/detect.sh` plus the result — the table is meant to grow or shrink based on
what people actually report, including failures.

---

## The idea

Every Android boot has a stage that runs **before zygote**, as `uid=0`, where the
vendor's own services start. On ColorOS builds of this era, that stage executes
shell scripts that live under `/data` — writable at runtime, outside the verified
boot chain.

That is the whole trick. Not a kernel exploit, not a race, not a leaked signing
key. The ROM asks for a script and runs it as root; the script happens to be
somewhere the user can write.

Consequences that make it worth writing down:

- **No bootloader unlock.** Nothing in the boot chain is modified, so nothing in
  the boot chain needs to be re-signed, re-patched, or re-verified.
- **No `dm-verity` disable.** `/system` stays exactly as shipped.
- **No data wipe.** Unlocking wipes; this does not.
- **Survives reboot by construction.** The hook is re-executed on every boot, so
  there is no patch to re-apply and no app that has to stay running.
- **Recovery is deleting one file.** Everything lives in `/data`. There is no
  half-flashed partition to un-brick.

## Compared to the usual route

|  | Unlock + patched boot | This |
|---|---|---|
| Time | 20–40 min incl. firmware download | minutes |
| Data loss | yes, unlock wipes | no |
| `boot.img` modified | yes | no |
| `dm-verity` | must disable | untouched |
| OTA | breaks | keeps working |
| After reboot | patch must persist | hook re-runs |
| Brick risk | real, on a bad slot write | near zero — remove the file |

The brick-risk row is the reason this exists. A bootloader patch that goes wrong
leaves a device that will not boot and cannot be reached. A file in `/data` that
goes wrong leaves a device that boots normally and ignores it.

## Scope

**In scope:** devices whose vendor boot stage still sources a user-writable
script. On OPPO that means ColorOS builds roughly Android 6–8. Newer ColorOS
reworked this layer; those builds are not covered.

**Out of scope, deliberately:**

- No payload, no one-liner, no copy-paste script that grants root.
- No "works on all OPPO" claim. It works where the layer exists.

The reason is not politeness. A script executed as root before zygote has **no
sandbox, no confirmation dialog, and no recovery UI**. A wrong line is a bootloop
that the user cannot see, cannot interrupt, and cannot diagnose — the screen never
lights up. Publishing a ready-to-run file for that stage means publishing a
bootloop generator for everyone who runs it on the wrong build.

So this repo ships the part that is safe to ship: **detection**, and the tooling
this project needed along the way.

## Detect

```bash
adb push tools/detect.sh /data/local/tmp/
adb shell sh /data/local/tmp/detect.sh
```

`detect.sh` is read-only. It reports device identity, whether the vendor boot
stage sources a script from a user-writable path, the permissions on that path,
and whether `dm-verity`/`ro.debuggable` would matter here. It writes nothing and
changes nothing.

If it prints `CANDIDATE: writable`, your device is in the affected class. What
you do with that is your decision, made with the risk section below in front of
you.

## What else is in here

Working tools from the same device, all independent of the root method:

| Path | What it does |
|---|---|
| `tools/detect.sh` | read-only probe for the vendor init hook |
| `tools/fiemap.c` | dump ext4 physical extents for a file — the only way to write to a read-only `/system` on a device where `mount -o rw,remount` returns `EPERM` |
| `tools/bootanim_build.py` | build a `bootanimation.zip` that lands on an **exact byte count**, for slots where the file size is fixed and an oversized archive means no boot |
| `docs/device-notes.md` | partition map, block devices, what worked and what returned `EPERM`, on CPH1801 |

The bootanimation tool is the least glamorous and most reused piece: on this
device `/system/media/bootanimation.zip` occupies a fixed 1,156,803-byte region
with no free space around it, so a custom animation has to be padded to that
number *exactly* or the device does not boot. It builds the archive, measures the
ZIP overhead, and pads to the target; if the frames do not fit, it refuses rather
than writing a truncated archive.

## Risks — read before you run anything

- **Root means losing attestation.** Banking apps, wallets, and anything using
  Play Integrity will refuse the device. That is the cost, not a bug, and no
  module fully removes it.
- **This stage runs before you can see the screen.** A mistake here is a
  bootloop with no UI. On this device that meant a full reflash twice during
  development.
- **Never run someone else's script at this layer.** No sandbox, no prompt, no
  undo. A script from a forum post at pre-zygote root is equivalent to handing
  over the device.
- **Vendor updates can remove the hook or, worse, keep it and change what runs**,
  which is how a working setup becomes a broken one after an OTA.

## Contributing

Useful issues, in order of value:

1. `detect.sh` output + device model + build number (works or not — failures are
   more useful than successes).
2. The exact point where it fails, if it fails.
3. Corrections to `docs/device-notes.md` on other models.

Not useful: "does this work on <phone>" with no output attached.

## License

MIT for the tooling. Device notes are provided as-is, with no warranty that any
procedure described is safe on your hardware.
