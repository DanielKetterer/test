BUILDROOT_VERSION ?= 2024.02.9
BUILDROOT_DIR    ?= buildroot
OUTPUT_DIR       ?= $(CURDIR)/output
BR2_EXTERNAL     := $(CURDIR)

# Passed through to genimage / post-image scripts
export BR2_EXTERNAL OUTPUT_DIR

.PHONY: setup defconfig build run menuconfig linux-menuconfig uboot-menuconfig clean distclean

setup:
	@scripts/setup.sh $(BUILDROOT_VERSION) $(BUILDROOT_DIR)

defconfig: setup
	$(MAKE) -C $(BUILDROOT_DIR) O=$(OUTPUT_DIR) \
		BR2_EXTERNAL=$(BR2_EXTERNAL) \
		qemu_arm_vexpress_defconfig

build: setup
	$(MAKE) -C $(BUILDROOT_DIR) O=$(OUTPUT_DIR) \
		BR2_EXTERNAL=$(BR2_EXTERNAL)

# Shortcut: configure then build in one shot
all: defconfig build

run:
	@scripts/run-qemu.sh

run-direct:
	@scripts/run-qemu.sh --direct

menuconfig: setup
	$(MAKE) -C $(BUILDROOT_DIR) O=$(OUTPUT_DIR) \
		BR2_EXTERNAL=$(BR2_EXTERNAL) \
		menuconfig

linux-menuconfig: setup
	$(MAKE) -C $(BUILDROOT_DIR) O=$(OUTPUT_DIR) \
		BR2_EXTERNAL=$(BR2_EXTERNAL) \
		linux-menuconfig

uboot-menuconfig: setup
	$(MAKE) -C $(BUILDROOT_DIR) O=$(OUTPUT_DIR) \
		BR2_EXTERNAL=$(BR2_EXTERNAL) \
		uboot-menuconfig

# Save current config back to configs/
savedefconfig: setup
	$(MAKE) -C $(BUILDROOT_DIR) O=$(OUTPUT_DIR) \
		BR2_EXTERNAL=$(BR2_EXTERNAL) \
		BR2_DEFCONFIG=$(BR2_EXTERNAL)/configs/qemu_arm_vexpress_defconfig \
		savedefconfig

clean:
	rm -rf $(OUTPUT_DIR)

distclean: clean
	rm -rf $(BUILDROOT_DIR)
