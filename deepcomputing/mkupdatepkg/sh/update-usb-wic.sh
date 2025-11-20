
echo "Starting upgrade process..."

# Set the board name (this is a placeholder, which will be replaced later)
board_name=BOARD_NAME_PLACEHOLDER

# Check if upgrade_dev is set
if test -n "$upgrade_dev" && test -e "$upgrade_dev"; then
    upgrade_dev_have=1
else
    echo "Error: upgrade_dev ($upgrade_dev) does not exist."
    upgrade_dev_have=0
fi

# Loop through 3 USB ports (usb 0 to usb 2)
for usb_dev in 0 1 2; do
    echo "Scanning USB port ${usb_dev}..."

    # Reset and activate the USB device
    usb dev ${usb_dev}

    for usb_part in 0; do
        echo "Scanning partition ${usb_dev}:${usb_part}..."
        
        # 1. Burn Bootloader (die0)
        if test -e usb ${usb_dev}:${usb_part} bootloader_${board_name}_die0.bin; then
            echo "Ready to burn bootloader die0 from USB ${usb_dev}:${usb_part}"
            ext4load usb ${usb_dev}:${usb_part} 0x100000000 bootloader_${board_name}_die0.bin
            es_burn write 0x100000000 flash 0
            eraseenv
            echo "Burn bootloader die0 successfully"
        fi

        # 2. Burn Bootloader (die1)
        if test -e usb ${usb_dev}:${usb_part} bootloader_${board_name}_die1.bin; then
            echo "Ready to burn bootloader die1 from USB ${usb_dev}:${usb_part}"
            ext4load usb ${usb_dev}:${usb_part} 0x100000000 bootloader_${board_name}_die1.bin
            es_burn write 0x100000000 flash 1
            echo "Burn bootloader die1 successfully"
        fi

        # 3. Burn wic
        if test ${upgrade_dev_have:-0} -eq 1; then
            if test -e usb ${usb_dev}:${usb_part} ${board_name}.wic; then
                echo "Ready to burn ${board_name}.wic from USB ${usb_dev}:${usb_part}"
                es_fs write usb ${usb_dev}:${usb_part} ${board_name}.wic ${upgrade_dev}
                echo "Burn ${board_name}.wic successfully"
            fi
        fi
    done
done

echo "The burn script executed completely."
echo "Please remove the usb, power off, and then power on."