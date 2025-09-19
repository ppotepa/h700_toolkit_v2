#!/bin/bash
# wizards/bootimg_adjust.sh - Boot.img / RootFS Adjuster Wizard Orchestrator
# This script coordinates the boot image adjustment process through multiple steps
# Each step is implemented as a separate file in the bootimg_adjust/ directory

# Source required libraries
source "$TOOLKIT_ROOT/lib/base.sh"
source "$TOOLKIT_ROOT/lib/ui.sh"
source "$TOOLKIT_ROOT/lib/config.sh"
source "$TOOLKIT_ROOT/mocks/data.sh"
source "$TOOLKIT_ROOT/mocks/fs.sh"
source "$TOOLKIT_ROOT/mocks/progress.sh"

# Wizard-specific variables
WIZARD_NAME="bootimg_adjust"
WIZARD_TITLE="Boot.img / RootFS Adjuster"

# bootimg_adjust_1_0__choose_base_bootimg
# Step 1-0: Choose base (stock) boot image
bootimg_adjust_1_0__choose_base_bootimg() {
    log "Starting step 1-0: Choose base boot image" "INFO"

    local choice
    choice=$(ui_menu "Choose Base Boot Image" \
        "Extract from device partition now" \
        "Browse for existing boot.img file")

    case "$choice" in
        "CANCEL")
            return 1
            ;;
        "Extract from device partition now")
            # Get device selection
            local device_choice
            device_choice=$(ui_menu "Select Device" "/dev/sdb4" "/dev/mmcblk0p4")
            if [[ "$device_choice" == "CANCEL" ]]; then
                return 1
            fi

            CTX[boot_source]="extract"
            CTX[boot_device]="$device_choice"
            CTX[boot_partition]="$device_choice"

            # Mock extraction
            local backup_path="backups/boot-$(get_timestamp).img"
            mock_backup "$device_choice" "$backup_path" "none"
            CTX[stock_boot_path]="$backup_path"

            log "Will extract boot image from: $device_choice" "INFO"
            ;;
        "Browse for existing boot.img file")
            local selected_file
            selected_file=$(ui_select_file "Select Boot Image" "." "*.img")
            if [[ "$selected_file" == "CANCEL" ]]; then
                return 1
            fi

            CTX[boot_source]="file"
            CTX[stock_boot_path]="$selected_file"

            log "Selected boot image file: $selected_file" "INFO"
            ;;
    esac

    ui_msgbox "Note" "Stock header sets pagesize/base/cmdline—copying these avoids boot loops."

    return 0
}

# bootimg_adjust_2_0__extraction_summary
# Step 2-0: Extraction summary and inspection
bootimg_adjust_2_0__extraction_summary() {
    log "Starting step 2-0: Extraction summary" "INFO"

    local boot_path="${CTX[stock_boot_path]}"
    if [[ -z "$boot_path" ]]; then
        ui_msgbox "Error" "No boot image path available"
        return 1
    fi

    # Mock extraction
    local extract_dir="work/bootimg-$(get_timestamp)"
    mock_abootimg_extract "$boot_path" "$extract_dir"

    # Show extracted information
    local header_info
    header_info=$(mock_bootimg_header)

    local summary="Work directory: $extract_dir\n\n"
    summary+="Header information:\n"
    summary+="$header_info\n\n"
    summary+="Extracted files:\n"
    summary+="• kernel\n"
    summary+="• ramdisk.cpio.gz\n"
    summary+="• dtb (device tree blob)\n"
    summary+="• bootimg.cfg"

    ui_msgbox "Extraction Complete" "$summary"

    CTX[extract_dir]="$extract_dir"
    log "Boot image extracted to: $extract_dir" "INFO"

    return 0
}

# bootimg_adjust_3_0__select_new_kernel
# Step 3-0: Select new kernel image
bootimg_adjust_3_0__select_new_kernel() {
    log "Starting step 3-0: Select new kernel" "INFO"

    # Find available kernel images
    local kernels
    mapfile -t kernels < <(find builds/ -type f \( -name "Image*" -o -name "zImage*" \) 2>/dev/null | head -10)

    if [[ ${#kernels[@]} -eq 0 ]]; then
        ui_msgbox "No Kernels" "No kernel images found in builds/. Please run Kernel Build first."
        return 1
    fi

    # Create menu items
    local menu_items=()
    for kernel in "${kernels[@]}"; do
        local version
        version=$(mock_kernel_version "$kernel")
        local filename
        filename=$(basename "$kernel")
        menu_items+=("$kernel" "$filename (v$version)")
    done

    local choice
    choice=$(ui_menu "Select New Kernel Image" "${menu_items[@]}")

    if [[ "$choice" == "CANCEL" ]]; then
        return 1
    fi

    CTX[new_kernel]="$choice"
    CTX[new_kernel_version]=$(mock_kernel_version "$choice")

    log "Selected new kernel: ${CTX[new_kernel]} (v${CTX[new_kernel_version]})" "INFO"

    return 0
}

# bootimg_adjust_4_0__dtb_mode
# Step 4-0: Choose DTB mode
bootimg_adjust_4_0__dtb_mode() {
    log "Starting step 4-0: Choose DTB mode" "INFO"

    local choice
    choice=$(ui_menu "Choose DTB Mode" \
        "with-dt: mkbootimg --dt dtb.img" \
        "catdt: cat Image + dtb.img > Image_dtb")

    case "$choice" in
        "CANCEL")
            return 1
            ;;
        "with-dt: mkbootimg --dt dtb.img")
            CTX[dtb_mode]="with-dt"
            ;;
        "catdt: cat Image + dtb.img > Image_dtb")
            CTX[dtb_mode]="catdt"
            ;;
    esac

    ui_msgbox "Device Profile" "RG35XX-H (Allwinner H700)\n\nTip: Try 'with-dt' first; 'catdt' is a fallback for picky bootloaders."

    log "Selected DTB mode: ${CTX[dtb_mode]}" "INFO"
    return 0
}

