#!/usr/bin/env bash
# Launch QEMU with the built vexpress-a9 image.
#
# Default mode  : U-Boot boot  (-kernel u-boot.bin  -sd sdcard.img)
# --direct mode : bare kernel  (-kernel zImage  -dtb …  -drive rootfs.ext4)
#
# In both modes:
#   Serial console → your terminal (stdio)
#   SSH            → localhost:2222  (ssh root@localhost -p 2222)
#   Exit QEMU      → Ctrl-A  then  X
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGES="${ROOT_DIR}/output/images"

DIRECT=0
for arg in "$@"; do
    case "$arg" in
        --direct) DIRECT=1 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

if [ "$DIRECT" -eq 1 ]; then
    # ── Direct kernel boot (no U-Boot) ──────────────────────────────────────
    KERNEL="${IMAGES}/zImage"
    DTB="${IMAGES}/vexpress-v2p-ca9.dtb"
    ROOTFS="${IMAGES}/rootfs.ext4"

    for f in "$KERNEL" "$DTB" "$ROOTFS"; do
        [[ -f "$f" ]] || { echo "Missing: $f — run 'make build' first." >&2; exit 1; }
    done

    echo "==> Direct kernel boot (no U-Boot)"
    echo "    Login : root (no password)"
    echo "    SSH   : ssh root@localhost -p 2222"
    echo "    Exit  : Ctrl-A X"
    echo ""

    exec qemu-system-arm \
        -M vexpress-a9 \
        -cpu cortex-a9 \
        -smp 1 \
        -m 512M \
        -kernel "$KERNEL" \
        -dtb    "$DTB" \
        -drive  "file=${ROOTFS},if=sd,format=raw" \
        -append "console=ttyAMA0,115200 root=/dev/mmcblk0 rootwait rw earlycon" \
        -serial stdio \
        -display none \
        -net nic,model=lan9118 \
        -net user,hostfwd=tcp::2222-:22
else
    # ── U-Boot boot (default) ────────────────────────────────────────────────
    UBOOT="${IMAGES}/u-boot.bin"
    SDCARD="${IMAGES}/sdcard.img"

    for f in "$UBOOT" "$SDCARD"; do
        [[ -f "$f" ]] || { echo "Missing: $f — run 'make build' first." >&2; exit 1; }
    done

    echo "==> U-Boot boot from SD card image"
    echo "    Login : root (no password)"
    echo "    SSH   : ssh root@localhost -p 2222"
    echo "    Exit  : Ctrl-A X"
    echo ""

    exec qemu-system-arm \
        -M vexpress-a9 \
        -cpu cortex-a9 \
        -smp 1 \
        -m 512M \
        -kernel "$UBOOT" \
        -sd     "$SDCARD" \
        -serial stdio \
        -display none \
        -net nic,model=lan9118 \
        -net user,hostfwd=tcp::2222-:22
fi
