#!/system/bin/sh
# detect.sh — read-only probe for vendor init scripts sourced from /data.
#
# Writes nothing. Runs without root for the parts that allow it and degrades
# gracefully where it cannot read. Safe to run on a production device.

set -u

echo "== device =="
getprop ro.product.model
getprop ro.product.device
getprop ro.build.version.release
getprop ro.build.version.sdk
getprop ro.build.display.id

echo
echo "== boot integrity =="
# ro.boot.veritymode: enforcing = dm-verity on; anything else means it is already off
echo "veritymode : $(getprop ro.boot.veritymode)"
echo "verifiedboot: $(getprop ro.boot.verifiedbootstate)"
echo "debuggable  : $(getprop ro.debuggable)"
echo "bootloader  : $(getprop ro.bootloader)"

echo
echo "== system mount =="
mount | grep -E ' /system | /vendor ' 2>/dev/null || echo "no system/vendor mount line"

echo
echo "== vendor init rc references to /data scripts =="
# Any .rc the boot stage reads, quoting a /data path with a shell exec.
for rc in /system/etc/init/*.rc /vendor/etc/init/*.rc /system/etc/init/hw/*.rc; do
    [ -f "$rc" ] || continue
    grep -nE 'exec.*(/data/|/data )' "$rc" 2>/dev/null | sed "s|^|$(basename "$rc"): |"
done

echo
echo "== candidate scripts under /data (top 3 levels) =="
# Bounded walk: /data can be huge, never recurse without a depth limit.
find /data -maxdepth 3 -name '*.sh' -type f 2>/dev/null | while read -r f; do
    perms=$(ls -l "$f" 2>/dev/null | awk '{print $1, $3, $4}')
    echo "$f"
    echo "    $perms"
done

echo
echo "== writability of those paths =="
find /data -maxdepth 3 -name '*.sh' -type f 2>/dev/null | while read -r f; do
    if [ -w "$f" ]; then
        echo "CANDIDATE: writable   $f"
    else
        echo "candidate: read-only  $f"
    fi
done

echo
echo "== done — nothing was modified =="
