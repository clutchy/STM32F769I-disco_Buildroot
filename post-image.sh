#!/bin/bash
# Format the SD card if necessary and create FAT32 as the first partition and EXT2 as the second one
# Deploy the kernel image and device tree to the first SD card partition
# Deploy the file system to the second SD card partition

set -e

if [ $# -ne 1 ]
  then
    echo "Please provide device name as the first argument. Example: sdc"
    exit 1
fi

DEV=$1
DEV_PATH="/dev/$DEV"

MOUNT_PATH1="/mnt/stmmount1"

umount_device () {
    DEVICE=$1

    if mount | grep -q "${DEV_PATH}1"; then
        MOUNT=$(mount | grep "${DEV_PATH}1" | awk '{print $3}')
        umount $MOUNT || true
    fi
}

umount_device "${DEV_PATH}1"
umount_device "${DEV_PATH}2"

if ! $(cat /proc/partitions | grep -qe "${DEV}$"); then
    echo "Device ${DEV_PATH} does not exist"
    exit 1
fi

if [ $(fsck -N "${DEV_PATH}1" | tail -n 1 | awk '{print $5}' | awk -F'.' '{print $2}') != "vfat" ] || \
    [ $(fsck -N "${DEV_PATH}2" | tail -n 1 | awk '{print $5}' | awk -F'.' '{print $2}') != "ext2" ]; then
    read -p "Warning: double check if the provided device is correct. The provided device $DEV_PATH will be formated! " -n 1 -r
    echo
    if [[ $REPLY =~ ^[^Yy]$ ]]; then
        exit 0
    fi

    # Check that the device is smaller than 16GB for safety
    if [ $(cat /proc/partitions | grep -e "${DEV}$" | awk '{print $3}') -gt "16000000" ]; then
        echo "The device $DEV_PATH is larger than 16GB! Exiting..."
        exit 1
    fi

    echo "Formating $DEV_PATH"
    dd if=/dev/zero of=$DEV_PATH bs=512 count=1 status=progress

    echo "Creating new partitions"
    parted "${DEV_PATH}" --script -- mklabel msdos
    parted "${DEV_PATH}" --script -- mkpart primary fat32 1MiB 100MiB
    parted "${DEV_PATH}" --script -- mkpart primary ext2 100MiB 100%

    sync

    while [ ! -e "${DEV_PATH}1" ]; do sleep 1; done
    while [ ! -e "${DEV_PATH}2" ]; do sleep 1; done
    mkfs.vfat -F32 "${DEV_PATH}1"
    mkfs.ext2 -F "${DEV_PATH}2"
fi

echo "Mounting FAT partition"
mkdir -p "$MOUNT_PATH1"
umount "$MOUNT_PATH1" 2>/dev/null || true
mount "${DEV_PATH}1" "$MOUNT_PATH1"

echo "Copying files to FAT partition"
mkdir -p "$MOUNT_PATH1/stm32f769/"
cp buildroot/output/build/linux-custom/arch/arm/boot/dts/stm32f769-disco.dtb "$MOUNT_PATH1/stm32f769/"
cp buildroot/output/images/zImage "$MOUNT_PATH1/stm32f769/"

echo "Copying rootfs to ext2 partition"
dd if=buildroot/output/images/rootfs.ext2 of="${DEV_PATH}2" status=progress

umount "$MOUNT_PATH1"
sync

echo "SD card was successfully flashed and can be safely removed"
