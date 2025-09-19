#!/bin/bash
# wizards/flash.sh - Flash Image Wizard Orchestrator
# This script coordinates the flash process through multiple steps
# Each step is implemented as a separate file in the flash/ directory

# Source required libraries
source "$TOOLKIT_ROOT/lib/base.sh"
source "$TOOLKIT_ROOT/lib/ui.sh"
source "$TOOLKIT_ROOT/lib/config.sh"
source "$TOOLKIT_ROOT/mocks/data.sh"
source "$TOOLKIT_ROOT/mocks/fs.sh"
source "$TOOLKIT_ROOT/mocks/progress.sh"

# Wizard-specific variables
WIZARD_NAME="flash"
WIZARD_TITLE="Flash Image"

# flash_1_0__pick_build_artifact
# Step 1-0: Pick build artifact to flash
flash_1_0__pick_build_artifact() {
    log "Starting step 1-0: Pick build artifact" "INFO"

    # Find available artifacts
    local artifacts
    mapfile -t artifacts < <(find builds/ -type f \( -name "Image*" -o -name "*.img" -o -name "zImage" \) 2>/dev/null | head -10)

    if [[ ${#artifacts[@]} -eq 0 ]]; then
        ui_msgbox "No Artifacts" "No build artifacts found. Please run Kernel Build first."
        return 1
    fi

    # Create menu items
    local menu_items=()
    for artifact in "${artifacts[@]}"; do
        local size
        size=$(du -h "$artifact" 2>/dev/null | cut -f1)
        local filename
        filename=$(basename "$artifact")
        menu_items+=("$artifact" "$filename ($size)")
    done

    # Add browse option
    menu_items+=("browse" "Browse for file...")

    local choice
    choice=$(ui_menu "Select Image or Kernel to Flash" "${menu_items[@]}")

    case "$choice" in
        "CANCEL")
            return 1
            ;;
        "browse")
            local selected_file
            selected_file=$(ui_select_file "Select File" "." "*")
            if [[ "$selected_file" == "CANCEL" ]]; then
                return 1
            fi
            CTX[artifact_path]="$selected_file"
            ;;
        *)
            CTX[artifact_path]="$choice"
            ;;
    esac

    log "Selected artifact: ${CTX[artifact_path]}" "INFO"

    # Show tip based on artifact type
    local filename
    filename=$(basename "${CTX[artifact_path]}")
    if [[ "$filename" == Image* ]]; then
        ui_msgbox "Tip" "If flashing a custom kernel, consider using Boot.img Adjuster next to ensure compatibility."
    fi

    return 0
}

