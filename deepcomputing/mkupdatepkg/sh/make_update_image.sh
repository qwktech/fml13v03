#!/bin/bash
set -e

# Path to the update directory
UPDATE_DIR="./update"
# Temporary mount directory
MOUNT_DIR="$PWD/mnt/update_img"
# Output image file name
IMG_FILE="./update_image.img"
# Extra space to add (in bytes), here we add 10MB
EXTRA_SPACE=$((10 * 1024 * 1024))

# Check if the update directory exists
if [ ! -d "$UPDATE_DIR" ]; then
    echo "Directory $UPDATE_DIR does not exist!"
    return
fi

echo "Calculating the size of the $UPDATE_DIR directory..."
# Calculate the size of the update directory (in bytes)
DIR_SIZE=$(du -sb "$UPDATE_DIR" | awk '{print $1}')
echo "Size of update directory: $DIR_SIZE bytes"

# Calculate the total size for the image: directory size plus extra space
TOTAL_SIZE=$((DIR_SIZE + EXTRA_SPACE))
echo "Total image size set to: $TOTAL_SIZE bytes (including extra space)"

# Create an empty image file with the calculated size
echo "Creating image file: $IMG_FILE"
dd if=/dev/zero of="$IMG_FILE" bs=1 count=0 seek="$TOTAL_SIZE"

# Format the image file with the ext4 filesystem
echo "Formatting the image as ext4..."
mkfs.ext4 -F "$IMG_FILE" > /dev/null

# Create the mount directory if it doesn't exist
echo "Creating mount directory: $MOUNT_DIR"
mkdir -p "$MOUNT_DIR"

# Mount the image file to the mount directory using loop device
echo "Mounting the image..."
sudo mount -o loop "$IMG_FILE" "$MOUNT_DIR"

# Copy the contents of the update directory into the mounted image
echo "Copying files from $UPDATE_DIR to the image..."
sudo cp -r "$UPDATE_DIR"/* "$MOUNT_DIR"

# Sync data to ensure all writes are completed
echo "Syncing data..."
sync

# Unmount the image
echo "Unmounting the image..."
sudo umount "$MOUNT_DIR"

echo "Image $IMG_FILE has been successfully created!"
