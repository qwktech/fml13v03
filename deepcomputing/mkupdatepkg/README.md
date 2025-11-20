# make_updateimg.sh Readme

This document provides a step-by-step guide for executing the `make_updateimg.sh` script to create the final update image.

## Overview

The `make_updateimg.sh` script performs the following tasks:

1. **Generate usbupdate.scr**  
   It creates `usbupdate.scr` from `update-usb.sh`.

2. **Copy ext4 Files**  
   Based on the configuration specified in `config.txt`, it copies the corresponding ext4 files into the `update` directory.

3. **Generate Final Image**  
   It executes a shell script that generates the final update image.

## Prerequisites

- Ensure you have a working Linux environment.
- Required tools: `bash`, `mkfs.ext4`, `dd`, and standard Unix utilities.
- Confirm that `update-usb.sh`, `config.txt`, and all required ext4 files are present in the working directory.

## Steps

1. **Generate update.scr**  
   The script will convert the `update-usb.sh` file into a script file named `update.scr`.

2. **Copy ext4 Files to update Directory**  
   The script reads `config.txt` to determine which ext4 files should be copied into the `update` directory. Make sure that `config.txt` is correctly configured and that the ext4 files exist.

3. **Execute the Update Image Script**  
   Finally, the script runs the shell commands to generate the final update image. This image includes the boot files and root filesystem as specified.

## Usage

Simply run the following command in your terminal:

```bash
sh make_updateimg.sh
