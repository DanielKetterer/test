#!/usr/bin/env bash
# Download and extract Buildroot if not already present.
set -euo pipefail

VERSION="${1:-2024.02.9}"
DIR="${2:-buildroot}"

if [ -d "$DIR" ]; then
    echo "[setup] Buildroot already at ./${DIR} — skipping download."
    exit 0
fi

TARBALL="buildroot-${VERSION}.tar.gz"
URL="https://buildroot.org/downloads/${TARBALL}"

echo "[setup] Downloading Buildroot ${VERSION}…"
curl -L --retry 4 --retry-delay 2 -o "${TARBALL}" "${URL}"

echo "[setup] Extracting…"
tar xzf "${TARBALL}"
mv "buildroot-${VERSION}" "${DIR}"
rm "${TARBALL}"

echo "[setup] Buildroot ${VERSION} ready at ./${DIR}"
