#!/usr/bin/env bash

# Install required packages if not installed
echo "Checking and installing required packages..."
apt update
apt install -y udev parted kpartx

# Read input parameters
BOARD=${board_name}
BOOT_IMG=${WORK_DIR}/${board_name}/output/boot-${board_name}.ext4
ROOTFS_IMG=${WORK_DIR}/${board_name}/output/root-${board_name}.ext4

# Check if boot and rootfs image files exist
if [ ! -f "$BOOT_IMG" ]; then
    echo "Error: Boot image '$BOOT_IMG' not found!"
    return 1
fi

if [ ! -f "$ROOTFS_IMG" ]; then
    echo "Error: RootFS image '$ROOTFS_IMG' not found!"
    return 1
fi

# Generate system image filename based on BOARD and RELEASE_TAG
IMAGE="EIC7X-${BOARD}-${RELEASE_TAG}.img"

# Fixed sizes for Boot and Swap partitions
BOOT_SIZE=512MiB
SWAP_SIZE=4G

# Dynamically calculate RootFS size based on the rootfs image size (in MB) plus a 50 MB margin
ROOT_SIZE=$(du -m "$ROOTFS_IMG" | awk '{print $1 + 50}')M

# Calculate the end of the swap partition in MiB
SWAP_END=$((${BOOT_SIZE%MiB} + ${SWAP_SIZE%G} * 1024))

# Total image size: Boot + Swap + RootFS + an extra 256M for buffer
TOTAL_SIZE=$(echo "$SWAP_END + ${ROOT_SIZE%M} + 256" | bc)M

echo "Creating minimal disk image: $IMAGE"
echo "Total size: $TOTAL_SIZE (Boot: $BOOT_SIZE, Swap: $SWAP_SIZE, RootFS: $ROOT_SIZE)"

# Create an image file with the total size
truncate -s "$TOTAL_SIZE" "$IMAGE"

BOOT_UUID=$(blkid -s UUID -o value "$BOOT_IMG")

# Create partition table using parted
parted -s "$IMAGE" mklabel gpt
parted -s "$IMAGE" mkpart boot ext4 1MiB ${BOOT_SIZE}
parted -s "$IMAGE" mkpart swap linux-swap ${BOOT_SIZE} ${SWAP_END}MiB
parted -s "$IMAGE" mkpart rootfs ext4 ${SWAP_END}MiB 100%

# Associate the image with a loop device (without --partscan)
LOOPDEV=$(losetup --find --show "$IMAGE")
echo "Using loop device: $LOOPDEV"

# Use kpartx to create partition mappings under /dev/mapper/
kpartx -av "$LOOPDEV"

# Format the partitions
mkswap /dev/mapper/$(basename "$LOOPDEV")p2
mkfs.ext4 -F /dev/mapper/$(basename "$LOOPDEV")p3

ROOTFS_UUID=$(blkid -s UUID -o value "$ROOTFS_IMG")
# 恢复 UUID
if [ -n "$ROOTFS_UUID" ]; then
    yes | tune2fs -f -U "$ROOTFS_UUID" /dev/mapper/$(basename "$LOOPDEV")p3
fi

# Get the UUID for swap partition
SWAP_UUID=$(blkid -s UUID -o value /dev/mapper/$(basename "$LOOPDEV")p2)
echo "Swap partition UUID: $SWAP_UUID"

# Get the UUID for root partition
ROOTFS_UUID=$(blkid -s UUID -o value /dev/mapper/$(basename "$LOOPDEV")p3)
echo "RootFS partition UUID: $ROOTFS_UUID"

# Mount and copy Boot data
dd if="$BOOT_IMG" of=/dev/mapper/$(basename "$LOOPDEV")p1 bs=1M status=progress

# Mount and copy RootFS data
mkdir -p /mnt/rootfs
mount /dev/mapper/$(basename "$LOOPDEV")p3 /mnt/rootfs
mkdir -p /mnt/rootfs_ext4
mount -o loop "$ROOTFS_IMG" /mnt/rootfs_ext4
echo "Copying rootfs image content into rootfs partition..."
cp -a /mnt/rootfs_ext4/. /mnt/rootfs/

FSTAB_FILE="/mnt/rootfs/etc/fstab"
#  swap
if grep -q "swap" "$FSTAB_FILE"; then
    sed -i "s|UUID=[a-f0-9-]*[[:space:]]*none[[:space:]]*swap|UUID=$SWAP_UUID none swap|" "$FSTAB_FILE"
else
    echo "UUID=$SWAP_UUID none swap sw 0 0" >> "$FSTAB_FILE"
fi

umount /mnt/rootfs_ext4
rmdir /mnt/rootfs_ext4
umount /mnt/rootfs
rmdir /mnt/rootfs

# Clean up: remove partition mappings and detach loop device
kpartx -dv "$LOOPDEV"
losetup -d "$LOOPDEV"

echo "Disk image creation complete: $IMAGE"