# bootimg_adjust_5_0__select_dtb_variants
# Step 5-0: Select DTB variants
bootimg_adjust_5_0__select_dtb_variants() {
    log "Starting step 5-0: Select DTB variants" "INFO"

    # Get available DTB files
    local dtbs
    mapfile -t dtbs < <(find builds/ -name "*.dtb" 2>/dev/null | head -10)

    if [[ ${#dtbs[@]} -eq 0 ]]; then
        ui_msgbox "No DTBs" "No DTB files found. Please ensure kernel build included DTBs."
        return 1
    fi

    # Create checkbox menu (simulated with multiple selections)
    local selected_dtbs=()
    for dtb in "${dtbs[@]}"; do
        local filename
        filename=$(basename "$dtb")
        local choice
        choice=$(ui_yesno "Include DTB?" "$filename" "yes")
        if [[ $? -eq 0 ]]; then
            selected_dtbs+=("$dtb")
        fi
    done

    if [[ ${#selected_dtbs[@]} -eq 0 ]]; then
        ui_msgbox "Error" "At least one DTB must be selected"
        return 1
    fi

    CTX[selected_dtbs]="${selected_dtbs[*]}"
    log "Selected DTBs: ${CTX[selected_dtbs]}" "INFO"

    return 0
}

# bootimg_adjust_6_0__cmdline_editor
# Step 6-0: Kernel cmdline editor
bootimg_adjust_6_0__cmdline_editor() {
    log "Starting step 6-0: Cmdline editor" "INFO"

    # Get current cmdline from mock header
    local current_cmdline
    current_cmdline=$(mock_bootimg_header | grep "cmdline=" | cut -d'=' -f2-)

    if [[ -z "$current_cmdline" ]]; then
        current_cmdline="console=ttyS0,115200 console=tty0 root=/dev/mmcblk0p5 rw"
    fi

    # Show current cmdline and quick toggles
    local display="From stock:\n$current_cmdline\n\n"
    display+="Quick toggles:\n"
    display+="• console=tty0\n"
    display+="• ignore_loglevel\n"
    display+="• earlycon"

    ui_msgbox "Current Cmdline" "$display"

    # Edit cmdline
    local new_cmdline
    new_cmdline=$(ui_input "Kernel Cmdline" "Edit cmdline:" "$current_cmdline")

    if [[ "$new_cmdline" == "CANCEL" ]]; then
        return 1
    fi

    CTX[kernel_cmdline]="$new_cmdline"
    log "Updated kernel cmdline: $new_cmdline" "INFO"

    return 0
}

# bootimg_adjust_7_0__repack_bootimg
# Step 7-0: Repack boot image
bootimg_adjust_7_0__repack_bootimg() {
    log "Starting step 7-0: Repack boot image" "INFO"

    local new_kernel="${CTX[new_kernel]}"
    local extract_dir="${CTX[extract_dir]}"
    local dtb_mode="${CTX[dtb_mode]}"
    local cmdline="${CTX[kernel_cmdline]}"

    if [[ -z "$new_kernel" || -z "$extract_dir" ]]; then
        ui_msgbox "Error" "Missing kernel or extract directory"
        return 1
    fi

    # Create output path
    local output_path="builds/$(basename "$new_kernel" .gz)-boot.img"

    # Show repack details
    local details="Repacking with:\n"
    details+="• Kernel: $(basename "$new_kernel")\n"
    details+="• Ramdisk: ramdisk.cpio.gz\n"
    details+="• DTB mode: $dtb_mode\n"
    details+="• Cmdline: $cmdline\n\n"
    details+="Output: $output_path"

    ui_msgbox "Repack Details" "$details"

    # Mock repack process
    mock_mkbootimg "$new_kernel" "$extract_dir/ramdisk.cpio.gz" \
                   "$extract_dir/dtb" "$cmdline" "$output_path"

    CTX[new_bootimg]="$output_path"
    log "Boot image repacked: $output_path" "INFO"

    return 0
}

# bootimg_adjust_8_0__modules_sync
# Step 8-0: Sync kernel modules to RootFS
bootimg_adjust_8_0__modules_sync() {
    log "Starting step 8-0: Modules sync" "INFO"

    local kernel_version="${CTX[new_kernel_version]}"
    if [[ -z "$kernel_version" ]]; then
        ui_msgbox "Error" "No kernel version available"
        return 1
    fi

    # Mock module detection
    local modules_dir="builds/${CTX[repo_name]//\//-}/$(get_timestamp)/lib/modules/$kernel_version"

    # Create mock modules
    mkdir -p "$modules_dir"
    touch "$modules_dir/modules.dep"
    touch "$modules_dir/modules.alias"

    # Show sync details
    local details="Detected kernel: $kernel_version\n"
    details+="RootFS partition: /dev/sdb5 (mount: /mnt/rootfs)\n\n"
    details+="Will copy: $modules_dir → /mnt/rootfs/lib/modules/…"

    ui_msgbox "Modules Sync" "$details"

    # Confirm sync
    local choice
    choice=$(ui_yesno "Confirm Sync" "Do this now (recommended)?" "yes")

    if [[ $? -eq 0 ]]; then
        mock_modules_sync "$modules_dir" "/mnt/rootfs"
        log "Modules synced successfully" "INFO"
    else
        log "Modules sync skipped" "WARN"
    fi

    return 0
}

# bootimg_adjust_9_0__flash_boot_partition
# Step 9-0: Flash new boot image to partition
bootimg_adjust_9_0__flash_boot_partition() {
    log "Starting step 9-0: Flash boot partition" "INFO"

    local new_bootimg="${CTX[new_bootimg]}"
    local boot_partition="${CTX[boot_partition]:-/dev/sdb4}"

    if [[ -z "$new_bootimg" ]]; then
        ui_msgbox "Error" "No boot image to flash"
        return 1
    fi

    # Safety backup
    local safety_backup="backups/boot-pre-adjust-$(get_timestamp).img"
    mock_backup "$boot_partition" "$safety_backup" "none"
    log "Safety backup created: $safety_backup" "INFO"

    # Double confirmation
    local confirm_msg="About to flash:\n$new_bootimg\n\nTo partition:\n$boot_partition\n\n"
    confirm_msg+="This will overwrite the current boot partition!"

    if ! ui_danger_confirm "Flash Boot Partition" "$confirm_msg" "FLASH"; then
        return 1
    fi

    # Mock flash
    mock_flash "$new_bootimg" "$boot_partition"

    ui_msgbox "Flash Complete" "New boot image flashed successfully!\n\nSafety backup: $safety_backup"

    return 0
}

# bootimg_adjust_10_0__qemu_smoke_test
# Step 10-0: Optional QEMU smoke test
bootimg_adjust_10_0__qemu_smoke_test() {
    log "Starting step 10-0: QEMU smoke test" "INFO"

    local choice
    choice=$(ui_yesno "QEMU Boot Test" \
        "Run headless boot test to verify the new boot image?\n\nThis captures first 200 lines of kernel log." \
        "yes")

    if [[ $? -eq 0 ]]; then
        local bootimg="${CTX[new_bootimg]}"
        mock_qemu_test "$bootimg"

        ui_msgbox "QEMU Test Complete" "Boot test completed successfully!\n\nCheck logs for kernel output."
    else
        log "QEMU test skipped" "INFO"
    fi

    return 0
}

# bootimg_adjust_11_0__done
# Step 11-0: Completion and next steps
bootimg_adjust_11_0__done() {
    log "Starting step 11-0: Done" "INFO"

    local completion_msg="Boot.img / RootFS Adjuster completed!\n\n"
    completion_msg+="New boot.img is flashed and modules synced.\n\n"
    completion_msg+="Next steps:\n"
    completion_msg+="• Power off device, reinsert SD, and boot\n"
    completion_msg+="• If black screen: rerun Adjuster with alternate DTB or catdt mode\n"
    completion_msg+="• Return to Main Menu"

    ui_msgbox "Adjuster Complete" "$completion_msg"

    # Offer next steps
    local choice
    choice=$(ui_menu "Next Steps" "Return to Main Menu")

    case "$choice" in
        "Return to Main Menu")
            CTX[continue]="false"
            ;;
        "CANCEL")
            return 1
            ;;
    esac

    return 0
}

# Export step functions
export -f bootimg_adjust_1_0__choose_base_bootimg
export -f bootimg_adjust_2_0__extraction_summary
export -f bootimg_adjust_3_0__select_new_kernel
export -f bootimg_adjust_4_0__dtb_mode
export -f bootimg_adjust_5_0__select_dtb_variants
export -f bootimg_adjust_6_0__cmdline_editor
export -f bootimg_adjust_7_0__repack_bootimg
export -f bootimg_adjust_8_0__modules_sync
export -f bootimg_adjust_9_0__flash_boot_partition
export -f bootimg_adjust_10_0__qemu_smoke_test
export -f bootimg_adjust_11_0__done
