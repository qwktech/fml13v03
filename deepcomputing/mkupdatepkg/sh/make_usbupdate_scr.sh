#!/usr/bin/env bash

set -e  # Exit immediately if a command exits with a non-zero status

# ANSI color codes
RED="\033[31m"
YELLOW="\033[33m"
RESET="\033[0m"

echo "Generating usbupdate.scr..."

# Create a temporary copy of update-usb-wic.sh
TEMP_UPDATE_USB="./sh/update-usb-temp.sh"
cp ./sh/update-usb-wic.sh "$TEMP_UPDATE_USB"

# Function to generate usbupdate.scr
generate_usbupdate() {
    if [ -z "$board_name" ]; then
        echo -e "${RED}Error: board_name is not set!${RESET}"
        return 1
    fi

    if [ ! -d "$WORK_DIR" ] || [ ! -f "$WORK_DIR/${board_name}/uboot-eswin/tools/mkimage" ]; then
        echo -e "${RED}Error: mkimage tool not found. Please check your WORK_DIR and board_name.${RESET}"
        return 1
    fi

    # Replace BOARD_NAME_PLACEHOLDER with the actual board_name in the temporary file
    sed -i "s/BOARD_NAME_PLACEHOLDER/$board_name/g" "$TEMP_UPDATE_USB"

    "${WORK_DIR}/${board_name}/uboot-eswin/tools/mkimage" \
        -A riscv -O linux -T script -C none \
        -a 0x90000000 -e 0x90000000 \
        -n "U-Boot Script" -d "$TEMP_UPDATE_USB" ./update/usbupdate.scr

    echo "usbupdate.scr generated successfully."
}

# Execute the function and handle errors
generate_usbupdate || echo -e "${RED}Failed to generate usbupdate.scr${RESET}"

# Remove the temporary file
rm -f "$TEMP_UPDATE_USB"
