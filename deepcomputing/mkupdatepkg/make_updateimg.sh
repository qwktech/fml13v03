#!/bin/bash
set -e

# Configuration file containing file name prefixes (one per line)
CONFIG_FILE="config.txt"

# ANSI color codes
RED='\033[31m'
YELLOW='\033[33m'
NC='\033[0m' # Reset color

# Ensure WORK_DIR and board_name are set
if [ -z "$WORK_DIR" ] || [ -z "$board_name" ]; then
    echo -e "${RED}Error: WORK_DIR or board_name is not set!${NC}"
    echo "Please configure the environment variables WORK_DIR and board_name before running this script."
    return 1
fi

# Define directories
SOURCE_DIR="${WORK_DIR}/${board_name}/output"
UPDATE_DIR="./update"

# Check if the configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Configuration file '$CONFIG_FILE' not found!${NC}"
    return 1
fi

rm -f update_image.img
rm -rf "$UPDATE_DIR"

# Create the update directory if it doesn't exist
mkdir -p "$UPDATE_DIR"

# Read file prefixes from config.txt and copy matching files
while IFS= read -r line || [ -n "$line" ]; do
    # Ignore empty lines and comments
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    echo "Processing prefix: '$line'"

    # Find matching files
    matches=( "$SOURCE_DIR"/"$line"* )

    if [ ! -e "${matches[0]}" ]; then
        echo -e "${YELLOW}Warning: No files found with prefix '$line' in $SOURCE_DIR.${NC}"
        continue
    fi

    # Copy matching files
    for file in "${matches[@]}"; do
        [ -f "$file" ] && echo "Copying: $file -> $UPDATE_DIR/" && cp "$file" "$UPDATE_DIR/"
    done

done < "$CONFIG_FILE"

echo "All matching files have been copied to the update directory."

# Execute additional scripts
echo "Executing make_usbupdate_scr.sh"
bash "sh/make_usbupdate_scr.sh"

echo "Executing make_update_image.sh"
bash "sh/make_update_image.sh"
