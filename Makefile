PREFIX = $(shell pwd)
url_buildroot = https://github.com/buildroot/buildroot.git
dir_external = $(PREFIX)
dir_buildroot = $(PREFIX)/buildroot
dir_output = $(dir_buildroot)/output
release_tag = 2020.05

.PHONY: bootstrap menuconfig linux_menuconfig linux_rebuild uboot_rebuild build save_all flash_bootloader clean

bootstrap:
	mkdir -p external
	@echo "Downloading buildroot to $(PREFIX)"
	git clone --depth 10 $(url_buildroot) $(dir_buildroot)
	cd $(dir_buildroot) && git fetch --tags && git reset --hard $(release_tag)

menuconfig:
	make BR2_EXTERNAL=$(dir_external) custom_stm32f769_defconfig -C $(dir_buildroot) menuconfig
	make savedefconfig BR2_DEFCONFIG=$(dir_external)/configs/custom_stm32f769_defconfig -C $(dir_buildroot)

linux_menuconfig:
	make -C $(dir_buildroot) linux-menuconfig
	make linux-update-defconfig -C $(dir_buildroot)

linux_rebuild:
	make linux-reconfigure -C $(dir_buildroot)

uboot_rebuild:
	make uboot-reconfigure -C $(dir_buildroot)

build:
ifeq ("$(wildcard $(dir_buildroot))","")
	make bootstrap
endif

	make BR2_EXTERNAL=$(dir_external) custom_stm32f769_defconfig -C $(dir_buildroot)
	make -C $(dir_buildroot)

flash_bootloader:
	$(dir_external)/host/bin/openocd \
		-f $(dir_output)/build/host-openocd-0.10.0/tcl/board/stm32f7discovery.cfg \
		-c "program $(dir_output)/images/u-boot-spl.bin 0x08000000" \
		-c "program $(dir_output)/images/u-boot.bin 0x08008000" \
		-c "reset run" -c shutdown

clean:
	rm -rf $(dir_buildroot)