# flash_2_0__select_sd_card
# Step 2-0: Select SD card target device
flash_2_0__select_sd_card() {
    log "Starting step 2-0: Select SD card" "INFO"

    # Get mock device list
    local devices
    devices=$(mock_lsblk)

    if [[ -z "$devices" ]]; then
        ui_msgbox "Error" "No block devices found"
        return 1
    fi

    # Parse devices and create menu
    local menu_items=()
    local device_paths=()
    while read -r line; do
        if [[ "$line" =~ \"name\": \"([^\"]+)\" ]]; then
            local device="${BASH_REMATCH[1]}"
            device_paths+=("/dev/$device")
        elif [[ "$line" =~ \"size\": \"([^\"]+)\" ]]; then
            local size="${BASH_REMATCH[1]}"
            if [[ "$line" =~ \"model\": \"([^\"]+)\" ]]; then
                local model="${BASH_REMATCH[1]}"
                menu_items+=("/dev/$device" "$model $size")
            fi
        fi
    done <<< "$devices"

    if [[ ${#menu_items[@]} -eq 0 ]]; then
        ui_msgbox "Error" "No suitable devices found"
        return 1
    fi

    local choice
    choice=$(ui_menu "Choose Target Device" "${menu_items[@]}")

    if [[ "$choice" == "CANCEL" ]]; then
        return 1
    fi

    CTX[target_device]="$choice"

    # Show device details
    local device_info="Device: $choice\n\n"
    device_info+="WARNING: Writing to a disk will erase existing data.\n"
    device_info+="Make a backup first if you haven't already."

    ui_msgbox "Device Selected" "$device_info"

    log "Selected target device: ${CTX[target_device]}" "INFO"
    return 0
}

# flash_3_0__backup_first
# Step 3-0: Optional backup before flashing
flash_3_0__backup_first() {
    log "Starting step 3-0: Backup first" "INFO"

    local target_device="${CTX[target_device]}"
    if [[ -z "$target_device" ]]; then
        ui_msgbox "Error" "No target device selected"
        return 1
    fi

    local choice
    choice=$(ui_yesno "Backup Before Flash" \
        "Recommended: Create a backup of $target_device before flashing.\n\nThis ensures you can restore if something goes wrong." \
        "yes")

    if [[ $? -eq 0 ]]; then
        # User wants backup
        local backup_choice
        backup_choice=$(ui_menu "Backup Scope" \
            "Full disk backup" \
            "Boot partition only" \
            "Skip backup")

        case "$backup_choice" in
            "CANCEL")
                return 1
                ;;
            "Full disk backup")
                CTX[backup_scope]="full"
                ;;
            "Boot partition only")
                CTX[backup_scope]="boot"
                ;;
            "Skip backup")
                CTX[backup_scope]="none"
                log "Backup skipped by user" "WARN"
                return 0
                ;;
        esac

        # Compression options
        local compression_choice
        compression_choice=$(ui_menu "Compression" "zstd" "gzip" "none")
        if [[ "$compression_choice" == "CANCEL" ]]; then
            return 1
        fi
        CTX[backup_compression]="$compression_choice"

        log "Backup configured: scope=${CTX[backup_scope]}, compression=${CTX[backup_compression]}" "INFO"
    else
        CTX[backup_scope]="none"
        log "Backup declined by user" "WARN"
    fi

    return 0
}

# flash_4_0__flash_progress
# Step 4-0: Flash progress with mock operations
flash_4_0__flash_progress() {
    log "Starting step 4-0: Flash progress" "INFO"

    local artifact_path="${CTX[artifact_path]}"
    local target_device="${CTX[target_device]}"
    local backup_scope="${CTX[backup_scope]:-none}"

    if [[ -z "$artifact_path" || -z "$target_device" ]]; then
        ui_msgbox "Error" "Missing artifact or target device"
        return 1
    fi

    # Create log file
    local log_file
    log_file=$(mock_touch_log "flash")

    # Perform backup if requested
    if [[ "$backup_scope" != "none" ]]; then
        local backup_dest="backups/$(basename "$target_device")-$(get_timestamp).img"
        mock_backup "$target_device" "$backup_dest" "${CTX[backup_compression]}"
        log "Backup created: $backup_dest" "INFO"
    fi

    # Perform flash
    mock_flash "$artifact_path" "$target_device"

    ui_msgbox "Flash Complete" "Image flashed successfully!\n\nTarget: $target_device\nArtifact: $(basename "$artifact_path")\n\nLog: $log_file"

    return 0
}

# flash_5_0__verify_done
# Step 5-0: Optional verification and completion
flash_5_0__verify_done() {
    log "Starting step 5-0: Verify and done" "INFO"

    local choice
    choice=$(ui_yesno "Optional Verification" \
        "Would you like to verify the flash by comparing hashes?\n\nThis is slower but ensures data integrity." \
        "no")

    if [[ $? -eq 0 ]]; then
        # Perform mock verification
        mock_spinner "Verifying flash integrity" 10
        ui_msgbox "Verification Complete" "Flash verification passed!\n\nHashes match - data integrity confirmed."
    fi

    # Show next steps
    local next_steps="Flash operation completed successfully!\n\n"
    next_steps+="Next steps:\n"
    next_steps+="• Run Boot.img / RootFS Adjuster if needed\n"
    next_steps+="• Power off device and test the new image\n"
    next_steps+="• Return to Main Menu"

    ui_msgbox "Flash Complete" "$next_steps"

    # Offer next steps
    local menu_choice
    menu_choice=$(ui_menu "Next Steps" \
        "Run Boot.img Adjuster" \
        "Return to Main Menu")

    case "$menu_choice" in
        "Run Boot.img Adjuster")
            CTX[next_wizard]="bootimg_adjust"
            ;;
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
export -f flash_1_0__pick_build_artifact
export -f flash_2_0__select_sd_card
export -f flash_3_0__backup_first
export -f flash_4_0__flash_progress
export -f flash_5_0__verify_done
