#!/bin/bash

# V2 Flash Toolkit - Main entrypoint

set -euo pipefail

# Load base functions
source lib/base.sh

# Main menu
main() {
    while true; do
        echo "V2 Flash Toolkit"
        echo "1. Kernel Build"
        echo "2. Flash Image"
        echo "3. Boot.img / RootFS Adjuster"
        echo "4. Backup / Restore"
        echo "5. Exit"
        read -p "Choose: " choice
        case $choice in
            1) source wizards/kernel_build.sh ;;
            2) source wizards/flash.sh ;;
            3) source wizards/bootimg_adjust.sh ;;
            4) source wizards/backup_restore.sh ;;
            5) exit 0 ;;
        esac
    done
}

main "$@"
