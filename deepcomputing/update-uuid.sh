#!/bin/bash

IMAGE=$1
if [ -z "$IMAGE" ]; then
    echo "Usage: $0 <image_file>"
    echo "Error: No image file provided."
    return 1
fi

if [ ! -f "$IMAGE" ]; then
    echo "Error: Image file '$IMAGE' not found!"
    return 1
fi

LOOPDEV=$(sudo losetup --find --show --partscan "$IMAGE")
if [ $? -ne 0 ]; then
    echo "Error: Failed to set up loop device."
    return 1
fi
echo "Loop device: $LOOPDEV"

# 解析 rootfs、boot 和 swap 分区号
ROOTFS_PART_NUM=$(sudo parted -m "$LOOPDEV" print | awk -F: '$6 == "rootfs" {print $1}')
BOOT_PART_NUM=$(sudo parted -m "$LOOPDEV" print | awk -F: '$6 == "boot" {print $1}')
SWAP_PART_NUM=$(sudo parted -m "$LOOPDEV" print | awk -F: '$6 == "swap" {print $1}')

if [ -z "$ROOTFS_PART_NUM" ]; then
    echo "Error: Could not find rootfs partition."
    sudo losetup -d "$LOOPDEV"
    return 1
fi
if [ -z "$BOOT_PART_NUM" ]; then
    echo "Error: Could not find boot partition."
    sudo losetup -d "$LOOPDEV"
    return 1
fi

ROOTFS_PARTITION="${LOOPDEV}p${ROOTFS_PART_NUM}"
BOOT_PARTITION="${LOOPDEV}p${BOOT_PART_NUM}"
echo "Found rootfs partition: $ROOTFS_PARTITION"
echo "Found boot partition: $BOOT_PARTITION"

ROOTFS_MOUNT_DIR=$(mktemp -d)
BOOT_MOUNT_DIR=$(mktemp -d)

# ---- 更新 rootfs UUID ----
echo "Running e2fsck on rootfs partition..."
sudo e2fsck -y -f "$ROOTFS_PARTITION"
if [ $? -ne 0 ]; then
    echo "Error: e2fsck failed on $ROOTFS_PARTITION"
    sudo losetup -d "$LOOPDEV"
    return 1
fi

echo "Changing UUID of rootfs..."
NEW_ROOTFS_UUID=$(uuidgen)
yes | sudo tune2fs "$ROOTFS_PARTITION" -U "$NEW_ROOTFS_UUID"
echo "New rootfs UUID: $NEW_ROOTFS_UUID"

# ---- 更新 swap UUID（如果存在）----
if [ -n "$SWAP_PART_NUM" ]; then
    SWAP_PARTITION="${LOOPDEV}p${SWAP_PART_NUM}"
    echo "Found swap partition: $SWAP_PARTITION"
    NEW_SWAP_UUID=$(uuidgen)
    sudo mkswap -U "$NEW_SWAP_UUID" "$SWAP_PARTITION"
    echo "New swap UUID: $NEW_SWAP_UUID"
fi

# ---- 更新 boot UUID ----
BOOT_TYPE=$(sudo blkid -o value -s TYPE "$BOOT_PARTITION")
if [ "$BOOT_TYPE" == "ext4" ]; then
    echo "Running e2fsck on boot partition..."
    sudo e2fsck -y -f "$BOOT_PARTITION"
    if [ $? -ne 0 ]; then
        echo "Error: e2fsck failed on boot partition, skipping UUID change."
    else
        echo "Changing UUID of boot partition..."
        NEW_BOOT_UUID=$(uuidgen)
        yes | sudo tune2fs "$BOOT_PARTITION" -U "$NEW_BOOT_UUID"
        echo "New boot UUID: $NEW_BOOT_UUID"
    fi
elif [ "$BOOT_TYPE" == "vfat" ]; then
    NEW_BOOT_LABEL="BOOT_$(uuidgen | cut -c1-4)"
    echo "Changing LABEL of boot partition to $NEW_BOOT_LABEL..."
    sudo dosfslabel "$BOOT_PARTITION" "$NEW_BOOT_LABEL"
    echo "New boot LABEL: $NEW_BOOT_LABEL"
else
    echo "Warning: Boot partition type ($BOOT_TYPE) is not supported for UUID change."
    NEW_BOOT_UUID=""
fi

# ---- 更新 /etc/fstab ----
echo "Mounting rootfs partition ($ROOTFS_PARTITION)..."
sudo mount "$ROOTFS_PARTITION" "$ROOTFS_MOUNT_DIR"
if [ $? -eq 0 ]; then
    FSTAB="$ROOTFS_MOUNT_DIR/etc/fstab"
    if [ -f "$FSTAB" ]; then
        echo "Updating /etc/fstab..."
        sudo sed -i "s|UUID=[a-f0-9-]\{36\}|UUID=$NEW_ROOTFS_UUID|g" "$FSTAB"
        if [ -n "$NEW_SWAP_UUID" ]; then
            sudo sed -i "s|UUID=[a-f0-9-]\{36\}.*swap|UUID=$NEW_SWAP_UUID swap|g" "$FSTAB"
        fi
        if [ -n "$NEW_BOOT_UUID" ]; then
            sudo sed -i "s|UUID=[a-f0-9-]\{36\}.*boot|UUID=$NEW_BOOT_UUID boot|g" "$FSTAB"
        fi
    fi
    sudo umount "$ROOTFS_MOUNT_DIR"
else
    echo "Error: Failed to mount rootfs partition."
fi
rmdir "$ROOTFS_MOUNT_DIR"

# ---- 更新 boot 分区的 extlinux.conf ----
echo "Mounting boot partition ($BOOT_PARTITION)..."
sudo mount "$BOOT_PARTITION" "$BOOT_MOUNT_DIR"
if [ $? -eq 0 ]; then
    EXTLINUX_CONF="$BOOT_MOUNT_DIR/extlinux/extlinux.conf"
    if [ -f "$EXTLINUX_CONF" ]; then
        echo "Updating extlinux.conf..."
        sudo sed -i "s|root=UUID=[a-f0-9-]\{36\}|root=UUID=$NEW_ROOTFS_UUID|g" "$EXTLINUX_CONF"
    else
        echo "Warning: extlinux.conf not found in boot partition!"
    fi
    sudo umount "$BOOT_MOUNT_DIR"
else
    echo "Error: Failed to mount boot partition."
fi
rmdir "$BOOT_MOUNT_DIR"

# 释放 loop 设备
if ! sudo losetup -d "$LOOPDEV"; then
    echo "Warning: Failed to detach loop device $LOOPDEV"
fi

echo "Done."
