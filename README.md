# Buildroot ARM QEMU — vexpress-a9

A minimal, from-scratch Buildroot image that boots on a QEMU ARM Cortex-A9
(Versatile Express) target via U-Boot. Structured as a
[`BR2_EXTERNAL`](https://buildroot.org/downloads/manual/manual.html#outside-br-custom)
tree, so the vendored Buildroot source stays pristine and upgradable.

Built as a weekend refresher that puts **cross-compilation, the Linux kernel,
the device tree, U-Boot, and the root-filesystem image layout** all in one
reproducible exercise.

---

## Table of contents

- [What you get](#what-you-get)
- [Prerequisites](#prerequisites)
- [Quick start](#quick-start)
- [How it fits together](#how-it-fits-together)
- [Boot flow](#boot-flow)
- [Repository layout](#repository-layout)
- [Makefile targets](#makefile-targets)
- [Running QEMU](#running-qemu)
- [Customizing the build](#customizing-the-build)
- [Kernel & U-Boot development workflow](#kernel--u-boot-development-workflow)
- [Debugging with GDB](#debugging-with-gdb)
- [Troubleshooting](#troubleshooting)
- [References](#references)

---

## What you get

| Component       | Version         | Notes                                                |
| --------------- | --------------- | ---------------------------------------------------- |
| Buildroot       | 2024.02.9 (LTS) | Downloaded on first run by `scripts/setup.sh`        |
| Linux kernel    | 6.6.28 (LTS)    | `vexpress_defconfig` + fragment in `board/qemu-arm/` |
| U-Boot          | 2024.01         | `vexpress_ca9x4` board defconfig                     |
| C library       | glibc           | Internal Buildroot toolchain (no host toolchain)     |
| Init / shell    | BusyBox         | Plus dropbear (SSH), strace, gdb, htop, devmem2      |
| Root filesystem | ext4, 256 MB    | Partition 2 of the SD card image                     |
| Boot partition  | FAT32, 32 MB    | Holds `zImage`, `vexpress-v2p-ca9.dtb`, `boot.scr`   |

---

## Prerequisites

### Linux host (tested on Debian / Ubuntu)

```bash
sudo apt update
sudo apt install -y \
    build-essential git wget cpio unzip rsync bc \
    file python3 libncurses-dev \
    qemu-system-arm
```

Fedora / RHEL:

```bash
sudo dnf install -y \
    @development-tools git wget cpio unzip rsync bc \
    file python3 ncurses-devel \
    qemu-system-arm
```

### macOS

Buildroot does not support building on macOS. Use a Linux VM (UTM, Lima,
OrbStack) or a container. QEMU itself runs fine natively if you want to
transfer `output/images/` out of the VM and run it on the host.

### Disk & time budget

| Resource         | Needed                                     |
| ---------------- | ------------------------------------------ |
| Disk             | ~6 GB for `buildroot/` + `output/`         |
| First build time | 30–60 min on a modern laptop (network IO)  |
| Subsequent       | Seconds to minutes depending on the change |

---

## Quick start

```bash
# 1. Clone and enter
git clone https://github.com/danielketterer/test.git
cd test

# 2. Download Buildroot, configure, and build (grab a coffee on first run)
make all

# 3. Boot via U-Boot → kernel → userspace
make run
```

You'll see U-Boot banner → `fatload` of zImage/DTB → kernel messages →
BusyBox login:

```
buildroot-arm login: root
# uname -a
Linux buildroot-arm 6.6.28 #1 SMP ... armv7l GNU/Linux
```

Exit QEMU with `Ctrl-A` then `X`.

SSH from the host while QEMU is running:

```bash
ssh -p 2222 root@localhost
```

---

## How it fits together

```
┌──────────────────────────────────────────────────────────────────┐
│  Your working tree (BR2_EXTERNAL)                                │
│                                                                  │
│  configs/qemu_arm_vexpress_defconfig   ← single source of truth  │
│  board/qemu-arm/                                                 │
│    ├── linux.config       (kernel fragment)                      │
│    ├── boot.cmd           (U-Boot script source)                 │
│    ├── genimage.cfg       (SD card partition map)                │
│    └── post-{build,image}.sh                                     │
└───────────────────────────┬──────────────────────────────────────┘
                            │ BR2_EXTERNAL=$(pwd)
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│  Vendored Buildroot 2024.02.9 (downloaded, never edited)         │
│                                                                  │
│  Fetches, patches, builds:                                       │
│    • cross-toolchain (gcc, binutils, glibc)                      │
│    • Linux 6.6.28    → zImage + DTB                              │
│    • U-Boot 2024.01  → u-boot.bin                                │
│    • BusyBox rootfs  → rootfs.ext4                               │
│  Then runs post-image.sh:                                        │
│    mkimage boot.cmd → boot.scr                                   │
│    genimage         → sdcard.img                                 │
└──────────────────────────────────────────────────────────────────┘
```

Buildroot never touches your tree; your tree only injects its defconfig
and hook scripts into Buildroot's build. Upgrade Buildroot by bumping
`BUILDROOT_VERSION` in the Makefile and re-running `make setup`.

---

## Boot flow

```
 QEMU                                         Linux
  │  -kernel u-boot.bin
  ▼
 U-Boot 2024.01  (loaded at 0x60000000)
  │
  │  autoboot runs env var bootcmd, which loads /boot/boot.scr
  │  from SD card FAT partition (fatload mmc 0:1 … boot.scr)
  ▼
 boot.scr  (compiled from board/qemu-arm/boot.cmd)
  │  fatload mmc 0:1 0x60100000 zImage
  │  fatload mmc 0:1 0x68000000 vexpress-v2p-ca9.dtb
  │  setenv bootargs "console=ttyAMA0,115200 root=/dev/mmcblk0p2 rootwait rw"
  │  bootz 0x60100000 - 0x68000000
  ▼
 Linux 6.6.28 (zImage self-decompresses, parses DTB)
  │  mounts /dev/mmcblk0p2 (ext4) as /
  ▼
 BusyBox init → getty on ttyAMA0 → login prompt
```

---

## Repository layout

```
.
├── Makefile                              # Top-level wrapper (see targets below)
├── Config.in                             # BR2_EXTERNAL — intentionally empty
├── external.mk                           # BR2_EXTERNAL — intentionally empty
├── configs/
│   └── qemu_arm_vexpress_defconfig       # The one defconfig that drives everything
├── board/qemu-arm/
│   ├── linux.config                      # Kernel fragment (merged with vexpress_defconfig)
│   ├── boot.cmd                          # U-Boot script source
│   ├── genimage.cfg                      # SD card partition layout
│   ├── post-build.sh                     # Runs after rootfs staging
│   └── post-image.sh                     # Runs after image creation
└── scripts/
    ├── setup.sh                          # Downloads + extracts Buildroot
    └── run-qemu.sh                       # Launches QEMU (U-Boot or --direct)
```

After the first build you'll also have:

```
buildroot/                                # Vendored Buildroot source (don't edit)
output/                                   # All build artifacts
├── build/                                # Per-package build trees
├── host/                                  # Host tools (cross-gcc, mkimage, genimage…)
├── images/                               # ★ Final artifacts
│   ├── zImage                            # Compressed kernel
│   ├── vexpress-v2p-ca9.dtb              # Device tree blob
│   ├── rootfs.ext4                       # 256 MB root filesystem
│   ├── u-boot.bin                        # U-Boot binary
│   ├── boot.scr                          # Compiled U-Boot script
│   ├── boot.vfat                         # FAT32 boot partition image
│   └── sdcard.img                        # ★ Final MBR-partitioned SD image
├── staging/                              # Target sysroot (for cross-compiling externally)
└── target/                               # Staged rootfs before image creation
```

---

## Makefile targets

| Target                 | What it does                                               |
| ---------------------- | ---------------------------------------------------------- |
| `make setup`           | Downloads Buildroot if not present                         |
| `make defconfig`       | Applies `qemu_arm_vexpress_defconfig` to `output/`         |
| `make build`           | Full build (kernel + U-Boot + rootfs + SD image)           |
| `make all`             | `setup` → `defconfig` → `build`                            |
| `make run`             | Boot via U-Boot (default, most realistic)                  |
| `make run-direct`      | Boot zImage directly (skip U-Boot, handy for quick cycles) |
| `make menuconfig`      | Edit the Buildroot config interactively                    |
| `make linux-menuconfig`| Edit the kernel config interactively                       |
| `make uboot-menuconfig`| Edit the U-Boot config interactively                       |
| `make savedefconfig`   | Write current Buildroot config back to `configs/…`         |
| `make clean`           | Remove `output/` (keeps downloaded Buildroot tarball)      |
| `make distclean`       | Remove `output/` and `buildroot/`                          |

---

## Running QEMU

### Default: boot through U-Boot

```bash
make run
```

Equivalent to:

```bash
qemu-system-arm -M vexpress-a9 -cpu cortex-a9 -m 512M \
    -kernel output/images/u-boot.bin \
    -sd     output/images/sdcard.img \
    -serial stdio -display none \
    -net nic,model=lan9118 -net user,hostfwd=tcp::2222-:22
```

To drop into the U-Boot shell, hit any key within the autoboot countdown.
From there you can:

```
=> printenv                         # inspect env
=> mmc list                         # see the SD card
=> fatls mmc 0:1                    # list boot files
=> help bootz                       # per-command help
```

### Fast path: skip U-Boot

```bash
make run-direct
```

QEMU's `-kernel` flag accepts a zImage directly, stamps a minimal ATAG/DTB
setup, and jumps to it. Use this when you're iterating on userspace and
don't care about the bootloader path.

### Networking

User-mode SLIRP, with SSH forwarded:

```bash
ssh -p 2222 root@localhost          # dropbear is installed
scp -P 2222 foo.bin root@localhost:/tmp/
```

For ping/ICMP from the guest, user-mode networking blocks it by default —
use `curl https://...` instead to verify egress.

---

## Customizing the build

### Adding a package

```bash
make menuconfig
# Target packages → pick one → exit + save
make savedefconfig                   # persist to configs/qemu_arm_vexpress_defconfig
make build                           # rebuild
```

### Changing kernel options

Add to `board/qemu-arm/linux.config`, or:

```bash
make linux-menuconfig
# edit, exit, save
# then to persist: copy output/build/linux-*/.config into your fragment
```

Buildroot **merges** your fragment with `vexpress_defconfig` — you only
need to list overrides and additions, not the full config.

### Changing U-Boot options

```bash
make uboot-menuconfig
```

For durable changes, copy `output/build/uboot-*/.config` into a fragment
and point `BR2_TARGET_UBOOT_CONFIG_FRAGMENT_FILES` at it.

### Changing the boot arguments

Edit `board/qemu-arm/boot.cmd` and `make build`. The `post-image.sh` hook
re-runs `mkimage` and regenerates `boot.scr` inside `sdcard.img`.

### Growing the root filesystem

```
# in configs/qemu_arm_vexpress_defconfig
BR2_TARGET_ROOTFS_EXT2_SIZE="512M"
```

And in `board/qemu-arm/genimage.cfg`, bump the rootfs partition if you've
changed the file size — genimage will complain if it doesn't fit.

---

## Kernel & U-Boot development workflow

The fastest inner loop for poking at the kernel:

```bash
# First time only — cache kernel sources
make build

# Edit files in output/build/linux-6.6.28/ directly, then:
make -C buildroot O=$(pwd)/output linux-rebuild linux-reinstall
make run-direct
```

Same pattern for U-Boot:

```bash
make -C buildroot O=$(pwd)/output uboot-rebuild uboot-reinstall
make run
```

When you're happy with the change, either:

- Commit a patch under a new `board/qemu-arm/linux-patches/` dir and point
  `BR2_LINUX_KERNEL_PATCH` at it, **or**
- For one-off experiments, just keep working in `output/build/…` —
  Buildroot will re-extract on `distclean`.

---

## Debugging with GDB

### Kernel-level

```bash
# Terminal 1: QEMU with a GDB stub on :1234, halted at entry
qemu-system-arm -M vexpress-a9 -cpu cortex-a9 -m 512M \
    -kernel output/images/u-boot.bin -sd output/images/sdcard.img \
    -serial stdio -display none -s -S

# Terminal 2: cross-GDB
output/host/bin/arm-buildroot-linux-gnueabihf-gdb \
    output/build/linux-6.6.28/vmlinux
(gdb) target remote :1234
(gdb) hbreak start_kernel
(gdb) continue
```

### Userspace (via gdbserver in the guest)

`gdbserver` is included in the image.

```bash
# In guest
gdbserver :2345 /bin/myapp

# On host
output/host/bin/arm-buildroot-linux-gnueabihf-gdb ./myapp
(gdb) target remote localhost:2345   # assumes you also forwarded :2345
```

To forward 2345, edit `scripts/run-qemu.sh` and add another `hostfwd=`
clause.

---

## Troubleshooting

### `make all` fails with "unable to download …"

Buildroot fetches sources over the network on first build. Re-run
`make build` — individual downloads are resumable. Set a mirror if you're
behind a proxy:

```bash
make build BR2_PRIMARY_SITE=https://your-mirror/buildroot
```

### Kernel panics with "VFS: Unable to mount root fs"

Most commonly:
- The `sdcard.img` rebuild failed silently — check `post-image.sh` output
- Wrong `root=` in `boot.cmd` — for U-Boot mode it's `/dev/mmcblk0p2`,
  for `--direct` mode it's `/dev/mmcblk0` (no partition table there)

### U-Boot autoboot doesn't find `boot.scr`

Hit a key to interrupt autoboot and inspect:

```
=> fatls mmc 0:1
```

If `boot.scr` is missing, `post-image.sh` didn't run — check the build
log for `mkimage` errors.

### "qemu-system-arm: command not found"

Install your distro's `qemu-system-arm` package (see [prerequisites](#prerequisites)).

### Build is slow

Buildroot parallelizes automatically via `$(nproc)`. If you're on a
laptop and want to keep it responsive, cap it:

```bash
make build BR2_JLEVEL=4
```

### "make: *** No rule to make target 'linux-rebuild'"

You ran `make linux-rebuild` from the project root instead of `buildroot/`.
Use the form in the [workflow section](#kernel--u-boot-development-workflow):

```bash
make -C buildroot O=$(pwd)/output linux-rebuild
```

---

## References

- **Buildroot manual** — <https://buildroot.org/downloads/manual/manual.html>
- **Linux vexpress DT binding** — `Documentation/devicetree/bindings/arm/vexpress.yaml`
- **QEMU vexpress-a9 machine** — `qemu-system-arm -M vexpress-a9 -machine help`
- **U-Boot vexpress board** — `buildroot/board/qemu/arm-vexpress/` (Buildroot's own reference)
- **Cortex-A9 TRM** — <https://developer.arm.com/documentation/100511/latest/>
