#!/usr/bin/env bash
# Runs after the root filesystem is assembled, before the image is made.
# TARGET_DIR  = staged rootfs
# BUILD_DIR   = Buildroot's build/ directory
# HOST_DIR    = Buildroot's host/ directory (cross tools live here)
set -euo pipefail

# Ensure ttyAMA0 is listed in /etc/securetty so root can log in on the serial port.
SECURETTY="${TARGET_DIR}/etc/securetty"
if [ -f "$SECURETTY" ] && ! grep -q "^ttyAMA0$" "$SECURETTY"; then
    echo "ttyAMA0" >> "$SECURETTY"
fi

# Drop a banner so it's obvious this is our custom image.
cat > "${TARGET_DIR}/etc/issue" <<'EOF'
  ____        _ _     _                 _      _    ____  __  __
 | __ ) _   _(_) | __| |_ __ ___   ___| |_   / \  |  _ \|  \/  |
 |  _ \| | | | | |/ _` | '__/ _ \ / _ \ __| / _ \ | |_) | |\/| |
 | |_) | |_| | | | (_| | | | (_) |  __/ |_ / ___ \|  _ <| |  | |
 |____/ \__,_|_|_|\__,_|_|  \___/ \___|\__/_/   \_\_| \_\_|  |_|

 QEMU vexpress-a9  |  Buildroot  |  Login: root (no password)

EOF
