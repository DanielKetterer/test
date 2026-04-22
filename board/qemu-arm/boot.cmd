# U-Boot boot script for QEMU vexpress-a9
# Compiled to boot.scr by post-image.sh via mkimage.
#
# Memory map (vexpress-a9 / Cortex-A9, 1 GB DRAM starting at 0x60000000):
#   kernel_addr_r  = 0x60100000   (zImage)
#   fdt_addr_r     = 0x68000000   (DTB)
#   ramdisk_addr_r = 0x61000000   (unused — rootfs is on SD)

echo "== Loading kernel from SD card (mmc 0, partition 1) =="
fatload mmc 0:1 ${kernel_addr_r}  zImage
fatload mmc 0:1 ${fdt_addr_r}     vexpress-v2p-ca9.dtb

setenv bootargs "console=ttyAMA0,115200 root=/dev/mmcblk0p2 rootwait rw earlycon"

echo "== Booting Linux =="
bootz ${kernel_addr_r} - ${fdt_addr_r}
