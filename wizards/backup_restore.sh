#!/bin/bash
# wizards/backup_restore.sh - Backup/Restore Wizard Orchestrator
# This script coordinates backup and restore operations through multiple steps
# Each step is implemented as a separate file in the backup_restore/ directory

# Source required libraries
source "$TOOLKIT_ROOT/lib/base.sh"
source "$TOOLKIT_ROOT/lib/ui.sh"
source "$TOOLKIT_ROOT/lib/config.sh"
source "$TOOLKIT_ROOT/mocks/data.sh"
source "$TOOLKIT_ROOT/mocks/fs.sh"
source "$TOOLKIT_ROOT/mocks/progress.sh"

# Wizard-specific variables
WIZARD_NAME="backup_restore"
WIZARD_TITLE="Backup / Restore"

# backup_restore_1_0__choose_action
# Step 1-0: Choose backup or restore action
backup_restore_1_0__choose_action() {
    log "Starting step 1-0: Choose action" "INFO"

    local choice
    choice=$(ui_menu "Choose Action" \
        "Backup partitions" \
        "Restore from backup")

    case "$choice" in
        "CANCEL")
            return 1
            ;;
        "Backup partitions")
            CTX[action]="backup"
            log "Selected action: backup" "INFO"
            ;;
        "Restore from backup")
            CTX[action]="restore"
            log "Selected action: restore" "INFO"
            ;;
    esac

    return 0
}

# backup_restore_2_0__select_partitions
# Step 2-0: Select partitions to backup/restore
backup_restore_2_0__select_partitions() {
    log "Starting step 2-0: Select partitions" "INFO"

    local action="${CTX[action]}"
    local title="Select Partitions to $action"

    # Get available partitions
    local partitions
    mapfile -t partitions < <(mock_lsblk | grep -E "sdb[0-9]|mmcblk0p[0-9]" | awk '{print $1}')

    if [[ ${#partitions[@]} -eq 0 ]]; then
        ui_msgbox "No Partitions" "No partitions found. Please ensure device is connected."
        return 1
    fi

    # Create partition info
    local menu_items=()
    for part in "${partitions[@]}"; do
        local info
        info=$(mock_lsblk | grep "$part")
        local size
        size=$(echo "$info" | awk '{print $4}')
        local mount
        mount=$(echo "$info" | awk '{print $7}')

        local desc="$part ($size)"
        if [[ -n "$mount" ]]; then
            desc+=" - $mount"
        fi

        menu_items+=("$part" "$desc")
    done

    # For backup, allow multiple selection
    if [[ "$action" == "backup" ]]; then
        local selected_parts=()
        for item in "${menu_items[@]}"; do
            # Skip descriptions, only process partition names
            if [[ "$item" =~ ^/dev/ ]]; then
                local choice
                choice=$(ui_yesno "Include Partition?" "$item" "yes")
                if [[ $? -eq 0 ]]; then
                    selected_parts+=("$item")
                fi
            fi
        done

        if [[ ${#selected_parts[@]} -eq 0 ]]; then
            ui_msgbox "Error" "At least one partition must be selected"
            return 1
        fi

        CTX[selected_partitions]="${selected_parts[*]}"
        log "Selected partitions for backup: ${CTX[selected_partitions]}" "INFO"

    # For restore, select backup file first
    else
        local backup_files
        mapfile -t backup_files < <(find backups/ -name "*.img" 2>/dev/null | head -10)

        if [[ ${#backup_files[@]} -eq 0 ]]; then
            ui_msgbox "No Backups" "No backup files found in backups/ directory."
            return 1
        fi

        # Select backup file
        local backup_menu=()
        for backup in "${backup_files[@]}"; do
            local filename
            filename=$(basename "$backup")
            local size
            size=$(du -h "$backup" 2>/dev/null | cut -f1)
            backup_menu+=("$backup" "$filename ($size)")
        done

        local selected_backup
        selected_backup=$(ui_menu "Select Backup File" "${backup_menu[@]}")

        if [[ "$selected_backup" == "CANCEL" ]]; then
            return 1
        fi

        # Select target partition
        local target_part
        target_part=$(ui_menu "Select Target Partition" "${menu_items[@]}")

        if [[ "$target_part" == "CANCEL" ]]; then
            return 1
        fi

        CTX[backup_file]="$selected_backup"
        CTX[target_partition]="$target_part"
        log "Selected backup: $selected_backup, target: $target_part" "INFO"
    fi

    return 0
}

# backup_restore_3_0__execute_operation
# Step 3-0: Execute backup or restore operation
backup_restore_3_0__execute_operation() {
    log "Starting step 3-0: Execute operation" "INFO"

    local action="${CTX[action]}"

    if [[ "$action" == "backup" ]]; then
        # Execute backup
        local partitions="${CTX[selected_partitions]}"
        local timestamp
        timestamp=$(get_timestamp)

        for part in $partitions; do
            local backup_path="backups/$(basename "$part")-$timestamp.img"
            log "Backing up $part to $backup_path" "INFO"

            # Show progress
            ui_msgbox "Backing up..." "Creating backup of $part\n\nThis may take several minutes..."

            mock_backup "$part" "$backup_path" "gzip"
        done

        ui_msgbox "Backup Complete" "All selected partitions have been backed up successfully!"

    else
        # Execute restore
        local backup_file="${CTX[backup_file]}"
        local target_part="${CTX[target_partition]}"

        # Safety confirmation
        local confirm_msg="About to restore:\n$backup_file\n\nTo partition:\n$target_part\n\n"
        confirm_msg+="This will OVERWRITE the target partition!\n\n"
        confirm_msg+="Make sure you have a backup of important data."

        if ! ui_danger_confirm "Restore Partition" "$confirm_msg" "RESTORE"; then
            return 1
        fi

        # Show progress
        ui_msgbox "Restoring..." "Restoring $backup_file to $target_part\n\nThis may take several minutes..."

        mock_flash "$backup_file" "$target_part"

        ui_msgbox "Restore Complete" "Partition restored successfully!"
    fi

    return 0
}

# backup_restore_4_0__done
# Step 4-0: Completion and summary
backup_restore_4_0__done() {
    log "Starting step 4-0: Done" "INFO"

    local action="${CTX[action]}"
    local summary="Backup/Restore operation completed!\n\n"

    if [[ "$action" == "backup" ]]; then
        summary+="Backups created in: backups/\n"
        summary+="Files: $(ls backups/ | wc -l) backup files\n\n"
        summary+="Tip: Store backups in a safe location for recovery."
    else
        summary+="Partition restored from backup.\n\n"
        summary+="Next steps:\n"
        summary+="• Safely eject device\n"
        summary+="• Reboot to verify restore worked"
    fi

    summary+="\nReturn to Main Menu"

    ui_msgbox "Operation Complete" "$summary"

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
export -f backup_restore_1_0__choose_action
export -f backup_restore_2_0__select_partitions
export -f backup_restore_3_0__execute_operation
export -f backup_restore_4_0__done
