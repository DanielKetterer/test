#!/usr/bin/env bash
# Runs after all filesystem images are created.
# Compiles the U-Boot boot script and assembles the final SD card image.
#
# Buildroot environment variables available here:
#   BINARIES_DIR  — output/images/
#   BUILD_DIR     — output/build/
#   HOST_DIR      — output/host/  (cross tools, mkimage, genimage, …)
#   TARGET_DIR    — staged rootfs
#   BR2_EXTERNAL_DIRS — path to this external tree
set -euo pipefail

BOARD_DIR="$(realpath "$(dirname "$0")")"
GENIMAGE_CFG="${1:-${BOARD_DIR}/genimage.cfg}"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"
MKIMAGE="${HOST_DIR}/bin/mkimage"

# ── 1. Compile boot.cmd → boot.scr ─────────────────────────────────────────
echo "[post-image] Compiling U-Boot boot script…"
"${MKIMAGE}" -C none -A arm -T script \
    -d "${BOARD_DIR}/boot.cmd" \
    "${BINARIES_DIR}/boot.scr"

# ── 2. Assemble SD card image via genimage ──────────────────────────────────
echo "[post-image] Running genimage (layout: ${GENIMAGE_CFG})…"
rm -rf "${GENIMAGE_TMP}"

"${HOST_DIR}/bin/genimage" \
    --rootpath "${TARGET_DIR}" \
    --tmppath  "${GENIMAGE_TMP}" \
    --inputpath  "${BINARIES_DIR}" \
    --outputpath "${BINARIES_DIR}" \
    --config "${GENIMAGE_CFG}"

echo "[post-image] SD card image: ${BINARIES_DIR}/sdcard.img"
ls -lh "${BINARIES_DIR}/sdcard.img" "${BINARIES_DIR}/u-boot.bin"
