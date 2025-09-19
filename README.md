# V2 Flash Toolkit

A Text User Interface (TUI) tool for building, flashing, and adjusting boot images for Allwinner H700 devices like RG35XX-H.

## Features

- Kernel Build: Select and build kernels from curated repositories.
- Flash Image: Flash system images or kernels to SD cards.
- Boot.img / RootFS Adjuster: Repack boot images with new kernels and sync modules.
- Backup / Restore: Backup and restore disk images.

## Safety Notes

- **Backup First**: Always create a backup of your SD card before flashing.
- **Risk**: Flashing can erase data or brick your device. Use at your own risk.
- **Permissions**: May require root or admin privileges for disk operations.

## Quick Start

1. Clone or download the toolkit.
2. Run `./flash-toolkit.sh` in a terminal.
3. Follow the menu prompts.

## Requirements

- Bash
- Tools: git, make, pv, dd, lsblk, blkid, abootimg/mkbootimg, fzf, whiptail/gum
- For QEMU testing: qemu-system-aarch64

## Project Structure

See the docs/ folder for detailed documentation.
