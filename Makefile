PREFIX = $(shell pwd)
url_buildroot = https://github.com/buildroot/buildroot.git
dir_external = $(PREFIX)
dir_buildroot = $(PREFIX)/buildroot
dir_output = $(dir_buildroot)/output
release_tag = 2020.05
out_dir = $(PREFIX)/output

bootstrap:
	mkdir -p external
	@echo "Downloading buildroot to $(PREFIX)"
	git clone --depth 10 $(url_buildroot) $(dir_buildroot)
	cd $(dir_buildroot) && git fetch --tags && git reset --hard $(release_tag)
	make BR2_EXTERNAL=$(dir_external) custom_stm32f769_defconfig -C $(dir_buildroot)
	#cp local.mk $(dir_buildroot)

menuconfig:
	make BR2_EXTERNAL=$(dir_external) custom_stm32f769_defconfig -C $(dir_buildroot) menuconfig
	make savedefconfig BR2_DEFCONFIG=$(dir_external)/configs/custom_stm32f769_defconfig -C $(dir_buildroot)

linux_menuconfig:
	make -C $(dir_buildroot) linux-menuconfig
	make linux-update-defconfig -C $(dir_buildroot)

linux_rebuild:
	make linux-reconfigure -C $(dir_buildroot)
	mkdir -p $(out_dir)
	cp $(dir_buildroot)/output/images/zImage $(out_dir)/
	cp $(dir_buildroot)/output/images/rootfs.ext2 $(out_dir)/
	cp $(dir_external)/buildroot/output/build/linux-custom/arch/arm/boot/dts/stm32f769-disco.dtb $(out_dir)/

uboot_rebuild:
	make uboot-reconfigure -C $(dir_buildroot)

build:
	make BR2_DEFCONFIG=$(dir_external)/configs/custom_stm32f769_defconfig -C $(dir_buildroot)
	cp $(dir_buildroot)/output/images/zImage $(out_dir)/
	cp $(dir_buildroot)/output/images/rootfs.ext2 $(out_dir)/
	cp $(dir_external)/buildroot/output/build/linux-custom/arch/arm/boot/dts/stm32f769-disco.dtb $(out_dir)/

save_all:
	make update-defconfig -C $(dir_buildroot)
	make linux-update-defconfig -C $(dir_buildroot)
	make busybox-update-config -C $(dir_buildroot)
	make uclibc-update-config -C $(dir_buildroot)
	make barebox-update-defconfig -C $(dir_buildroot)
	make uboot-update-defconfig -C $(dir_buildroot)

flash_bootloader:
	cd $(dir_output)/build/host-openocd-0.10.0/tcl && ../../../host/usr/bin/openocd \
		-f board/stm32f7discovery.cfg \
		-c "program ../../../images/u-boot-spl.bin 0x08000000" \
		-c "program ../../../images/u-boot.bin 0x08008000" \
		-c "reset run" -c shutdown

clean:
	rm -rf $(dir_buildroot)
